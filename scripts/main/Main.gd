extends Node2D

@onready var map_manager: Node = $MapManager
@onready var time_manager: Node = $TimeManager
@onready var hud: CanvasLayer = $HUD

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

func _on_night_started() -> void:
	print("Main received night_started signal.")

	if map_manager.current_location_id == "farm":
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message("It is turning night. Here they come.")
	else:
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message("It is getting late, I need to return.")

	map_manager.force_return_to_farm()

func _on_time_changed(day_number: int, hour: int, minute: int, phase: String) -> void:
	if hud.has_method("update_time"):
		hud.update_time(day_number, hour, minute, phase)
