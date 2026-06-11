extends CharacterBody2D
class_name BaseEnemy

@export var enemy_name: String = "Base Enemy"
@export var max_health: int = 45
@export var move_speed: float = 80.0
@export var contact_damage: int = 10
@export var damage_cooldown: float = 0.8

@export var seed_drop_scene: PackedScene
@export var scrap_drop_scene: PackedScene
@export var seed_drop_chance: float = 0.5
@export var scrap_drop_chance: float = 0.3

var current_health: int
var player: Node2D
var player_in_damage_area: bool = false
var can_damage_player: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var damage_area: Area2D = $DamageArea

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")

	if damage_area != null:
		damage_area.body_entered.connect(_on_damage_area_body_entered)
		damage_area.body_exited.connect(_on_damage_area_body_exited)

func _physics_process(_delta: float) -> void:
	if player == null:
		return

	update_enemy_behavior()

	if player_in_damage_area and can_damage_player:
		damage_player()

func update_enemy_behavior() -> void:
	chase_player()

func chase_player() -> void:
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: int) -> void:
	current_health -= amount
	current_health = max(current_health, 0)

	print(enemy_name, " took damage: ", amount, " | HP: ", current_health)

	show_hit_feedback()

	if current_health <= 0:
		die()

func show_hit_feedback() -> void:
	if sprite == null:
		return

	var original_color := sprite.modulate
	sprite.modulate = Color(1, 1, 1)

	await get_tree().create_timer(0.08).timeout

	if is_instance_valid(sprite):
		sprite.modulate = original_color

func damage_player() -> void:
	if player == null:
		return

	if player.has_method("take_damage"):
		player.take_damage(contact_damage)
		start_damage_cooldown()

func start_damage_cooldown() -> void:
	can_damage_player = false
	await get_tree().create_timer(damage_cooldown).timeout
	can_damage_player = true

func _on_damage_area_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_damage_area = true
		player = body

func _on_damage_area_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_damage_area = false

func die() -> void:
	print(enemy_name, " died.")
	drop_resources()
	queue_free()

func drop_resources() -> void:
	if seed_drop_scene != null and randf() <= seed_drop_chance:
		spawn_drop(seed_drop_scene)

	if scrap_drop_scene != null and randf() <= scrap_drop_chance:
		spawn_drop(scrap_drop_scene)

func spawn_drop(drop_scene: PackedScene) -> void:
	var drop = drop_scene.instantiate()
	get_tree().current_scene.add_child(drop)
	drop.global_position = global_position
