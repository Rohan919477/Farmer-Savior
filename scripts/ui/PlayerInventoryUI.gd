extends CanvasLayer
class_name PlayerInventoryUI

const SLOTS_PER_PAGE: int = 16

@export var inventory_slot_scene: PackedScene

@onready var open_inventory_button: Button = (
	$RootControl/OpenInventoryButton
)

@onready var overlay: ColorRect = $RootControl/Overlay

@onready var inventory_panel: Panel = (
	$RootControl/InventoryPanel
)

@onready var close_button: Button = (
	$RootControl/InventoryPanel/CloseButton
)

@onready var player_info_label: Label = (
	$RootControl/InventoryPanel/PlayerInfoPanel/PlayerInfoLabel
)

@onready var selected_item_label: Label = (
	$RootControl/InventoryPanel/PlayerInfoPanel/SelectedItemLabel
)

@onready var previous_page_button: Button = (
	$RootControl/InventoryPanel/InventoryContentPanel/PreviousPageButton
)

@onready var page_label: Label = (
	$RootControl/InventoryPanel/InventoryContentPanel/PageLabel
)

@onready var next_page_button: Button = (
	$RootControl/InventoryPanel/InventoryContentPanel/NextPageButton
)

@onready var slot_grid: GridContainer = (
	$RootControl/InventoryPanel/InventoryContentPanel/SlotGrid
)

@onready var status_label: Label = (
	$RootControl/InventoryPanel/InventoryContentPanel/StatusLabel
)

var inventory_manager: InventoryManager = null
var player: Node = null

var inventory_open: bool = false
var current_page_index: int = 0
var selected_slot_index: int = -1

var slot_controls: Array[InventorySlotUI] = []

var stats_refresh_timer: float = 0.0

func _ready() -> void:
	add_to_group("player_inventory_ui")

	open_inventory_button.pressed.connect(open_inventory)
	close_button.pressed.connect(close_inventory)

	previous_page_button.pressed.connect(_on_previous_page_pressed)
	next_page_button.pressed.connect(_on_next_page_pressed)

	overlay.visible = false
	inventory_panel.visible = false

	call_deferred("_connect_systems")

func _process(delta: float) -> void:
	if not inventory_open:
		return

	stats_refresh_timer -= delta

	if stats_refresh_timer <= 0.0:
		stats_refresh_timer = 0.15
		refresh_player_information()
		
func is_workshop_open() -> bool:
	var workshop_ui: Node = get_tree().get_first_node_in_group(
		"workshop_ui"
	)

	if workshop_ui == null:
		return false

	if workshop_ui.has_method("is_workshop_open"):
		return bool(workshop_ui.call("is_workshop_open"))

	return false

func _unhandled_input(event: InputEvent) -> void:
	if is_workshop_open():
		return
		
	if event.is_action_pressed("inventory"):
		if inventory_open:
			close_inventory()
		else:
			open_inventory()

		get_viewport().set_input_as_handled()
		return

	if inventory_open and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()

func _connect_systems() -> void:
	await get_tree().process_frame

	inventory_manager = get_tree().get_first_node_in_group(
		"inventory_manager"
	) as InventoryManager

	player = get_tree().get_first_node_in_group("player")

	if inventory_manager == null:
		print("PlayerInventoryUI could not find InventoryManager.")
		return

	if not inventory_manager.inventory_changed.is_connected(
		_on_inventory_changed
	):
		inventory_manager.inventory_changed.connect(
			_on_inventory_changed
		)

	_build_slot_controls()
	refresh_inventory_view()

func is_inventory_open() -> bool:
	return inventory_open

func open_inventory() -> void:
	if inventory_manager == null:
		_connect_systems()

	if inventory_manager == null:
		return

	inventory_open = true
	selected_slot_index = -1
	status_label.text = "Select an occupied slot to begin."

	overlay.visible = true
	inventory_panel.visible = true
	open_inventory_button.visible = false

	refresh_inventory_view()

func close_inventory() -> void:
	inventory_open = false
	selected_slot_index = -1

	overlay.visible = false
	inventory_panel.visible = false
	open_inventory_button.visible = true

func _build_slot_controls() -> void:
	if inventory_slot_scene == null:
		print("PlayerInventoryUI is missing Inventory Slot Scene.")
		return

	for child in slot_grid.get_children():
		child.queue_free()

	slot_controls.clear()

	for _local_slot_index in range(SLOTS_PER_PAGE):
		var slot_control: InventorySlotUI = (
			inventory_slot_scene.instantiate() as InventorySlotUI
		)

		if slot_control == null:
			continue

		slot_grid.add_child(slot_control)

		slot_control.inventory_slot_pressed.connect(
			_on_inventory_slot_pressed
		)

		slot_controls.append(slot_control)

func refresh_inventory_view() -> void:
	if inventory_manager == null:
		return

	if slot_controls.is_empty():
		_build_slot_controls()

	var page_count: int = inventory_manager.get_page_count(
		SLOTS_PER_PAGE
	)

	current_page_index = clampi(
		current_page_index,
		0,
		page_count - 1
	)

	for local_slot_index in range(slot_controls.size()):
		var slot_control: InventorySlotUI = (
			slot_controls[local_slot_index]
		)

		var absolute_slot_index: int = (
			current_page_index * SLOTS_PER_PAGE
			+ local_slot_index
		)

		var slot_exists: bool = (
			absolute_slot_index < inventory_manager.get_slot_count()
		)

		var slot_data: Dictionary = {}

		if slot_exists:
			slot_data = inventory_manager.get_slot(
				absolute_slot_index
			)

		slot_control.configure_slot(
			absolute_slot_index,
			slot_data,
			slot_exists,
			absolute_slot_index == selected_slot_index
		)

	page_label.text = "Page %d / %d" % [
		current_page_index + 1,
		page_count
	]

	# Requirement: hide arrows at first/last page.
	previous_page_button.visible = current_page_index > 0
	next_page_button.visible = current_page_index < page_count - 1

	refresh_player_information()
	refresh_selected_item_information()

func refresh_player_information() -> void:
	if inventory_manager == null:
		return

	var current_health: int = 0
	var max_health: int = 0

	if player != null:
		current_health = int(player.get("current_health"))
		max_health = int(player.get("max_health"))

	var occupied_slots: int = 0

	for slot_index in range(inventory_manager.get_slot_count()):
		if not inventory_manager.is_slot_empty(slot_index):
			occupied_slots += 1

	player_info_label.text = (
		"PLAYER STATS\n\n"
		+ "Health: %d / %d\n\n"
		+ "RESOURCES\n"
		+ "Seeds: %d\n"
		+ "Scrap: %d\n"
		+ "Mutant Seeds: %d\n\n"
		+ "BACKPACK\n"
		+ "Slots Used: %d / %d"
	) % [
		current_health,
		max_health,
		inventory_manager.get_item_amount("seeds"),
		inventory_manager.get_item_amount("scrap"),
		inventory_manager.get_item_amount("mutant_seeds"),
		occupied_slots,
		inventory_manager.get_slot_count()
	]

func refresh_selected_item_information() -> void:
	if inventory_manager == null:
		return

	if selected_slot_index < 0:
		selected_item_label.text = (
			"ITEM DETAILS\n\n"
			+ "Select an item slot to view it here."
		)
		return

	var slot_data: Dictionary = inventory_manager.get_slot(
		selected_slot_index
	)

	var item_id: String = str(slot_data.get("item_id", ""))
	var amount: int = int(slot_data.get("amount", 0))

	if item_id.is_empty() or amount <= 0:
		selected_item_label.text = (
			"ITEM DETAILS\n\n"
			+ "No item selected."
		)
		return

	selected_item_label.text = (
		"ITEM DETAILS\n\n"
		+ "Item: %s\n"
		+ "Amount: %d\n"
		+ "Stack Limit: %d\n\n"
		+ "Choose another slot to move, merge, or swap."
	) % [
		get_item_display_name(item_id),
		amount,
		inventory_manager.get_item_stack_limit(item_id)
	]

func _on_inventory_slot_pressed(slot_index: int) -> void:
	if inventory_manager == null:
		return

	if selected_slot_index < 0:
		if inventory_manager.is_slot_empty(slot_index):
			status_label.text = "Select an occupied slot first."
			return

		selected_slot_index = slot_index

		var selected_data: Dictionary = inventory_manager.get_slot(
			slot_index
		)

		status_label.text = (
			"Selected %s."
			% get_item_display_name(
				str(selected_data.get("item_id", ""))
			)
		)

		refresh_inventory_view()
		return

	if selected_slot_index == slot_index:
		selected_slot_index = -1
		status_label.text = "Selection cancelled."

		refresh_inventory_view()
		return

	var moved_successfully: bool = inventory_manager.move_or_merge_slot(
		selected_slot_index,
		slot_index
	)

	if moved_successfully:
		selected_slot_index = -1
		status_label.text = "Item slots updated."
	else:
		status_label.text = (
			"Could not move that item. The target stack may be full."
		)

	refresh_inventory_view()

func _on_previous_page_pressed() -> void:
	if current_page_index <= 0:
		return

	current_page_index -= 1
	selected_slot_index = -1
	status_label.text = "Previous inventory page."

	refresh_inventory_view()

func _on_next_page_pressed() -> void:
	if inventory_manager == null:
		return

	var page_count: int = inventory_manager.get_page_count(
		SLOTS_PER_PAGE
	)

	if current_page_index >= page_count - 1:
		return

	current_page_index += 1
	selected_slot_index = -1
	status_label.text = "Next inventory page."

	refresh_inventory_view()

func _on_inventory_changed() -> void:
	if inventory_open:
		refresh_inventory_view()

func get_item_display_name(item_id: String) -> String:
	match item_id:
		"seeds":
			return "Seed"
		"scrap":
			return "Scrap"
		"mutant_seeds":
			return "Mutant Seed"
		_:
			return item_id.capitalize()
