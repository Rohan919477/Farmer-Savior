extends CanvasLayer

signal travel_requested(location_id: String)

@onready var current_location_label: Label = $RootControl/Panel/VBoxContainer/CurrentLocationLabel

@onready var farm_button: Button = $RootControl/Panel/VBoxContainer/FarmButton
@onready var forest_camp_button: Button = $RootControl/Panel/VBoxContainer/ForestCampButton
@onready var close_button: Button = $RootControl/Panel/VBoxContainer/CloseButton

var current_location_id: String = "farm"

func _ready() -> void:
	farm_button.pressed.connect(_on_farm_button_pressed)
	forest_camp_button.pressed.connect(_on_forest_camp_button_pressed)
	close_button.pressed.connect(close_menu)

	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()

func open_menu(
	new_current_location_id: String,
	unlocked_locations: Dictionary
) -> void:
	current_location_id = new_current_location_id
	visible = true

	current_location_label.text = (
		"Current Location: "
		+ get_location_display_name(current_location_id)
	)

	update_button(farm_button, "farm", unlocked_locations)
	update_button(forest_camp_button, "forest_camp", unlocked_locations)

func close_menu() -> void:
	visible = false

func _request_travel(location_id: String) -> void:
	travel_requested.emit(location_id)
	close_menu()

func update_button(
	button: Button,
	location_id: String,
	unlocked_locations: Dictionary
) -> void:
	var is_unlocked: bool = bool(
		unlocked_locations.get(location_id, false)
	)
	var display_name: String = get_location_display_name(location_id)

	if not is_unlocked:
		button.text = display_name + " (Locked)"
		button.disabled = true
	elif location_id == current_location_id:
		button.text = display_name + " (Current)"
		button.disabled = true
	else:
		button.text = display_name
		button.disabled = false

func get_location_display_name(location_id: String) -> String:
	match location_id:
		"farm":
			return "Farm"
		"house":
			return "House"
		"forest_camp":
			return "Forest Camp"
		_:
			return location_id

func _on_farm_button_pressed() -> void:
	_request_travel("farm")

func _on_forest_camp_button_pressed() -> void:
	_request_travel("forest_camp")
