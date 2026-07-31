extends Control

signal primary_action(global_cursor_position: Vector2)

const CONTROLLER_CURSOR_SPEED := 650.0

@export var radius := 8.0
@export var line_width := 2.0
@export var cursor_color := Color(0.75, 0.95, 1.0)

var _active := false
var _cursor_position := Vector2.ZERO
var _movement_bounds := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0 + line_width, radius * 2.0 + line_width)
	visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return

	var stick_input := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward",
		0.2
	)
	if stick_input.length() > 0.0:
		_cursor_position += stick_input * CONTROLLER_CURSOR_SPEED * delta
		_cursor_position = _cursor_position.clamp(Vector2.ZERO, _movement_bounds)
		_update_position()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventMouseMotion:
		_cursor_position = event.position.clamp(Vector2.ZERO, _movement_bounds)
		_update_position()
	elif event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_A:
			primary_action.emit(get_global_transform_with_canvas() * size * 0.5)
			get_viewport().set_input_as_handled()


func activate(movement_bounds: Vector2) -> void:
	_active = true
	_movement_bounds = movement_bounds
	_cursor_position = movement_bounds * 0.5
	visible = true
	_update_position()


func deactivate() -> void:
	_active = false
	visible = false


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 32, cursor_color, line_width, true)
	draw_circle(center, 1.5, cursor_color)


func _update_position() -> void:
	position = _cursor_position - size * 0.5
