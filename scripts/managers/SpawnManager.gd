extends Node

signal night_cleanup_cleared

@export var crop_mite_scene: PackedScene
@export var blight_pig_scene: PackedScene
@export var rot_crop_scene: PackedScene

@export var spawn_interval: float = 2.5
@export var base_max_active_enemies: int = 4
@export var minimum_spawn_distance_from_player: float = 220.0
@export var spawn_ring_thickness_cells: int = 2

@onready var map_manager: Node = get_parent().get_node("MapManager")
@onready var time_manager: Node = get_parent().get_node("TimeManager")
@onready var player: Node2D = get_parent().get_node("Player")
@onready var defense_manager: DefenseManager = get_parent().get_node("DefenseManager") as DefenseManager

var active_farm_map: Node = null
var active_enemies: Array[Node2D] = []
var spawn_cooldown: float = 0.0
var cleanup_cleared_emitted: bool = false

func _ready() -> void:
	if map_manager.has_signal("location_loaded"):
		map_manager.location_loaded.connect(_on_location_loaded)

	if time_manager.has_signal("day_started"):
		time_manager.day_started.connect(_on_day_started)

	if time_manager.has_signal("midnight_reached"):
		time_manager.midnight_reached.connect(_on_midnight_reached)

func _process(delta: float) -> void:
	if is_night_cleanup():
		check_night_cleanup_complete()
		return

	if not can_spawn_night_enemies():
		return

	spawn_cooldown -= delta

	if spawn_cooldown > 0.0:
		return

	if get_active_enemy_count() >= get_max_active_enemies():
		spawn_cooldown = 0.5
		return

	spawn_enemy()
	spawn_cooldown = spawn_interval

func can_spawn_night_enemies() -> bool:
	if active_farm_map == null:
		return false

	if map_manager.current_location_id != "farm":
		return false

	if not time_manager.has_method("is_active_night_wave"):
		return false

	return bool(time_manager.call("is_active_night_wave"))

func is_night_cleanup() -> bool:
	if not time_manager.has_method("is_night_cleanup"):
		return false

	return bool(time_manager.call("is_night_cleanup"))

func has_active_enemies() -> bool:
	return get_active_enemy_count() > 0

func get_active_enemy_count() -> int:
	var valid_enemies: Array[Node2D] = []

	for enemy in active_enemies:
		if is_instance_valid(enemy):
			valid_enemies.append(enemy)

	active_enemies = valid_enemies

	return active_enemies.size()

func get_max_active_enemies() -> int:
	var day_number: int = 1

	if time_manager.has_method("get_day_number"):
		day_number = int(time_manager.call("get_day_number"))

	return base_max_active_enemies + (day_number - 1)

func spawn_enemy() -> void:
	if active_farm_map == null:
		return

	var enemy_container: Node = active_farm_map.get_node_or_null("EnemyContainer")

	if enemy_container == null:
		print("Farm map is missing EnemyContainer.")
		return

	var spawn_position: Vector2 = get_valid_spawn_position()

	if spawn_position == Vector2.INF:
		print("No valid spawn-ring position was found.")
		return

	var enemy_scene: PackedScene = choose_enemy_scene()

	if enemy_scene == null:
		print("Enemy scene is not assigned.")
		return

	var enemy: Node2D = enemy_scene.instantiate() as Node2D

	if enemy == null:
		print("Could not instantiate enemy.")
		return

	enemy_container.add_child(enemy)
	enemy.global_position = spawn_position

	var day_number: int = 1

	if time_manager.has_method("get_day_number"):
		day_number = int(time_manager.call("get_day_number"))

	if enemy.has_method("apply_day_scaling"):
		enemy.call("apply_day_scaling", day_number)

	active_enemies.append(enemy)

	print("Spawned ", enemy.name, " at ", spawn_position)

func get_valid_spawn_position() -> Vector2:
	if defense_manager == null:
		return Vector2.INF

	var candidates: Array[Vector2] = []

	for row_index in range(1, defense_manager.grid_rows - 1):
		for column_index in range(1, defense_manager.grid_columns - 1):
			var grid_cell := Vector2i(column_index, row_index)

			if not is_spawn_ring_cell(grid_cell):
				continue

			if defense_manager.get_cell_type(grid_cell) != "open":
				continue

			if defense_manager.is_cell_occupied(grid_cell):
				continue

			var candidate_position: Vector2 = defense_manager.get_turret_position(grid_cell)

			if candidate_position.distance_to(player.global_position) < minimum_spawn_distance_from_player:
				continue

			candidates.append(candidate_position)

	if candidates.is_empty():
		return Vector2.INF

	var selected_position: Vector2 = candidates.pick_random()

	var horizontal_jitter: float = defense_manager.farm_grid_cell_size.x * 0.22
	var vertical_jitter: float = defense_manager.farm_grid_cell_size.y * 0.22

	return selected_position + Vector2(
		randf_range(-horizontal_jitter, horizontal_jitter),
		randf_range(-vertical_jitter, vertical_jitter)
	)

func is_spawn_ring_cell(grid_cell: Vector2i) -> bool:
	var left_distance: int = grid_cell.x - 1
	var right_distance: int = (defense_manager.grid_columns - 2) - grid_cell.x
	var top_distance: int = grid_cell.y - 1
	var bottom_distance: int = (defense_manager.grid_rows - 2) - grid_cell.y

	var edge_distance: int = mini(
		mini(left_distance, right_distance),
		mini(top_distance, bottom_distance)
	)

	return edge_distance < spawn_ring_thickness_cells

func choose_enemy_scene() -> PackedScene:
	match randi_range(0, 2):
		0:
			return crop_mite_scene
		1:
			return blight_pig_scene
		_:
			return rot_crop_scene

func check_night_cleanup_complete() -> void:
	if cleanup_cleared_emitted:
		return

	if has_active_enemies():
		return

	cleanup_cleared_emitted = true
	night_cleanup_cleared.emit()

func clear_active_enemies() -> void:
	for enemy in active_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()

	active_enemies.clear()

func _on_location_loaded(location_id: String, loaded_map: Node) -> void:
	clear_active_enemies()

	if location_id == "farm":
		active_farm_map = loaded_map
	else:
		active_farm_map = null

func _on_midnight_reached() -> void:
	cleanup_cleared_emitted = false
	spawn_cooldown = 0.0
	check_night_cleanup_complete()

func _on_day_started(_day_number: int) -> void:
	clear_active_enemies()
	spawn_cooldown = 0.0
	cleanup_cleared_emitted = false
