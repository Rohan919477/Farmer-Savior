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

@onready var range_area: Area2D = $RangeArea
@onready var turret_sprite: AnimatedSprite2D = $BodySprite
@onready var health_bar: ProgressBar = $HealthBar

var enemies_in_range: Array[Node2D] = []
var attack_cooldown: float = 0.0

var defense_manager: DefenseManager = null
var turret_key: String = ""
var turret_state: String = "perfect"

var base_modulate: Color = Color.WHITE
var visual_token: int = 0


func _ready() -> void:
	add_to_group("farm_defenses")
	add_to_group("attackable_placeables")

	base_modulate = turret_sprite.modulate

	range_area.body_entered.connect(_on_range_area_body_entered)
	range_area.body_exited.connect(_on_range_area_body_exited)

	_configure_animation_settings()
	_setup_health_bar()
	_apply_condition_visual()
	_update_health_bar()


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

	if is_currently_broken:
		enemies_in_range.clear()

	_update_health_bar()

	var state_changed: bool = previous_state != turret_state

	if force_visual_update or state_changed or is_currently_broken:
		visual_token += 1
		_apply_condition_visual()


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

	await get_tree().create_timer(fire_duration).timeout

	if current_token == visual_token and is_instance_valid(turret_sprite):
		_apply_condition_visual()


func _show_old_spray_flash() -> void:
	visual_token += 1
	var current_token: int = visual_token

	turret_sprite.modulate = Color(0.55, 1.0, 0.55, 1.0)

	await get_tree().create_timer(0.12).timeout

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


func _on_turret_condition_changed(
	changed_turret_key: String,
	_new_turret_state: String
) -> void:
	if changed_turret_key != turret_key:
		return

	_refresh_from_manager(false)
