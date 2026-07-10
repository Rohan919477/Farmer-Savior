extends CanvasLayer

@onready var time_label: Label = $TimeLabel
@onready var night_warning_label: Label = $NightWarningLabel
@onready var fade_overlay: ColorRect = $FadeOverlay

@onready var tutorial_objective_label: Label = (
	get_node_or_null("TutorialObjectiveLabel") as Label
)

var warning_tween: Tween
var fade_tween: Tween
var tutorial_feedback_tween: Tween

func _ready() -> void:
	fade_overlay.visible = false
	fade_overlay.modulate = Color(1, 1, 1, 0)

	if tutorial_objective_label != null:
		tutorial_objective_label.visible = false
		tutorial_objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial_objective_label.add_theme_font_size_override(
			"font_size",
			17
		)
		tutorial_objective_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.55, 1.0)
		)

	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	_resize_fade_overlay()
	_layout_tutorial_objective()

func _resize_fade_overlay() -> void:
	fade_overlay.position = Vector2.ZERO
	fade_overlay.size = get_viewport().get_visible_rect().size

func _layout_tutorial_objective() -> void:
	if tutorial_objective_label == null:
		return

	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	tutorial_objective_label.position = Vector2(18.0, 54.0)
	tutorial_objective_label.size = Vector2(
		viewport_size.x - 36.0,
		52.0
	)

func show_tutorial_objective(objective_text: String) -> void:
	if tutorial_objective_label == null:
		return

	if tutorial_feedback_tween != null:
		tutorial_feedback_tween.kill()

	tutorial_objective_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	tutorial_objective_label.text = "Objective: " + objective_text
	tutorial_objective_label.visible = true
	_layout_tutorial_objective()

func hide_tutorial_objective() -> void:
	if tutorial_objective_label == null:
		return

	tutorial_objective_label.visible = false
	
func show_tutorial_completion_message(
	message: String,
	duration: float = 4.0
) -> void:
	if tutorial_objective_label == null:
		return

	if tutorial_feedback_tween != null:
		tutorial_feedback_tween.kill()

	tutorial_objective_label.text = message
	tutorial_objective_label.visible = true
	tutorial_objective_label.modulate = Color(1.0, 0.88, 0.45, 1.0)

	_layout_tutorial_objective()

	tutorial_feedback_tween = create_tween()
	tutorial_feedback_tween.tween_interval(duration)
	tutorial_feedback_tween.tween_property(
		tutorial_objective_label,
		"modulate:a",
		0.0,
		0.65
	)
	tutorial_feedback_tween.tween_callback(
		func() -> void:
			tutorial_objective_label.visible = false
			tutorial_objective_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	)

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
