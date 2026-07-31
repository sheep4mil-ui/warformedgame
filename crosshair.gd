extends Control

## Radius of the circular reticle in screen pixels.
@export_range(1.0, 100.0, 1.0) var radius: float = 10.0:
	set(value):
		radius = value
		queue_redraw()

## Thickness of the circle outline in screen pixels.
@export_range(1.0, 10.0, 0.5) var line_width: float = 2.0:
	set(value):
		line_width = value
		queue_redraw()

## Color of the circular reticle.
@export var crosshair_color: Color = Color.WHITE:
	set(value):
		crosshair_color = value
		queue_redraw()


func _ready() -> void:
	# The HUD must never intercept clicks or mouse movement.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, radius, 0.0, TAU, 64, crosshair_color, line_width, true)

