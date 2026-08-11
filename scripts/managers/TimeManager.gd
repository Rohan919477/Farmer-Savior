extends Node

signal time_changed(day_number: int, hour: int, minute: int, phase: String)
signal night_started
signal midnight_reached
signal day_started(day_number: int)

@export var minutes_per_real_second: float = 10.0
@export var start_hour: int = 6
@export var night_start_hour: int = 18

var day_number: int = 1
var current_minutes: float = 0.0
var phase: String = "day"
var night_started_today: bool = false

func _ready() -> void:
	add_to_group("time_manager")

	current_minutes = float(start_hour * 60)
	phase = "day"
	night_started_today = false

	emit_time_changed()

func _process(delta: float) -> void:
	if _is_tutorial_clock_paused():
		return

	# Normal defense nights are quota-based, not clock-based. Once the
	# 18:00 handoff starts, the wave itself decides when the night is over.
	if _should_pause_for_normal_night():
		return

	if phase == "night_cleanup":
		return

	current_minutes += minutes_per_real_second * delta

	if current_minutes >= 24.0 * 60.0:
		current_minutes = 24.0 * 60.0
		start_night_cleanup()
		return

	check_phase_change()
	emit_time_changed()

func check_phase_change() -> void:
	if phase == "day" and current_minutes >= float(night_start_hour * 60):
		if not night_started_today:
			start_night()

func start_night() -> void:
	phase = "night"
	night_started_today = true

	print("Night started at 18:00.")
	night_started.emit()
	emit_time_changed()

func start_night_cleanup() -> void:
	if phase == "night_cleanup":
		return

	phase = "night_cleanup"

	print("Midnight reached. Clear remaining enemies.")
	midnight_reached.emit()
	emit_time_changed()

func complete_night_and_start_new_day() -> void:
	if phase != "night" and phase != "night_cleanup":
		return

	day_number += 1
	current_minutes = float(start_hour * 60)
	phase = "day"
	night_started_today = false

	print("Day ", day_number, " started at 06:00.")
	day_started.emit(day_number)
	emit_time_changed()

func is_daytime() -> bool:
	return phase == "day"

func is_nighttime() -> bool:
	return phase == "night" or phase == "night_cleanup"

func is_active_night_wave() -> bool:
	return phase == "night"

func is_night_cleanup() -> bool:
	return phase == "night_cleanup"

func get_day_number() -> int:
	return day_number

func get_current_day_number() -> int:
	return day_number

func get_current_minutes() -> float:
	return current_minutes

func set_time_of_day(hour: int, minute: int = 0) -> void:
	var clamped_hour: int = clampi(hour, 0, 24)
	var clamped_minute: int = clampi(minute, 0, 59)

	current_minutes = float(clamped_hour * 60 + clamped_minute)

	if current_minutes >= 24.0 * 60.0:
		current_minutes = 24.0 * 60.0
		start_night_cleanup()
		return

	if current_minutes < float(night_start_hour * 60):
		phase = "day"
		night_started_today = false
	else:
		phase = "night"
		night_started_today = true

	print(
		"[Time] Forced time to ",
		get_time_text(),
		" | Phase: ",
		phase
	)

	emit_time_changed()

func get_hour() -> int:
	return int(current_minutes / 60.0) % 24

func get_minute() -> int:
	return int(current_minutes) % 60

func get_time_text() -> String:
	return "%02d:%02d" % [get_hour(), get_minute()]

func emit_time_changed() -> void:
	time_changed.emit(day_number, get_hour(), get_minute(), phase)

func _is_tutorial_clock_paused() -> bool:
	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if tutorial_manager == null:
		return false

	if tutorial_manager.has_method("should_pause_time"):
		return bool(tutorial_manager.call("should_pause_time"))

	if tutorial_manager.has_method("is_world_soft_paused"):
		return bool(tutorial_manager.call("is_world_soft_paused"))

	return false

func _should_pause_for_normal_night() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("should_pause_clock_for_normal_night"):
		return bool(
			main_node.call("should_pause_clock_for_normal_night")
		)

	return false

func get_save_data() -> Dictionary:
	return {
		"day_number": day_number,
		"current_minutes": current_minutes,
		"hour": get_hour(),
		"minute": get_minute(),
		"phase": phase,
		"night_started_today": night_started_today
	}

func load_save_data(data: Dictionary) -> void:
	day_number = maxi(1, int(data.get("day_number", 1)))

	current_minutes = float(
		data.get(
			"current_minutes",
			float(start_hour * 60)
		)
	)

	current_minutes = clampf(
		current_minutes,
		0.0,
		24.0 * 60.0
	)

	phase = str(data.get("phase", "day"))

	if phase != "day" and phase != "night" and phase != "night_cleanup":
		phase = "day"

	night_started_today = bool(
		data.get(
			"night_started_today",
			phase != "day"
		)
	)


	emit_time_changed()

	print(
		"[Time] Loaded Day ",
		day_number,
		" ",
		get_time_text(),
		" | Phase: ",
		phase
	)

func reset_for_new_game() -> void:
	day_number = 1
	current_minutes = float(start_hour * 60)
	phase = "day"
	night_started_today = false

	emit_time_changed()

	print("[Time] Reset for new game.")
