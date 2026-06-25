extends Node
class_name DefenseManager

signal inventory_changed(pesticide_turrets_available: int)
signal turret_placed(grid_cell: Vector2i)
signal placement_failed(reason: String)
signal turret_removed(grid_cell: Vector2i)

@export var pesticide_turret_scene: PackedScene

@export var grid_columns: int = 20
@export var grid_rows: int = 14

# Adjust these later only if turret placements do not align with the farm map.
@export var farm_grid_origin: Vector2 = Vector2(-980.0, -680.0)
@export var farm_grid_cell_size: Vector2 = Vector2(98.0, 97.0)

@export var max_pesticide_turrets: int = 2

var pesticide_turrets_available: int = 2
var placed_turret_cells: Array[Vector2i] = []
var active_farm_map: Node = null

func _ready() -> void:
	var map_manager: Node = get_parent().get_node_or_null("MapManager") as Node

	if map_manager != null and map_manager.has_signal("location_loaded"):
		map_manager.connect("location_loaded", Callable(self, "_on_location_loaded"))

func get_pesticide_turrets_available() -> int:
	return pesticide_turrets_available

func is_inside_grid(grid_cell: Vector2i) -> bool:
	return (
		grid_cell.x >= 0
		and grid_cell.x < grid_columns
		and grid_cell.y >= 0
		and grid_cell.y < grid_rows
	)

func get_cell_type(grid_cell: Vector2i) -> String:
	if not is_inside_grid(grid_cell):
		return "outside"

	# Fence border.
	if (
		grid_cell.x == 0
		or grid_cell.x == grid_columns - 1
		or grid_cell.y == 0
		or grid_cell.y == grid_rows - 1
	):
		return "fence"

	# House zone.
	if is_cell_in_range(grid_cell, 2, 5, 2, 4):
		return "house"

	# Truck zone.
	if is_cell_in_range(grid_cell, 14, 16, 2, 3):
		return "truck"

	# Farmland zone.
	if is_cell_in_range(grid_cell, 7, 12, 9, 11):
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

func is_cell_occupied(grid_cell: Vector2i) -> bool:
	return placed_turret_cells.has(grid_cell)

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

	if cell_type == "fence":
		return "Turrets cannot be placed on the fence."

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

	placed_turret_cells.append(grid_cell)
	pesticide_turrets_available -= 1

	inventory_changed.emit(pesticide_turrets_available)
	turret_placed.emit(grid_cell)

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()

	return true

func get_turret_position(grid_cell: Vector2i) -> Vector2:
	var offset_x: float = (float(grid_cell.x) + 0.5) * farm_grid_cell_size.x
	var offset_y: float = (float(grid_cell.y) + 0.5) * farm_grid_cell_size.y

	return farm_grid_origin + Vector2(offset_x, offset_y)

func _on_location_loaded(location_id: String, loaded_map: Node) -> void:
	if location_id == "farm":
		active_farm_map = loaded_map
		rebuild_farm_turrets()
	else:
		active_farm_map = null

func has_placed_turrets() -> bool:
	return not placed_turret_cells.is_empty()

func can_remove_turret(grid_cell: Vector2i) -> bool:
	return is_cell_occupied(grid_cell)

func remove_pesticide_turret(grid_cell: Vector2i) -> bool:
	if not can_remove_turret(grid_cell):
		placement_failed.emit("There is no turret placed on this grid cell.")
		return false

	placed_turret_cells.erase(grid_cell)
	pesticide_turrets_available = mini(
		pesticide_turrets_available + 1,
		max_pesticide_turrets
	)

	inventory_changed.emit(pesticide_turrets_available)
	turret_removed.emit(grid_cell)

	if active_farm_map != null and is_instance_valid(active_farm_map):
		rebuild_farm_turrets()

	return true

func rebuild_farm_turrets() -> void:
	if pesticide_turret_scene == null:
		print("Pesticide turret scene is not assigned.")
		return

	if active_farm_map == null:
		return

	var placement_root: Node2D = active_farm_map.get_node_or_null("TurretPlacementRoot") as Node2D

	if placement_root == null:
		print("Farm map is missing TurretPlacementRoot.")
		return

	for child in placement_root.get_children():
		child.queue_free()

	for placed_cell in placed_turret_cells:
		var grid_cell: Vector2i = placed_cell
		var turret: Node2D = pesticide_turret_scene.instantiate() as Node2D

		if turret == null:
			continue

		turret.position = get_turret_position(grid_cell)
		placement_root.add_child(turret)
