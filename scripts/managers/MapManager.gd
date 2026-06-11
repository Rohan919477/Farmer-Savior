extends Node

@export var farm_scene: PackedScene
@export var nearby_field_scene: PackedScene

@export var map_container_path: NodePath
@export var player_path: NodePath
@export var map_menu_path: NodePath

var current_location_id: String = "farm"
var current_map: Node = null

var unlocked_locations := {
	"farm": true,
	"nearby_field": true,
	"military_base": false,
	"city": false,
	"suburbs": false
}

@onready var map_container: Node2D = get_node(map_container_path)
@onready var player: CharacterBody2D = get_node(player_path)
@onready var map_menu: Control = get_node(map_menu_path)

func _ready() -> void:
	map_menu.travel_requested.connect(travel_to_location)
	load_location("farm", "DefaultSpawn")

func open_map_menu() -> void:
	map_menu.open_menu(current_location_id, unlocked_locations)

func travel_to_location(location_id: String) -> void:
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
	if current_location_id != "farm":
		print("Nightfall: forcing return to farm.")
		load_location("farm", "NightReturnSpawn")
	else:
		print("Nightfall: player already at farm.")

func load_location(location_id: String, spawn_id: String = "DefaultSpawn") -> void:
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

func get_scene_for_location(location_id: String) -> PackedScene:
	match location_id:
		"farm":
			return farm_scene
		"nearby_field":
			return nearby_field_scene
		_:
			return null

func clear_current_map() -> void:
	for child in map_container.get_children():
		child.queue_free()

func position_player_at_spawn(spawn_id: String) -> void:
	if current_map == null:
		return

	var spawn_path := "SpawnPoints/" + spawn_id
	var spawn_point := current_map.get_node_or_null(spawn_path)

	if spawn_point == null:
		spawn_point = current_map.get_node_or_null("SpawnPoints/DefaultSpawn")

	if spawn_point != null:
		player.global_position = spawn_point.global_position
	else:
		player.global_position = Vector2.ZERO
