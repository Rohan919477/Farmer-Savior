extends Node

signal location_loaded(location_id: String, loaded_map: Node)

@export var farm_scene: PackedScene
@export var house_scene: PackedScene
@export var nearby_field_scene: PackedScene

@export var map_container_path: NodePath
@export var player_path: NodePath
@export var map_menu_path: NodePath

var current_location_id: String = "farm"
var current_map: Node = null

var unlocked_locations := {
	"farm": true,
	"house": true,
	"nearby_field": true,
	"military_base": false,
	"city": false,
	"suburbs": false
}

var loading_save_data: bool = false

@onready var map_container: Node2D = get_node(map_container_path)
@onready var player: CharacterBody2D = get_node(player_path)
@onready var map_menu: Control = get_node(map_menu_path)

func _ready() -> void:
	add_to_group("map_manager")

	if map_menu != null:
		if map_menu.has_signal("travel_requested"):
			if not map_menu.travel_requested.is_connected(
				_on_map_menu_travel_requested
			):
				map_menu.travel_requested.connect(
					_on_map_menu_travel_requested
				)

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
		map_menu.open_menu(current_location_id, unlocked_locations)

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
	clear_current_map()

	var scene_to_load: PackedScene = get_scene_for_location(location_id)

	if scene_to_load == null:
		print("No scene assigned for location: ", location_id)
		return

	current_map = scene_to_load.instantiate()
	map_container.add_child(current_map)

	current_location_id = location_id
	position_player_at_spawn(spawn_id)

	print("Loaded location: ", location_id)

	location_loaded.emit(current_location_id, current_map)

func get_scene_for_location(location_id: String) -> PackedScene:
	match location_id:
		"farm":
			return farm_scene
		"house":
			return house_scene
		"nearby_field":
			return nearby_field_scene
		_:
			return null

func clear_current_map() -> void:
	if map_container == null:
		return

	for child in map_container.get_children():
		child.queue_free()

	current_map = null

func close_map_menu() -> void:
	if map_menu != null and map_menu.has_method("close_menu"):
		map_menu.close_menu()

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

	if spawn_point != null:
		player.global_position = spawn_point.global_position
	else:
		player.global_position = Vector2.ZERO

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

	loading_save_data = true
	load_location(saved_location_id, "DefaultSpawn")
	loading_save_data = false

	print("[Map] Loaded saved location: ", saved_location_id)

func reset_for_new_game() -> void:
	unlocked_locations = {
		"farm": true,
		"house": true,
		"nearby_field": true,
		"military_base": false,
		"city": false,
		"suburbs": false
	}

	loading_save_data = true
	load_location("farm", "DefaultSpawn")
	loading_save_data = false

	print("[Map] Reset for new game.")
