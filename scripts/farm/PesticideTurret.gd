extends Node2D

@export var attack_damage: int = 8
@export var attack_interval: float = 1.0
@export var attack_range: float = 180.0

@onready var range_area: Area2D = $RangeArea
@onready var turret_sprite: Sprite2D = $Sprite2D
@onready var normal_modulate: Color = turret_sprite.modulate

var enemies_in_range: Array[Node2D] = []
var attack_cooldown: float = 0.0

func _ready() -> void:
	add_to_group("farm_defenses")

	range_area.body_entered.connect(_on_range_area_body_entered)
	range_area.body_exited.connect(_on_range_area_body_exited)

func _physics_process(delta: float) -> void:
	if not is_nighttime():
		return

	attack_cooldown -= delta

	if attack_cooldown > 0.0:
		return

	var target: Node2D = get_nearest_enemy()

	if target == null:
		return

	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage)

		attack_cooldown = attack_interval
		show_spray_feedback()

		print(
			"Pesticide Turret sprayed ",
			target.name,
			" for ",
			attack_damage,
			" damage."
		)

func is_nighttime() -> bool:
	var time_manager: Node = get_tree().get_first_node_in_group("time_manager")

	if time_manager == null:
		return false

	if time_manager.has_method("is_nighttime"):
		return bool(time_manager.call("is_nighttime"))

	return false

func get_nearest_enemy() -> Node2D:
	var nearest_enemy: Node2D = null
	var nearest_distance_squared: float = INF

	for enemy in enemies_in_range:
		if not is_instance_valid(enemy):
			continue

		if not enemy.is_in_group("enemies"):
			continue

		var distance_squared: float = global_position.distance_squared_to(
			enemy.global_position
		)

		if distance_squared > attack_range * attack_range:
			continue

		if distance_squared < nearest_distance_squared:
			nearest_enemy = enemy
			nearest_distance_squared = distance_squared

	return nearest_enemy

func show_spray_feedback() -> void:
	turret_sprite.modulate = Color(0.55, 1.0, 0.55, 1.0)

	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(turret_sprite):
		turret_sprite.modulate = normal_modulate

func _on_range_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	if not enemies_in_range.has(body):
		enemies_in_range.append(body)

func _on_range_area_body_exited(body: Node2D) -> void:
	if enemies_in_range.has(body):
		enemies_in_range.erase(body)
