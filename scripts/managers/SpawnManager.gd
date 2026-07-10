extends Node

signal night_cleanup_cleared

@export var crop_mite_scene: PackedScene
@export var blight_pig_scene: PackedScene
@export var rot_crop_scene: PackedScene
@export var tutorial_boss_scene: PackedScene

@export var spawn_interval: float = 2.5
@export var base_max_active_enemies: int = 4

@export var minimum_spawn_distance_from_player: float = 220.0
@export var exterior_spawn_min_distance_from_fence: float = 300.0
@export var exterior_spawn_max_distance_from_fence: float = 440.0
@export var exterior_spawn_edge_padding: float = 64.0
@export var spawn_position_attempts: int = 30

@onready var map_manager: Node = get_parent().get_node("MapManager")
@onready var time_manager: Node = get_parent().get_node("TimeManager")
@onready var player: Node2D = get_parent().get_node("Player")
@onready var defense_manager: DefenseManager = (
	get_parent().get_node("DefenseManager") as DefenseManager
)

var active_farm_map: Node = null
var active_enemies: Array[Node2D] = []

var spawn_cooldown: float = 0.0
var cleanup_cleared_emitted: bool = false

func _ready() -> void:
	add_to_group("spawn_manager")
	
	if map_manager.has_signal("location_loaded"):
		map_manager.location_loaded.connect(_on_location_loaded)

	if time_manager.has_signal("day_started"):
		time_manager.day_started.connect(_on_day_started)

	if time_manager.has_signal("midnight_reached"):
		time_manager.midnight_reached.connect(_on_midnight_reached)

func _process(delta: float) -> void:
	if _is_tutorial_world_soft_paused():
		return

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
	var spawn_position: Vector2 = get_valid_spawn_position()

	if spawn_position == Vector2.INF:
		print("No valid exterior spawn position was found.")
		return

	var enemy_scene: PackedScene = choose_enemy_scene()

	if enemy_scene == null:
		print("Enemy scene is not assigned.")
		return

	spawn_specific_enemy_scene(enemy_scene, spawn_position, true)
	
func spawn_specific_enemy_scene(
	enemy_scene: PackedScene,
	spawn_position: Vector2,
	apply_scaling: bool = true
) -> Node2D:
	if active_farm_map == null:
		print("Cannot spawn enemy. Farm map is not active.")
		return null

	if enemy_scene == null:
		print("Cannot spawn enemy. Scene is not assigned.")
		return null

	var enemy_container: Node = active_farm_map.get_node_or_null(
		"EnemyContainer"
	)

	if enemy_container == null:
		print("Farm map is missing EnemyContainer.")
		return null

	var enemy: Node2D = enemy_scene.instantiate() as Node2D

	if enemy == null:
		print("Could not instantiate enemy.")
		return null

	enemy_container.add_child(enemy)
	enemy.global_position = spawn_position

	if apply_scaling:
		var day_number: int = 1

		if time_manager.has_method("get_day_number"):
			day_number = int(time_manager.call("get_day_number"))

		if enemy.has_method("apply_day_scaling"):
			enemy.call("apply_day_scaling", day_number)

	active_enemies.append(enemy)

	print("Spawned ", enemy.name, " at ", spawn_position)

	return enemy
	
func spawn_tutorial_boss() -> Node2D:
	if tutorial_boss_scene == null:
		print("Tutorial boss scene is not assigned.")
		return null

	var boss_position: Vector2 = get_tutorial_boss_spawn_position()

	var boss: Node2D = spawn_specific_enemy_scene(
		tutorial_boss_scene,
		boss_position,
		false
	)

	if boss != null:
		print("Spawned exactly one Tutorial Boss.")

	return boss
	
func get_tutorial_boss_spawn_position() -> Vector2:
	if defense_manager == null:
		return Vector2.ZERO

	var farm_left: float = defense_manager.farm_grid_origin.x
	var farm_top: float = defense_manager.farm_grid_origin.y

	var farm_right: float = (
		farm_left
		+ float(defense_manager.grid_columns)
		* defense_manager.farm_grid_cell_size.x
	)

	var farm_bottom: float = (
		farm_top
		+ float(defense_manager.grid_rows)
		* defense_manager.farm_grid_cell_size.y
	)

	var spawn_x: float = (farm_left + farm_right) * 0.5
	var spawn_y: float = (
		farm_bottom
		+ defense_manager.farm_grid_cell_size.y * 9.0
	)

	return Vector2(spawn_x, spawn_y)
	
func spawn_training_crop_mite() -> Node2D:
	if crop_mite_scene == null:
		print("Crop Mite scene is not assigned.")
		return null

	if player == null:
		print("Player reference is missing.")
		return null

	var spawn_position: Vector2 = (
		player.global_position
		+ Vector2(170.0, 0.0)
	)

	var enemy: Node2D = spawn_specific_enemy_scene(
		crop_mite_scene,
		spawn_position,
		false
	)

	if enemy == null:
		return null

	enemy.set("guaranteed_seed_drops", 1)
	enemy.set("guaranteed_scrap_drops", 1)

	enemy.set("seed_drop_chance", 0.0)
	enemy.set("scrap_drop_chance", 0.0)

	print("[Tutorial] Training Crop Mite will guarantee 1 Seed and 1 Scrap.")

	return enemy

func get_valid_spawn_position() -> Vector2:
	if defense_manager == null or player == null:
		return Vector2.INF

	for attempt in range(spawn_position_attempts):
		var candidate_position: Vector2 = (
			get_random_exterior_spawn_position()
		)

		if candidate_position.distance_to(player.global_position) < (
			minimum_spawn_distance_from_player
		):
			continue

		return candidate_position

	return Vector2.INF

func get_random_exterior_spawn_position() -> Vector2:
	var farm_left: float = defense_manager.farm_grid_origin.x
	var farm_top: float = defense_manager.farm_grid_origin.y

	var farm_right: float = (
		farm_left
		+ float(defense_manager.grid_columns)
		* defense_manager.farm_grid_cell_size.x
	)

	var farm_bottom: float = (
		farm_top
		+ float(defense_manager.grid_rows)
		* defense_manager.farm_grid_cell_size.y
	)

	var minimum_distance: float = minf(
		exterior_spawn_min_distance_from_fence,
		exterior_spawn_max_distance_from_fence
	)

	var maximum_distance: float = maxf(
		exterior_spawn_min_distance_from_fence,
		exterior_spawn_max_distance_from_fence
	)

	var spawn_side: int = randi_range(0, 3)

	match spawn_side:
		0:
			return Vector2(
				randf_range(
					farm_left + exterior_spawn_edge_padding,
					farm_right - exterior_spawn_edge_padding
				),
				randf_range(
					farm_top - maximum_distance,
					farm_top - minimum_distance
				)
			)

		1:
			return Vector2(
				randf_range(
					farm_left + exterior_spawn_edge_padding,
					farm_right - exterior_spawn_edge_padding
				),
				randf_range(
					farm_bottom + minimum_distance,
					farm_bottom + maximum_distance
				)
			)

		2:
			return Vector2(
				randf_range(
					farm_left - maximum_distance,
					farm_left - minimum_distance
				),
				randf_range(
					farm_top + exterior_spawn_edge_padding,
					farm_bottom - exterior_spawn_edge_padding
				)
			)

		_:
			return Vector2(
				randf_range(
					farm_right + minimum_distance,
					farm_right + maximum_distance
				),
				randf_range(
					farm_top + exterior_spawn_edge_padding,
					farm_bottom - exterior_spawn_edge_padding
				)
			)

func choose_enemy_scene() -> PackedScene:
	var enemy_options: Array[PackedScene] = []

	if crop_mite_scene != null:
		enemy_options.append(crop_mite_scene)

	if blight_pig_scene != null:
		enemy_options.append(blight_pig_scene)

	if rot_crop_scene != null:
		enemy_options.append(rot_crop_scene)

	if enemy_options.is_empty():
		return null

	return enemy_options.pick_random()

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
	
func _is_tutorial_world_soft_paused() -> bool:
	var tutorial_manager: Node = get_tree().get_first_node_in_group(
		"tutorial_manager"
	)

	if tutorial_manager == null:
		return false

	if tutorial_manager.has_method("is_world_soft_paused"):
		return bool(tutorial_manager.call("is_world_soft_paused"))

	return false
