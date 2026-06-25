extends CanvasLayer

@onready var time_label: Label = $TimeLabel
@onready var night_warning_label: Label = $NightWarningLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

var warning_tween: Tween
var fade_tween: Tween

func _ready() -> void:
	fade_overlay.visible = false
	fade_overlay.modulate = Color(1, 1, 1, 0)

	get_viewport().size_changed.connect(_resize_fade_overlay)
	_resize_fade_overlay()

func _resize_fade_overlay() -> void:
	fade_overlay.position = Vector2.ZERO
	fade_overlay.size = get_viewport().get_visible_rect().size

func update_time(day_number: int, hour: int, minute: int, phase: String) -> void:
	time_label.text = "Day %d | %02d:%02d | %s" % [
		day_number,
		hour,
		minute,
		get_phase_display_name(phase)
	]

func get_phase_display_name(phase: String) -> String:
	match phase:
		"day":
			return "Day"
		"night":
			return "Night"
		"night_cleanup":
			return "Clear Remaining Enemies"
		_:
			return phase.capitalize()

func show_nightfall_message(message: String) -> void:
	show_big_red_message(message, 3.0)

func show_warning_message(message: String) -> void:
	show_big_red_message(message, 2.0)

func show_big_red_message(message: String, duration: float) -> void:
	if warning_tween != null:
		warning_tween.kill()

	night_warning_label.text = message
	night_warning_label.visible = true
	night_warning_label.modulate = Color(1, 0, 0, 1)
	night_warning_label.rotation = -0.08
	night_warning_label.scale = Vector2(1.1, 1.1)

	warning_tween = create_tween()
	warning_tween.tween_property(
		night_warning_label,
		"scale",
		Vector2(1.18, 1.18),
		0.15
	)
	warning_tween.tween_property(
		night_warning_label,
		"scale",
		Vector2(1.1, 1.1),
		0.15
	)
	warning_tween.tween_interval(duration)
	warning_tween.tween_property(
		night_warning_label,
		"modulate:a",
		0.0,
		0.5
	)
	warning_tween.tween_callback(
		func() -> void:
			night_warning_label.visible = false
	)

func fade_to_black(duration: float = 0.35) -> void:
	if fade_tween != null:
		fade_tween.kill()

	fade_overlay.visible = true
	fade_overlay.modulate = Color(1, 1, 1, 0)

	fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, duration)

	await fade_tween.finished

func fade_from_black(duration: float = 0.35) -> void:
	if fade_tween != null:
		fade_tween.kill()

	fade_overlay.visible = true
	fade_overlay.modulate = Color(1, 1, 1, 1)

	fade_tween = create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 0.0, duration)

	await fade_tween.finished

	fade_overlay.visible = false
