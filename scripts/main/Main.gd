extends Node2D

const NIGHT_STATE_DAY: String = "day"
const NIGHT_STATE_HOUSE_EVACUATION: String = "house_evacuation"
const NIGHT_STATE_COMBAT: String = "night_combat"
const NIGHT_STATE_CLEARED: String = "night_cleared"

const SAVE_SLOT_CONTEXT_NONE: String = "none"
const SAVE_SLOT_CONTEXT_TITLE_NEW_GAME: String = "title_new_game"
const SAVE_SLOT_CONTEXT_TITLE_LOAD: String = "title_load"
const SAVE_SLOT_CONTEXT_PAUSE_LOAD: String = "pause_load"
const SAVE_SLOT_CONTEXT_BED_SLEEP: String = "bed_sleep"

const HOUSE_EVACUATION_DURATION: float = 20.0

const HOUSE_LIGHT_TEXTURE_SIZE: int = 384
const HOUSE_LIGHT_TEXTURE_SCALE: float = 2.0
const HOUSE_LIGHT_COLOR: Color = Color(1.0, 0.78, 0.42, 1.0)
const HOUSE_LIGHT_ENERGY: float = 2.4
const HOUSE_LIGHT_Z_INDEX: int = 30

@onready var map_manager: Node = $MapManager
@onready var time_manager: Node = $TimeManager
@onready var hud: CanvasLayer = $HUD
@onready var map_menu: Control = $MapMenu
@onready var defense_manager: DefenseManager = $DefenseManager
@onready var defense_placement_ui: DefensePlacementUI = $DefensePlacementUI
@onready var spawn_manager: Node = $SpawnManager
@onready var world_drop_manager: Node = $WorldDropManager

@onready var title_screen_ui: TitleScreenUI = $TitleScreenUI
@onready var tutorial_popup_ui: TutorialPopupUI = $TutorialPopupUI
@onready var tutorial_manager: TutorialManager = $TutorialManager
@onready var game_over_ui: GameOverUI = $GameOverUI
@onready var player: Node2D = $Player
@onready var save_manager: SaveManager = $SaveManager
@onready var save_slot_ui: SaveSlotUI = $SaveSlotUI
@onready var pause_menu: PauseMenuUI = $PauseMenu
@onready var telemetry_manager: TelemetryManager = $TelemetryManager

var normal_night_state: String = NIGHT_STATE_DAY
var house_evacuation_timer: float = 0.0
var house_entry_locked_until_clear: bool = false

var night_cleared_blocked_messages: Array[String] = [
	"I am too tired for this.",
	"I should go to sleep.",
	"My body is giving out.",
	"Not now. I need rest.",
	"The night is over. I should sleep.",
	"I can deal with this in the morning."
]

var house_evacuation_blocked_messages: Array[String] = [
	"I have to get outside.",
	"The walls are breathing.",
	"I can't stay in here.",
	"The house does not feel safe.",
	"I need to face the night outside."
]

var dawn_transition_running: bool = false
var sleep_transition_running: bool = false
var pending_manual_save_slot: int = -1
var active_manual_save_slot: int = -1
var reserved_new_game_manual_slot: int = -1
var save_slot_menu_context: String = SAVE_SLOT_CONTEXT_NONE
var house_light_texture: Texture2D = null

func _ready() -> void:
	add_to_group("main")

	if map_manager != null and map_manager.has_signal("location_loaded"):
		if not map_manager.location_loaded.is_connected(
			_on_location_loaded
		):
			map_manager.location_loaded.connect(_on_location_loaded)

	if time_manager.has_signal("night_started"):
		time_manager.night_started.connect(_on_night_started)

	if time_manager.has_signal("time_changed"):
		time_manager.time_changed.connect(_on_time_changed)

	if time_manager.has_signal("midnight_reached"):
		time_manager.midnight_reached.connect(_on_midnight_reached)

	if spawn_manager != null:
		if spawn_manager.has_signal("night_cleanup_cleared"):
			if not spawn_manager.night_cleanup_cleared.is_connected(
				_on_night_cleanup_cleared
			):
				spawn_manager.night_cleanup_cleared.connect(
					_on_night_cleanup_cleared
				)

		if spawn_manager.has_signal("night_enemy_count_changed"):
			if not spawn_manager.night_enemy_count_changed.is_connected(
				_on_night_enemy_count_changed
			):
				spawn_manager.night_enemy_count_changed.connect(
					_on_night_enemy_count_changed
				)

		if spawn_manager.has_signal("normal_night_finished"):
			if not spawn_manager.normal_night_finished.is_connected(
				_on_normal_night_finished
			):
				spawn_manager.normal_night_finished.connect(
					_on_normal_night_finished
				)

	if defense_placement_ui != null:
		if defense_placement_ui.has_signal("defense_placement_closed"):
			if not defense_placement_ui.defense_placement_closed.is_connected(
				_on_defense_placement_closed
			):
				defense_placement_ui.defense_placement_closed.connect(
					_on_defense_placement_closed
				)

	if save_slot_ui != null:
		if save_slot_ui.has_signal("save_slot_selected"):
			if not save_slot_ui.save_slot_selected.is_connected(
				_on_save_slot_selected
			):
				save_slot_ui.save_slot_selected.connect(
					_on_save_slot_selected
				)

		if save_slot_ui.has_signal("save_slot_cancelled"):
			if not save_slot_ui.save_slot_cancelled.is_connected(
				_on_save_slot_cancelled
			):
				save_slot_ui.save_slot_cancelled.connect(
					_on_save_slot_cancelled
				)

		if save_slot_ui.has_signal("new_game_slot_selected"):
			if not save_slot_ui.new_game_slot_selected.is_connected(
				_on_new_game_slot_selected
			):
				save_slot_ui.new_game_slot_selected.connect(
					_on_new_game_slot_selected
				)

		if save_slot_ui.has_signal("load_slot_selected"):
			if not save_slot_ui.load_slot_selected.is_connected(
				_on_load_slot_selected
			):
				save_slot_ui.load_slot_selected.connect(
					_on_load_slot_selected
				)

		if save_slot_ui.has_signal("slot_menu_cancelled"):
			if not save_slot_ui.slot_menu_cancelled.is_connected(
				_on_slot_menu_cancelled
			):
				save_slot_ui.slot_menu_cancelled.connect(
					_on_slot_menu_cancelled
				)

	if pause_menu != null:
		if pause_menu.has_signal("resume_requested"):
			if not pause_menu.resume_requested.is_connected(
				_on_pause_resume_requested
			):
				pause_menu.resume_requested.connect(
					_on_pause_resume_requested
				)

		if pause_menu.has_signal("settings_requested"):
			if not pause_menu.settings_requested.is_connected(
				_on_pause_settings_requested
			):
				pause_menu.settings_requested.connect(
					_on_pause_settings_requested
				)

		if pause_menu.has_signal("load_save_requested"):
			if not pause_menu.load_save_requested.is_connected(
				_on_pause_load_save_requested
			):
				pause_menu.load_save_requested.connect(
					_on_pause_load_save_requested
				)

		if pause_menu.has_signal("back_to_title_requested"):
			if not pause_menu.back_to_title_requested.is_connected(
				_on_pause_back_to_title_requested
			):
				pause_menu.back_to_title_requested.connect(
					_on_pause_back_to_title_requested
				)

	if title_screen_ui != null:
		if title_screen_ui.has_signal("new_game_pressed"):
			if not title_screen_ui.new_game_pressed.is_connected(
				_on_title_screen_new_game_pressed
			):
				title_screen_ui.new_game_pressed.connect(
					_on_title_screen_new_game_pressed
				)

		if title_screen_ui.has_signal("load_save_pressed"):
			if not title_screen_ui.load_save_pressed.is_connected(
				_on_title_screen_load_save_pressed
			):
				title_screen_ui.load_save_pressed.connect(
					_on_title_screen_load_save_pressed
				)

func _on_location_loaded(location_id: String, loaded_map: Node) -> void:
	if location_id != "house":
		return

	_ensure_house_interior_lights(loaded_map)


func _ensure_house_interior_lights(loaded_map: Node) -> void:
	if loaded_map == null:
		return

	if loaded_map.get_node_or_null("PermanentInteriorLights") != null:
		return

	var light_root: Node2D = Node2D.new()
	light_root.name = "PermanentInteriorLights"
	loaded_map.add_child(light_root)

	var light_positions: Array[Vector2] = [
		Vector2(-245.0, -205.0),
		Vector2(245.0, -205.0),
		Vector2(-245.0, 205.0),
		Vector2(245.0, 205.0)
	]

	for index in range(light_positions.size()):
		var point_light: PointLight2D = PointLight2D.new()
		point_light.name = "InteriorLight%d" % (index + 1)
		point_light.position = light_positions[index]
		point_light.texture = _get_house_light_texture()
		point_light.color = HOUSE_LIGHT_COLOR
		point_light.energy = HOUSE_LIGHT_ENERGY
		point_light.texture_scale = HOUSE_LIGHT_TEXTURE_SCALE
		point_light.shadow_enabled = false
		point_light.z_index = HOUSE_LIGHT_Z_INDEX
		light_root.add_child(point_light)


func _get_house_light_texture() -> Texture2D:
	if house_light_texture != null:
		return house_light_texture

	var image: Image = Image.create(
		HOUSE_LIGHT_TEXTURE_SIZE,
		HOUSE_LIGHT_TEXTURE_SIZE,
		false,
		Image.FORMAT_RGBA8
	)

	var center: Vector2 = Vector2(
		float(HOUSE_LIGHT_TEXTURE_SIZE - 1) * 0.5,
		float(HOUSE_LIGHT_TEXTURE_SIZE - 1) * 0.5
	)

	var radius: float = float(HOUSE_LIGHT_TEXTURE_SIZE) * 0.5

	for y in range(HOUSE_LIGHT_TEXTURE_SIZE):
		for x in range(HOUSE_LIGHT_TEXTURE_SIZE):
			var distance: float = Vector2(x, y).distance_to(center)
			var normalized_distance: float = clampf(
				distance / radius,
				0.0,
				1.0
			)

			var alpha: float = 1.0 - normalized_distance
			alpha = pow(alpha, 2.0)

			image.set_pixel(
				x,
				y,
				Color(1.0, 1.0, 1.0, alpha)
			)

	house_light_texture = ImageTexture.create_from_image(image)
	return house_light_texture


func _process(delta: float) -> void:
	_process_normal_night_state(delta)

func _unhandled_input(event: InputEvent) -> void:
	# Fullscreen input is owned globally by the FullscreenManager autoload.
	# Handling it here as well would toggle twice for the same key press.
	if not event.is_action_pressed("ui_cancel"):
		return

	if _should_ignore_pause_input():
		return

	if pause_menu == null:
		return

	if pause_menu.has_method("is_pause_menu_open"):
		if bool(pause_menu.call("is_pause_menu_open")):
			return

	if pause_menu.has_method("open_pause_menu"):
		pause_menu.call("open_pause_menu")

func _should_ignore_pause_input() -> bool:
	if title_screen_ui != null and title_screen_ui.is_title_screen_open():
		return true

	if tutorial_popup_ui != null and tutorial_popup_ui.is_popup_open():
		return true

	if game_over_ui != null and game_over_ui.is_game_over_open():
		return true

	if save_slot_ui != null:
		if save_slot_ui.has_method("is_save_slot_ui_open"):
			if bool(save_slot_ui.call("is_save_slot_ui_open")):
				return true

	if sleep_transition_running:
		return true

	if dawn_transition_running:
		return true

	return false

func get_workshop_ui() -> Node:
	return get_node_or_null("WorkshopUI")

func _on_title_screen_new_game_pressed() -> void:
	if save_slot_ui == null:
		_start_new_game_with_slot(-1)
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_TITLE_NEW_GAME

	if save_slot_ui.has_method("open_new_game_menu"):
		save_slot_ui.call("open_new_game_menu")
	else:
		_start_new_game_with_slot(-1)

func _on_title_screen_load_save_pressed() -> void:
	if save_slot_ui == null:
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_TITLE_LOAD

	if save_slot_ui.has_method("open_load_game_menu"):
		save_slot_ui.call("open_load_game_menu")

func _on_title_screen_play_pressed() -> void:
	_start_new_game_with_slot(-1)

func _on_new_game_slot_selected(slot_index: int) -> void:
	save_slot_menu_context = SAVE_SLOT_CONTEXT_NONE
	_start_new_game_with_slot(slot_index)

func _start_new_game_with_slot(slot_index: int) -> void:
	active_manual_save_slot = slot_index
	pending_manual_save_slot = -1

	_reset_game_state_for_new_game()
	reserved_new_game_manual_slot = slot_index if slot_index >= 1 else -1

	if title_screen_ui != null:
		title_screen_ui.hide_title_screen()

	get_tree().paused = false

	if tutorial_manager != null:
		if tutorial_manager.has_method("start_tutorial"):
			tutorial_manager.call("start_tutorial")
			
	_log_telemetry("new_game_started", {
		"manual_slot_index": active_manual_save_slot
	})
	
	print("[New Game] Started with manual slot: ", active_manual_save_slot)

func _reset_game_state_for_new_game() -> void:
	close_workshop()
	close_defense_placement()
	close_crop_planting_menu()
	close_player_inventory()

	if map_manager != null and map_manager.has_method("close_map_menu"):
		map_manager.call("close_map_menu")

	if spawn_manager != null:
		if spawn_manager.has_method("stop_normal_night_combat"):
			spawn_manager.call("stop_normal_night_combat")

		if spawn_manager.has_method("clear_active_enemies"):
			spawn_manager.call("clear_active_enemies")

	normal_night_state = NIGHT_STATE_DAY
	house_evacuation_timer = 0.0
	house_entry_locked_until_clear = false
	dawn_transition_running = false
	sleep_transition_running = false
	pending_manual_save_slot = -1
	reserved_new_game_manual_slot = -1

	if tutorial_manager != null:
		if tutorial_manager.has_method("reset_for_new_game"):
			tutorial_manager.call("reset_for_new_game")

	if time_manager != null:
		if time_manager.has_method("reset_for_new_game"):
			time_manager.call("reset_for_new_game")

	var inventory_manager: Node = get_tree().get_first_node_in_group(
		"inventory_manager"
	)

	if inventory_manager != null:
		if inventory_manager.has_method("clear_inventory"):
			inventory_manager.call("clear_inventory")
		elif inventory_manager.has_method("reset_for_new_game"):
			inventory_manager.call("reset_for_new_game")

	if player != null and player.has_method("reset_for_new_game"):
		player.call("reset_for_new_game")

	var upgrade_manager: Node = get_tree().get_first_node_in_group(
		"upgrade_manager"
	)

	if upgrade_manager != null:
		if upgrade_manager.has_method("reset_for_new_game"):
			upgrade_manager.call("reset_for_new_game")

	if defense_manager != null:
		if defense_manager.has_method("reset_for_new_game"):
			defense_manager.call("reset_for_new_game")

	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager != null:
		if crop_manager.has_method("reset_for_new_game"):
			crop_manager.call("reset_for_new_game")

	if world_drop_manager != null:
		if world_drop_manager.has_method("reset_for_new_game"):
			world_drop_manager.call("reset_for_new_game")

	if map_manager != null:
		if map_manager.has_method("reset_for_new_game"):
			map_manager.call("reset_for_new_game")
		elif map_manager.has_method("load_location"):
			map_manager.call("load_location", "farm", "DefaultSpawn")

	if hud != null and hud.has_method("show_time_display"):
		hud.call("show_time_display")

	print("[Main] New game state reset complete.")

func _on_load_slot_selected(slot_index: int) -> void:
	var previous_context: String = save_slot_menu_context

	if _load_game_from_slot(slot_index):
		save_slot_menu_context = SAVE_SLOT_CONTEXT_NONE
		return

	_restore_load_ui_after_failure(previous_context)

func _load_game_from_slot(slot_index: int) -> bool:
	if save_manager == null:
		print("[Load] SaveManager missing.")
		return false

	if not save_manager.has_method("load_slot_data"):
		print("[Load] SaveManager.load_slot_data() missing.")
		return false

	var save_data: Dictionary = save_manager.call(
		"load_slot_data",
		slot_index
	)

	if save_data.is_empty():
		print("[Load] Could not load slot: ", slot_index)
		return false

	if pause_menu != null:
		if pause_menu.has_method("close_pause_menu"):
			pause_menu.call("close_pause_menu", false)

	if title_screen_ui != null:
		title_screen_ui.hide_title_screen()

	_apply_loaded_save_data(save_data, slot_index)

	get_tree().paused = false
	
	_log_telemetry("load_applied_to_game", {
		"slot_index": slot_index
	})

	print("[Load] Game applied from slot: ", slot_index)
	return true

func _restore_load_ui_after_failure(previous_context: String) -> void:
	save_slot_menu_context = previous_context
	get_tree().paused = true

	# SaveSlotUI closes itself before emitting load_slot_selected. If loading
	# fails, reopen the load menu so a paused game is never left with no
	# visible interface and the player can choose/delete another save.
	if save_slot_ui != null and save_slot_ui.has_method("open_load_game_menu"):
		save_slot_ui.call("open_load_game_menu")
		return

	match previous_context:
		SAVE_SLOT_CONTEXT_TITLE_LOAD:
			if title_screen_ui != null:
				title_screen_ui.show_title_screen()

		SAVE_SLOT_CONTEXT_PAUSE_LOAD:
			if pause_menu != null:
				if pause_menu.has_method("open_pause_menu"):
					pause_menu.call("open_pause_menu")

func _apply_loaded_save_data(
	save_data: Dictionary,
	slot_index: int
) -> void:
	active_manual_save_slot = slot_index

	if slot_index == 0:
		active_manual_save_slot = -1

	close_workshop()
	close_defense_placement()
	close_crop_planting_menu()
	close_player_inventory()

	if map_manager != null and map_manager.has_method("close_map_menu"):
		map_manager.call("close_map_menu")

	if spawn_manager != null:
		if spawn_manager.has_method("stop_normal_night_combat"):
			spawn_manager.call("stop_normal_night_combat")

		if spawn_manager.has_method("clear_active_enemies"):
			spawn_manager.call("clear_active_enemies")

	normal_night_state = NIGHT_STATE_DAY
	house_evacuation_timer = 0.0
	house_entry_locked_until_clear = false
	dawn_transition_running = false
	sleep_transition_running = false
	pending_manual_save_slot = -1
	reserved_new_game_manual_slot = -1

	if tutorial_manager != null:
		if tutorial_manager.has_method("prepare_for_load"):
			tutorial_manager.call("prepare_for_load")

	_load_time_from_save(save_data)
	_load_map_from_save(save_data)
	_load_inventory_from_save(save_data)
	_load_player_from_save(save_data)
	_load_upgrade_from_save(save_data)
	_load_defense_from_save(save_data)
	_load_crop_from_save(save_data)
	_load_world_drops_from_save(save_data)
	_load_tutorial_from_save(save_data)

	if hud != null and hud.has_method("show_time_display"):
		hud.call("show_time_display")

	print("[Main] Loaded save data applied.")

func _load_time_from_save(save_data: Dictionary) -> void:
	if time_manager == null:
		return

	var world_data: Dictionary = save_data.get("world", {})
	var time_data: Dictionary = world_data.get(
		"time",
		save_data.get("time", {})
	)

	if time_manager.has_method("load_save_data"):
		time_manager.call("load_save_data", time_data)
		return

func _load_map_from_save(save_data: Dictionary) -> void:
	if map_manager == null:
		return

	var world_data: Dictionary = save_data.get("world", {})
	var map_data: Dictionary = world_data.get(
		"map",
		save_data.get("map", {})
	)

	if map_manager.has_method("load_save_data"):
		map_manager.call("load_save_data", map_data)
		return

	var location_id: String = str(
		map_data.get("current_location_id", "farm")
	)

	if location_id.is_empty():
		location_id = "farm"

	if map_manager.has_method("load_location"):
		map_manager.call("load_location", location_id, "DefaultSpawn")

func _load_inventory_from_save(save_data: Dictionary) -> void:
	var inventory_manager: Node = get_tree().get_first_node_in_group(
		"inventory_manager"
	)

	if inventory_manager == null:
		return

	var inventory_data: Dictionary = save_data.get("inventory", {})

	if inventory_manager.has_method("load_save_data"):
		inventory_manager.call("load_save_data", inventory_data)

func _load_player_from_save(save_data: Dictionary) -> void:
	if player == null:
		return

	var player_data: Dictionary = save_data.get("player", {})

	if player.has_method("load_save_data"):
		player.call("load_save_data", player_data)

func _load_upgrade_from_save(save_data: Dictionary) -> void:
	var upgrade_manager: Node = get_tree().get_first_node_in_group(
		"upgrade_manager"
	)

	if upgrade_manager == null:
		return

	var progression_data: Dictionary = save_data.get("progression", {})
	var upgrade_data: Dictionary = progression_data.get(
		"upgrades",
		save_data.get("upgrades", {})
	)

	if upgrade_manager.has_method("load_save_data"):
		upgrade_manager.call("load_save_data", upgrade_data)

func _load_defense_from_save(save_data: Dictionary) -> void:
	if defense_manager == null:
		return

	var defense_data: Dictionary = save_data.get(
		"defenses",
		save_data.get("defense", {})
	)

	if defense_manager.has_method("load_save_data"):
		defense_manager.call("load_save_data", defense_data)

func _load_crop_from_save(save_data: Dictionary) -> void:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return

	var crop_data: Dictionary = save_data.get(
		"farming",
		save_data.get("crops", {})
	)

	if crop_manager.has_method("load_save_data"):
		crop_manager.call("load_save_data", crop_data)

func _load_world_drops_from_save(save_data: Dictionary) -> void:
	if world_drop_manager == null:
		return

	var maps_data: Dictionary = save_data.get("maps", {})

	if world_drop_manager.has_method("load_save_data"):
		world_drop_manager.call("load_save_data", maps_data)


func _load_tutorial_from_save(save_data: Dictionary) -> void:
	if tutorial_manager == null:
		return

	var progression_data: Dictionary = save_data.get("progression", {})
	var tutorial_data: Dictionary = progression_data.get(
		"tutorial",
		save_data.get("tutorial", {})
	)

	if tutorial_manager.has_method("load_save_data"):
		tutorial_manager.call("load_save_data", tutorial_data)
		return

	var tutorial_completed: bool = bool(
		tutorial_data.get("tutorial_completed", true)
	)

	if "tutorial_completed" in tutorial_manager:
		tutorial_manager.set("tutorial_completed", tutorial_completed)

	if "tutorial_active" in tutorial_manager:
		tutorial_manager.set("tutorial_active", false)

	if "tutorial_world_soft_paused" in tutorial_manager:
		tutorial_manager.set("tutorial_world_soft_paused", false)

	if "tutorial_clock_paused" in tutorial_manager:
		tutorial_manager.set("tutorial_clock_paused", false)

	if "tutorial_night_sequence_started" in tutorial_manager:
		tutorial_manager.set("tutorial_night_sequence_started", false)

	if tutorial_manager.has_method("_hide_objective"):
		tutorial_manager.call("_hide_objective")

func handle_player_death() -> void:
	print("[Death Debug] Main.handle_player_death() called.")
	
	_log_telemetry("player_died", {
		"location_id": _get_current_location_id()
	})

	close_workshop()
	close_defense_placement()
	close_crop_planting_menu()
	close_player_inventory()

	if map_manager != null and map_manager.has_method("close_map_menu"):
		map_manager.call("close_map_menu")

	if game_over_ui == null:
		print("[Death Debug] GameOverUI is null.")
		return

	print("[Death Debug] Showing Game Over UI.")
	game_over_ui.show_game_over()

func is_using_week10_normal_night_loop() -> bool:
	return (
		normal_night_state == NIGHT_STATE_HOUSE_EVACUATION
		or normal_night_state == NIGHT_STATE_COMBAT
		or normal_night_state == NIGHT_STATE_CLEARED
	)

func should_pause_clock_for_normal_night() -> bool:
	# The clock only determines when a normal defense starts. From 18:00
	# onward, completion is controlled entirely by the enemy quota.
	return is_using_week10_normal_night_loop()

func _on_midnight_reached() -> void:
	if is_using_week10_normal_night_loop():
		return

	if _should_use_tutorial_night_flow():
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
	if is_using_week10_normal_night_loop():
		return

	# During the Day 1 tutorial, midnight intentionally clears the ordinary
	# enemies before the tutorial boss is spawned. SpawnManager can therefore
	# report an empty cleanup immediately. The tutorial owns dawn progression
	# until the boss-defeated popup is acknowledged.
	if _should_use_tutorial_night_flow():
		return

	start_dawn_transition()

func start_dawn_transition() -> void:
	if dawn_transition_running:
		return

	dawn_transition_running = true

	if hud.has_method("fade_to_black"):
		await hud.fade_to_black(0.35)

	if time_manager.has_method("complete_night_and_start_new_day"):
		time_manager.complete_night_and_start_new_day()

	if hud.has_method("show_time_display"):
		hud.show_time_display()

	normal_night_state = NIGHT_STATE_DAY
	house_evacuation_timer = 0.0
	house_entry_locked_until_clear = false

	await get_tree().create_timer(0.10).timeout

	if hud.has_method("fade_from_black"):
		await hud.fade_from_black(0.35)

	dawn_transition_running = false

func open_map_menu() -> void:
	if _is_house_object_blocked_by_night("Map Table"):
		_show_blocked_house_object_message()
		return

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
	if normal_night_state == NIGHT_STATE_HOUSE_EVACUATION:
		if location_id == "farm":
			close_workshop()
			close_defense_placement()
			_perform_location_travel(location_id)
			_enter_normal_night_combat()
			return

		_show_roleplay_message("I have to get outside.")
		return

	if normal_night_state == NIGHT_STATE_COMBAT:
		if _is_current_location_house() and location_id == "farm":
			close_workshop()
			close_defense_placement()
			_perform_location_travel(location_id)
			return

		if location_id == "house":
			_show_roleplay_message("They are still out there.")
			return

		_show_roleplay_message("They are still out there.")
		return

	if normal_night_state == NIGHT_STATE_CLEARED:
		if location_id == "house":
			close_workshop()
			close_defense_placement()
			_perform_location_travel(location_id)
			return

		_show_roleplay_message("I am too tired for this.")
		return

	if time_manager.has_method("is_daytime") and not time_manager.is_daytime():
		print("Cannot travel at night.")

		if hud.has_method("show_warning_message"):
			hud.show_warning_message(
				"It is too dangerous to travel at night."
			)

		return

	close_workshop()
	_perform_location_travel(location_id)

func _perform_location_travel(location_id: String) -> void:
	# Map-local modal/action state must never carry into the destination scene.
	close_crop_planting_menu()
	close_player_inventory()
	cancel_player_transient_actions()

	# Ordinary player-initiated travel should use the destination's normal
	# spawn point. NightReturnSpawn is reserved for forced nightfall returns.
	if map_manager != null and map_manager.has_method(
		"travel_to_location"
	):
		map_manager.call("travel_to_location", location_id)
		return

	if map_manager != null and map_manager.has_method("load_location"):
		map_manager.call("load_location", location_id)
		return

	print("[Travel] Could not travel to location: ", location_id)

func open_defense_placement() -> void:
	if _is_house_object_blocked_by_night("War Table"):
		_show_blocked_house_object_message()
		return

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

func _on_defense_placement_closed() -> void:
	if tutorial_manager == null:
		return

	if tutorial_manager.has_method("on_war_table_closed"):
		tutorial_manager.call("on_war_table_closed")

func open_workshop() -> void:
	if _is_house_object_blocked_by_night("Workshop"):
		_show_blocked_house_object_message()
		return

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

func close_crop_planting_menu() -> void:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return

	if crop_manager.has_method("cancel_planting_menu"):
		crop_manager.call("cancel_planting_menu")

func close_player_inventory() -> void:
	var inventory_ui: Node = get_node_or_null("PlayerInventoryUI")

	if inventory_ui == null:
		inventory_ui = get_tree().get_first_node_in_group(
			"player_inventory_ui"
		)

	if inventory_ui == null:
		return

	if inventory_ui.has_method("close_inventory"):
		inventory_ui.call("close_inventory")

func cancel_player_transient_actions() -> void:
	if player == null:
		return

	if player.has_method("cancel_transient_actions_for_transition"):
		player.call("cancel_transient_actions_for_transition")


func _on_night_started() -> void:
	map_manager.close_map_menu()
	close_defense_placement()
	close_workshop()
	close_crop_planting_menu()
	close_player_inventory()
	
	_log_telemetry("night_started", {
		"location_id": _get_current_location_id()
	})
	
	print("Main received night_started signal.")

	if _should_use_normal_night_loop():
		_start_normal_night_loop()
		return

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

	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager != null and crop_manager.has_method("is_planting_menu_open"):
		if bool(crop_manager.call("is_planting_menu_open")):
			return true

	if save_slot_ui != null:
		if save_slot_ui.has_method("is_save_slot_ui_open"):
			if bool(save_slot_ui.call("is_save_slot_ui_open")):
				return true

	if pause_menu != null:
		if pause_menu.has_method("is_pause_menu_open"):
			if bool(pause_menu.call("is_pause_menu_open")):
				return true

	return (
		dawn_transition_running
		or sleep_transition_running
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

func _process_normal_night_state(delta: float) -> void:
	if normal_night_state != NIGHT_STATE_HOUSE_EVACUATION:
		return

	house_evacuation_timer -= delta

	var seconds_left: int = maxi(
		0,
		ceili(house_evacuation_timer)
	)

	if hud != null and hud.has_method("show_house_evacuation_warning"):
		hud.call("show_house_evacuation_warning", seconds_left)

	if not _is_current_location_house():
		_enter_normal_night_combat()
		return

	if house_evacuation_timer <= 0.0:
		_force_player_out_of_house_for_night()

func _should_use_tutorial_night_flow() -> bool:
	if tutorial_manager == null:
		return false

	if tutorial_manager.has_method("is_tutorial_running"):
		return bool(tutorial_manager.call("is_tutorial_running"))

	if tutorial_manager.has_method("is_tutorial_completed"):
		return not bool(tutorial_manager.call("is_tutorial_completed"))

	return false

func _should_use_normal_night_loop() -> bool:
	return not _should_use_tutorial_night_flow()

func _start_normal_night_loop() -> void:
	house_entry_locked_until_clear = true

	if _is_current_location_house():
		normal_night_state = NIGHT_STATE_HOUSE_EVACUATION
		house_evacuation_timer = HOUSE_EVACUATION_DURATION

		_show_roleplay_message(
			"The walls are breathing. I have to get outside."
		)

		if hud != null and hud.has_method("show_house_evacuation_warning"):
			hud.call(
				"show_house_evacuation_warning",
				int(HOUSE_EVACUATION_DURATION)
			)

		print("[Night] House evacuation started.")
		return

	if not _is_current_location_farm():
		_force_player_to_farm_for_night()

	_enter_normal_night_combat()

func _enter_normal_night_combat() -> void:
	if normal_night_state == NIGHT_STATE_COMBAT:
		return

	normal_night_state = NIGHT_STATE_COMBAT
	house_evacuation_timer = 0.0
	house_entry_locked_until_clear = true

	var current_day: int = 1

	if time_manager != null:
		if time_manager.has_method("get_current_day_number"):
			current_day = int(time_manager.call("get_current_day_number"))
		elif time_manager.has_method("get_day_number"):
			current_day = int(time_manager.call("get_day_number"))

	if spawn_manager != null and spawn_manager.has_method(
		"begin_normal_night_combat"
	):
		spawn_manager.call("begin_normal_night_combat", current_day)

	_force_refresh_normal_night_hud_count()

	print("[Night] Normal night combat active.")

func _force_refresh_normal_night_hud_count() -> void:
	if hud == null:
		return

	if not hud.has_method("show_night_enemy_count"):
		return

	var enemies_left: int = 0

	if spawn_manager != null:
		if spawn_manager.has_method("get_normal_night_enemies_left"):
			enemies_left = int(
				spawn_manager.call("get_normal_night_enemies_left")
			)

	hud.call("show_night_enemy_count", enemies_left)

	print("[Night HUD] Forced enemy count display: ", enemies_left)

func _on_night_enemy_count_changed(enemies_left: int) -> void:
	if normal_night_state != NIGHT_STATE_COMBAT:
		return

	if hud != null and hud.has_method("show_night_enemy_count"):
		hud.call("show_night_enemy_count", enemies_left)

func _on_normal_night_finished() -> void:
	normal_night_state = NIGHT_STATE_CLEARED
	house_entry_locked_until_clear = false

	if hud != null and hud.has_method("show_night_cleared"):
		hud.call("show_night_cleared")

	_show_roleplay_message("The house is quiet again.")
	
	_log_telemetry("night_cleared", {
		"location_id": _get_current_location_id()
	})

	print("[Night] Night cleared. Bed is now available.")

func is_normal_night_combat_active() -> bool:
	return normal_night_state == NIGHT_STATE_COMBAT

func is_normal_night_cleared() -> bool:
	return normal_night_state == NIGHT_STATE_CLEARED

func is_house_entry_locked_by_night() -> bool:
	return house_entry_locked_until_clear

func _force_player_out_of_house_for_night() -> void:
	_show_roleplay_message(
		"The house rejects me. I have to face the night."
	)

	_force_player_to_farm_for_night()
	_enter_normal_night_combat()

func _force_player_to_farm_for_night() -> void:
	cancel_player_transient_actions()

	if map_manager != null and map_manager.has_method("force_return_to_farm"):
		map_manager.call("force_return_to_farm")
		return

	if map_manager != null and map_manager.has_method("travel_to_location"):
		map_manager.call("travel_to_location", "farm")
		return

	if map_manager != null and map_manager.has_method("load_location"):
		map_manager.call("load_location", "farm")
		return

	print("[Night] Could not force player to farm. No farm loading method found.")

func _is_current_location_house() -> bool:
	var location_id: String = _get_current_location_id()
	return location_id == "house"

func _is_current_location_farm() -> bool:
	var location_id: String = _get_current_location_id()
	return location_id == "farm"

func _get_current_location_id() -> String:
	if map_manager == null:
		return ""

	if map_manager.has_method("get_current_location_id"):
		return str(map_manager.call("get_current_location_id"))

	if "current_location_id" in map_manager:
		return str(map_manager.get("current_location_id"))

	if "current_location" in map_manager:
		return str(map_manager.get("current_location"))

	return ""

func _is_house_object_blocked_by_night(
	interaction_name: String
) -> bool:
	if normal_night_state == NIGHT_STATE_HOUSE_EVACUATION:
		return interaction_name != "House Exit"

	if normal_night_state == NIGHT_STATE_COMBAT:
		if _is_current_location_house():
			return interaction_name != "House Exit"

		return false

	if normal_night_state == NIGHT_STATE_CLEARED:
		return interaction_name != "Bed"

	return false

func _show_blocked_house_object_message() -> void:
	if normal_night_state == NIGHT_STATE_HOUSE_EVACUATION:
		_show_roleplay_message(
			_get_random_message(
				house_evacuation_blocked_messages,
				"I have to get outside."
			)
		)
		return

	if normal_night_state == NIGHT_STATE_CLEARED:
		_show_roleplay_message(
			_get_random_message(
				night_cleared_blocked_messages,
				"I am too tired for this."
			)
		)
		return

	_show_roleplay_message("Not now.")

func _get_random_message(
	messages: Array[String],
	fallback_message: String
) -> String:
	if messages.is_empty():
		return fallback_message

	return str(messages.pick_random())

func _show_roleplay_message(message: String) -> void:
	if hud != null and hud.has_method("show_tutorial_completion_message"):
		hud.call("show_tutorial_completion_message", message, 3.0)
		return

	print(message)

func show_night_house_locked_message() -> void:
	_show_roleplay_message("They are still out there.")

func sleep_at_bed() -> void:
	if sleep_transition_running:
		return

	if normal_night_state == NIGHT_STATE_HOUSE_EVACUATION:
		_show_roleplay_message(
			_get_random_message(
				house_evacuation_blocked_messages,
				"I have to get outside."
			)
		)
		return

	if normal_night_state == NIGHT_STATE_COMBAT:
		_show_roleplay_message("They are still out there.")
		return

	if normal_night_state != NIGHT_STATE_CLEARED:
		_show_roleplay_message("I do not need to sleep yet.")
		return

	if save_slot_ui == null:
		print("[Save Slot] SaveSlotUI missing. Sleeping with autosave only.")
		await _run_sleep_transition_with_save(-1)
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_BED_SLEEP

	if save_slot_ui.has_method("open_sleep_save_menu"):
		save_slot_ui.call("open_sleep_save_menu")
	elif save_slot_ui.has_method("open_save_menu"):
		save_slot_ui.call("open_save_menu")
	else:
		print("[Save Slot] SaveSlotUI.open_save_menu() missing.")
		await _run_sleep_transition_with_save(-1)

func _on_save_slot_selected(manual_slot_index: int) -> void:
	if sleep_transition_running:
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_NONE
	pending_manual_save_slot = manual_slot_index

	await _run_sleep_transition_with_save(manual_slot_index)

func _on_save_slot_cancelled() -> void:
	pending_manual_save_slot = -1

	if save_slot_menu_context != SAVE_SLOT_CONTEXT_BED_SLEEP:
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_NONE
	_show_roleplay_message("I should decide before sleeping.")

func _run_sleep_transition_with_save(manual_slot_index: int) -> void:
	if sleep_transition_running:
		return

	sleep_transition_running = true
	
	_log_telemetry("sleep_started", {
		"manual_slot_index": manual_slot_index
	})

	close_workshop()
	close_defense_placement()
	close_crop_planting_menu()
	close_player_inventory()

	if map_manager != null and map_manager.has_method("close_map_menu"):
		map_manager.close_map_menu()

	_show_roleplay_message("I can finally rest.")

	await get_tree().create_timer(0.45).timeout

	if hud != null and hud.has_method("fade_to_black"):
		await hud.call("fade_to_black", 0.45)

	if spawn_manager != null:
		if spawn_manager.has_method("stop_normal_night_combat"):
			spawn_manager.call("stop_normal_night_combat")

		if spawn_manager.has_method("clear_active_enemies"):
			spawn_manager.call("clear_active_enemies")

	if time_manager != null:
		if time_manager.has_method("complete_night_and_start_new_day"):
			time_manager.call("complete_night_and_start_new_day")

	normal_night_state = NIGHT_STATE_DAY
	house_evacuation_timer = 0.0
	house_entry_locked_until_clear = false

	_wake_player_at_bed()

	if hud != null and hud.has_method("show_time_display"):
		hud.call("show_time_display")

	_perform_sleep_saves(manual_slot_index)

	await get_tree().create_timer(0.20).timeout

	if hud != null and hud.has_method("fade_from_black"):
		await hud.call("fade_from_black", 0.45)

	sleep_transition_running = false
	pending_manual_save_slot = -1
	
	_log_telemetry("sleep_completed", {
		"manual_slot_index": manual_slot_index,
		"active_manual_save_slot": active_manual_save_slot
	})
	
	print("[Sleep] Player slept. New day started.")

func _perform_sleep_saves(manual_slot_index: int) -> void:
	if save_manager == null:
		print("[Save] SaveManager is missing. Could not save.")
		return

	if not save_manager.has_method("save_to_slot"):
		return

	# Every completed sleep updates the dedicated autosave slot. A manual slot
	# is written only when the player explicitly selected one in the sleep
	# menu. Do not fall back to active_manual_save_slot here: the UI promises
	# that "SLEEP WITH AUTOSAVE ONLY" preserves existing manual checkpoints.
	save_manager.call("save_to_slot", 0)

	if manual_slot_index >= 1:
		save_manager.call("save_to_slot", manual_slot_index)
		active_manual_save_slot = manual_slot_index
		# An explicit bedtime slot choice supersedes the one-time reservation
		# made when this New Game was created.
		reserved_new_game_manual_slot = -1
		return

	# A New Game may reserve an empty manual slot for a one-time first-sleep
	# save. Keep that reservation separate from active_manual_save_slot. A
	# loaded manual save can later be deliberately deleted by the player, and
	# "Autosave Only" must not silently recreate that deleted checkpoint.
	if reserved_new_game_manual_slot < 1:
		return

	if not save_manager.has_method("has_slot_save"):
		return

	var reserved_slot_is_occupied: bool = bool(
		save_manager.call(
			"has_slot_save",
			reserved_new_game_manual_slot
		)
	)

	if reserved_slot_is_occupied:
		reserved_new_game_manual_slot = -1
		return

	var created_reserved_save: bool = bool(
		save_manager.call(
			"save_to_slot",
			reserved_new_game_manual_slot
		)
	)

	if created_reserved_save:
		reserved_new_game_manual_slot = -1

func _wake_player_at_bed() -> void:
	if player == null:
		return

	var wake_marker: Node2D = _find_bed_wake_marker()

	if wake_marker == null:
		print("[Sleep] BedWakeMarker not found. Player position unchanged.")
		return

	player.global_position = wake_marker.global_position

func _find_bed_wake_marker() -> Node2D:
	var map_container_node: Node = get_node_or_null("MapContainer")

	if map_container_node == null:
		return null

	for child in map_container_node.get_children():
		var marker: Node = child.find_child(
			"BedWakeMarker",
			true,
			false
		)

		if marker is Node2D:
			return marker as Node2D

	return null

func _on_pause_resume_requested() -> void:
	pass

func _on_pause_settings_requested() -> void:
	_show_roleplay_message("Settings are planned for a later iteration.")

func _on_pause_load_save_requested() -> void:
	if save_slot_ui == null:
		return

	save_slot_menu_context = SAVE_SLOT_CONTEXT_PAUSE_LOAD

	if pause_menu != null:
		if pause_menu.has_method("close_pause_menu"):
			pause_menu.call("close_pause_menu", false)

	if save_slot_ui.has_method("open_load_game_menu"):
		save_slot_ui.call("open_load_game_menu")

func _on_pause_back_to_title_requested() -> void:
	_log_telemetry("back_to_title_requested", {})
	
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_slot_menu_cancelled(menu_mode: String) -> void:
	var previous_context: String = save_slot_menu_context
	save_slot_menu_context = SAVE_SLOT_CONTEXT_NONE

	if menu_mode == SaveSlotUI.MODE_SLEEP_SAVE:
		return

	match previous_context:
		SAVE_SLOT_CONTEXT_TITLE_NEW_GAME:
			if title_screen_ui != null:
				title_screen_ui.show_title_screen()

			get_tree().paused = true

		SAVE_SLOT_CONTEXT_TITLE_LOAD:
			if title_screen_ui != null:
				title_screen_ui.show_title_screen()

			get_tree().paused = true

		SAVE_SLOT_CONTEXT_PAUSE_LOAD:
			if pause_menu != null:
				if pause_menu.has_method("open_pause_menu"):
					pause_menu.call("open_pause_menu")

			get_tree().paused = true

		_:
			get_tree().paused = true
			
func _log_telemetry(
	event_name: String,
	event_data: Dictionary = {}
) -> void:
	var telemetry_node: Node = telemetry_manager

	if telemetry_node == null:
		telemetry_node = get_tree().get_first_node_in_group(
			"telemetry_manager"
		)

	if telemetry_node == null:
		return

	if telemetry_node.has_method("log_event"):
		telemetry_node.call("log_event", event_name, event_data)
