extends CharacterBody2D

@export var move_speed: float = 220.0
@export var max_health: int = 100
@export var seed_projectile_scene: PackedScene

var current_health: int
var facing_direction: Vector2 = Vector2.RIGHT
var can_melee_attack: bool = true
var can_shoot: bool = true

var seeds: int = 0
var scrap: int = 0
var mutant_seeds: int = 0

@onready var hoe_hitbox: Area2D = $HoeHitbox
@onready var hoe_collision: CollisionShape2D = $HoeHitbox/CollisionShape2D
@onready var health_label: Label = $PlayerDebugUI/HealthLabel

func _ready() -> void:
	current_health = max_health
	hoe_collision.disabled = true
	update_debug_ui()

func _physics_process(_delta: float) -> void:
	handle_movement()
	handle_combat_input()

func handle_movement() -> void:
	var input_direction := Vector2.ZERO
	
	input_direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()
		facing_direction = input_direction
		
	velocity = input_direction * move_speed
	move_and_slide()
	
func handle_combat_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		shoot_seed()
		
	if Input.is_action_just_pressed("melee_attack"):
		use_hoe_swing()
		
func shoot_seed() -> void:
	if not can_shoot:
		return
	
	if seed_projectile_scene == null:
		print("Seed projectile scene is not assigned.")
		return
		
	can_shoot = false
	
	var projectile = seed_projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	
	projectile.global_position = global_position + facing_direction * 32
	projectile.setup(facing_direction)
	
	await get_tree().create_timer(0.25).timeout
	can_shoot = true
	
func use_hoe_swing() -> void:
	if not can_melee_attack:
		return
		
	can_melee_attack = false
	
	hoe_hitbox.position = facing_direction * 32
	hoe_collision.disabled = false
	
	await get_tree().create_timer(0.12).timeout
	hoe_collision.disabled = true
	
	await get_tree().create_timer(0.25).timeout
	can_melee_attack = true
	
func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(current_health, 0)
	
	print("Player took damage: ", amount, " | HP: ", current_health)
	update_debug_ui()
	
	if current_health <= 0:
		die()

func update_debug_ui() -> void:
	if health_label != null:
		health_label.text = "HP: %s / %s" % [current_health, max_health]

func add_resource(resource_type: String, amount: int) -> void:
	match resource_type:
		"seeds":
			seeds += amount
		"scrap":
			scrap += amount
		"mutant_seeds":
			mutant_seeds += amount
		_:
			print("Unknown resource type: ", resource_type)
			return

	print("Resources | Seeds: ", seeds, " Scrap: ", scrap, " Mutant Seeds: ", mutant_seeds)
		
func die() -> void:
	print("Player died.")
	
	
	
