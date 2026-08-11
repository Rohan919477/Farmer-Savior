extends BaseEnemy

@export var basic_attack_damage: int = 8
@export var basic_attack_interval: float = 0.90
@export var basic_attack_hit_frame: int = 2
@export var basic_attack_extra_range: float = 10.0

@export var pulse_damage: int = 4
@export var pulse_range: float = 120.0
@export var pulse_cooldown: float = 4.0
@export var pulse_decision_interval: float = 1.0

@export_range(0.0, 1.0, 0.01)
var pulse_trigger_chance: float = 0.20

@export var pulse_damage_frame: int = 3
@export var hurt_pose_duration: float = 0.16

var is_basic_attack_active: bool = false
var is_pulse_sequence_active: bool = false
var is_hurt_animation_playing: bool = false
var is_death_animation_playing: bool = false

var can_pulse: bool = true
var pulse_decision_ready: bool = true

var last_horizontal_facing: float = 1.0
var hurt_feedback_serial: int = 0

@onready var body_sprite: AnimatedSprite2D = (
	get_node_or_null("BodySprite") as AnimatedSprite2D
)


func _ready() -> void:
	enemy_name = "Rot Crop"
	max_health = 90
	move_speed = 45.0

	contact_damage = basic_attack_damage
	damage_cooldown = basic_attack_interval
	attack_range = 30.0
	fence_attack_range = 34.0
	damage_type = "Rot"

	body_radius = 11.0
	visual_scale_multiplier = 1.05

	seed_drop_chance = 0.4
	scrap_drop_chance = 0.4

	super._ready()

	if sprite != null:
		sprite.visible = false

	if body_sprite == null:
		print(
			"[Rot Crop Animation] BodySprite is missing from RotCrop.tscn."
		)
		return

	body_sprite.visible = true
	body_sprite.scale = (
		body_sprite.scale * visual_scale_multiplier
	)

	_set_facing_from_direction(Vector2.RIGHT)
	_play_looping_animation(&"walk")


func update_enemy_behavior() -> void:
	if is_death_animation_playing:
		velocity = Vector2.ZERO
		return

	if (
		is_basic_attack_active
		or is_pulse_sequence_active
		or is_hurt_animation_playing
	):
		velocity = Vector2.ZERO
		return

	if _should_try_pulse():
		if _try_begin_pulse():
			return

	execute_shared_target_strategy()
	_update_walk_animation()


func attacks_through_fences() -> bool:
	# Normal vine/claw attacks must reach a target physically.
	# The radial pulse is handled separately and can reach through fences.
	return false


func _should_try_pulse() -> bool:
	if not can_pulse or not pulse_decision_ready:
		return false

	if player == null or not is_instance_valid(player):
		return false

	if get_primary_target() != player:
		return false

	return (
		global_position.distance_to(player.global_position)
		<= pulse_range
	)


func _try_begin_pulse() -> bool:
	pulse_decision_ready = false
	_reset_pulse_decision_after_delay()

	if randf() > clampf(pulse_trigger_chance, 0.0, 1.0):
		return false

	start_pulse_attack()
	return true


func _reset_pulse_decision_after_delay() -> void:
	await get_tree().create_timer(
		maxf(pulse_decision_interval, 0.05)
	).timeout

	if is_instance_valid(self):
		pulse_decision_ready = true


func start_pulse_attack() -> void:
	if is_death_animation_playing:
		return

	if is_pulse_sequence_active:
		return

	can_pulse = false
	is_pulse_sequence_active = true
	velocity = Vector2.ZERO

	if player != null and is_instance_valid(player):
		_face_towards_position(player.global_position)

	var special_started: bool = _start_action_animation(
		&"special_attack"
	)

	if special_started:
		await get_tree().create_timer(
			_get_animation_hit_delay(
				&"special_attack",
				pulse_damage_frame
			)
		).timeout

	if (
		not is_instance_valid(self)
		or is_death_animation_playing
	):
		return

	_apply_radial_pulse_damage()

	if (
		special_started
		and body_sprite != null
		and body_sprite.animation == &"special_attack"
		and body_sprite.is_playing()
	):
		await body_sprite.animation_finished

	if (
		not is_instance_valid(self)
		or is_death_animation_playing
	):
		return

	is_pulse_sequence_active = false
	_update_walk_animation()
	_begin_pulse_cooldown()


func _begin_pulse_cooldown() -> void:
	await get_tree().create_timer(
		maxf(pulse_cooldown, 0.05)
	).timeout

	if is_instance_valid(self):
		can_pulse = true


func _apply_radial_pulse_damage() -> void:
	var damaged_instance_ids: Dictionary = {}

	_try_apply_pulse_damage_to_target(
		player,
		damaged_instance_ids
	)

	for candidate_node in get_tree().get_nodes_in_group(
		"attackable_placeables"
	):
		if not (candidate_node is Node2D):
			continue

		_try_apply_pulse_damage_to_target(
			candidate_node as Node2D,
			damaged_instance_ids
		)


func _try_apply_pulse_damage_to_target(
	target: Node2D,
	damaged_instance_ids: Dictionary
) -> void:
	if target == null or not is_instance_valid(target):
		return

	if not target.has_method("take_damage"):
		return

	var target_id: int = target.get_instance_id()

	if damaged_instance_ids.has(target_id):
		return

	var target_position: Vector2 = get_target_position(target)

	if global_position.distance_to(target_position) > pulse_range:
		return

	var damage_to_deal: int = pulse_damage

	if (
		target != player
		and target.is_in_group("attackable_placeables")
	):
		damage_to_deal = maxi(
			1,
			roundi(
				float(pulse_damage)
				* structure_damage_multiplier
			)
		)

	damaged_instance_ids[target_id] = true
	target.call("take_damage", damage_to_deal)

	print(
		"Rot Crop radial pulse dealt ",
		damage_to_deal,
		" Rot damage to ",
		target.name
	)


func perform_attack_on_target(target: Node2D) -> void:
	if is_death_animation_playing:
		return

	if is_basic_attack_active or is_pulse_sequence_active:
		return

	if target == null or not is_instance_valid(target):
		return

	if not target.has_method("take_damage"):
		return

	can_attack_target = false
	is_basic_attack_active = true
	velocity = Vector2.ZERO

	var target_position: Vector2 = get_target_position(target)
	_face_towards_position(target_position)

	var damage_to_deal: int = contact_damage

	if (
		target != player
		and target.is_in_group("attackable_placeables")
	):
		damage_to_deal = get_structure_damage_amount()

	var attack_started: bool = _start_action_animation(
		&"basic_attack"
	)

	if attack_started:
		await get_tree().create_timer(
			_get_animation_hit_delay(
				&"basic_attack",
				basic_attack_hit_frame
			)
		).timeout

	if is_death_animation_playing:
		return

	if (
		is_instance_valid(target)
		and global_position.distance_to(
			get_target_position(target)
		) <= get_attack_range() + basic_attack_extra_range
	):
		target.call("take_damage", damage_to_deal)

	if (
		attack_started
		and body_sprite != null
		and body_sprite.animation == &"basic_attack"
		and body_sprite.is_playing()
	):
		await body_sprite.animation_finished

	if is_death_animation_playing:
		return

	is_basic_attack_active = false
	_update_walk_animation()
	start_attack_cooldown()


func try_attack_fence(fence: Node2D) -> void:
	if not can_attack_target:
		return

	if is_death_animation_playing:
		return

	if is_basic_attack_active or is_pulse_sequence_active:
		return

	if not _is_intact_fence(fence):
		return

	can_attack_target = false
	is_basic_attack_active = true
	velocity = Vector2.ZERO

	_face_towards_position(fence.global_position)

	var attack_started: bool = _start_action_animation(
		&"basic_attack"
	)

	if attack_started:
		await get_tree().create_timer(
			_get_animation_hit_delay(
				&"basic_attack",
				basic_attack_hit_frame
			)
		).timeout

	if is_death_animation_playing:
		return

	if (
		_is_intact_fence(fence)
		and global_position.distance_to(
			fence.global_position
		) <= fence_attack_range + basic_attack_extra_range
	):
		var fence_damage: float = get_fence_damage_amount()

		if fence.has_method("take_fence_damage"):
			fence.call("take_fence_damage", fence_damage)
		elif fence.has_method("take_damage"):
			fence.call("take_damage", fence_damage)

	if (
		attack_started
		and body_sprite != null
		and body_sprite.animation == &"basic_attack"
		and body_sprite.is_playing()
	):
		await body_sprite.animation_finished

	if is_death_animation_playing:
		return

	is_basic_attack_active = false
	_update_walk_animation()
	start_attack_cooldown()


func take_damage(amount: int) -> void:
	if is_death_animation_playing:
		return

	super.take_damage(amount)


func show_hit_feedback() -> void:
	if body_sprite == null:
		super.show_hit_feedback()
		return

	if is_death_animation_playing:
		return

	hurt_feedback_serial += 1
	var current_serial: int = hurt_feedback_serial

	# Preserve attack and special telegraphs. Flash red instead of
	# replacing those animations with the hurt animation.
	if is_basic_attack_active or is_pulse_sequence_active:
		var original_colour: Color = body_sprite.self_modulate

		body_sprite.self_modulate = Color(
			1.0,
			0.35,
			0.35,
			1.0
		)

		await get_tree().create_timer(0.08).timeout

		if (
			is_instance_valid(body_sprite)
			and current_serial == hurt_feedback_serial
			and not is_death_animation_playing
		):
			body_sprite.self_modulate = original_colour

		return

	is_hurt_animation_playing = true
	velocity = Vector2.ZERO

	var hurt_started: bool = _start_action_animation(&"hurt")

	if hurt_started:
		await get_tree().create_timer(
			maxf(hurt_pose_duration, 0.05)
		).timeout
	else:
		body_sprite.self_modulate = Color(
			1.0,
			0.35,
			0.35,
			1.0
		)

		await get_tree().create_timer(0.08).timeout

	if (
		current_serial != hurt_feedback_serial
		or is_death_animation_playing
	):
		return

	body_sprite.self_modulate = Color.WHITE
	is_hurt_animation_playing = false
	_update_walk_animation()


func die() -> void:
	if is_death_animation_playing:
		return

	is_death_animation_playing = true
	is_basic_attack_active = false
	is_pulse_sequence_active = false
	is_hurt_animation_playing = false

	can_attack_target = false
	can_pulse = false
	velocity = Vector2.ZERO

	hurt_feedback_serial += 1

	if body_sprite != null:
		body_sprite.self_modulate = Color.WHITE

	if body_collision != null:
		body_collision.set_deferred("disabled", true)

	if damage_area_collision != null:
		damage_area_collision.set_deferred("disabled", true)

	print(enemy_name, " died.")

	var death_started: bool = _start_action_animation(&"death")

	if death_started:
		await body_sprite.animation_finished

	if not is_instance_valid(self):
		return

	drop_resources()
	queue_free()


func _update_walk_animation() -> void:
	if body_sprite == null:
		return

	if (
		is_death_animation_playing
		or is_basic_attack_active
		or is_pulse_sequence_active
		or is_hurt_animation_playing
	):
		return

	_set_facing_from_direction(velocity)

	if velocity.length_squared() > 1.0:
		_play_looping_animation(&"walk")
		return

	# Rot Crops have no gameplay idle animation.
	# Hold the first walk frame whenever movement stops.
	if body_sprite.animation != &"walk":
		body_sprite.animation = &"walk"

	body_sprite.stop()
	body_sprite.frame = 0
	body_sprite.frame_progress = 0.0


func _face_towards_position(target_position: Vector2) -> void:
	var direction: Vector2 = global_position.direction_to(
		target_position
	)

	_set_facing_from_direction(direction)


func _set_facing_from_direction(direction: Vector2) -> void:
	if body_sprite == null:
		return

	if absf(direction.x) > 0.01:
		last_horizontal_facing = (
			1.0 if direction.x > 0.0 else -1.0
		)

	# The supplied Rot Crop artwork faces right.
	# Flip horizontally when facing left.
	body_sprite.flip_h = last_horizontal_facing < 0.0


func _play_looping_animation(
	animation_name: StringName
) -> bool:
	if body_sprite == null:
		return false

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Rot Crop Animation] Missing animation: ",
			animation_name
		)
		return false

	if (
		body_sprite.animation != animation_name
		or not body_sprite.is_playing()
	):
		body_sprite.play(animation_name)

	return true


func _start_action_animation(
	animation_name: StringName
) -> bool:
	if body_sprite == null:
		return false

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Rot Crop Animation] Missing animation: ",
			animation_name
		)
		return false

	body_sprite.stop()
	body_sprite.speed_scale = 1.0
	body_sprite.animation = animation_name
	body_sprite.frame = 0
	body_sprite.frame_progress = 0.0
	body_sprite.play(animation_name)

	print(
		"[Rot Crop Animation] Playing: ",
		animation_name
	)

	return true


func _get_animation_hit_delay(
	animation_name: StringName,
	hit_frame: int
) -> float:
	if body_sprite == null:
		return 0.0

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		return 0.0

	var frame_count: int = (
		body_sprite.sprite_frames.get_frame_count(
			animation_name
		)
	)

	var animation_fps: float = (
		body_sprite.sprite_frames.get_animation_speed(
			animation_name
		)
	)

	if frame_count <= 0 or animation_fps <= 0.0:
		return 0.0

	var safe_hit_frame: int = clampi(
		hit_frame,
		0,
		frame_count - 1
	)

	return float(safe_hit_frame) / animation_fps
