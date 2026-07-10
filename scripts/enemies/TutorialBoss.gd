extends BaseEnemy
class_name TutorialBoss

@export var mutant_seed_reward_amount: int = 1

func _ready() -> void:
	enemy_name = "Blight Root Brute"

	max_health = 260
	move_speed = 36.0

	# Player damage is high but survivable.
	contact_damage = 22

	# Boss should tear down farm structures much faster
	# than normal enemies.
	fence_damage_multiplier = 6.0
	structure_damage_multiplier = 4.0

	damage_cooldown = 1.15

	attack_range = 68.0
	fence_attack_range = 76.0

	player_priority_distance = 360.0
	placeable_priority_ratio = 0.80

	damage_type = "Blunt"

	required_fence_gap_segments = 4
	body_radius = 44.0
	visual_scale_multiplier = 2.0

	seed_drop_chance = 0.0
	scrap_drop_chance = 0.0

	debug_ai_logging = true

	super._ready()

func apply_day_scaling(_day_number: int) -> void:
	# Tutorial boss uses fixed stats so the first boss fight is controlled.
	current_health = max_health

func die() -> void:
	print(enemy_name, " defeated. Awarding Mutant Seed.")

	var player_node: Node = get_tree().get_first_node_in_group("player")

	if (
		player_node != null
		and player_node.has_method("add_resource")
		and mutant_seed_reward_amount > 0
	):
		player_node.call(
			"add_resource",
			"mutant_seeds",
			mutant_seed_reward_amount
		)

	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if (
		tutorial_manager != null
		and tutorial_manager.has_method("on_tutorial_boss_defeated")
	):
		tutorial_manager.call("on_tutorial_boss_defeated")

	queue_free()
