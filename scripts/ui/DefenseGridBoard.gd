extends Control
class_name DefenseGridBoard

signal grid_cell_clicked(grid_cell: Vector2i)

@export var columns: int = 20
@export var rows: int = 14

var defense_manager: Node = null
var selected_item_id: String = ""
var hover_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)

func configure(new_defense_manager: Node, new_selected_item_id: String) -> void:
	defense_manager = new_defense_manager
	selected_item_id = new_selected_item_id
	queue_redraw()

func can_remove(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method("can_remove_turret"):
		return bool(defense_manager.call("can_remove_turret", grid_cell))

	return false

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.25, 0.14))

	for row_index in range(rows):
		for column_index in range(columns):
			var grid_cell: Vector2i = Vector2i(column_index, row_index)
			var cell_rect: Rect2 = get_cell_rect(grid_cell)
			var cell_type: String = get_cell_type(grid_cell)

			var fill_color: Color = get_cell_color(cell_type)

			if grid_cell == hover_cell:
				if selected_item_id == "pesticide_turret":
					if can_place(grid_cell):
						fill_color = Color(0.20, 0.45, 0.90, 0.85)
					else:
						fill_color = Color(0.80, 0.15, 0.15, 0.85)

				elif selected_item_id == "remove_turret":
					if can_remove(grid_cell):
						fill_color = Color(0.90, 0.35, 0.15, 0.90)
					else:
						fill_color = Color(0.45, 0.10, 0.10, 0.70)

			draw_rect(cell_rect, fill_color)
			draw_rect(cell_rect, Color(0.55, 0.65, 0.70, 0.55), false, 1.0)

			if is_occupied(grid_cell):
				draw_circle(
					cell_rect.get_center(),
					min(cell_rect.size.x, cell_rect.size.y) * 0.24,
					Color(0.25, 0.95, 0.40)
				)

func get_cell_rect(grid_cell: Vector2i) -> Rect2:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	var cell_position: Vector2 = Vector2(
		float(grid_cell.x) * cell_width,
		float(grid_cell.y) * cell_height
	)

	return Rect2(cell_position, Vector2(cell_width, cell_height))

func get_cell_from_position(local_position: Vector2) -> Vector2i:
	var cell_width: float = size.x / float(columns)
	var cell_height: float = size.y / float(rows)

	var cell_x: int = int(floor(local_position.x / cell_width))
	var cell_y: int = int(floor(local_position.y / cell_height))

	return Vector2i(cell_x, cell_y)

func is_inside_grid(grid_cell: Vector2i) -> bool:
	return (
		grid_cell.x >= 0
		and grid_cell.x < columns
		and grid_cell.y >= 0
		and grid_cell.y < rows
	)

func get_cell_type(grid_cell: Vector2i) -> String:
	if defense_manager != null and defense_manager.has_method("get_cell_type"):
		return str(defense_manager.call("get_cell_type", grid_cell))

	return "outside"

func can_place(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method("can_place_pesticide_turret"):
		return bool(defense_manager.call("can_place_pesticide_turret", grid_cell))

	return false

func is_occupied(grid_cell: Vector2i) -> bool:
	if defense_manager != null and defense_manager.has_method("is_cell_occupied"):
		return bool(defense_manager.call("is_cell_occupied", grid_cell))

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
		"fence":
			return Color(0.18, 0.12, 0.06)
		_:
			return Color(0.10, 0.10, 0.10)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		hover_cell = get_cell_from_position(motion_event.position)
		queue_redraw()

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var clicked_cell: Vector2i = get_cell_from_position(mouse_event.position)

			if is_inside_grid(clicked_cell):
				grid_cell_clicked.emit(clicked_cell)

			accept_event()

func _on_mouse_exited() -> void:
	hover_cell = Vector2i(-1, -1)
	queue_redraw()
