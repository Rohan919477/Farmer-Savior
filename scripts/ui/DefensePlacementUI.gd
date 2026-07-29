extends CanvasLayer
class_name DefensePlacementUI

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

	show_controls_hint()
	update_ui()

func close_ui() -> void:
	selected_item_id = ""
	visible = false

func show_controls_hint() -> void:
	if instruction_tween != null:
		instruction_tween.kill()

	instruction_label.text = (
		"Left-click an item to select it. "
		+ "Turrets and NightLights use grid cells. "
		+ "For fences, click close to a grid line. "
		+ "Right-click a placed item to remove it."
	)

	instruction_label.visible = true
	instruction_label.modulate = Color(1, 1, 1, 1)

	instruction_tween = create_tween()
	instruction_tween.tween_interval(5.0)

	instruction_tween.tween_property(
		instruction_label,
		"modulate:a",
		0.0,
		0.5
	)

	instruction_tween.tween_callback(_hide_controls_hint)

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
