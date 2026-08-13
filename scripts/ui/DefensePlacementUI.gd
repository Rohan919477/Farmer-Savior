extends CanvasLayer
class_name DefensePlacementUI

signal defense_placement_closed

const ITEM_PESTICIDE_TURRET: String = "pesticide_turret"
const ITEM_FENCE: String = "fence"
const ITEM_NIGHTLIGHT: String = "nightlight"

@onready var grid_board: DefenseGridBoard = (
	$RootControl/MainPanel/GridBoard
)

@onready var pesticide_turret_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/PesticideTurretButton
)

@onready var fence_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/FenceButton
)

@onready var nightlight_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/NightLightButton
)

@onready var locked_tool_2_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/LockedTool2Button
)

@onready var status_label: Label = (
	$RootControl/MainPanel/StatusLabel
)

@onready var close_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/CloseButton
)

@onready var instruction_label: Label = (
	$RootControl/MainPanel/InstructionLabel
)

@onready var details_label: Label = (
	$RootControl/MainPanel/DetailsPanel/DetailsLabel
)

@onready var object_preview: DefenseDetailsPreview = (
	$RootControl/MainPanel/DetailsPanel/ObjectPreview
)

var defense_manager: DefenseManager = null
var selected_item_id: String = ""
var reposition_data: Dictionary = {}
var hovered_object_ref: Dictionary = {}
var instruction_tween: Tween

var war_table_guide_panel: Panel = null
var war_table_guide_title_label: Label = null
var war_table_guide_body_label: Label = null
var war_table_guide_page_label: Label = null
var war_table_guide_previous_button: Button = null
var war_table_guide_next_button: Button = null
var war_table_guide_close_button: Button = null
var war_table_guide_page_index: int = 0
var war_table_guide_titles: Array[String] = [
	"1. Select a defence",
	"2. Place turrets and NightLights",
	"3. Place fences",
	"4. Inspect and reposition",
	"5. Repair before moving"
]
var war_table_guide_bodies: Array[String] = [
	"Choose Pesticide Turret, Fence, or NightLight from the right side. The left panel explains the selected object and its placement rules.",
	"Turrets and NightLights use grid cells. Select the item, then left-click a valid green cell inside the farm boundary.",
	"Fences are placed on grid lines, not inside cells. Select Fence, then left-click close to the grid line where you want a barrier.",
	"Hover a placed defence to inspect its live condition. Left-click a full-health object to lift it, then left-click a valid destination. Right-click cancels and returns it to its original position.",
	"Damaged and broken defences stay on the field and must be repaired there before they can be moved or returned to inventory. Broken repairs cost much more Scrap."
]

const WAR_TABLE_GUIDE_DIM_ALPHA: float = 0.76
const WAR_TABLE_GUIDE_FOCUS_PADDING: float = 8.0

var war_table_guide_dim_rects: Array[ColorRect] = []
var war_table_guide_focus_blocker: ColorRect = null
var war_table_guide_focus_border: Panel = null

func _ready() -> void:
	pesticide_turret_button.pressed.connect(
		_on_pesticide_turret_button_pressed
	)

	fence_button.pressed.connect(_on_fence_button_pressed)
	nightlight_button.pressed.connect(_on_nightlight_button_pressed)
	close_button.pressed.connect(close_ui)

	var overlay: Control = get_node_or_null("RootControl/Overlay") as Control
	if overlay != null and not overlay.gui_input.is_connected(_on_overlay_gui_input):
		overlay.gui_input.connect(_on_overlay_gui_input)

	grid_board.grid_cell_clicked.connect(
		_on_grid_cell_left_clicked
	)

	grid_board.grid_cell_right_clicked.connect(
		_on_grid_cell_right_clicked
	)

	grid_board.fence_edge_clicked.connect(
		_on_fence_edge_left_clicked
	)

	grid_board.fence_edge_right_clicked.connect(
		_on_fence_edge_right_clicked
	)

	_build_war_table_guide()

	visible = false


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event

	if (
		mouse_event.pressed
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
	):
		# Clicking outside the War Table panel exits the interface. close_ui()
		# transactionally cancels any active reposition and restores the source.
		close_ui()
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not visible or defense_manager == null:
		return

	if not reposition_data.is_empty() or not selected_item_id.is_empty():
		return

	var new_hover_ref: Dictionary = grid_board.get_hovered_placed_object_ref()

	if new_hover_ref != hovered_object_ref:
		hovered_object_ref = new_hover_ref.duplicate(true)
		update_details_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# The War Table is a modal gameplay interface. Escape should close it just
	# like the Workshop rather than opening the Pause Menu on top. close_ui()
	# also transactionally cancels any active reposition, leaving the selected
	# defense at its original position.
	if event.is_action_pressed("ui_cancel"):
		close_ui()
		get_viewport().set_input_as_handled()
		return

	if reposition_data.is_empty():
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event

		if (
			mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_RIGHT
		):
			_cancel_reposition(
				"Reposition cancelled. Defence returned to its original position."
			)
			get_viewport().set_input_as_handled()

func open_ui(new_defense_manager: DefenseManager) -> void:
	if defense_manager != new_defense_manager:
		defense_manager = new_defense_manager

		if not defense_manager.inventory_changed.is_connected(
			_on_inventory_changed
		):
			defense_manager.inventory_changed.connect(
				_on_inventory_changed
			)

		if not defense_manager.fence_inventory_changed.is_connected(
			_on_fence_inventory_changed
		):
			defense_manager.fence_inventory_changed.connect(
				_on_fence_inventory_changed
			)

		if defense_manager.has_signal("nightlight_inventory_changed"):
			if not defense_manager.nightlight_inventory_changed.is_connected(
				_on_nightlight_inventory_changed
			):
				defense_manager.nightlight_inventory_changed.connect(
					_on_nightlight_inventory_changed
				)

		if not defense_manager.placement_failed.is_connected(
			_on_placement_failed
		):
			defense_manager.placement_failed.connect(
				_on_placement_failed
			)

	selected_item_id = ""
	reposition_data.clear()
	hovered_object_ref.clear()
	status_label.text = "Select an inventory item or hover a placed defence."
	visible = true

	if instruction_label != null:
		instruction_label.visible = false

	_maybe_show_war_table_guide()
	update_ui()

func close_ui() -> void:
	var was_visible: bool = visible

	_cancel_reposition("", false)
	selected_item_id = ""
	hovered_object_ref.clear()
	_hide_war_table_guide()
	visible = false

	if was_visible:
		defense_placement_closed.emit()

func _build_war_table_guide() -> void:
	if war_table_guide_panel != null:
		return

	var main_panel: Control = get_node_or_null("RootControl/MainPanel") as Control

	if main_panel == null:
		return

	_build_war_table_guide_overlay(main_panel)

	war_table_guide_panel = Panel.new()
	war_table_guide_panel.name = "WarTableGuidePanel"
	war_table_guide_panel.position = Vector2(265.0, 120.0)
	war_table_guide_panel.size = Vector2(520.0, 250.0)
	war_table_guide_panel.visible = false
	war_table_guide_panel.z_index = 50
	war_table_guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.030, 0.025, 0.96)
	panel_style.border_color = Color(0.75, 0.50, 0.18, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	war_table_guide_panel.add_theme_stylebox_override("panel", panel_style)

	main_panel.add_child(war_table_guide_panel)

	war_table_guide_title_label = Label.new()
	war_table_guide_title_label.name = "GuideTitleLabel"
	war_table_guide_title_label.position = Vector2(18.0, 14.0)
	war_table_guide_title_label.size = Vector2(484.0, 32.0)
	war_table_guide_title_label.add_theme_font_size_override("font_size", 20)
	war_table_guide_title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.82, 0.42, 1.0)
	)
	war_table_guide_title_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)
	war_table_guide_title_label.add_theme_constant_override("outline_size", 2)
	war_table_guide_panel.add_child(war_table_guide_title_label)

	war_table_guide_body_label = Label.new()
	war_table_guide_body_label.name = "GuideBodyLabel"
	war_table_guide_body_label.position = Vector2(18.0, 55.0)
	war_table_guide_body_label.size = Vector2(484.0, 106.0)
	war_table_guide_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	war_table_guide_body_label.add_theme_font_size_override("font_size", 16)
	war_table_guide_body_label.add_theme_color_override(
		"font_color",
		Color(0.94, 0.90, 0.82, 1.0)
	)
	war_table_guide_body_label.add_theme_color_override(
		"font_outline_color",
		Color(0.0, 0.0, 0.0, 1.0)
	)
	war_table_guide_body_label.add_theme_constant_override("outline_size", 2)
	war_table_guide_panel.add_child(war_table_guide_body_label)

	war_table_guide_page_label = Label.new()
	war_table_guide_page_label.name = "GuidePageLabel"
	war_table_guide_page_label.position = Vector2(18.0, 166.0)
	war_table_guide_page_label.size = Vector2(484.0, 22.0)
	war_table_guide_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	war_table_guide_page_label.add_theme_font_size_override("font_size", 13)
	war_table_guide_page_label.add_theme_color_override(
		"font_color",
		Color(0.76, 0.66, 0.48, 1.0)
	)
	war_table_guide_panel.add_child(war_table_guide_page_label)

	war_table_guide_previous_button = Button.new()
	war_table_guide_previous_button.name = "GuidePreviousButton"
	war_table_guide_previous_button.text = "PREVIOUS"
	war_table_guide_previous_button.position = Vector2(18.0, 198.0)
	war_table_guide_previous_button.size = Vector2(130.0, 34.0)
	war_table_guide_previous_button.pressed.connect(_on_war_table_guide_previous_pressed)
	war_table_guide_panel.add_child(war_table_guide_previous_button)

	war_table_guide_close_button = Button.new()
	war_table_guide_close_button.name = "GuideCloseButton"
	war_table_guide_close_button.text = "CLOSE GUIDE"
	war_table_guide_close_button.position = Vector2(185.0, 198.0)
	war_table_guide_close_button.size = Vector2(150.0, 34.0)
	war_table_guide_close_button.pressed.connect(_hide_war_table_guide)
	war_table_guide_panel.add_child(war_table_guide_close_button)

	war_table_guide_next_button = Button.new()
	war_table_guide_next_button.name = "GuideNextButton"
	war_table_guide_next_button.text = "NEXT"
	war_table_guide_next_button.position = Vector2(372.0, 198.0)
	war_table_guide_next_button.size = Vector2(130.0, 34.0)
	war_table_guide_next_button.pressed.connect(_on_war_table_guide_next_pressed)
	war_table_guide_panel.add_child(war_table_guide_next_button)

	_update_war_table_guide_page()

func _build_war_table_guide_overlay(main_panel: Control) -> void:
	if not war_table_guide_dim_rects.is_empty():
		return

	for index: int in range(4):
		var dim_rect: ColorRect = ColorRect.new()
		dim_rect.name = "WarTableGuideDimRect%d" % index
		dim_rect.color = Color(0.0, 0.0, 0.0, WAR_TABLE_GUIDE_DIM_ALPHA)
		dim_rect.visible = false
		dim_rect.z_index = 45
		dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
		main_panel.add_child(dim_rect)
		war_table_guide_dim_rects.append(dim_rect)

	war_table_guide_focus_blocker = ColorRect.new()
	war_table_guide_focus_blocker.name = "WarTableGuideFocusBlocker"
	war_table_guide_focus_blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	war_table_guide_focus_blocker.visible = false
	war_table_guide_focus_blocker.z_index = 46
	war_table_guide_focus_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	main_panel.add_child(war_table_guide_focus_blocker)

	war_table_guide_focus_border = Panel.new()
	war_table_guide_focus_border.name = "WarTableGuideFocusBorder"
	war_table_guide_focus_border.visible = false
	war_table_guide_focus_border.z_index = 47
	war_table_guide_focus_border.mouse_filter = Control.MOUSE_FILTER_STOP

	var focus_style: StyleBoxFlat = StyleBoxFlat.new()
	focus_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	focus_style.border_color = Color(1.0, 0.78, 0.24, 1.0)
	focus_style.border_width_left = 3
	focus_style.border_width_top = 3
	focus_style.border_width_right = 3
	focus_style.border_width_bottom = 3
	focus_style.corner_radius_top_left = 6
	focus_style.corner_radius_top_right = 6
	focus_style.corner_radius_bottom_left = 6
	focus_style.corner_radius_bottom_right = 6
	war_table_guide_focus_border.add_theme_stylebox_override(
		"panel",
		focus_style
	)

	main_panel.add_child(war_table_guide_focus_border)

func _set_war_table_guide_overlay_visible(is_visible: bool) -> void:
	for dim_rect: ColorRect in war_table_guide_dim_rects:
		if dim_rect != null:
			dim_rect.visible = is_visible

	if war_table_guide_focus_blocker != null:
		war_table_guide_focus_blocker.visible = is_visible

	if war_table_guide_focus_border != null:
		war_table_guide_focus_border.visible = is_visible

func _get_war_table_guide_focus_target() -> Control:
	if war_table_guide_page_index == 0:
		return $RootControl/MainPanel/Sidebar/VBoxContainer as Control

	if war_table_guide_page_index == 1:
		return grid_board as Control

	if war_table_guide_page_index == 2:
		return fence_button as Control

	if war_table_guide_page_index == 3:
		return grid_board as Control

	if war_table_guide_page_index == 4:
		return close_button as Control

	return grid_board as Control

func _update_war_table_guide_focus() -> void:
	if war_table_guide_panel == null or not war_table_guide_panel.visible:
		_set_war_table_guide_overlay_visible(false)
		return

	var main_panel: Control = get_node_or_null("RootControl/MainPanel") as Control

	if main_panel == null:
		_set_war_table_guide_overlay_visible(false)
		return

	var focus_target: Control = _get_war_table_guide_focus_target()

	if focus_target == null:
		_set_war_table_guide_overlay_visible(false)
		return

	var main_rect: Rect2 = Rect2(Vector2.ZERO, main_panel.size)
	var target_global_rect: Rect2 = focus_target.get_global_rect().grow(
		WAR_TABLE_GUIDE_FOCUS_PADDING
	)

	var focus_position: Vector2 = (
		target_global_rect.position - main_panel.global_position
	)

	var focus_rect: Rect2 = Rect2(
		focus_position,
		target_global_rect.size
	).intersection(main_rect)

	if focus_rect.size.x <= 0.0 or focus_rect.size.y <= 0.0:
		_set_war_table_guide_overlay_visible(false)
		return

	if war_table_guide_dim_rects.size() >= 4:
		var top_rect: ColorRect = war_table_guide_dim_rects[0]
		var left_rect: ColorRect = war_table_guide_dim_rects[1]
		var right_rect: ColorRect = war_table_guide_dim_rects[2]
		var bottom_rect: ColorRect = war_table_guide_dim_rects[3]

		top_rect.position = Vector2.ZERO
		top_rect.size = Vector2(main_rect.size.x, focus_rect.position.y)

		left_rect.position = Vector2(0.0, focus_rect.position.y)
		left_rect.size = Vector2(focus_rect.position.x, focus_rect.size.y)

		right_rect.position = Vector2(focus_rect.end.x, focus_rect.position.y)
		right_rect.size = Vector2(
			main_rect.size.x - focus_rect.end.x,
			focus_rect.size.y
		)

		bottom_rect.position = Vector2(0.0, focus_rect.end.y)
		bottom_rect.size = Vector2(
			main_rect.size.x,
			main_rect.size.y - focus_rect.end.y
		)

	if war_table_guide_focus_blocker != null:
		war_table_guide_focus_blocker.position = focus_rect.position
		war_table_guide_focus_blocker.size = focus_rect.size

	if war_table_guide_focus_border != null:
		war_table_guide_focus_border.position = focus_rect.position
		war_table_guide_focus_border.size = focus_rect.size

	_set_war_table_guide_overlay_visible(true)

func _maybe_show_war_table_guide() -> void:
	if not _should_show_war_table_guide():
		_hide_war_table_guide()
		return

	war_table_guide_page_index = 0
	_update_war_table_guide_page()

	if war_table_guide_panel != null:
		war_table_guide_panel.visible = true
		war_table_guide_panel.move_to_front()

	if war_table_guide_next_button != null:
		war_table_guide_next_button.grab_focus()

	_update_war_table_guide_focus()

func _should_show_war_table_guide() -> bool:
	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if tutorial_manager == null:
		return false

	if tutorial_manager.has_method("is_tutorial_running"):
		if not bool(tutorial_manager.call("is_tutorial_running")):
			return false

	return str(tutorial_manager.get("current_step")) == "use_war_table"

func _on_war_table_guide_previous_pressed() -> void:
	_cancel_reposition("", false)
	war_table_guide_page_index = maxi(
		0,
		war_table_guide_page_index - 1
	)

	_update_war_table_guide_page()

func _on_war_table_guide_next_pressed() -> void:
	_cancel_reposition("", false)
	if war_table_guide_page_index >= war_table_guide_titles.size() - 1:
		_hide_war_table_guide()
		return

	war_table_guide_page_index += 1
	_update_war_table_guide_page()

func _update_war_table_guide_page() -> void:
	if war_table_guide_titles.is_empty():
		return

	war_table_guide_page_index = clampi(
		war_table_guide_page_index,
		0,
		war_table_guide_titles.size() - 1
	)

	if war_table_guide_title_label != null:
		war_table_guide_title_label.text = war_table_guide_titles[
			war_table_guide_page_index
		]

	if war_table_guide_body_label != null:
		war_table_guide_body_label.text = war_table_guide_bodies[
			war_table_guide_page_index
		]

	if war_table_guide_page_label != null:
		war_table_guide_page_label.text = "Page %d / %d" % [
			war_table_guide_page_index + 1,
			war_table_guide_titles.size()
		]

	if war_table_guide_previous_button != null:
		war_table_guide_previous_button.disabled = (
			war_table_guide_page_index <= 0
		)

	if war_table_guide_next_button != null:
		if war_table_guide_page_index >= war_table_guide_titles.size() - 1:
			war_table_guide_next_button.text = "DONE"
		else:
			war_table_guide_next_button.text = "NEXT"

	_update_war_table_guide_focus()

func _hide_war_table_guide() -> void:
	_cancel_reposition("", false)

	if war_table_guide_panel != null:
		war_table_guide_panel.visible = false

	_set_war_table_guide_overlay_visible(false)

func show_controls_hint() -> void:
	if instruction_tween != null:
		instruction_tween.kill()

	if instruction_label != null:
		instruction_label.visible = false

func _hide_controls_hint() -> void:
	instruction_label.visible = false

func _cancel_reposition(
	message: String = "Reposition cancelled. Defence returned to its original position.",
	refresh_ui: bool = true
) -> void:
	if reposition_data.is_empty():
		return

	reposition_data.clear()

	if not message.is_empty():
		status_label.text = message

	if refresh_ui and defense_manager != null:
		update_ui()

func _begin_reposition_turret(grid_cell: Vector2i) -> void:
	if defense_manager == null or not defense_manager.has_turret(grid_cell):
		return

	var turret_key: String = defense_manager.get_turret_key(grid_cell)
	var turret_state: String = defense_manager.get_turret_state(turret_key)

	if turret_state != DefenseManager.PLACEABLE_STATE_PERFECT:
		status_label.text = (
			"Repair this Pesticide Turret to full condition in the field before moving it."
		)
		update_ui()
		return

	selected_item_id = ""
	hovered_object_ref.clear()
	reposition_data = {
		"item_id": ITEM_PESTICIDE_TURRET,
		"source_cell": grid_cell
	}
	status_label.text = (
		"Moving Pesticide Turret. Left-click a valid cell; right-click to cancel."
	)
	update_ui()

func _begin_reposition_nightlight(grid_cell: Vector2i) -> void:
	if defense_manager == null or not defense_manager.has_nightlight(grid_cell):
		return

	var nightlight_key: String = defense_manager.get_nightlight_key(grid_cell)
	var nightlight_state: String = defense_manager.get_nightlight_state(
		nightlight_key
	)

	if nightlight_state != DefenseManager.PLACEABLE_STATE_PERFECT:
		status_label.text = (
			"Repair this NightLight to full condition in the field before moving it."
		)
		update_ui()
		return

	selected_item_id = ""
	hovered_object_ref.clear()
	reposition_data = {
		"item_id": ITEM_NIGHTLIGHT,
		"source_cell": grid_cell
	}
	status_label.text = (
		"Moving NightLight. Left-click a valid cell; right-click to cancel."
	)
	update_ui()

func _begin_reposition_fence(
	fence_key: String,
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null or not defense_manager.has_fence(fence_key):
		return

	var fence_state: String = defense_manager.get_fence_state(fence_key)
	var fence_data: Dictionary = defense_manager.get_fence_data(fence_key)

	if fence_state != DefenseManager.FENCE_STATE_PERFECT:
		status_label.text = (
			"Repair this Fence to full HP in the field before moving it."
		)
		update_ui()
		return

	if bool(fence_data.get("is_perimeter_fence", false)):
		status_label.text = "Perimeter fences are fixed to the farm boundary."
		update_ui()
		return

	selected_item_id = ""
	hovered_object_ref.clear()
	reposition_data = {
		"item_id": ITEM_FENCE,
		"source_fence_key": fence_key,
		"source_orientation": orientation,
		"source_grid_edge": grid_edge
	}
	status_label.text = (
		"Moving Fence. Left-click a valid grid edge; right-click to cancel."
	)
	update_ui()

func _on_pesticide_turret_button_pressed() -> void:
	_cancel_reposition("", false)

	if defense_manager == null:
		return

	if defense_manager.get_pesticide_turrets_available() <= 0:
		status_label.text = "No Pesticide Turrets remain."
		update_ui()
		return

	selected_item_id = ITEM_PESTICIDE_TURRET
	hovered_object_ref.clear()
	status_label.text = "Select a valid farm grid cell."
	update_ui()

func _on_fence_button_pressed() -> void:
	_cancel_reposition("", false)

	if defense_manager == null:
		return

	if defense_manager.get_fences_available() <= 0:
		status_label.text = "No fences remain in storage."
		update_ui()
		return

	selected_item_id = ITEM_FENCE
	hovered_object_ref.clear()
	status_label.text = "Click close to a grid line to place a fence."
	update_ui()

func _on_nightlight_button_pressed() -> void:
	_cancel_reposition("", false)

	if defense_manager == null:
		return

	if defense_manager.get_nightlights_available() <= 0:
		status_label.text = "No NightLights remain."
		update_ui()
		return

	selected_item_id = ITEM_NIGHTLIGHT
	hovered_object_ref.clear()
	status_label.text = "Select a valid farm grid cell for the NightLight."
	update_ui()

func _on_grid_cell_left_clicked(grid_cell: Vector2i) -> void:
	if defense_manager == null:
		return

	if not reposition_data.is_empty():
		var moving_item_id: String = str(reposition_data.get("item_id", ""))

		if moving_item_id == ITEM_PESTICIDE_TURRET:
			var source_cell: Vector2i = reposition_data.get(
				"source_cell",
				Vector2i(-1, -1)
			)

			if defense_manager.reposition_pesticide_turret(
				source_cell,
				grid_cell
			):
				reposition_data.clear()
				status_label.text = "Pesticide Turret repositioned."

			update_ui()
			return

		if moving_item_id == ITEM_NIGHTLIGHT:
			var source_cell: Vector2i = reposition_data.get(
				"source_cell",
				Vector2i(-1, -1)
			)

			if defense_manager.reposition_nightlight(source_cell, grid_cell):
				reposition_data.clear()
				status_label.text = "NightLight repositioned."

			update_ui()
			return

		status_label.text = "Click a grid edge to reposition the selected Fence."
		update_ui()
		return

	# A click on an already placed defence always refers to that field object,
	# even if an inventory item was selected previously. This keeps the direct
	# reposition interaction predictable: the player never has to manually
	# deselect an inventory button before selecting a placed defence.
	if defense_manager.has_turret(grid_cell):
		selected_item_id = ""
		_begin_reposition_turret(grid_cell)
		return

	if defense_manager.has_nightlight(grid_cell):
		selected_item_id = ""
		_begin_reposition_nightlight(grid_cell)
		return

	if selected_item_id == ITEM_PESTICIDE_TURRET:
		_place_pesticide_turret(grid_cell)
		return

	if selected_item_id == ITEM_NIGHTLIGHT:
		_place_nightlight(grid_cell)
		return

	status_label.text = "Select an inventory item, or click a full-health placed defence."
	update_ui()

func _place_pesticide_turret(grid_cell: Vector2i) -> void:
	var placed_successfully: bool = defense_manager.place_pesticide_turret(
		grid_cell
	)

	if placed_successfully:
		status_label.text = "Pesticide Turret placed."

		if defense_manager.get_pesticide_turrets_available() <= 0:
			selected_item_id = ""

	update_ui()

func _place_nightlight(grid_cell: Vector2i) -> void:
	var placed_successfully: bool = defense_manager.place_nightlight(grid_cell)

	if placed_successfully:
		status_label.text = "NightLight placed."

		if defense_manager.get_nightlights_available() <= 0:
			selected_item_id = ""

	update_ui()

func _on_fence_edge_left_clicked(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null:
		return

	if not reposition_data.is_empty():
		if str(reposition_data.get("item_id", "")) != ITEM_FENCE:
			status_label.text = "Select a valid grid cell for the moving defence."
			update_ui()
			return

		var source_fence_key: String = str(
			reposition_data.get("source_fence_key", "")
		)

		if defense_manager.reposition_fence(
			source_fence_key,
			orientation,
			grid_edge
		):
			reposition_data.clear()
			status_label.text = "Fence repositioned."

		update_ui()
		return

	var fence_key: String = defense_manager.get_fence_key(
		orientation,
		grid_edge
	)

	# Existing fences also take precedence over the currently selected
	# inventory item. Clicking a placed fence means inspect/reposition that
	# fence, not attempt to place another fence on the occupied edge.
	if defense_manager.has_fence(fence_key):
		selected_item_id = ""
		_begin_reposition_fence(fence_key, orientation, grid_edge)
		return

	if selected_item_id != ITEM_FENCE:
		status_label.text = "Select Fence from the inventory first."
		update_ui()
		return

	var placed_successfully: bool = defense_manager.place_fence(
		orientation,
		grid_edge
	)

	if placed_successfully:
		status_label.text = "Fence placed."

		if defense_manager.get_fences_available() <= 0:
			selected_item_id = ""

	update_ui()

func _on_grid_cell_right_clicked(grid_cell: Vector2i) -> void:
	if defense_manager == null:
		return

	if not reposition_data.is_empty():
		_cancel_reposition()
		return

	if defense_manager.has_nightlight(grid_cell):
		if defense_manager.remove_nightlight(grid_cell):
			status_label.text = "NightLight returned to inventory."
		update_ui()
		return

	if defense_manager.has_turret(grid_cell):
		if defense_manager.remove_pesticide_turret(grid_cell):
			status_label.text = "Pesticide Turret returned to inventory."
		update_ui()
		return

	status_label.text = "No placed item exists on this grid cell."
	update_ui()

func _on_fence_edge_right_clicked(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null:
		return

	if not reposition_data.is_empty():
		_cancel_reposition()
		return

	var fence_key: String = defense_manager.get_fence_key(
		orientation,
		grid_edge
	)

	if defense_manager.remove_fence(fence_key):
		status_label.text = "Fence returned to inventory."

	update_ui()

func _on_inventory_changed(_remaining_turrets: int) -> void:
	update_ui()

func _on_fence_inventory_changed(_remaining_fences: int) -> void:
	update_ui()

func _on_nightlight_inventory_changed(_remaining_nightlights: int) -> void:
	update_ui()

func _on_placement_failed(reason: String) -> void:
	status_label.text = reason
	update_ui()

func update_ui() -> void:
	if defense_manager == null:
		return

	var available_turrets: int = defense_manager.get_pesticide_turrets_available()
	var available_fences: int = defense_manager.get_fences_available()
	var available_nightlights: int = defense_manager.get_nightlights_available()

	pesticide_turret_button.text = "PESTICIDE TURRET x%d" % available_turrets
	fence_button.text = "FENCE x%d" % available_fences
	nightlight_button.text = "NIGHTLIGHT x%d" % available_nightlights
	locked_tool_2_button.text = "LOCKED"

	pesticide_turret_button.disabled = available_turrets <= 0
	fence_button.disabled = available_fences <= 0
	nightlight_button.disabled = available_nightlights <= 0
	locked_tool_2_button.disabled = true

	_update_item_button_visual(
		pesticide_turret_button,
		selected_item_id == ITEM_PESTICIDE_TURRET,
		available_turrets > 0
	)
	_update_item_button_visual(
		fence_button,
		selected_item_id == ITEM_FENCE,
		available_fences > 0
	)
	_update_item_button_visual(
		nightlight_button,
		selected_item_id == ITEM_NIGHTLIGHT,
		available_nightlights > 0
	)
	locked_tool_2_button.self_modulate = Color(0.45, 0.52, 0.60)

	update_details_panel()

	var board_item_id: String = selected_item_id
	if not reposition_data.is_empty():
		board_item_id = str(reposition_data.get("item_id", ""))

	grid_board.configure(
		defense_manager,
		board_item_id,
		reposition_data
	)

func _update_item_button_visual(
	button: Button,
	is_selected: bool,
	is_available: bool
) -> void:
	if is_selected:
		button.self_modulate = Color(0.18, 0.35, 0.75)
		return

	if is_available:
		button.self_modulate = Color(0.48, 0.60, 0.72)
		return

	button.self_modulate = Color(0.34, 0.38, 0.42)

func update_details_panel() -> void:
	if defense_manager == null:
		return

	if not reposition_data.is_empty():
		_show_reposition_details()
		return

	if not selected_item_id.is_empty():
		_show_inventory_item_details(selected_item_id)
		return

	if not hovered_object_ref.is_empty():
		_show_hovered_object_details(hovered_object_ref)
		return

	object_preview.clear_preview()
	details_label.text = (
		"ITEM DETAILS\n\n"
		+ "Hover a placed defence to inspect its current condition.\n\n"
		+ "Left-click a full-health placed defence to reposition it.\n"
		+ "Right-click a full-health non-perimeter defence to return it to inventory."
	)

func _show_inventory_item_details(item_id: String) -> void:
	object_preview.show_defense(item_id, DefenseManager.PLACEABLE_STATE_PERFECT)

	if item_id == ITEM_PESTICIDE_TURRET:
		details_label.text = (
			"PESTICIDE TURRET\n\n"
			+ ("Integrity: %d/%d\n" % [
				int(defense_manager.pesticide_turret_max_integrity),
				int(defense_manager.pesticide_turret_max_integrity)
			])
			+ ("Durability: %d/%d\n" % [
				int(defense_manager.pesticide_turret_max_durability),
				int(defense_manager.pesticide_turret_max_durability)
			])
			+ "Damage: 8\nRange: 180\n\n"
			+ "Left-click a valid grid cell to place."
		)
		return

	if item_id == ITEM_FENCE:
		details_label.text = (
			"FENCE\n\n"
			+ ("HP: %d/%d\n" % [
				int(defense_manager.fence_max_health),
				int(defense_manager.fence_max_health)
			])
			+ "Blocks ground enemies and the player.\n\n"
			+ "Damaged/broken fences must be repaired in the field.\n"
			+ "Click near a grid line to place."
		)
		return

	if item_id == ITEM_NIGHTLIGHT:
		details_label.text = (
			"NIGHTLIGHT\n\n"
			+ ("Integrity: %d/%d\n" % [
				int(defense_manager.nightlight_max_integrity),
				int(defense_manager.nightlight_max_integrity)
			])
			+ ("Night Wear: %.2f/sec\n\n" % defense_manager.nightlight_wear_per_second)
			+ "Provides local visibility.\n"
			+ "Damaged/broken NightLights must be repaired in the field.\n\n"
			+ "Left-click a valid grid cell to place."
		)

func _show_reposition_details() -> void:
	var item_id: String = str(reposition_data.get("item_id", ""))

	if item_id == ITEM_PESTICIDE_TURRET:
		var grid_cell: Vector2i = reposition_data.get("source_cell", Vector2i.ZERO)
		_show_turret_details(grid_cell, true)
		return

	if item_id == ITEM_NIGHTLIGHT:
		var grid_cell: Vector2i = reposition_data.get("source_cell", Vector2i.ZERO)
		_show_nightlight_details(grid_cell, true)
		return

	if item_id == ITEM_FENCE:
		_show_fence_details(
			str(reposition_data.get("source_fence_key", "")),
			true
		)

func _show_hovered_object_details(object_ref: Dictionary) -> void:
	var item_id: String = str(object_ref.get("item_id", ""))

	if item_id == ITEM_PESTICIDE_TURRET:
		_show_turret_details(
			object_ref.get("grid_cell", Vector2i.ZERO),
			false
		)
		return

	if item_id == ITEM_NIGHTLIGHT:
		_show_nightlight_details(
			object_ref.get("grid_cell", Vector2i.ZERO),
			false
		)
		return

	if item_id == ITEM_FENCE:
		_show_fence_details(str(object_ref.get("fence_key", "")), false)
		return

	object_preview.clear_preview()

func _show_turret_details(grid_cell: Vector2i, moving: bool) -> void:
	var turret_key: String = defense_manager.get_turret_key(grid_cell)
	var state: String = defense_manager.get_turret_state(turret_key)
	var current_integrity: int = int(round(
		defense_manager.get_pesticide_turret_current_integrity(turret_key)
	))
	var current_durability: int = int(round(
		defense_manager.get_pesticide_turret_current_durability(turret_key)
	))
	var max_integrity: int = int(round(defense_manager.pesticide_turret_max_integrity))
	var max_durability: int = int(round(defense_manager.pesticide_turret_max_durability))

	object_preview.show_defense(ITEM_PESTICIDE_TURRET, state)

	var action_text: String = _get_condition_action_text(
		ITEM_PESTICIDE_TURRET,
		state,
		false,
		moving,
		defense_manager.get_pesticide_turret_repair_cost_scrap(turret_key)
	)

	details_label.text = (
		"PESTICIDE TURRET\n\n"
		+ ("State: %s\n" % state.capitalize())
		+ ("Integrity: %d/%d\n" % [current_integrity, max_integrity])
		+ ("Durability: %d/%d\n\n" % [current_durability, max_durability])
		+ action_text
	)

func _show_nightlight_details(grid_cell: Vector2i, moving: bool) -> void:
	var nightlight_key: String = defense_manager.get_nightlight_key(grid_cell)
	var state: String = defense_manager.get_nightlight_state(nightlight_key)
	var current_integrity: int = int(round(
		defense_manager.get_nightlight_current_integrity(nightlight_key)
	))
	var max_integrity: int = int(round(defense_manager.nightlight_max_integrity))

	object_preview.show_defense(ITEM_NIGHTLIGHT, state)

	var action_text: String = _get_condition_action_text(
		ITEM_NIGHTLIGHT,
		state,
		false,
		moving,
		defense_manager.get_nightlight_repair_cost_scrap(nightlight_key)
	)

	details_label.text = (
		"NIGHTLIGHT\n\n"
		+ ("State: %s\n" % state.capitalize())
		+ ("Integrity: %d/%d\n" % [current_integrity, max_integrity])
		+ ("Night Wear: %.2f/sec\n\n" % defense_manager.nightlight_wear_per_second)
		+ action_text
	)

func _show_fence_details(fence_key: String, moving: bool) -> void:
	if fence_key.is_empty() or not defense_manager.has_fence(fence_key):
		object_preview.clear_preview()
		return

	var state: String = defense_manager.get_fence_state(fence_key)
	var fence_data: Dictionary = defense_manager.get_fence_data(fence_key)
	var current_hp: int = int(round(defense_manager.get_fence_current_health(fence_key)))
	var max_hp: int = int(round(defense_manager.fence_max_health))
	var is_perimeter: bool = bool(fence_data.get("is_perimeter_fence", false))

	object_preview.show_defense(ITEM_FENCE, state)

	var action_text: String = _get_condition_action_text(
		ITEM_FENCE,
		state,
		is_perimeter,
		moving,
		defense_manager.get_fence_repair_cost_scrap(fence_key)
	)

	details_label.text = (
		"FENCE\n\n"
		+ ("State: %s\n" % state.capitalize())
		+ ("HP: %d/%d\n" % [current_hp, max_hp])
		+ ("Perimeter: %s\n\n" % ("Yes" if is_perimeter else "No"))
		+ action_text
	)

func _get_condition_action_text(
	item_id: String,
	state: String,
	is_perimeter: bool,
	moving: bool,
	repair_cost: int
) -> String:
	if moving:
		return (
			"MOVING\nLeft-click a valid destination.\n"
			+ "Right-click, close the War Table, or choose another tool to cancel."
		)

	if state == DefenseManager.PLACEABLE_STATE_BROKEN:
		return (
			"Broken — cannot be moved or removed.\n"
			+ ("Rebuild in the field: %d Scrap." % repair_cost)
		)

	if state == DefenseManager.PLACEABLE_STATE_DAMAGED:
		return (
			"Damaged — cannot be moved or removed.\n"
			+ ("Repair in the field: %d Scrap." % repair_cost)
		)

	if item_id == ITEM_FENCE and is_perimeter:
		return "Full HP. Perimeter fences are fixed to the farm boundary."

	return (
		"Full health.\n"
		+ "Left-click to reposition.\n"
		+ "Right-click to return to inventory."
	)
