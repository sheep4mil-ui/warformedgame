class_name PlayerInventory
extends Node

## Inventory state is kept separate from the HUD so a multiplayer authority can
## own and replicate it later without changing the presentation layer.
signal inventory_changed(slots: Array[Dictionary])

@export_range(1, 64, 1) var capacity: int = 16

var _slots: Array[Dictionary] = []


func _ready() -> void:
	_slots.resize(capacity)
	for index in capacity:
		_slots[index] = {}

	# Starter items make the first inventory build immediately testable.
	add_item("training_blade", "Training Blade", 1, 1)
	add_item("repair_gel", "Repair Gel", 3, 5)
	add_item("credit_chip", "Credit Chips", 24, 99)


func get_slots_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot in _slots:
		snapshot.append(slot.duplicate(true))
	return snapshot


func add_item(
	item_id: StringName,
	display_name: String,
	quantity: int = 1,
	max_stack: int = 1
) -> int:
	var remaining := maxi(quantity, 0)

	# Fill existing stacks first.
	for slot in _slots:
		if remaining == 0:
			break
		if slot.get("id", &"") != item_id:
			continue
		var free_space: int = maxi(int(slot.get("max_stack", 1)) - int(slot.get("quantity", 0)), 0)
		var moved := mini(remaining, free_space)
		slot["quantity"] = int(slot.get("quantity", 0)) + moved
		remaining -= moved

	# Then occupy empty slots.
	for index in _slots.size():
		if remaining == 0:
			break
		if not _slots[index].is_empty():
			continue
		var moved := mini(remaining, maxi(max_stack, 1))
		_slots[index] = {
			"id": item_id,
			"name": display_name,
			"quantity": moved,
			"max_stack": maxi(max_stack, 1),
		}
		remaining -= moved

	inventory_changed.emit(get_slots_snapshot())
	return remaining


func remove_from_slot(slot_index: int, quantity: int = 1) -> bool:
	if slot_index < 0 or slot_index >= _slots.size() or _slots[slot_index].is_empty():
		return false

	var current_quantity: int = int(_slots[slot_index].get("quantity", 0))
	if quantity <= 0 or quantity > current_quantity:
		return false

	current_quantity -= quantity
	if current_quantity == 0:
		_slots[slot_index] = {}
	else:
		_slots[slot_index]["quantity"] = current_quantity

	inventory_changed.emit(get_slots_snapshot())
	return true

