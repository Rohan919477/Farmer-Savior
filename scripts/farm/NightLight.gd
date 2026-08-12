extends Node2D
class_name NightLight

const REPAIR_RANGE: float = 42.0
const REPAIR_PROMPT_OFFSET: Vector2 = Vector2(-56.0, -48.0)

@export var light_radius: float = 8.0
@export var light_energy: float = 2.2
@export var flicker_enabled: bool = true
@export var flicker_strength: float = 0.06
@export var flicker_speed: float = 5.0

@export var show_health_bar_when_full: bool = true
@export var health_bar_size: Vector2 = Vector2(26.0, 4.0)
@export var health_bar_offset: Vector2 = Vector2(0.0, -30.0)

var defense_manager: Node = null
var nightlight_key: String = ""
var nightlight_state: String = "perfect"

var current_integrity: float = 100.0
var max_integrity: float = 100.0

var body_sprite: Sprite2D = null
var glow_sprite: Sprite2D = null
var shadow_polygon: Polygon2D = null
var point_light: PointLight2D = null

var health_bar_root: Node2D = null
var health_bar_back: Polygon2D = null
var health_bar_fill: Polygon2D = null
var health_bar_border: Line2D = null

var repair_area: Area2D = null
var repair_area_shape: CollisionShape2D = null
var repair_prompt: Label = null
var player_in_repair_range: Node = null
var repair_debug_session_active: bool = false

var base_energy: float = 1.35
var flicker_time: float = 0.0

func _ready() -> void:
	add_to_group("nightlight")
	add_to_group("farm_defenses")
	add_to_group("attackable_placeables")
	add_to_group("field_repairable")
	_build_runtime_nodes()
	_build_health_bar_nodes()
	_build_repair_nodes()

	base_energy = light_energy
	max_integrity = _get_max_integrity_from_manager()
	current_integrity = max_integrity

	if point_light != null:
		point_light.enabled = true
		point_light.energy = light_energy
		point_light.texture_scale = light_radius
		point_light.color = Color(1.0, 0.72, 0.32, 1.0)

	_refresh_condition_from_manager()
	_apply_state_visuals()
	_update_health_bar()

func _process(delta: float) -> void:
	_refresh_condition_from_manager()
	_position_world_ui()
	_update_health_bar()
	_update_repair_prompt()

	if _can_repair_now() and Input.is_action_pressed("repair_fence"):
		_repair_while_holding(delta)
	else:
		repair_debug_session_active = false

	if nightlight_state == "broken":
		return

	if not flicker_enabled:
		return

	if point_light == null:
		return

	flicker_time += delta * flicker_speed

	var wear_ratio: float = _get_integrity_ratio()
	var state_energy_multiplier: float = _get_light_strength_multiplier(wear_ratio)

	var wave_a: float = sin(flicker_time) * flicker_strength
	var wave_b: float = sin(flicker_time * 2.37) * flicker_strength * 0.45

	point_light.energy = (
		base_energy * state_energy_multiplier
		+ wave_a
		+ wave_b
	)

	if glow_sprite != null:
		var glow_alpha: float = clampf(
			0.42 * state_energy_multiplier + wave_a + wave_b,
			0.16,
			0.62
		)

		glow_sprite.modulate = Color(1.0, 0.68, 0.24, glow_alpha)

func configure_nightlight(
	new_defense_manager: Node,
	new_nightlight_key: String
) -> void:
	defense_manager = new_defense_manager
	nightlight_key = new_nightlight_key

	max_integrity = _get_max_integrity_from_manager()
	_refresh_condition_from_manager()
	_apply_state_visuals()
	_update_health_bar()

func set_nightlight_state(new_state: String) -> void:
	nightlight_state = new_state
	_apply_state_visuals()
	_update_health_bar()

func set_light_enabled(enabled: bool) -> void:
	if point_light != null:
		point_light.enabled = enabled

	if glow_sprite != null:
		glow_sprite.visible = enabled


func is_broken() -> bool:
	if defense_manager == null or nightlight_key.is_empty():
		return nightlight_state == "broken"

	if defense_manager.has_method("get_nightlight_state"):
		return str(
			defense_manager.call(
				"get_nightlight_state",
				nightlight_key
			)
		) == "broken"

	return nightlight_state == "broken"


func can_be_targeted_by_enemy() -> bool:
	return not is_broken()


func get_target_position() -> Vector2:
	return global_position


func take_damage(damage_amount: float) -> void:
	if damage_amount <= 0.0:
		return

	if defense_manager == null or nightlight_key.is_empty():
		return

	if is_broken():
		return

	if not defense_manager.has_method("damage_nightlight_integrity"):
		return

	defense_manager.call(
		"damage_nightlight_integrity",
		nightlight_key,
		damage_amount
	)

	_refresh_condition_from_manager()
	_apply_state_visuals()
	_update_health_bar()

func _refresh_condition_from_manager() -> void:
	if defense_manager == null:
		return

	if nightlight_key.is_empty():
		return

	max_integrity = _get_max_integrity_from_manager()

	if defense_manager.has_method("get_nightlight_current_integrity"):
		current_integrity = float(
			defense_manager.call(
				"get_nightlight_current_integrity",
				nightlight_key
			)
		)

	var previous_state: String = nightlight_state

	if defense_manager.has_method("get_nightlight_state"):
		nightlight_state = str(
			defense_manager.call(
				"get_nightlight_state",
				nightlight_key
			)
		)
	else:
		if current_integrity <= 0.0:
			nightlight_state = "broken"
		elif current_integrity < max_integrity:
			nightlight_state = "damaged"
		else:
			nightlight_state = "perfect"

	if previous_state != nightlight_state:
		_apply_state_visuals()

func _get_max_integrity_from_manager() -> float:
	if defense_manager == null:
		return max_integrity

	if "nightlight_max_integrity" in defense_manager:
		return float(defense_manager.get("nightlight_max_integrity"))

	return max_integrity

func _get_integrity_ratio() -> float:
	if max_integrity <= 0.0:
		return 0.0

	return clampf(current_integrity / max_integrity, 0.0, 1.0)

func _apply_state_visuals() -> void:
	if nightlight_state == "broken":
		set_light_enabled(false)

		if body_sprite != null:
			body_sprite.modulate = Color(0.45, 0.42, 0.38, 1.0)

		if shadow_polygon != null:
			shadow_polygon.color = Color(0.0, 0.0, 0.0, 0.22)

		return

	set_light_enabled(true)

	if nightlight_state == "damaged":
		# Keep almost-full NightLights visually strong. The lamp should only
		# look meaningfully weaker once integrity has dropped a noticeable amount.
		base_energy = light_energy

		if body_sprite != null:
			body_sprite.modulate = Color(0.96, 0.88, 0.72, 1.0)

		if glow_sprite != null:
			glow_sprite.modulate = Color(1.0, 0.62, 0.20, 0.40)

		return

	base_energy = light_energy

	if body_sprite != null:
		body_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)

	if glow_sprite != null:
		glow_sprite.modulate = Color(1.0, 0.68, 0.24, 0.42)

func _build_runtime_nodes() -> void:
	shadow_polygon = get_node_or_null("Shadow") as Polygon2D

	if shadow_polygon == null:
		shadow_polygon = Polygon2D.new()
		shadow_polygon.name = "Shadow"
		add_child(shadow_polygon)

	shadow_polygon.polygon = PackedVector2Array([
		Vector2(-10.0, 7.0),
		Vector2(10.0, 7.0),
		Vector2(14.0, 12.0),
		Vector2(-14.0, 12.0)
	])

	shadow_polygon.color = Color(0.0, 0.0, 0.0, 0.34)
	shadow_polygon.z_index = -2

	body_sprite = get_node_or_null("Body") as Sprite2D

	if body_sprite == null:
		body_sprite = Sprite2D.new()
		body_sprite.name = "Body"
		add_child(body_sprite)

	body_sprite.texture = _create_body_texture()
	body_sprite.centered = true
	body_sprite.position = Vector2(0.0, -4.0)
	body_sprite.z_index = 2

	glow_sprite = get_node_or_null("GlowCore") as Sprite2D

	if glow_sprite == null:
		glow_sprite = Sprite2D.new()
		glow_sprite.name = "GlowCore"
		add_child(glow_sprite)

	glow_sprite.texture = _create_glow_core_texture()
	glow_sprite.centered = true
	glow_sprite.position = Vector2(0.0, -8.0)
	glow_sprite.modulate = Color(1.0, 0.68, 0.24, 0.42)
	glow_sprite.z_index = 1

	point_light = get_node_or_null("PointLight2D") as PointLight2D

	if point_light == null:
		point_light = PointLight2D.new()
		point_light.name = "PointLight2D"
		add_child(point_light)

	point_light.position = Vector2(0.0, -8.0)
	point_light.texture = _create_light_texture(128)
	point_light.shadow_enabled = false

func _build_health_bar_nodes() -> void:
	health_bar_root = get_node_or_null("HealthBar") as Node2D

	if health_bar_root == null:
		health_bar_root = Node2D.new()
		health_bar_root.name = "HealthBar"
		add_child(health_bar_root)

	health_bar_root.position = health_bar_offset
	health_bar_root.z_index = 20

	health_bar_back = health_bar_root.get_node_or_null("Back") as Polygon2D

	if health_bar_back == null:
		health_bar_back = Polygon2D.new()
		health_bar_back.name = "Back"
		health_bar_root.add_child(health_bar_back)

	health_bar_back.polygon = _make_rect_polygon(
		health_bar_size.x + 4.0,
		health_bar_size.y + 4.0,
		1.0
	)
	health_bar_back.color = Color(0.025, 0.018, 0.014, 0.92)
	health_bar_back.z_index = 0

	health_bar_fill = health_bar_root.get_node_or_null("Fill") as Polygon2D

	if health_bar_fill == null:
		health_bar_fill = Polygon2D.new()
		health_bar_fill.name = "Fill"
		health_bar_root.add_child(health_bar_fill)

	health_bar_fill.z_index = 1

	health_bar_border = health_bar_root.get_node_or_null("Border") as Line2D

	if health_bar_border == null:
		health_bar_border = Line2D.new()
		health_bar_border.name = "Border"
		health_bar_root.add_child(health_bar_border)

	var border_width: float = health_bar_size.x + 4.0
	var border_height: float = health_bar_size.y + 4.0

	health_bar_border.points = PackedVector2Array([
		Vector2(-border_width * 0.5, -border_height * 0.5),
		Vector2(border_width * 0.5, -border_height * 0.5),
		Vector2(border_width * 0.5, border_height * 0.5),
		Vector2(-border_width * 0.5, border_height * 0.5),
		Vector2(-border_width * 0.5, -border_height * 0.5)
	])

	health_bar_border.width = 1.0
	health_bar_border.default_color = Color(0.11, 0.07, 0.035, 1.0)
	health_bar_border.z_index = 2

func _build_repair_nodes() -> void:
	repair_area = get_node_or_null("RepairArea") as Area2D

	if repair_area == null:
		repair_area = Area2D.new()
		repair_area.name = "RepairArea"
		add_child(repair_area)

	repair_area_shape = (
		repair_area.get_node_or_null("CollisionShape2D")
		as CollisionShape2D
	)

	if repair_area_shape == null:
		repair_area_shape = CollisionShape2D.new()
		repair_area_shape.name = "CollisionShape2D"
		repair_area.add_child(repair_area_shape)

	var circle_shape: CircleShape2D = (
		repair_area_shape.shape as CircleShape2D
	)

	if circle_shape == null:
		circle_shape = CircleShape2D.new()
		repair_area_shape.shape = circle_shape

	circle_shape.radius = REPAIR_RANGE

	repair_area.collision_layer = 0
	repair_area.collision_mask = 1
	repair_area.monitoring = true
	repair_area.monitorable = false

	if not repair_area.body_entered.is_connected(
		_on_repair_area_body_entered
	):
		repair_area.body_entered.connect(
			_on_repair_area_body_entered
		)

	if not repair_area.body_exited.is_connected(
		_on_repair_area_body_exited
	):
		repair_area.body_exited.connect(
			_on_repair_area_body_exited
		)

	repair_prompt = get_node_or_null("RepairPrompt") as Label

	if repair_prompt == null:
		repair_prompt = Label.new()
		repair_prompt.name = "RepairPrompt"
		add_child(repair_prompt)

	repair_prompt.visible = false
	repair_prompt.z_index = 30
	repair_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repair_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	repair_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	repair_prompt.size = Vector2(120.0, 34.0)
	repair_prompt.add_theme_color_override(
		"font_color",
		Color(1.0, 0.83, 0.46, 1.0)
	)
	repair_prompt.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.92)
	)
	repair_prompt.add_theme_constant_override("shadow_offset_x", 1)
	repair_prompt.add_theme_constant_override("shadow_offset_y", 1)

func _position_world_ui() -> void:
	if health_bar_root != null:
		health_bar_root.global_position = global_position + health_bar_offset
		health_bar_root.global_rotation = 0.0

	if repair_prompt != null:
		repair_prompt.global_position = global_position + REPAIR_PROMPT_OFFSET
		repair_prompt.rotation = 0.0

func can_be_field_repair_candidate(player_node: Node) -> bool:
	return (
		nightlight_state == "damaged"
		and player_in_repair_range == player_node
		and _is_daytime()
		and not _is_gameplay_input_blocked()
	)

func _can_repair_now() -> bool:
	if player_in_repair_range == null:
		return false

	if not can_be_field_repair_candidate(player_in_repair_range):
		return false

	if defense_manager != null and defense_manager.has_method(
		"is_primary_field_repair_target"
	):
		return bool(
			defense_manager.call(
				"is_primary_field_repair_target",
				self,
				player_in_repair_range
			)
		)

	return true

func _update_repair_prompt() -> void:
	if repair_prompt == null:
		return

	var should_show_prompt: bool = _can_repair_now()
	repair_prompt.visible = should_show_prompt

	if not should_show_prompt:
		return

	if Input.is_action_pressed("repair_fence"):
		return

	if defense_manager != null and defense_manager.has_method(
		"is_nightlight_repair_cost_paid"
	):
		if bool(
			defense_manager.call(
				"is_nightlight_repair_cost_paid",
				nightlight_key
			)
		):
			repair_prompt.text = "Fix NightLight (Hold F)"
			return

	repair_prompt.text = (
		"Fix NightLight (Hold F)\nScrap: %d"
		% _get_damaged_repair_cost()
	)

func _repair_while_holding(delta: float) -> void:
	if defense_manager == null:
		return

	if nightlight_key.is_empty():
		return

	if not defense_manager.has_method("repair_nightlight"):
		return

	var repair_cost_was_paid: bool = false

	if defense_manager.has_method("is_nightlight_repair_cost_paid"):
		repair_cost_was_paid = bool(
			defense_manager.call(
				"is_nightlight_repair_cost_paid",
				nightlight_key
			)
		)

	if not repair_cost_was_paid:
		var repair_cost: int = _get_damaged_repair_cost()

		if repair_cost > 0:
			if player_in_repair_range == null:
				return

			if not player_in_repair_range.has_method("spend_resource"):
				return

			var spent_successfully: bool = bool(
				player_in_repair_range.call(
					"spend_resource",
					"scrap",
					repair_cost
				)
			)

			if not spent_successfully:
				repair_prompt.text = "Need %d Scrap" % repair_cost
				repair_debug_session_active = false
				return

		if defense_manager.has_method("mark_nightlight_repair_cost_paid"):
			defense_manager.call(
				"mark_nightlight_repair_cost_paid",
				nightlight_key
			)

	if not repair_debug_session_active:
		print(
			"[NightLight Repair] Started repairing ",
			nightlight_key,
			" | Current integrity: ",
			current_integrity,
			" | Max integrity: ",
			max_integrity
		)

		repair_debug_session_active = true

	repair_prompt.text = "Fixing NightLight..."

	defense_manager.call(
		"repair_nightlight",
		nightlight_key,
		_get_repair_rate() * delta
	)

	_refresh_condition_from_manager()
	_update_health_bar()

	if nightlight_state == "perfect":
		print(
			"[NightLight Repair] Completed repair for ",
			nightlight_key
		)
		repair_debug_session_active = false

func _get_damaged_repair_cost() -> int:
	if defense_manager == null:
		return 1

	if defense_manager.has_method("get_damaged_nightlight_repair_cost_scrap"):
		return int(
			defense_manager.call(
				"get_damaged_nightlight_repair_cost_scrap"
			)
		)

	if "damaged_nightlight_repair_cost_scrap" in defense_manager:
		return int(defense_manager.get("damaged_nightlight_repair_cost_scrap"))

	return 1

func _get_repair_rate() -> float:
	if defense_manager == null:
		return 20.0

	if defense_manager.has_method("get_nightlight_repair_rate_per_second"):
		return float(
			defense_manager.call(
				"get_nightlight_repair_rate_per_second"
			)
		)

	if "nightlight_repair_rate_per_second" in defense_manager:
		return float(defense_manager.get("nightlight_repair_rate_per_second"))

	return 20.0

func _is_daytime() -> bool:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager == null:
		return true

	if time_manager.has_method("is_nighttime"):
		return not bool(time_manager.call("is_nighttime"))

	return true

func _is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false

func _on_repair_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_repair_range = body

func _on_repair_area_body_exited(body: Node2D) -> void:
	if body == player_in_repair_range:
		player_in_repair_range = null
		repair_debug_session_active = false

func _update_health_bar() -> void:
	if health_bar_root == null or health_bar_fill == null:
		return

	var ratio: float = _get_integrity_ratio()

	if not show_health_bar_when_full:
		health_bar_root.visible = ratio < 0.999
	else:
		health_bar_root.visible = true

	var fill_width: float = maxf(1.0, health_bar_size.x * ratio)

	if ratio <= 0.0:
		fill_width = 0.0

	health_bar_fill.polygon = _make_left_aligned_rect_polygon(
		fill_width,
		health_bar_size.y,
		health_bar_size.x
	)

	health_bar_fill.color = _get_health_bar_colour(ratio)

func _make_rect_polygon(width: float, height: float, pixel_offset: float = 0.0) -> PackedVector2Array:
	var half_width: float = width * 0.5
	var half_height: float = height * 0.5

	return PackedVector2Array([
		Vector2(-half_width, -half_height),
		Vector2(half_width, -half_height),
		Vector2(half_width, half_height),
		Vector2(-half_width, half_height)
	])

func _make_left_aligned_rect_polygon(
	fill_width: float,
	height: float,
	full_width: float
) -> PackedVector2Array:
	var left_x: float = -full_width * 0.5
	var right_x: float = left_x + fill_width
	var half_height: float = height * 0.5

	return PackedVector2Array([
		Vector2(left_x, -half_height),
		Vector2(right_x, -half_height),
		Vector2(right_x, half_height),
		Vector2(left_x, half_height)
	])

func _get_health_bar_colour(ratio: float) -> Color:
	if ratio <= 0.0:
		return Color(0.22, 0.025, 0.018, 1.0)

	# Keep the bar yellow while the NightLight is mostly healthy.
	# It should not turn orange immediately after one tiny tick of wear.
	if ratio >= 0.75:
		return Color(0.95, 0.72, 0.20, 1.0)

	if ratio >= 0.35:
		return Color(0.86, 0.38, 0.12, 1.0)

	return Color(0.52, 0.055, 0.035, 1.0)

func _get_light_strength_multiplier(ratio: float) -> float:
	if nightlight_state == "broken":
		return 0.0

	# No visible weakening while the lamp is only lightly worn.
	if ratio >= 0.75:
		return 1.0

	# Below 75%, weaken smoothly. At very low integrity it becomes weak,
	# but not instantly useless before it fully breaks.
	var normalized_ratio: float = clampf(ratio / 0.75, 0.0, 1.0)
	return lerpf(0.55, 1.0, normalized_ratio)

func _create_body_texture() -> Texture2D:
	var image: Image = Image.create(20, 28, false, Image.FORMAT_RGBA8)

	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	for y in range(28):
		for x in range(20):
			var colour: Color = Color(0.0, 0.0, 0.0, 0.0)

			var in_stand: bool = (
				x >= 8
				and x <= 11
				and y >= 13
				and y <= 25
			)

			var in_base: bool = (
				x >= 5
				and x <= 14
				and y >= 24
				and y <= 26
			)

			var in_lamp_box: bool = (
				x >= 5
				and x <= 14
				and y >= 4
				and y <= 14
			)

			var in_top_cap: bool = (
				x >= 7
				and x <= 12
				and y >= 1
				and y <= 3
			)

			var in_handle: bool = (
				(
					x == 6
					or x == 13
				)
				and y >= 0
				and y <= 5
			)

			if in_stand or in_base or in_top_cap or in_handle:
				colour = Color(0.14, 0.10, 0.065, 1.0)

			if in_lamp_box:
				colour = Color(0.20, 0.13, 0.07, 1.0)

				if x >= 7 and x <= 12 and y >= 6 and y <= 12:
					colour = Color(0.95, 0.55, 0.16, 1.0)

				if x == 5 or x == 14 or y == 4 or y == 14:
					colour = Color(0.08, 0.055, 0.035, 1.0)

			if colour.a > 0.0:
				image.set_pixel(x, y, colour)

	var texture: ImageTexture = ImageTexture.create_from_image(image)

	return texture

func _create_glow_core_texture() -> Texture2D:
	var image: Image = Image.create(32, 32, false, Image.FORMAT_RGBA8)

	var center: Vector2 = Vector2(15.5, 15.5)

	for y in range(32):
		for x in range(32):
			var distance: float = Vector2(x, y).distance_to(center)
			var alpha: float = clampf(1.0 - distance / 16.0, 0.0, 1.0)

			alpha = pow(alpha, 1.7) * 0.75

			image.set_pixel(
				x,
				y,
				Color(1.0, 0.58, 0.16, alpha)
			)

	var texture: ImageTexture = ImageTexture.create_from_image(image)

	return texture

func _create_light_texture(texture_size: int) -> Texture2D:
	var image: Image = Image.create(
		texture_size,
		texture_size,
		false,
		Image.FORMAT_RGBA8
	)

	var center: Vector2 = Vector2(
		float(texture_size - 1) * 0.5,
		float(texture_size - 1) * 0.5
	)

	var radius: float = float(texture_size) * 0.5

	for y in range(texture_size):
		for x in range(texture_size):
			var distance: float = Vector2(x, y).distance_to(center)
			var normalized_distance: float = clampf(
				distance / radius,
				0.0,
				1.0
			)

			var alpha: float = 1.0 - normalized_distance
			alpha = pow(alpha, 2.2)

			image.set_pixel(
				x,
				y,
				Color(1.0, 1.0, 1.0, alpha)
			)

	var texture: ImageTexture = ImageTexture.create_from_image(image)

	return texture
