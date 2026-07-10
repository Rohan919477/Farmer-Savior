extends Node2D
class_name PesticideTurret

@export var attack_damage: int = 8
@export var attack_interval: float = 1.0
@export var attack_range: float = 180.0
@export var durability_cost_per_attack: float = 1.0

@onready var range_area: Area2D = $RangeArea
@onready var turret_sprite: Sprite2D = $Sprite2D

var enemies_in_range: Array[Node2D] = []
var attack_cooldown: float = 0.0

var defense_manager: DefenseManager = null
var turret_key: String = ""
var turret_state: String = "perfect"
var base_modulate: Color = Color.WHITE

func _ready() -> void:
	add_to_group("farm_defenses")
	add_to_group("attackable_placeables")

	base_modulate = turret_sprite.modulate

	range_area.body_entered.connect(_on_range_area_body_entered)
	range_area.body_exited.connect(_on_range_area_body_exited)

	_apply_condition_visual()

func configure_turret(
	new_defense_manager: DefenseManager,
	new_turret_key: String
) -> void:
	defense_manager = new_defense_manager
	turret_key = new_turret_key

	if not defense_manager.turret_condition_changed.is_connected(
		_on_turret_condition_changed
	):
		defense_manager.turret_condition_changed.connect(
			_on_turret_condition_changed
		)

	_refresh_from_manager()

func _physics_process(delta: float) -> void:
	if is_broken():
		return

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

		if defense_manager != null and not turret_key.is_empty():
			defense_manager.consume_pesticide_turret_durability(
				turret_key,
				durability_cost_per_attack
			)

		print(
			"Pesticide Turret sprayed ",
			target.name,
			" for ",
			attack_damage,
			" poison damage."
		)

func is_broken() -> bool:
	if defense_manager == null or turret_key.is_empty():
		return false

	return (
		defense_manager.get_turret_state(turret_key)
		== DefenseManager.PLACEABLE_STATE_BROKEN
	)

func can_be_targeted_by_enemy() -> bool:
	return not is_broken()

func get_target_position() -> Vector2:
	return global_position

func take_damage(damage_amount: float) -> void:
	if defense_manager == null or turret_key.is_empty():
		return

	defense_manager.damage_pesticide_turret_integrity(
		turret_key,
		damage_amount
	)

func _refresh_from_manager() -> void:
	if defense_manager == null or turret_key.is_empty():
		return

	turret_state = defense_manager.get_turret_state(turret_key)

	var is_currently_broken: bool = (
		turret_state == DefenseManager.PLACEABLE_STATE_BROKEN
	)

	range_area.set_deferred("monitoring", not is_currently_broken)

	if is_currently_broken:
		enemies_in_range.clear()

	_apply_condition_visual()

func _apply_condition_visual() -> void:
	if turret_sprite == null:
		return

	if turret_state == DefenseManager.PLACEABLE_STATE_BROKEN:
		turret_sprite.modulate = Color(0.25, 0.25, 0.25)
		return

	if turret_state == DefenseManager.PLACEABLE_STATE_DAMAGED:
		turret_sprite.modulate = Color(1.0, 0.72, 0.35)
		return

	turret_sprite.modulate = base_modulate

func is_nighttime() -> bool:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

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
		_apply_condition_visual()

func _on_range_area_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemies"):
		return

	if not enemies_in_range.has(body):
		enemies_in_range.append(body)

func _on_range_area_body_exited(body: Node2D) -> void:
	if enemies_in_range.has(body):
		enemies_in_range.erase(body)

func _on_turret_condition_changed(
	changed_turret_key: String,
	_new_turret_state: String
) -> void:
	if changed_turret_key != turret_key:
		return

	_refresh_from_manager()
