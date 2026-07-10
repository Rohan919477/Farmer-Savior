extends CanvasLayer
class_name TitleScreenUI

signal play_pressed

@onready var root_control: Control = $RootControl
@onready var backdrop: ColorRect = $RootControl/Backdrop
@onready var center_panel: Panel = $RootControl/CenterPanel

@onready var title_label: Label = $RootControl/CenterPanel/TitleLabel
@onready var subtitle_label: Label = $RootControl/CenterPanel/SubtitleLabel

@onready var play_button: Button = $RootControl/CenterPanel/PlayButton
@onready var settings_button: Button = $RootControl/CenterPanel/SettingsButton
@onready var glossary_button: Button = $RootControl/CenterPanel/GlossaryButton
@onready var credits_button: Button = $RootControl/CenterPanel/CreditsButton

@onready var placeholder_label: Label = (
	$RootControl/CenterPanel/PlaceholderLabel
)

func _ready() -> void:
	if root_control == null:
		print(name, " is missing RootControl. Check the scene tree.")
		return
		
	process_mode = Node.PROCESS_MODE_ALWAYS

	root_control.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	root_control.visible = false
	root_control.mouse_filter = Control.MOUSE_FILTER_STOP

	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.color = Color(0.015, 0.02, 0.015, 1.0)

	_apply_panel_style()
	_setup_text()
	_setup_buttons()

	play_button.pressed.connect(_on_play_button_pressed)

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
	title_label.text = "FARMER SAVIOR"
	subtitle_label.text = (
		"A farm-defence survival prototype"
	)

	placeholder_label.text = (
		"Settings, Glossary, and Credits are planned "
		+ "for a later iteration."
	)

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title_label.add_theme_font_size_override("font_size", 34)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	placeholder_label.add_theme_font_size_override("font_size", 13)

func _setup_buttons() -> void:
	play_button.text = "PLAY"
	settings_button.text = "SETTINGS"
	glossary_button.text = "GLOSSARY"
	credits_button.text = "CREDITS"

	play_button.focus_mode = Control.FOCUS_NONE
	settings_button.focus_mode = Control.FOCUS_NONE
	glossary_button.focus_mode = Control.FOCUS_NONE
	credits_button.focus_mode = Control.FOCUS_NONE

	settings_button.tooltip_text = (
		"Placeholder — planned for a later iteration."
	)

	glossary_button.tooltip_text = (
		"Placeholder — discovered enemy records will be added later."
	)

	credits_button.tooltip_text = (
		"Placeholder — planned for a later iteration."
	)

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color(0.08, 0.10, 0.07, 1.0)
	panel_style.border_color = Color(0.70, 0.58, 0.24, 1.0)

	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)

	center_panel.add_theme_stylebox_override(
		"panel",
		panel_style
	)

func _layout_ui() -> void:
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size

	var panel_size := Vector2(440.0, 430.0)

	center_panel.position = (
		viewport_size - panel_size
	) * 0.5

	center_panel.size = panel_size

	title_label.position = Vector2(20.0, 34.0)
	title_label.size = Vector2(400.0, 48.0)

	subtitle_label.position = Vector2(20.0, 90.0)
	subtitle_label.size = Vector2(400.0, 30.0)

	var button_x: float = 70.0
	var button_width: float = 300.0
	var button_height: float = 42.0

	play_button.position = Vector2(button_x, 146.0)
	play_button.size = Vector2(button_width, button_height)

	settings_button.position = Vector2(button_x, 200.0)
	settings_button.size = Vector2(button_width, button_height)

	glossary_button.position = Vector2(button_x, 254.0)
	glossary_button.size = Vector2(button_width, button_height)

	credits_button.position = Vector2(button_x, 308.0)
	credits_button.size = Vector2(button_width, button_height)

	placeholder_label.position = Vector2(32.0, 366.0)
	placeholder_label.size = Vector2(376.0, 42.0)

func _on_play_button_pressed() -> void:
	hide_title_screen()

	get_tree().paused = false
	play_pressed.emit()
