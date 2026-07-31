extends Control

@export var radius := 8.0
@export var line_width := 2.0
@export var cursor_color := Color(0.75, 0.95, 1.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 2.0 + line_width, radius * 2.0 + line_width)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 32, cursor_color, line_width, true)
	draw_circle(center, 1.5, cursor_color)

