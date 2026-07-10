extends Node
class_name InventoryManager

signal inventory_changed
signal slot_changed(slot_index: int)

@export var starting_slot_count: int = 16
@export var default_stack_limit: int = 99
@export var debug_inventory_logging: bool = true

var slots: Array[Dictionary] = []

func _ready() -> void:
	add_to_group("inventory_manager")
	ensure_slot_count(starting_slot_count)

func _create_empty_slot() -> Dictionary:
	return {
		"item_id": "",
		"amount": 0
	}

func ensure_slot_count(target_slot_count: int) -> void:
	var safe_target_count: int = maxi(target_slot_count, 1)

	while slots.size() < safe_target_count:
		slots.append(_create_empty_slot())

	inventory_changed.emit()
	
func add_inventory_slots(additional_slots: int) -> void:
	if additional_slots <= 0:
		return

	ensure_slot_count(slots.size() + additional_slots)

func get_slot_count() -> int:
	return slots.size()

func get_slot(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= slots.size():
		return {}

	return slots[slot_index].duplicate(true)

func is_slot_empty(slot_index: int) -> bool:
	var slot_data: Dictionary = get_slot(slot_index)

	if slot_data.is_empty():
		return true

	return str(slot_data.get("item_id", "")).is_empty()

func get_item_stack_limit(_item_id: String) -> int:
	return default_stack_limit

func get_item_amount(item_id: String) -> int:
	var total_amount: int = 0

	for slot_data in slots:
		if str(slot_data.get("item_id", "")) != item_id:
			continue

		total_amount += int(slot_data.get("amount", 0))

	return total_amount

func has_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	return get_item_amount(item_id) >= amount

func add_item(item_id: String, amount: int) -> int:
	if item_id.is_empty() or amount <= 0:
		return amount

	var remaining_amount: int = amount
	var stack_limit: int = get_item_stack_limit(item_id)

	# Fill existing stacks first.
	for slot_index in range(slots.size()):
		var slot_data: Dictionary = slots[slot_index]

		if str(slot_data.get("item_id", "")) != item_id:
			continue

		var current_amount: int = int(slot_data.get("amount", 0))
		var available_space: int = stack_limit - current_amount

		if available_space <= 0:
			continue

		var amount_to_add: int = mini(
			remaining_amount,
			available_space
		)

		slot_data["amount"] = current_amount + amount_to_add
		slots[slot_index] = slot_data

		remaining_amount -= amount_to_add
		slot_changed.emit(slot_index)

		if remaining_amount <= 0:
			inventory_changed.emit()
			return 0

	# Then use empty slots.
	for slot_index in range(slots.size()):
		if not is_slot_empty(slot_index):
			continue

		var amount_to_add: int = mini(
			remaining_amount,
			stack_limit
		)

		slots[slot_index] = {
			"item_id": item_id,
			"amount": amount_to_add
		}

		remaining_amount -= amount_to_add
		slot_changed.emit(slot_index)

		if remaining_amount <= 0:
			inventory_changed.emit()
			return 0

	inventory_changed.emit()

	if debug_inventory_logging and remaining_amount > 0:
		print(
			"[Inventory] No space for ",
			remaining_amount,
			" ",
			item_id
		)

	return remaining_amount

func spend_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true

	if not has_item(item_id, amount):
		return false

	var remaining_amount: int = amount

	for slot_index in range(slots.size()):
		var slot_data: Dictionary = slots[slot_index]

		if str(slot_data.get("item_id", "")) != item_id:
			continue

		var current_amount: int = int(slot_data.get("amount", 0))
		var amount_to_remove: int = mini(
			current_amount,
			remaining_amount
		)

		current_amount -= amount_to_remove
		remaining_amount -= amount_to_remove

		if current_amount <= 0:
			slots[slot_index] = _create_empty_slot()
		else:
			slot_data["amount"] = current_amount
			slots[slot_index] = slot_data

		slot_changed.emit(slot_index)

		if remaining_amount <= 0:
			inventory_changed.emit()
			return true

	return false

func move_or_merge_slot(
	source_slot_index: int,
	target_slot_index: int
) -> bool:
	if source_slot_index == target_slot_index:
		return false

	if source_slot_index < 0 or source_slot_index >= slots.size():
		return false

	if target_slot_index < 0 or target_slot_index >= slots.size():
		return false

	if is_slot_empty(source_slot_index):
		return false

	var source_slot: Dictionary = slots[source_slot_index]
	var target_slot: Dictionary = slots[target_slot_index]

	# Move into an empty slot.
	if str(target_slot.get("item_id", "")).is_empty():
		slots[target_slot_index] = source_slot
		slots[source_slot_index] = _create_empty_slot()

		slot_changed.emit(source_slot_index)
		slot_changed.emit(target_slot_index)
		inventory_changed.emit()

		return true

	var source_item_id: String = str(source_slot.get("item_id", ""))
	var target_item_id: String = str(target_slot.get("item_id", ""))

	# Merge matching item stacks.
	if source_item_id == target_item_id:
		var stack_limit: int = get_item_stack_limit(source_item_id)

		var source_amount: int = int(source_slot.get("amount", 0))
		var target_amount: int = int(target_slot.get("amount", 0))

		var available_space: int = stack_limit - target_amount

		if available_space <= 0:
			return false

		var amount_to_move: int = mini(
			source_amount,
			available_space
		)

		target_slot["amount"] = target_amount + amount_to_move
		source_amount -= amount_to_move

		if source_amount <= 0:
			slots[source_slot_index] = _create_empty_slot()
		else:
			source_slot["amount"] = source_amount
			slots[source_slot_index] = source_slot

		slots[target_slot_index] = target_slot

		slot_changed.emit(source_slot_index)
		slot_changed.emit(target_slot_index)
		inventory_changed.emit()

		return true

	# Swap different item types.
	slots[source_slot_index] = target_slot
	slots[target_slot_index] = source_slot

	slot_changed.emit(source_slot_index)
	slot_changed.emit(target_slot_index)
	inventory_changed.emit()

	return true

func get_page_count(slots_per_page: int) -> int:
	var safe_slots_per_page: int = maxi(slots_per_page, 1)

	return maxi(
		1,
		ceili(float(slots.size()) / float(safe_slots_per_page))
	)

func get_page_slots(
	page_index: int,
	slots_per_page: int
) -> Array[Dictionary]:
	var page_slots: Array[Dictionary] = []
	var safe_slots_per_page: int = maxi(slots_per_page, 1)

	var start_index: int = page_index * safe_slots_per_page
	var end_index: int = mini(
		start_index + safe_slots_per_page,
		slots.size()
	)

	for slot_index in range(start_index, end_index):
		page_slots.append(get_slot(slot_index))

	return page_slots
