extends Node2D

@onready var map_manager: Node = $MapManager
@onready var time_manager: Node = $TimeManager
@onready var hud: CanvasLayer = $HUD
@onready var map_menu: Control = $MapMenu
@onready var defense_manager: DefenseManager = $DefenseManager
@onready var defense_placement_ui: DefensePlacementUI = $DefensePlacementUI
@onready var spawn_manager: Node = $SpawnManager

@onready var title_screen_ui: TitleScreenUI = $TitleScreenUI
@onready var tutorial_popup_ui: TutorialPopupUI = $TutorialPopupUI
@onready var tutorial_manager: TutorialManager = $TutorialManager
@onready var game_over_ui: GameOverUI = $GameOverUI

var dawn_transition_running: bool = false

func _ready() -> void:
	add_to_group("main")

	if time_manager.has_signal("night_started"):
		time_manager.night_started.connect(_on_night_started)

	if time_manager.has_signal("time_changed"):
		time_manager.time_changed.connect(_on_time_changed)

	if time_manager.has_signal("midnight_reached"):
		time_manager.midnight_reached.connect(_on_midnight_reached)

	if spawn_manager.has_signal("night_cleanup_cleared"):
		spawn_manager.night_cleanup_cleared.connect(
			_on_night_cleanup_cleared
		)

	if title_screen_ui != null:
		title_screen_ui.play_pressed.connect(
			_on_title_screen_play_pressed
		)

func get_workshop_ui() -> Node:
	return get_node_or_null("WorkshopUI")

func _on_title_screen_play_pressed() -> void:
	if tutorial_manager != null:
		tutorial_manager.start_tutorial()

func handle_player_death() -> void:
	print("[Death Debug] Main.handle_player_death() called.")

	close_workshop()
	close_defense_placement()

	if map_manager != null and map_manager.has_method("close_map_menu"):
		map_manager.close_map_menu()

	if game_over_ui == null:
		print("[Death Debug] GameOverUI is null.")
		return

	print("[Death Debug] Showing Game Over UI.")
	game_over_ui.show_game_over()

func _on_midnight_reached() -> void:
	if tutorial_manager != null:
		if tutorial_manager.has_method("handle_midnight_reached"):
			var tutorial_handled_midnight: bool = bool(
				tutorial_manager.call("handle_midnight_reached")
			)

			if tutorial_handled_midnight:
				return

	if spawn_manager.has_method("has_active_enemies"):
		if spawn_manager.has_active_enemies():
			if hud.has_method("show_warning_message"):
				hud.show_warning_message("Clear the remaining enemies.")
			return

	start_dawn_transition()

func _on_night_cleanup_cleared() -> void:
	start_dawn_transition()

func start_dawn_transition() -> void:
	if dawn_transition_running:
		return

	dawn_transition_running = true

	if hud.has_method("fade_to_black"):
		await hud.fade_to_black(0.35)

	if time_manager.has_method("complete_night_and_start_new_day"):
		time_manager.complete_night_and_start_new_day()

	await get_tree().create_timer(0.10).timeout

	if hud.has_method("fade_from_black"):
		await hud.fade_from_black(0.35)

	dawn_transition_running = false

func open_map_menu() -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		print("Cannot use the map table at night.")

		if hud.has_method("show_warning_message"):
			hud.show_warning_message(
				"It is too dangerous to travel at night."
			)

		return

	close_workshop()
	map_manager.open_map_menu()

func travel_to_location(location_id: String) -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		print("Cannot travel at night.")

		if hud.has_method("show_warning_message"):
			hud.show_warning_message(
				"It is too dangerous to travel at night."
			)

		return

	close_workshop()
	map_manager.travel_to_location(location_id)

func open_defense_placement() -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		if hud.has_method("show_warning_message"):
			hud.show_warning_message(
				"There is no time to plan defenses now."
			)

		return

	close_workshop()
	defense_placement_ui.open_ui(defense_manager)
	if tutorial_manager != null:
		if tutorial_manager.has_method("on_preparation_system_opened"):
			tutorial_manager.call(
				"on_preparation_system_opened",
				"War Table"
			)

func close_defense_placement() -> void:
	if defense_placement_ui != null:
		defense_placement_ui.close_ui()

func open_workshop() -> void:
	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		if hud.has_method("show_warning_message"):
			hud.show_warning_message(
				"The Workshop can only be used during daytime."
			)

		return

	var workshop_ui: Node = get_workshop_ui()

	if workshop_ui == null:
		print("WorkshopUI is missing from Main.tscn.")
		return

	if workshop_ui.has_method("open_workshop"):
		workshop_ui.call("open_workshop")
	
	if tutorial_manager != null:
		if tutorial_manager.has_method("on_preparation_system_opened"):
			tutorial_manager.call(
				"on_preparation_system_opened",
				"Workshop"
			)

func close_workshop() -> void:
	var workshop_ui: Node = get_workshop_ui()

	if workshop_ui == null:
		return

	if workshop_ui.has_method("close_workshop"):
		workshop_ui.call("close_workshop")

func _on_night_started() -> void:
	map_manager.close_map_menu()
	close_defense_placement()
	close_workshop()

	print("Main received night_started signal.")

	if map_manager.current_location_id == "farm":
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message(
				"It is turning night. Here they come."
			)
	else:
		if hud.has_method("show_nightfall_message"):
			hud.show_nightfall_message(
				"It is getting late, I need to return."
			)

	map_manager.force_return_to_farm()

func is_gameplay_input_blocked() -> bool:
	if title_screen_ui != null:
		if title_screen_ui.is_title_screen_open():
			return true

	if tutorial_popup_ui != null:
		if tutorial_popup_ui.is_popup_open():
			return true

	if game_over_ui != null:
		if game_over_ui.is_game_over_open():
			return true

	var workshop_ui: Node = get_workshop_ui()

	if workshop_ui != null and workshop_ui.has_method("is_workshop_open"):
		if bool(workshop_ui.call("is_workshop_open")):
			return true

	var inventory_ui: Node = get_node_or_null("PlayerInventoryUI")

	if inventory_ui != null and inventory_ui.has_method("is_inventory_open"):
		if bool(inventory_ui.call("is_inventory_open")):
			return true

	return (
		dawn_transition_running
		or map_menu.visible
		or defense_placement_ui.visible
	)

func _on_time_changed(
	day_number: int,
	hour: int,
	minute: int,
	phase: String
) -> void:
	if hud.has_method("update_time"):
		hud.update_time(day_number, hour, minute, phase)
