extends BaseEnemy

@export var charge_speed: float = 220.0
@export var charge_duration: float = 0.35
@export var charge_cooldown: float = 2.0

var is_charging: bool = false
var can_charge: bool = true
var charge_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	enemy_name = "Blight Pig"
	max_health = 60
	move_speed = 75.0
	contact_damage = 14
	damage_type = "Blunt"

	required_fence_gap_segments = 1
	body_radius = 12.0
	visual_scale_multiplier = 0.95

	seed_drop_chance = 1.0
	scrap_drop_chance = 1.0

	super._ready()

func update_enemy_behavior() -> void:
	if is_charging:
		velocity = charge_direction * charge_speed
		move_and_slide()
		return

	var primary_target: Node2D = get_primary_target()

	# Blight Pigs charge only at the player.
	# They do not charge blindly into fences or turrets.
	if (
		primary_target == player
		and can_charge
		and player != null
		and has_clear_path_to(player.global_position)
	):
		var distance_to_player: float = global_position.distance_to(
			player.global_position
		)

		if (
			distance_to_player > get_attack_range() * 1.5
			and distance_to_player < 260.0
		):
			start_charge(player.global_position)
			return

	execute_shared_target_strategy()

func start_charge(target_position: Vector2) -> void:
	can_charge = false
	is_charging = true

	charge_direction = global_position.direction_to(target_position)

	await get_tree().create_timer(charge_duration).timeout

	if not is_instance_valid(self):
		return

	is_charging = false

	await get_tree().create_timer(charge_cooldown).timeout

	if is_instance_valid(self):
		can_charge = true
