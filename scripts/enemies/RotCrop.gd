extends BaseEnemy

@export var pulse_damage: int = 4
@export var pulse_interval: float = 1.5
@export var pulse_range: float = 120.0

var can_pulse: bool = true

func _ready() -> void:
	enemy_name = "Rot Crop"
	max_health = 90
	move_speed = 45.0
	contact_damage = 8
	seed_drop_chance = 0.4
	scrap_drop_chance = 0.4

	super._ready()

func update_enemy_behavior() -> void:
	chase_player()

	if can_pulse:
		rot_pulse()

func rot_pulse() -> void:
	if player == null:
		return

	can_pulse = false

	var distance_to_player := global_position.distance_to(player.global_position)

	if distance_to_player <= pulse_range:
		if player.has_method("take_damage"):
			print("Rot Crop pulse damaged player.")
			player.take_damage(pulse_damage)

	await get_tree().create_timer(pulse_interval).timeout
	can_pulse = true
