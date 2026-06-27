extends CharacterBody2D

@export var move_speed: float = 220.0
@export var max_health: int = 100

var current_health: int
var facing_direction: Vector2 = Vector2.RIGHT
var can_melee_attack: bool = true

var seeds: int = 0
var scrap: int = 0
var mutant_seeds: int = 0

@onready var hoe_hitbox: Area2D = $HoeHitbox
@onready var hoe_collision: CollisionShape2D = $HoeHitbox/CollisionShape2D
@onready var health_label: Label = $PlayerDebugUI/HealthLabel
@onready var pistol: Pistol = $Pistol

func _ready() -> void:
	current_health = max_health
	hoe_collision.disabled = true
	update_debug_ui()

func is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(main_node.call("is_gameplay_input_blocked"))

	return false

func _physics_process(_delta: float) -> void:
	if is_gameplay_input_blocked():
		velocity = Vector2.ZERO
		hoe_collision.disabled = true
		return

	handle_movement()
	handle_combat_input()

func handle_movement() -> void:
	var input_direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down",
	)

	if input_direction.length() > 0.0:
		facing_direction = input_direction

	velocity = input_direction * move_speed
	move_and_slide()

func handle_combat_input() -> void:
	if Input.is_action_just_pressed("shoot"):
		fire_pistol()

	if Input.is_action_just_pressed("melee_attack"):
		use_hoe_swing()

func fire_pistol() -> void:
	if pistol == null:
		print("Pistol node is missing from Player.tscn.")
		return

	pistol.fire(facing_direction)

func use_hoe_swing() -> void:
	print("Hoe swing pressed")
	if not can_melee_attack:
		return

	can_melee_attack = false

	hoe_hitbox.position = facing_direction * 32.0
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

	print(
		"Resources | Seeds: ",
		seeds,
		" Scrap: ",
		scrap,
		" Mutant Seeds: ",
		mutant_seeds
	)

func die() -> void:
	print("Player died.")
