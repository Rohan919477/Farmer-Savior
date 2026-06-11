extends Node

signal time_changed(day_number: int, hour: int, minute: int, phase: String)
signal night_started
signal day_started(day_number: int)

@export var minutes_per_real_second: float = 10.0
@export var start_hour: int = 6
@export var night_start_hour: int = 18
@export var night_end_hour: int = 0

var day_number: int = 1
var current_minutes: float = 0.0
var phase: String = "day"

var night_started_today: bool = false

func _ready() -> void:
	current_minutes = float(start_hour * 60)
	phase = "day"
	emit_time_changed()

func _process(delta: float) -> void:
	current_minutes += minutes_per_real_second * delta

	if current_minutes >= 24.0 * 60.0:
		start_new_day()
		return

	check_phase_change()
	emit_time_changed()

func check_phase_change() -> void:
	var current_hour: int = int(current_minutes / 60.0)

	if current_hour >= night_start_hour and not night_started_today:
		start_night()

func start_night() -> void:
	phase = "night"
	night_started_today = true

	print("Night started at 18:00.")
	night_started.emit()
	emit_time_changed()

func start_new_day() -> void:
	day_number += 1
	current_minutes = float(start_hour * 60)
	phase = "day"
	night_started_today = false

	print("Day ", day_number, " started at 06:00.")
	day_started.emit(day_number)
	emit_time_changed()

func get_hour() -> int:
	return int(current_minutes / 60.0)

func get_minute() -> int:
	return int(current_minutes) % 60

func get_time_text() -> String:
	var hour: int = get_hour()
	var minute: int = get_minute()
	return "%02d:%02d" % [hour, minute]

func is_daytime() -> bool:
	return phase == "day"

func emit_time_changed() -> void:
	time_changed.emit(day_number, get_hour(), get_minute(), phase)
