extends CanvasLayer
class_name PauseMenuUI

signal resume_requested
signal settings_requested
signal load_save_requested
signal back_to_title_requested

@onready var resume_button: Button = $Resume
@onready var settings_button: Button = $Settings
@onready var load_save_button: Button = $"Load Save"
@onready var back_to_title_button: Button = $"Back To Title"

var pause_open: bool = false

var backdrop: ColorRect
var confirm_panel: Panel
var confirm_label: Label
var confirm_yes_button: Button
var confirm_no_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_extra_ui()
	_setup_buttons()
	_connect_buttons()

	get_viewport().size_changed.connect(_layout_ui)

	close_pause_menu(false)

func open_pause_menu() -> void:
	pause_open = true
	get_tree().paused = true

	backdrop.visible = true
	resume_button.visible = true
	settings_button.visible = true
	load_save_button.visible = true
	back_to_title_button.visible = true
	confirm_panel.visible = false

	_layout_ui()

func close_pause_menu(resume_game: bool = true) -> void:
	pause_open = false

	if backdrop != null:
		backdrop.visible = false

	if resume_button != null:
		resume_button.visible = false

	if settings_button != null:
		settings_button.visible = false

	if load_save_button != null:
		load_save_button.visible = false

	if back_to_title_button != null:
		back_to_title_button.visible = false

	if confirm_panel != null:
		confirm_panel.visible = false

	if resume_game:
		get_tree().paused = false

func is_pause_menu_open() -> bool:
	return pause_open

func _unhandled_input(event: InputEvent) -> void:
	if not pause_open:
		return

	if event.is_action_pressed("ui_cancel"):
		close_pause_menu(true)
		resume_requested.emit()

func _build_extra_ui() -> void:
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	add_child(backdrop)
	move_child(backdrop, 0)

	backdrop.color = Color(0.0, 0.0, 0.0, 0.70)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP

	confirm_panel = Panel.new()
	confirm_panel.name = "ConfirmPanel"
	add_child(confirm_panel)

	confirm_label = Label.new()
	confirm_label.name = "ConfirmLabel"
	confirm_panel.add_child(confirm_label)

	confirm_yes_button = Button.new()
	confirm_yes_button.name = "ConfirmYesButton"
	confirm_panel.add_child(confirm_yes_button)

	confirm_no_button = Button.new()
	confirm_no_button.name = "ConfirmNoButton"
	confirm_panel.add_child(confirm_no_button)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.08, 0.045, 1.0)
	confirm_style.border_color = Color(0.90, 0.60, 0.20, 1.0)
	confirm_style.set_border_width_all(2)
	confirm_style.set_corner_radius_all(14)

	confirm_panel.add_theme_stylebox_override("panel", confirm_style)

func _setup_buttons() -> void:
	resume_button.text = "RESUME"
	settings_button.text = "SETTINGS"
	load_save_button.text = "LOAD SAVE"
	back_to_title_button.text = "BACK TO TITLE"

	resume_button.focus_mode = Control.FOCUS_NONE
	settings_button.focus_mode = Control.FOCUS_NONE
	load_save_button.focus_mode = Control.FOCUS_NONE
	back_to_title_button.focus_mode = Control.FOCUS_NONE

	confirm_label.text = (
		"Return to title?\n"
		+ "Any unsaved progress will be lost."
	)
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.add_theme_font_size_override("font_size", 16)

	confirm_yes_button.text = "YES, BACK TO TITLE"
	confirm_no_button.text = "NO"

	confirm_yes_button.focus_mode = Control.FOCUS_NONE
	confirm_no_button.focus_mode = Control.FOCUS_NONE

func _connect_buttons() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	load_save_button.pressed.connect(_on_load_save_pressed)
	back_to_title_button.pressed.connect(_on_back_to_title_pressed)

	confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)
	confirm_no_button.pressed.connect(_on_confirm_no_pressed)

func _layout_ui() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	backdrop.position = Vector2.ZERO
	backdrop.size = viewport_size

	var button_width: float = 320.0
	var button_height: float = 44.0
	var button_x: float = (viewport_size.x - button_width) * 0.5
	var first_y: float = (viewport_size.y - 240.0) * 0.5
	var gap: float = 56.0

	resume_button.position = Vector2(button_x, first_y)
	resume_button.size = Vector2(button_width, button_height)

	settings_button.position = Vector2(button_x, first_y + gap)
	settings_button.size = Vector2(button_width, button_height)

	load_save_button.position = Vector2(button_x, first_y + gap * 2.0)
	load_save_button.size = Vector2(button_width, button_height)

	back_to_title_button.position = Vector2(button_x, first_y + gap * 3.0)
	back_to_title_button.size = Vector2(button_width, button_height)

	var panel_size: Vector2 = Vector2(460.0, 210.0)

	confirm_panel.position = (viewport_size - panel_size) * 0.5
	confirm_panel.size = panel_size

	confirm_label.position = Vector2(24.0, 24.0)
	confirm_label.size = Vector2(412.0, 74.0)

	confirm_yes_button.position = Vector2(42.0, 124.0)
	confirm_yes_button.size = Vector2(190.0, 42.0)

	confirm_no_button.position = Vector2(244.0, 124.0)
	confirm_no_button.size = Vector2(174.0, 42.0)

func _on_resume_pressed() -> void:
	close_pause_menu(true)
	resume_requested.emit()

func _on_settings_pressed() -> void:
	settings_requested.emit()

func _on_load_save_pressed() -> void:
	load_save_requested.emit()

func _on_back_to_title_pressed() -> void:
	confirm_panel.visible = true

func _on_confirm_yes_pressed() -> void:
	back_to_title_requested.emit()

func _on_confirm_no_pressed() -> void:
	confirm_panel.visible = false
