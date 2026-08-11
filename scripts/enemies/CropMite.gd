extends BaseEnemy

@export var basic_attack_hit_frame: int = 1
@export var basic_attack_extra_range: float = 8.0
@export var hurt_pose_duration: float = 0.12

var is_basic_attack_active: bool = false
var is_hurt_animation_playing: bool = false
var is_death_animation_playing: bool = false

var last_horizontal_facing: float = -1.0
var hurt_feedback_serial: int = 0

@onready var body_sprite: AnimatedSprite2D = (
	get_node_or_null("BodySprite") as AnimatedSprite2D
)


func _ready() -> void:
	enemy_name = "Crop Mite"
	max_health = 25
	move_speed = 130.0
	contact_damage = 6

	body_radius = 8.0
	visual_scale_multiplier = 0.65

	seed_drop_chance = 0.7
	scrap_drop_chance = 0.1

	super._ready()

	if sprite != null:
		sprite.visible = false

	if body_sprite == null:
		print(
			"[Crop Mite Animation] BodySprite is missing from CropMite.tscn."
		)
		return

	body_sprite.visible = true
	body_sprite.scale = (
		body_sprite.scale * visual_scale_multiplier
	)

	_set_facing_from_direction(Vector2.LEFT)
	_play_looping_animation(&"walk")


func update_enemy_behavior() -> void:
	if is_death_animation_playing:
		velocity = Vector2.ZERO
		return

	if is_basic_attack_active or is_hurt_animation_playing:
		velocity = Vector2.ZERO
		return

	execute_shared_target_strategy()
	_update_walk_animation()


func perform_attack_on_target(target: Node2D) -> void:
	if is_death_animation_playing:
		return

	if is_basic_attack_active:
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

	if is_basic_attack_active:
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

	# Keep an active bite animation visible and use a red flash instead.
	if is_basic_attack_active:
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

	if body_sprite.sprite_frames.has_animation(&"hurt"):
		body_sprite.stop()
		body_sprite.animation = &"hurt"
		body_sprite.frame = 0
		body_sprite.frame_progress = 0.0
	else:
		body_sprite.self_modulate = Color(
			1.0,
			0.35,
			0.35,
			1.0
		)

	await get_tree().create_timer(
		maxf(hurt_pose_duration, 0.05)
	).timeout

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
	is_hurt_animation_playing = false
	can_attack_target = false
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
		or is_hurt_animation_playing
	):
		return

	_set_facing_from_direction(velocity)

	if velocity.length_squared() > 1.0:
		_play_looping_animation(&"walk")
		return

	# Crop Mites have no idle animation.
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

	# The supplied Crop Mite artwork faces left.
	# Flip horizontally when facing right.
	body_sprite.flip_h = last_horizontal_facing > 0.0


func _play_looping_animation(
	animation_name: StringName
) -> bool:
	if body_sprite == null:
		return false

	if not body_sprite.sprite_frames.has_animation(
		animation_name
	):
		print(
			"[Crop Mite Animation] Missing animation: ",
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
			"[Crop Mite Animation] Missing animation: ",
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
		"[Crop Mite Animation] Playing: ",
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
