extends Node
class_name TelemetryManager

signal event_logged(event_name: String, event_data: Dictionary)

const TELEMETRY_DIRECTORY: String = "user://telemetry"
const EVENT_LOG_PATH: String = "user://telemetry/farmer_savior_events.jsonl"

@export var telemetry_enabled: bool = true
@export var print_logged_events: bool = true

var session_id: String = ""

func _ready() -> void:
	add_to_group("telemetry_manager")

	session_id = _create_session_id()
	_ensure_telemetry_directory()

	log_event("telemetry_session_started", {
		"session_id": session_id
	})

func log_event(
	event_name: String,
	event_data: Dictionary = {}
) -> void:
	if not telemetry_enabled:
		return

	if event_name.is_empty():
		return

	_ensure_telemetry_directory()

	var final_event_data: Dictionary = event_data.duplicate(true)

	var event_entry: Dictionary = {
		"event": event_name,
		"timestamp_unix": Time.get_unix_time_from_system(),
		"timestamp_text": Time.get_datetime_string_from_system(
			false,
			true
		),
		"session_id": session_id,
		"context": _get_current_game_context(),
		"data": final_event_data
	}

	var json_line: String = JSON.stringify(event_entry)

	var file: FileAccess = FileAccess.open(
		EVENT_LOG_PATH,
		FileAccess.READ_WRITE
	)

	if file == null:
		file = FileAccess.open(EVENT_LOG_PATH, FileAccess.WRITE)
	else:
		file.seek_end()

	if file == null:
		print("[Telemetry] Could not open telemetry log file.")
		return

	file.store_line(json_line)
	file.close()

	event_logged.emit(event_name, event_entry)

	if print_logged_events:
		print("[Telemetry] ", event_name, " ", final_event_data)

func clear_telemetry_log() -> void:
	_ensure_telemetry_directory()

	var file: FileAccess = FileAccess.open(
		EVENT_LOG_PATH,
		FileAccess.WRITE
	)

	if file == null:
		print("[Telemetry] Could not clear telemetry log.")
		return

	file.store_string("")
	file.close()

	print("[Telemetry] Log cleared.")

func get_telemetry_log_path() -> String:
	return EVENT_LOG_PATH

func _ensure_telemetry_directory() -> void:
	var user_directory: DirAccess = DirAccess.open("user://")

	if user_directory == null:
		print("[Telemetry] Could not open user:// directory.")
		return

	if not user_directory.dir_exists("telemetry"):
		var error_code: int = user_directory.make_dir("telemetry")

		if error_code != OK:
			print("[Telemetry] Could not create telemetry directory.")

func _create_session_id() -> String:
	return "%s_%d" % [
		Time.get_datetime_string_from_system(false, false),
		randi()
	]

func _get_current_game_context() -> Dictionary:
	var context: Dictionary = {
		"day_number": 1,
		"time_text": "06:00",
		"phase": "day",
		"location_id": "unknown"
	}

	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager != null:
		if time_manager.has_method("get_day_number"):
			context["day_number"] = int(
				time_manager.call("get_day_number")
			)

		if time_manager.has_method("get_time_text"):
			context["time_text"] = str(
				time_manager.call("get_time_text")
			)

		if "phase" in time_manager:
			context["phase"] = str(time_manager.get("phase"))

	var map_manager: Node = get_tree().get_first_node_in_group(
		"map_manager"
	)

	if map_manager != null:
		if map_manager.has_method("get_current_location_id"):
			context["location_id"] = str(
				map_manager.call("get_current_location_id")
			)
		elif "current_location_id" in map_manager:
			context["location_id"] = str(
				map_manager.get("current_location_id")
			)

	return context
