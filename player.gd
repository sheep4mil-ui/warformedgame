extends CharacterBody3D

const SPEED := 5.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.002
const CONTROLLER_LOOK_SPEED := 2.5
const CONTROLLER_DEADZONE := 0.15

@onready var head: Node3D = $Head

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event):
	# Mouse look
	if event is InputEventMouseMotion:
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
	# Right stick look
	var look_input := Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down",
		CONTROLLER_DEADZONE
	)

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
	var movement_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

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
