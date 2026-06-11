extends Node2D

@onready var map_manager: Node = $MapManager

func _ready() -> void:
	add_to_group("main")

func open_map_menu() -> void:
	map_manager.open_map_menu()
