class_name PlayerHotbar
extends Node

signal hotbar_changed(slots: Array[Dictionary])
signal selected_slot_changed(slot_index: int, item: Dictionary)

const SLOT_COUNT := 3

var _slots: Array[Dictionary] = [{}, {}, {}]
var _selected_slot := 0


func _ready() -> void:
	_emit_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("hotbar_previous"):
		select_slot((_selected_slot - 1 + SLOT_COUNT) % SLOT_COUNT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_next"):
		select_slot((_selected_slot + 1) % SLOT_COUNT)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_slot_1"):
		select_slot(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_slot_2"):
		select_slot(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_slot_3"):
		select_slot(2)
		get_viewport().set_input_as_handled()


func assign_item(item: Dictionary) -> void:
	_slots[_selected_slot] = item.duplicate(true)
	_emit_state()


func select_slot(slot_index: int) -> void:
	_selected_slot = clampi(slot_index, 0, SLOT_COUNT - 1)
	_emit_state()


func get_slots_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for slot in _slots:
		snapshot.append(slot.duplicate(true))
	return snapshot


func get_selected_slot() -> int:
	return _selected_slot


func _emit_state() -> void:
	var snapshot := get_slots_snapshot()
	hotbar_changed.emit(snapshot)
	selected_slot_changed.emit(_selected_slot, snapshot[_selected_slot])

