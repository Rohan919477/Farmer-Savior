extends Node2D
class_name WorldLightingManager

@onready var world_tint: CanvasModulate = $CanvasModulate
@onready var celestial_light: DirectionalLight2D = $DirectionalLight2D

@export var smooth_lighting_changes: bool = true
@export var smoothing_speed: float = 8.0

# Keep this false for normal gameplay. Turn it on only when tuning lighting.
@export var debug_lighting_prints: bool = false

var time_manager: Node = null

var target_ambient_tint: Color = Color.WHITE
var target_light_color: Color = Color.WHITE
var target_light_energy: float = 0.8
var target_light_rotation: float = 0.0

func _ready() -> void:
	add_to_group("world_lighting_manager")

	time_manager = get_tree().get_first_node_in_group("time_manager")

	if time_manager != null and time_manager.has_signal("time_changed"):
		if not time_manager.time_changed.is_connected(_on_time_changed):
			time_manager.time_changed.connect(_on_time_changed)

	force_update_lighting()

func _process(delta: float) -> void:
	if time_manager == null:
		time_manager = get_tree().get_first_node_in_group("time_manager")

	_calculate_lighting_targets()

	if not smooth_lighting_changes:
		_apply_targets_immediately()
		return

	var blend_amount: float = clampf(delta * smoothing_speed, 0.0, 1.0)

	if world_tint != null:
		world_tint.color = world_tint.color.lerp(
			target_ambient_tint,
			blend_amount
		)

	if celestial_light != null:
		celestial_light.color = celestial_light.color.lerp(
			target_light_color,
			blend_amount
		)

		celestial_light.energy = lerpf(
			celestial_light.energy,
			target_light_energy,
			blend_amount
		)

		celestial_light.rotation = lerp_angle(
			celestial_light.rotation,
			target_light_rotation,
			blend_amount
		)

func _on_time_changed(
	_day_number: int,
	_hour: int,
	_minute: int,
	_phase: String
) -> void:
	_calculate_lighting_targets()

func force_update_lighting() -> void:
	_calculate_lighting_targets()
	_apply_targets_immediately()

func _apply_targets_immediately() -> void:
	if world_tint != null:
		world_tint.color = target_ambient_tint

	if celestial_light != null:
		celestial_light.enabled = true
		celestial_light.color = target_light_color
		celestial_light.energy = target_light_energy
		celestial_light.rotation = target_light_rotation

func _calculate_lighting_targets() -> void:
	var current_minutes: float = _get_current_minutes()

	target_ambient_tint = get_ambient_tint(current_minutes)
	target_light_color = get_light_color(current_minutes)
	target_light_energy = get_light_energy(current_minutes)
	target_light_rotation = get_sun_rotation(current_minutes)

	if debug_lighting_prints:
		print(
			"[Lighting] ",
			_get_time_text(),
			" | Tint: ",
			target_ambient_tint,
			" | Energy: ",
			target_light_energy
		)

func _get_current_minutes() -> float:
	if time_manager == null:
		return 720.0

	if time_manager.has_method("get_current_minutes"):
		return float(time_manager.call("get_current_minutes"))

	return 720.0

func _get_time_text() -> String:
	if time_manager != null and time_manager.has_method("get_time_text"):
		return str(time_manager.call("get_time_text"))

	var minutes: int = int(_get_current_minutes())
	return "%02d:%02d" % [
		int(minutes / 60.0) % 24,
		minutes % 60
	]

# -------------------------------------------------------------------
# Lighting curve
# -------------------------------------------------------------------

func get_ambient_tint(minutes: float) -> Color:
	minutes = clampf(minutes, 360.0, 1440.0)

	# 06:00 - 08:30: cold blue dawn into weak morning.
	if minutes <= 510.0:
		return Color(0.48, 0.55, 0.70, 1.0).lerp(
			Color(0.78, 0.73, 0.58, 1.0),
			_smooth_inverse_lerp(360.0, 510.0, minutes)
		)

	# 08:30 - 12:00: readable but still slightly dirty daylight.
	if minutes <= 720.0:
		return Color(0.78, 0.73, 0.58, 1.0).lerp(
			Color(0.96, 0.93, 0.78, 1.0),
			_smooth_inverse_lerp(510.0, 720.0, minutes)
		)

	# 12:00 - 15:30: bright day slowly dries into yellow-brown farm heat.
	if minutes <= 930.0:
		return Color(0.96, 0.93, 0.78, 1.0).lerp(
			Color(0.86, 0.71, 0.50, 1.0),
			_smooth_inverse_lerp(720.0, 930.0, minutes)
		)

	# 15:30 - 17:40: sunset warning, sick orange/brown.
	if minutes <= 1060.0:
		return Color(0.86, 0.71, 0.50, 1.0).lerp(
			Color(0.54, 0.33, 0.31, 1.0),
			_smooth_inverse_lerp(930.0, 1060.0, minutes)
		)

	# 17:40 - 18:00: fast drop into night danger.
	if minutes <= 1080.0:
		return Color(0.54, 0.33, 0.31, 1.0).lerp(
			Color(0.22, 0.20, 0.32, 1.0),
			_smooth_inverse_lerp(1060.0, 1080.0, minutes)
		)

	# 18:00 - 21:00: playable dark blue night.
	if minutes <= 1260.0:
		return Color(0.22, 0.20, 0.32, 1.0).lerp(
			Color(0.09, 0.105, 0.18, 1.0),
			_smooth_inverse_lerp(1080.0, 1260.0, minutes)
		)

	# 21:00 - 24:00: deepest night, lamps become very important.
	return Color(0.09, 0.105, 0.18, 1.0).lerp(
		Color(0.035, 0.045, 0.075, 1.0),
		_smooth_inverse_lerp(1260.0, 1440.0, minutes)
	)

func get_light_color(minutes: float) -> Color:
	minutes = clampf(minutes, 360.0, 1440.0)

	if minutes <= 720.0:
		return Color(0.95, 0.78, 0.52, 1.0).lerp(
			Color(1.0, 0.88, 0.62, 1.0),
			_smooth_inverse_lerp(360.0, 720.0, minutes)
		)

	if minutes <= 1060.0:
		return Color(1.0, 0.88, 0.62, 1.0).lerp(
			Color(1.0, 0.44, 0.24, 1.0),
			_smooth_inverse_lerp(720.0, 1060.0, minutes)
		)

	if minutes <= 1080.0:
		return Color(1.0, 0.44, 0.24, 1.0).lerp(
			Color(0.40, 0.52, 0.95, 1.0),
			_smooth_inverse_lerp(1060.0, 1080.0, minutes)
		)

	return Color(0.40, 0.52, 0.95, 1.0).lerp(
		Color(0.22, 0.30, 0.55, 1.0),
		_smooth_inverse_lerp(1080.0, 1440.0, minutes)
	)

func get_light_energy(minutes: float) -> float:
	minutes = clampf(minutes, 360.0, 1440.0)

	if minutes <= 720.0:
		return lerpf(
			0.35,
			0.95,
			_smooth_inverse_lerp(360.0, 720.0, minutes)
		)

	if minutes <= 1060.0:
		return lerpf(
			0.95,
			0.25,
			_smooth_inverse_lerp(720.0, 1060.0, minutes)
		)

	if minutes <= 1080.0:
		return lerpf(
			0.25,
			0.08,
			_smooth_inverse_lerp(1060.0, 1080.0, minutes)
		)

	return lerpf(
		0.08,
		0.025,
		_smooth_inverse_lerp(1080.0, 1440.0, minutes)
	)

func get_sun_rotation(minutes: float) -> float:
	var cycle_progress: float = _smooth_inverse_lerp(
		360.0,
		1440.0,
		clampf(minutes, 360.0, 1440.0)
	)

	return deg_to_rad(lerpf(-42.0, 218.0, cycle_progress))

# -------------------------------------------------------------------
# Shadow helpers used by optional drop-shadow scripts
# -------------------------------------------------------------------

func get_shadow_alpha_multiplier() -> float:
	var minutes: float = _get_current_minutes()

	if minutes <= 720.0:
		return lerpf(
			0.45,
			1.0,
			_smooth_inverse_lerp(360.0, 720.0, minutes)
		)

	if minutes <= 1080.0:
		return lerpf(
			1.0,
			0.38,
			_smooth_inverse_lerp(720.0, 1080.0, minutes)
		)

	return lerpf(
		0.38,
		0.12,
		_smooth_inverse_lerp(1080.0, 1440.0, minutes)
	)

func get_shadow_length_multiplier() -> float:
	var minutes: float = _get_current_minutes()

	# Long shadows near morning/evening, shortest around noon.
	var noon_distance: float = abs(minutes - 720.0) / 720.0

	return lerpf(
		0.75,
		1.85,
		clampf(noon_distance, 0.0, 1.0)
	)

func get_shadow_rotation() -> float:
	return get_sun_rotation(_get_current_minutes()) + PI

func is_deep_night() -> bool:
	return _get_current_minutes() >= 1260.0

func get_lighting_context() -> Dictionary:
	var current_minutes: float = _get_current_minutes()

	return {
		"time_text": _get_time_text(),
		"minutes": current_minutes,
		"ambient_tint": get_ambient_tint(current_minutes),
		"light_color": get_light_color(current_minutes),
		"light_energy": get_light_energy(current_minutes),
		"shadow_alpha_multiplier": get_shadow_alpha_multiplier(),
		"shadow_length_multiplier": get_shadow_length_multiplier(),
		"shadow_rotation": get_shadow_rotation(),
		"is_deep_night": is_deep_night()
	}

func _smooth_inverse_lerp(
	minimum_value: float,
	maximum_value: float,
	value: float
) -> float:
	if is_equal_approx(minimum_value, maximum_value):
		return 0.0

	var t: float = inverse_lerp(minimum_value, maximum_value, value)
	t = clampf(t, 0.0, 1.0)

	return t * t * (3.0 - 2.0 * t)
