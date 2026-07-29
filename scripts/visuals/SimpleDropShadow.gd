extends Node2D
class_name SimpleDropShadow

@export var shadow_offset: Vector2 = Vector2(0.0, 16.0)

# In this new version, base_width acts like the normal shadow length.
@export var base_width: float = 72.0
@export var base_height: float = 18.0
@export var base_alpha: float = 0.48

@export var dynamic_with_time: bool = true
@export var react_to_nightlights: bool = true

@export var nightlight_detection_radius: float = 320.0
@export var nightlight_min_alpha: float = 0.04
@export var nightlight_extra_length: float = 70.0

@export var minimum_visible_alpha: float = 0.04
@export var shadow_z_index: int = 0
@export var debug_force_visible: bool = false

const SHADOW_TEXTURE_WIDTH: int = 128
const SHADOW_TEXTURE_HEIGHT: int = 48

var shadow_sprite: Sprite2D = null
var time_manager: Node = null

func _ready() -> void:
	z_as_relative = true
	z_index = shadow_z_index

	_build_shadow_sprite()

	time_manager = get_tree().get_first_node_in_group("time_manager")

func _process(_delta: float) -> void:
	_update_shadow()

func _build_shadow_sprite() -> void:
	shadow_sprite = get_node_or_null("ShadowSprite") as Sprite2D

	if shadow_sprite == null:
		shadow_sprite = Sprite2D.new()
		shadow_sprite.name = "ShadowSprite"
		add_child(shadow_sprite)

	shadow_sprite.texture = _create_shadow_texture(
		SHADOW_TEXTURE_WIDTH,
		SHADOW_TEXTURE_HEIGHT
	)

	shadow_sprite.centered = true
	shadow_sprite.top_level = true
	shadow_sprite.z_as_relative = false
	shadow_sprite.z_index = shadow_z_index
	shadow_sprite.show_behind_parent = true

	_update_shadow()

func _update_shadow() -> void:
	if shadow_sprite == null:
		return

	var owner_node: Node2D = get_parent() as Node2D

	if owner_node == null:
		shadow_sprite.visible = false
		return

	var owner_position: Vector2 = owner_node.global_position
	var shadow_data: Dictionary = _get_shadow_data(owner_position)

	var shadow_direction: Vector2 = shadow_data.get(
		"direction",
		Vector2(0.35, 0.65).normalized()
	)

	var shadow_length: float = float(
		shadow_data.get("length", base_width)
	)

	var shadow_thickness: float = float(
		shadow_data.get("thickness", base_height)
	)

	var shadow_alpha: float = float(
		shadow_data.get("alpha", base_alpha)
	)

	if debug_force_visible:
		shadow_alpha = 0.85
		shadow_length = base_width + 60.0
		shadow_thickness = base_height + 6.0

	shadow_alpha = maxf(shadow_alpha, minimum_visible_alpha)
	shadow_alpha = clampf(shadow_alpha, 0.0, 0.90)

	if shadow_alpha <= 0.01:
		shadow_sprite.visible = false
		return

	shadow_sprite.visible = true

	# The shadow starts near the feet and stretches away from the light.
	var shadow_center: Vector2 = (
		owner_position
		+ shadow_offset
		+ shadow_direction * shadow_length * 0.36
	)

	shadow_sprite.global_position = shadow_center
	shadow_sprite.global_rotation = shadow_direction.angle()

	shadow_sprite.scale = Vector2(
		shadow_length / float(SHADOW_TEXTURE_WIDTH),
		shadow_thickness / float(SHADOW_TEXTURE_HEIGHT)
	)

	shadow_sprite.modulate = Color(
		0.0,
		0.0,
		0.0,
		shadow_alpha
	)

func _get_shadow_data(owner_position: Vector2) -> Dictionary:
	if _is_nighttime():
		return _get_night_shadow_data(owner_position)

	return _get_day_shadow_data()

func _get_day_shadow_data() -> Dictionary:
	var hour_float: float = _get_current_hour_float()

	# 06:00 to 18:00 mapped to 0.0 to 1.0
	var day_progress: float = clampf(
		(hour_float - 6.0) / 12.0,
		0.0,
		1.0
	)

	var morning_direction: Vector2 = Vector2(0.85, 0.55).normalized()
	var noon_direction: Vector2 = Vector2(0.15, 0.35).normalized()
	var evening_direction: Vector2 = Vector2(-0.85, 0.55).normalized()

	var shadow_direction: Vector2

	if day_progress < 0.5:
		var first_half_progress: float = day_progress / 0.5

		shadow_direction = morning_direction.lerp(
			noon_direction,
			first_half_progress
		).normalized()
	else:
		var second_half_progress: float = (
			(day_progress - 0.5) / 0.5
		)

		shadow_direction = noon_direction.lerp(
			evening_direction,
			second_half_progress
		).normalized()

	# Long shadows in morning/evening, short shadow near noon.
	var noon_distance: float = absf(day_progress - 0.5) * 2.0

	var shadow_length: float = lerpf(
		base_width * 0.42,
		base_width * 1.18,
		noon_distance
	)

	var shadow_thickness: float = lerpf(
		base_height * 0.75,
		base_height * 1.05,
		noon_distance
	)

	var shadow_alpha: float = base_alpha * lerpf(
		0.55,
		1.0,
		noon_distance
	)

	return {
		"direction": shadow_direction,
		"length": shadow_length,
		"thickness": shadow_thickness,
		"alpha": shadow_alpha
	}

func _get_night_shadow_data(owner_position: Vector2) -> Dictionary:
	if not react_to_nightlights:
		return {
			"direction": Vector2(0.35, 0.65).normalized(),
			"length": base_width * 0.35,
			"thickness": base_height * 0.70,
			"alpha": nightlight_min_alpha
		}

	var light_data: Dictionary = _get_nearest_active_nightlight(owner_position)

	if light_data.is_empty():
		return {
			"direction": Vector2(0.35, 0.65).normalized(),
			"length": base_width * 0.25,
			"thickness": base_height * 0.60,
			"alpha": 0.02
		}

	var light_position: Vector2 = light_data.get(
		"position",
		owner_position
	)

	var proximity: float = float(
		light_data.get("proximity", 0.0)
	)

	var shadow_direction: Vector2 = (
		owner_position - light_position
	)

	if shadow_direction.length() <= 0.01:
		shadow_direction = Vector2(0.4, 0.7)

	shadow_direction = shadow_direction.normalized()

	# Closer to a NightLight = clearer and longer cast shadow.
	var shadow_length: float = lerpf(
		base_width * 0.30,
		base_width + nightlight_extra_length,
		proximity
	)

	var shadow_thickness: float = lerpf(
		base_height * 0.70,
		base_height * 1.20,
		proximity
	)

	var shadow_alpha: float = lerpf(
		nightlight_min_alpha,
		base_alpha * 1.15,
		proximity
	)

	return {
		"direction": shadow_direction,
		"length": shadow_length,
		"thickness": shadow_thickness,
		"alpha": shadow_alpha
	}

func _get_nearest_active_nightlight(owner_position: Vector2) -> Dictionary:
	var best_data: Dictionary = {}
	var best_score: float = 0.0

	var nightlights: Array = get_tree().get_nodes_in_group("nightlight")

	for nightlight_variant in nightlights:
		var nightlight: Node2D = nightlight_variant as Node2D

		if nightlight == null:
			continue

		if not is_instance_valid(nightlight):
			continue

		var point_light: PointLight2D = (
			nightlight.get_node_or_null("PointLight2D")
			as PointLight2D
		)

		if point_light == null:
			continue

		if not point_light.enabled:
			continue

		if point_light.energy <= 0.01:
			continue

		var light_position: Vector2 = point_light.global_position
		var distance: float = owner_position.distance_to(light_position)

		var effective_radius: float = nightlight_detection_radius

		if "light_radius" in nightlight:
			effective_radius = maxf(
				nightlight_detection_radius,
				float(nightlight.get("light_radius")) * 120.0
			)

		if distance > effective_radius:
			continue

		var proximity: float = clampf(
			1.0 - (distance / effective_radius),
			0.0,
			1.0
		)

		var score: float = proximity * maxf(point_light.energy, 0.20)

		if score > best_score:
			best_score = score

			best_data = {
				"position": light_position,
				"distance": distance,
				"radius": effective_radius,
				"proximity": proximity,
				"energy": point_light.energy
			}

	return best_data

func _is_nighttime() -> bool:
	if time_manager == null:
		time_manager = get_tree().get_first_node_in_group("time_manager")

	if time_manager == null:
		return false

	if time_manager.has_method("is_nighttime"):
		return bool(time_manager.call("is_nighttime"))

	var hour_float: float = _get_current_hour_float()

	return hour_float >= 18.0 or hour_float < 6.0

func _get_current_hour_float() -> float:
	if time_manager == null:
		time_manager = get_tree().get_first_node_in_group("time_manager")

	if time_manager == null:
		return 12.0

	if time_manager.has_method("get_current_hour"):
		var hour: int = int(time_manager.call("get_current_hour"))
		var minute: int = 0

		if time_manager.has_method("get_current_minute"):
			minute = int(time_manager.call("get_current_minute"))
		elif "current_minute" in time_manager:
			minute = int(time_manager.get("current_minute"))

		return float(hour) + float(minute) / 60.0

	if "current_minutes" in time_manager:
		var current_minutes: int = int(
			time_manager.get("current_minutes")
		)

		return float(current_minutes) / 60.0

	if "current_hour" in time_manager:
		return float(time_manager.get("current_hour"))

	return 12.0

func _create_shadow_texture(width: int, height: int) -> Texture2D:
	var image: Image = Image.create(
		width,
		height,
		false,
		Image.FORMAT_RGBA8
	)

	var center: Vector2 = Vector2(
		float(width - 1) * 0.5,
		float(height - 1) * 0.5
	)

	var radius_x: float = float(width) * 0.5
	var radius_y: float = float(height) * 0.5

	for y in range(height):
		for x in range(width):
			var offset: Vector2 = Vector2(x, y) - center

			var normalized_distance: float = sqrt(
				pow(offset.x / radius_x, 2.0)
				+ pow(offset.y / radius_y, 2.0)
			)

			var alpha: float = 1.0 - normalized_distance

			alpha = clampf(alpha, 0.0, 1.0)
			alpha = pow(alpha, 1.55)

			image.set_pixel(
				x,
				y,
				Color(0.0, 0.0, 0.0, alpha)
			)

	var texture: ImageTexture = ImageTexture.create_from_image(image)

	return texture
