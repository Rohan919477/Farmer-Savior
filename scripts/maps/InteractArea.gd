extends Area2D

@export var interaction_name: String = "Interact"
@export var interaction_type: String = "map_menu"
@export var target_location_id: String = ""
@export var prompt_follows_player: bool = true
@export var prompt_offset: Vector2 = Vector2(-120.0, -86.0)

var player_nearby: bool = false
var nearby_player: Node = null

@onready var prompt_label: Label = get_node_or_null(
	"PromptLabel"
)
@onready var highlight_visual: CanvasItem = get_node_or_null(
	"HighlightVisual"
)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if prompt_label != null:
		prompt_label.text = _get_prompt_text()
		prompt_label.visible = false
		prompt_label.z_index = 500
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		prompt_label.add_theme_font_size_override("font_size", 18)
		prompt_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.92, 0.55, 1.0)
		)
		prompt_label.add_theme_color_override(
			"font_outline_color",
			Color(0.02, 0.0, 0.0, 1.0)
		)
		prompt_label.add_theme_constant_override("outline_size", 4)

	if highlight_visual != null:
		highlight_visual.visible = false


func _get_prompt_text() -> String:
	if interaction_type == "travel" and target_location_id == "house":
		return "Press E to enter House"

	return "Press E - " + interaction_name


func _update_prompt_position() -> void:
	if prompt_label == null:
		return

	if not prompt_follows_player:
		return

	if nearby_player == null or not is_instance_valid(nearby_player):
		return

	prompt_label.global_position = (
		nearby_player.global_position
		+ prompt_offset
	)

func is_gameplay_input_blocked() -> bool:
	var main_node: Node = get_tree().get_first_node_in_group(
		"main"
	)

	if main_node == null:
		return false

	if main_node.has_method("is_gameplay_input_blocked"):
		return bool(
			main_node.call("is_gameplay_input_blocked")
		)

	return false


func _process(_delta: float) -> void:
	_update_prompt_position()

	if not player_nearby:
		return

	if is_gameplay_input_blocked():
		return

	if Input.is_action_just_pressed("interact"):
		perform_interaction()


func play_player_interaction_pose() -> void:
	if nearby_player == null:
		return

	if nearby_player.has_method("play_interaction_pose"):
		nearby_player.call("play_interaction_pose")


func perform_interaction() -> void:
	var main: Node = get_tree().get_first_node_in_group(
		"main"
	)

	if main == null:
		print("Could not find Main.")
		return

	match interaction_type:
		"map_menu":
			if main.has_method("open_map_menu"):
				play_player_interaction_pose()
				print("Interacted with: ", interaction_name)
				main.open_map_menu()
			else:
				print("Main.open_map_menu() is missing.")

		"travel":
			if main.has_method("travel_to_location"):
				play_player_interaction_pose()
				print("Interacted with: ", interaction_name)
				main.travel_to_location(target_location_id)
			else:
				print("Main.travel_to_location() is missing.")

		"war_table":
			if main.has_method("open_defense_placement"):
				play_player_interaction_pose()
				print("Interacted with: ", interaction_name)
				main.open_defense_placement()
			else:
				print("War Table interaction is missing.")

		"workshop":
			if main.has_method("open_workshop"):
				play_player_interaction_pose()
				print("Interacted with: ", interaction_name)
				main.open_workshop()
			else:
				print("Workshop interaction is missing.")

		"bed":
			if main.has_method("sleep_at_bed"):
				play_player_interaction_pose()
				print("Interacted with: ", interaction_name)
				main.sleep_at_bed()
			else:
				print("Bed interaction is missing.")

		_:
			print(
				"Unknown interaction type: ",
				interaction_type
			)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_nearby = true
	nearby_player = body

	if prompt_label != null:
		prompt_label.text = _get_prompt_text()
	_update_prompt_position()
	show_interaction_feedback()

	print(
		"Press E to interact with ",
		interaction_name
	)


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	player_nearby = false

	if nearby_player == body:
		nearby_player = null

	hide_interaction_feedback()


func show_interaction_feedback() -> void:
	if prompt_label != null:
		prompt_label.visible = true

	if highlight_visual != null:
		highlight_visual.visible = false


func hide_interaction_feedback() -> void:
	if prompt_label != null:
		prompt_label.visible = false

	if highlight_visual != null:
		highlight_visual.visible = false
