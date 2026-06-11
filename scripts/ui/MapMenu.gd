extends Control

signal travel_requested(location_id: String)

@onready var current_location_label: Label = $Panel/VBoxContainer/CurrentLocationLabel

@onready var farm_button: Button = $Panel/VBoxContainer/FarmButton
@onready var nearby_field_button: Button = $Panel/VBoxContainer/NearbyFieldButton
@onready var military_base_button: Button = $Panel/VBoxContainer/MilitaryBaseButton
@onready var city_button: Button = $Panel/VBoxContainer/CityButton
@onready var suburbs_button: Button = $Panel/VBoxContainer/SuburbsButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

var current_location_id: String = "farm"

func _ready() -> void:
	farm_button.pressed.connect(_on_farm_button_pressed)
	nearby_field_button.pressed.connect(_on_nearby_field_button_pressed)
	military_base_button.pressed.connect(_on_military_base_button_pressed)
	city_button.pressed.connect(_on_city_button_pressed)
	suburbs_button.pressed.connect(_on_suburbs_button_pressed)
	close_button.pressed.connect(close_menu)

	visible = false

func open_menu(new_current_location_id: String, unlocked_locations: Dictionary) -> void:
	current_location_id = new_current_location_id
	visible = true

	current_location_label.text = "Current Location: " + get_location_display_name(current_location_id)

	update_button(farm_button, "farm", unlocked_locations)
	update_button(nearby_field_button, "nearby_field", unlocked_locations)
	update_button(military_base_button, "military_base", unlocked_locations)
	update_button(city_button, "city", unlocked_locations)
	update_button(suburbs_button, "suburbs", unlocked_locations)

func close_menu() -> void:
	visible = false

func _request_travel(location_id: String) -> void:
	travel_requested.emit(location_id)
	close_menu()

func update_button(button: Button, location_id: String, unlocked_locations: Dictionary) -> void:
	var is_unlocked: bool = bool(unlocked_locations.get(location_id, false))
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
		"nearby_field":
			return "Nearby Field"
		"military_base":
			return "Military Base"
		"city":
			return "City"
		"suburbs":
			return "Suburbs"
		_:
			return location_id

func _on_farm_button_pressed() -> void:
	_request_travel("farm")

func _on_nearby_field_button_pressed() -> void:
	_request_travel("nearby_field")

func _on_military_base_button_pressed() -> void:
	_request_travel("military_base")

func _on_city_button_pressed() -> void:
	_request_travel("city")

func _on_suburbs_button_pressed() -> void:
	_request_travel("suburbs")
