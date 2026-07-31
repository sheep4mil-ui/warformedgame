extends Control

const InventoryCursor = preload("res://inventory_cursor.gd")
const CONTROLLER_CURSOR_SPEED := 650.0

@export var inventory_path: NodePath
@export var player_path: NodePath
@export var crosshair_path: NodePath

var _inventory: Node
var _player: CharacterBody3D
var _crosshair: Control
var _panel: PanelContainer
var _grid: GridContainer
var _details: Label
var _cursor: Control
var _cursor_position := Vector2.ZERO
var _slot_buttons: Array[Button] = []
var _is_open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_inventory = get_node(inventory_path)
	_player = get_node(player_path) as CharacterBody3D
	_crosshair = get_node(crosshair_path) as Control

	_build_interface()
	_inventory.inventory_changed.connect(_refresh_slots)
	_refresh_slots(_inventory.get_slots_snapshot())
	_set_open(false)


func _process(delta: float) -> void:
	if not _is_open:
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
		_cursor_position = _cursor_position.clamp(Vector2.ZERO, size)
		_update_cursor_position()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		_set_open(not _is_open)
		get_viewport().set_input_as_handled()
	elif _is_open and event.is_action_pressed("ui_cancel"):
		_set_open(false)
		get_viewport().set_input_as_handled()
	elif _is_open and event is InputEventMouseMotion:
		_cursor_position = event.position
		_update_cursor_position()
	elif _is_open and event is InputEventJoypadButton:
		if event.pressed and event.button_index == JOY_BUTTON_A:
			_select_item_under_cursor()
			get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(660, 460)
	center.add_child(_panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)

	var title := Label.new()
	title.text = "ADVENTURER'S PACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	content.add_child(title)

	var rule := HSeparator.new()
	content.add_child(rule)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_grid)

	for slot_index in _inventory.capacity:
		var button := Button.new()
		button.custom_minimum_size = Vector2(145, 74)
		button.text = "EMPTY"
		button.pressed.connect(_on_slot_selected.bind(slot_index))
		_grid.add_child(button)
		_slot_buttons.append(button)

	_details = Label.new()
	_details.text = "Select an item to inspect it."
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_details)

	var hint := Label.new()
	hint.text = "Press I to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.7, 0.75, 0.82)
	content.add_child(hint)

	_cursor = InventoryCursor.new()
	_cursor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_cursor.size = Vector2(22, 22)
	_cursor.z_index = 100
	add_child(_cursor)


func _refresh_slots(slots: Array[Dictionary]) -> void:
	for index in _slot_buttons.size():
		var slot: Dictionary = slots[index] if index < slots.size() else {}
		if slot.is_empty():
			_slot_buttons[index].text = "EMPTY"
			_slot_buttons[index].disabled = true
			continue

		var quantity: int = int(slot.get("quantity", 1))
		var quantity_text := "\n×%d" % quantity if quantity > 1 else ""
		_slot_buttons[index].text = "%s%s" % [str(slot.get("name", "Unknown")), quantity_text]
		_slot_buttons[index].disabled = false


func _on_slot_selected(slot_index: int) -> void:
	var slots: Array[Dictionary] = _inventory.get_slots_snapshot()
	if slot_index >= slots.size() or slots[slot_index].is_empty():
		_details.text = "Empty slot"
		return

	var slot: Dictionary = slots[slot_index]
	var stack_type := "Infinite stack" if bool(slot.get("stackable", true)) else "Non-stackable"
	_details.text = "%s  •  Quantity: %d  •  %s  •  Item ID: %s" % [
		str(slot.get("name", "Unknown")),
		int(slot.get("quantity", 0)),
		stack_type,
		str(slot.get("id", &"")),
	]


func _set_open(open: bool) -> void:
	_is_open = open
	_panel.visible = open
	_cursor.visible = open
	_crosshair.visible = not open
	mouse_filter = Control.MOUSE_FILTER_STOP if open else Control.MOUSE_FILTER_IGNORE
	_player.set("controls_enabled", not open)
	if open:
		_cursor_position = size * 0.5
		_update_cursor_position()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_cursor_position() -> void:
	_cursor.position = _cursor_position - _cursor.size * 0.5


func _select_item_under_cursor() -> void:
	var global_cursor_position := get_global_transform_with_canvas() * _cursor_position
	for slot_index in _slot_buttons.size():
		var button := _slot_buttons[slot_index]
		if not button.disabled and button.get_global_rect().has_point(global_cursor_position):
			button.grab_focus()
			_on_slot_selected(slot_index)
			return
