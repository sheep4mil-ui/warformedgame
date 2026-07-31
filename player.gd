extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.002
const CONTROLLER_LOOK_SPEED := 2.5
const CONTROLLER_DEADZONE := 0.15

@onready var head: Node3D = $Head
@onready var player_camera: Camera3D = $Head/Camera3D
@onready var controller_support: Node = $ControllerSupport
@onready var motion_receiver: Node = get_node_or_null("../MotionReceiver")
@onready var spartan_model: Node3D = get_node_or_null("SpartanModel")
var controls_enabled := true
var tracking_enabled := true
var tracker_connected := false
var third_person_enabled := false
var skeleton: Skeleton3D
var _jaw_rest := Quaternion.IDENTITY
var _smoothed_points: Array[Vector3] = []
var _camera_rest_position := Vector3.ZERO
var _camera_rest_rotation := Vector3.ZERO

const TRACKED_BONES := {
	"hip_02": "hip", "abdomen_03": "abdomen", "chest_04": "chest",
	"neck_05": "neck", "head_06": "head",
	"rShldr_018": "right_upper_arm", "rForeArm_019": "right_forearm", "rHand_020": "right_hand",
	"lShldr_042": "left_upper_arm", "lForeArm_043": "left_forearm", "lHand_044": "left_hand",
	"rThigh_083": "right_thigh", "rShin_084": "right_shin", "rFoot_085": "right_foot",
	"lThigh_0100": "left_thigh", "lShin_0101": "left_shin", "lFoot_0102": "left_foot",
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED
	_camera_rest_position = player_camera.position
	_camera_rest_rotation = player_camera.rotation
	if spartan_model:
		skeleton = spartan_model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		var jaw_id := skeleton.find_bone("lowerJaw_09")
		if jaw_id >= 0:
			_jaw_rest = skeleton.get_bone_pose_rotation(jaw_id)
	if motion_receiver:
		motion_receiver.motion_packet_received.connect(_on_motion_packet)
		motion_receiver.connection_changed.connect(_on_tracker_connection_changed)

func _on_tracker_connection_changed(connected: bool) -> void:
	tracker_connected = connected

func _on_motion_packet(packet: Dictionary) -> void:
	if not tracking_enabled or not skeleton:
		return
	var raw_pose = packet.get("pose", [])
	if raw_pose is Array and raw_pose.size() >= 33:
		_apply_tracked_pose(raw_pose, bool(packet.get("handsLatched", false)))
	_apply_tracked_face(packet.get("face", {}))

func _tracking_point(raw_pose: Array, index: int) -> Vector3:
	var point: Array = raw_pose[index]
	return Vector3(-float(point[0]), -float(point[1]), -float(point[2]))

func _apply_tracked_pose(raw_pose: Array, hands_latched: bool) -> void:
	var raw_points: Array[Vector3] = []
	for index in raw_pose.size():
		raw_points.append(_tracking_point(raw_pose, index))
	if _smoothed_points.size() != raw_points.size():
		_smoothed_points = raw_points.duplicate()
	else:
		for index in raw_points.size():
			_smoothed_points[index] = _smoothed_points[index].lerp(raw_points[index], 0.58)
	var points: Array[Vector3] = _smoothed_points.duplicate()
	if hands_latched:
		# Aim both forearms at one shared wrist while retaining each hand's
		# direction. Collapsing every finger point made the hand bone undefined.
		var shared_wrist := (points[15] + points[16]) * 0.5
		points[15] = shared_wrist
		points[16] = shared_wrist
	var hip := (points[23] + points[24]) * 0.5
	var shoulders := (points[11] + points[12]) * 0.5
	var segments := {
		"hip": [hip, shoulders],
		"abdomen": [hip, hip.lerp(shoulders, 0.52)],
		"chest": [hip.lerp(shoulders, 0.48), shoulders],
		"neck": [shoulders, points[0]], "head": [shoulders.lerp(points[0], 0.65), points[0]],
		"right_upper_arm": [points[12], points[14]], "right_forearm": [points[14], points[16]],
		"right_hand": [points[16], (points[18] + points[20] + points[22]) / 3.0],
		"left_upper_arm": [points[11], points[13]], "left_forearm": [points[13], points[15]],
		"left_hand": [points[15], (points[17] + points[19] + points[21]) / 3.0],
		"right_thigh": [points[24], points[26]], "right_shin": [points[26], points[28]], "right_foot": [points[28], points[32]],
		"left_thigh": [points[23], points[25]], "left_shin": [points[25], points[27]], "left_foot": [points[27], points[31]],
	}
	for bone_name in TRACKED_BONES:
		var segment: Array = segments.get(String(TRACKED_BONES[bone_name]), [])
		if segment.size() == 2:
			_drive_bone_global(bone_name, segment[0], segment[1])
	_follow_tracked_head()

func _follow_tracked_head() -> void:
	var head_id := skeleton.find_bone("head_06")
	if head_id < 0:
		return
	var head_world := skeleton.global_transform * skeleton.get_bone_global_pose(head_id)
	if third_person_enabled:
		var target := head_world.origin + Vector3.UP * 0.12
		var behind := global_basis.z.normalized()
		player_camera.global_position = target + behind * 3.2 + Vector3.UP * 0.65
		player_camera.look_at(target, Vector3.UP)
	else:
		# Follow the tracked head while retaining player/mouse look orientation.
		# The unscaled world-space offset keeps the lens 22 cm beyond the face.
		player_camera.rotation = _camera_rest_rotation
		var camera_forward := -player_camera.global_basis.z.normalized()
		player_camera.global_position = head_world.origin + camera_forward * 0.22

func _drive_bone_global(bone_name: String, start: Vector3, end: Vector3) -> void:
	var bone_id := skeleton.find_bone(bone_name)
	if bone_id < 0:
		return
	var children := skeleton.get_bone_children(bone_id)
	if children.is_empty():
		return
	var rest_global := skeleton.get_bone_global_rest(bone_id)
	var child_rest := skeleton.get_bone_global_rest(children[0])
	var rest_direction := child_rest.origin - rest_global.origin
	var target := end - start
	if rest_direction.length_squared() < 0.0001 or target.length_squared() < 0.0001:
		return
	var delta_rotation := Quaternion(rest_direction.normalized(), target.normalized())
	var desired_global := delta_rotation * rest_global.basis.get_rotation_quaternion()
	var parent_id := skeleton.get_bone_parent(bone_id)
	var parent_global := Quaternion.IDENTITY
	if parent_id >= 0:
		parent_global = skeleton.get_bone_global_pose(parent_id).basis.get_rotation_quaternion()
	var desired_local := parent_global.inverse() * desired_global
	var current_local := skeleton.get_bone_pose_rotation(bone_id)
	# Local rotations preserve the skeleton hierarchy. Global pose overrides also
	# froze each rest-position origin, making the limbs detach and act alone.
	skeleton.set_bone_pose_rotation(bone_id, current_local.slerp(desired_local, 0.82))

func _apply_tracked_face(face) -> void:
	if not skeleton or not (face is Dictionary):
		return
	var jaw_id := skeleton.find_bone("lowerJaw_09")
	if jaw_id < 0:
		return
	var raw_open := float(face.get("jawOpen", 0.0))
	var openness: float = clampf((raw_open - 0.004) * 2.4, 0.0, 1.0)
	skeleton.set_bone_pose_rotation(jaw_id, _jaw_rest * Quaternion(Vector3.RIGHT, openness * 0.6))

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F5:
		third_person_enabled = not third_person_enabled
		if not third_person_enabled:
			player_camera.rotation = _camera_rest_rotation
		_follow_tracked_head()
		print("Third-person camera %s" % ("enabled" if third_person_enabled else "disabled"))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		tracking_enabled = not tracking_enabled
		if not tracking_enabled and skeleton:
			skeleton.clear_bones_global_pose_override()
			player_camera.position = _camera_rest_position
		print("Body tracking %s" % ("enabled" if tracking_enabled else "disabled"))
		get_viewport().set_input_as_handled()
		return

	# Mouse look
	if controls_enabled and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)

		head.rotation.x = clamp(
			head.rotation.x,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)

	# Capture mouse when left-clicking.
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not OS.has_feature("web"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta):
	if not controls_enabled:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# Right stick look
	var look_input: Vector2 = controller_support.call("get_look_vector")

	rotate_y(-look_input.x * CONTROLLER_LOOK_SPEED * delta)
	head.rotate_x(-look_input.y * CONTROLLER_LOOK_SPEED * delta)

	head.rotation.x = clamp(
		head.rotation.x,
		deg_to_rad(-89.0),
		deg_to_rad(89.0)
	)

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement
	var movement_input: Vector2 = controller_support.call("get_movement_vector")

	var arrow_input := Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	movement_input += arrow_input

	if movement_input.length() > 1.0:
		movement_input = movement_input.normalized()

	var direction := (
		transform.basis *
		Vector3(movement_input.x, 0.0, movement_input.y)
	).normalized()

	if direction != Vector3.ZERO:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

	move_and_slide()
