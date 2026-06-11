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
	seed_drop_chance = 0.3
	scrap_drop_chance = 0.5

	super._ready()

func update_enemy_behavior() -> void:
	if player == null:
		return

	if is_charging:
		velocity = charge_direction * charge_speed
		move_and_slide()
		return

	var distance_to_player := global_position.distance_to(player.global_position)

	if distance_to_player < 260 and can_charge:
		start_charge()
	else:
		chase_player()

func start_charge() -> void:
	can_charge = false
	is_charging = true
	charge_direction = global_position.direction_to(player.global_position)

	await get_tree().create_timer(charge_duration).timeout
	is_charging = false

	await get_tree().create_timer(charge_cooldown).timeout
	can_charge = true
