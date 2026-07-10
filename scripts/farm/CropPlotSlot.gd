extends Node2D
class_name CropPlotSlot

@export var debug_crop_slot_logging: bool = false

const SLOT_SIZE: float = 30.0

@onready var plot_area: Area2D = $PlotArea
@onready var collision_shape: CollisionShape2D = (
	$PlotArea/CollisionShape2D
)
@onready var hover_label: Label = $HoverLabel

var crop_manager: CropManager = null
var grid_cell: Vector2i = Vector2i.ZERO
var is_hovered: bool = false
var click_locked: bool = false

func _ready() -> void:
	_setup_input_area()

	plot_area.mouse_entered.connect(_on_mouse_entered)
	plot_area.mouse_exited.connect(_on_mouse_exited)
	plot_area.input_event.connect(_on_plot_input_event)

	hover_label.visible = false
	queue_redraw()

func configure_slot(
	new_crop_manager: CropManager,
	new_grid_cell: Vector2i
) -> void:
	crop_manager = new_crop_manager
	grid_cell = new_grid_cell

	if not crop_manager.crop_data_changed.is_connected(
		_on_crop_data_changed
	):
		crop_manager.crop_data_changed.connect(
			_on_crop_data_changed
		)

	_refresh_visual()

func _setup_input_area() -> void:
	var rectangle_shape: RectangleShape2D = (
		collision_shape.shape as RectangleShape2D
	)

	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		collision_shape.shape = rectangle_shape

	rectangle_shape.size = Vector2(SLOT_SIZE, SLOT_SIZE)

	# Layer 5 is reserved for crop-click input only.
	plot_area.collision_layer = 16
	plot_area.collision_mask = 0
	plot_area.input_pickable = true

func _draw() -> void:
	var slot_rect: Rect2 = Rect2(
		Vector2(-SLOT_SIZE / 2.0, -SLOT_SIZE / 2.0),
		Vector2(SLOT_SIZE, SLOT_SIZE)
	)

	var crop_state: String = "empty"

	if crop_manager != null:
		crop_state = crop_manager.get_crop_state(grid_cell)

	draw_rect(
		slot_rect,
		Color(0.20, 0.10, 0.03, 0.18)
	)

	draw_rect(
		slot_rect,
		Color(0.72, 0.45, 0.12, 0.70),
		false,
		1.0
	)

	match crop_state:
		"growing":
			draw_circle(
				Vector2.ZERO,
				7.0,
				Color(0.25, 0.65, 0.20)
			)

		"ready":
			draw_circle(
				Vector2.ZERO,
				10.0,
				Color(0.92, 0.78, 0.18)
			)

	if is_hovered:
		draw_rect(
			slot_rect.grow(1.0),
			Color(0.92, 0.92, 0.92, 0.95),
			false,
			1.5
		)

func _refresh_visual() -> void:
	if crop_manager == null:
		return

	hover_label.text = crop_manager.get_crop_hover_text(grid_cell)
	hover_label.visible = is_hovered

	queue_redraw()

func _on_mouse_entered() -> void:
	is_hovered = true

	if debug_crop_slot_logging:
		print("[Crop Slot] Mouse entered: ", grid_cell)

	_refresh_visual()

func _on_mouse_exited() -> void:
	is_hovered = false

	if debug_crop_slot_logging:
		print("[Crop Slot] Mouse exited: ", grid_cell)

	hover_label.visible = false
	queue_redraw()

func _on_plot_input_event(
	_viewport: Node,
	event: InputEvent,
	_shape_index: int
) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not mouse_event.pressed:
		click_locked = false
		return

	if click_locked:
		return

	click_locked = true

	if crop_manager == null:
		print("[Crop Slot] Click received, but CropManager is missing.")
		return

	if debug_crop_slot_logging:
		print("[Crop Slot] Left-clicked: ", grid_cell)

	crop_manager.request_crop_slot_interaction(grid_cell)
	get_viewport().set_input_as_handled()

func _on_crop_data_changed() -> void:
	_refresh_visual()
