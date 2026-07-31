extends CanvasLayer

const MenuCursor = preload("res://inventory_cursor.gd")

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var _cursor: Control


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cursor = MenuCursor.new()
	_cursor.size = Vector2(22, 22)
	_cursor.z_index = 100
	_cursor.connect("primary_action", _activate_control_at_position)
	add_child(_cursor)
	hide()


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			resume_game()
		else:
			pause_game()

		get_viewport().set_input_as_handled()


func pause_game():
	get_tree().paused = true
	show()
	_cursor.call("activate", get_viewport().get_visible_rect().size)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	resume_button.grab_focus()


func resume_game():
	_cursor.call("deactivate")
	get_tree().paused = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_resume_button_pressed():
	resume_game()


func _on_quit_button_pressed():
	get_tree().quit()


func _activate_control_at_position(global_cursor_position: Vector2) -> void:
	for button in [resume_button, quit_button]:
		if button.visible and not button.disabled and button.get_global_rect().has_point(global_cursor_position):
			button.grab_focus()
			button.pressed.emit()
			return
