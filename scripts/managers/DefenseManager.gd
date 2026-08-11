extends Node
class_name DefenseManager

signal inventory_changed(pesticide_turrets_available: int)
signal turret_placed(grid_cell: Vector2i)
signal placement_failed(reason: String)
signal turret_removed(grid_cell: Vector2i)
signal turret_condition_changed(turret_key: String, turret_state: String)
signal turret_repair_queue_changed(broken_turrets_in_queue: int)

signal fence_inventory_changed(fences_available: int)
signal fence_placed(fence_key: String)
signal fence_removed(fence_key: String)
signal fence_state_changed(fence_key: String, fence_state: String)
signal fence_repair_queue_changed(broken_fences_in_queue: int)
signal fence_crafted(fences_available: int)
signal fence_workshop_action_failed(reason: String)
signal fence_navigation_changed
signal fence_stats_changed

signal nightlight_inventory_changed(nightlights_available: int)
signal nightlight_placed(grid_cell: Vector2i)
signal nightlight_removed(grid_cell: Vector2i)
signal nightlight_condition_changed(nightlight_key: String, nightlight_state: String)
signal nightlight_repair_queue_changed(broken_nightlights_in_queue: int)

const FENCE_ORIENTATION_HORIZONTAL: String = "horizontal"
const FENCE_ORIENTATION_VERTICAL: String = "vertical"

const FENCE_STATE_PERFECT: String = "perfect"
const FENCE_STATE_DAMAGED: String = "damaged"
const FENCE_STATE_BROKEN: String = "broken"

const PLACEABLE_STATE_PERFECT: String = "perfect"
const PLACEABLE_STATE_DAMAGED: String = "damaged"
const PLACEABLE_STATE_BROKEN: String = "broken"

@export var pesticide_turret_scene: PackedScene
@export var fence_segment_scene: PackedScene
@export var nightlight_scene: PackedScene

# Expanded farm map: 1792 × 1280 world units.
# 56 × 40 cells at 32 × 32 gives more room for combat, farming, and defences.
@export var grid_columns: int = 56
@export var grid_rows: int = 40

@export var farm_grid_origin: Vector2 = Vector2(-896.0, -640.0)
@export var farm_grid_cell_size: Vector2 = Vector2(32.0, 32.0)

@export var max_pesticide_turrets: int = 2
@export var pesticide_turret_max_integrity: float = 100.0
@export var pesticide_turret_max_durability: float = 100.0
@export var damaged_pesticide_turret_repair_cost_scrap: int = 1
@export var pesticide_turret_repair_rate_per_second: float = 20.0

# War Table starting inventory.
@export var starting_fences: int = 12
@export var starting_nightlights: int = 8
@export var nightlight_max_integrity: float = 100.0
@export var nightlight_wear_per_second: float = 0.20
@export var damaged_nightlight_repair_cost_scrap: int = 1
@export var nightlight_repair_rate_per_second: float = 20.0
@export var fence_max_health: float = 100.0
@export var create_starting_perimeter_fence: bool = true

# Workshop-upgrade values later.
@export var damaged_fence_repair_cost_scrap: int = 1
@export var fence_repair_rate_per_second: float = 25.0
@export var fence_damage_multiplier: float = 1.0

# Used by the Fence Workshop crafting section later this week.
@export var fence_craft_scrap_cost: int = 3
@export var fence_craft_seed_cost: int = 2
@export var broken_fence_repair_scrap_cost: int = 3
@export var broken_nightlight_repair_scrap_cost: int = 2

@export var minimum_broken_segments_for_passable_gap: int = 2
@export var debug_fence_logging: bool = true

var pesticide_turrets_available: int = 2
var fences_available: int = 12
var nightlights_available: int = 8

# Example:
# {
#     "10:5": {
#         "grid_cell": Vector2i(10, 5),
#         "current_integrity": 100.0,
#         "current_durability": 100.0,
#         "repair_cost_paid": false
#     }
# }
var placed_turrets: Dictionary = {}

# Example:
# {
#     "10:5": {
#         "grid_cell": Vector2i(10, 5),
#         "current_integrity": 100.0
#     }
# }
var placed_nightlights: Dictionary = {}

var broken_pesticide_turrets_in_repair_queue: int = 0
var broken_nightlights_in_repair_queue: int = 0

# Example:
# {
#     "horizontal:10:5": {
#         "orientation": "horizontal",
#         "grid_edge": Vector2i(10, 5),
#         "current_health": 100.0,
#         "repair_cost_paid": false,
#         "is_perimeter_fence": false
#     }
# }
var placed_fences: Dictionary = {}

var broken_fences_in_repair_queue: int = 0
var active_farm_map: Node = null

var base_max_pesticide_turrets: int = 2
var base_pesticide_turret_max_integrity: float = 100.0
var base_pesticide_turret_max_durability: float = 100.0
var base_damaged_pesticide_turret_repair_cost_scrap: int = 1
var base_pesticide_turret_repair_rate_per_second: float = 20.0
var base_starting_fences: int = 12
var base_starting_nightlights: int = 8
var base_nightlight_max_integrity: float = 100.0
var base_nightlight_wear_per_second: float = 0.20
var base_damaged_nightlight_repair_cost_scrap: int = 1
var base_nightlight_repair_rate_per_second: float = 20.0
var base_broken_nightlight_repair_scrap_cost: int = 2
var base_fence_max_health: float = 100.0
var base_fence_repair_rate_per_second: float = 25.0
var base_fence_damage_multiplier: float = 1.0

func _ready() -> void:
	add_to_group("defense_manager")

	base_max_pesticide_turrets = max_pesticide_turrets
	base_pesticide_turret_max_integrity = pesticide_turret_max_integrity
	base_pesticide_turret_max_durability = pesticide_turret_max_durability
	base_damaged_pesticide_turret_repair_cost_scrap = (
		damaged_pesticide_turret_repair_cost_scrap
	)
	base_pesticide_turret_repair_rate_per_second = (
		pesticide_turret_repair_rate_per_second
	)
	base_starting_fences = starting_fences
	base_starting_nightlights = starting_nightlights
	base_nightlight_max_integrity = nightlight_max_integrity
	base_nightlight_wear_per_second = nightlight_wear_per_second
	base_damaged_nightlight_repair_cost_scrap = damaged_nightlight_repair_cost_scrap
	base_nightlight_repair_rate_per_second = nightlight_repair_rate_per_second
	base_broken_nightlight_repair_scrap_cost = broken_nightlight_repair_scrap_cost
	base_fence_max_health = fence_max_health
	base_fence_repair_rate_per_second = fence_repair_rate_per_second
	base_fence_damage_multiplier = fence_damage_multiplier

	pesticide_turrets_available = max_pesticide_turrets
	fences_available = starting_fences
	nightlights_available = starting_nightlights

	_create_starting_perimeter_fences()

	var map_manager: Node = get_parent().get_node_or_null("MapManager")

	if map_manager != null and map_manager.has_signal("location_loaded"):
		map_manager.connect(
			"location_loaded",
			Callable(self, "_on_location_loaded")
		)

	call_deferred("_bind_initial_farm_map")

func _process(delta: float) -> void:
	_process_nightlight_wear(delta)

func _bind_initial_farm_map() -> void:
	await get_tree().process_frame

	if active_farm_map != null and is_instance_valid(active_farm_map):
		return

	var farm_map: Node = get_tree().get_first_node_in_group("farm_map")

	if farm_map == null:
		return

	active_farm_map = farm_map

	rebuild_farm_turrets()
	rebuild_farm_fences()
	rebuild_farm_nightlights()

# -------------------------------------------------------------------
# Starting perimeter fences
# -------------------------------------------------------------------

func _create_starting_perimeter_fences() -> void:
	if not create_starting_perimeter_fence:
		return

	# Important later for save/load: do not overwrite restored fence data.
	if not placed_fences.is_empty():
		return

	for column_index in range(grid_columns):
		_add_starting_perimeter_fence(
			FENCE_ORIENTATION_HORIZONTAL,
			Vector2i(column_index, 0)
		)

		_add_starting_perimeter_fence(
			FENCE_ORIENTATION_HORIZONTAL,
			Vector2i(column_index, grid_rows)
		)

	for row_index in range(grid_rows):
		_add_starting_perimeter_fence(
			FENCE_ORIENTATION_VERTICAL,
			Vector2i(0, row_index)
		)

		_add_starting_perimeter_fence(
			FENCE_ORIENTATION_VERTICAL,
			Vector2i(grid_columns, row_index)
		)

func _add_starting_perimeter_fence(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if not is_valid_fence_edge(orientation, grid_edge):
		return

	var fence_key: String = get_fence_key(orientation, grid_edge)

	placed_fences[fence_key] = {
		"orientation": orientation,
		"grid_edge": grid_edge,
		"current_health": fence_max_health,
		"repair_cost_paid": false,
		"is_perimeter_fence": true
	}

# -------------------------------------------------------------------
# Grid helpers
# -------------------------------------------------------------------

func get_grid_columns() -> int:
	return grid_columns

func get_grid_rows() -> int:
	return grid_rows

func is_inside_grid(grid_cell: Vector2i) -> bool:
	return (
		grid_cell.x >= 0
		and grid_cell.x < grid_columns
		and grid_cell.y >= 0
		and grid_cell.y < grid_rows
	)

func is_boundary_cell(grid_cell: Vector2i) -> bool:
	return (
		grid_cell.x == 0
		or grid_cell.x == grid_columns - 1
		or grid_cell.y == 0
		or grid_cell.y == grid_rows - 1
	)

func get_cell_type(grid_cell: Vector2i) -> String:
	if not is_inside_grid(grid_cell):
		return "outside"

	if is_boundary_cell(grid_cell):
		return "boundary"

	# Farmhouse zone. Keep it unavailable for defence placement.
	if is_cell_in_range(grid_cell, 5, 15, 4, 12):
		return "house"

	# Truck zone. Keep it unavailable for defence placement.
	if is_cell_in_range(grid_cell, 42, 50, 4, 9):
		return "truck"

	# Larger crop/farmland zone near the lower centre of the farm.
	if is_cell_in_range(grid_cell, 18, 37, 28, 36):
		return "farmland"

	return "open"

func is_cell_in_range(
	grid_cell: Vector2i,
	minimum_x: int,
	maximum_x: int,
	minimum_y: int,
	maximum_y: int
) -> bool:
	return (
		grid_cell.x >= minimum_x
		and grid_cell.x <= maximum_x
		and grid_cell.y >= minimum_y
		and grid_cell.y <= maximum_y
	)

# -------------------------------------------------------------------
# Pesticide Turrets
# -------------------------------------------------------------------

func get_pesticide_turrets_available() -> int:
	return pesticide_turrets_available

func get_turret_key(grid_cell: Vector2i) -> String:
	return "%d:%d" % [grid_cell.x, grid_cell.y]

func has_turret(grid_cell: Vector2i) -> bool:
	return placed_turrets.has(get_turret_key(grid_cell))

func is_cell_occupied(grid_cell: Vector2i) -> bool:
	return has_turret(grid_cell) or has_nightlight(grid_cell)

func get_turret_data(turret_key: String) -> Dictionary:
	if not placed_turrets.has(turret_key):
		return {}

	var turret_data: Dictionary = placed_turrets[turret_key]
	return turret_data.duplicate(true)
	
func get_pesticide_turret_current_integrity(turret_key: String) -> float:
	var turret_data: Dictionary = get_turret_data(turret_key)

	if turret_data.is_empty():
		return 0.0

	return clampf(
		float(
			turret_data.get(
				"current_integrity",
				pesticide_turret_max_integrity
			)
		),
		0.0,
		pesticide_turret_max_integrity
	)


func get_pesticide_turret_integrity_percent(turret_key: String) -> float:
	if pesticide_turret_max_integrity <= 0.0:
		return 0.0

	return clampf(
		get_pesticide_turret_current_integrity(turret_key)
		/ pesticide_turret_max_integrity,
		0.0,
		1.0
	)

func get_pesticide_turret_current_durability(turret_key: String) -> float:
	var turret_data: Dictionary = get_turret_data(turret_key)

	if turret_data.is_empty():
		return 0.0

	return clampf(
		float(
			turret_data.get(
				"current_durability",
				pesticide_turret_max_durability
			)
		),
		0.0,
		pesticide_turret_max_durability
	)


func get_pesticide_turret_durability_percent(turret_key: String) -> float:
	if pesticide_turret_max_durability <= 0.0:
		return 0.0

	return clampf(
		get_pesticide_turret_current_durability(turret_key)
		/ pesticide_turret_max_durability,
		0.0,
		1.0
	)


func get_damaged_pesticide_turret_repair_cost_scrap() -> int:
	return maxi(0, damaged_pesticide_turret_repair_cost_scrap)


func get_pesticide_turret_repair_rate_per_second() -> float:
	return maxf(0.0, pesticide_turret_repair_rate_per_second)


func is_pesticide_turret_repair_cost_paid(turret_key: String) -> bool:
	var turret_data: Dictionary = get_turret_data(turret_key)

	if turret_data.is_empty():
		return false

	return bool(turret_data.get("repair_cost_paid", false))


func mark_pesticide_turret_repair_cost_paid(turret_key: String) -> void:
	if not placed_turrets.has(turret_key):
		return

	var turret_data: Dictionary = placed_turrets[turret_key]
	turret_data["repair_cost_paid"] = true
	placed_turrets[turret_key] = turret_data


func repair_pesticide_turret(
	turret_key: String,
	repair_amount: float
) -> void:
	if repair_amount <= 0.0:
		return

	if not placed_turrets.has(turret_key):
		return

	if get_turret_state(turret_key) == PLACEABLE_STATE_BROKEN:
		return

	var old_state: String = get_turret_state(turret_key)
	var turret_data: Dictionary = placed_turrets[turret_key]

	var current_integrity: float = float(
		turret_data.get(
			"current_integrity",
			pesticide_turret_max_integrity
		)
	)

	var current_durability: float = float(
		turret_data.get(
			"current_durability",
			pesticide_turret_max_durability
		)
	)

	var new_integrity: float = clampf(
		current_integrity + repair_amount,
		0.0,
		pesticide_turret_max_integrity
	)

	var new_durability: float = clampf(
		current_durability + repair_amount,
		0.0,
		pesticide_turret_max_durability
	)

	turret_data["current_integrity"] = new_integrity
	turret_data["current_durability"] = new_durability

	if (
		new_integrity >= pesticide_turret_max_integrity
		and new_durability >= pesticide_turret_max_durability
	):
		turret_data["repair_cost_paid"] = false

	placed_turrets[turret_key] = turret_data

	var new_state: String = get_turret_state(turret_key)

	turret_condition_changed.emit(turret_key, new_state)

	if (
		old_state == PLACEABLE_STATE_DAMAGED
		and new_state == PLACEABLE_STATE_PERFECT
	):
		_log_telemetry("pesticide_turret_field_repaired", {
			"turret_key": turret_key,
			"repair_type": "field_repair",
			"repair_amount": repair_amount,
			"current_integrity": new_integrity,
			"current_durability": new_durability,
			"max_integrity": pesticide_turret_max_integrity,
			"max_durability": pesticide_turret_max_durability
		})


func get_turret_state(turret_key: String) -> String:
	var turret_data: Dictionary = get_turret_data(turret_key)

	if turret_data.is_empty():
		return PLACEABLE_STATE_BROKEN

	var current_integrity: float = float(
		turret_data.get("current_integrity", 0.0)
	)

	var current_durability: float = float(
		turret_data.get("current_durability", 0.0)
	)

	if current_integrity <= 0.0 or current_durability <= 0.0:
		return PLACEABLE_STATE_BROKEN

	if (
		current_integrity < pesticide_turret_max_integrity
		or current_durability < pesticide_turret_max_durability
	):
		return PLACEABLE_STATE_DAMAGED

	return PLACEABLE_STATE_PERFECT

func get_broken_pesticide_turrets_in_repair_queue() -> int:
	return broken_pesticide_turrets_in_repair_queue

func can_place_pesticide_turret(grid_cell: Vector2i) -> bool:
	if pesticide_turrets_available <= 0:
		return false

	if get_cell_type(grid_cell) != "open":
		return false

	if is_cell_occupied(grid_cell):
		return false

	return true

func get_placement_failure_reason(grid_cell: Vector2i) -> String:
	if pesticide_turrets_available <= 0:
		return "No Pesticide Turrets are available."

	var cell_type: String = get_cell_type(grid_cell)

	if cell_type == "outside":
		return "Choose a cell within the farm boundary."

	if cell_type == "boundary":
		return "Turrets cannot be placed on the outer boundary."

	if cell_type == "house":
		return "Turrets cannot be placed on the house."

	if cell_type == "truck":
		return "Turrets cannot be placed on the truck."

	if cell_type == "farmland":
		return "Turrets cannot be placed on farmland."

	if is_cell_occupied(grid_cell):
		return "A turret is already placed there."

	return "This location cannot be used."

func place_pesticide_turret(grid_cell: Vector2i) -> bool:
	if not can_place_pesticide_turret(grid_cell):
		placement_failed.emit(get_placement_failure_reason(grid_cell))
		return false

	var turret_key: String = get_turret_key(grid_cell)

	placed_turrets[turret_key] = {
		"grid_cell": grid_cell,
		"current_integrity": pesticide_turret_max_integrity,
		"current_durability": pesticide_turret_max_durability,
		"repair_cost_paid": false
	}

	pesticide_turrets_available -= 1

	inventory_changed.emit(pesticide_turrets_available)
	turret_placed.emit(grid_cell)

	_log_telemetry("turret_placed", {
		"grid_x": grid_cell.x,
		"grid_y": grid_cell.y,
		"turrets_available": pesticide_turrets_available
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()

	return true

func get_turret_position(grid_cell: Vector2i) -> Vector2:
	var offset_x: float = (
		(float(grid_cell.x) + 0.5) * farm_grid_cell_size.x
	)

	var offset_y: float = (
		(float(grid_cell.y) + 0.5) * farm_grid_cell_size.y
	)

	return farm_grid_origin + Vector2(offset_x, offset_y)

func has_placed_turrets() -> bool:
	return not placed_turrets.is_empty()

func can_remove_turret(grid_cell: Vector2i) -> bool:
	if not has_turret(grid_cell):
		return false

	var turret_key: String = get_turret_key(grid_cell)
	var turret_state: String = get_turret_state(turret_key)

	return (
		turret_state == PLACEABLE_STATE_PERFECT
		or turret_state == PLACEABLE_STATE_BROKEN
	)

func remove_pesticide_turret(grid_cell: Vector2i) -> bool:
	if not has_turret(grid_cell):
		placement_failed.emit("There is no turret placed on this grid cell.")
		return false

	var turret_key: String = get_turret_key(grid_cell)
	var turret_state: String = get_turret_state(turret_key)

	if turret_state == PLACEABLE_STATE_DAMAGED:
		placement_failed.emit(
			"Damaged Pesticide Turrets must be repaired before removal."
		)
		return false

	placed_turrets.erase(turret_key)

	if turret_state == PLACEABLE_STATE_PERFECT:
		pesticide_turrets_available += 1
		inventory_changed.emit(pesticide_turrets_available)

	elif turret_state == PLACEABLE_STATE_BROKEN:
		broken_pesticide_turrets_in_repair_queue += 1

		turret_repair_queue_changed.emit(
			broken_pesticide_turrets_in_repair_queue
		)

	turret_removed.emit(grid_cell)

	_log_telemetry("turret_removed", {
		"grid_x": grid_cell.x,
		"grid_y": grid_cell.y,
		"turret_state": turret_state,
		"turrets_available": pesticide_turrets_available,
		"broken_turrets_in_repair_queue": (
			broken_pesticide_turrets_in_repair_queue
		)
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()

	return true

func damage_pesticide_turret_integrity(
	turret_key: String,
	damage_amount: float
) -> void:
	if damage_amount <= 0.0:
		return

	if not placed_turrets.has(turret_key):
		return

	if get_turret_state(turret_key) == PLACEABLE_STATE_BROKEN:
		return

	var turret_data: Dictionary = placed_turrets[turret_key]

	turret_data["current_integrity"] = clampf(
		float(turret_data.get("current_integrity", 0.0)) - damage_amount,
		0.0,
		pesticide_turret_max_integrity
	)

	if (
		float(turret_data.get("current_integrity", 0.0))
		< pesticide_turret_max_integrity
	):
		turret_data["repair_cost_paid"] = false

	placed_turrets[turret_key] = turret_data

	turret_condition_changed.emit(
		turret_key,
		get_turret_state(turret_key)
	)

func consume_pesticide_turret_durability(
	turret_key: String,
	durability_cost: float
) -> void:
	if durability_cost <= 0.0:
		return

	if not placed_turrets.has(turret_key):
		return

	if get_turret_state(turret_key) == PLACEABLE_STATE_BROKEN:
		return

	var turret_data: Dictionary = placed_turrets[turret_key]

	turret_data["current_durability"] = clampf(
		float(turret_data.get("current_durability", 0.0)) - durability_cost,
		0.0,
		pesticide_turret_max_durability
	)

	if (
		float(turret_data.get("current_durability", 0.0))
		< pesticide_turret_max_durability
	):
		turret_data["repair_cost_paid"] = false

	placed_turrets[turret_key] = turret_data

	turret_condition_changed.emit(
		turret_key,
		get_turret_state(turret_key)
	)

# This will be used by the Workshop later.
func repair_broken_pesticide_turrets_in_workshop(amount: int) -> int:
	if amount <= 0:
		return 0

	var repaired_count: int = mini(
		amount,
		broken_pesticide_turrets_in_repair_queue
	)

	if repaired_count <= 0:
		return 0

	broken_pesticide_turrets_in_repair_queue -= repaired_count
	pesticide_turrets_available += repaired_count

	turret_repair_queue_changed.emit(
		broken_pesticide_turrets_in_repair_queue
	)

	inventory_changed.emit(pesticide_turrets_available)

	_log_telemetry("turret_repair_queue_used", {
		"repaired_count": repaired_count,
		"broken_turrets_in_repair_queue": (
			broken_pesticide_turrets_in_repair_queue
		),
		"turrets_available": pesticide_turrets_available
	})

	return repaired_count


# -------------------------------------------------------------------
# Nightlights
# -------------------------------------------------------------------

func get_nightlights_available() -> int:
	return nightlights_available

func get_nightlight_key(grid_cell: Vector2i) -> String:
	return "%d:%d" % [grid_cell.x, grid_cell.y]

func has_nightlight(grid_cell: Vector2i) -> bool:
	return placed_nightlights.has(get_nightlight_key(grid_cell))

func has_placed_nightlights() -> bool:
	return not placed_nightlights.is_empty()

func get_nightlight_data(nightlight_key: String) -> Dictionary:
	if not placed_nightlights.has(nightlight_key):
		return {}

	var nightlight_data: Dictionary = placed_nightlights[nightlight_key]
	return nightlight_data.duplicate(true)

func get_nightlight_current_integrity(nightlight_key: String) -> float:
	var nightlight_data: Dictionary = get_nightlight_data(nightlight_key)

	if nightlight_data.is_empty():
		return 0.0

	return float(
		nightlight_data.get(
			"current_integrity",
			nightlight_max_integrity
		)
	)

func is_nightlight_repair_cost_paid(nightlight_key: String) -> bool:
	var nightlight_data: Dictionary = get_nightlight_data(nightlight_key)

	if nightlight_data.is_empty():
		return false

	return bool(nightlight_data.get("repair_cost_paid", false))

func mark_nightlight_repair_cost_paid(nightlight_key: String) -> void:
	if not placed_nightlights.has(nightlight_key):
		return

	var nightlight_data: Dictionary = placed_nightlights[nightlight_key]
	nightlight_data["repair_cost_paid"] = true
	placed_nightlights[nightlight_key] = nightlight_data

func get_nightlight_state(nightlight_key: String) -> String:
	if not placed_nightlights.has(nightlight_key):
		return PLACEABLE_STATE_BROKEN

	var current_integrity: float = get_nightlight_current_integrity(
		nightlight_key
	)

	if current_integrity <= 0.0:
		return PLACEABLE_STATE_BROKEN

	if current_integrity < nightlight_max_integrity:
		return PLACEABLE_STATE_DAMAGED

	return PLACEABLE_STATE_PERFECT

func get_broken_nightlights_in_repair_queue() -> int:
	return broken_nightlights_in_repair_queue

func get_broken_nightlight_repair_scrap_cost() -> int:
	return maxi(0, broken_nightlight_repair_scrap_cost)

func get_damaged_nightlight_repair_cost_scrap() -> int:
	return maxi(0, damaged_nightlight_repair_cost_scrap)

func get_nightlight_repair_rate_per_second() -> float:
	return maxf(0.0, nightlight_repair_rate_per_second)


func get_repairable_broken_nightlight_count(
	requested_amount: int
) -> int:
	if requested_amount <= 0:
		return 0

	return mini(
		requested_amount,
		broken_nightlights_in_repair_queue
	)

func get_broken_nightlight_repair_total_cost(
	requested_amount: int
) -> int:
	var repair_count: int = get_repairable_broken_nightlight_count(
		requested_amount
	)

	return repair_count * get_broken_nightlight_repair_scrap_cost()

func get_broken_nightlight_repair_failure_reason(
	requested_amount: int
) -> String:
	if broken_nightlights_in_repair_queue <= 0:
		return "No broken NightLights are waiting for repair."

	var repair_count: int = get_repairable_broken_nightlight_count(
		requested_amount
	)

	if repair_count <= 0:
		return "No broken NightLights are waiting for repair."

	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		return "Player inventory is unavailable."

	if not player_node.has_method("has_resource"):
		return "Player inventory is unavailable."

	var total_scrap_cost: int = (
		get_broken_nightlight_repair_total_cost(repair_count)
	)

	if not bool(
		player_node.call(
			"has_resource",
			"scrap",
			total_scrap_cost
		)
	):
		var current_scrap: int = int(
			player_node.call("get_resource_amount", "scrap")
		)

		return "Need %d Scrap. You have %d." % [
			total_scrap_cost,
			current_scrap
		]

	return ""

func can_place_nightlight(grid_cell: Vector2i) -> bool:
	if nightlights_available <= 0:
		return false

	if get_cell_type(grid_cell) != "open":
		return false

	if is_cell_occupied(grid_cell):
		return false

	return true

func get_nightlight_placement_failure_reason(grid_cell: Vector2i) -> String:
	if nightlights_available <= 0:
		return "No Nightlights are available."

	var cell_type: String = get_cell_type(grid_cell)

	if cell_type == "outside":
		return "Choose a cell within the farm boundary."

	if cell_type == "boundary":
		return "Nightlights cannot be placed on the outer boundary."

	if cell_type == "house":
		return "Nightlights cannot be placed on the house."

	if cell_type == "truck":
		return "Nightlights cannot be placed on the truck."

	if cell_type == "farmland":
		return "Nightlights cannot be placed on farmland."

	if is_cell_occupied(grid_cell):
		return "Another defense item is already placed there."

	return "This location cannot be used."

func place_nightlight(grid_cell: Vector2i) -> bool:
	if not can_place_nightlight(grid_cell):
		placement_failed.emit(
			get_nightlight_placement_failure_reason(grid_cell)
		)
		return false

	var nightlight_key: String = get_nightlight_key(grid_cell)

	placed_nightlights[nightlight_key] = {
		"grid_cell": grid_cell,
		"current_integrity": nightlight_max_integrity,
		"repair_cost_paid": false
	}

	nightlights_available -= 1

	nightlight_inventory_changed.emit(nightlights_available)
	nightlight_placed.emit(grid_cell)
	nightlight_condition_changed.emit(
		nightlight_key,
		get_nightlight_state(nightlight_key)
	)

	_log_telemetry("nightlight_placed", {
		"grid_x": grid_cell.x,
		"grid_y": grid_cell.y,
		"nightlights_available": nightlights_available,
		"current_integrity": nightlight_max_integrity,
		"max_integrity": nightlight_max_integrity
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_nightlights()

	return true

func can_remove_nightlight(grid_cell: Vector2i) -> bool:
	if not has_nightlight(grid_cell):
		return false

	var nightlight_key: String = get_nightlight_key(grid_cell)
	var nightlight_state: String = get_nightlight_state(nightlight_key)

	return (
		nightlight_state == PLACEABLE_STATE_PERFECT
		or nightlight_state == PLACEABLE_STATE_BROKEN
	)

func remove_nightlight(grid_cell: Vector2i) -> bool:
	if not has_nightlight(grid_cell):
		placement_failed.emit("There is no Nightlight placed on this grid cell.")
		return false

	var nightlight_key: String = get_nightlight_key(grid_cell)
	var nightlight_state: String = get_nightlight_state(nightlight_key)
	var nightlight_data: Dictionary = get_nightlight_data(nightlight_key)

	if nightlight_state == PLACEABLE_STATE_DAMAGED:
		placement_failed.emit(
			"Damaged Nightlights must be repaired before removal."
		)
		return false

	placed_nightlights.erase(nightlight_key)

	if nightlight_state == PLACEABLE_STATE_PERFECT:
		nightlights_available += 1
		nightlight_inventory_changed.emit(nightlights_available)

	elif nightlight_state == PLACEABLE_STATE_BROKEN:
		broken_nightlights_in_repair_queue += 1
		nightlight_repair_queue_changed.emit(
			broken_nightlights_in_repair_queue
		)

	nightlight_removed.emit(grid_cell)

	_log_telemetry("nightlight_removed", {
		"grid_x": grid_cell.x,
		"grid_y": grid_cell.y,
		"nightlight_state": nightlight_state,
		"current_integrity": float(
			nightlight_data.get("current_integrity", 0.0)
		),
		"nightlights_available": nightlights_available,
		"broken_nightlights_in_repair_queue": (
			broken_nightlights_in_repair_queue
		)
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_nightlights()

	return true

func damage_nightlight_integrity(
	nightlight_key: String,
	damage_amount: float,
	damage_source: String = "wear"
) -> bool:
	if damage_amount <= 0.0:
		return false

	if not placed_nightlights.has(nightlight_key):
		return false

	if get_nightlight_state(nightlight_key) == PLACEABLE_STATE_BROKEN:
		return false

	var old_state: String = get_nightlight_state(nightlight_key)
	var nightlight_data: Dictionary = placed_nightlights[nightlight_key]
	var old_integrity: float = float(
		nightlight_data.get(
			"current_integrity",
			nightlight_max_integrity
		)
	)

	var new_integrity: float = clampf(
		old_integrity - damage_amount,
		0.0,
		nightlight_max_integrity
	)

	nightlight_data["current_integrity"] = new_integrity

	if new_integrity < nightlight_max_integrity:
		nightlight_data["repair_cost_paid"] = false

	placed_nightlights[nightlight_key] = nightlight_data

	var new_state: String = get_nightlight_state(nightlight_key)

	if new_state != old_state:
		nightlight_condition_changed.emit(nightlight_key, new_state)

		_log_telemetry("nightlight_condition_changed", {
			"nightlight_key": nightlight_key,
			"old_state": old_state,
			"new_state": new_state,
			"damage_source": damage_source,
			"current_integrity": new_integrity,
			"max_integrity": nightlight_max_integrity
		})

	if new_state == PLACEABLE_STATE_BROKEN:
		_log_telemetry("nightlight_broken", {
			"nightlight_key": nightlight_key,
			"damage_source": damage_source,
			"current_integrity": new_integrity,
			"max_integrity": nightlight_max_integrity
		})

		return true

	return false

func repair_nightlight(
	nightlight_key: String,
	repair_amount: float
) -> void:
	if repair_amount <= 0.0:
		return

	if not placed_nightlights.has(nightlight_key):
		return

	if get_nightlight_state(nightlight_key) == PLACEABLE_STATE_BROKEN:
		return

	var old_state: String = get_nightlight_state(nightlight_key)
	var nightlight_data: Dictionary = placed_nightlights[nightlight_key]

	var old_integrity: float = float(
		nightlight_data.get(
			"current_integrity",
			nightlight_max_integrity
		)
	)

	var new_integrity: float = clampf(
		old_integrity + repair_amount,
		0.0,
		nightlight_max_integrity
	)

	nightlight_data["current_integrity"] = new_integrity

	if new_integrity >= nightlight_max_integrity:
		nightlight_data["repair_cost_paid"] = false

	placed_nightlights[nightlight_key] = nightlight_data

	var new_state: String = get_nightlight_state(nightlight_key)

	nightlight_condition_changed.emit(nightlight_key, new_state)

	if (
		old_state == PLACEABLE_STATE_DAMAGED
		and new_state == PLACEABLE_STATE_PERFECT
	):
		_log_telemetry("nightlight_field_repaired", {
			"nightlight_key": nightlight_key,
			"repair_type": "field_repair",
			"repair_amount": repair_amount,
			"current_integrity": new_integrity,
			"max_integrity": nightlight_max_integrity
		})


func repair_broken_nightlights_in_workshop(amount: int) -> int:
	if amount <= 0:
		return 0

	var repaired_count: int = mini(
		amount,
		broken_nightlights_in_repair_queue
	)

	if repaired_count <= 0:
		return 0

	broken_nightlights_in_repair_queue -= repaired_count
	nightlights_available += repaired_count

	nightlight_repair_queue_changed.emit(
		broken_nightlights_in_repair_queue
	)

	nightlight_inventory_changed.emit(nightlights_available)

	_log_telemetry("nightlight_repair_queue_used", {
		"repaired_count": repaired_count,
		"broken_nightlights_in_repair_queue": (
			broken_nightlights_in_repair_queue
		),
		"nightlights_available": nightlights_available
	})

	return repaired_count

func repair_broken_nightlights_with_materials(
	requested_amount: int
) -> int:
	var failure_reason: String = (
		get_broken_nightlight_repair_failure_reason(
			requested_amount
		)
	)

	if not failure_reason.is_empty():
		fence_workshop_action_failed.emit(failure_reason)

		_log_telemetry("nightlight_repair_queue_failed", {
			"requested_amount": requested_amount,
			"reason": failure_reason
		})

		return 0

	var repair_count: int = get_repairable_broken_nightlight_count(
		requested_amount
	)

	var total_scrap_cost: int = (
		get_broken_nightlight_repair_total_cost(repair_count)
	)

	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		var missing_inventory_reason: String = (
			"Player inventory is unavailable."
		)

		fence_workshop_action_failed.emit(missing_inventory_reason)

		_log_telemetry("nightlight_repair_queue_failed", {
			"requested_amount": requested_amount,
			"reason": missing_inventory_reason
		})

		return 0

	var spent_scrap: bool = bool(
		player_node.call(
			"spend_resource",
			"scrap",
			total_scrap_cost
		)
	)

	if not spent_scrap:
		var scrap_failure_reason: String = "Not enough Scrap."

		fence_workshop_action_failed.emit(scrap_failure_reason)

		_log_telemetry("nightlight_repair_queue_failed", {
			"requested_amount": requested_amount,
			"repair_count": repair_count,
			"total_scrap_cost": total_scrap_cost,
			"reason": scrap_failure_reason
		})

		return 0

	var repaired_count: int = repair_broken_nightlights_in_workshop(
		repair_count
	)

	if repaired_count <= 0:
		player_node.call(
			"add_resource",
			"scrap",
			total_scrap_cost
		)

		var completion_failure_reason: String = (
			"NightLight repair could not be completed."
		)

		fence_workshop_action_failed.emit(
			completion_failure_reason
		)

		_log_telemetry("nightlight_repair_queue_failed", {
			"requested_amount": requested_amount,
			"repair_count": repair_count,
			"total_scrap_cost": total_scrap_cost,
			"reason": completion_failure_reason
		})

		return 0

	_log_telemetry("nightlight_repair_queue_paid", {
		"requested_amount": requested_amount,
		"repaired_count": repaired_count,
		"total_scrap_cost": total_scrap_cost,
		"broken_nightlights_in_repair_queue": (
			broken_nightlights_in_repair_queue
		),
		"nightlights_available": nightlights_available
	})

	print(
		"[Workshop] Repaired ",
		repaired_count,
		" NightLight(s). Stored NightLights: ",
		nightlights_available
	)

	return repaired_count

func get_nightlight_position(grid_cell: Vector2i) -> Vector2:
	return get_turret_position(grid_cell)

func _process_nightlight_wear(delta: float) -> void:
	if delta <= 0.0:
		return

	if placed_nightlights.is_empty():
		return

	if nightlight_wear_per_second <= 0.0:
		return

	if not _is_nighttime_for_nightlight_wear():
		return

	var wear_damage: float = nightlight_wear_per_second * delta
	var should_rebuild_nightlights: bool = false

	for nightlight_key_variant in placed_nightlights.keys():
		var nightlight_key: String = str(nightlight_key_variant)

		var broke_now: bool = damage_nightlight_integrity(
			nightlight_key,
			wear_damage,
			"night_wear"
		)

		if broke_now:
			should_rebuild_nightlights = true

	if should_rebuild_nightlights:
		if active_farm_map != null and is_instance_valid(active_farm_map):
			rebuild_farm_nightlights()

func _is_nighttime_for_nightlight_wear() -> bool:
	var current_time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if current_time_manager == null:
		return false

	if current_time_manager.has_method("is_nighttime"):
		return bool(current_time_manager.call("is_nighttime"))

	if "phase" in current_time_manager:
		return str(current_time_manager.get("phase")) == "night"

	return false

# -------------------------------------------------------------------
# Fence placement and condition
# -------------------------------------------------------------------

func get_fences_available() -> int:
	return fences_available

func get_total_owned_fence_count() -> int:
	return (
		fences_available
		+ placed_fences.size()
		+ broken_fences_in_repair_queue
	)

func get_fence_damage_reduction_percent() -> int:
	return int(round((1.0 - fence_damage_multiplier) * 100.0))

func apply_fence_max_health_upgrade(health_bonus: float) -> void:
	if health_bonus <= 0.0:
		return

	fence_max_health += health_bonus

	for fence_key_variant in placed_fences.keys():
		var fence_key: String = str(fence_key_variant)

		if get_fence_state(fence_key) == FENCE_STATE_BROKEN:
			continue

		var current_health: float = get_fence_current_health(fence_key)

		set_fence_current_health(
			fence_key,
			current_health + health_bonus
		)

	fence_stats_changed.emit()

	print(
		"[Fence Upgrade] Fence Maximum HP increased by ",
		health_bonus,
		". New maximum: ",
		fence_max_health
	)

func apply_fence_damage_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	fence_damage_multiplier = clampf(
		fence_damage_multiplier * multiplier,
		0.10,
		1.0
	)

	fence_stats_changed.emit()

	print(
		"[Fence Upgrade] Fence damage reduction is now ",
		get_fence_damage_reduction_percent(),
		"%."
	)

func apply_fence_repair_rate_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	fence_repair_rate_per_second *= multiplier

	fence_stats_changed.emit()

	print(
		"[Fence Upgrade] Fence repair rate is now ",
		fence_repair_rate_per_second,
		" HP per second."
	)


func apply_pesticide_turret_capacity_bonus(capacity_bonus: int) -> void:
	if capacity_bonus <= 0:
		return

	max_pesticide_turrets += capacity_bonus
	pesticide_turrets_available += capacity_bonus

	inventory_changed.emit(pesticide_turrets_available)

	print(
		"[Turret Upgrade] Maximum Pesticide Turret capacity increased by ",
		capacity_bonus,
		". Available turrets: ",
		pesticide_turrets_available
	)

func apply_pesticide_turret_integrity_and_durability_bonus(bonus: float) -> void:
	if bonus <= 0.0:
		return

	pesticide_turret_max_integrity += bonus
	pesticide_turret_max_durability += bonus

	for turret_key_variant in placed_turrets.keys():
		var turret_key: String = str(turret_key_variant)

		if get_turret_state(turret_key) == PLACEABLE_STATE_BROKEN:
			continue

		var turret_data: Dictionary = placed_turrets[turret_key]
		turret_data["current_integrity"] = clampf(
			float(turret_data.get("current_integrity", 0.0)) + bonus,
			0.0,
			pesticide_turret_max_integrity
		)
		turret_data["current_durability"] = clampf(
			float(turret_data.get("current_durability", 0.0)) + bonus,
			0.0,
			pesticide_turret_max_durability
		)
		placed_turrets[turret_key] = turret_data

		turret_condition_changed.emit(
			turret_key,
			get_turret_state(turret_key)
		)

	print(
		"[Turret Upgrade] Pesticide Turret integrity/durability max increased by ",
		bonus,
		". New max integrity: ",
		pesticide_turret_max_integrity
	)

func apply_pesticide_turret_repair_rate_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	pesticide_turret_repair_rate_per_second *= multiplier

	print(
		"[Turret Upgrade] Pesticide Turret repair rate is now ",
		pesticide_turret_repair_rate_per_second,
		" per second."
	)

func get_placed_fence_keys() -> Array[String]:
	var fence_keys: Array[String] = []

	for fence_key_variant in placed_fences.keys():
		fence_keys.append(str(fence_key_variant))

	return fence_keys

func is_valid_fence_orientation(orientation: String) -> bool:
	return (
		orientation == FENCE_ORIENTATION_HORIZONTAL
		or orientation == FENCE_ORIENTATION_VERTICAL
	)

func is_valid_fence_edge(
	orientation: String,
	grid_edge: Vector2i
) -> bool:
	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		return (
			grid_edge.x >= 0
			and grid_edge.x < grid_columns
			and grid_edge.y >= 0
			and grid_edge.y <= grid_rows
		)

	if orientation == FENCE_ORIENTATION_VERTICAL:
		return (
			grid_edge.x >= 0
			and grid_edge.x <= grid_columns
			and grid_edge.y >= 0
			and grid_edge.y < grid_rows
		)

	return false

func get_fence_key(
	orientation: String,
	grid_edge: Vector2i
) -> String:
	return "%s:%d:%d" % [
		orientation,
		grid_edge.x,
		grid_edge.y
	]

func get_cells_touching_fence_edge(
	orientation: String,
	grid_edge: Vector2i
) -> Array[Vector2i]:
	var touching_cells: Array[Vector2i] = []

	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		if grid_edge.y > 0:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y - 1)
			)

		if grid_edge.y < grid_rows:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y)
			)

	elif orientation == FENCE_ORIENTATION_VERTICAL:
		if grid_edge.x > 0:
			touching_cells.append(
				Vector2i(grid_edge.x - 1, grid_edge.y)
			)

		if grid_edge.x < grid_columns:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y)
			)

	return touching_cells

func is_fence_edge_inside_static_object(
	orientation: String,
	grid_edge: Vector2i
) -> bool:
	var touching_cells: Array[Vector2i] = (
		get_cells_touching_fence_edge(orientation, grid_edge)
	)

	if touching_cells.size() < 2:
		return false

	var first_type: String = get_cell_type(touching_cells[0])
	var second_type: String = get_cell_type(touching_cells[1])

	# Block placement inside or directly beside the crop plot.
	if first_type == "farmland" or second_type == "farmland":
		return true

	# Block only the interior of the house or truck.
	if first_type == "house" and second_type == "house":
		return true

	if first_type == "truck" and second_type == "truck":
		return true

	return false

func can_place_fence(
	orientation: String,
	grid_edge: Vector2i
) -> bool:
	if fences_available <= 0:
		return false

	if not is_valid_fence_orientation(orientation):
		return false

	if not is_valid_fence_edge(orientation, grid_edge):
		return false

	var fence_key: String = get_fence_key(orientation, grid_edge)

	if placed_fences.has(fence_key):
		return false

	if is_fence_edge_inside_static_object(orientation, grid_edge):
		return false

	return true

func get_fence_placement_failure_reason(
	orientation: String,
	grid_edge: Vector2i
) -> String:
	if fences_available <= 0:
		return "No fences are available in storage."

	if not is_valid_fence_orientation(orientation):
		return "Choose a valid fence orientation."

	if not is_valid_fence_edge(orientation, grid_edge):
		return "Choose a valid fence edge."

	var fence_key: String = get_fence_key(orientation, grid_edge)

	if placed_fences.has(fence_key):
		return "A fence is already placed on this edge."

	if is_fence_edge_inside_static_object(orientation, grid_edge):
		return (
			"Fences cannot be placed on farmland or through "
			+ "the house or truck."
		)

	return "This fence location cannot be used."

func place_fence(
	orientation: String,
	grid_edge: Vector2i
) -> bool:
	if not can_place_fence(orientation, grid_edge):
		placement_failed.emit(
			get_fence_placement_failure_reason(
				orientation,
				grid_edge
			)
		)
		return false

	var fence_key: String = get_fence_key(orientation, grid_edge)

	placed_fences[fence_key] = {
		"orientation": orientation,
		"grid_edge": grid_edge,
		"current_health": fence_max_health,
		"repair_cost_paid": false,
		"is_perimeter_fence": false
	}

	fences_available -= 1

	fence_inventory_changed.emit(fences_available)
	fence_placed.emit(fence_key)
	fence_navigation_changed.emit()

	_log_telemetry("fence_placed", {
		"fence_key": fence_key,
		"orientation": orientation,
		"grid_x": grid_edge.x,
		"grid_y": grid_edge.y,
		"fences_available": fences_available
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_fences()

	return true

func has_fence(fence_key: String) -> bool:
	return placed_fences.has(fence_key)

func get_fence_data(fence_key: String) -> Dictionary:
	if not placed_fences.has(fence_key):
		return {}

	var fence_data: Dictionary = placed_fences[fence_key]
	return fence_data.duplicate(true)

func is_fence_repair_cost_paid(fence_key: String) -> bool:
	var fence_data: Dictionary = get_fence_data(fence_key)

	if fence_data.is_empty():
		return false

	return bool(fence_data.get("repair_cost_paid", false))

func mark_fence_repair_cost_paid(fence_key: String) -> void:
	if not has_fence(fence_key):
		return

	var fence_data: Dictionary = placed_fences[fence_key]

	fence_data["repair_cost_paid"] = true
	placed_fences[fence_key] = fence_data

func get_fence_current_health(fence_key: String) -> float:
	var fence_data: Dictionary = get_fence_data(fence_key)

	if fence_data.is_empty():
		return 0.0

	return float(fence_data.get("current_health", 0.0))

func get_fence_state(fence_key: String) -> String:
	if not has_fence(fence_key):
		return FENCE_STATE_BROKEN

	var current_health: float = get_fence_current_health(fence_key)

	if current_health <= 0.0:
		return FENCE_STATE_BROKEN

	if current_health < fence_max_health:
		return FENCE_STATE_DAMAGED

	return FENCE_STATE_PERFECT
	
func _get_fence_key_from_axis(
	orientation: String,
	fixed_axis: int,
	changing_axis: int
) -> String:
	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		return get_fence_key(
			orientation,
			Vector2i(changing_axis, fixed_axis)
		)

	return get_fence_key(
		orientation,
		Vector2i(fixed_axis, changing_axis)
	)

func _is_broken_fence_on_axis(
	orientation: String,
	fixed_axis: int,
	changing_axis: int
) -> bool:
	var fence_key: String = _get_fence_key_from_axis(
		orientation,
		fixed_axis,
		changing_axis
	)

	return (
		has_fence(fence_key)
		and get_fence_state(fence_key) == FENCE_STATE_BROKEN
	)

func get_broken_fence_run_data(fence_key: String) -> Dictionary:
	if not has_fence(fence_key):
		return {}

	if get_fence_state(fence_key) != FENCE_STATE_BROKEN:
		return {}

	var fence_data: Dictionary = get_fence_data(fence_key)

	var orientation: String = str(
		fence_data.get("orientation", "")
	)

	var grid_edge: Vector2i = fence_data.get(
		"grid_edge",
		Vector2i.ZERO
	)

	if orientation.is_empty():
		return {}

	var fixed_axis: int = grid_edge.y
	var current_axis: int = grid_edge.x

	if orientation == FENCE_ORIENTATION_VERTICAL:
		fixed_axis = grid_edge.x
		current_axis = grid_edge.y

	var start_axis: int = current_axis
	var end_axis: int = current_axis

	while _is_broken_fence_on_axis(
		orientation,
		fixed_axis,
		start_axis - 1
	):
		start_axis -= 1

	while _is_broken_fence_on_axis(
		orientation,
		fixed_axis,
		end_axis + 1
	):
		end_axis += 1

	return {
		"orientation": orientation,
		"fixed_axis": fixed_axis,
		"start_axis": start_axis,
		"end_axis": end_axis,
		"segment_count": end_axis - start_axis + 1
	}

func get_broken_fences_in_repair_queue() -> int:
	return broken_fences_in_repair_queue

func get_fence_craft_scrap_cost() -> int:
	return maxi(0, fence_craft_scrap_cost)

func get_fence_craft_seed_cost() -> int:
	return maxi(0, fence_craft_seed_cost)

func get_broken_fence_repair_scrap_cost() -> int:
	return maxi(0, broken_fence_repair_scrap_cost)

func get_repairable_broken_fence_count(
	requested_amount: int
) -> int:
	if requested_amount <= 0:
		return 0

	return mini(
		requested_amount,
		broken_fences_in_repair_queue
	)

func get_broken_fence_repair_total_cost(
	requested_amount: int
) -> int:
	var repair_count: int = get_repairable_broken_fence_count(
		requested_amount
	)

	return repair_count * get_broken_fence_repair_scrap_cost()

func _get_player_resource_node() -> Node:
	return get_tree().get_first_node_in_group("player")

func get_fence_craft_failure_reason() -> String:
	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		return "Player inventory is unavailable."

	if not player_node.has_method("has_resource"):
		return "Player inventory is unavailable."

	var scrap_cost: int = get_fence_craft_scrap_cost()
	var seed_cost: int = get_fence_craft_seed_cost()

	if not bool(player_node.call("has_resource", "scrap", scrap_cost)):
		var current_scrap: int = int(
			player_node.call("get_resource_amount", "scrap")
		)

		return "Need %d Scrap. You have %d." % [
			scrap_cost,
			current_scrap
		]

	if not bool(player_node.call("has_resource", "seeds", seed_cost)):
		var current_seeds: int = int(
			player_node.call("get_resource_amount", "seeds")
		)

		return "Need %d Seeds. You have %d." % [
			seed_cost,
			current_seeds
		]

	return ""

func get_broken_fence_repair_failure_reason(
	requested_amount: int
) -> String:
	if broken_fences_in_repair_queue <= 0:
		return "No broken fences are waiting for repair."

	var repair_count: int = get_repairable_broken_fence_count(
		requested_amount
	)

	if repair_count <= 0:
		return "No broken fences are waiting for repair."

	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		return "Player inventory is unavailable."

	if not player_node.has_method("has_resource"):
		return "Player inventory is unavailable."

	var total_scrap_cost: int = get_broken_fence_repair_total_cost(
		repair_count
	)

	if not bool(
		player_node.call(
			"has_resource",
			"scrap",
			total_scrap_cost
		)
	):
		var current_scrap: int = int(
			player_node.call("get_resource_amount", "scrap")
		)

		return "Need %d Scrap. You have %d." % [
			total_scrap_cost,
			current_scrap
		]

	return ""

func craft_fence_in_workshop() -> bool:
	var failure_reason: String = get_fence_craft_failure_reason()

	if not failure_reason.is_empty():
		fence_workshop_action_failed.emit(failure_reason)

		_log_telemetry("fence_craft_failed", {
			"reason": failure_reason
		})

		return false

	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		var missing_inventory_reason: String = "Player inventory is unavailable."

		fence_workshop_action_failed.emit(missing_inventory_reason)

		_log_telemetry("fence_craft_failed", {
			"reason": missing_inventory_reason
		})

		return false

	var scrap_cost: int = get_fence_craft_scrap_cost()
	var seed_cost: int = get_fence_craft_seed_cost()

	var spent_scrap: bool = bool(
		player_node.call("spend_resource", "scrap", scrap_cost)
	)

	if not spent_scrap:
		var scrap_failure_reason: String = "Not enough Scrap."

		fence_workshop_action_failed.emit(scrap_failure_reason)

		_log_telemetry("fence_craft_failed", {
			"reason": scrap_failure_reason,
			"scrap_cost": scrap_cost,
			"seed_cost": seed_cost
		})

		return false

	var spent_seeds: bool = bool(
		player_node.call("spend_resource", "seeds", seed_cost)
	)

	if not spent_seeds:
		player_node.call("add_resource", "scrap", scrap_cost)

		var seed_failure_reason: String = "Not enough Seeds."

		fence_workshop_action_failed.emit(seed_failure_reason)

		_log_telemetry("fence_craft_failed", {
			"reason": seed_failure_reason,
			"scrap_cost": scrap_cost,
			"seed_cost": seed_cost
		})

		return false

	fences_available += 1

	fence_inventory_changed.emit(fences_available)
	fence_crafted.emit(fences_available)

	_log_telemetry("fence_crafted", {
		"fences_available": fences_available,
		"scrap_cost": scrap_cost,
		"seed_cost": seed_cost
	})

	print(
		"[Workshop] Crafted 1 Fence. "
		+ "Stored fences: ",
		fences_available
	)

	return true

func repair_broken_fences_with_materials(
	requested_amount: int
) -> int:
	var failure_reason: String = (
		get_broken_fence_repair_failure_reason(
			requested_amount
		)
	)

	if not failure_reason.is_empty():
		fence_workshop_action_failed.emit(failure_reason)

		_log_telemetry("fence_repair_queue_failed", {
			"requested_amount": requested_amount,
			"reason": failure_reason
		})

		return 0

	var repair_count: int = get_repairable_broken_fence_count(
		requested_amount
	)

	var total_scrap_cost: int = get_broken_fence_repair_total_cost(
		repair_count
	)

	var player_node: Node = _get_player_resource_node()

	if player_node == null:
		var missing_inventory_reason: String = "Player inventory is unavailable."

		fence_workshop_action_failed.emit(missing_inventory_reason)

		_log_telemetry("fence_repair_queue_failed", {
			"requested_amount": requested_amount,
			"reason": missing_inventory_reason
		})

		return 0

	var spent_scrap: bool = bool(
		player_node.call(
			"spend_resource",
			"scrap",
			total_scrap_cost
		)
	)

	if not spent_scrap:
		var scrap_failure_reason: String = "Not enough Scrap."

		fence_workshop_action_failed.emit(
			scrap_failure_reason
		)

		_log_telemetry("fence_repair_queue_failed", {
			"requested_amount": requested_amount,
			"repair_count": repair_count,
			"total_scrap_cost": total_scrap_cost,
			"reason": scrap_failure_reason
		})

		return 0

	var repaired_count: int = repair_broken_fences_in_workshop(
		repair_count
	)

	if repaired_count <= 0:
		player_node.call(
			"add_resource",
			"scrap",
			total_scrap_cost
		)

		var completion_failure_reason: String = (
			"Fence repair could not be completed."
		)

		fence_workshop_action_failed.emit(
			completion_failure_reason
		)

		_log_telemetry("fence_repair_queue_failed", {
			"requested_amount": requested_amount,
			"repair_count": repair_count,
			"total_scrap_cost": total_scrap_cost,
			"reason": completion_failure_reason
		})

		return 0

	_log_telemetry("fence_repair_queue_used", {
		"requested_amount": requested_amount,
		"repaired_count": repaired_count,
		"total_scrap_cost": total_scrap_cost,
		"broken_fences_in_repair_queue": broken_fences_in_repair_queue,
		"fences_available": fences_available
	})

	print(
		"[Workshop] Repaired ",
		repaired_count,
		" Fence(s). Stored fences: ",
		fences_available
	)

	return repaired_count

func is_fence_gap_passable(
	fence_key: String,
	required_segment_count: int = 0
) -> bool:
	var run_data: Dictionary = get_broken_fence_run_data(fence_key)

	var segment_count: int = int(
		run_data.get("segment_count", 0)
	)

	var final_required_segment_count: int = (
		required_segment_count
	)

	if final_required_segment_count <= 0:
		final_required_segment_count = (
			minimum_broken_segments_for_passable_gap
		)

	final_required_segment_count = maxi(
		1,
		final_required_segment_count
	)

	return segment_count >= final_required_segment_count

func get_fence_gap_center_position(fence_key: String) -> Vector2:
	var run_data: Dictionary = get_broken_fence_run_data(fence_key)

	if run_data.is_empty():
		return Vector2.ZERO

	var orientation: String = str(
		run_data.get("orientation", "")
	)

	var fixed_axis: int = int(run_data.get("fixed_axis", 0))
	var start_axis: int = int(run_data.get("start_axis", 0))
	var end_axis: int = int(run_data.get("end_axis", 0))

	var start_edge: Vector2i
	var end_edge: Vector2i

	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		start_edge = Vector2i(start_axis, fixed_axis)
		end_edge = Vector2i(end_axis, fixed_axis)
	else:
		start_edge = Vector2i(fixed_axis, start_axis)
		end_edge = Vector2i(fixed_axis, end_axis)

	return (
		get_fence_world_position(orientation, start_edge)
		+ get_fence_world_position(orientation, end_edge)
	) * 0.5
	
func get_perimeter_side_for_fence(fence_key: String) -> String:
	if not has_fence(fence_key):
		return ""

	var fence_data: Dictionary = get_fence_data(fence_key)

	if not bool(fence_data.get("is_perimeter_fence", false)):
		return ""

	var orientation: String = str(
		fence_data.get("orientation", "")
	)

	var grid_edge: Vector2i = fence_data.get(
		"grid_edge",
		Vector2i.ZERO
	)

	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		if grid_edge.y == 0:
			return "top"

		if grid_edge.y == grid_rows:
			return "bottom"

	elif orientation == FENCE_ORIENTATION_VERTICAL:
		if grid_edge.x == 0:
			return "left"

		if grid_edge.x == grid_columns:
			return "right"

	return ""

func get_exterior_side_for_world_position(
	world_position: Vector2
) -> String:
	var farm_left: float = farm_grid_origin.x
	var farm_top: float = farm_grid_origin.y

	var farm_right: float = (
		farm_left + float(grid_columns) * farm_grid_cell_size.x
	)

	var farm_bottom: float = (
		farm_top + float(grid_rows) * farm_grid_cell_size.y
	)

	var best_side: String = ""
	var greatest_outside_distance: float = 0.0

	var top_distance: float = farm_top - world_position.y

	if top_distance > greatest_outside_distance:
		greatest_outside_distance = top_distance
		best_side = "top"

	var bottom_distance: float = world_position.y - farm_bottom

	if bottom_distance > greatest_outside_distance:
		greatest_outside_distance = bottom_distance
		best_side = "bottom"

	var left_distance: float = farm_left - world_position.x

	if left_distance > greatest_outside_distance:
		greatest_outside_distance = left_distance
		best_side = "left"

	var right_distance: float = world_position.x - farm_right

	if right_distance > greatest_outside_distance:
		best_side = "right"

	return best_side
	
func is_world_position_inside_farm_perimeter(
	world_position: Vector2
) -> bool:
	var farm_left: float = farm_grid_origin.x
	var farm_top: float = farm_grid_origin.y

	var farm_right: float = (
		farm_left
		+ float(grid_columns) * farm_grid_cell_size.x
	)

	var farm_bottom: float = (
		farm_top
		+ float(grid_rows) * farm_grid_cell_size.y
	)

	return (
		world_position.x > farm_left
		and world_position.x < farm_right
		and world_position.y > farm_top
		and world_position.y < farm_bottom
	)

func get_perimeter_breach_route(
	fence_key: String,
	required_segment_count: int = 0
) -> Dictionary:
	if not is_fence_gap_passable(
		fence_key,
		required_segment_count
	):
		return {}

	var perimeter_side: String = get_perimeter_side_for_fence(
		fence_key
	)

	if perimeter_side.is_empty():
		return {}

	var gap_center: Vector2 = get_fence_gap_center_position(
		fence_key
	)

	var outward_direction: Vector2 = Vector2.ZERO

	match perimeter_side:
		"top":
			outward_direction = Vector2.UP
		"bottom":
			outward_direction = Vector2.DOWN
		"left":
			outward_direction = Vector2.LEFT
		"right":
			outward_direction = Vector2.RIGHT

	var route_offset: float = 28.0

	return {
		"side": perimeter_side,
		"outside_position": gap_center + outward_direction * route_offset,
		"inside_position": gap_center - outward_direction * route_offset
	}

func set_fence_current_health(
	fence_key: String,
	new_current_health: float
) -> void:
	if not has_fence(fence_key):
		return

	var old_state: String = get_fence_state(fence_key)

	var fence_data: Dictionary = placed_fences[fence_key]

	var clamped_health: float = clampf(
		new_current_health,
		0.0,
		fence_max_health
	)

	fence_data["current_health"] = clamped_health

	if clamped_health >= fence_max_health:
		fence_data["repair_cost_paid"] = false

	placed_fences[fence_key] = fence_data

	var new_state: String = get_fence_state(fence_key)

	fence_state_changed.emit(fence_key, new_state)

	var old_was_broken: bool = old_state == FENCE_STATE_BROKEN
	var new_was_broken: bool = new_state == FENCE_STATE_BROKEN

	if old_was_broken != new_was_broken:
		fence_navigation_changed.emit()

		if debug_fence_logging:
			if new_was_broken:
				var run_data: Dictionary = get_broken_fence_run_data(
					fence_key
				)

				var broken_count: int = int(
					run_data.get("segment_count", 0)
				)

				print(
					"[Fence] ",
					fence_key,
					" broke. Consecutive gap: ",
					broken_count,
					"/",
					minimum_broken_segments_for_passable_gap,
					" | Passable: ",
					is_fence_gap_passable(fence_key)
				)
			else:
				print(
					"[Fence] ",
					fence_key,
					" is no longer broken."
				)

func damage_fence(
	fence_key: String,
	damage_amount: float
) -> void:
	if damage_amount <= 0.0:
		return

	if not has_fence(fence_key):
		return

	var old_state: String = get_fence_state(fence_key)
	var current_health: float = get_fence_current_health(fence_key)

	set_fence_current_health(
		fence_key,
		current_health - damage_amount
	)

	var new_state: String = get_fence_state(fence_key)

	if (
		old_state != FENCE_STATE_BROKEN
		and new_state == FENCE_STATE_BROKEN
	):
		var fence_data: Dictionary = get_fence_data(fence_key)

		var grid_edge: Vector2i = fence_data.get(
			"grid_edge",
			Vector2i.ZERO
		)

		_log_telemetry("fence_broken", {
			"fence_key": fence_key,
			"orientation": str(fence_data.get("orientation", "")),
			"grid_x": grid_edge.x,
			"grid_y": grid_edge.y,
			"damage_amount": damage_amount,
			"fence_max_health": fence_max_health
		})

func repair_fence(
	fence_key: String,
	repair_amount: float
) -> void:
	if repair_amount <= 0.0:
		return

	if get_fence_state(fence_key) == FENCE_STATE_BROKEN:
		return

	var old_state: String = get_fence_state(fence_key)
	var current_health: float = get_fence_current_health(fence_key)

	set_fence_current_health(
		fence_key,
		current_health + repair_amount
	)

	var new_state: String = get_fence_state(fence_key)

	if (
		old_state == FENCE_STATE_DAMAGED
		and new_state == FENCE_STATE_PERFECT
	):
		_log_telemetry("fence_repaired", {
			"fence_key": fence_key,
			"repair_type": "field_repair",
			"repair_amount": repair_amount,
			"current_health": get_fence_current_health(fence_key),
			"fence_max_health": fence_max_health
		})

func can_remove_fence(fence_key: String) -> bool:
	var fence_state: String = get_fence_state(fence_key)

	return (
		fence_state == FENCE_STATE_PERFECT
		or fence_state == FENCE_STATE_BROKEN
	)

func remove_fence(fence_key: String) -> bool:
	if not has_fence(fence_key):
		placement_failed.emit("There is no fence placed there.")
		return false

	var fence_state: String = get_fence_state(fence_key)

	if fence_state == FENCE_STATE_DAMAGED:
		placement_failed.emit(
			"Damaged fences must be repaired in the field before removal."
		)
		return false

	var fence_data: Dictionary = get_fence_data(fence_key)

	var orientation: String = str(
		fence_data.get("orientation", "")
	)

	var grid_edge: Vector2i = fence_data.get(
		"grid_edge",
		Vector2i.ZERO
	)

	placed_fences.erase(fence_key)

	if fence_state == FENCE_STATE_PERFECT:
		fences_available += 1
		fence_inventory_changed.emit(fences_available)

	elif fence_state == FENCE_STATE_BROKEN:
		broken_fences_in_repair_queue += 1

		fence_repair_queue_changed.emit(
			broken_fences_in_repair_queue
		)

	fence_removed.emit(fence_key)
	fence_navigation_changed.emit()

	_log_telemetry("fence_removed", {
		"fence_key": fence_key,
		"orientation": orientation,
		"grid_x": grid_edge.x,
		"grid_y": grid_edge.y,
		"fence_state": fence_state,
		"fences_available": fences_available,
		"broken_fences_in_repair_queue": broken_fences_in_repair_queue
	})

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_fences()

	return true

func repair_broken_fences_in_workshop(amount: int) -> int:
	if amount <= 0:
		return 0

	var repaired_count: int = mini(
		amount,
		broken_fences_in_repair_queue
	)

	if repaired_count <= 0:
		return 0

	broken_fences_in_repair_queue -= repaired_count
	fences_available += repaired_count

	fence_repair_queue_changed.emit(
		broken_fences_in_repair_queue
	)

	fence_inventory_changed.emit(fences_available)

	return repaired_count

func get_fence_world_position(
	orientation: String,
	grid_edge: Vector2i
) -> Vector2:
	if orientation == FENCE_ORIENTATION_HORIZONTAL:
		return farm_grid_origin + Vector2(
			(float(grid_edge.x) + 0.5) * farm_grid_cell_size.x,
			float(grid_edge.y) * farm_grid_cell_size.y
		)

	return farm_grid_origin + Vector2(
		float(grid_edge.x) * farm_grid_cell_size.x,
		(float(grid_edge.y) + 0.5) * farm_grid_cell_size.y
	)

func get_fence_world_rotation(orientation: String) -> float:
	if orientation == FENCE_ORIENTATION_VERTICAL:
		return PI / 2.0

	return 0.0

# -------------------------------------------------------------------
# Farm-map reconstruction
# -------------------------------------------------------------------

func _on_location_loaded(
	location_id: String,
	loaded_map: Node
) -> void:
	if location_id == "farm":
		active_farm_map = loaded_map

		rebuild_farm_turrets()
		rebuild_farm_fences()
		rebuild_farm_nightlights()
	else:
		active_farm_map = null

func rebuild_farm_turrets() -> void:
	if pesticide_turret_scene == null:
		print("Pesticide turret scene is not assigned.")
		return

	if active_farm_map == null:
		return

	var placement_root: Node2D = (
		active_farm_map.get_node_or_null(
			"TurretPlacementRoot"
		) as Node2D
	)

	if placement_root == null:
		print("Farm map is missing TurretPlacementRoot.")
		return

	for child in placement_root.get_children():
		child.queue_free()

	for turret_key_variant in placed_turrets.keys():
		var turret_key: String = str(turret_key_variant)
		var turret_data: Dictionary = get_turret_data(turret_key)

		var grid_cell: Vector2i = turret_data.get(
			"grid_cell",
			Vector2i.ZERO
		)

		var turret: Node2D = (
			pesticide_turret_scene.instantiate() as Node2D
		)

		if turret == null:
			continue

		turret.position = get_turret_position(grid_cell)
		placement_root.add_child(turret)

		if turret.has_method("configure_turret"):
			turret.call(
				"configure_turret",
				self,
				turret_key
			)

func rebuild_farm_nightlights() -> void:
	if active_farm_map == null:
		return

	var placement_root: Node2D = _get_or_create_nightlight_placement_root()

	if placement_root == null:
		print("Farm map is missing NightLightPlacementRoot.")
		return

	for child in placement_root.get_children():
		child.queue_free()

	if placed_nightlights.is_empty():
		return

	if nightlight_scene == null:
		print("NightLight scene is not assigned.")
		return

	for nightlight_key_variant in placed_nightlights.keys():
		var nightlight_key: String = str(nightlight_key_variant)
		var nightlight_data: Dictionary = get_nightlight_data(
			nightlight_key
		)

		var grid_cell: Vector2i = nightlight_data.get(
			"grid_cell",
			Vector2i.ZERO
		)

		var nightlight: Node2D = (
			nightlight_scene.instantiate() as Node2D
		)

		if nightlight == null:
			continue

		nightlight.position = get_nightlight_position(grid_cell)
		placement_root.add_child(nightlight)

		if nightlight.has_method("configure_nightlight"):
			nightlight.call(
				"configure_nightlight",
				self,
				nightlight_key
			)

		if nightlight.has_method("set_nightlight_state"):
			nightlight.call(
				"set_nightlight_state",
				get_nightlight_state(nightlight_key)
			)

func _get_or_create_nightlight_placement_root() -> Node2D:
	if active_farm_map == null:
		return null

	var placement_root: Node2D = (
		active_farm_map.get_node_or_null(
			"NightLightPlacementRoot"
		) as Node2D
	)

	if placement_root != null:
		return placement_root

	placement_root = Node2D.new()
	placement_root.name = "NightLightPlacementRoot"
	active_farm_map.add_child(placement_root)

	return placement_root

func rebuild_farm_fences() -> void:
	if active_farm_map == null:
		return

	var placement_root: Node2D = (
		active_farm_map.get_node_or_null(
			"FencePlacementRoot"
		) as Node2D
	)

	if placement_root == null:
		if not placed_fences.is_empty():
			print("Farm map is missing FencePlacementRoot.")
		return

	for child in placement_root.get_children():
		child.queue_free()

	if placed_fences.is_empty():
		return

	if fence_segment_scene == null:
		print("Fence segment scene is not assigned.")
		return

	for fence_key_variant in placed_fences.keys():
		var fence_key: String = str(fence_key_variant)
		var fence_data: Dictionary = get_fence_data(fence_key)

		var orientation: String = str(
			fence_data.get("orientation", "")
		)

		var grid_edge: Vector2i = fence_data.get(
			"grid_edge",
			Vector2i.ZERO
		)

		var fence_segment: Node2D = (
			fence_segment_scene.instantiate() as Node2D
		)

		if fence_segment == null:
			continue

		fence_segment.position = get_fence_world_position(
			orientation,
			grid_edge
		)

		fence_segment.rotation = get_fence_world_rotation(
			orientation
		)

		placement_root.add_child(fence_segment)

		if fence_segment.has_method("configure_fence"):
			fence_segment.call(
				"configure_fence",
				self,
				fence_key
			)
			
func get_save_data() -> Dictionary:
	var saved_turrets: Array[Dictionary] = []

	for turret_key_variant in placed_turrets.keys():
		var turret_key: String = str(turret_key_variant)
		var turret_data: Dictionary = get_turret_data(turret_key)

		var grid_cell: Vector2i = turret_data.get(
			"grid_cell",
			Vector2i.ZERO
		)

		saved_turrets.append({
			"turret_key": turret_key,
			"grid_x": grid_cell.x,
			"grid_y": grid_cell.y,
			"current_integrity": float(
				turret_data.get("current_integrity", 0.0)
			),
			"current_durability": float(
				turret_data.get("current_durability", 0.0)
			),
			"repair_cost_paid": bool(
				turret_data.get("repair_cost_paid", false)
			)
		})

	var saved_nightlights: Array[Dictionary] = []

	for nightlight_key_variant in placed_nightlights.keys():
		var nightlight_key: String = str(nightlight_key_variant)
		var nightlight_data: Dictionary = get_nightlight_data(
			nightlight_key
		)

		var nightlight_grid_cell: Vector2i = nightlight_data.get(
			"grid_cell",
			Vector2i.ZERO
		)

		saved_nightlights.append({
			"nightlight_key": nightlight_key,
			"grid_x": nightlight_grid_cell.x,
			"grid_y": nightlight_grid_cell.y,
			"current_integrity": float(
				nightlight_data.get(
					"current_integrity",
					nightlight_max_integrity
				)
			),
			"repair_cost_paid": bool(
				nightlight_data.get("repair_cost_paid", false)
			)
		})

	var saved_fences: Array[Dictionary] = []

	for fence_key_variant in placed_fences.keys():
		var fence_key: String = str(fence_key_variant)
		var fence_data: Dictionary = get_fence_data(fence_key)

		var grid_edge: Vector2i = fence_data.get(
			"grid_edge",
			Vector2i.ZERO
		)

		saved_fences.append({
			"fence_key": fence_key,
			"orientation": str(
				fence_data.get("orientation", "")
			),
			"grid_x": grid_edge.x,
			"grid_y": grid_edge.y,
			"current_health": float(
				fence_data.get("current_health", fence_max_health)
			),
			"repair_cost_paid": bool(
				fence_data.get("repair_cost_paid", false)
			),
			"is_perimeter_fence": bool(
				fence_data.get("is_perimeter_fence", false)
			)
		})

	return {
		"max_pesticide_turrets": max_pesticide_turrets,
		"pesticide_turrets_available": pesticide_turrets_available,
		"pesticide_turret_max_integrity": pesticide_turret_max_integrity,
		"pesticide_turret_max_durability": pesticide_turret_max_durability,
		"broken_pesticide_turrets_in_repair_queue": (
			broken_pesticide_turrets_in_repair_queue
		),
		"placed_turrets": saved_turrets,
		"damaged_pesticide_turret_repair_cost_scrap": (
			damaged_pesticide_turret_repair_cost_scrap
		),
		"pesticide_turret_repair_rate_per_second": (
			pesticide_turret_repair_rate_per_second
		),

		"nightlights_available": nightlights_available,
		"broken_nightlights_in_repair_queue": (
			broken_nightlights_in_repair_queue
		),
		"placed_nightlights": saved_nightlights,
		"nightlight_max_integrity": nightlight_max_integrity,
		"nightlight_wear_per_second": nightlight_wear_per_second,
		"damaged_nightlight_repair_cost_scrap": (
			damaged_nightlight_repair_cost_scrap
		),
		"nightlight_repair_rate_per_second": (
			nightlight_repair_rate_per_second
		),
		"broken_nightlight_repair_scrap_cost": (
			broken_nightlight_repair_scrap_cost
		),

		"fences_available": fences_available,
		"broken_fences_in_repair_queue": broken_fences_in_repair_queue,
		"placed_fences": saved_fences,

		"fence_max_health": fence_max_health,
		"fence_repair_rate_per_second": fence_repair_rate_per_second,
		"fence_damage_multiplier": fence_damage_multiplier
	}

func load_save_data(data: Dictionary) -> void:
	max_pesticide_turrets = int(
		data.get(
			"max_pesticide_turrets",
			max_pesticide_turrets
		)
	)

	pesticide_turret_max_integrity = float(
		data.get(
			"pesticide_turret_max_integrity",
			pesticide_turret_max_integrity
		)
	)

	pesticide_turret_max_durability = float(
		data.get(
			"pesticide_turret_max_durability",
			pesticide_turret_max_durability
		)
	)

	pesticide_turrets_available = int(
		data.get(
			"pesticide_turrets_available",
			max_pesticide_turrets
		)
	)

	broken_pesticide_turrets_in_repair_queue = int(
		data.get(
			"broken_pesticide_turrets_in_repair_queue",
			0
		)
	)

	damaged_pesticide_turret_repair_cost_scrap = int(
		data.get(
			"damaged_pesticide_turret_repair_cost_scrap",
			damaged_pesticide_turret_repair_cost_scrap
		)
	)

	pesticide_turret_repair_rate_per_second = float(
		data.get(
			"pesticide_turret_repair_rate_per_second",
			pesticide_turret_repair_rate_per_second
		)
	)

	nightlights_available = int(
		data.get("nightlights_available", starting_nightlights)
	)

	broken_nightlights_in_repair_queue = int(
		data.get("broken_nightlights_in_repair_queue", 0)
	)

	nightlight_max_integrity = float(
		data.get("nightlight_max_integrity", nightlight_max_integrity)
	)

	nightlight_wear_per_second = float(
		data.get("nightlight_wear_per_second", nightlight_wear_per_second)
	)

	damaged_nightlight_repair_cost_scrap = int(
		data.get(
			"damaged_nightlight_repair_cost_scrap",
			damaged_nightlight_repair_cost_scrap
		)
	)

	nightlight_repair_rate_per_second = float(
		data.get(
			"nightlight_repair_rate_per_second",
			nightlight_repair_rate_per_second
		)
	)

	broken_nightlight_repair_scrap_cost = int(
		data.get(
			"broken_nightlight_repair_scrap_cost",
			broken_nightlight_repair_scrap_cost
		)
	)

	fences_available = int(
		data.get("fences_available", starting_fences)
	)

	broken_fences_in_repair_queue = int(
		data.get("broken_fences_in_repair_queue", 0)
	)

	fence_max_health = float(
		data.get("fence_max_health", fence_max_health)
	)

	fence_repair_rate_per_second = float(
		data.get(
			"fence_repair_rate_per_second",
			fence_repair_rate_per_second
		)
	)

	fence_damage_multiplier = float(
		data.get("fence_damage_multiplier", fence_damage_multiplier)
	)

	placed_turrets.clear()

	var saved_turrets: Array = data.get("placed_turrets", [])

	for turret_variant in saved_turrets:
		var turret_data: Dictionary = turret_variant

		var grid_cell := Vector2i(
			int(turret_data.get("grid_x", 0)),
			int(turret_data.get("grid_y", 0))
		)

		var turret_key: String = get_turret_key(grid_cell)

		placed_turrets[turret_key] = {
			"grid_cell": grid_cell,
			"current_integrity": float(
				turret_data.get(
					"current_integrity",
					pesticide_turret_max_integrity
				)
			),
			"current_durability": float(
				turret_data.get(
					"current_durability",
					pesticide_turret_max_durability
				)
			),
			"repair_cost_paid": bool(
				turret_data.get("repair_cost_paid", false)
			)
		}

	placed_nightlights.clear()

	var saved_nightlights: Array = data.get("placed_nightlights", [])

	for nightlight_variant in saved_nightlights:
		var nightlight_data: Dictionary = nightlight_variant

		var nightlight_grid_cell := Vector2i(
			int(nightlight_data.get("grid_x", 0)),
			int(nightlight_data.get("grid_y", 0))
		)

		if get_cell_type(nightlight_grid_cell) != "open":
			continue

		var nightlight_key: String = get_nightlight_key(
			nightlight_grid_cell
		)

		placed_nightlights[nightlight_key] = {
			"grid_cell": nightlight_grid_cell,
			"current_integrity": clampf(
				float(
					nightlight_data.get(
						"current_integrity",
						nightlight_max_integrity
					)
				),
				0.0,
				nightlight_max_integrity
			),
			"repair_cost_paid": bool(
				nightlight_data.get("repair_cost_paid", false)
			)
		}

	placed_fences.clear()

	var saved_fences: Array = data.get("placed_fences", [])

	for fence_variant in saved_fences:
		var fence_data: Dictionary = fence_variant

		var orientation: String = str(
			fence_data.get("orientation", "")
		)

		var grid_edge := Vector2i(
			int(fence_data.get("grid_x", 0)),
			int(fence_data.get("grid_y", 0))
		)

		if not is_valid_fence_orientation(orientation):
			continue

		if not is_valid_fence_edge(orientation, grid_edge):
			continue

		var fence_key: String = get_fence_key(
			orientation,
			grid_edge
		)

		placed_fences[fence_key] = {
			"orientation": orientation,
			"grid_edge": grid_edge,
			"current_health": float(
				fence_data.get("current_health", fence_max_health)
			),
			"repair_cost_paid": bool(
				fence_data.get("repair_cost_paid", false)
			),
			"is_perimeter_fence": bool(
				fence_data.get("is_perimeter_fence", false)
			)
		}

	inventory_changed.emit(pesticide_turrets_available)
	nightlight_inventory_changed.emit(nightlights_available)
	nightlight_repair_queue_changed.emit(
		broken_nightlights_in_repair_queue
	)

	turret_repair_queue_changed.emit(
		broken_pesticide_turrets_in_repair_queue
	)

	fence_inventory_changed.emit(fences_available)

	fence_repair_queue_changed.emit(
		broken_fences_in_repair_queue
	)

	fence_stats_changed.emit()
	fence_navigation_changed.emit()

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()
		rebuild_farm_fences()
		rebuild_farm_nightlights()

	print(
		"[Defense] Loaded save data. Turrets: ",
		placed_turrets.size(),
		" | Nightlights: ",
		placed_nightlights.size(),
		" | Fences: ",
		placed_fences.size()
	)

func reset_for_new_game() -> void:
	max_pesticide_turrets = base_max_pesticide_turrets
	pesticide_turret_max_integrity = base_pesticide_turret_max_integrity
	pesticide_turret_max_durability = base_pesticide_turret_max_durability
	pesticide_turrets_available = base_max_pesticide_turrets
	broken_pesticide_turrets_in_repair_queue = 0
	placed_turrets.clear()

	damaged_pesticide_turret_repair_cost_scrap = (
		base_damaged_pesticide_turret_repair_cost_scrap
	)

	pesticide_turret_repair_rate_per_second = (
		base_pesticide_turret_repair_rate_per_second
	)

	fences_available = base_starting_fences
	nightlights_available = base_starting_nightlights
	broken_nightlights_in_repair_queue = 0
	broken_fences_in_repair_queue = 0
	placed_fences.clear()
	placed_nightlights.clear()

	nightlight_max_integrity = base_nightlight_max_integrity
	nightlight_wear_per_second = base_nightlight_wear_per_second
	damaged_nightlight_repair_cost_scrap = (
		base_damaged_nightlight_repair_cost_scrap
	)
	nightlight_repair_rate_per_second = (
		base_nightlight_repair_rate_per_second
	)
	broken_nightlight_repair_scrap_cost = (
		base_broken_nightlight_repair_scrap_cost
	)
	fence_max_health = base_fence_max_health
	fence_repair_rate_per_second = base_fence_repair_rate_per_second
	fence_damage_multiplier = base_fence_damage_multiplier

	_create_starting_perimeter_fences()

	inventory_changed.emit(pesticide_turrets_available)
	nightlight_inventory_changed.emit(nightlights_available)
	nightlight_repair_queue_changed.emit(
		broken_nightlights_in_repair_queue
	)
	turret_repair_queue_changed.emit(
		broken_pesticide_turrets_in_repair_queue
	)

	fence_inventory_changed.emit(fences_available)
	fence_repair_queue_changed.emit(broken_fences_in_repair_queue)

	fence_stats_changed.emit()
	fence_navigation_changed.emit()

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()
		rebuild_farm_fences()
		rebuild_farm_nightlights()

	print("[Defense] Reset for new game.")
	
func _log_telemetry(
	event_name: String,
	event_data: Dictionary = {}
) -> void:
	var telemetry_manager: Node = get_tree().get_first_node_in_group(
		"telemetry_manager"
	)

	if telemetry_manager == null:
		return

	if telemetry_manager.has_method("log_event"):
		telemetry_manager.call("log_event", event_name, event_data)
