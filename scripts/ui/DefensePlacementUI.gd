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

var defense_manager: DefenseManager = null
var selected_item_id: String = ""
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
	"4. Remove mistakes",
	"5. Prepare before night"
]
var war_table_guide_bodies: Array[String] = [
	"Choose Pesticide Turret, Fence, or NightLight from the right side. The left panel explains the selected object and its placement rules.",
	"Turrets and NightLights use grid cells. Select the item, then left-click a valid green cell inside the farm boundary.",
	"Fences are placed on grid lines, not inside cells. Select Fence, then left-click close to the grid line where you want a barrier.",
	"Right-click a placed turret, NightLight, or fence to remove it. Broken objects can be sent to the Workshop repair queue.",
	"Use the War Table during the day to prepare the farm before night. Close this menu yourself when you are done looking around."
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
	status_label.text = "Select a defence item."
	visible = true

	if instruction_label != null:
		instruction_label.visible = false

	_maybe_show_war_table_guide()
	update_ui()

func close_ui() -> void:
	var was_visible: bool = visible

	selected_item_id = ""
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
	war_table_guide_page_index = maxi(
		0,
		war_table_guide_page_index - 1
	)

	_update_war_table_guide_page()

func _on_war_table_guide_next_pressed() -> void:
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

func _on_pesticide_turret_button_pressed() -> void:
	if defense_manager == null:
		return

	if defense_manager.get_pesticide_turrets_available() <= 0:
		status_label.text = "No Pesticide Turrets remain."
		return

	selected_item_id = ITEM_PESTICIDE_TURRET
	status_label.text = "Select a valid farm grid cell."

	update_ui()

func _on_fence_button_pressed() -> void:
	if defense_manager == null:
		return

	if defense_manager.get_fences_available() <= 0:
		status_label.text = "No fences remain in storage."
		return

	selected_item_id = ITEM_FENCE

	status_label.text = (
		"Click close to a grid line to place a fence."
	)

	update_ui()

func _on_nightlight_button_pressed() -> void:
	if defense_manager == null:
		return

	if not defense_manager.has_method("get_nightlights_available"):
		status_label.text = "NightLights are unavailable."
		return

	if int(defense_manager.call("get_nightlights_available")) <= 0:
		status_label.text = "No NightLights remain."
		return

	selected_item_id = ITEM_NIGHTLIGHT
	status_label.text = "Select a valid farm grid cell for the NightLight."

	update_ui()

func _on_grid_cell_left_clicked(
	grid_cell: Vector2i
) -> void:
	if defense_manager == null:
		return

	if selected_item_id == ITEM_PESTICIDE_TURRET:
		_place_pesticide_turret(grid_cell)
		return

	if selected_item_id == ITEM_NIGHTLIGHT:
		_place_nightlight(grid_cell)
		return

	status_label.text = "Select a defence item first."
	update_ui()

func _place_pesticide_turret(grid_cell: Vector2i) -> void:
	var placed_successfully: bool = (
		defense_manager.place_pesticide_turret(grid_cell)
	)

	if placed_successfully:
		status_label.text = "Pesticide Turret placed."

		if defense_manager.get_pesticide_turrets_available() <= 0:
			selected_item_id = ""

	update_ui()

func _place_nightlight(grid_cell: Vector2i) -> void:
	if not defense_manager.has_method("place_nightlight"):
		status_label.text = "NightLight placement is unavailable."
		update_ui()
		return

	var placed_successfully: bool = bool(
		defense_manager.call("place_nightlight", grid_cell)
	)

	if placed_successfully:
		status_label.text = "NightLight placed."

		if int(defense_manager.call("get_nightlights_available")) <= 0:
			selected_item_id = ""

	update_ui()

func _on_fence_edge_left_clicked(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null:
		return

	if selected_item_id != ITEM_FENCE:
		status_label.text = "Select Fence from the inventory first."
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

func _on_grid_cell_right_clicked(
	grid_cell: Vector2i
) -> void:
	if defense_manager == null:
		return

	if _try_remove_nightlight(grid_cell):
		update_ui()
		return

	if _try_remove_pesticide_turret(grid_cell):
		update_ui()
		return

	status_label.text = "No placed item exists on this grid cell."
	update_ui()

func _try_remove_nightlight(grid_cell: Vector2i) -> bool:
	if not defense_manager.has_method("has_nightlight"):
		return false

	if not bool(defense_manager.call("has_nightlight", grid_cell)):
		return false

	if not defense_manager.has_method("remove_nightlight"):
		status_label.text = "NightLight removal is unavailable."
		return true

	var nightlight_state_before_removal: String = "perfect"

	if defense_manager.has_method("get_nightlight_key"):
		var nightlight_key: String = str(
			defense_manager.call("get_nightlight_key", grid_cell)
		)

		if defense_manager.has_method("get_nightlight_state"):
			nightlight_state_before_removal = str(
				defense_manager.call(
					"get_nightlight_state",
					nightlight_key
				)
			)

	var removed_successfully: bool = bool(
		defense_manager.call("remove_nightlight", grid_cell)
	)

	if removed_successfully:
		if nightlight_state_before_removal == (
			DefenseManager.PLACEABLE_STATE_BROKEN
		):
			status_label.text = (
				"Broken NightLight moved to Workshop repair queue."
			)
		else:
			status_label.text = "NightLight returned to inventory."

	return true

func _try_remove_pesticide_turret(grid_cell: Vector2i) -> bool:
	if not defense_manager.has_method("has_turret"):
		return false

	if not defense_manager.has_turret(grid_cell):
		return false

	var turret_key: String = defense_manager.get_turret_key(grid_cell)

	var turret_state_before_removal: String = (
		defense_manager.get_turret_state(turret_key)
	)

	var removed_successfully: bool = (
		defense_manager.remove_pesticide_turret(grid_cell)
	)

	if removed_successfully:
		if turret_state_before_removal == DefenseManager.PLACEABLE_STATE_BROKEN:
			status_label.text = (
				"Broken Pesticide Turret moved to Workshop repair queue."
			)
		else:
			status_label.text = (
				"Pesticide Turret returned to inventory."
			)

	return true

func _on_fence_edge_right_clicked(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null:
		return

	var fence_key: String = defense_manager.get_fence_key(
		orientation,
		grid_edge
	)

	var fence_state_before_removal: String = (
		defense_manager.get_fence_state(fence_key)
	)

	var removed_successfully: bool = defense_manager.remove_fence(
		fence_key
	)

	if removed_successfully:
		if fence_state_before_removal == DefenseManager.FENCE_STATE_BROKEN:
			status_label.text = (
				"Broken Fence moved to Workshop repair queue."
			)
		else:
			status_label.text = "Fence returned to inventory."

	update_ui()

func _on_inventory_changed(
	_remaining_turrets: int
) -> void:
	update_ui()

func _on_fence_inventory_changed(
	_remaining_fences: int
) -> void:
	update_ui()

func _on_nightlight_inventory_changed(
	_remaining_nightlights: int
) -> void:
	update_ui()

func _on_placement_failed(reason: String) -> void:
	status_label.text = reason
	update_ui()

func update_ui() -> void:
	if defense_manager == null:
		return

	var available_turrets: int = (
		defense_manager.get_pesticide_turrets_available()
	)

	var available_fences: int = (
		defense_manager.get_fences_available()
	)

	var available_nightlights: int = 0

	if defense_manager.has_method("get_nightlights_available"):
		available_nightlights = int(
			defense_manager.call("get_nightlights_available")
		)

	pesticide_turret_button.text = (
		"PESTICIDE TURRET x%d" % available_turrets
	)

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
	grid_board.configure(defense_manager, selected_item_id)

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

	if selected_item_id == ITEM_PESTICIDE_TURRET:
		details_label.text = (
			"PESTICIDE TURRET\n\n"
			+ "Damage: 8\n"
			+ "Damage Type: Poison\n"
			+ "Targeting: Nearest Enemy\n"
			+ "Attack Style: Single Target\n"
			+ "Attack Interval: 1.0 sec\n"
			+ "Range: 180\n\n"
			+ "Select a valid grid cell to place."
		)
		return

	if selected_item_id == ITEM_FENCE:
		details_label.text = (
			"FENCE\n\n"
			+ ("Max HP: %d\n" % int(defense_manager.fence_max_health))
			+ "Blocks: Player and enemies\n"
			+ "Does not block: Projectiles and AoE\n\n"
			+ "Perfect fences can be removed.\n"
			+ "Damaged fences must be fixed in the field.\n"
			+ "Broken fences go to the Workshop repair queue.\n\n"
			+ "Click near a grid line to place."
		)
		return

	if selected_item_id == ITEM_NIGHTLIGHT:
		var max_integrity: int = 100
		var wear_rate: float = 0.0

		if "nightlight_max_integrity" in defense_manager:
			max_integrity = int(defense_manager.get("nightlight_max_integrity"))

		if "nightlight_wear_per_second" in defense_manager:
			wear_rate = float(defense_manager.get("nightlight_wear_per_second"))

		details_label.text = (
			"NIGHTLIGHT\n\n"
			+ ("Integrity: %d\n" % max_integrity)
			+ ("Night Wear: %.2f/sec\n" % wear_rate)
			+ "Purpose: Visibility\n"
			+ "Light Type: Warm local glow\n"
			+ "Best Use: Farm paths, breach points, and defence zones\n\n"
			+ "NightLights do not damage enemies.\n"
			+ "They slowly wear down while active at night.\n"
			+ "Broken NightLights go to the Workshop repair queue.\n\n"
			+ "Select a valid grid cell to place."
		)
		return

	details_label.text = (
		"ITEM DETAILS\n\n"
		+ "Select an inventory item to view its "
		+ "properties, placement rules, and combat behaviour."
	)
