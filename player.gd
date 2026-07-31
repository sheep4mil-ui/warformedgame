extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.002
const CONTROLLER_LOOK_SPEED := 2.5
const CONTROLLER_DEADZONE := 0.15

@onready var head: Node3D = $Head
@onready var controller_support: Node = $ControllerSupport
@onready var motion_receiver: Node = get_node_or_null("../MotionReceiver")
@onready var spartan_model: Node3D = get_node_or_null("SpartanModel")
var controls_enabled := true
var tracking_enabled := true
var tracker_connected := false
var skeleton: Skeleton3D
var _jaw_rest := Quaternion.IDENTITY

const TRACKED_BONES := {
	"hip_02": "hip", "abdomen_03": "abdomen", "chest_04": "chest",
	"neck_05": "neck", "head_06": "head",
	"rShldr_018": "right_upper_arm", "rForeArm_019": "right_forearm", "rHand_020": "right_hand",
	"lShldr_042": "left_upper_arm", "lForeArm_043": "left_forearm", "lHand_044": "left_hand",
	"rThigh_083": "right_thigh", "rShin_084": "right_shin", "rFoot_085": "right_foot",
	"lThigh_0100": "left_thigh", "lShin_0101": "left_shin", "lFoot_0102": "left_foot",
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	var points: Array[Vector3] = []
	for index in raw_pose.size():
		points.append(_tracking_point(raw_pose, index))
	if hands_latched:
		var palm := Vector3.ZERO
		for index in [15, 17, 19, 21, 16, 18, 20, 22]:
			palm += points[index]
		palm /= 8.0
		for index in [15, 17, 19, 21, 16, 18, 20, 22]:
			points[index] = palm
	var hip := (points[23] + points[24]) * 0.5
	var shoulders := (points[11] + points[12]) * 0.5
	var segments := {
		"hip": [hip + Vector3(0, -0.25, 0), hip],
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

func _drive_bone_global(bone_name: String, start: Vector3, end: Vector3) -> void:
	var bone_id := skeleton.find_bone(bone_name)
	if bone_id < 0:
		return
	var children := skeleton.get_bone_children(bone_id)
	if children.is_empty():
		return
	var rest := skeleton.get_bone_global_rest(bone_id)
	var child_rest := skeleton.get_bone_global_rest(children[0])
	var rest_direction := child_rest.origin - rest.origin
	var target := end - start
	if rest_direction.length_squared() < 0.0001 or target.length_squared() < 0.0001:
		return
	var delta_rotation := Quaternion(rest_direction.normalized(), target.normalized())
	var target_pose := rest
	target_pose.basis = Basis(delta_rotation * rest.basis.get_rotation_quaternion())
	skeleton.set_bone_global_pose_override(bone_id, target_pose, 0.82, true)

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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_T:
		tracking_enabled = not tracking_enabled
		if not tracking_enabled and skeleton:
			skeleton.clear_bones_global_pose_override()
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
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
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
