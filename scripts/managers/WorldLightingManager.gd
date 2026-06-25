extends Node2D

@onready var world_tint: CanvasModulate = $CanvasModulate
@onready var celestial_light: DirectionalLight2D = $DirectionalLight2D

var time_manager: Node

func _ready() -> void:
	time_manager = get_tree().get_first_node_in_group("time_manager")

	if time_manager == null:
		return

	if time_manager.has_signal("time_changed"):
		time_manager.time_changed.connect(_on_time_changed)

	update_lighting()

func _on_time_changed(
	_day_number: int,
	_hour: int,
	_minute: int,
	_phase: String
) -> void:
	update_lighting()

func update_lighting() -> void:
	if time_manager == null:
		return

	var current_minutes: float = float(time_manager.call("get_current_minutes"))
	current_minutes = clampf(current_minutes, 360.0, 1440.0)

	world_tint.color = get_ambient_tint(current_minutes)
	celestial_light.color = get_light_color(current_minutes)
	celestial_light.energy = get_light_energy(current_minutes)

	var cycle_progress: float = inverse_lerp(360.0, 1440.0, current_minutes)

	celestial_light.rotation = deg_to_rad(
		lerpf(-35.0, 215.0, cycle_progress)
	)

func get_ambient_tint(minutes: float) -> Color:
	if minutes <= 540.0:
		return Color(0.68, 0.73, 0.92).lerp(
			Color(1.0, 0.94, 0.78),
			inverse_lerp(360.0, 540.0, minutes)
		)

	if minutes <= 720.0:
		return Color(1.0, 0.94, 0.78).lerp(
			Color(1.0, 1.0, 1.0),
			inverse_lerp(540.0, 720.0, minutes)
		)

	if minutes <= 960.0:
		return Color(1.0, 1.0, 1.0).lerp(
			Color(1.0, 0.88, 0.66),
			inverse_lerp(720.0, 960.0, minutes)
		)

	if minutes <= 1080.0:
		return Color(1.0, 0.88, 0.66).lerp(
			Color(0.52, 0.40, 0.68),
			inverse_lerp(960.0, 1080.0, minutes)
		)

	if minutes <= 1260.0:
		return Color(0.52, 0.40, 0.68).lerp(
			Color(0.25, 0.32, 0.55),
			inverse_lerp(1080.0, 1260.0, minutes)
		)

	return Color(0.25, 0.32, 0.55).lerp(
		Color(0.12, 0.17, 0.33),
		inverse_lerp(1260.0, 1440.0, minutes)
	)

func get_light_color(minutes: float) -> Color:
	if minutes < 1080.0:
		return Color(1.0, 0.86, 0.66)

	return Color(0.45, 0.58, 1.0)

func get_light_energy(minutes: float) -> float:
	if minutes <= 720.0:
		return lerpf(0.35, 0.95, inverse_lerp(360.0, 720.0, minutes))

	if minutes <= 1080.0:
		return lerpf(0.95, 0.20, inverse_lerp(720.0, 1080.0, minutes))

	return lerpf(0.20, 0.08, inverse_lerp(1080.0, 1440.0, minutes))
