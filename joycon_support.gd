extends Node

## Adapts two separately connected Joy-Con halves into one logical controller.
## OS-paired Joy-Cons and Switch Pro controllers already use Godot's standard
## joypad mapping and automatically fall back to the normal input actions.

const DEADZONE := 0.18

var _left_joycon := -1
var _right_joycon := -1


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_devices()


func get_movement_vector() -> Vector2:
	var standard_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)

	if _left_joycon < 0:
		return standard_input

	var joycon_input := Vector2(
		Input.get_joy_axis(_left_joycon, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(_left_joycon, JOY_AXIS_LEFT_Y)
	)
	return _apply_deadzone(joycon_input) if joycon_input.length() > DEADZONE else standard_input


func get_look_vector() -> Vector2:
	var standard_input := Input.get_vector(
		"look_left",
		"look_right",
		"look_up",
		"look_down",
		DEADZONE
	)

	if _right_joycon < 0:
		return standard_input

	# A separately connected right Joy-Con exposes its only stick as left-stick
	# axes. Treat those axes as the logical right stick of the combined pair.
	var joycon_input := Vector2(
		Input.get_joy_axis(_right_joycon, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(_right_joycon, JOY_AXIS_LEFT_Y)
	)
	return _apply_deadzone(joycon_input) if joycon_input.length() > DEADZONE else standard_input


func has_separate_pair() -> bool:
	return _left_joycon >= 0 and _right_joycon >= 0


func _refresh_devices() -> void:
	_left_joycon = -1
	_right_joycon = -1

	for device_id in Input.get_connected_joypads():
		var device_name := Input.get_joy_name(device_id).to_lower()
		if _is_left_joycon(device_name):
			_left_joycon = device_id
		elif _is_right_joycon(device_name):
			_right_joycon = device_id


func _is_left_joycon(device_name: String) -> bool:
	return (
		"joy-con (l)" in device_name
		or "joycon (l)" in device_name
		or "joy-con l" in device_name
	)


func _is_right_joycon(device_name: String) -> bool:
	return (
		"joy-con (r)" in device_name
		or "joycon (r)" in device_name
		or "joy-con r" in device_name
	)


func _apply_deadzone(value: Vector2) -> Vector2:
	var length := value.length()
	if length <= DEADZONE:
		return Vector2.ZERO
	var scaled_length := (length - DEADZONE) / (1.0 - DEADZONE)
	return value.normalized() * clampf(scaled_length, 0.0, 1.0)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_devices()

