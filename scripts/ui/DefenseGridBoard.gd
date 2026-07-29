extends Control
class_name DefenseGridBoard

signal grid_cell_clicked(grid_cell: Vector2i)
signal grid_cell_right_clicked(grid_cell: Vector2i)

signal fence_edge_clicked(
	orientation: String,
	grid_edge: Vector2i
)

signal fence_edge_right_clicked(
	orientation: String,
	grid_edge: Vector2i
)

const ITEM_PESTICIDE_TURRET: String = "pesticide_turret"
const ITEM_FENCE: String = "fence"
const ITEM_NIGHTLIGHT: String = "nightlight"

@export var columns: int = 40
@export var rows: int = 28

var defense_manager: Node = null
var selected_item_id: String = ""

var hover_cell: Vector2i = Vector2i(-1, -1)
var hover_local_position: Vector2 = Vector2(-9999.0, -9999.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)

func configure(
	new_defense_manager: Node,
	new_selected_item_id: String
) -> void:
	defense_manager = new_defense_manager
	selected_item_id = new_selected_item_id

	if defense_manager != null:
		if defense_manager.has_method("get_grid_columns"):
			columns = int(defense_manager.call("get_grid_columns"))

		if defense_manager.has_method("get_grid_rows"):
			rows = int(defense_manager.call("get_grid_rows"))

	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(
		Rect2(Vector2.ZERO, size),
		Color(0.12, 0.25, 0.14)
	)

	for row_index in range(rows):
		for column_index in range(columns):
			var grid_cell: Vector2i = Vector2i(
				column_index,
				row_index
			)

			var cell_rect: Rect2 = get_cell_rect(grid_cell)
			var cell_type: String = get_cell_type(grid_cell)

			var fill_color: Color = get_cell_color(cell_type)

			if grid_cell == hover_cell:
				fill_color = _get_hover_cell_color(
					grid_cell,
					fill_color
				)

			draw_rect(cell_rect, fill_color)

			draw_rect(
				cell_rect,
				Color(0.55, 0.65, 0.70, 0.45),
				false,
				1.0
			)

			if is_turret_occupied(grid_cell):
				_draw_turret_marker(cell_rect)

			if is_nightlight_occupied(grid_cell):
				_draw_nightlight_marker(cell_rect)

	_draw_placed_fences()
	_draw_fence_hover_preview()

func _get_hover_cell_color(
	grid_cell: Vector2i,
	default_color: Color
) -> Color:
	if selected_item_id == ITEM_PESTICIDE_TURRET:
		if can_place_turret(grid_cell):
			return Color(0.20, 0.45, 0.90, 0.85)

		return Color(0.80, 0.15, 0.15, 0.85)

	if selected_item_id == ITEM_NIGHTLIGHT:
		if can_place_nightlight(grid_cell):
			return Color(0.95, 0.72, 0.22, 0.88)

		return Color(0.80, 0.15, 0.15, 0.85)

	if is_turret_occupied(grid_cell) or is_nightlight_occupied(grid_cell):
		return Color(0.90, 0.42, 0.12, 0.90)

	return default_color

func _draw_turret_marker(cell_rect: Rect2) -> void:
	var center: Vector2 = cell_rect.get_center()
	var radius: float = min(cell_rect.size.x, cell_rect.size.y) * 0.24

	draw_circle(
		center,
		radius,
		Color(0.25, 0.95, 0.40)
	)

	draw_circle(
		center,
		radius * 0.45,
		Color(0.08, 0.30, 0.12)
	)

func _draw_nightlight_marker(cell_rect: Rect2) -> void:
	var center: Vector2 = cell_rect.get_center()
	var radius: float = min(cell_rect.size.x, cell_rect.size.y) * 0.25

	draw_circle(
		center,
		radius * 1.35,
		Color(1.0, 0.72, 0.24, 0.24)
	)

	draw_circle(
		center,
		radius,
		Color(0.95, 0.58, 0.18)
	)

	draw_circle(
		center,
		radius * 0.42,
		Color(0.18, 0.10, 0.04)
	)

func _draw_placed_fences() -> void:
	if defense_manager == null:
		return

	if not defense_manager.has_method("get_placed_fence_keys"):
		return

	var fence_keys: Array = defense_manager.call(
		"get_placed_fence_keys"
	)

	for fence_key_variant in fence_keys:
		var fence_key: String = str(fence_key_variant)

		if not defense_manager.has_method("get_fence_data"):
			continue

		var fence_data: Dictionary = defense_manager.call(
			"get_fence_data",
			fence_key
		)

		var orientation: String = str(
			fence_data.get("orientation", "")
		)

		var grid_edge: Vector2i = fence_data.get(
			"grid_edge",
			Vector2i.ZERO
		)

		var fence_state: String = str(
			defense_manager.call("get_fence_state", fence_key)
		)

		_draw_fence_line(
			orientation,
			grid_edge,
			get_fence_state_color(fence_state),
			4.0,
			fence_state == "broken"
		)

func _draw_fence_hover_preview() -> void:
	if selected_item_id != ITEM_FENCE:
		return

	if not is_hovering_grid():
		return

	var edge_data: Dictionary = get_nearest_fence_edge(
		hover_local_position
	)

	var orientation: String = str(
		edge_data.get("orientation", "")
	)

	var grid_edge: Vector2i = edge_data.get(
		"grid_edge",
		Vector2i.ZERO
	)

	var preview_color: Color = Color(0.20, 0.90, 0.35, 0.90)

	if not can_place_fence(orientation, grid_edge):
		preview_color = Color(0.90, 0.18, 0.18, 0.90)

	_draw_fence_line(
		orientation,
		grid_edge,
		preview_color,
		4.0,
		false
	)

func _draw_fence_line(
	orientation: String,
	grid_edge: Vector2i,
	line_color: Color,
	line_width: float,
	is_broken: bool
) -> void:
	var line_start: Vector2 = get_fence_line_start(
		orientation,
		grid_edge
	)

	var line_end: Vector2 = get_fence_line_end(
		orientation,
		grid_edge
	)

	if not is_broken:
		draw_line(
			line_start,
			line_end,
			line_color,
			line_width,
			true
		)
		return

	var direction: Vector2 = line_end - line_start

	draw_line(
		line_start,
		line_start + direction * 0.28,
		line_color,
		line_width,
		true
	)

	draw_line(
		line_start + direction * 0.72,
		line_end,
		line_color,
		line_width,
		true
	)

func get_fence_line_start(
	orientation: String,
	grid_edge: Vector2i
) -> Vector2:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	if orientation == "horizontal":
		return Vector2(
			float(grid_edge.x) * cell_width,
			float(grid_edge.y) * cell_height
		)

	return Vector2(
		float(grid_edge.x) * cell_width,
		float(grid_edge.y) * cell_height
	)

func get_fence_line_end(
	orientation: String,
	grid_edge: Vector2i
) -> Vector2:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	if orientation == "horizontal":
		return Vector2(
			float(grid_edge.x + 1) * cell_width,
			float(grid_edge.y) * cell_height
		)

	return Vector2(
		float(grid_edge.x) * cell_width,
		float(grid_edge.y + 1) * cell_height
	)

func get_fence_state_color(fence_state: String) -> Color:
	match fence_state:
		"perfect":
			return Color(0.50, 0.28, 0.08)
		"damaged":
			return Color(0.95, 0.60, 0.10)
		"broken":
			return Color(0.38, 0.12, 0.08)
		_:
			return Color(0.50, 0.28, 0.08)

func get_cell_rect(grid_cell: Vector2i) -> Rect2:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	var cell_position: Vector2 = Vector2(
		float(grid_cell.x) * cell_width,
		float(grid_cell.y) * cell_height
	)

	return Rect2(
		cell_position,
		Vector2(cell_width, cell_height)
	)

func get_cell_from_position(
	local_position: Vector2
) -> Vector2i:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	var cell_x: int = clampi(
		int(floor(local_position.x / cell_width)),
		0,
		columns - 1
	)

	var cell_y: int = clampi(
		int(floor(local_position.y / cell_height)),
		0,
		rows - 1
	)

	return Vector2i(cell_x, cell_y)

func get_nearest_fence_edge(
	local_position: Vector2
) -> Dictionary:
	var grid_cell: Vector2i = get_cell_from_position(
		local_position
	)

	var cell_rect: Rect2 = get_cell_rect(grid_cell)

	var distance_left: float = absf(
		local_position.x - cell_rect.position.x
	)

	var distance_right: float = absf(
		cell_rect.end.x - local_position.x
	)

	var distance_top: float = absf(
		local_position.y - cell_rect.position.y
	)

	var distance_bottom: float = absf(
		cell_rect.end.y - local_position.y
	)

	var smallest_distance: float = distance_left
	var orientation: String = "vertical"
	var grid_edge: Vector2i = Vector2i(
		grid_cell.x,
		grid_cell.y
	)

	if distance_right < smallest_distance:
		smallest_distance = distance_right
		orientation = "vertical"
		grid_edge = Vector2i(
			grid_cell.x + 1,
			grid_cell.y
		)

	if distance_top < smallest_distance:
		smallest_distance = distance_top
		orientation = "horizontal"
		grid_edge = Vector2i(
			grid_cell.x,
			grid_cell.y
		)

	if distance_bottom < smallest_distance:
		orientation = "horizontal"
		grid_edge = Vector2i(
			grid_cell.x,
			grid_cell.y + 1
		)

	return {
		"orientation": orientation,
		"grid_edge": grid_edge
	}

func is_inside_grid(grid_cell: Vector2i) -> bool:
	return (
		grid_cell.x >= 0
		and grid_cell.x < columns
		and grid_cell.y >= 0
		and grid_cell.y < rows
	)

func is_hovering_grid() -> bool:
	return (
		hover_local_position.x >= 0.0
		and hover_local_position.y >= 0.0
		and hover_local_position.x <= size.x
		and hover_local_position.y <= size.y
	)

func get_cell_type(grid_cell: Vector2i) -> String:
	if defense_manager != null and defense_manager.has_method(
		"get_cell_type"
	):
		return str(
			defense_manager.call(
				"get_cell_type",
				grid_cell
			)
		)

	return "outside"

func can_place_turret(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method(
		"can_place_pesticide_turret"
	):
		return bool(
			defense_manager.call(
				"can_place_pesticide_turret",
				grid_cell
			)
		)

	return false

func can_place_nightlight(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method(
		"can_place_nightlight"
	):
		return bool(
			defense_manager.call(
				"can_place_nightlight",
				grid_cell
			)
		)

	return false

func can_place_fence(
	orientation: String,
	grid_edge: Vector2i
) -> bool:
	if defense_manager != null and defense_manager.has_method(
		"can_place_fence"
	):
		return bool(
			defense_manager.call(
				"can_place_fence",
				orientation,
				grid_edge
			)
		)

	return false

func is_turret_occupied(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method(
		"has_turret"
	):
		return bool(
			defense_manager.call(
				"has_turret",
				grid_cell
			)
		)

	return false

func is_nightlight_occupied(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method(
		"has_nightlight"
	):
		return bool(
			defense_manager.call(
				"has_nightlight",
				grid_cell
			)
		)

	return false

func get_cell_color(cell_type: String) -> Color:
	match cell_type:
		"open":
			return Color(0.25, 0.55, 0.28)
		"house":
			return Color(0.72, 0.18, 0.18)
		"truck":
			return Color(0.08, 0.18, 0.42)
		"farmland":
			return Color(0.40, 0.24, 0.10)
		"boundary":
			return Color(0.18, 0.12, 0.06)
		_:
			return Color(0.10, 0.10, 0.10)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		hover_local_position = motion_event.position
		hover_cell = get_cell_from_position(
			hover_local_position
		)

		queue_redraw()
		return

	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event

	if not mouse_event.pressed:
		return

	if not is_hovering_grid():
		return

	var clicked_cell: Vector2i = get_cell_from_position(
		mouse_event.position
	)

	var edge_data: Dictionary = get_nearest_fence_edge(
		mouse_event.position
	)

	var orientation: String = str(
		edge_data.get("orientation", "")
	)

	var grid_edge: Vector2i = edge_data.get(
		"grid_edge",
		Vector2i.ZERO
	)

	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if selected_item_id == ITEM_FENCE:
			fence_edge_clicked.emit(orientation, grid_edge)
		else:
			grid_cell_clicked.emit(clicked_cell)

		accept_event()

	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		var fence_key: String = ""

		if defense_manager != null and defense_manager.has_method(
			"get_fence_key"
		):
			fence_key = str(
				defense_manager.call(
					"get_fence_key",
					orientation,
					grid_edge
				)
			)

		if (
			not fence_key.is_empty()
			and defense_manager != null
			and defense_manager.has_method("has_fence")
			and bool(
				defense_manager.call(
					"has_fence",
					fence_key
				)
			)
		):
			fence_edge_right_clicked.emit(
				orientation,
				grid_edge
			)
		else:
			grid_cell_right_clicked.emit(clicked_cell)

		accept_event()

func _on_mouse_exited() -> void:
	hover_cell = Vector2i(-1, -1)
	hover_local_position = Vector2(-9999.0, -9999.0)
	queue_redraw()
