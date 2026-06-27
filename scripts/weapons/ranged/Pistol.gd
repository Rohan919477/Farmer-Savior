extends Node2D
class_name Pistol

@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.25

@onready var muzzle_point: Marker2D = $MuzzlePoint

var can_fire: bool = true

func fire(direction: Vector2) -> void:
	if not can_fire:
		return

	if bullet_scene == null:
		print("Pistol Bullet scene is not assigned.")
		return

	if direction.length() <= 0.0:
		return

	can_fire = false
	rotation = direction.angle()

	var bullet: PistolBullet = bullet_scene.instantiate() as PistolBullet

	if bullet != null:
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle_point.global_position
		bullet.setup(direction)

	await get_tree().create_timer(fire_cooldown).timeout
	can_fire = true
