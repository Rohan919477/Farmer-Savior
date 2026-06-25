extends Node2D

@onready var map_manager: Node = $MapManager
@onready var time_manager: Node = $TimeManager
@onready var hud: CanvasLayer = $HUD
@onready var map_menu: Control = $MapMenu
@onready var defense_manager: DefenseManager = $DefenseManager
@onready var defense_placement_ui: DefensePlacementUI = $DefensePlacementUI

func _ready() -> void:
	add_to_group("main")

	if time_manager.has_signal("night_started"):
		time_manager.night_started.connect(_on_night_started)

	if time_manager.has_signal("time_changed"):
		time_manager.time_changed.connect(_on_time_changed)

func open_map_menu() -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		print("Cannot use the map table at night.")
		if hud.has_method("show_warning_message"):
			hud.show_warning_message("It is too dangerous to travel at night.")
		return

	map_manager.open_map_menu()

func travel_to_location(location_id: String) -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		print("Cannot travel at night.")
		if hud.has_method("show_warning_message"):
			hud.show_warning_message("It is too dangerous to travel at night.")
		return

	map_manager.travel_to_location(location_id)

func open_defense_placement() -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		if hud.has_method("show_warning_message"):
			hud.show_warning_message("There is no time to plan defenses now.")
		return

	defense_placement_ui.open_ui(defense_manager)
	
func close_defense_placement() -> void:
	if defense_placement_ui != null:
		defense_placement_ui.close_ui()

func _on_night_started() -> void:
	map_manager.close_map_menu()
	close_defense_placement()

	print("Main received night_started signal.")

	if map_manager.current_location_id == "farm":
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message("It is turning night. Here they come.")
	else:
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message("It is getting late, I need to return.")

	map_manager.force_return_to_farm()
	
func is_gameplay_input_blocked() -> bool:
	return map_menu.visible or defense_placement_ui.visible

func _on_time_changed(day_number: int, hour: int, minute: int, phase: String) -> void:
	if hud.has_method("update_time"):
		hud.update_time(day_number, hour, minute, phase)
