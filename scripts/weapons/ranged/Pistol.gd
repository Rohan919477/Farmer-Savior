extends Node2D
class_name Pistol

signal ammo_changed(
	current_ammo: int,
	magazine_size: int,
	reserve_ammo: int
)

signal reload_started(reload_duration: float)
signal reload_finished


@export_group("Combat")
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.25
@export var magazine_size: int = 6
@export var reload_time: float = 1.5

@export_group("Ammo")
@export var starting_reserve_ammo: int = 200

@onready var muzzle_point: Marker2D = $MuzzlePoint

var can_fire: bool = true
var current_ammo: int = 0
var reserve_ammo: int = 0
var pending_reload_ammo: int = 0
var is_reloading: bool = false


func _ready() -> void:
	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	pending_reload_ammo = 0
	_emit_ammo_changed()


func fire(direction: Vector2) -> bool:
	if not can_fire:
		return false

	if is_reloading:
		return false

	if current_ammo <= 0:
		print("[Pistol] Pistol is empty. Press R to reload.")
		return false

	if bullet_scene == null:
		print("[Pistol] Bullet scene is not assigned.")
		return false

	if direction.length() <= 0.0:
		return false

	can_fire = false
	current_ammo -= 1
	rotation = direction.angle()

	_emit_ammo_changed()

	var bullet: PistolBullet = (
		bullet_scene.instantiate() as PistolBullet
	)

	if bullet != null:
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = muzzle_point.global_position
		bullet.setup(direction)

	_begin_fire_cooldown()

	return true


func _begin_fire_cooldown() -> void:
	await get_tree().create_timer(fire_cooldown).timeout

	if not is_reloading:
		can_fire = true


func start_reload() -> bool:
	if is_reloading:
		return false

	if current_ammo >= magazine_size:
		return false

	if reserve_ammo <= 0:
		print("[Pistol] No reserve pistol ammo left to reload.")
		return false

	var bullets_needed: int = magazine_size - current_ammo
	pending_reload_ammo = mini(
		bullets_needed,
		reserve_ammo
	)

	if pending_reload_ammo <= 0:
		return false

	is_reloading = true
	can_fire = false

	reload_started.emit(reload_time)
	_finish_reload_after_delay()

	return true


func _finish_reload_after_delay() -> void:
	await get_tree().create_timer(reload_time).timeout

	current_ammo += pending_reload_ammo
	reserve_ammo -= pending_reload_ammo
	pending_reload_ammo = 0

	current_ammo = clampi(
		current_ammo,
		0,
		magazine_size
	)

	reserve_ammo = maxi(
		0,
		reserve_ammo
	)

	is_reloading = false
	can_fire = true

	_emit_ammo_changed()
	reload_finished.emit()

	print(
		"[Pistol] Reload complete. Ammo: ",
		current_ammo,
		"/",
		magazine_size,
		" Reserve: ",
		reserve_ammo
	)


func add_reserve_ammo(amount: int) -> void:
	if amount <= 0:
		return

	reserve_ammo += amount
	_emit_ammo_changed()


func get_current_ammo() -> int:
	return current_ammo


func get_magazine_size() -> int:
	return magazine_size


func get_reload_time() -> float:
	return reload_time


func get_reserve_ammo() -> int:
	return reserve_ammo


func get_pistol_reserve_ammo() -> int:
	return reserve_ammo


# Kept only so older code that still calls this will not crash.
# It now returns reserve ammo, not magazine count.
func get_total_magazines() -> int:
	return reserve_ammo


func reset_weapon() -> void:
	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	pending_reload_ammo = 0
	is_reloading = false
	can_fire = true

	_emit_ammo_changed()
	
func get_save_data() -> Dictionary:
	return {
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo
	}

func load_save_data(save_data: Dictionary) -> void:
	current_ammo = int(
		save_data.get(
			"current_ammo",
			magazine_size
		)
	)

	reserve_ammo = int(
		save_data.get(
			"reserve_ammo",
			starting_reserve_ammo
		)
	)

	current_ammo = clampi(
		current_ammo,
		0,
		magazine_size
	)

	reserve_ammo = maxi(
		0,
		reserve_ammo
	)

	pending_reload_ammo = 0
	is_reloading = false
	can_fire = true

	_emit_ammo_changed()


func _emit_ammo_changed() -> void:
	ammo_changed.emit(
		current_ammo,
		magazine_size,
		reserve_ammo
	)
