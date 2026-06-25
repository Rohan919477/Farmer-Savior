extends CanvasLayer
class_name DefensePlacementUI

@onready var grid_board: DefenseGridBoard = $RootControl/MainPanel/GridBoard
@onready var pesticide_turret_button: Button = $RootControl/MainPanel/Sidebar/VBoxContainer/PesticideTurretButton
@onready var locked_tool_1_button: Button = $RootControl/MainPanel/Sidebar/VBoxContainer/LockedTool1Button
@onready var locked_tool_2_button: Button = $RootControl/MainPanel/Sidebar/VBoxContainer/LockedTool2Button
@onready var status_label: Label = $RootControl/MainPanel/Sidebar/VBoxContainer/StatusLabel
@onready var close_button: Button = $RootControl/MainPanel/Sidebar/VBoxContainer/CloseButton
@onready var remove_turret_button: Button = $RootControl/MainPanel/Sidebar/VBoxContainer/RemoveTurretButton

var defense_manager: DefenseManager = null
var selected_item_id: String = ""

func _ready() -> void:
	pesticide_turret_button.pressed.connect(_on_pesticide_turret_button_pressed)
	close_button.pressed.connect(close_ui)
	grid_board.grid_cell_clicked.connect(_on_grid_cell_clicked)
	remove_turret_button.pressed.connect(_on_remove_turret_button_pressed)

	visible = false
	
func _on_remove_turret_button_pressed() -> void:
	if defense_manager == null:
		return

	if not defense_manager.has_placed_turrets():
		status_label.text = "There are no placed turrets to remove."
		return

	selected_item_id = "remove_turret"
	status_label.text = "Click a placed turret marker to return it to inventory."

	update_ui()

func open_ui(new_defense_manager: DefenseManager) -> void:
	if defense_manager != new_defense_manager:
		defense_manager = new_defense_manager

		if not defense_manager.inventory_changed.is_connected(_on_inventory_changed):
			defense_manager.inventory_changed.connect(_on_inventory_changed)

		if not defense_manager.placement_failed.is_connected(_on_placement_failed):
			defense_manager.placement_failed.connect(_on_placement_failed)

	selected_item_id = ""
	status_label.text = "Select a defence item."
	visible = true

	update_ui()

func close_ui() -> void:
	selected_item_id = ""
	visible = false

func _on_pesticide_turret_button_pressed() -> void:
	if defense_manager == null:
		return

	if defense_manager.get_pesticide_turrets_available() <= 0:
		status_label.text = "No Pesticide Turrets remain."
		return

	selected_item_id = "pesticide_turret"
	status_label.text = "Select a valid farm grid cell."

	update_ui()

func _on_grid_cell_clicked(grid_cell: Vector2i) -> void:
	if defense_manager == null:
		return

	match selected_item_id:
		"pesticide_turret":
			var placed_successfully: bool = defense_manager.place_pesticide_turret(grid_cell)

			if placed_successfully:
				status_label.text = "Pesticide Turret placed."

				if defense_manager.get_pesticide_turrets_available() <= 0:
					selected_item_id = ""

				update_ui()

		"remove_turret":
			var removed_successfully: bool = defense_manager.remove_pesticide_turret(grid_cell)

			if removed_successfully:
				status_label.text = "Pesticide Turret returned to inventory."

				if not defense_manager.has_placed_turrets():
					selected_item_id = ""

				update_ui()

		_:
			status_label.text = "Select a defence item or removal mode first."

func _on_inventory_changed(_remaining_turrets: int) -> void:
	update_ui()

func _on_placement_failed(reason: String) -> void:
	status_label.text = reason
	update_ui()

func update_ui() -> void:
	if defense_manager == null:
		return

	var available_turrets: int = defense_manager.get_pesticide_turrets_available()
	var has_placed_turrets: bool = defense_manager.has_placed_turrets()

	pesticide_turret_button.text = "PESTICIDE TURRET x%d" % available_turrets
	pesticide_turret_button.disabled = available_turrets <= 0
	remove_turret_button.disabled = not has_placed_turrets

	if selected_item_id == "pesticide_turret":
		pesticide_turret_button.self_modulate = Color(0.18, 0.35, 0.75)
	else:
		pesticide_turret_button.self_modulate = Color(0.48, 0.60, 0.72)

	if selected_item_id == "remove_turret":
		remove_turret_button.self_modulate = Color(0.75, 0.20, 0.20)
	else:
		remove_turret_button.self_modulate = Color(0.55, 0.55, 0.55)

	locked_tool_1_button.self_modulate = Color(0.45, 0.52, 0.60)
	locked_tool_2_button.self_modulate = Color(0.45, 0.52, 0.60)

	grid_board.configure(defense_manager, selected_item_id)
