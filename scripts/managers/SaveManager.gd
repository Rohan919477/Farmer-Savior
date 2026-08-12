extends Node
class_name SaveManager

signal save_completed(slot_index: int, save_path: String)
signal save_failed(slot_index: int, reason: String)
signal load_completed(slot_index: int)
signal load_failed(slot_index: int, reason: String)
signal save_deleted(slot_index: int)
signal delete_failed(slot_index: int, reason: String)

# Save System V2 owns file/schema concerns only. Gameplay systems own the
# contents of their sections through get_save_data()/load_save_data().
# Future persistent world objects should use stable persistent IDs rather than
# scene-tree NodePaths so scene reorganizations do not invalidate saves.
const SAVE_SCHEMA_VERSION: int = 2
const OLDEST_SUPPORTED_SCHEMA_VERSION: int = 1
const SAVE_DIRECTORY: String = "user://saves"
const AUTO_SAVE_SLOT: int = 0
const MAX_SAVE_SLOT: int = 3

var last_validation_error: String = ""

func _ready() -> void:
	add_to_group("save_manager")
	_ensure_save_directory()

func get_slot_path(slot_index: int) -> String:
	if slot_index == AUTO_SAVE_SLOT:
		return SAVE_DIRECTORY + "/slot_0_autosave.json"
	return SAVE_DIRECTORY + "/slot_%d.json" % slot_index

func get_slot_backup_path(slot_index: int) -> String:
	return get_slot_path(slot_index).get_basename() + ".backup.json"

func get_slot_temp_path(slot_index: int) -> String:
	return get_slot_path(slot_index).get_basename() + ".tmp.json"

func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= AUTO_SAVE_SLOT and slot_index <= MAX_SAVE_SLOT

func has_slot_save(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false
	return (
		FileAccess.file_exists(get_slot_path(slot_index))
		or FileAccess.file_exists(get_slot_backup_path(slot_index))
	)

func has_slot_backup(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		return false
	return FileAccess.file_exists(get_slot_backup_path(slot_index))

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

	var prepared_result: Dictionary = _read_prepared_slot_data(slot_index)
	var save_data: Dictionary = prepared_result.get("data", {})
	if save_data.is_empty():
		return {
			"title": slot_title,
			"details": "Unreadable or unsupported save file",
			"is_empty": false,
			"slot_index": slot_index
		}

	var meta: Dictionary = save_data.get("meta", {})
	var world: Dictionary = save_data.get("world", {})
	var time_data: Dictionary = world.get("time", {})
	var day_text: String = "Day ?"
	if not time_data.is_empty():
		day_text = "Day %d" % maxi(int(time_data.get("day_number", 1)), 1)

	var saved_text: String = str(meta.get("saved_at_text", "Unknown time"))
	var details: String = "%s | %s" % [day_text, saved_text]
	if bool(prepared_result.get("used_backup", false)):
		details += " | Backup recovered"

	return {
		"title": slot_title,
		"details": details,
		"is_empty": false,
		"slot_index": slot_index
	}

func save_to_slot(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		_emit_save_failed(slot_index, "Invalid save slot.")
		return false

	_ensure_save_directory()
	var save_path: String = get_slot_path(slot_index)
	var backup_path: String = get_slot_backup_path(slot_index)
	var temp_path: String = get_slot_temp_path(slot_index)
	var save_data: Dictionary = _collect_save_data(slot_index)

	var validation: Dictionary = validate_save_data(save_data)
	if not bool(validation.get("valid", false)):
		var reason: String = str(validation.get("reason", "Save validation failed."))
		_emit_save_failed(slot_index, reason)
		return false

	_remove_file_if_exists(temp_path)
	if not _write_json_file(temp_path, save_data):
		_emit_save_failed(slot_index, "Could not write temporary save file.")
		return false

	# Verify the temporary file before touching the current good save.
	var temp_data: Dictionary = _read_save_file_at_path(temp_path)
	var temp_validation: Dictionary = validate_save_data(temp_data)
	if not bool(temp_validation.get("valid", false)):
		_remove_file_if_exists(temp_path)
		_emit_save_failed(slot_index, "Temporary save verification failed.")
		return false

	# Preserve the previous primary as a backup only if it is itself readable,
	# migratable and valid. A corrupt primary must never overwrite a good backup.
	if FileAccess.file_exists(save_path):
		var previous_raw: Dictionary = _read_save_file_at_path(save_path)
		var previous_valid: Dictionary = {}
		if not previous_raw.is_empty():
			previous_valid = _prepare_save_data(previous_raw, slot_index)

		if not previous_valid.is_empty():
			if not _copy_file(save_path, backup_path):
				_remove_file_if_exists(temp_path)
				_emit_save_failed(slot_index, "Could not create save backup.")
				return false
		else:
			print("[Save] Existing primary is invalid; keeping the older backup unchanged.")

	if not _replace_file_with_temp(save_path, temp_path):
		if (
			not FileAccess.file_exists(save_path)
			and FileAccess.file_exists(backup_path)
		):
			_copy_file(backup_path, save_path)
		_remove_file_if_exists(temp_path)
		_emit_save_failed(slot_index, "Could not replace the current save file.")
		return false

	# Verify the final primary and roll back if replacement produced a bad file.
	var final_data: Dictionary = _read_save_file_at_path(save_path)
	var final_validation: Dictionary = validate_save_data(final_data)
	if not bool(final_validation.get("valid", false)):
		_remove_file_if_exists(save_path)
		if FileAccess.file_exists(backup_path):
			_copy_file(backup_path, save_path)
		_emit_save_failed(
			slot_index,
			"Final save verification failed; previous backup restored."
		)
		return false

	save_completed.emit(slot_index, save_path)
	_log_telemetry("save_completed", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index),
		"save_path": save_path,
		"schema_version": SAVE_SCHEMA_VERSION,
		"backup_available": FileAccess.file_exists(backup_path)
	})
	print("[Save] Saved Slot ", slot_index, " as schema V", SAVE_SCHEMA_VERSION)
	return true

func load_slot_data(slot_index: int) -> Dictionary:
	if not is_valid_slot(slot_index):
		_emit_load_failed(slot_index, "Invalid save slot.")
		return {}
	if not has_slot_save(slot_index):
		_emit_load_failed(slot_index, "Save slot is empty.")
		return {}

	var prepared_result: Dictionary = _read_prepared_slot_data(slot_index)
	var save_data: Dictionary = prepared_result.get("data", {})
	if save_data.is_empty():
		var reason: String = last_validation_error
		if reason.is_empty():
			reason = "Save file could not be read or migrated."
		_emit_load_failed(slot_index, reason)
		return {}

	var used_backup: bool = bool(prepared_result.get("used_backup", false))
	var source_version: int = int(
		prepared_result.get("source_schema_version", SAVE_SCHEMA_VERSION)
	)

	load_completed.emit(slot_index)
	_log_telemetry("load_completed", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index),
		"schema_version": SAVE_SCHEMA_VERSION,
		"source_schema_version": source_version,
		"used_backup": used_backup
	})

	if source_version < SAVE_SCHEMA_VERSION:
		print(
			"[Load] Migrated Slot ", slot_index,
			" from schema V", source_version,
			" to V", SAVE_SCHEMA_VERSION,
			" in memory. The next save will write V", SAVE_SCHEMA_VERSION, "."
		)
	if used_backup:
		print("[Load] Loaded backup for Slot ", slot_index, ".")
	print("[Load] Loaded Slot ", slot_index)
	return save_data

func delete_slot_save(slot_index: int) -> bool:
	if not is_valid_slot(slot_index):
		_emit_delete_failed(slot_index, "Invalid save slot.")
		return false
	if not has_slot_save(slot_index):
		_emit_delete_failed(slot_index, "Save slot is already empty.")
		return false

	var removed_any: bool = false
	var delete_failed_any: bool = false
	for path in [
		get_slot_path(slot_index),
		get_slot_backup_path(slot_index),
		get_slot_temp_path(slot_index)
	]:
		if not FileAccess.file_exists(path):
			continue
		if _remove_file_if_exists(path):
			removed_any = true
		else:
			delete_failed_any = true

	if delete_failed_any or not removed_any:
		_emit_delete_failed(slot_index, "Could not delete all save files.")
		return false

	save_deleted.emit(slot_index)
	_log_telemetry("save_deleted", {
		"slot_index": slot_index,
		"slot_name": get_slot_display_name(slot_index)
	})
	print("[Save] Deleted Slot ", slot_index, " and its backup.")
	return true

# Public validation entry point. New fields inside owned sections can remain
# optional and use defaults; incompatible root/schema changes require migration.
func validate_save_data(save_data: Dictionary) -> Dictionary:
	if save_data.is_empty():
		return _validation_failure("Save data is empty.")

	var schema_version: int = int(save_data.get("schema_version", 0))
	if schema_version != SAVE_SCHEMA_VERSION:
		return _validation_failure(
			"Expected save schema V%d but received V%d." % [
				SAVE_SCHEMA_VERSION, schema_version
			]
		)

	var required_dictionary_sections: Array[String] = [
		"meta", "world", "player", "inventory",
		"progression", "defenses", "farming", "maps"
	]
	for section_name in required_dictionary_sections:
		if not save_data.has(section_name):
			return _validation_failure(
				"Missing required save section: %s" % section_name
			)
		if typeof(save_data.get(section_name)) != TYPE_DICTIONARY:
			return _validation_failure(
				"Save section '%s' must be a Dictionary." % section_name
			)

	var world: Dictionary = save_data.get("world", {})
	for world_section in ["time", "map"]:
		if typeof(world.get(world_section, {})) != TYPE_DICTIONARY:
			return _validation_failure(
				"World section '%s' must be a Dictionary." % world_section
			)

	var progression: Dictionary = save_data.get("progression", {})
	for progression_section in ["upgrades", "tutorial"]:
		if typeof(progression.get(progression_section, {})) != TYPE_DICTIONARY:
			return _validation_failure(
				"Progression section '%s' must be a Dictionary." % progression_section
			)

	var meta: Dictionary = save_data.get("meta", {})
	if not is_valid_slot(int(meta.get("slot_index", -1))):
		return _validation_failure("Save metadata contains an invalid slot index.")

	var time_data: Dictionary = world.get("time", {})
	if int(time_data.get("day_number", 1)) < 1:
		return _validation_failure("Saved day number must be at least 1.")
	var current_minutes: float = float(time_data.get("current_minutes", 0.0))
	if current_minutes < 0.0 or current_minutes > 1440.0:
		return _validation_failure("Saved time must be between 00:00 and 24:00.")

	return {"valid": true, "reason": ""}

func _validation_failure(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}

func _ensure_save_directory() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")
	if user_directory == null:
		print("[Save] Could not open user:// directory.")
		return
	if not user_directory.dir_exists("saves"):
		var error_code: int = user_directory.make_dir("saves")
		if error_code != OK:
			print("[Save] Could not create saves directory.")

func _read_prepared_slot_data(slot_index: int) -> Dictionary:
	last_validation_error = ""
	var primary_path: String = get_slot_path(slot_index)
	var backup_path: String = get_slot_backup_path(slot_index)

	var primary_raw: Dictionary = _read_save_file_at_path(primary_path)
	if not primary_raw.is_empty():
		var primary_source_version: int = int(primary_raw.get("schema_version", 0))
		var primary_data: Dictionary = _prepare_save_data(primary_raw, slot_index)
		if not primary_data.is_empty():
			return {
				"data": primary_data,
				"used_backup": false,
				"source_path": primary_path,
				"source_schema_version": primary_source_version
			}

	var primary_error: String = last_validation_error
	var backup_raw: Dictionary = _read_save_file_at_path(backup_path)
	if not backup_raw.is_empty():
		var backup_source_version: int = int(backup_raw.get("schema_version", 0))
		var backup_data: Dictionary = _prepare_save_data(backup_raw, slot_index)
		if not backup_data.is_empty():
			return {
				"data": backup_data,
				"used_backup": true,
				"source_path": backup_path,
				"source_schema_version": backup_source_version
			}

	if last_validation_error.is_empty():
		last_validation_error = primary_error
	if last_validation_error.is_empty():
		last_validation_error = "No readable save or backup was found."
	return {}

func _read_save_file_at_path(save_path: String) -> Dictionary:
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

func _prepare_save_data(raw_save_data: Dictionary, expected_slot_index: int) -> Dictionary:
	last_validation_error = ""
	if raw_save_data.is_empty():
		last_validation_error = "Save file is empty."
		return {}

	var source_version: int = int(raw_save_data.get("schema_version", 0))
	if source_version > SAVE_SCHEMA_VERSION:
		last_validation_error = (
			"Save schema V%d is newer than this game supports (V%d)." % [
				source_version, SAVE_SCHEMA_VERSION
			]
		)
		return {}
	if source_version < OLDEST_SUPPORTED_SCHEMA_VERSION:
		last_validation_error = "Save schema V%d is too old or missing." % source_version
		return {}

	var save_data: Dictionary = raw_save_data.duplicate(true)
	var working_version: int = source_version
	while working_version < SAVE_SCHEMA_VERSION:
		match working_version:
			1:
				save_data = _migrate_v1_to_v2(save_data, expected_slot_index)
			_:
				last_validation_error = (
					"No migration path exists from save schema V%d." % working_version
				)
				return {}
		if save_data.is_empty():
			last_validation_error = "Migration from schema V%d failed." % working_version
			return {}
		working_version = int(save_data.get("schema_version", working_version))

	var validation: Dictionary = validate_save_data(save_data)
	if not bool(validation.get("valid", false)):
		last_validation_error = str(validation.get("reason", "Save validation failed."))
		return {}

	# Slot metadata is informational. Normalize it to the physical slot that was
	# selected without changing any gameplay-owned data.
	var normalized_data: Dictionary = save_data.duplicate(true)
	var meta: Dictionary = normalized_data.get("meta", {})
	meta["slot_index"] = expected_slot_index
	meta["slot_name"] = get_slot_display_name(expected_slot_index)
	normalized_data["meta"] = meta
	return normalized_data

func _migrate_v1_to_v2(v1_data: Dictionary, expected_slot_index: int) -> Dictionary:
	var old_slot_index: int = int(v1_data.get("slot_index", expected_slot_index))
	if not is_valid_slot(old_slot_index):
		old_slot_index = expected_slot_index
	var old_game: Dictionary = _dictionary_or_empty(v1_data.get("game", {}))

	return {
		"schema_version": 2,
		"meta": {
			"slot_index": old_slot_index,
			"slot_name": str(v1_data.get("slot_name", get_slot_display_name(old_slot_index))),
			"saved_at_unix": float(v1_data.get("saved_at_unix", 0.0)),
			"saved_at_text": str(v1_data.get("saved_at_text", "Unknown time")),
			"game_version": str(old_game.get("game_version", "legacy-v1")),
			"save_rule": str(old_game.get("save_rule", "bed_sleep_checkpoint")),
			"migrated_from_schema": 1
		},
		"world": {
			"time": _dictionary_or_empty(v1_data.get("time", {})),
			"map": _dictionary_or_empty(v1_data.get("map", {}))
		},
		"player": _migrate_v1_player_data(
			_dictionary_or_empty(v1_data.get("player", {}))
		),
		"inventory": _dictionary_or_empty(v1_data.get("inventory", {})),
		"progression": {
			"upgrades": _dictionary_or_empty(v1_data.get("upgrades", {})),
			"tutorial": _dictionary_or_empty(v1_data.get("tutorial", {}))
		},
		"defenses": _dictionary_or_empty(v1_data.get("defense", {})),
		"farming": _dictionary_or_empty(v1_data.get("crops", {})),
		"maps": {}
	}


func _migrate_v1_player_data(v1_player: Dictionary) -> Dictionary:
	var player_data: Dictionary = v1_player.duplicate(true)
	var pistol_data: Dictionary = _dictionary_or_empty(
		player_data.get("pistol", {})
	)

	if not pistol_data.is_empty():
		# Support older ammo-pool field names without forcing the weapon script
		# to understand every historical save representation.
		if not pistol_data.has("reserve_ammo"):
			if pistol_data.has("total_ammo"):
				pistol_data["reserve_ammo"] = maxi(
					int(pistol_data.get("total_ammo", 0)), 0
				)
			elif pistol_data.has("total_magazines"):
				var magazine_size: int = maxi(
					int(pistol_data.get("magazine_size", 6)), 1
				)
				pistol_data["reserve_ammo"] = maxi(
					int(pistol_data.get("total_magazines", 0)), 0
				) * magazine_size

		pistol_data.erase("total_ammo")
		pistol_data.erase("total_magazines")
		player_data["pistol"] = pistol_data

	return player_data

func _dictionary_or_empty(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)

func _collect_save_data(slot_index: int) -> Dictionary:
	return {
		"schema_version": SAVE_SCHEMA_VERSION,
		"meta": {
			"slot_index": slot_index,
			"slot_name": get_slot_display_name(slot_index),
			"saved_at_unix": Time.get_unix_time_from_system(),
			"saved_at_text": _get_current_datetime_text(),
			"game_version": _get_game_version_text(),
			"save_rule": "bed_sleep_checkpoint"
		},
		"world": {
			"time": _get_time_save_data(),
			"map": _get_map_save_data()
		},
		"player": _get_player_save_data(),
		"inventory": _get_inventory_save_data(),
		"progression": {
			"upgrades": _get_upgrade_save_data(),
			"tutorial": _get_tutorial_save_data()
		},
		"defenses": _get_defense_save_data(),
		"farming": _get_crop_save_data(),
		# Persistent per-map state. Resource drops are the first V2 map-owned data.
		"maps": _get_world_drop_save_data()
	}

func _get_current_datetime_text() -> String:
	return Time.get_datetime_string_from_system(false, true)

func _get_game_version_text() -> String:
	var version_text: String = str(ProjectSettings.get_setting(
		"application/config/version", "prototype"
	))
	if version_text.is_empty():
		return "prototype"
	return version_text

func _get_time_save_data() -> Dictionary:
	return _get_group_save_data("time_manager")

func _get_map_save_data() -> Dictionary:
	return _get_group_save_data("map_manager")

func _get_player_save_data() -> Dictionary:
	return _get_group_save_data("player")

func _get_inventory_save_data() -> Dictionary:
	return _get_group_save_data("inventory_manager")

func _get_upgrade_save_data() -> Dictionary:
	return _get_group_save_data("upgrade_manager")

func _get_defense_save_data() -> Dictionary:
	return _get_group_save_data("defense_manager")

func _get_crop_save_data() -> Dictionary:
	return _get_group_save_data("crop_manager")

func _get_world_drop_save_data() -> Dictionary:
	return _get_group_save_data("world_drop_manager")

func _get_group_save_data(group_name: String) -> Dictionary:
	var owner: Node = get_tree().get_first_node_in_group(group_name)
	if owner == null or not owner.has_method("get_save_data"):
		return {}
	var result: Variant = owner.call("get_save_data")
	if typeof(result) != TYPE_DICTIONARY:
		return {}
	return result as Dictionary

func _get_tutorial_save_data() -> Dictionary:
	var tutorial_manager: Node = get_tree().get_first_node_in_group("tutorial_manager")
	if tutorial_manager == null:
		return {"tutorial_completed": false}
	if tutorial_manager.has_method("get_save_data"):
		var result: Variant = tutorial_manager.call("get_save_data")
		if typeof(result) == TYPE_DICTIONARY:
			return result as Dictionary
	var tutorial_completed: bool = false
	if tutorial_manager.has_method("is_tutorial_completed"):
		tutorial_completed = bool(tutorial_manager.call("is_tutorial_completed"))
	return {"tutorial_completed": tutorial_completed}

func _write_json_file(path: String, save_data: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func _copy_file(source_path: String, destination_path: String) -> bool:
	if not FileAccess.file_exists(source_path):
		return false
	var source: FileAccess = FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return false
	var bytes: PackedByteArray = source.get_buffer(source.get_length())
	source.close()
	var destination: FileAccess = FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return false
	destination.store_buffer(bytes)
	destination.close()
	return true

func _replace_file_with_temp(final_path: String, temp_path: String) -> bool:
	var save_directory: DirAccess = DirAccess.open(SAVE_DIRECTORY)
	if save_directory == null:
		return false
	var final_file_name: String = final_path.get_file()
	var temp_file_name: String = temp_path.get_file()
	if save_directory.file_exists(final_file_name):
		if save_directory.remove(final_file_name) != OK:
			return false
	return save_directory.rename(temp_file_name, final_file_name) == OK

func _remove_file_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	var save_directory: DirAccess = DirAccess.open(SAVE_DIRECTORY)
	if save_directory == null:
		return false
	return save_directory.remove(path.get_file()) == OK

func _emit_save_failed(slot_index: int, reason: String) -> void:
	save_failed.emit(slot_index, reason)
	_log_telemetry("save_failed", {
		"slot_index": slot_index,
		"reason": reason,
		"schema_version": SAVE_SCHEMA_VERSION
	})

func _emit_load_failed(slot_index: int, reason: String) -> void:
	load_failed.emit(slot_index, reason)
	_log_telemetry("load_failed", {
		"slot_index": slot_index,
		"reason": reason,
		"schema_version": SAVE_SCHEMA_VERSION
	})

func _emit_delete_failed(slot_index: int, reason: String) -> void:
	delete_failed.emit(slot_index, reason)
	_log_telemetry("save_delete_failed", {
		"slot_index": slot_index,
		"reason": reason
	})

func _log_telemetry(event_name: String, event_data: Dictionary = {}) -> void:
	var telemetry_manager: Node = get_tree().get_first_node_in_group("telemetry_manager")
	if telemetry_manager == null:
		return
	if telemetry_manager.has_method("log_event"):
		telemetry_manager.call("log_event", event_name, event_data)
