extends Node
class_name SaveManager

signal save_completed(slot_index: int, save_path: String)
signal save_failed(slot_index: int, reason: String)

signal load_completed(slot_index: int)
signal load_failed(slot_index: int, reason: String)

signal save_deleted(slot_index: int)
signal delete_failed(slot_index: int, reason: String)

const SAVE_SCHEMA_VERSION: int = 1
const SAVE_DIRECTORY: String = "user://saves"
const AUTO_SAVE_SLOT: int = 0
const MAX_SAVE_SLOT: int = 3

func _ready() -> void:
	add_to_group("save_manager")
	_ensure_save_directory()

func get_slot_path(slot_index: int) -> String:
	if slot_index == AUTO_SAVE_SLOT:
		return SAVE_DIRECTORY + "/slot_0_autosave.json"

	return SAVE_DIRECTORY + "/slot_%d.json" % slot_index

func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= AUTO_SAVE_SLOT and slot_index <= MAX_SAVE_SLOT

func has_slot_save(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false

	return FileAccess.file_exists(get_slot_path(slot_index))

func get_slot_display_name(slot_index: int) -> String:
	if slot_index == AUTO_SAVE_SLOT:
		return "Autosave Slot"

	return "Manual Slot %d" % slot_index

func get_slot_summary(slot_index: int) -> Dictionary:
	if not is_valid_slot(slot_index):
		return {
			"title": "Invalid Slot",
			"details": "Unavailable",
			"is_empty": true,
			"slot_index": slot_index
		}

	var slot_title: String = get_slot_display_name(slot_index)

	if not has_slot_save(slot_index):
		return {
			"title": slot_title,
			"details": "Empty",
			"is_empty": true,
			"slot_index": slot_index
		}

	var save_data: Dictionary = _read_save_file(slot_index)

	if save_data.is_empty():
		return {
			"title": slot_title,
			"details": "Unreadable save file",
			"is_empty": false,
			"slot_index": slot_index
		}

	var day_text: String = "Day ?"
	var saved_text: String = str(
		save_data.get("saved_at_text", "Unknown time")
	)

	var time_data: Dictionary = save_data.get("time", {})

	if not time_data.is_empty():
		day_text = "Day %d" % int(time_data.get("day_number", 1))

	return {
		"title": slot_title,
		"details": "%s | %s" % [
			day_text,
			saved_text
		],
		"is_empty": false,
		"slot_index": slot_index
	}

func save_to_slot(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		_emit_save_failed(slot_index, "Invalid save slot.")
		return false

	_ensure_save_directory()

	var save_path: String = get_slot_path(slot_index)
	var save_data: Dictionary = _collect_save_data(slot_index)

	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if file == null:
		var error_message: String = (
			"Could not open save file for writing."
		)

		_emit_save_failed(slot_index, error_message)

		print("[Save] Failed Slot ", slot_index, ": ", error_message)

		return false

	var json_text: String = JSON.stringify(save_data, "\t")

	file.store_string(json_text)
	file.close()

	save_completed.emit(slot_index, save_path)

	_log_telemetry("save_completed", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index),
		"save_path": save_path
	})

	print(
		"[Save] Saved Slot ",
		slot_index,
		" to ",
		save_path
	)

	return true

func load_slot_data(slot_index: int) -> Dictionary:
	if not is_valid_slot(slot_index):
		_emit_load_failed(slot_index, "Invalid save slot.")
		return {}

	if not has_slot_save(slot_index):
		_emit_load_failed(slot_index, "Save slot is empty.")
		return {}

	var save_data: Dictionary = _read_save_file(slot_index)

	if save_data.is_empty():
		_emit_load_failed(slot_index, "Save file could not be read.")
		return {}

	var schema_version: int = int(
		save_data.get("schema_version", 0)
	)

	if schema_version != SAVE_SCHEMA_VERSION:
		print(
			"[Load] Warning: save schema version ",
			schema_version,
			" does not match current version ",
			SAVE_SCHEMA_VERSION,
			"."
		)

	load_completed.emit(slot_index)

	_log_telemetry("load_completed", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index)
	})

	print("[Load] Loaded Slot ", slot_index)

	return save_data

func delete_slot_save(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		_emit_delete_failed(slot_index, "Invalid save slot.")
		return false

	if not has_slot_save(slot_index):
		_emit_delete_failed(slot_index, "Save slot is already empty.")
		return false

	var save_directory: DirAccess = DirAccess.open(SAVE_DIRECTORY)

	if save_directory == null:
		_emit_delete_failed(
			slot_index,
			"Could not open save directory."
		)
		return false

	var save_file_name: String = get_slot_path(slot_index).get_file()
	var error_code: int = save_directory.remove(save_file_name)

	if error_code != OK:
		_emit_delete_failed(slot_index, "Could not delete save file.")
		print("[Save] Failed to delete Slot ", slot_index)
		return false

	save_deleted.emit(slot_index)

	_log_telemetry("save_deleted", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index)
	})

	print("[Save] Deleted Slot ", slot_index)

	return true

func _ensure_save_directory() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")

	if user_directory == null:
		print("[Save] Could not open user:// directory.")
		return

	if not user_directory.dir_exists("saves"):
		var error_code: int = user_directory.make_dir("saves")

		if error_code != OK:
			print("[Save] Could not create saves directory.")

func _read_save_file(slot_index: int) -> Dictionary:
	if not is_valid_slot(slot_index):
		return {}

	var save_path: String = get_slot_path(slot_index)

	if not FileAccess.file_exists(save_path):
		return {}

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if file == null:
		return {}

	var json_text: String = file.get_as_text()
	file.close()

	var parsed_data: Variant = JSON.parse_string(json_text)

	if typeof(parsed_data) != TYPE_DICTIONARY:
		return {}

	return parsed_data as Dictionary

func _collect_save_data(slot_index: int) -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_text": _get_current_datetime_text(),
		"game": {
			"prototype_week": 10,
			"save_rule": "bed_sleep_checkpoint"
		},
		"time": _get_time_save_data(),
		"map": _get_map_save_data(),
		"player": _get_player_save_data(),
		"inventory": _get_inventory_save_data(),
		"resources": _get_resource_summary_data(),
		"upgrades": _get_upgrade_save_data(),
		"defense": _get_defense_save_data(),
		"crops": _get_crop_save_data(),
		"tutorial": _get_tutorial_save_data()
	}

func _get_current_datetime_text() -> String:
	return Time.get_datetime_string_from_system(false, true)

func _get_time_save_data() -> Dictionary:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager == null:
		return {}

	if time_manager.has_method("get_save_data"):
		return time_manager.call("get_save_data")

	return {}

func _get_map_save_data() -> Dictionary:
	var map_manager: Node = get_tree().get_first_node_in_group(
		"map_manager"
	)

	if map_manager == null:
		return {}

	if map_manager.has_method("get_save_data"):
		return map_manager.call("get_save_data")

	var current_location_id: String = "farm"

	if map_manager.has_method("get_current_location_id"):
		current_location_id = str(
			map_manager.call("get_current_location_id")
		)
	elif "current_location_id" in map_manager:
		current_location_id = str(map_manager.get("current_location_id"))

	return {
		"current_location_id": current_location_id
	}

func _get_player_save_data() -> Dictionary:
	var player: Node = get_tree().get_first_node_in_group("player")

	if player == null:
		return {}

	if player.has_method("get_save_data"):
		return player.call("get_save_data")

	return {}

func _get_inventory_save_data() -> Dictionary:
	var inventory_manager: Node = get_tree().get_first_node_in_group(
		"inventory_manager"
	)

	if inventory_manager == null:
		return {}

	if inventory_manager.has_method("get_save_data"):
		return inventory_manager.call("get_save_data")

	return {}

func _get_resource_summary_data() -> Dictionary:
	var inventory_manager: Node = get_tree().get_first_node_in_group(
		"inventory_manager"
	)

	if inventory_manager == null:
		return {
			"seeds": 0,
			"scrap": 0,
			"mutant_seeds": 0
		}

	if not inventory_manager.has_method("get_item_amount"):
		return {
			"seeds": 0,
			"scrap": 0,
			"mutant_seeds": 0
		}

	return {
		"seeds": int(
			inventory_manager.call("get_item_amount", "seeds")
		),
		"scrap": int(
			inventory_manager.call("get_item_amount", "scrap")
		),
		"mutant_seeds": int(
			inventory_manager.call("get_item_amount", "mutant_seeds")
		)
	}

func _get_upgrade_save_data() -> Dictionary:
	var upgrade_manager: Node = get_tree().get_first_node_in_group(
		"upgrade_manager"
	)

	if upgrade_manager == null:
		return {}

	if upgrade_manager.has_method("get_save_data"):
		return upgrade_manager.call("get_save_data")

	return {}

func _get_defense_save_data() -> Dictionary:
	var defense_manager: Node = get_tree().get_first_node_in_group(
		"defense_manager"
	)

	if defense_manager == null:
		return {}

	if defense_manager.has_method("get_save_data"):
		return defense_manager.call("get_save_data")

	return {}

func _get_crop_save_data() -> Dictionary:
	var crop_manager: Node = get_tree().get_first_node_in_group(
		"crop_manager"
	)

	if crop_manager == null:
		return {}

	if crop_manager.has_method("get_save_data"):
		return crop_manager.call("get_save_data")

	return {}

func _get_tutorial_save_data() -> Dictionary:
	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if tutorial_manager == null:
		return {
			"tutorial_completed": false
		}

	if tutorial_manager.has_method("get_save_data"):
		return tutorial_manager.call("get_save_data")

	var tutorial_completed: bool = false

	if tutorial_manager.has_method("is_tutorial_completed"):
		tutorial_completed = bool(
			tutorial_manager.call("is_tutorial_completed")
		)

	return {
		"tutorial_completed": tutorial_completed
	}

func _emit_save_failed(slot_index: int, reason: String) -> void:
	save_failed.emit(slot_index, reason)

	_log_telemetry("save_failed", {
		"slot_index": slot_index,
		"reason": reason
	})

func _emit_load_failed(slot_index: int, reason: String) -> void:
	load_failed.emit(slot_index, reason)

	_log_telemetry("load_failed", {
		"slot_index": slot_index,
		"reason": reason
	})

func _emit_delete_failed(slot_index: int, reason: String) -> void:
	delete_failed.emit(slot_index, reason)

	_log_telemetry("save_delete_failed", {
		"slot_index": slot_index,
		"reason": reason
	})

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
