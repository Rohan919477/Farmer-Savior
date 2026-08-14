extends Node

# Compatibility signal: this still means "the player has arrived at this
# location". Existing UI/Main code can continue listening to it.
signal location_loaded(location_id: String, loaded_map: Node)

# New persistent-world signal: emitted only when a map scene instance is first
# created and added to MapContainer.
signal persistent_map_loaded(location_id: String, loaded_map: Node)

@export var farm_scene: PackedScene
@export var house_scene: PackedScene
@export var forest_camp_scene: PackedScene

@export var map_container_path: NodePath
@export var player_path: NodePath
@export var map_menu_path: NodePath

# Persistent maps share one 2D world, so each map receives a distant world slot
# to prevent collisions/rendering from different locations overlapping.
@export var persistent_map_spacing: float = 100000.0

var current_location_id: String = "farm"
var current_map: Node = null
var loaded_maps: Dictionary = {}

var unlocked_locations := {
	"farm": true,
	"house": true,
	"forest_camp": true
}

var loading_save_data: bool = false

@onready var map_container: Node2D = get_node(map_container_path)
@onready var player: CharacterBody2D = get_node(player_path)
@onready var map_menu: Node = get_node(map_menu_path)

func _ready() -> void:
	add_to_group("map_manager")

	if map_menu != null and map_menu.has_signal("travel_requested"):
		var travel_callable := Callable(
			self,
			"_on_map_menu_travel_requested"
		)

		if not map_menu.is_connected("travel_requested", travel_callable):
			map_menu.connect("travel_requested", travel_callable)

	# The Farm is the persistent simulation anchor and must always exist even
	# while the player is inside another location.
	_ensure_location_loaded("farm")
	load_location("farm", "DefaultSpawn")

func _on_map_menu_travel_requested(location_id: String) -> void:
	# Route player-selected Map Table travel through Main so global gameplay
	# rules (including active-night restrictions) cannot be bypassed by the UI.
	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node != null and main_node.has_method("travel_to_location"):
		main_node.call("travel_to_location", location_id)
		return

	travel_to_location(location_id)

func open_map_menu() -> void:
	if map_menu == null:
		return

	if map_menu.has_method("open_menu"):
		map_menu.call("open_menu", current_location_id, unlocked_locations)

func travel_to_location(location_id: String) -> void:
	if _is_house_entry_blocked_by_main(location_id):
		return

	if not unlocked_locations.has(location_id):
		print("Unknown location: ", location_id)
		return

	if unlocked_locations[location_id] == false:
		print("Location locked: ", location_id)
		return

	if location_id == current_location_id:
		print("Already at location: ", location_id)
		return

	load_location(location_id, "DefaultSpawn")

func force_return_to_farm() -> void:
	close_map_menu()

	if current_location_id != "farm":
		print("Nightfall: forcing return to farm.")
		load_location("farm", "NightReturnSpawn")
	else:
		print("Nightfall: player already at farm.")

func load_location(
	location_id: String,
	spawn_id: String = "DefaultSpawn"
) -> void:
	if _is_house_entry_blocked_by_main(location_id):
		return

	close_map_menu()

	var loaded_map: Node = _ensure_location_loaded(location_id)

	if loaded_map == null:
		print("No scene assigned for location: ", location_id)
		return

	# Persistent-world transition: do not free the previous scene. Switch only
	# which loaded map is considered the player's current location.
	current_location_id = location_id
	current_map = loaded_map
	position_player_at_spawn(spawn_id)

	print(
		"Activated persistent location: ",
		location_id,
		" | Loaded maps: ",
		loaded_maps.size()
	)

	location_loaded.emit(current_location_id, current_map)

func _ensure_location_loaded(location_id: String) -> Node:
	if loaded_maps.has(location_id):
		var existing_map: Node = loaded_maps.get(location_id) as Node

		if existing_map != null and is_instance_valid(existing_map):
			return existing_map

		loaded_maps.erase(location_id)

	var scene_to_load: PackedScene = get_scene_for_location(location_id)

	if scene_to_load == null:
		return null

	var loaded_map: Node = scene_to_load.instantiate()

	if loaded_map == null:
		return null

	# Assign the world slot before entering the tree so any map-local _ready()
	# code observes the correct global transform immediately.
	if loaded_map is Node2D:
		var loaded_map_2d: Node2D = loaded_map as Node2D
		loaded_map_2d.position = get_map_world_offset(location_id)

	map_container.add_child(loaded_map)
	loaded_maps[location_id] = loaded_map
	persistent_map_loaded.emit(location_id, loaded_map)

	print(
		"Loaded persistent map: ",
		location_id,
		" at ",
		get_map_world_offset(location_id)
	)

	return loaded_map

func get_scene_for_location(location_id: String) -> PackedScene:
	match location_id:
		"farm":
			return farm_scene
		"house":
			return house_scene
		"forest_camp":
			return forest_camp_scene
		_:
			return null

func get_loaded_map(location_id: String) -> Node:
	if not loaded_maps.has(location_id):
		return null

	var loaded_map: Node = loaded_maps.get(location_id) as Node

	if loaded_map == null or not is_instance_valid(loaded_map):
		loaded_maps.erase(location_id)
		return null

	return loaded_map

func get_loaded_location_ids() -> Array[String]:
	var location_ids: Array[String] = []

	for location_id_variant in loaded_maps.keys():
		var location_id: String = str(location_id_variant)
		var loaded_map: Node = get_loaded_map(location_id)

		if loaded_map != null:
			location_ids.append(location_id)

	return location_ids

func is_location_loaded(location_id: String) -> bool:
	return get_loaded_map(location_id) != null

func get_map_world_offset(location_id: String) -> Vector2:
	match location_id:
		"farm":
			return Vector2.ZERO
		"house":
			return Vector2(persistent_map_spacing, 0.0)
		"forest_camp":
			return Vector2(-persistent_map_spacing, 0.0)
		_:
			return Vector2.ZERO

func get_location_id_for_node(node: Node) -> String:
	if node == null:
		return ""

	for location_id_variant in loaded_maps.keys():
		var location_id: String = str(location_id_variant)
		var loaded_map: Node = get_loaded_map(location_id)

		if loaded_map == null:
			continue

		if loaded_map == node or loaded_map.is_ancestor_of(node):
			return location_id

	return ""

func map_to_world_position(
	location_id: String,
	map_local_position: Vector2
) -> Vector2:
	var loaded_map: Node = get_loaded_map(location_id)

	if loaded_map is Node2D:
		return (loaded_map as Node2D).to_global(map_local_position)

	return map_local_position + get_map_world_offset(location_id)

func world_to_map_position(
	location_id: String,
	world_position: Vector2
) -> Vector2:
	var loaded_map: Node = get_loaded_map(location_id)

	if loaded_map is Node2D:
		return (loaded_map as Node2D).to_local(world_position)

	return world_position - get_map_world_offset(location_id)

# Compatibility method retained for older callers. Persistent travel no longer
# invokes this; explicit callers can still clear every map when truly required.
func clear_current_map() -> void:
	print(
		"[Map] clear_current_map() ignored: persistent maps remain loaded."
	)

func clear_all_loaded_maps() -> void:
	for location_id_variant in loaded_maps.keys():
		var loaded_map: Node = loaded_maps.get(location_id_variant) as Node

		if loaded_map != null and is_instance_valid(loaded_map):
			loaded_map.queue_free()

	loaded_maps.clear()
	current_map = null

func close_map_menu() -> void:
	if map_menu != null and map_menu.has_method("close_menu"):
		map_menu.call("close_menu")

func is_current_location(location_id: String) -> bool:
	return current_location_id == location_id

func get_current_location_id() -> String:
	return current_location_id

func position_player_at_spawn(spawn_id: String) -> void:
	if current_map == null:
		return

	var spawn_path := "SpawnPoints/" + spawn_id
	var spawn_point := current_map.get_node_or_null(spawn_path)

	if spawn_point == null:
		spawn_point = current_map.get_node_or_null(
			"SpawnPoints/DefaultSpawn"
		)

	if spawn_point is Node2D:
		player.global_position = (spawn_point as Node2D).global_position
	else:
		player.global_position = get_map_world_offset(current_location_id)

func unlock_location(location_id: String) -> void:
	if not unlocked_locations.has(location_id):
		return

	unlocked_locations[location_id] = true

func lock_location(location_id: String) -> void:
	if not unlocked_locations.has(location_id):
		return

	unlocked_locations[location_id] = false

func _is_house_entry_blocked_by_main(location_id: String) -> bool:
	if loading_save_data:
		return false

	if location_id != "house":
		return false

	var main_node: Node = get_tree().get_first_node_in_group("main")

	if main_node == null:
		return false

	if not main_node.has_method("is_house_entry_locked_by_night"):
		return false

	var house_locked: bool = bool(
		main_node.call("is_house_entry_locked_by_night")
	)

	if not house_locked:
		return false

	if main_node.has_method("show_night_house_locked_message"):
		main_node.call("show_night_house_locked_message")

	return true

func get_save_data() -> Dictionary:
	return {
		"current_location_id": current_location_id,
		"unlocked_locations": unlocked_locations.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	var saved_unlocked_locations: Dictionary = data.get(
		"unlocked_locations",
		{}
	)

	for location_id_variant in saved_unlocked_locations.keys():
		var location_id: String = str(location_id_variant)

		if not unlocked_locations.has(location_id):
			continue

		unlocked_locations[location_id] = bool(
			saved_unlocked_locations.get(location_id, false)
		)

	var saved_location_id: String = str(
		data.get("current_location_id", "farm")
	)

	if saved_location_id.is_empty():
		saved_location_id = "farm"

	if not unlocked_locations.has(saved_location_id):
		saved_location_id = "farm"

	if get_scene_for_location(saved_location_id) == null:
		saved_location_id = "farm"

	# Farm stays loaded as the simulation anchor even when a save was made in
	# another map.
	_ensure_location_loaded("farm")

	loading_save_data = true
	load_location(saved_location_id, "DefaultSpawn")
	loading_save_data = false

	print("[Map] Loaded saved location: ", saved_location_id)

func reset_for_new_game() -> void:
	unlocked_locations = {
		"farm": true,
		"house": true,
		"forest_camp": true
	}

	_ensure_location_loaded("farm")

	loading_save_data = true
	load_location("farm", "DefaultSpawn")
	loading_save_data = false

	print("[Map] Reset for new game.")
