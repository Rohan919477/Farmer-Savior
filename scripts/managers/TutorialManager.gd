extends Node
class_name TutorialManager

signal tutorial_step_changed(tutorial_step: String)

const STEP_NONE: String = "none"
const STEP_INTRO: String = "intro"
const STEP_MOVE: String = "move"
const STEP_COMBAT_POPUP: String = "combat_popup"
const STEP_DEFEAT_TRAINING_ENEMY: String = "defeat_training_enemy"
const STEP_COLLECT_DROPS_POPUP: String = "collect_drops_popup"
const STEP_COLLECT_DROPS: String = "collect_drops"
const STEP_PLANT_CROP_POPUP: String = "plant_crop_popup"
const STEP_PLANT_BASIC_CROP: String = "plant_basic_crop"
const STEP_PREP_POPUP: String = "prep_popup"
const STEP_USE_PREP_SYSTEM: String = "use_prep_system"
const STEP_NIGHT_POPUP: String = "night_popup"
const STEP_SURVIVE_TO_MIDNIGHT: String = "survive_to_midnight"
const STEP_BOSS_POPUP: String = "boss_popup"
const STEP_BOSS_FIGHT: String = "boss_fight"
const STEP_BOSS_DEFEATED_POPUP: String = "boss_defeated_popup"
const STEP_MUTANT_SEED_RECEIVED: String = "mutant_seed_received"
const STEP_PLANT_MUTANT_SEED: String = "plant_mutant_seed"
const STEP_TUTORIAL_COMPLETE_POPUP: String = "tutorial_complete_popup"
const STEP_COMPLETE: String = "complete"
const STEP_WAR_TABLE_POPUP: String = "war_table_popup"
const STEP_USE_WAR_TABLE: String = "use_war_table"
const STEP_WORKSHOP_POPUP: String = "workshop_popup"
const STEP_USE_WORKSHOP: String = "use_workshop"
const STEP_WORKSHOP_UPGRADE_POPUP: String = "workshop_upgrade_popup"
const STEP_BUY_FIELD_CONDITIONING: String = "buy_field_conditioning"

@export var required_move_distance: float = 96.0

var tutorial_active: bool = false
var tutorial_completed: bool = false
var current_step: String = STEP_NONE

var start_move_position: Vector2 = Vector2.ZERO
var training_enemy: Node2D = null
var tutorial_boss: Node2D = null
var war_table_opened_for_tutorial: bool = false

var baseline_seed_count: int = 0
var baseline_scrap_count: int = 0

var tutorial_world_soft_paused: bool = false
var tutorial_clock_paused: bool = false
var tutorial_night_sequence_started: bool = false

@onready var main_node: Node = get_parent()
@onready var tutorial_popup_ui: TutorialPopupUI = (
	get_parent().get_node_or_null("TutorialPopupUI")
	as TutorialPopupUI
)

@onready var hud: CanvasLayer = (
	get_parent().get_node_or_null("HUD") as CanvasLayer
)

@onready var player: Node2D = (
	get_parent().get_node_or_null("Player") as Node2D
)

@onready var spawn_manager: Node = (
	get_parent().get_node_or_null("SpawnManager")
)

@onready var crop_manager: CropManager = (
	get_parent().get_node_or_null("CropManager") as CropManager
)

@onready var time_manager: Node = (
	get_parent().get_node_or_null("TimeManager")
)

@onready var upgrade_manager: UpgradeManager = (
	get_parent().get_node_or_null("UpgradeManager") as UpgradeManager
)

func _ready() -> void:
	if upgrade_manager != null:
		if not upgrade_manager.upgrade_purchased.is_connected(
			_on_upgrade_purchased
		):
			upgrade_manager.upgrade_purchased.connect(
				_on_upgrade_purchased
			)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tutorial_manager")

	if tutorial_popup_ui != null:
		tutorial_popup_ui.acknowledged.connect(
			_on_tutorial_popup_acknowledged
		)

	if crop_manager != null:
		crop_manager.planting_result.connect(
			_on_crop_planting_result
		)

		if crop_manager.has_signal("mutant_crop_reward_unlocked"):
			crop_manager.mutant_crop_reward_unlocked.connect(
				_on_mutant_crop_reward_unlocked
			)

func _process(_delta: float) -> void:
	if not tutorial_active:
		return

	if tutorial_popup_ui != null and tutorial_popup_ui.is_popup_open():
		return

	match current_step:
		STEP_MOVE:
			_check_movement_objective()

		STEP_DEFEAT_TRAINING_ENEMY:
			_check_training_enemy_defeated()

		STEP_COLLECT_DROPS:
			_check_resource_collection()

func start_tutorial() -> void:
	if tutorial_completed:
		return

	tutorial_active = true
	tutorial_clock_paused = true
	tutorial_night_sequence_started = false
	war_table_opened_for_tutorial = false

	if time_manager != null and time_manager.has_method("set_time_of_day"):
		time_manager.call("set_time_of_day", 17, 0)

	_set_step(STEP_INTRO)

	_show_popup(
		STEP_INTRO,
		"The blight is near.\n\n"
		+ "Keep the farm standing, or be swallowed with it.\n\n"
		+ "Press "
		+ _get_movement_hint()
		+ " to move."
	)

func is_tutorial_active() -> bool:
	return tutorial_active

func is_tutorial_completed() -> bool:
	return tutorial_completed


func reset_for_new_game() -> void:
	_clear_runtime_state()
	tutorial_completed = false
	_set_step(STEP_NONE)


func prepare_for_load() -> void:
	# Tutorial interaction state is runtime-only. Clear it before other
	# systems apply loaded data so stale pause flags cannot affect TimeManager.
	_clear_runtime_state()
	_set_step(STEP_NONE)


func get_save_data() -> Dictionary:
	# Saves only occur during the sleep flow, after the tutorial is expected
	# to be complete. Dynamic tutorial encounters/popups are intentionally
	# not serialized.
	return {
		"tutorial_completed": tutorial_completed
	}


func load_save_data(data: Dictionary) -> void:
	_clear_runtime_state()

	# Older saves may not contain tutorial data. Treat those as already past
	# the tutorial instead of accidentally trapping the player in tutorial flow.
	tutorial_completed = bool(
		data.get("tutorial_completed", true)
	)

	if tutorial_completed:
		_set_step(STEP_COMPLETE)
	else:
		_set_step(STEP_NONE)


func _clear_runtime_state() -> void:
	tutorial_active = false
	training_enemy = null
	tutorial_boss = null
	war_table_opened_for_tutorial = false

	start_move_position = Vector2.ZERO
	baseline_seed_count = 0
	baseline_scrap_count = 0

	tutorial_world_soft_paused = false
	tutorial_clock_paused = false
	tutorial_night_sequence_started = false

	_disable_workshop_tutorial_focus()
	_hide_objective()

	if tutorial_popup_ui != null and tutorial_popup_ui.is_popup_open():
		tutorial_popup_ui.hide_popup(false)

func is_tutorial_popup_open() -> bool:
	if tutorial_popup_ui == null:
		return false

	return tutorial_popup_ui.is_popup_open()

func on_preparation_system_opened(system_name: String) -> void:
	match current_step:
		STEP_USE_WAR_TABLE:
			if system_name != "War Table":
				return

			war_table_opened_for_tutorial = true
			_show_objective(
				"Look over the War Table, then close it yourself."
			)

		STEP_USE_WORKSHOP:
			if system_name != "Workshop":
				return

			_hide_objective()

			tutorial_world_soft_paused = true

			var workshop_ui: Node = _get_workshop_ui()

			if workshop_ui != null and workshop_ui.has_method(
				"set_tutorial_player_upgrade_focus"
			):
				workshop_ui.call(
					"set_tutorial_player_upgrade_focus",
					true
				)

			_show_popup(
				STEP_WORKSHOP_UPGRADE_POPUP,
				"Scrap can harden the body or the farm.\n\n"
				+ "Buy Field Conditioning I."
			)
	
func on_war_table_closed() -> void:
	if current_step != STEP_USE_WAR_TABLE:
		return

	if not war_table_opened_for_tutorial:
		return

	war_table_opened_for_tutorial = false
	_hide_objective()

	_show_popup(
		STEP_WORKSHOP_POPUP,
		"The War Table marks where the farm will bleed.\n\n"
		+ "Now open the Workshop. Spend your Scrap before night."
	)

func is_world_soft_paused() -> bool:
	return tutorial_world_soft_paused

func should_pause_time() -> bool:
	return tutorial_clock_paused

func handle_midnight_reached() -> bool:
	if current_step != STEP_SURVIVE_TO_MIDNIGHT:
		return false

	if spawn_manager != null and spawn_manager.has_method(
		"clear_active_enemies"
	):
		spawn_manager.call("clear_active_enemies")

	_show_popup(
		STEP_BOSS_POPUP,
		"The ground is splitting.\n\n"
		+ "A brute is coming. It needs a wide breach to enter.\n\n"
		+ "Kill it."
	)

	return true



func on_tutorial_boss_defeated() -> void:
	if current_step != STEP_BOSS_FIGHT:
		return

	tutorial_boss = null
	war_table_opened_for_tutorial = false

	_show_popup(
		STEP_BOSS_DEFEATED_POPUP,
		"The brute is dead.\n\n"
		+ "A Mutant Seed pulses in your pack.\n\n"
		+ "Plant it at dawn."
	)

func _set_step(new_step: String) -> void:
	current_step = new_step
	tutorial_step_changed.emit(current_step)

	print("[Tutorial] Current step: ", current_step)

func _show_popup(step_id: String, message: String) -> void:
	_set_step(step_id)

	if tutorial_popup_ui == null:
		return

	tutorial_popup_ui.show_popup(step_id, message)

func _show_objective(objective_text: String) -> void:
	if hud == null:
		return

	if hud.has_method("show_tutorial_objective"):
		hud.call("show_tutorial_objective", objective_text)

func _hide_objective() -> void:
	if hud == null:
		return

	if hud.has_method("hide_tutorial_objective"):
		hud.call("hide_tutorial_objective")

func _on_tutorial_popup_acknowledged(
	acknowledged_step: String
) -> void:
	match acknowledged_step:
		STEP_INTRO:
			_begin_move_objective()

		STEP_COMBAT_POPUP:
			_begin_training_enemy_objective()

		STEP_COLLECT_DROPS_POPUP:
			_begin_collect_drops_objective()

		STEP_PLANT_CROP_POPUP:
			_begin_plant_crop_objective()

		STEP_PREP_POPUP:
			_begin_prep_objective()

		STEP_NIGHT_POPUP:
			_begin_night_survival_objective()

		STEP_BOSS_POPUP:
			_begin_boss_fight()

		STEP_BOSS_DEFEATED_POPUP:
			_begin_mutant_seed_received_step()
		
		STEP_TUTORIAL_COMPLETE_POPUP:
			_complete_tutorial()
		
		STEP_WAR_TABLE_POPUP:
			_begin_war_table_objective()

		STEP_WORKSHOP_POPUP:
			_close_defense_ui_if_open()
			_begin_workshop_objective()

		STEP_WORKSHOP_UPGRADE_POPUP:
			_begin_buy_field_conditioning_objective()

func _begin_move_objective() -> void:
	if player != null:
		start_move_position = player.global_position

	_set_step(STEP_MOVE)

	_show_objective(
		"Move with " + _get_movement_hint() + "."
	)

func _check_movement_objective() -> void:
	if player == null:
		return

	var moved_distance: float = start_move_position.distance_to(
		player.global_position
	)

	if moved_distance < required_move_distance:
		return

	_hide_objective()

	_show_popup(
		STEP_COMBAT_POPUP,
		"Something crawls through the soil.\n\n"
		+ "Aim with the mouse.\n"
		+ "Press "
		+ _get_action_hint("shoot")
		+ " to shoot, or "
		+ _get_action_hint("melee_attack")
		+ " to strike."
	)

func _on_upgrade_purchased(upgrade_id: String) -> void:
	if current_step != STEP_BUY_FIELD_CONDITIONING:
		return

	if upgrade_id != UpgradeManager.UPGRADE_FIELD_CONDITIONING:
		return

	tutorial_world_soft_paused = false

	var workshop_ui: Node = _get_workshop_ui()

	if workshop_ui != null and workshop_ui.has_method(
		"set_tutorial_player_upgrade_focus"
	):
		workshop_ui.call("set_tutorial_player_upgrade_focus", false)

	if main_node != null and main_node.has_method("close_workshop"):
		main_node.call("close_workshop")

	_hide_objective()

	_show_popup(
		STEP_NIGHT_POPUP,
		"The body holds.\n\n" 
		+ "The sun is dying. Hold out until midnight."
	)

func _begin_training_enemy_objective() -> void:
	if spawn_manager != null and spawn_manager.has_method(
		"spawn_training_crop_mite"
	):
		training_enemy = spawn_manager.call(
			"spawn_training_crop_mite"
		) as Node2D

	_set_step(STEP_DEFEAT_TRAINING_ENEMY)
	_show_objective("Defeat the training Crop Mite.")

func _check_training_enemy_defeated() -> void:
	if training_enemy != null and is_instance_valid(training_enemy):
		return

	training_enemy = null
	_hide_objective()

	_show_popup(
		STEP_COLLECT_DROPS_POPUP,
		"The corpse left supplies.\n\n"
		+ "Gather what remains."
	)

func _begin_collect_drops_objective() -> void:
	baseline_seed_count = _get_player_resource_amount("seeds")
	baseline_scrap_count = _get_player_resource_amount("scrap")

	_set_step(STEP_COLLECT_DROPS)
	_show_objective("Collect at least one dropped resource.")

func _check_resource_collection() -> void:
	var current_seed_count: int = _get_player_resource_amount("seeds")
	var current_scrap_count: int = _get_player_resource_amount("scrap")

	if (
		current_seed_count <= baseline_seed_count
		and current_scrap_count <= baseline_scrap_count
	):
		return

	_hide_objective()

	_show_popup(
		STEP_PLANT_CROP_POPUP,
		"Seeds keep the farm alive.\n\n"
		+ "Plant one Basic Seed in the field."
	)

func _begin_plant_crop_objective() -> void:
	_set_step(STEP_PLANT_BASIC_CROP)
	_show_objective("Plant one Basic Crop in the farm plot.")

func _begin_war_table_objective() -> void:
	_set_step(STEP_USE_WAR_TABLE)
	_show_objective("Open the War Table.")

func _begin_workshop_objective() -> void:
	_set_step(STEP_USE_WORKSHOP)
	_show_objective("Open the Workshop.")

func _begin_buy_field_conditioning_objective() -> void:
	_set_step(STEP_BUY_FIELD_CONDITIONING)

	tutorial_world_soft_paused = true

	var workshop_ui: Node = _get_workshop_ui()

	if workshop_ui != null and workshop_ui.has_method(
		"set_tutorial_player_upgrade_focus"
	):
		workshop_ui.call("set_tutorial_player_upgrade_focus", true)

	_show_objective("Buy Field Conditioning I.")

func _close_defense_ui_if_open() -> void:
	if main_node == null:
		return

	if main_node.has_method("close_defense_placement"):
		main_node.call("close_defense_placement")

func _get_workshop_ui() -> Node:
	if main_node == null:
		return null

	if main_node.has_method("get_workshop_ui"):
		return main_node.call("get_workshop_ui") as Node

	return null

func _on_crop_planting_result(
	success: bool,
	_message: String
) -> void:
	if current_step != STEP_PLANT_BASIC_CROP:
		return

	if not success:
		return

	_hide_objective()

	_show_popup(
		STEP_WAR_TABLE_POPUP,
		"The field is planted.\n\n"
		+ "Now check the War Table. The fence line is your first skin."
	)

func _begin_prep_objective() -> void:
	_set_step(STEP_USE_PREP_SYSTEM)
	_show_objective("Open the War Table or Workshop once.")

func _begin_night_survival_objective() -> void:
	tutorial_night_sequence_started = true
	tutorial_clock_paused = false

	_set_step(STEP_SURVIVE_TO_MIDNIGHT)
	_show_objective("Survive until midnight.")

	if time_manager != null and time_manager.has_method(
		"set_time_of_day"
	):
		time_manager.call("set_time_of_day", 17, 0)

func _begin_boss_fight() -> void:
	_set_step(STEP_BOSS_FIGHT)
	_show_objective("Defeat the Blight Root Brute.")

	if spawn_manager != null and spawn_manager.has_method(
		"spawn_tutorial_boss"
	):
		tutorial_boss = spawn_manager.call(
			"spawn_tutorial_boss"
		) as Node2D

func _begin_mutant_seed_received_step() -> void:
	_set_step(STEP_PLANT_MUTANT_SEED)

	_show_objective(
		"At dawn, plant the Mutant Seed in any empty crop plot."
	)

func _on_mutant_crop_reward_unlocked(reward_name: String) -> void:
	if current_step != STEP_PLANT_MUTANT_SEED:
		return

	_hide_objective()

	_show_popup(
		STEP_TUTORIAL_COMPLETE_POPUP,
		"Mutant Compost awakened.\n\n"
		+ "Basic Crops now yield +1 Seed.\n\n"
		+ "The farm survived its first lesson."
	)

func _complete_tutorial() -> void:
	tutorial_completed = true
	tutorial_active = false
	tutorial_world_soft_paused = false
	tutorial_clock_paused = false

	training_enemy = null
	tutorial_boss = null
	war_table_opened_for_tutorial = false

	_disable_workshop_tutorial_focus()
	_hide_objective()

	_set_step(STEP_COMPLETE)

	if hud != null and hud.has_method("show_tutorial_completion_message"):
		hud.call(
			"show_tutorial_completion_message",
			"The first night is over. The farm is yours to defend.",
			4.0
		)

	print("[Tutorial] Tutorial completed. Normal gameplay unlocked.")

func _get_action_hint(action_name: String) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)

	if events.is_empty():
		return action_name

	return _format_input_event(events[0])

func _format_input_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		var keycode: Key = key_event.physical_keycode

		if keycode == KEY_NONE:
			keycode = key_event.keycode

		if keycode != KEY_NONE:
			return OS.get_keycode_string(keycode)

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		match mouse_event.button_index:
			MOUSE_BUTTON_LEFT:
				return "Left Click"
			MOUSE_BUTTON_RIGHT:
				return "Right Click"
			MOUSE_BUTTON_MIDDLE:
				return "Middle Click"
			MOUSE_BUTTON_WHEEL_UP:
				return "Mouse Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN:
				return "Mouse Wheel Down"

	var event_text: String = event.as_text()
	event_text = event_text.replace(" (Physical)", "")
	event_text = event_text.replace(" - Physical", "")
	event_text = event_text.replace("Physical - ", "")
	event_text = event_text.replace("Pressed ", "")

	return event_text

func _get_movement_hint() -> String:
	return "%s / %s / %s / %s" % [
		_get_action_hint("move_up"),
		_get_action_hint("move_left"),
		_get_action_hint("move_down"),
		_get_action_hint("move_right")
	]

func _get_player_resource_amount(resource_type: String) -> int:
	var player_node: Node = get_tree().get_first_node_in_group(
		"player"
	)

	if player_node == null:
		return 0

	if not player_node.has_method("get_resource_amount"):
		return 0

	return int(
		player_node.call(
			"get_resource_amount",
			resource_type
		)
	)

func _disable_workshop_tutorial_focus() -> void:
	var workshop_ui: Node = _get_workshop_ui()

	if workshop_ui == null:
		return

	if workshop_ui.has_method("set_tutorial_player_upgrade_focus"):
		workshop_ui.call("set_tutorial_player_upgrade_focus", false)

func is_tutorial_running() -> bool:
	return tutorial_active and not tutorial_completed
