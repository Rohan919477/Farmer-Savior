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

# Player upgrades
const UPGRADE_FIELD_CONDITIONING: String = "field_conditioning_1"
const UPGRADE_FIELD_CONDITIONING_2: String = "field_conditioning_2"
const UPGRADE_FIELD_CONDITIONING_3: String = "field_conditioning_3"
const UPGRADE_FIELD_RUNNER: String = "field_runner_1"
const UPGRADE_FIELD_RUNNER_2: String = "field_runner_2"
const UPGRADE_HOMESTEAD_GUARDIAN: String = "homestead_guardian_1"
const UPGRADE_HOMESTEAD_GUARDIAN_2: String = "homestead_guardian_2"

# Fence upgrades
const UPGRADE_REINFORCED_TIMBER: String = "reinforced_timber_1"
const UPGRADE_REINFORCED_TIMBER_2: String = "reinforced_timber_2"
const UPGRADE_REINFORCED_TIMBER_3: String = "reinforced_timber_3"
const UPGRADE_STRONGHOLD_FRAMES: String = "stronghold_frames_1"
const UPGRADE_IRON_BRACING: String = "iron_bracing_1"
const UPGRADE_RAPID_PATCHWORK: String = "rapid_patchwork_1"
const UPGRADE_RAPID_PATCHWORK_2: String = "rapid_patchwork_2"

# Pistol/weapon upgrades
const UPGRADE_STABLE_GRIP: String = "stable_grip_1"
const UPGRADE_FARMLOAD_ROUNDS: String = "farmload_rounds_1"
const UPGRADE_QUICK_HANDS: String = "quick_hands_1"
const UPGRADE_DEEP_AMMO_POUCH: String = "deep_ammo_pouch_1"
const UPGRADE_TUNED_TRIGGER: String = "tuned_trigger_1"
const UPGRADE_BIGGER_CHAMBER: String = "bigger_chamber_1"

# Pesticide Turret upgrades
const UPGRADE_SPARE_SPRAYER: String = "spare_sprayer_1"
const UPGRADE_REINFORCED_TANKS: String = "reinforced_tanks_1"
const UPGRADE_FIELD_MAINTENANCE: String = "field_maintenance_1"
const UPGRADE_EXTRA_TURRET_FRAME: String = "extra_turret_frame_1"
const UPGRADE_SEALED_PUMP_HOUSING: String = "sealed_pump_housing_1"

const UPGRADE_DEFINITIONS: Dictionary = {
	UPGRADE_FIELD_CONDITIONING: {
		"tree": TAB_PLAYER,
		"order": 10,
		"title": "Field Conditioning I",
		"description": "Your body hardens against the first nights. +10 Maximum Health.",
		"cost_scrap": 1,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_FIELD_CONDITIONING_2: {
		"tree": TAB_PLAYER,
		"order": 20,
		"title": "Field Conditioning II",
		"description": "+15 Maximum Health. Improves survivability before specialisation.",
		"cost_scrap": 3,
		"requires": [UPGRADE_FIELD_CONDITIONING],
		"branch_group": ""
	},
	UPGRADE_FIELD_RUNNER: {
		"tree": TAB_PLAYER,
		"order": 30,
		"title": "Field Runner I",
		"description": "+25 movement speed. Better for dodging and repositioning.",
		"cost_scrap": 4,
		"requires": [UPGRADE_FIELD_CONDITIONING_2],
		"branch_group": ""
	},
	UPGRADE_HOMESTEAD_GUARDIAN: {
		"tree": TAB_PLAYER,
		"order": 40,
		"title": "Homestead Guardian I",
		"description": "Take 10% less damage from enemies.",
		"cost_scrap": 4,
		"requires": [UPGRADE_FIELD_CONDITIONING_2],
		"branch_group": ""
	},
	UPGRADE_FIELD_CONDITIONING_3: {
		"tree": TAB_PLAYER,
		"order": 50,
		"title": "Field Conditioning III",
		"description": "+20 Maximum Health for longer night survival.",
		"cost_scrap": 5,
		"requires": [UPGRADE_FIELD_CONDITIONING_2],
		"branch_group": ""
	},
	UPGRADE_FIELD_RUNNER_2: {
		"tree": TAB_PLAYER,
		"order": 60,
		"title": "Field Runner II",
		"description": "+20 movement speed. Helps kite Blight Pigs and reposition near fences.",
		"cost_scrap": 6,
		"requires": [UPGRADE_FIELD_RUNNER],
		"branch_group": ""
	},
	UPGRADE_HOMESTEAD_GUARDIAN_2: {
		"tree": TAB_PLAYER,
		"order": 70,
		"title": "Homestead Guardian II",
		"description": "Take another 10% less damage. Stacks with Homestead Guardian I.",
		"cost_scrap": 6,
		"requires": [UPGRADE_HOMESTEAD_GUARDIAN],
		"branch_group": ""
	},

	UPGRADE_REINFORCED_TIMBER: {
		"tree": TAB_FENCE,
		"order": 10,
		"title": "Reinforced Timber I",
		"description": "+20 maximum HP for all non-broken fences.",
		"cost_scrap": 4,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_REINFORCED_TIMBER_2: {
		"tree": TAB_FENCE,
		"order": 20,
		"title": "Reinforced Timber II",
		"description": "+25 maximum HP for all non-broken fences.",
		"cost_scrap": 5,
		"requires": [UPGRADE_REINFORCED_TIMBER],
		"branch_group": ""
	},
	UPGRADE_STRONGHOLD_FRAMES: {
		"tree": TAB_FENCE,
		"order": 30,
		"title": "Stronghold Frames",
		"description": "Fences take 10% less damage from enemies.",
		"cost_scrap": 5,
		"requires": [UPGRADE_REINFORCED_TIMBER_2],
		"branch_group": ""
	},
	UPGRADE_RAPID_PATCHWORK: {
		"tree": TAB_FENCE,
		"order": 40,
		"title": "Rapid Patchwork I",
		"description": "+50% field fence repair speed.",
		"cost_scrap": 5,
		"requires": [UPGRADE_REINFORCED_TIMBER_2],
		"branch_group": ""
	},
	UPGRADE_REINFORCED_TIMBER_3: {
		"tree": TAB_FENCE,
		"order": 50,
		"title": "Reinforced Timber III",
		"description": "+30 maximum HP for all non-broken fences.",
		"cost_scrap": 7,
		"requires": [UPGRADE_REINFORCED_TIMBER_2],
		"branch_group": ""
	},
	UPGRADE_IRON_BRACING: {
		"tree": TAB_FENCE,
		"order": 60,
		"title": "Iron Bracing",
		"description": "Fences take another 15% less damage from enemies.",
		"cost_scrap": 8,
		"requires": [UPGRADE_STRONGHOLD_FRAMES],
		"branch_group": ""
	},
	UPGRADE_RAPID_PATCHWORK_2: {
		"tree": TAB_FENCE,
		"order": 70,
		"title": "Rapid Patchwork II",
		"description": "Another +50% field fence repair speed.",
		"cost_scrap": 8,
		"requires": [UPGRADE_RAPID_PATCHWORK],
		"branch_group": ""
	},

	UPGRADE_STABLE_GRIP: {
		"tree": TAB_WEAPONS,
		"order": 10,
		"title": "Stable Grip",
		"description": "Pistol fire cooldown reduced by 15%.",
		"cost_scrap": 4,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_FARMLOAD_ROUNDS: {
		"tree": TAB_WEAPONS,
		"order": 20,
		"title": "Farmload Rounds",
		"description": "+1 pistol loaded-ammo capacity.",
		"cost_scrap": 5,
		"requires": [UPGRADE_STABLE_GRIP],
		"branch_group": ""
	},
	UPGRADE_QUICK_HANDS: {
		"tree": TAB_WEAPONS,
		"order": 30,
		"title": "Quick Hands",
		"description": "Pistol reload time reduced by 15%.",
		"cost_scrap": 5,
		"requires": [UPGRADE_STABLE_GRIP],
		"branch_group": ""
	},
	UPGRADE_DEEP_AMMO_POUCH: {
		"tree": TAB_WEAPONS,
		"order": 40,
		"title": "Deep Ammo Pouch",
		"description": "+50 reserve pistol ammo immediately.",
		"cost_scrap": 5,
		"requires": [UPGRADE_STABLE_GRIP],
		"branch_group": ""
	},
	UPGRADE_TUNED_TRIGGER: {
		"tree": TAB_WEAPONS,
		"order": 50,
		"title": "Tuned Trigger",
		"description": "Pistol fire cooldown reduced by another 15%.",
		"cost_scrap": 7,
		"requires": [UPGRADE_FARMLOAD_ROUNDS],
		"branch_group": ""
	},
	UPGRADE_BIGGER_CHAMBER: {
		"tree": TAB_WEAPONS,
		"order": 60,
		"title": "Bigger Chamber",
		"description": "+1 more pistol loaded-ammo capacity.",
		"cost_scrap": 8,
		"requires": [UPGRADE_FARMLOAD_ROUNDS],
		"branch_group": ""
	},

	UPGRADE_SPARE_SPRAYER: {
		"tree": TAB_TURRETS,
		"order": 10,
		"title": "Spare Sprayer",
		"description": "+1 maximum Pesticide Turret inventory capacity.",
		"cost_scrap": 5,
		"requires": [],
		"branch_group": ""
	},
	UPGRADE_REINFORCED_TANKS: {
		"tree": TAB_TURRETS,
		"order": 20,
		"title": "Reinforced Tanks",
		"description": "+25 Pesticide Turret integrity and durability.",
		"cost_scrap": 6,
		"requires": [UPGRADE_SPARE_SPRAYER],
		"branch_group": ""
	},
	UPGRADE_FIELD_MAINTENANCE: {
		"tree": TAB_TURRETS,
		"order": 30,
		"title": "Field Maintenance",
		"description": "+50% Pesticide Turret field repair speed.",
		"cost_scrap": 6,
		"requires": [UPGRADE_SPARE_SPRAYER],
		"branch_group": ""
	},
	UPGRADE_EXTRA_TURRET_FRAME: {
		"tree": TAB_TURRETS,
		"order": 40,
		"title": "Extra Turret Frame",
		"description": "+1 more maximum Pesticide Turret inventory capacity.",
		"cost_scrap": 8,
		"requires": [UPGRADE_SPARE_SPRAYER],
		"branch_group": ""
	},
	UPGRADE_SEALED_PUMP_HOUSING: {
		"tree": TAB_TURRETS,
		"order": 50,
		"title": "Sealed Pump Housing",
		"description": "+25 more Pesticide Turret integrity and durability.",
		"cost_scrap": 8,
		"requires": [UPGRADE_REINFORCED_TANKS],
		"branch_group": ""
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

	upgrade_ids.sort_custom(Callable(self, "_compare_upgrade_order"))
	return upgrade_ids

func _compare_upgrade_order(a: String, b: String) -> bool:
	var a_definition: Dictionary = get_upgrade_definition(a)
	var b_definition: Dictionary = get_upgrade_definition(b)

	var a_order: int = int(a_definition.get("order", 9999))
	var b_order: int = int(b_definition.get("order", 9999))

	if a_order == b_order:
		return a < b

	return a_order < b_order

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

	var defense_manager: Node = get_tree().get_first_node_in_group(
		"defense_manager"
	)

	var pistol_node: Node = null

	if player_node != null:
		pistol_node = player_node.get_node_or_null("Pistol")

	match upgrade_id:
		UPGRADE_FIELD_CONDITIONING:
			return _apply_player_health(player_node, 10)

		UPGRADE_FIELD_CONDITIONING_2:
			return _apply_player_health(player_node, 15)

		UPGRADE_FIELD_CONDITIONING_3:
			return _apply_player_health(player_node, 20)

		UPGRADE_FIELD_RUNNER:
			return _apply_player_speed(player_node, 25.0)

		UPGRADE_FIELD_RUNNER_2:
			return _apply_player_speed(player_node, 20.0)

		UPGRADE_HOMESTEAD_GUARDIAN:
			return _apply_player_damage_multiplier(player_node, 0.90)

		UPGRADE_HOMESTEAD_GUARDIAN_2:
			return _apply_player_damage_multiplier(player_node, 0.90)

		UPGRADE_REINFORCED_TIMBER:
			return _call_defense_method(
				defense_manager,
				"apply_fence_max_health_upgrade",
				[20.0]
			)

		UPGRADE_REINFORCED_TIMBER_2:
			return _call_defense_method(
				defense_manager,
				"apply_fence_max_health_upgrade",
				[25.0]
			)

		UPGRADE_REINFORCED_TIMBER_3:
			return _call_defense_method(
				defense_manager,
				"apply_fence_max_health_upgrade",
				[30.0]
			)

		UPGRADE_STRONGHOLD_FRAMES:
			return _call_defense_method(
				defense_manager,
				"apply_fence_damage_multiplier",
				[0.90]
			)

		UPGRADE_IRON_BRACING:
			return _call_defense_method(
				defense_manager,
				"apply_fence_damage_multiplier",
				[0.85]
			)

		UPGRADE_RAPID_PATCHWORK:
			return _call_defense_method(
				defense_manager,
				"apply_fence_repair_rate_multiplier",
				[1.50]
			)

		UPGRADE_RAPID_PATCHWORK_2:
			return _call_defense_method(
				defense_manager,
				"apply_fence_repair_rate_multiplier",
				[1.50]
			)

		UPGRADE_STABLE_GRIP:
			return _call_weapon_method(
				pistol_node,
				"apply_fire_cooldown_multiplier",
				[0.85]
			)

		UPGRADE_FARMLOAD_ROUNDS:
			return _call_weapon_method(
				pistol_node,
				"apply_magazine_size_bonus",
				[1]
			)

		UPGRADE_QUICK_HANDS:
			return _call_weapon_method(
				pistol_node,
				"apply_reload_time_multiplier",
				[0.85]
			)

		UPGRADE_DEEP_AMMO_POUCH:
			return _call_weapon_method(
				pistol_node,
				"add_reserve_ammo",
				[50]
			)

		UPGRADE_TUNED_TRIGGER:
			return _call_weapon_method(
				pistol_node,
				"apply_fire_cooldown_multiplier",
				[0.85]
			)

		UPGRADE_BIGGER_CHAMBER:
			return _call_weapon_method(
				pistol_node,
				"apply_magazine_size_bonus",
				[1]
			)

		UPGRADE_SPARE_SPRAYER:
			return _call_defense_method(
				defense_manager,
				"apply_pesticide_turret_capacity_bonus",
				[1]
			)

		UPGRADE_REINFORCED_TANKS:
			return _call_defense_method(
				defense_manager,
				"apply_pesticide_turret_integrity_and_durability_bonus",
				[25.0]
			)

		UPGRADE_FIELD_MAINTENANCE:
			return _call_defense_method(
				defense_manager,
				"apply_pesticide_turret_repair_rate_multiplier",
				[1.50]
			)

		UPGRADE_EXTRA_TURRET_FRAME:
			return _call_defense_method(
				defense_manager,
				"apply_pesticide_turret_capacity_bonus",
				[1]
			)

		UPGRADE_SEALED_PUMP_HOUSING:
			return _call_defense_method(
				defense_manager,
				"apply_pesticide_turret_integrity_and_durability_bonus",
				[25.0]
			)

	return false

func _apply_player_health(
	player_node: Node,
	health_bonus: int
) -> bool:
	if player_node == null:
		return false

	if not player_node.has_method("apply_max_health_upgrade"):
		return false

	player_node.call("apply_max_health_upgrade", health_bonus)
	return true

func _apply_player_speed(
	player_node: Node,
	speed_bonus: float
) -> bool:
	if player_node == null:
		return false

	if not player_node.has_method("apply_move_speed_upgrade"):
		return false

	player_node.call("apply_move_speed_upgrade", speed_bonus)
	return true

func _apply_player_damage_multiplier(
	player_node: Node,
	multiplier: float
) -> bool:
	if player_node == null:
		return false

	if not player_node.has_method("apply_damage_taken_multiplier"):
		return false

	player_node.call("apply_damage_taken_multiplier", multiplier)
	return true

func _call_weapon_method(
	weapon_node: Node,
	method_name: String,
	args: Array
) -> bool:
	if weapon_node == null:
		return false

	if not weapon_node.has_method(method_name):
		return false

	weapon_node.callv(method_name, args)
	return true

func _call_defense_method(
	defense_manager: Node,
	method_name: String,
	args: Array
) -> bool:
	if defense_manager == null:
		return false

	if not defense_manager.has_method(method_name):
		return false

	defense_manager.callv(method_name, args)
	return true

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
