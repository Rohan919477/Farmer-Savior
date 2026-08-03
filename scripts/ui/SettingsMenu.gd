extends Control
class_name SettingsMenu

signal closed

const CONFIG_PATH: String = "user://input_settings.cfg"

const ACTION_ITEMS: Array[Dictionary] = [
	{
		"action": "move_up",
		"label": "Move Up"
	},
	{
		"action": "move_down",
		"label": "Move Down"
	},
	{
		"action": "move_left",
		"label": "Move Left"
	},
	{
		"action": "move_right",
		"label": "Move Right"
	},
	{
		"action": "shoot",
		"label": "Shoot / Select"
	},
	{
		"action": "melee_attack",
		"label": "Hoe Attack"
	},
	{
		"action": "reload",
		"label": "Reload"
	},
	{
		"action": "interact",
		"label": "Interact"
	},
	{
		"action": "repair_fence",
		"label": "Repair"
	},
	{
		"action": "Inventory",
		"label": "Inventory"
	},
	{
		"action": "ui_cancel",
		"label": "Pause / Back"
	}
]

@onready var dim_overlay: ColorRect = $DimOverlay
@onready var panel: PanelContainer = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var help_label: Label = $Panel/MarginContainer/VBoxContainer/HelpLabel
@onready var actions_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ActionsScroll/ActionsContainer
@onready var waiting_label: Label = $Panel/MarginContainer/VBoxContainer/WaitingLabel
@onready var reset_defaults_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/ResetDefaultsButton
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/CloseButton

var rebind_buttons: Dictionary = {}
var waiting_for_action: String = ""
var waiting_for_label: String = ""


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP

	_setup_static_ui()
	_ensure_default_actions_exist()
	_apply_saved_bindings()
	_build_action_rows()
	_refresh_action_rows()

	if close_button != null:
		close_button.pressed.connect(close)

	if reset_defaults_button != null:
		reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)

	get_viewport().size_changed.connect(_layout_ui)
	call_deferred("_layout_ui")


func open() -> void:
	visible = true
	waiting_for_action = ""
	waiting_for_label = ""
	_refresh_action_rows()
	_layout_ui()
	move_to_front()

	if close_button != null:
		close_button.grab_focus()


func close() -> void:
	waiting_for_action = ""
	waiting_for_label = ""
	visible = false
	closed.emit()


func _setup_static_ui() -> void:
	if dim_overlay != null:
		dim_overlay.color = Color(0.0, 0.0, 0.0, 0.74)
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	if panel != null:
		var panel_style: StyleBoxFlat = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.055, 0.045, 0.035, 0.96)
		panel_style.border_color = Color(0.72, 0.55, 0.22, 1.0)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(12)
		panel.add_theme_stylebox_override("panel", panel_style)

	if title_label != null:
		title_label.text = "SETTINGS"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 28)
		title_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.88, 0.50, 1.0)
		)
		title_label.add_theme_color_override(
			"font_outline_color",
			Color(0.015, 0.008, 0.002, 1.0)
		)
		title_label.add_theme_constant_override("outline_size", 3)

	if help_label != null:
		help_label.text = (
			"Click a control, then press a new key or mouse button. "
			+ "The change is saved automatically."
		)
		help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		help_label.add_theme_font_size_override("font_size", 15)
		help_label.add_theme_color_override(
			"font_color",
			Color(0.92, 0.86, 0.72, 1.0)
		)

	if waiting_label != null:
		waiting_label.text = ""
		waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		waiting_label.add_theme_font_size_override("font_size", 16)
		waiting_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.78, 0.32, 1.0)
		)
		waiting_label.add_theme_color_override(
			"font_outline_color",
			Color(0.02, 0.0, 0.0, 1.0)
		)
		waiting_label.add_theme_constant_override("outline_size", 3)

	if reset_defaults_button != null:
		reset_defaults_button.text = "RESET DEFAULTS"
		reset_defaults_button.focus_mode = Control.FOCUS_ALL

	if close_button != null:
		close_button.text = "CLOSE"
		close_button.focus_mode = Control.FOCUS_ALL


func _layout_ui() -> void:
	if not is_inside_tree():
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	if dim_overlay != null:
		dim_overlay.position = Vector2.ZERO
		dim_overlay.size = viewport_size

	if panel != null:
		var panel_size: Vector2 = Vector2(
			minf(720.0, viewport_size.x - 80.0),
			minf(620.0, viewport_size.y - 80.0)
		)

		panel.size = panel_size
		panel.position = (viewport_size - panel_size) * 0.5


func _build_action_rows() -> void:
	if actions_container == null:
		return

	for child in actions_container.get_children():
		child.queue_free()

	rebind_buttons.clear()

	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))
		var display_name: String = str(item.get("label", action_name))

		var row: HBoxContainer = HBoxContainer.new()
		row.name = action_name + "Row"
		actions_container.add_child(row)

		var label: Label = Label.new()
		label.text = display_name
		label.custom_minimum_size = Vector2(220.0, 36.0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override(
			"font_color",
			Color(0.96, 0.90, 0.78, 1.0)
		)
		row.add_child(label)

		var bind_button: Button = Button.new()
		bind_button.name = action_name + "Button"
		bind_button.custom_minimum_size = Vector2(250.0, 36.0)
		bind_button.focus_mode = Control.FOCUS_ALL
		bind_button.pressed.connect(
			_begin_rebind.bind(action_name, display_name)
		)
		row.add_child(bind_button)

		rebind_buttons[action_name] = bind_button


func _refresh_action_rows() -> void:
	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))
		var button: Button = rebind_buttons.get(action_name, null)

		if button == null:
			continue

		button.text = _get_action_display_text(action_name)
		button.disabled = false

	if waiting_label == null:
		return

	if waiting_for_action.is_empty():
		waiting_label.text = ""
		return

	waiting_label.text = "Press a key or mouse button for: " + waiting_for_label


func _begin_rebind(action_name: String, display_name: String) -> void:
	waiting_for_action = action_name
	waiting_for_label = display_name
	_refresh_action_rows()

	var button: Button = rebind_buttons.get(action_name, null)

	if button != null:
		button.text = "PRESS NEW INPUT..."


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if waiting_for_action.is_empty():
		return

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if not key_event.pressed or key_event.echo:
			return

		if key_event.physical_keycode == KEY_ESCAPE and waiting_for_action != "ui_cancel":
			_cancel_rebind()
			get_viewport().set_input_as_handled()
			return

		_apply_rebind(waiting_for_action, _copy_key_event(key_event))
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if not mouse_event.pressed:
			return

		_apply_rebind(waiting_for_action, _copy_mouse_event(mouse_event))
		get_viewport().set_input_as_handled()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if waiting_for_action.is_empty() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _cancel_rebind() -> void:
	waiting_for_action = ""
	waiting_for_label = ""
	_refresh_action_rows()


func _apply_rebind(action_name: String, new_event: InputEvent) -> void:
	if action_name.is_empty():
		return

	_ensure_default_actions_exist()
	_remove_event_from_other_actions(action_name, new_event)

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, new_event)

	waiting_for_action = ""
	waiting_for_label = ""

	_save_current_bindings()
	_refresh_action_rows()


func _remove_event_from_other_actions(
	target_action: String,
	new_event: InputEvent
) -> void:
	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))

		if action_name == target_action:
			continue

		if not InputMap.has_action(action_name):
			continue

		for existing_event in InputMap.action_get_events(action_name):
			if _events_match(existing_event, new_event):
				InputMap.action_erase_event(action_name, existing_event)


func _on_reset_defaults_pressed() -> void:
	_apply_default_bindings()
	_save_current_bindings()
	waiting_for_action = ""
	waiting_for_label = ""
	_refresh_action_rows()


func _ensure_default_actions_exist() -> void:
	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))

		if action_name.is_empty():
			continue

		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)


func _apply_saved_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(CONFIG_PATH)

	if error != OK:
		return

	if not config.has_section("bindings"):
		return

	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))
		var encoded_events: Variant = config.get_value(
			"bindings",
			action_name,
			[]
		)

		var events: Array[InputEvent] = []

		if encoded_events is Array:
			for encoded_event in encoded_events:
				var decoded_event: InputEvent = _decode_event(str(encoded_event))

				if decoded_event != null:
					events.append(decoded_event)
		elif encoded_events is String:
			var decoded_single_event: InputEvent = _decode_event(str(encoded_events))

			if decoded_single_event != null:
				events.append(decoded_single_event)

		if events.is_empty():
			continue

		InputMap.action_erase_events(action_name)

		for input_event in events:
			InputMap.action_add_event(action_name, input_event)


func _save_current_bindings() -> void:
	var config: ConfigFile = ConfigFile.new()

	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))
		var encoded_events: Array[String] = []

		if InputMap.has_action(action_name):
			for input_event in InputMap.action_get_events(action_name):
				var encoded_event: String = _encode_event(input_event)

				if not encoded_event.is_empty():
					encoded_events.append(encoded_event)

		config.set_value("bindings", action_name, encoded_events)

	var save_error: Error = config.save(CONFIG_PATH)

	if save_error != OK:
		print("[Settings] Could not save input settings: ", save_error)


func _apply_default_bindings() -> void:
	_ensure_default_actions_exist()

	for item in ACTION_ITEMS:
		var action_name: String = str(item.get("action", ""))
		var default_events: Array[InputEvent] = _get_default_events_for_action(
			action_name
		)

		InputMap.action_erase_events(action_name)

		for input_event in default_events:
			InputMap.action_add_event(action_name, input_event)


func _get_default_events_for_action(action_name: String) -> Array[InputEvent]:
	match action_name:
		"move_up":
			return [
				_make_key_event(KEY_W),
				_make_key_event(KEY_UP)
			]
		"move_down":
			return [
				_make_key_event(KEY_S),
				_make_key_event(KEY_DOWN)
			]
		"move_left":
			return [
				_make_key_event(KEY_A),
				_make_key_event(KEY_LEFT)
			]
		"move_right":
			return [
				_make_key_event(KEY_D),
				_make_key_event(KEY_RIGHT)
			]
		"shoot":
			return [
				_make_mouse_button_event(MOUSE_BUTTON_LEFT),
				_make_key_event(KEY_Z)
			]
		"melee_attack":
			return [
				_make_mouse_button_event(MOUSE_BUTTON_RIGHT),
				_make_key_event(KEY_X)
			]
		"reload":
			return [
				_make_key_event(KEY_R)
			]
		"interact":
			return [
				_make_key_event(KEY_E)
			]
		"repair_fence":
			return [
				_make_key_event(KEY_F)
			]
		"Inventory":
			return [
				_make_key_event(KEY_I)
			]
		"ui_cancel":
			return [
				_make_key_event(KEY_ESCAPE)
			]

	return []


func _make_key_event(keycode_value: int) -> InputEventKey:
	var input_event: InputEventKey = InputEventKey.new()
	input_event.keycode = keycode_value
	input_event.physical_keycode = keycode_value
	return input_event


func _make_mouse_button_event(button_index_value: int) -> InputEventMouseButton:
	var input_event: InputEventMouseButton = InputEventMouseButton.new()
	input_event.button_index = button_index_value
	return input_event


func _copy_key_event(source_event: InputEventKey) -> InputEventKey:
	var copied_event: InputEventKey = InputEventKey.new()
	copied_event.keycode = source_event.keycode
	copied_event.physical_keycode = source_event.physical_keycode
	copied_event.key_label = source_event.key_label
	return copied_event


func _copy_mouse_event(source_event: InputEventMouseButton) -> InputEventMouseButton:
	var copied_event: InputEventMouseButton = InputEventMouseButton.new()
	copied_event.button_index = source_event.button_index
	return copied_event


func _get_action_display_text(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return "UNBOUND"

	var parts: Array[String] = []

	for input_event in InputMap.action_get_events(action_name):
		var display_text: String = _event_to_display_text(input_event)

		if not display_text.is_empty():
			parts.append(display_text)

	if parts.is_empty():
		return "UNBOUND"

	return " / ".join(parts)


func _event_to_display_text(input_event: InputEvent) -> String:
	if input_event is InputEventKey:
		var key_event: InputEventKey = input_event as InputEventKey
		var keycode_value: int = int(key_event.physical_keycode)

		if keycode_value == 0:
			keycode_value = int(key_event.keycode)

		if keycode_value == 0:
			return "Unknown Key"

		return OS.get_keycode_string(keycode_value)

	if input_event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
		return _mouse_button_to_text(mouse_event.button_index)

	return input_event.as_text()


func _mouse_button_to_text(button_index_value: int) -> String:
	match button_index_value:
		MOUSE_BUTTON_LEFT:
			return "Left Mouse"
		MOUSE_BUTTON_RIGHT:
			return "Right Mouse"
		MOUSE_BUTTON_MIDDLE:
			return "Middle Mouse"
		MOUSE_BUTTON_WHEEL_UP:
			return "Mouse Wheel Up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Mouse Wheel Down"
		MOUSE_BUTTON_XBUTTON1:
			return "Mouse Button 4"
		MOUSE_BUTTON_XBUTTON2:
			return "Mouse Button 5"

	return "Mouse Button " + str(button_index_value)


func _events_match(
	first_event: InputEvent,
	second_event: InputEvent
) -> bool:
	if first_event is InputEventKey and second_event is InputEventKey:
		var first_key: InputEventKey = first_event as InputEventKey
		var second_key: InputEventKey = second_event as InputEventKey

		var first_code: int = int(first_key.physical_keycode)
		var second_code: int = int(second_key.physical_keycode)

		if first_code == 0:
			first_code = int(first_key.keycode)

		if second_code == 0:
			second_code = int(second_key.keycode)

		return first_code == second_code

	if first_event is InputEventMouseButton and second_event is InputEventMouseButton:
		var first_mouse: InputEventMouseButton = first_event as InputEventMouseButton
		var second_mouse: InputEventMouseButton = second_event as InputEventMouseButton
		return first_mouse.button_index == second_mouse.button_index

	return false


func _encode_event(input_event: InputEvent) -> String:
	if input_event is InputEventKey:
		var key_event: InputEventKey = input_event as InputEventKey
		var keycode_value: int = int(key_event.physical_keycode)

		if keycode_value == 0:
			keycode_value = int(key_event.keycode)

		if keycode_value == 0:
			return ""

		return "key:" + str(keycode_value)

	if input_event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = input_event as InputEventMouseButton
		return "mouse:" + str(int(mouse_event.button_index))

	return ""


func _decode_event(encoded_event: String) -> InputEvent:
	if encoded_event.begins_with("key:"):
		var keycode_value: int = int(encoded_event.substr(4))

		if keycode_value == 0:
			return null

		return _make_key_event(keycode_value)

	if encoded_event.begins_with("mouse:"):
		var button_index_value: int = int(encoded_event.substr(6))

		if button_index_value <= 0:
			return null

		return _make_mouse_button_event(button_index_value)

	return null
