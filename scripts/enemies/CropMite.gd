extends BaseEnemy

func _ready() -> void:
	enemy_name = "Crop Mite"
	max_health = 25
	move_speed = 130.0
	contact_damage = 6
	seed_drop_chance = 0.7
	scrap_drop_chance = 0.1

	super._ready()
