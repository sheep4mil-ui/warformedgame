extends Control

@export var hotbar_path: NodePath

var _hotbar: Node
var _slot_panels: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hotbar = get_node(hotbar_path)
	_build_interface()
	_hotbar.connect("hotbar_changed", _refresh)
	_hotbar.connect("selected_slot_changed", _on_selected_slot_changed)
	_refresh(_hotbar.call("get_slots_snapshot"))
	_on_selected_slot_changed(_hotbar.call("get_selected_slot"), {})


func _build_interface() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-225, -100)
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	for index in 3:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(140, 72)
		row.add_child(panel)
		_slot_panels.append(panel)

		var label := Label.new()
		label.text = "%d\nEMPTY" % (index + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		panel.add_child(label)
		_slot_labels.append(label)


func _refresh(slots: Array[Dictionary]) -> void:
	for index in _slot_labels.size():
		var item: Dictionary = slots[index] if index < slots.size() else {}
		var item_name := "EMPTY" if item.is_empty() else str(item.get("name", "Unknown"))
		_slot_labels[index].text = "%d\n%s" % [index + 1, item_name]


func _on_selected_slot_changed(slot_index: int, _item: Dictionary) -> void:
	for index in _slot_panels.size():
		_slot_panels[index].modulate = (
			Color(1.0, 0.82, 0.32, 1.0)
			if index == slot_index
			else Color(0.65, 0.7, 0.8, 0.82)
		)

