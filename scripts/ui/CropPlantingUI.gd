extends CanvasLayer
class_name CropPlantingUI

const SEED_BASIC: String = "basic"
const SEED_MUTANT: String = "mutant"

@onready var root_control: Control = $RootControl
@onready var seed_panel: Control = $RootControl/SeedPanel

@onready var title_label: Label = $RootControl/SeedPanel/TitleLabel

@onready var description_label: Label = (
	$RootControl/SeedPanel/DescriptionLabel
)

@onready var seed_count_label: Label = (
	$RootControl/SeedPanel/SeedCountLabel
)

@onready var basic_crop_button: Button = (
	$RootControl/SeedPanel/BasicCropButton
)

@onready var mutant_crop_button: Button = (
	get_node_or_null(
		"RootControl/SeedPanel/MutantCropButton"
	) as Button
)

@onready var status_label: Label = $RootControl/SeedPanel/StatusLabel

@onready var cancel_button: Button = (
	$RootControl/SeedPanel/CancelButton
)

@onready var crop_info_panel: Panel = (
	get_node_or_null("RootControl/CropInfoPanel") as Panel
)

@onready var crop_info_label: Label = (
	get_node_or_null("RootControl/CropInfoPanel/CropInfoLabel") as Label
)

@onready var remove_crop_button: Button = (
	get_node_or_null("RootControl/CropInfoPanel/RemoveCropButton") as Button
)

@onready var close_info_button: Button = (
	get_node_or_null("RootControl/CropInfoPanel/CloseInfoButton") as Button
)

@onready var seed_tooltip_panel: Panel = (
	get_node_or_null("RootControl/SeedTooltipPanel") as Panel
)

@onready var tooltip_title_label: Label = (
	get_node_or_null("RootControl/SeedTooltipPanel/TooltipTitleLabel") as Label
)

@onready var tooltip_type_label: Label = (
	get_node_or_null("RootControl/SeedTooltipPanel/TooltipTypeLabel") as Label
)

@onready var tooltip_description_label: Label = (
	get_node_or_null("RootControl/SeedTooltipPanel/TooltipDescriptionLabel")
	as Label
)

var crop_manager: CropManager = null
var selected_grid_cell: Vector2i = Vector2i(-1, -1)
var hovered_seed_id: String = ""

func _ready() -> void:
	visible = false
	_apply_ui_style()

	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seed_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	basic_crop_button.focus_mode = Control.FOCUS_NONE

	if mutant_crop_button != null:
		mutant_crop_button.focus_mode = Control.FOCUS_NONE

	cancel_button.focus_mode = Control.FOCUS_NONE

	if crop_info_panel != null:
		crop_info_panel.visible = false
		crop_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if crop_info_label != null:
		crop_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if remove_crop_button != null:
		remove_crop_button.focus_mode = Control.FOCUS_NONE
		remove_crop_button.pressed.connect(_on_remove_crop_pressed)

	if close_info_button != null:
		close_info_button.focus_mode = Control.FOCUS_NONE
		close_info_button.pressed.connect(_on_cancel_pressed)

	if seed_tooltip_panel != null:
		seed_tooltip_panel.visible = false
		seed_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if tooltip_description_label != null:
		tooltip_description_label.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)

	basic_crop_button.pressed.connect(_on_basic_crop_pressed)
	basic_crop_button.mouse_entered.connect(
		_on_seed_slot_mouse_entered.bind(SEED_BASIC)
	)
	basic_crop_button.mouse_exited.connect(_on_seed_slot_mouse_exited)

	if mutant_crop_button != null:
		mutant_crop_button.pressed.connect(_on_mutant_crop_pressed)
		mutant_crop_button.mouse_entered.connect(
			_on_seed_slot_mouse_entered.bind(SEED_MUTANT)
		)
		mutant_crop_button.mouse_exited.connect(_on_seed_slot_mouse_exited)

	cancel_button.pressed.connect(_on_cancel_pressed)

	get_viewport().size_changed.connect(_layout_ui)

	call_deferred("_connect_crop_manager")
	call_deferred("_layout_ui")

func _process(_delta: float) -> void:
	if not visible:
		return

	if seed_tooltip_panel != null and seed_tooltip_panel.visible:
		_position_seed_tooltip_near_mouse()

func _connect_crop_manager() -> void:
	crop_manager = get_tree().get_first_node_in_group(
		"crop_manager"
	) as CropManager

	if crop_manager == null:
		print("CropPlantingUI could not find CropManager.")
		return

	if not crop_manager.planting_menu_requested.is_connected(
		_on_planting_menu_requested
	):
		crop_manager.planting_menu_requested.connect(
			_on_planting_menu_requested
		)

	if crop_manager.has_signal("crop_inspection_requested"):
		if not crop_manager.crop_inspection_requested.is_connected(
			_on_crop_inspection_requested
		):
			crop_manager.crop_inspection_requested.connect(
				_on_crop_inspection_requested
			)

	if not crop_manager.planting_menu_closed.is_connected(
		_on_planting_menu_closed
	):
		crop_manager.planting_menu_closed.connect(
			_on_planting_menu_closed
		)

	if not crop_manager.planting_result.is_connected(
		_on_planting_result
	):
		crop_manager.planting_result.connect(
			_on_planting_result
		)

func _layout_ui() -> void:
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	root_control.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var panel_size: Vector2 = Vector2(500.0, 360.0)

	seed_panel.position = (
		viewport_size - panel_size
	) * 0.5

	seed_panel.size = panel_size

	var padding: float = 26.0
	var content_width: float = panel_size.x - padding * 2.0

	title_label.position = Vector2(padding, 18.0)
	title_label.size = Vector2(content_width, 28.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	description_label.position = Vector2(padding, 52.0)
	description_label.size = Vector2(content_width, 44.0)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	seed_count_label.position = Vector2(padding, 106.0)
	seed_count_label.size = Vector2(content_width, 24.0)
	seed_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var slot_size: Vector2 = Vector2(150.0, 116.0)
	var slot_gap: float = 32.0
	var total_slot_width: float = slot_size.x * 2.0 + slot_gap
	var slot_start_x: float = (panel_size.x - total_slot_width) * 0.5
	var slot_y: float = 148.0

	basic_crop_button.position = Vector2(slot_start_x, slot_y)
	basic_crop_button.size = slot_size

	if mutant_crop_button != null:
		mutant_crop_button.position = Vector2(
			slot_start_x + slot_size.x + slot_gap,
			slot_y
		)
		mutant_crop_button.size = slot_size

	status_label.position = Vector2(padding, 274.0)
	status_label.size = Vector2(content_width, 32.0)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	cancel_button.position = Vector2(
		(panel_size.x - 160.0) * 0.5,
		314.0
	)
	cancel_button.size = Vector2(160.0, 32.0)

	if crop_info_panel != null:
		var info_panel_size: Vector2 = Vector2(430.0, 230.0)

		crop_info_panel.position = (
			viewport_size - info_panel_size
		) * 0.5

		crop_info_panel.size = info_panel_size

		if crop_info_label != null:
			crop_info_label.position = Vector2(24.0, 22.0)
			crop_info_label.size = Vector2(382.0, 94.0)
			crop_info_label.horizontal_alignment = (
				HORIZONTAL_ALIGNMENT_CENTER
			)

		if remove_crop_button != null:
			remove_crop_button.position = Vector2(56.0, 136.0)
			remove_crop_button.size = Vector2(318.0, 34.0)

		if close_info_button != null:
			close_info_button.position = Vector2(135.0, 182.0)
			close_info_button.size = Vector2(160.0, 30.0)

	if seed_tooltip_panel != null:
		seed_tooltip_panel.size = Vector2(330.0, 190.0)

		if tooltip_title_label != null:
			tooltip_title_label.position = Vector2(18.0, 16.0)
			tooltip_title_label.size = Vector2(294.0, 28.0)

		if tooltip_type_label != null:
			tooltip_type_label.position = Vector2(18.0, 52.0)
			tooltip_type_label.size = Vector2(294.0, 24.0)

		if tooltip_description_label != null:
			tooltip_description_label.position = Vector2(18.0, 84.0)
			tooltip_description_label.size = Vector2(294.0, 92.0)

func _on_planting_menu_requested(grid_cell: Vector2i) -> void:
	selected_grid_cell = grid_cell

	visible = true
	seed_panel.visible = true

	if crop_info_panel != null:
		crop_info_panel.visible = false

	if seed_tooltip_panel != null:
		seed_tooltip_panel.visible = false

	title_label.text = "Seed Pouch"

	description_label.text = (
		"Choose a seed to plant in this empty plot."
	)

	status_label.text = ""

	_layout_ui()
	update_ui()

func _on_crop_inspection_requested(grid_cell: Vector2i) -> void:
	selected_grid_cell = grid_cell

	visible = true
	seed_panel.visible = false

	if seed_tooltip_panel != null:
		seed_tooltip_panel.visible = false

	if crop_info_panel != null:
		crop_info_panel.visible = true

	_update_crop_info_panel()
	_layout_ui()

func _update_crop_info_panel() -> void:
	if crop_manager == null or crop_info_label == null:
		return

	var crop_name: String = crop_manager.get_crop_display_name(
		selected_grid_cell
	)

	var days_left: int = crop_manager.get_crop_remaining_days(
		selected_grid_cell
	)

	crop_info_label.text = (
		crop_name
		+ "\n"
		+ "Time Remaining: "
		+ str(days_left)
		+ " day(s)\n\n"
		+ "Remove with shovel to clear the plot.\n"
		+ "No seeds or harvest will be returned."
	)

func _on_planting_menu_closed() -> void:
	visible = false
	selected_grid_cell = Vector2i(-1, -1)
	hovered_seed_id = ""

	if crop_info_panel != null:
		crop_info_panel.visible = false

	if seed_tooltip_panel != null:
		seed_tooltip_panel.visible = false

func _on_basic_crop_pressed() -> void:
	if crop_manager == null:
		return

	if crop_manager.get_available_seed_count() < crop_manager.basic_crop_seed_cost:
		status_label.text = "You do not have enough Seeds."
		return

	crop_manager.confirm_plant_basic_crop()

func _on_mutant_crop_pressed() -> void:
	if crop_manager == null:
		return

	if not crop_manager.has_method("confirm_plant_mutant_crop"):
		status_label.text = "Mutant planting is unavailable."
		return

	if crop_manager.get_available_mutant_seed_count() < (
		crop_manager.mutant_crop_mutant_seed_cost
	):
		status_label.text = "You do not have a Mutant Seed."
		return

	crop_manager.confirm_plant_mutant_crop()

func _on_remove_crop_pressed() -> void:
	if crop_manager == null:
		return

	if crop_manager.has_method("remove_crop_without_harvest"):
		crop_manager.remove_crop_without_harvest(selected_grid_cell)

func _on_cancel_pressed() -> void:
	if crop_manager == null:
		visible = false
		return

	crop_manager.cancel_planting_menu()

func _on_planting_result(success: bool, message: String) -> void:
	status_label.text = message

	if not success:
		update_ui()

func update_ui() -> void:
	if crop_manager == null:
		return

	var seed_count: int = crop_manager.get_available_seed_count()

	var mutant_seed_count: int = 0

	if crop_manager.has_method("get_available_mutant_seed_count"):
		mutant_seed_count = crop_manager.get_available_mutant_seed_count()

	seed_count_label.text = (
		"Seeds: %d    |    Mutant Seeds: %d"
		% [seed_count, mutant_seed_count]
	)

	var basic_harvest_amount: int = (
		crop_manager.basic_crop_harvest_amount
	)

	if crop_manager.has_method("get_effective_basic_crop_harvest_amount"):
		basic_harvest_amount = (
			crop_manager.get_effective_basic_crop_harvest_amount()
		)

	basic_crop_button.text = (
		"BASIC SEED\n\nx%d" % seed_count
	)

	if seed_count < crop_manager.basic_crop_seed_cost:
		basic_crop_button.modulate = Color(1.0, 1.0, 1.0, 0.35)
	else:
		basic_crop_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	basic_crop_button.tooltip_text = (
		"Basic Crop | Harvest: %d Seeds"
		% basic_harvest_amount
	)

	if mutant_crop_button == null:
		return

	mutant_crop_button.text = (
		"MUTANT SEED\n\nx%d" % mutant_seed_count
	)

	if mutant_seed_count < crop_manager.mutant_crop_mutant_seed_cost:
		mutant_crop_button.modulate = Color(1.0, 1.0, 1.0, 0.35)
	else:
		mutant_crop_button.modulate = Color(1.0, 1.0, 1.0, 1.0)

	mutant_crop_button.tooltip_text = (
		"Mutant Crop | Unlocks Mutant Compost"
	)

func _on_seed_slot_mouse_entered(seed_id: String) -> void:
	hovered_seed_id = seed_id
	_show_seed_tooltip(seed_id)
	_update_seed_hover_visuals()

func _on_seed_slot_mouse_exited() -> void:
	hovered_seed_id = ""

	if seed_tooltip_panel != null:
		seed_tooltip_panel.visible = false

	_update_seed_hover_visuals()

func _update_seed_hover_visuals() -> void:
	update_ui()

	if hovered_seed_id == SEED_BASIC:
		if _has_seed_available(SEED_BASIC):
			basic_crop_button.modulate = Color(1.0, 0.90, 0.42, 1.0)
		else:
			basic_crop_button.modulate = Color(1.0, 0.90, 0.42, 0.45)

	elif hovered_seed_id == SEED_MUTANT and mutant_crop_button != null:
		if _has_seed_available(SEED_MUTANT):
			mutant_crop_button.modulate = Color(1.0, 0.90, 0.42, 1.0)
		else:
			mutant_crop_button.modulate = Color(1.0, 0.90, 0.42, 0.45)

func _show_seed_tooltip(seed_id: String) -> void:
	if seed_tooltip_panel == null:
		return

	if crop_manager == null:
		return

	seed_tooltip_panel.visible = true

	match seed_id:
		SEED_BASIC:
			_set_tooltip_text(
				"BASIC SEED",
				"Type: Crop Seed",
				"Plants a Basic Crop.\n"
				+ "Growth: "
				+ str(crop_manager.basic_crop_growth_days)
				+ " day(s)\n"
				+ "Harvest: "
				+ str(crop_manager.get_effective_basic_crop_harvest_amount())
				+ " Seeds\n\n"
				+ "A reliable crop used to build the farm economy."
			)

		SEED_MUTANT:
			_set_tooltip_text(
				"MUTANT SEED",
				"Type: Special Seed",
				"Plants a Mutant Crop.\n"
				+ "Growth: "
				+ str(crop_manager.mutant_crop_growth_days)
				+ " day(s)\n"
				+ "Harvest: "
				+ str(crop_manager.mutant_crop_harvest_amount)
				+ " Seeds\n\n"
				+ "Unlocks Mutant Compost when planted."
			)

	_position_seed_tooltip_near_mouse()
	
func _has_seed_available(seed_id: String) -> bool:
	if crop_manager == null:
		return false

	match seed_id:
		SEED_BASIC:
			return (
				crop_manager.get_available_seed_count()
				>= crop_manager.basic_crop_seed_cost
			)

		SEED_MUTANT:
			if not crop_manager.has_method("get_available_mutant_seed_count"):
				return false

			return (
				crop_manager.get_available_mutant_seed_count()
				>= crop_manager.mutant_crop_mutant_seed_cost
			)

	return false

func _set_tooltip_text(
	title_text: String,
	type_text: String,
	description_text: String
) -> void:
	if tooltip_title_label != null:
		tooltip_title_label.text = title_text

	if tooltip_type_label != null:
		tooltip_type_label.text = type_text

	if tooltip_description_label != null:
		tooltip_description_label.text = description_text

func _position_seed_tooltip_near_mouse() -> void:
	if seed_tooltip_panel == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	var mouse_position: Vector2 = get_viewport().get_mouse_position()
	var tooltip_size: Vector2 = seed_tooltip_panel.size

	var tooltip_position: Vector2 = mouse_position + Vector2(24.0, 18.0)

	if tooltip_position.x + tooltip_size.x > viewport_size.x - 12.0:
		tooltip_position.x = mouse_position.x - tooltip_size.x - 18.0

	if tooltip_position.y + tooltip_size.y > viewport_size.y - 12.0:
		tooltip_position.y = mouse_position.y - tooltip_size.y - 18.0

	seed_tooltip_panel.position = tooltip_position
	
func _apply_ui_style() -> void:
	var main_panel_style: StyleBoxFlat = _make_panel_style(
		Color(0.04, 0.08, 0.035, 0.98),
		Color(0.34, 0.19, 0.10, 1.0),
		3,
		8
	)

	seed_panel.add_theme_stylebox_override("panel", main_panel_style)

	if crop_info_panel != null:
		crop_info_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.035, 0.045, 0.035, 0.98),
				Color(0.46, 0.22, 0.12, 1.0),
				3,
				8
			)
		)

	if seed_tooltip_panel != null:
		seed_tooltip_panel.add_theme_stylebox_override(
			"panel",
			_make_panel_style(
				Color(0.02, 0.025, 0.05, 0.96),
				Color(0.36, 0.40, 0.85, 1.0),
				3,
				4
			)
		)

	_apply_seed_button_style(basic_crop_button)

	if mutant_crop_button != null:
		_apply_seed_button_style(mutant_crop_button)

	_apply_plain_button_style(cancel_button)

	if remove_crop_button != null:
		_apply_plain_button_style(remove_crop_button)

	if close_info_button != null:
		_apply_plain_button_style(close_info_button)

	title_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.86, 0.58, 1.0)
	)

	description_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.84, 0.72, 1.0)
	)

	seed_count_label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.78, 0.45, 1.0)
	)

	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.58, 0.42, 1.0)
	)

func _make_panel_style(
	background_colour: Color,
	border_colour: Color,
	border_width: int,
	corner_radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = background_colour
	style.border_color = border_colour

	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)

	return style

func _apply_seed_button_style(button: Button) -> void:
	if button == null:
		return

	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(
			Color(0.08, 0.11, 0.07, 1.0),
			Color(0.30, 0.22, 0.12, 1.0),
			2,
			4
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			Color(0.14, 0.16, 0.09, 1.0),
			Color(0.86, 0.66, 0.25, 1.0),
			3,
			4
		)
	)

	button.add_theme_stylebox_override(
		"pressed",
		_make_panel_style(
			Color(0.20, 0.16, 0.08, 1.0),
			Color(0.95, 0.78, 0.32, 1.0),
			3,
			4
		)
	)

	button.add_theme_font_size_override("font_size", 15)

func _apply_plain_button_style(button: Button) -> void:
	if button == null:
		return

	button.add_theme_stylebox_override(
		"normal",
		_make_panel_style(
			Color(0.08, 0.07, 0.055, 1.0),
			Color(0.34, 0.22, 0.12, 1.0),
			2,
			4
		)
	)

	button.add_theme_stylebox_override(
		"hover",
		_make_panel_style(
			Color(0.16, 0.10, 0.07, 1.0),
			Color(0.75, 0.32, 0.20, 1.0),
			2,
			4
		)
	)
