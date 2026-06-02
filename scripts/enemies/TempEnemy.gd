extends CharacterBody2D

@export var max_health: int = 45
@export var move_speed: float = 80.0
@export var contact_damage: int = 10
@export var damage_cooldown: float = 0.8

var current_health: int
var player: Node2D
var can_damage_player: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_area: Area2D = $DamageArea

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	var direction := global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(current_health, 0)

	print(name, " took damage: ", amount, " | HP: ", current_health)

	show_hit_feedback()

	if current_health <= 0:
		die()

func show_hit_feedback() -> void:
	if sprite == null:
		return

	sprite.modulate = Color(1, 1, 1)

	await get_tree().create_timer(0.08).timeout

	if is_instance_valid(sprite):
		sprite.modulate = Color(1, 0.2, 0.2)

func die() -> void:
	print(name, " died.")
	queue_free()

func _on_damage_area_body_entered(body: Node) -> void:
	if not can_damage_player:
		return

	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
		start_damage_cooldown()

func start_damage_cooldown() -> void:
	can_damage_player = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_damage_player = true
