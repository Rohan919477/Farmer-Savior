extends Node2D
class_name PesticideTurret

const ANIM_IDLE: StringName = "idle"
const ANIM_FIRE: StringName = "fire"
const ANIM_DAMAGED_IDLE: StringName = "damagedIdle"
const ANIM_BROKEN: StringName = "broken"

@export_group("Combat")
@export var attack_damage: int = 8
@export var attack_interval: float = 1.0
@export var attack_range: float = 180.0
@export var durability_cost_per_attack: float = 1.0

@export_group("Animation")
@export var fire_frame_time: float = 0.12

@export_group("Health Bar")
@export var show_health_bar_always: bool = true

@export_group("Repair and Collision")
@export var repair_range: float = 44.0
@export var visual_scale: float = 0.04
@export var blocker_size: Vector2 = Vector2(26.0, 22.0)
@export var blocker_offset: Vector2 = Vector2(0.0, 8.0)
@export var repair_prompt_offset: Vector2 = Vector2(-72.0, -64.0)
@export var health_bar_position: Vector2 = Vector2(-32.0, -45.0)
@export var health_bar_size: Vector2 = Vector2(64.0, 12.0)

@onready var range_area: Area2D = $RangeArea
@onready var turret_sprite: AnimatedSprite2D = $BodySprite
@onready var health_bar: ProgressBar = $HealthBar
@onready var repair_area: Area2D = get_node_or_null("RepairArea") as Area2D
@onready var repair_area_shape: CollisionShape2D = (
	get_node_or_null("RepairArea/CollisionShape2D") as CollisionShape2D
)
@onready var repair_prompt: Label = get_node_or_null("RepairPrompt") as Label
@onready var blocker: StaticBody2D = get_node_or_null("Blocker") as StaticBody2D
@onready var blocker_shape: CollisionShape2D = (
	get_node_or_null("Blocker/CollisionShape2D") as CollisionShape2D
)

var enemies_in_range: Array[Node2D] = []
var attack_cooldown: float = 0.0

var defense_manager: DefenseManager = null
var turret_key: String = ""
var turret_state: String = "perfect"

var base_modulate: Color = Color.WHITE
var visual_token: int = 0
var player_in_repair_range: Node = null
var repair_debug_session_active: bool = false
var repair_hold_cost_paid: bool = false
var blocker_enable_pending_until_player_clear: bool = false


func _ready() -> void:
	add_to_group("farm_defenses")
	add_to_group("attackable_placeables")
	add_to_group("field_repairable")

	base_modulate = turret_sprite.modulate

	_setup_visual_layout()
	_setup_physical_blocker()
	_setup_repair_area()

	if not range_area.body_entered.is_connected(_on_range_area_body_entered):
		range_area.body_entered.connect(_on_range_area_body_entered)

	if not range_area.body_exited.is_connected(_on_range_area_body_exited):
		range_area.body_exited.connect(_on_range_area_body_exited)

	_configure_animation_settings()
	_setup_health_bar()
	_apply_condition_visual()
	_update_health_bar()
	_update_repair_prompt()


func configure_turret(
	new_defense_manager: DefenseManager,
	new_turret_key: String
) -> void:
	defense_manager = new_defense_manager
	turret_key = new_turret_key

	if not defense_manager.turret_condition_changed.is_connected(
		_on_turret_condition_changed
	):
		defense_manager.turret_condition_changed.connect(
			_on_turret_condition_changed
		)

	_refresh_from_manager(true)


func _process(delta: float) -> void:
	_update_pending_blocker_enable()
	_position_world_ui()
	_update_repair_prompt()

	var repair_input_held: bool = Input.is_action_pressed("repair_fence")

	if _can_repair_now() and repair_input_held:
		_repair_while_holding(delta)
	else:
		repair_debug_session_active = false

	if not repair_input_held:
		repair_hold_cost_paid = false


func _setup_visual_layout() -> void:
	# The generated turret frames are 1024 x 1536. At 0.1 scale they become
	# visually larger than one farm grid cell and cover nearby fence edges.
	# Keep the object readable, but make it behave like a one-cell defense.
	if turret_sprite != null:
		turret_sprite.scale = Vector2(visual_scale, visual_scale)
		turret_sprite.position = Vector2.ZERO
		turret_sprite.z_index = 0

	z_index = 0

	if health_bar != null:
		health_bar.position = health_bar_position
		health_bar.size = health_bar_size
		health_bar.z_index = 30

	if repair_prompt != null:
		repair_prompt.visible = false
		repair_prompt.z_index = 31
		repair_prompt.size = Vector2(150.0, 38.0)
		repair_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		repair_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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


func _setup_physical_blocker() -> void:
	if blocker == null:
		blocker = StaticBody2D.new()
		blocker.name = "Blocker"
		add_child(blocker)

	if blocker_shape == null:
		blocker_shape = blocker.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

	if blocker_shape == null:
		blocker_shape = CollisionShape2D.new()
		blocker_shape.name = "CollisionShape2D"
		blocker.add_child(blocker_shape)

	var rectangle_shape: RectangleShape2D = (
		blocker_shape.shape as RectangleShape2D
	)

	if rectangle_shape == null:
		rectangle_shape = RectangleShape2D.new()
		blocker_shape.shape = rectangle_shape

	rectangle_shape.size = blocker_size
	blocker_shape.position = blocker_offset

	# Same blocker layer used by fences.
	# Player and enemies already collide with this layer.
	blocker.collision_layer = 4
	blocker.collision_mask = 0


func _setup_repair_area() -> void:
	if repair_area == null:
		repair_area = Area2D.new()
		repair_area.name = "RepairArea"
		add_child(repair_area)

	if repair_area_shape == null:
		repair_area_shape = repair_area.get_node_or_null(
			"CollisionShape2D"
		) as CollisionShape2D

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

	circle_shape.radius = repair_range

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

	if repair_prompt == null:
		repair_prompt = Label.new()
		repair_prompt.name = "RepairPrompt"
		add_child(repair_prompt)


func _position_world_ui() -> void:
	if health_bar != null:
		health_bar.global_position = global_position + health_bar_position
		health_bar.rotation = 0.0

	if repair_prompt != null:
		repair_prompt.global_position = global_position + repair_prompt_offset
		repair_prompt.rotation = 0.0


func can_be_field_repair_candidate(player_node: Node) -> bool:
	return (
		turret_state != DefenseManager.PLACEABLE_STATE_PERFECT
		and player_in_repair_range == player_node
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
		"is_pesticide_turret_repair_cost_paid"
	):
		if bool(
			defense_manager.call(
				"is_pesticide_turret_repair_cost_paid",
				turret_key
			)
		):
			repair_prompt.text = "Fix Turret (Hold F)"
			return

	var repair_cost: int = _get_repair_cost()

	if turret_state == DefenseManager.PLACEABLE_STATE_BROKEN:
		repair_prompt.text = (
			"Rebuild Turret (Hold F)\nScrap: %d"
			% repair_cost
		)
	else:
		repair_prompt.text = (
			"Fix Turret (Hold F)\nScrap: %d"
			% repair_cost
		)


func _repair_while_holding(delta: float) -> void:
	if defense_manager == null:
		return

	if turret_key.is_empty():
		return

	if not defense_manager.has_method("repair_pesticide_turret"):
		return

	var repair_cost_was_paid: bool = false

	if defense_manager.has_method("is_pesticide_turret_repair_cost_paid"):
		repair_cost_was_paid = bool(
			defense_manager.call(
				"is_pesticide_turret_repair_cost_paid",
				turret_key
			)
		)

	if repair_cost_was_paid:
		repair_hold_cost_paid = true

	if not repair_cost_was_paid and not repair_hold_cost_paid:
		var repair_cost: int = _get_repair_cost()

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

		repair_hold_cost_paid = true

		if defense_manager.has_method(
			"mark_pesticide_turret_repair_cost_paid"
		):
			defense_manager.call(
				"mark_pesticide_turret_repair_cost_paid",
				turret_key
			)

	if not repair_debug_session_active:
		print(
			"[Pesticide Turret Repair] Started repairing ",
			turret_key
		)
		repair_debug_session_active = true

	repair_prompt.text = "Fixing Turret..."

	defense_manager.call(
		"repair_pesticide_turret",
		turret_key,
		_get_repair_rate() * delta
	)

	_refresh_from_manager(false)
	_update_health_bar()

	if turret_state == DefenseManager.PLACEABLE_STATE_PERFECT:
		print(
			"[Pesticide Turret Repair] Completed repair for ",
			turret_key
		)
		repair_debug_session_active = false


func _get_repair_cost() -> int:
	if defense_manager == null:
		return 1

	if defense_manager.has_method(
		"get_pesticide_turret_repair_cost_scrap"
	):
		return int(
			defense_manager.call(
				"get_pesticide_turret_repair_cost_scrap",
				turret_key
			)
		)

	if turret_state == DefenseManager.PLACEABLE_STATE_BROKEN:
		if defense_manager.has_method(
			"get_broken_pesticide_turret_repair_cost_scrap"
		):
			return int(
				defense_manager.call(
					"get_broken_pesticide_turret_repair_cost_scrap"
				)
			)

	if defense_manager.has_method(
		"get_damaged_pesticide_turret_repair_cost_scrap"
	):
		return int(
			defense_manager.call(
				"get_damaged_pesticide_turret_repair_cost_scrap"
			)
		)

	return 1

func _get_repair_rate() -> float:
	if defense_manager == null:
		return 20.0

	if defense_manager.has_method("get_pesticide_turret_repair_rate_per_second"):
		return float(
			defense_manager.call(
				"get_pesticide_turret_repair_rate_per_second"
			)
		)

	if "pesticide_turret_repair_rate_per_second" in defense_manager:
		return float(
			defense_manager.get("pesticide_turret_repair_rate_per_second")
		)

	return 20.0


func _is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false


func _physics_process(delta: float) -> void:
	if is_broken():
		return

	if not is_nighttime():
		return

	attack_cooldown -= delta

	if attack_cooldown > 0.0:
		return

	var target: Node2D = get_nearest_enemy()

	if target == null:
		return

	if not target.has_method("take_damage"):
		return

	target.call("take_damage", attack_damage)

	attack_cooldown = attack_interval

	if defense_manager != null and not turret_key.is_empty():
		defense_manager.consume_pesticide_turret_durability(
			turret_key,
			durability_cost_per_attack
		)

	_play_audio_sfx("turret_fire")
	show_spray_feedback()

	print(
		"Pesticide Turret sprayed ",
		target.name,
		" for ",
		attack_damage,
		" poison damage."
	)


func is_broken() -> bool:
	if defense_manager == null or turret_key.is_empty():
		return false

	return (
		defense_manager.get_turret_state(turret_key)
		== DefenseManager.PLACEABLE_STATE_BROKEN
	)


func can_be_targeted_by_enemy() -> bool:
	return not is_broken()


func get_target_position() -> Vector2:
	return global_position


func take_damage(damage_amount: float) -> void:
	if defense_manager == null or turret_key.is_empty():
		return

	defense_manager.damage_pesticide_turret_integrity(
		turret_key,
		damage_amount
	)

	_update_health_bar()


func _refresh_from_manager(force_visual_update: bool = false) -> void:
	if defense_manager == null or turret_key.is_empty():
		return

	var previous_state: String = turret_state
	turret_state = defense_manager.get_turret_state(turret_key)

	var is_currently_broken: bool = (
		turret_state == DefenseManager.PLACEABLE_STATE_BROKEN
	)

	range_area.set_deferred("monitoring", not is_currently_broken)

	# A broken turret is no longer a valid enemy target. Its physical blocker
	# must also be disabled, otherwise the broken turret becomes an
	# indestructible wall for the remainder of the defense wave. When a broken
	# turret is rebuilt while the player is standing inside its footprint, keep
	# collision disabled until the player steps clear so the rebuild cannot trap
	# the player inside a newly re-enabled StaticBody2D.
	if blocker_shape != null:
		if is_currently_broken:
			blocker_enable_pending_until_player_clear = false
			blocker_shape.set_deferred("disabled", true)
		elif _is_player_overlapping_blocker():
			blocker_enable_pending_until_player_clear = true
			blocker_shape.set_deferred("disabled", true)
		else:
			blocker_enable_pending_until_player_clear = false
			blocker_shape.set_deferred("disabled", false)

	if is_currently_broken:
		enemies_in_range.clear()

	_update_health_bar()

	var state_changed: bool = previous_state != turret_state

	if force_visual_update or state_changed or is_currently_broken:
		visual_token += 1
		_apply_condition_visual()


func _update_pending_blocker_enable() -> void:
	if not blocker_enable_pending_until_player_clear:
		return

	if blocker_shape == null:
		blocker_enable_pending_until_player_clear = false
		return

	if is_broken():
		blocker_enable_pending_until_player_clear = false
		return

	if _is_player_overlapping_blocker():
		return

	blocker_enable_pending_until_player_clear = false
	blocker_shape.set_deferred("disabled", false)


func _is_player_overlapping_blocker() -> bool:
	if blocker_shape == null or blocker_shape.shape == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = blocker_shape.shape
	query.transform = blocker_shape.global_transform
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results: Array[Dictionary] = (
		get_world_2d().direct_space_state.intersect_shape(query, 8)
	)

	for result in results:
		var collider: Object = result.get("collider", null)

		if collider is Node and (collider as Node).is_in_group("player"):
			return true

	return false


func _apply_condition_visual() -> void:
	if turret_sprite == null:
		return

	turret_sprite.modulate = base_modulate

	if turret_state == DefenseManager.PLACEABLE_STATE_BROKEN:
		if not _play_animation(ANIM_BROKEN, true):
			turret_sprite.modulate = Color(0.25, 0.25, 0.25)

		return

	if turret_state == DefenseManager.PLACEABLE_STATE_DAMAGED:
		if not _play_animation(ANIM_DAMAGED_IDLE, true):
			turret_sprite.modulate = Color(1.0, 0.72, 0.35)

		return

	_play_animation(ANIM_IDLE, true)


func _configure_animation_settings() -> void:
	if turret_sprite == null:
		return

	if turret_sprite.sprite_frames == null:
		return

	if _has_animation(ANIM_IDLE):
		turret_sprite.sprite_frames.set_animation_loop(ANIM_IDLE, true)

	if _has_animation(ANIM_FIRE):
		turret_sprite.sprite_frames.set_animation_loop(ANIM_FIRE, false)
		turret_sprite.sprite_frames.set_animation_speed(
			ANIM_FIRE,
			1.0 / fire_frame_time
		)

	if _has_animation(ANIM_DAMAGED_IDLE):
		turret_sprite.sprite_frames.set_animation_loop(ANIM_DAMAGED_IDLE, true)

	if _has_animation(ANIM_BROKEN):
		turret_sprite.sprite_frames.set_animation_loop(ANIM_BROKEN, true)


func _setup_health_bar() -> void:
	if health_bar == null:
		return

	health_bar.min_value = 0.0
	health_bar.max_value = 100.0
	health_bar.value = 100.0
	health_bar.visible = show_health_bar_always


func _update_health_bar() -> void:
	if health_bar == null:
		return

	var health_percent: float = _get_turret_health_percent()

	health_bar.value = health_percent * 100.0

	if show_health_bar_always:
		health_bar.visible = true
	else:
		health_bar.visible = health_percent < 1.0 and health_percent > 0.0


func _get_turret_health_percent() -> float:
	if defense_manager == null or turret_key.is_empty():
		return 1.0

	if defense_manager.has_method("get_pesticide_turret_integrity_percent"):
		return clampf(
			float(
				defense_manager.call(
					"get_pesticide_turret_integrity_percent",
					turret_key
				)
			),
			0.0,
			1.0
		)

	if turret_state == DefenseManager.PLACEABLE_STATE_BROKEN:
		return 0.0

	if turret_state == DefenseManager.PLACEABLE_STATE_DAMAGED:
		return 0.5

	return 1.0


func _has_animation(animation_name: StringName) -> bool:
	if turret_sprite == null:
		return false

	if turret_sprite.sprite_frames == null:
		return false

	return turret_sprite.sprite_frames.has_animation(animation_name)


func _play_animation(
	animation_name: StringName,
	restart_animation: bool = false
) -> bool:
	if not _has_animation(animation_name):
		push_warning(
			"PesticideTurret missing animation: " + String(animation_name)
		)
		return false

	if restart_animation:
		turret_sprite.stop()
		turret_sprite.frame = 0
		turret_sprite.play(animation_name)
		return true

	if turret_sprite.animation != animation_name:
		turret_sprite.play(animation_name)

	return true


func _get_animation_duration(
	animation_name: StringName,
	fallback_duration: float
) -> float:
	if not _has_animation(animation_name):
		return fallback_duration

	var frame_count: int = turret_sprite.sprite_frames.get_frame_count(
		animation_name
	)

	var animation_speed: float = turret_sprite.sprite_frames.get_animation_speed(
		animation_name
	)

	if frame_count <= 0 or animation_speed <= 0.0:
		return fallback_duration

	return float(frame_count) / animation_speed



func _play_audio_sfx(sfx_name: String) -> void:
	var audio_manager: Node = get_tree().get_first_node_in_group(
		"audio_manager"
	)

	if audio_manager == null:
		return

	if audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_name)

func is_nighttime() -> bool:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager == null:
		return false

	if time_manager.has_method("is_nighttime"):
		return bool(time_manager.call("is_nighttime"))

	return false


func get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_squared: float = INF

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue

		if not enemy.is_in_group("enemies"):
			continue

		if enemy.has_method("can_be_targeted_by_defense"):
			if not bool(enemy.call("can_be_targeted_by_defense")):
				continue

		var distance_squared: float = global_position.distance_squared_to(
			enemy.global_position
		)

		if distance_squared > attack_range * attack_range:
			continue

		if distance_squared < nearest_distance_squared:
			nearest_enemy = enemy
			nearest_distance_squared = distance_squared

	return nearest_enemy


func show_spray_feedback() -> void:
	if not _has_animation(ANIM_FIRE):
		_show_old_spray_flash()
		return

	if is_broken():
		_apply_condition_visual()
		return

	visual_token += 1
	var current_token: int = visual_token

	_play_animation(ANIM_FIRE, true)

	var fire_duration: float = _get_animation_duration(
		ANIM_FIRE,
		fire_frame_time * 3.0
	)

	await get_tree().create_timer(fire_duration, false).timeout

	if current_token == visual_token and is_instance_valid(turret_sprite):
		_apply_condition_visual()


func _show_old_spray_flash() -> void:
	visual_token += 1
	var current_token: int = visual_token

	turret_sprite.modulate = Color(0.55, 1.0, 0.55, 1.0)

	await get_tree().create_timer(0.12, false).timeout

	if current_token == visual_token and is_instance_valid(turret_sprite):
		_apply_condition_visual()


func _on_range_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	if not enemies_in_range.has(body):
		enemies_in_range.append(body)


func _on_range_area_body_exited(body: Node2D) -> void:
	if enemies_in_range.has(body):
		enemies_in_range.erase(body)



func _on_repair_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_in_repair_range = body


func _on_repair_area_body_exited(body: Node2D) -> void:
	if body == player_in_repair_range:
		player_in_repair_range = null
		repair_debug_session_active = false
		repair_hold_cost_paid = false


func _on_turret_condition_changed(
	changed_turret_key: String,
	_new_turret_state: String
) -> void:
	if changed_turret_key != turret_key:
		return

	_refresh_from_manager(false)
