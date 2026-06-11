extends CanvasLayer

@onready var time_label: Label = $TimeLabel
@onready var night_warning_label: Label = $NightWarningLabel

var warning_tween: Tween

func update_time(day_number: int, hour: int, minute: int, phase: String) -> void:
	var phase_text: String = phase.capitalize()
	time_label.text = "Day %d | %02d:%02d | %s" % [day_number, hour, minute, phase_text]

func show_nightfall_message(message: String) -> void:
	show_big_red_message(message, 3.0)

func show_warning_message(message: String) -> void:
	show_big_red_message(message, 2.0)

func show_big_red_message(message: String, duration: float) -> void:
	if night_warning_label == null:
		return

	if warning_tween != null:
		warning_tween.kill()

	night_warning_label.text = message
	night_warning_label.visible = true
	night_warning_label.modulate = Color(1, 0, 0, 1)
	night_warning_label.rotation = -0.08
	night_warning_label.scale = Vector2(1.1, 1.1)

	warning_tween = create_tween()
	warning_tween.tween_property(night_warning_label, "scale", Vector2(1.18, 1.18), 0.15)
	warning_tween.tween_property(night_warning_label, "scale", Vector2(1.1, 1.1), 0.15)
	warning_tween.tween_interval(duration)
	warning_tween.tween_property(night_warning_label, "modulate:a", 0.0, 0.5)
	warning_tween.tween_callback(func(): night_warning_label.visible = false)
