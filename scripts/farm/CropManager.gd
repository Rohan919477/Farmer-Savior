extends Node
class_name CropManager

signal crop_data_changed
signal crop_slot_clicked(grid_cell: Vector2i)
signal crop_growth_updated(day_number: int)

signal planting_menu_requested(grid_cell: Vector2i)
signal planting_menu_closed
signal planting_result(success: bool, message: String)

signal crop_planted(crop_id: String, grid_cell: Vector2i)

signal crop_harvested(
	crop_id: String,
	grid_cell: Vector2i,
	resource_type: String,
	amount: int
)

signal mutant_crop_reward_unlocked(reward_name: String)

signal crop_inspection_requested(grid_cell: Vector2i)
signal crop_removed(crop_id: String, grid_cell: Vector2i)

const CROP_STATE_EMPTY: String = "empty"
const CROP_STATE_GROWING: String = "growing"
const CROP_STATE_READY: String = "ready"

const BASIC_CROP_ID: String = "basic_crop"
const MUTANT_CROP_ID: String = "mutant_crop"

@export var crop_plot_slot_scene: PackedScene

# Temporary Week 8 values. These become Workshop/data-driven later.
@export var basic_crop_seed_cost: int = 1
@export var basic_crop_growth_days: int = 1
@export var basic_crop_harvest_amount: int = 2

@export var mutant_crop_mutant_seed_cost: int = 1
@export var mutant_crop_growth_days: int = 1
@export var mutant_crop_harvest_amount: int = 4
@export var mutant_growth_basic_crop_bonus: int = 1

var defense_manager: DefenseManager = null
var map_manager: Node = null
var time_manager: Node = null

var active_farm_map: Node = null
var planted_crops: Dictionary = {}
var mutant_growth_reward_unlocked: bool = false

var pending_plant_grid_cell: Vector2i = Vector2i(-1, -1)
var planting_menu_open: bool = false

# Prevents the original world click from firing a pistol shot.
var capture_crop_click_until_release: bool = false

func _ready() -> void:
	add_to_group("crop_manager")

	defense_manager = (
		get_parent().get_node_or_null("DefenseManager")
		as DefenseManager
	)

	map_manager = get_parent().get_node_or_null("MapManager")
	time_manager = get_parent().get_node_or_null("TimeManager")

	if map_manager != null and map_manager.has_signal("location_loaded"):
		map_manager.location_loaded.connect(_on_location_loaded)

	if time_manager != null and time_manager.has_signal("day_started"):
		time_manager.day_started.connect(_on_day_started)

	call_deferred("_bind_initial_farm_map")

func _process(_delta: float) -> void:
	if (
		capture_crop_click_until_release
		and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	):
		capture_crop_click_until_release = false

func _bind_initial_farm_map() -> void:
	await get_tree().process_frame

	if active_farm_map != null and is_instance_valid(active_farm_map):
		return

	var farm_map: Node = get_tree().get_first_node_in_group("farm_map")

	if farm_map == null:
		return

	active_farm_map = farm_map
	rebuild_crop_slots()

func _on_location_loaded(location_id: String, loaded_map: Node) -> void:
	if location_id == "farm":
		active_farm_map = loaded_map
		rebuild_crop_slots()
	else:
		active_farm_map = null

func _on_day_started(day_number: int) -> void:
	crop_growth_updated.emit(day_number)
	crop_data_changed.emit()

func is_capturing_crop_click() -> bool:
	return capture_crop_click_until_release

func is_planting_menu_open() -> bool:
	return planting_menu_open

func get_crop_key(grid_cell: Vector2i) -> String:
	return "%d:%d" % [grid_cell.x, grid_cell.y]

func is_crop_plot_cell(grid_cell: Vector2i) -> bool:
	if defense_manager == null:
		return false

	return defense_manager.get_cell_type(grid_cell) == "farmland"

func get_crop_plot_cells() -> Array[Vector2i]:
	var crop_cells: Array[Vector2i] = []

	if defense_manager == null:
		return crop_cells

	for row_index in range(defense_manager.grid_rows):
		for column_index in range(defense_manager.grid_columns):
			var grid_cell: Vector2i = Vector2i(
				column_index,
				row_index
			)

			if is_crop_plot_cell(grid_cell):
				crop_cells.append(grid_cell)

	return crop_cells

func get_crop_world_position(grid_cell: Vector2i) -> Vector2:
	if defense_manager == null:
		return Vector2.ZERO

	return defense_manager.get_turret_position(grid_cell)

func has_crop(grid_cell: Vector2i) -> bool:
	return planted_crops.has(get_crop_key(grid_cell))

func get_crop_data(grid_cell: Vector2i) -> Dictionary:
	var crop_key: String = get_crop_key(grid_cell)

	if not planted_crops.has(crop_key):
		return {}

	var crop_data: Dictionary = planted_crops[crop_key]
	return crop_data.duplicate(true)

func get_crop_state(grid_cell: Vector2i) -> String:
	if not has_crop(grid_cell):
		return CROP_STATE_EMPTY

	var crop_data: Dictionary = get_crop_data(grid_cell)

	var planted_day: int = int(crop_data.get("planted_day", 0))
	var growth_days: int = int(crop_data.get("growth_days", 1))

	if get_current_day_number() - planted_day >= growth_days:
		return CROP_STATE_READY

	return CROP_STATE_GROWING

func get_crop_hover_text(grid_cell: Vector2i) -> String:
	var crop_state: String = get_crop_state(grid_cell)

	if crop_state == CROP_STATE_EMPTY:
		return "Empty Plot\nClick to plant"

	var crop_data: Dictionary = get_crop_data(grid_cell)

	var crop_name: String = str(
		crop_data.get("display_name", "Crop")
	)

	if crop_state == CROP_STATE_READY:
		return "%s\nREADY\nClick to harvest" % crop_name

	var planted_day: int = int(crop_data.get("planted_day", 0))
	var growth_days: int = int(crop_data.get("growth_days", 1))

	var days_left: int = maxi(
		0,
		growth_days - (get_current_day_number() - planted_day)
	)

	return "%s\n%d day(s) left\nUNRIPE" % [
		crop_name,
		days_left
	]
	
func get_crop_display_name(grid_cell: Vector2i) -> String:
	var crop_data: Dictionary = get_crop_data(grid_cell)

	if crop_data.is_empty():
		return "Empty Plot"

	return str(crop_data.get("display_name", "Crop"))

func get_crop_remaining_days(grid_cell: Vector2i) -> int:
	if not has_crop(grid_cell):
		return 0

	var crop_data: Dictionary = get_crop_data(grid_cell)

	var planted_day: int = int(crop_data.get("planted_day", 0))
	var growth_days: int = int(crop_data.get("growth_days", 1))

	return maxi(
		0,
		growth_days - (get_current_day_number() - planted_day)
	)

func remove_crop_without_harvest(grid_cell: Vector2i) -> bool:
	if not has_crop(grid_cell):
		planting_result.emit(false, "There is no crop to remove.")
		return false

	if get_crop_state(grid_cell) == CROP_STATE_READY:
		planting_result.emit(
			false,
			"Ready crops should be harvested, not removed."
		)
		return false

	var crop_key: String = get_crop_key(grid_cell)
	var crop_data: Dictionary = get_crop_data(grid_cell)

	var crop_id: String = str(
		crop_data.get("crop_id", "unknown_crop")
	)

	planted_crops.erase(crop_key)

	planting_menu_open = false
	pending_plant_grid_cell = Vector2i(-1, -1)

	print(
		"[Crop] Removed ",
		crop_id,
		" at ",
		grid_cell,
		" without refund or harvest."
	)

	crop_data_changed.emit()
	crop_removed.emit(crop_id, grid_cell)
	planting_result.emit(true, "Crop removed.")
	planting_menu_closed.emit()

	return true

func request_crop_slot_interaction(grid_cell: Vector2i) -> void:
	capture_crop_click_until_release = true

	if not is_daytime():
		print("[Crop] Planting and harvesting are available only during daytime.")
		return

	var crop_state: String = get_crop_state(grid_cell)

	match crop_state:
		CROP_STATE_EMPTY:
			if planting_menu_open:
				print("[Crop] Planting menu is already open.")
				return

			pending_plant_grid_cell = grid_cell
			planting_menu_open = true

			crop_slot_clicked.emit(grid_cell)
			planting_menu_requested.emit(grid_cell)

		CROP_STATE_GROWING:
			if planting_menu_open:
				return

			pending_plant_grid_cell = grid_cell
			planting_menu_open = true

			crop_slot_clicked.emit(grid_cell)
			crop_inspection_requested.emit(grid_cell)

		CROP_STATE_READY:
			harvest_ready_crop(grid_cell)

func confirm_plant_basic_crop() -> bool:
	if not planting_menu_open:
		planting_result.emit(false, "No crop plot is selected.")
		return false

	if not is_daytime():
		planting_result.emit(
			false,
			"Planting is available only during daytime."
		)
		return false

	var grid_cell: Vector2i = pending_plant_grid_cell

	if not is_crop_plot_cell(grid_cell) or has_crop(grid_cell):
		planting_result.emit(false, "That plot is no longer available.")
		return false

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null or not player_node.has_method("spend_resource"):
		planting_result.emit(false, "Player resource data is unavailable.")
		return false

	var spent_successfully: bool = bool(
		player_node.call(
			"spend_resource",
			"seeds",
			basic_crop_seed_cost
		)
	)

	if not spent_successfully:
		planting_result.emit(
			false,
			"Need %d Seed(s)." % basic_crop_seed_cost
		)
		return false

	if not plant_basic_crop(grid_cell):
		planting_result.emit(false, "Crop could not be planted.")
		return false

	planting_menu_open = false
	pending_plant_grid_cell = Vector2i(-1, -1)

	planting_result.emit(true, "Basic Crop planted.")
	planting_menu_closed.emit()

	return true

func confirm_plant_mutant_crop() -> bool:
	if not planting_menu_open:
		planting_result.emit(false, "No crop plot is selected.")
		return false

	if not is_daytime():
		planting_result.emit(
			false,
			"Planting is available only during daytime."
		)
		return false

	var grid_cell: Vector2i = pending_plant_grid_cell

	if not is_crop_plot_cell(grid_cell) or has_crop(grid_cell):
		planting_result.emit(false, "That plot is no longer available.")
		return false

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null or not player_node.has_method("spend_resource"):
		planting_result.emit(false, "Player resource data is unavailable.")
		return false

	var spent_successfully: bool = bool(
		player_node.call(
			"spend_resource",
			"mutant_seeds",
			mutant_crop_mutant_seed_cost
		)
	)

	if not spent_successfully:
		planting_result.emit(
			false,
			"Need %d Mutant Seed(s)."
			% mutant_crop_mutant_seed_cost
		)
		return false

	if not plant_mutant_crop(grid_cell):
		if player_node.has_method("add_resource"):
			player_node.call(
				"add_resource",
				"mutant_seeds",
				mutant_crop_mutant_seed_cost
			)

		planting_result.emit(false, "Mutant Crop could not be planted.")
		return false

	_unlock_mutant_crop_reward()

	planting_menu_open = false
	pending_plant_grid_cell = Vector2i(-1, -1)

	planting_result.emit(
		true,
		"Mutant Crop planted. Mutant Compost unlocked."
	)

	planting_menu_closed.emit()

	return true

func plant_mutant_crop(grid_cell: Vector2i) -> bool:
	if not is_crop_plot_cell(grid_cell):
		return false

	if has_crop(grid_cell):
		return false

	if not is_daytime():
		return false

	var crop_key: String = get_crop_key(grid_cell)

	planted_crops[crop_key] = {
		"crop_id": MUTANT_CROP_ID,
		"display_name": "Mutant Crop",
		"planted_day": get_current_day_number(),
		"growth_days": mutant_crop_growth_days,
		"harvest_amount": mutant_crop_harvest_amount,
		"harvest_resource_type": "seeds"
	}

	print(
		"[Crop] Mutant Crop planted at ",
		grid_cell,
		". Mutant Compost reward available."
	)

	crop_data_changed.emit()
	crop_planted.emit(MUTANT_CROP_ID, grid_cell)

	return true

func _unlock_mutant_crop_reward() -> void:
	if mutant_growth_reward_unlocked:
		return

	mutant_growth_reward_unlocked = true

	print(
		"[Mutant Reward] Mutant Compost unlocked. "
		+ "Basic Crops now harvest +",
		mutant_growth_basic_crop_bonus,
		" Seed(s)."
	)

	mutant_crop_reward_unlocked.emit("Mutant Compost")
	crop_data_changed.emit()

func cancel_planting_menu() -> void:
	if not planting_menu_open:
		return

	planting_menu_open = false
	pending_plant_grid_cell = Vector2i(-1, -1)

	planting_menu_closed.emit()

func plant_basic_crop(grid_cell: Vector2i) -> bool:
	if not is_crop_plot_cell(grid_cell):
		return false

	if has_crop(grid_cell):
		return false

	if not is_daytime():
		return false

	var crop_key: String = get_crop_key(grid_cell)

	planted_crops[crop_key] = {
		"crop_id": BASIC_CROP_ID,
		"display_name": "Basic Crop",
		"planted_day": get_current_day_number(),
		"growth_days": basic_crop_growth_days,
		"harvest_amount": basic_crop_harvest_amount,
		"harvest_resource_type": "seeds"
	}

	print(
		"[Crop] Basic Crop planted at ",
		grid_cell,
		". Ready after ",
		basic_crop_growth_days,
		" in-game day(s)."
	)

	crop_data_changed.emit()
	crop_planted.emit(BASIC_CROP_ID, grid_cell)

	return true

func harvest_ready_crop(grid_cell: Vector2i) -> void:
	var crop_data: Dictionary = harvest_crop(grid_cell)

	if crop_data.is_empty():
		return

	var crop_id: String = str(
		crop_data.get("crop_id", BASIC_CROP_ID)
	)

	var harvest_amount: int = int(
		crop_data.get("harvest_amount", 0)
	)

	if crop_id == BASIC_CROP_ID:
		harvest_amount = get_effective_basic_crop_harvest_amount()

	var resource_type: String = str(
		crop_data.get("harvest_resource_type", "seeds")
	)

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node != null and player_node.has_method("add_resource"):
		player_node.call(
			"add_resource",
			resource_type,
			harvest_amount
		)

	print(
		"[Crop] Harvested ",
		harvest_amount,
		" ",
		resource_type,
		" from ",
		grid_cell
	)

	crop_harvested.emit(
		crop_id,
		grid_cell,
		resource_type,
		harvest_amount
	)

func harvest_crop(grid_cell: Vector2i) -> Dictionary:
	if get_crop_state(grid_cell) != CROP_STATE_READY:
		return {}

	var crop_key: String = get_crop_key(grid_cell)
	var crop_data: Dictionary = get_crop_data(grid_cell)

	planted_crops.erase(crop_key)
	crop_data_changed.emit()

	return crop_data

func get_available_seed_count() -> int:
	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return 0

	if player_node.has_method("get_resource_amount"):
		return int(player_node.call("get_resource_amount", "seeds"))

	return 0

func get_available_mutant_seed_count() -> int:
	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return 0

	if player_node.has_method("get_resource_amount"):
		return int(
			player_node.call("get_resource_amount", "mutant_seeds")
		)

	return 0

func is_mutant_crop_reward_unlocked() -> bool:
	return mutant_growth_reward_unlocked

func get_effective_basic_crop_harvest_amount() -> int:
	var harvest_amount: int = basic_crop_harvest_amount

	if mutant_growth_reward_unlocked:
		harvest_amount += mutant_growth_basic_crop_bonus

	return harvest_amount

func get_current_day_number() -> int:
	if time_manager == null:
		return 1

	if time_manager.has_method("get_day_number"):
		return int(time_manager.call("get_day_number"))

	return 1

func is_daytime() -> bool:
	if time_manager == null:
		return true

	if time_manager.has_method("is_nighttime"):
		return not bool(time_manager.call("is_nighttime"))

	return true

func rebuild_crop_slots() -> void:
	if active_farm_map == null:
		return

	if crop_plot_slot_scene == null:
		print("Crop Plot Slot Scene is not assigned.")
		return

	var crop_root: Node2D = (
		active_farm_map.get_node_or_null("CropPlacementRoot")
		as Node2D
	)

	if crop_root == null:
		print("Farm map is missing CropPlacementRoot.")
		return

	for child in crop_root.get_children():
		child.queue_free()

	for grid_cell in get_crop_plot_cells():
		var crop_slot: Node2D = (
			crop_plot_slot_scene.instantiate() as Node2D
		)

		if crop_slot == null:
			continue

		crop_slot.position = get_crop_world_position(grid_cell)
		crop_root.add_child(crop_slot)

		if crop_slot.has_method("configure_slot"):
			crop_slot.call("configure_slot", self, grid_cell)
