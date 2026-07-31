extends Node3D

@export var hotbar_path: NodePath

var _hotbar: Node


func _ready() -> void:
	_hotbar = get_node(hotbar_path)
	_hotbar.connect("selected_slot_changed", _on_selected_item_changed)
	var selected_slot: int = _hotbar.call("get_selected_slot")
	var slots: Array[Dictionary] = _hotbar.call("get_slots_snapshot")
	_on_selected_item_changed(selected_slot, slots[selected_slot])


func _on_selected_item_changed(_slot_index: int, item: Dictionary) -> void:
	for child in get_children():
		child.queue_free()

	if item.is_empty():
		return

	match StringName(item.get("id", &"")):
		&"training_blade":
			_create_training_blade()
		&"repair_gel":
			_create_repair_gel()
		&"credit_chip":
			_create_credit_chips()
		_:
			_create_generic_item()


func _create_training_blade() -> void:
	var steel := _material(Color(0.72, 0.8, 0.9), 0.25, 0.75)
	var leather := _material(Color(0.2, 0.08, 0.035), 0.8)
	_add_box(Vector3(0.075, 0.72, 0.045), Vector3(0, 0.18, 0), steel)
	_add_box(Vector3(0.16, 0.08, 0.08), Vector3(0, -0.2, 0), leather)
	_add_box(Vector3(0.075, 0.28, 0.075), Vector3(0, -0.36, 0), leather)


func _create_repair_gel() -> void:
	var bottle := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.13
	mesh.height = 0.32
	bottle.mesh = mesh
	bottle.material_override = _material(Color(0.1, 0.9, 0.55, 0.82), 0.15, 0.05)
	add_child(bottle)


func _create_credit_chips() -> void:
	var gold := _material(Color(1.0, 0.68, 0.12), 0.28, 0.8)
	for index in 3:
		_add_box(Vector3(0.24, 0.035, 0.14), Vector3(0, float(index) * 0.045, 0), gold)


func _create_generic_item() -> void:
	_add_box(Vector3(0.24, 0.24, 0.24), Vector3.ZERO, _material(Color(0.65, 0.48, 0.28), 0.75))


func _add_box(box_size: Vector3, local_position: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.position = local_position
	instance.material_override = material
	add_child(instance)


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

