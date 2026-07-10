extends CanvasLayer
class_name DefensePlacementUI

@onready var grid_board: DefenseGridBoard = (
	$RootControl/MainPanel/GridBoard
)

@onready var pesticide_turret_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/PesticideTurretButton
)

@onready var fence_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/FenceButton
)

@onready var locked_tool_1_button: Button = (
	$RootControl/MainPanel/Sidebar/VBoxContainer/LockedTool1Button
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

	selected_item_id = "pesticide_turret"
	status_label.text = "Select a valid farm grid cell."

	update_ui()

func _on_fence_button_pressed() -> void:
	if defense_manager == null:
		return

	if defense_manager.get_fences_available() <= 0:
		status_label.text = "No fences remain in storage."
		return

	selected_item_id = "fence"

	status_label.text = (
		"Click close to a grid line to place a fence."
	)

	update_ui()

func _on_grid_cell_left_clicked(
	grid_cell: Vector2i
) -> void:
	if defense_manager == null:
		return

	if selected_item_id != "pesticide_turret":
		status_label.text = "Select a defence item first."
		return

	var placed_successfully: bool = (
		defense_manager.place_pesticide_turret(grid_cell)
	)

	if placed_successfully:
		status_label.text = "Pesticide Turret placed."

		if defense_manager.get_pesticide_turrets_available() <= 0:
			selected_item_id = ""

	update_ui()

func _on_fence_edge_left_clicked(
	orientation: String,
	grid_edge: Vector2i
) -> void:
	if defense_manager == null:
		return

	if selected_item_id != "fence":
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

	if not defense_manager.is_cell_occupied(grid_cell):
		status_label.text = "No placed item exists on this grid cell."
		return

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

	update_ui()

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

	pesticide_turret_button.text = (
		"PESTICIDE TURRET x%d" % available_turrets
	)

	fence_button.text = "FENCE x%d" % available_fences

	pesticide_turret_button.disabled = available_turrets <= 0
	fence_button.disabled = available_fences <= 0

	if selected_item_id == "pesticide_turret":
		pesticide_turret_button.self_modulate = (
			Color(0.18, 0.35, 0.75)
		)
	else:
		pesticide_turret_button.self_modulate = (
			Color(0.48, 0.60, 0.72)
		)

	if selected_item_id == "fence":
		fence_button.self_modulate = (
			Color(0.18, 0.35, 0.75)
		)
	else:
		fence_button.self_modulate = (
			Color(0.48, 0.60, 0.72)
		)

	locked_tool_1_button.self_modulate = Color(0.45, 0.52, 0.60)
	locked_tool_2_button.self_modulate = Color(0.45, 0.52, 0.60)

	update_details_panel()
	grid_board.configure(defense_manager, selected_item_id)

func update_details_panel() -> void:
	if defense_manager == null:
		return

	if selected_item_id == "pesticide_turret":
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

	if selected_item_id == "fence":
		details_label.text = (
			"FENCE\n\n"
			+ "Max HP: %d\n"
			% int(defense_manager.fence_max_health)
			+ "Blocks: Player and enemies\n"
			+ "Does not block: Projectiles and AoE\n\n"
			+ "Perfect fences can be removed.\n"
			+ "Damaged fences must be fixed in the field.\n"
			+ "Broken fences go to the Workshop repair queue.\n\n"
			+ "Click near a grid line to place."
		)
		return

	details_label.text = (
		"ITEM DETAILS\n\n"
		+ "Select an inventory item to view its "
		+ "properties, placement rules, and combat behaviour."
	)
