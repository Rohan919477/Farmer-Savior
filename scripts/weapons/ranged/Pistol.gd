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

var base_fire_cooldown: float = 0.25
var base_magazine_size: int = 6
var base_reload_time: float = 1.5
var base_starting_reserve_ammo: int = 200

var can_fire: bool = true
var current_ammo: int = 0
var reserve_ammo: int = 0
var pending_reload_ammo: int = 0
var is_reloading: bool = false
var fire_cooldown_serial: int = 0
var reload_operation_serial: int = 0


func _ready() -> void:
	base_fire_cooldown = fire_cooldown
	base_magazine_size = magazine_size
	base_reload_time = reload_time
	base_starting_reserve_ammo = starting_reserve_ammo

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
		print("Pistol Bullet scene is not assigned.")
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
	_play_audio_sfx("pistol_shot")

	return true


func _begin_fire_cooldown() -> void:
	fire_cooldown_serial += 1
	var current_serial: int = fire_cooldown_serial

	await get_tree().create_timer(fire_cooldown, false).timeout

	if current_serial != fire_cooldown_serial:
		return

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
	reload_operation_serial += 1
	var current_reload_serial: int = reload_operation_serial

	_play_audio_sfx("reload")
	reload_started.emit(reload_time)
	_finish_reload_after_delay(current_reload_serial)

	return true


func _finish_reload_after_delay(reload_serial: int) -> void:
	await get_tree().create_timer(reload_time, false).timeout

	# Loads/new games can reset the same Pistol node while an older reload
	# coroutine is still waiting. Ignore stale operations so they cannot
	# consume the pending ammo belonging to a later reload.
	if reload_serial != reload_operation_serial:
		return

	if not is_reloading:
		return

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


func apply_magazine_size_bonus(amount: int) -> void:
	if amount <= 0:
		return

	magazine_size += amount
	current_ammo += amount
	current_ammo = clampi(current_ammo, 0, magazine_size)

	_emit_ammo_changed()

	print(
		"[Pistol Upgrade] Magazine size increased to ",
		magazine_size
	)


func apply_reload_time_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	reload_time = clampf(
		reload_time * multiplier,
		0.35,
		base_reload_time
	)

	print(
		"[Pistol Upgrade] Reload time is now ",
		reload_time
	)


func apply_fire_cooldown_multiplier(multiplier: float) -> void:
	if multiplier <= 0.0:
		return

	fire_cooldown = clampf(
		fire_cooldown * multiplier,
		0.08,
		base_fire_cooldown
	)

	print(
		"[Pistol Upgrade] Fire cooldown is now ",
		fire_cooldown
	)


func get_current_ammo() -> int:
	return current_ammo


func get_magazine_size() -> int:
	return magazine_size


func get_reload_time() -> float:
	return reload_time

func is_reload_in_progress() -> bool:
	return is_reloading

func get_reserve_ammo() -> int:
	return reserve_ammo


func get_pistol_reserve_ammo() -> int:
	return reserve_ammo


# Kept only so older code that still calls this will not crash.
# It now returns reserve ammo, not magazine count.
func get_total_magazines() -> int:
	return reserve_ammo


func cancel_transient_actions() -> void:
	# Map/forced world transitions keep the weapon's persistent ammo and upgrade
	# state, but an in-progress reload/cooldown must not leak into the destination.
	_invalidate_pending_weapon_operations()
	pending_reload_ammo = 0
	is_reloading = false
	can_fire = true


func reset_weapon() -> void:
	_invalidate_pending_weapon_operations()

	fire_cooldown = base_fire_cooldown
	magazine_size = base_magazine_size
	reload_time = base_reload_time
	starting_reserve_ammo = base_starting_reserve_ammo

	current_ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	pending_reload_ammo = 0
	is_reloading = false
	can_fire = true

	_emit_ammo_changed()
	
func get_save_data() -> Dictionary:
	return {
		"current_ammo": current_ammo,
		"reserve_ammo": reserve_ammo,
		"magazine_size": magazine_size,
		"reload_time": reload_time,
		"fire_cooldown": fire_cooldown,
		"starting_reserve_ammo": starting_reserve_ammo
	}

func load_save_data(save_data: Dictionary) -> void:
	_invalidate_pending_weapon_operations()

	magazine_size = int(
		save_data.get(
			"magazine_size",
			base_magazine_size
		)
	)

	reload_time = float(
		save_data.get(
			"reload_time",
			base_reload_time
		)
	)

	fire_cooldown = float(
		save_data.get(
			"fire_cooldown",
			base_fire_cooldown
		)
	)

	starting_reserve_ammo = int(
		save_data.get(
			"starting_reserve_ammo",
			base_starting_reserve_ammo
		)
	)

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

	magazine_size = maxi(1, magazine_size)
	reload_time = maxf(0.35, reload_time)
	fire_cooldown = maxf(0.08, fire_cooldown)

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




func _invalidate_pending_weapon_operations() -> void:
	# Incrementing the serials invalidates any async cooldown/reload callbacks
	# that were started before a New Game or Load reset this same node.
	fire_cooldown_serial += 1
	reload_operation_serial += 1


func _play_audio_sfx(sfx_name: String) -> void:
	var audio_manager: Node = get_tree().get_first_node_in_group(
		"audio_manager"
	)

	if audio_manager == null:
		return

	if audio_manager.has_method("play_sfx"):
		audio_manager.call("play_sfx", sfx_name)


func _emit_ammo_changed() -> void:
	ammo_changed.emit(
		current_ammo,
		magazine_size,
		reserve_ammo
	)
