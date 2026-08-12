extends RefCounted

# Pure geometry helpers used by DefenseManager. This script intentionally owns
# no gameplay state, signals, scene references, inventory, health, or save data.
# DefenseManager remains the public facade used by the rest of the game.

static func is_inside_grid(
	grid_cell: Vector2i,
	grid_columns: int,
	grid_rows: int
) -> bool:
	return (
		grid_cell.x >= 0
		and grid_cell.x < grid_columns
		and grid_cell.y >= 0
		and grid_cell.y < grid_rows
	)

static func is_boundary_cell(
	grid_cell: Vector2i,
	grid_columns: int,
	grid_rows: int
) -> bool:
	return (
		grid_cell.x == 0
		or grid_cell.x == grid_columns - 1
		or grid_cell.y == 0
		or grid_cell.y == grid_rows - 1
	)

static func is_cell_in_range(
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

static func get_cell_type(
	grid_cell: Vector2i,
	grid_columns: int,
	grid_rows: int
) -> String:
	if not is_inside_grid(grid_cell, grid_columns, grid_rows):
		return "outside"

	if is_boundary_cell(grid_cell, grid_columns, grid_rows):
		return "boundary"

	# Farmhouse zone. Keep it unavailable for defence placement.
	if is_cell_in_range(grid_cell, 5, 15, 4, 12):
		return "house"

	# Truck zone. Keep it unavailable for defence placement.
	if is_cell_in_range(grid_cell, 42, 50, 4, 9):
		return "truck"

	# Crop/farmland zone near the lower centre of the farm.
	if is_cell_in_range(grid_cell, 18, 37, 28, 36):
		return "farmland"

	return "open"

static func get_cell_center_world_position(
	grid_cell: Vector2i,
	farm_grid_origin: Vector2,
	farm_grid_cell_size: Vector2
) -> Vector2:
	return farm_grid_origin + Vector2(
		(float(grid_cell.x) + 0.5) * farm_grid_cell_size.x,
		(float(grid_cell.y) + 0.5) * farm_grid_cell_size.y
	)

static func is_valid_fence_orientation(
	orientation: String,
	horizontal_orientation: String,
	vertical_orientation: String
) -> bool:
	return (
		orientation == horizontal_orientation
		or orientation == vertical_orientation
	)

static func is_valid_fence_edge(
	orientation: String,
	grid_edge: Vector2i,
	grid_columns: int,
	grid_rows: int,
	horizontal_orientation: String,
	vertical_orientation: String
) -> bool:
	if orientation == horizontal_orientation:
		return (
			grid_edge.x >= 0
			and grid_edge.x < grid_columns
			and grid_edge.y >= 0
			and grid_edge.y <= grid_rows
		)

	if orientation == vertical_orientation:
		return (
			grid_edge.x >= 0
			and grid_edge.x <= grid_columns
			and grid_edge.y >= 0
			and grid_edge.y < grid_rows
		)

	return false

static func get_fence_key(
	orientation: String,
	grid_edge: Vector2i
) -> String:
	return "%s:%d:%d" % [
		orientation,
		grid_edge.x,
		grid_edge.y
	]

static func get_cells_touching_fence_edge(
	orientation: String,
	grid_edge: Vector2i,
	grid_columns: int,
	grid_rows: int,
	horizontal_orientation: String,
	vertical_orientation: String
) -> Array[Vector2i]:
	var touching_cells: Array[Vector2i] = []

	if orientation == horizontal_orientation:
		if grid_edge.y > 0:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y - 1)
			)

		if grid_edge.y < grid_rows:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y)
			)

	elif orientation == vertical_orientation:
		if grid_edge.x > 0:
			touching_cells.append(
				Vector2i(grid_edge.x - 1, grid_edge.y)
			)

		if grid_edge.x < grid_columns:
			touching_cells.append(
				Vector2i(grid_edge.x, grid_edge.y)
			)

	return touching_cells

static func get_fence_world_position(
	orientation: String,
	grid_edge: Vector2i,
	farm_grid_origin: Vector2,
	farm_grid_cell_size: Vector2,
	horizontal_orientation: String
) -> Vector2:
	if orientation == horizontal_orientation:
		return farm_grid_origin + Vector2(
			(float(grid_edge.x) + 0.5) * farm_grid_cell_size.x,
			float(grid_edge.y) * farm_grid_cell_size.y
		)

	return farm_grid_origin + Vector2(
		float(grid_edge.x) * farm_grid_cell_size.x,
		(float(grid_edge.y) + 0.5) * farm_grid_cell_size.y
	)

static func get_fence_world_rotation(
	orientation: String,
	vertical_orientation: String
) -> float:
	if orientation == vertical_orientation:
		return PI / 2.0
	return 0.0

static func get_exterior_side_for_world_position(
	world_position: Vector2,
	farm_grid_origin: Vector2,
	farm_grid_cell_size: Vector2,
	grid_columns: int,
	grid_rows: int
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

static func is_world_position_inside_farm_perimeter(
	world_position: Vector2,
	farm_grid_origin: Vector2,
	farm_grid_cell_size: Vector2,
	grid_columns: int,
	grid_rows: int
) -> bool:
	var farm_left: float = farm_grid_origin.x
	var farm_top: float = farm_grid_origin.y
	var farm_right: float = (
		farm_left + float(grid_columns) * farm_grid_cell_size.x
	)
	var farm_bottom: float = (
		farm_top + float(grid_rows) * farm_grid_cell_size.y
	)

	return (
		world_position.x > farm_left
		and world_position.x < farm_right
		and world_position.y > farm_top
		and world_position.y < farm_bottom
	)
