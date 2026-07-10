extends BaseEnemy

@export var pulse_damage: int = 4
@export var pulse_interval: float = 1.5
@export var pulse_range: float = 120.0

func _ready() -> void:
	enemy_name = "Rot Crop"
	max_health = 90
	move_speed = 45.0

	contact_damage = pulse_damage
	damage_cooldown = pulse_interval
	attack_range = pulse_range
	damage_type = "Rot"

	required_fence_gap_segments = 1
	body_radius = 11.0
	visual_scale_multiplier = 1.05

	seed_drop_chance = 1.0
	scrap_drop_chance = 1.0

	super._ready()

func get_attack_range() -> float:
	return pulse_range

func attacks_through_fences() -> bool:
	return true

func perform_attack_on_target(target: Node2D) -> void:
	if not target.has_method("take_damage"):
		return

	target.call("take_damage", pulse_damage)

	print(
		"Rot Crop pulse dealt ",
		pulse_damage,
		" Rot damage to ",
		target.name
	)

	start_attack_cooldown()
