extends Node
class_name UpgradeManager

signal workshop_tab_changed(main_tab: String, subtab: String)
signal upgrade_purchased(upgrade_id: String)
signal upgrade_purchase_failed(upgrade_id: String, reason: String)
signal upgrade_state_changed

const TAB_PLAYER: String = "player"
const TAB_FENCE: String = "fence"
const TAB_TURRETS: String = "turrets"
const TAB_WEAPONS: String = "weapons"
const TAB_BACKPACK: String = "backpack"
const TAB_GADGETS: String = "gadgets"

const STATUS_AVAILABLE: String = "available"
const STATUS_PURCHASED: String = "purchased"
const STATUS_LOCKED_PREREQUISITE: String = "locked_prerequisite"
const STATUS_LOCKED_BRANCH: String = "locked_branch"
const STATUS_INSUFFICIENT_SCRAP: String = "insufficient_scrap"
const STATUS_UNAVAILABLE: String = "unavailable"

const UPGRADE_FIELD_CONDITIONING: String = "field_conditioning_1"
const UPGRADE_FIELD_RUNNER: String = "field_runner_1"
const UPGRADE_HOMESTEAD_GUARDIAN: String = "homestead_guardian_1"

const UPGRADE_REINFORCED_TIMBER: String = "reinforced_timber_1"
const UPGRADE_STRONGHOLD_FRAMES: String = "stronghold_frames_1"
const UPGRADE_RAPID_PATCHWORK: String = "rapid_patchwork_1"

const UPGRADE_DEFINITIONS: Dictionary = {
	UPGRADE_FIELD_CONDITIONING: {
		"tree": TAB_PLAYER,
		"title": "Field Conditioning I",
		"description": "Your body hardens against the first nights. +10 Maximum Health.",
		"cost_scrap": 1,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_FIELD_RUNNER: {
		"tree": TAB_PLAYER,
		"title": "Field Runner",
		"description": "+35 movement speed. Locks the defensive branch.",
		"cost_scrap": 4,
		"requires": [UPGRADE_FIELD_CONDITIONING],
		"branch_group": "player_specialization"
	},
	UPGRADE_HOMESTEAD_GUARDIAN: {
		"tree": TAB_PLAYER,
		"title": "Homestead Guardian",
		"description": "Take 15% less damage. Locks the mobility branch.",
		"cost_scrap": 4,
		"requires": [UPGRADE_FIELD_CONDITIONING],
		"branch_group": "player_specialization"
	},
	UPGRADE_REINFORCED_TIMBER: {
		"tree": TAB_FENCE,
		"title": "Reinforced Timber I",
		"description": "+20 maximum HP for all non-broken fences.",
		"cost_scrap": 4,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_STRONGHOLD_FRAMES: {
		"tree": TAB_FENCE,
		"title": "Stronghold Frames",
		"description": (
			"+30 Fence Maximum HP and fences take 15% less damage. "
			+ "Locks the repair branch."
		),
		"cost_scrap": 5,
		"requires": [UPGRADE_REINFORCED_TIMBER],
		"branch_group": "fence_specialization"
	},
	UPGRADE_RAPID_PATCHWORK: {
		"tree": TAB_FENCE,
		"title": "Rapid Patchwork",
		"description": (
			"+75% field fence repair speed. "
			+ "Locks the stronghold branch."
		),
		"cost_scrap": 5,
		"requires": [UPGRADE_REINFORCED_TIMBER],
		"branch_group": "fence_specialization"
	}
}

var workshop_opened_once: bool = false
var last_workshop_tab: String = TAB_PLAYER

var last_subtab_by_main_tab: Dictionary = {
	TAB_TURRETS: "pesticide_turret",
	TAB_WEAPONS: "pistol"
}

var purchased_upgrades: Dictionary = {}

func _ready() -> void:
	add_to_group("upgrade_manager")

func get_workshop_tab_to_open() -> String:
	if not workshop_opened_once:
		return TAB_PLAYER

	return last_workshop_tab

func get_last_workshop_subtab(main_tab: String) -> String:
	return str(last_subtab_by_main_tab.get(main_tab, ""))

func mark_workshop_opened() -> void:
	workshop_opened_once = true

func set_workshop_selection(
	main_tab: String,
	subtab: String = ""
) -> void:
	if not _is_known_main_tab(main_tab):
		return

	last_workshop_tab = main_tab

	if not subtab.is_empty():
		last_subtab_by_main_tab[main_tab] = subtab

	workshop_tab_changed.emit(
		main_tab,
		get_last_workshop_subtab(main_tab)
	)

func get_upgrade_definition(upgrade_id: String) -> Dictionary:
	if not UPGRADE_DEFINITIONS.has(upgrade_id):
		return {}

	var definition: Dictionary = UPGRADE_DEFINITIONS[upgrade_id]
	return definition.duplicate(true)

func get_upgrade_ids_for_tree(tree_id: String) -> Array[String]:
	var upgrade_ids: Array[String] = []

	for upgrade_id_variant in UPGRADE_DEFINITIONS.keys():
		var upgrade_id: String = str(upgrade_id_variant)
		var definition: Dictionary = get_upgrade_definition(upgrade_id)

		if str(definition.get("tree", "")) == tree_id:
			upgrade_ids.append(upgrade_id)

	return upgrade_ids

func is_upgrade_purchased(upgrade_id: String) -> bool:
	return bool(purchased_upgrades.get(upgrade_id, false))

func get_upgrade_status(upgrade_id: String) -> String:
	var definition: Dictionary = get_upgrade_definition(upgrade_id)

	if definition.is_empty():
		return STATUS_UNAVAILABLE

	if is_upgrade_purchased(upgrade_id):
		return STATUS_PURCHASED

	if not _has_required_upgrades(definition):
		return STATUS_LOCKED_PREREQUISITE

	if _is_locked_by_branch_choice(upgrade_id, definition):
		return STATUS_LOCKED_BRANCH

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null:
		return STATUS_UNAVAILABLE

	if not player_node.has_method("get_resource_amount"):
		return STATUS_UNAVAILABLE

	var scrap_available: int = int(
		player_node.call("get_resource_amount", "scrap")
	)

	var scrap_cost: int = int(definition.get("cost_scrap", 0))

	if scrap_available < scrap_cost:
		return STATUS_INSUFFICIENT_SCRAP

	return STATUS_AVAILABLE

func get_upgrade_status_message(upgrade_id: String) -> String:
	match get_upgrade_status(upgrade_id):
		STATUS_AVAILABLE:
			return "Available"
		STATUS_PURCHASED:
			return "Purchased"
		STATUS_LOCKED_PREREQUISITE:
			return "Requires the previous upgrade."
		STATUS_LOCKED_BRANCH:
			return "Locked by your other branch choice."
		STATUS_INSUFFICIENT_SCRAP:
			return "Not enough Scrap."
		_:
			return "Unavailable."

func purchase_upgrade(upgrade_id: String) -> bool:
	var status: String = get_upgrade_status(upgrade_id)

	if status != STATUS_AVAILABLE:
		var failure_reason: String = get_upgrade_status_message(upgrade_id)

		upgrade_purchase_failed.emit(
			upgrade_id,
			failure_reason
		)

		_log_telemetry("upgrade_purchase_failed", {
			"upgrade_id": upgrade_id,
			"status": status,
			"reason": failure_reason
		})

		return false

	var definition: Dictionary = get_upgrade_definition(upgrade_id)
	var scrap_cost: int = int(definition.get("cost_scrap", 0))

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if player_node == null or not player_node.has_method("spend_resource"):
		var failure_reason: String = "Player resource data is unavailable."

		upgrade_purchase_failed.emit(
			upgrade_id,
			failure_reason
		)

		_log_telemetry("upgrade_purchase_failed", {
			"upgrade_id": upgrade_id,
			"status": "player_resource_unavailable",
			"reason": failure_reason
		})

		return false

	var spent_successfully: bool = bool(
		player_node.call("spend_resource", "scrap", scrap_cost)
	)

	if not spent_successfully:
		var failure_reason: String = "Not enough Scrap."

		upgrade_purchase_failed.emit(
			upgrade_id,
			failure_reason
		)

		_log_telemetry("upgrade_purchase_failed", {
			"upgrade_id": upgrade_id,
			"status": "resource_spend_failed",
			"reason": failure_reason,
			"cost_scrap": scrap_cost
		})

		return false

	if not _apply_upgrade_effect(upgrade_id):
		if player_node.has_method("add_resource"):
			player_node.call("add_resource", "scrap", scrap_cost)

		var failure_reason: String = "Upgrade effect could not be applied."

		upgrade_purchase_failed.emit(
			upgrade_id,
			failure_reason
		)

		_log_telemetry("upgrade_purchase_failed", {
			"upgrade_id": upgrade_id,
			"status": "effect_failed",
			"reason": failure_reason,
			"cost_scrap": scrap_cost
		})

		return false

	purchased_upgrades[upgrade_id] = true

	_log_telemetry("upgrade_purchased", {
		"upgrade_id": upgrade_id,
		"title": str(definition.get("title", upgrade_id)),
		"tree": str(definition.get("tree", "")),
		"cost_scrap": scrap_cost
	})

	print(
		"[Upgrade] Purchased ",
		str(definition.get("title", upgrade_id)),
		" for ",
		scrap_cost,
		" Scrap."
	)

	upgrade_purchased.emit(upgrade_id)
	upgrade_state_changed.emit()

	return true

func _apply_upgrade_effect(upgrade_id: String) -> bool:
	var player_node: Node = get_tree().get_first_node_in_group("player")

	var defense_manager: DefenseManager = (
		get_tree().get_first_node_in_group("defense_manager")
		as DefenseManager
	)

	match upgrade_id:
		UPGRADE_FIELD_CONDITIONING:
			if player_node == null:
				return false

			if not player_node.has_method("apply_max_health_upgrade"):
				return false

			player_node.call("apply_max_health_upgrade", 10)
			return true

		UPGRADE_FIELD_RUNNER:
			if player_node == null:
				return false

			if not player_node.has_method("apply_move_speed_upgrade"):
				return false

			player_node.call("apply_move_speed_upgrade", 35.0)
			return true

		UPGRADE_HOMESTEAD_GUARDIAN:
			if player_node == null:
				return false

			if not player_node.has_method("apply_damage_taken_multiplier"):
				return false

			player_node.call("apply_damage_taken_multiplier", 0.85)
			return true

		UPGRADE_REINFORCED_TIMBER:
			if defense_manager == null:
				return false

			defense_manager.apply_fence_max_health_upgrade(20.0)
			return true

		UPGRADE_STRONGHOLD_FRAMES:
			if defense_manager == null:
				return false

			defense_manager.apply_fence_max_health_upgrade(30.0)
			defense_manager.apply_fence_damage_multiplier(0.85)
			return true

		UPGRADE_RAPID_PATCHWORK:
			if defense_manager == null:
				return false

			defense_manager.apply_fence_repair_rate_multiplier(1.75)
			return true

	return false

func _has_required_upgrades(definition: Dictionary) -> bool:
	var required_upgrades: Array = definition.get("requires", [])

	for required_upgrade_variant in required_upgrades:
		var required_upgrade_id: String = str(required_upgrade_variant)

		if not is_upgrade_purchased(required_upgrade_id):
			return false

	return true

func _is_locked_by_branch_choice(
	upgrade_id: String,
	definition: Dictionary
) -> bool:
	var branch_group: String = str(definition.get("branch_group", ""))

	if branch_group.is_empty():
		return false

	var selected_upgrade: String = get_selected_upgrade_in_branch(
		branch_group
	)

	return (
		not selected_upgrade.is_empty()
		and selected_upgrade != upgrade_id
	)

func get_selected_upgrade_in_branch(branch_group: String) -> String:
	if branch_group.is_empty():
		return ""

	for upgrade_id_variant in UPGRADE_DEFINITIONS.keys():
		var upgrade_id: String = str(upgrade_id_variant)
		var definition: Dictionary = get_upgrade_definition(upgrade_id)

		if str(definition.get("branch_group", "")) != branch_group:
			continue

		if is_upgrade_purchased(upgrade_id):
			return upgrade_id

	return ""

func _is_known_main_tab(main_tab: String) -> bool:
	return main_tab in [
		TAB_PLAYER,
		TAB_FENCE,
		TAB_TURRETS,
		TAB_WEAPONS,
		TAB_BACKPACK,
		TAB_GADGETS
	]

func get_save_data() -> Dictionary:
	var purchased_upgrade_ids: Array[String] = []

	for upgrade_id_variant in purchased_upgrades.keys():
		var upgrade_id: String = str(upgrade_id_variant)

		if bool(purchased_upgrades.get(upgrade_id, false)):
			purchased_upgrade_ids.append(upgrade_id)

	return {
		"purchased_upgrade_ids": purchased_upgrade_ids,
		"workshop_opened_once": workshop_opened_once,
		"last_workshop_tab": last_workshop_tab,
		"last_subtab_by_main_tab": last_subtab_by_main_tab.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	purchased_upgrades.clear()

	var purchased_upgrade_ids: Array = data.get(
		"purchased_upgrade_ids",
		[]
	)

	for upgrade_id_variant in purchased_upgrade_ids:
		var upgrade_id: String = str(upgrade_id_variant)

		if not UPGRADE_DEFINITIONS.has(upgrade_id):
			continue

		purchased_upgrades[upgrade_id] = true

	workshop_opened_once = bool(
		data.get("workshop_opened_once", false)
	)

	last_workshop_tab = str(
		data.get("last_workshop_tab", TAB_PLAYER)
	)

	if not _is_known_main_tab(last_workshop_tab):
		last_workshop_tab = TAB_PLAYER

	var saved_subtabs: Dictionary = data.get(
		"last_subtab_by_main_tab",
		{}
	)

	last_subtab_by_main_tab = {
		TAB_TURRETS: "pesticide_turret",
		TAB_WEAPONS: "pistol"
	}

	for main_tab_variant in saved_subtabs.keys():
		var main_tab: String = str(main_tab_variant)

		if not _is_known_main_tab(main_tab):
			continue

		last_subtab_by_main_tab[main_tab] = str(
			saved_subtabs.get(main_tab, "")
		)

	upgrade_state_changed.emit()

	print(
		"[Upgrade] Loaded ",
		purchased_upgrades.size(),
		" purchased upgrade(s)."
	)

func reset_for_new_game() -> void:
	workshop_opened_once = false
	last_workshop_tab = TAB_PLAYER

	last_subtab_by_main_tab = {
		TAB_TURRETS: "pesticide_turret",
		TAB_WEAPONS: "pistol"
	}

	purchased_upgrades.clear()

	upgrade_state_changed.emit()

	print("[Upgrade] Reset for new game.")
	
func _log_telemetry(
	event_name: String,
	event_data: Dictionary = {}
) -> void:
	var telemetry_manager: Node = get_tree().get_first_node_in_group(
		"telemetry_manager"
	)

	if telemetry_manager == null:
		return

	if telemetry_manager.has_method("log_event"):
		telemetry_manager.call("log_event", event_name, event_data)
		
	
