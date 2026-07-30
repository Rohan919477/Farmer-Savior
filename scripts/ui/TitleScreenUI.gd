extends CanvasLayer
class_name TitleScreenUI

signal new_game_pressed
signal load_save_pressed
signal settings_pressed
signal glossary_pressed
signal credits_pressed

# Retained for compatibility with older references.
signal play_pressed


@onready var root_control: Control = $RootControl
@onready var background: TextureRect = $RootControl/Background
@onready var center_panel: Panel = $RootControl/CenterPanel

@onready var title_label: Label = (
	$RootControl/CenterPanel/TitleLabel
)
@onready var subtitle_label: Label = (
	$RootControl/CenterPanel/SubtitleLabel
)

@onready var play_button: Button = (
	$RootControl/CenterPanel/PlayButton
)
@onready var load_save_button: Button = (
	$RootControl/CenterPanel/LoadSaveButton
)
@onready var settings_button: Button = (
	$RootControl/CenterPanel/SettingsButton
)
@onready var glossary_button: Button = (
	$RootControl/CenterPanel/GlossaryButton
)
@onready var credits_button: Button = (
	$RootControl/CenterPanel/CreditsButton
)

@onready var placeholder_label: Label = (
	$RootControl/CenterPanel/PlaceholderLabel
)


func _ready() -> void:
	if root_control == null:
		print(
			name,
			" is missing RootControl. Check the scene tree."
		)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS

	root_control.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	root_control.visible = false
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP

	if background != null:
		background.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		# The artwork must not block button input.
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_setup_text()
	_setup_buttons()
	_connect_buttons()

	get_viewport().size_changed.connect(_layout_ui)

	call_deferred("show_title_screen")


func show_title_screen() -> void:
	root_control.visible = true
	_layout_ui()
	get_tree().paused = true


func hide_title_screen() -> void:
	root_control.visible = false


func is_title_screen_open() -> bool:
	return root_control.visible


func _setup_text() -> void:
	# The title and subtitle are already part of the artwork.
	if title_label != null:
		title_label.visible = false

	if subtitle_label != null:
		subtitle_label.visible = false

	# This label remains hidden until a placeholder button is pressed.
	if placeholder_label != null:
		placeholder_label.visible = false
		placeholder_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)


func _setup_buttons() -> void:
	play_button.text = "NEW GAME"
	load_save_button.text = "LOAD SAVE"
	settings_button.text = "SETTINGS"
	glossary_button.text = "GLOSSARY"
	credits_button.text = "CREDITS"

	play_button.focus_mode = Control.FOCUS_ALL
	load_save_button.focus_mode = Control.FOCUS_ALL
	settings_button.focus_mode = Control.FOCUS_ALL
	glossary_button.focus_mode = Control.FOCUS_ALL
	credits_button.focus_mode = Control.FOCUS_ALL

	load_save_button.tooltip_text = (
		"Load a saved game from Autosave or a manual slot."
	)

	settings_button.tooltip_text = (
		"Settings are planned for a later iteration."
	)

	glossary_button.tooltip_text = (
		"Discovered enemy records will be added later."
	)

	credits_button.tooltip_text = (
		"Credits are planned for a later iteration."
	)


func _connect_buttons() -> void:
	if not play_button.pressed.is_connected(
		_on_new_game_button_pressed
	):
		play_button.pressed.connect(
			_on_new_game_button_pressed
		)

	if not load_save_button.pressed.is_connected(
		_on_load_save_button_pressed
	):
		load_save_button.pressed.connect(
			_on_load_save_button_pressed
		)

	if not settings_button.pressed.is_connected(
		_on_settings_button_pressed
	):
		settings_button.pressed.connect(
			_on_settings_button_pressed
		)

	if not glossary_button.pressed.is_connected(
		_on_glossary_button_pressed
	):
		glossary_button.pressed.connect(
			_on_glossary_button_pressed
		)

	if not credits_button.pressed.is_connected(
		_on_credits_button_pressed
	):
		credits_button.pressed.connect(
			_on_credits_button_pressed
		)


func _layout_ui() -> void:
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	if background != null:
		background.position = Vector2.ZERO
		background.size = viewport_size

	var panel_size: Vector2 = Vector2(
		336.0,
		306.0
	)

	var edge_margin: float = 24.0

	center_panel.size = panel_size
	center_panel.position = Vector2(
		viewport_size.x
			- panel_size.x
			- edge_margin,
		viewport_size.y
			- panel_size.y
			- edge_margin
	)

	var button_position_x: float = 28.0
	var button_width: float = 280.0
	var button_height: float = 44.0

	play_button.position = Vector2(
		button_position_x,
		23.0
	)
	play_button.size = Vector2(
		button_width,
		button_height
	)

	load_save_button.position = Vector2(
		button_position_x,
		77.0
	)
	load_save_button.size = Vector2(
		button_width,
		button_height
	)

	settings_button.position = Vector2(
		button_position_x,
		131.0
	)
	settings_button.size = Vector2(
		button_width,
		button_height
	)

	glossary_button.position = Vector2(
		button_position_x,
		185.0
	)
	glossary_button.size = Vector2(
		button_width,
		button_height
	)

	credits_button.position = Vector2(
		button_position_x,
		239.0
	)
	credits_button.size = Vector2(
		button_width,
		button_height
	)


func _on_new_game_button_pressed() -> void:
	new_game_pressed.emit()


func _on_load_save_button_pressed() -> void:
	load_save_pressed.emit()


func _on_settings_button_pressed() -> void:
	settings_pressed.emit()
	_show_placeholder_message(
		"Settings are planned for a later iteration."
	)


func _on_glossary_button_pressed() -> void:
	glossary_pressed.emit()
	_show_placeholder_message(
		"Glossary is planned for a later iteration."
	)


func _on_credits_button_pressed() -> void:
	credits_pressed.emit()
	_show_placeholder_message(
		"Credits are planned for a later iteration."
	)


func _show_placeholder_message(message: String) -> void:
	# Keep the title menu visually clean for now.
	# The message is printed instead of displaying the old label.
	print("[Title Screen] ", message)
