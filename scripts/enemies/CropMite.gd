extends BaseEnemy

func _ready() -> void:
	enemy_name = "Crop Mite"
	max_health = 25
	move_speed = 130.0
	contact_damage = 6

	required_fence_gap_segments = 1
	body_radius = 8.0
	visual_scale_multiplier = 0.65

	seed_drop_chance = 1.0
	scrap_drop_chance = 1.0

	super._ready()
