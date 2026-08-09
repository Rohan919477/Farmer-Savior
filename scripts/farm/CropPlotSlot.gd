extends Node2D
class_name CropPlotSlot

@export var debug_crop_slot_logging: bool = false
const BASIC_CROP_GROWING_TEXTURE: Texture2D = preload(
	"res://sprites/farm/crops/BasicCrop_growing_01.png"
)
const BASIC_CROP_READY_TEXTURE: Texture2D = preload(
	"res://sprites/farm/crops/BasicCrop_ready_01.png"
)
const MUTANT_CROP_GROWING_TEXTURE: Texture2D = preload(
	"res://sprites/farm/crops/MutantCrop_growing_01.png"
)
const MUTANT_CROP_READY_TEXTURE: Texture2D = preload(
	"res://sprites/farm/crops/MutantCrop_ready_01.png"
)
const SLOT_SIZE: float = 30.0

@onready var plot_area: Area2D = $PlotArea
@onready var collision_shape: CollisionShape2D = (
	$PlotArea/CollisionShape2D
)
@onready var hover_label: Label = $HoverLabel
var crop_sprite: Sprite2D = null

var crop_manager: CropManager = null
var grid_cell: Vector2i = Vector2i.ZERO
var is_hovered: bool = false
var click_locked: bool = false
var crop_input_enabled: bool = true

func _ready() -> void:
	_ensure_crop_sprite()
	_setup_input_area()

	plot_area.mouse_entered.connect(_on_mouse_entered)
	plot_area.mouse_exited.connect(_on_mouse_exited)
	plot_area.input_event.connect(_on_plot_input_event)

	hover_label.visible = false
	_refresh_crop_sprite()
	queue_redraw()


func _process(_delta: float) -> void:
	_update_crop_input_enabled()


func _update_crop_input_enabled() -> void:
	var should_enable_input: bool = true

	if crop_manager != null and crop_manager.has_method("is_daytime"):
		should_enable_input = bool(crop_manager.call("is_daytime"))

	if crop_input_enabled == should_enable_input:
		return

	crop_input_enabled = should_enable_input

	if plot_area != null:
		plot_area.input_pickable = crop_input_enabled

	if not crop_input_enabled:
		is_hovered = false
		click_locked = false

		if hover_label != null:
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

	_update_crop_input_enabled()
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

	_refresh_crop_sprite()
	queue_redraw()

func _ensure_crop_sprite() -> void:
	if crop_sprite != null:
		return

	if has_node("CropSprite"):
		crop_sprite = $CropSprite as Sprite2D
	else:
		crop_sprite = Sprite2D.new()
		crop_sprite.name = "CropSprite"
		add_child(crop_sprite)

	crop_sprite.centered = true
	crop_sprite.position = Vector2.ZERO
	crop_sprite.scale = Vector2(0.04, 0.04)
	crop_sprite.z_index = 20
	crop_sprite.visible = false

func _on_mouse_entered() -> void:
	is_hovered = true

	if debug_crop_slot_logging:
		print("[Crop Slot] Mouse entered: ", grid_cell)

	_refresh_visual()
	
func _refresh_crop_sprite() -> void:
	_ensure_crop_sprite()

	if crop_sprite == null:
		return

	if crop_manager == null:
		crop_sprite.visible = false
		crop_sprite.texture = null
		return

	var crop_state: String = crop_manager.get_crop_state(grid_cell)

	if crop_state == CropManager.CROP_STATE_EMPTY:
		crop_sprite.visible = false
		crop_sprite.texture = null
		return

	var crop_data: Dictionary = crop_manager.get_crop_data(grid_cell)
	var crop_id: String = str(crop_data.get("crop_id", ""))

	var selected_texture: Texture2D = null

	if crop_id == CropManager.BASIC_CROP_ID:
		if crop_state == CropManager.CROP_STATE_GROWING:
			selected_texture = BASIC_CROP_GROWING_TEXTURE
		elif crop_state == CropManager.CROP_STATE_READY:
			selected_texture = BASIC_CROP_READY_TEXTURE

	elif crop_id == CropManager.MUTANT_CROP_ID:
		if crop_state == CropManager.CROP_STATE_GROWING:
			selected_texture = MUTANT_CROP_GROWING_TEXTURE
		elif crop_state == CropManager.CROP_STATE_READY:
			selected_texture = MUTANT_CROP_READY_TEXTURE

	if selected_texture == null:
		print(
			"[Crop Slot] No texture selected. Cell: ",
			grid_cell,
			" | State: ",
			crop_state,
			" | Crop ID: ",
			crop_id
		)

	crop_sprite.texture = selected_texture
	crop_sprite.visible = selected_texture != null
	crop_sprite.z_index = 20

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

	if crop_manager.has_method("is_daytime"):
		if not bool(crop_manager.call("is_daytime")):
			# Do not consume nighttime clicks. The player must be able
			# to shoot over the farm plot during night combat.
			click_locked = false
			return

	if debug_crop_slot_logging:
		print("[Crop Slot] Left-clicked: ", grid_cell)

	crop_manager.request_crop_slot_interaction(grid_cell)
	get_viewport().set_input_as_handled()

func _on_crop_data_changed() -> void:
	_refresh_visual()
