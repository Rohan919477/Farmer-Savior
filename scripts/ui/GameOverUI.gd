extends CanvasLayer
class_name GameOverUI

@onready var root_control: Control = $RootControl
@onready var backdrop: ColorRect = $RootControl/Backdrop
@onready var center_panel: Panel = $RootControl/CenterPanel

@onready var title_label: Label = $RootControl/CenterPanel/TitleLabel
@onready var reason_label: Label = $RootControl/CenterPanel/ReasonLabel

@onready var return_to_title_button: Button = (
	$RootControl/CenterPanel/ReturnToTitleButton
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
	backdrop.color = Color(0.04, 0.0, 0.0, 0.94)

	_apply_panel_style()

	title_label.text = "THE FARM HAS FALLEN"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 30)

	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.add_theme_font_size_override("font_size", 16)

	return_to_title_button.text = "RETURN TO TITLE"
	return_to_title_button.focus_mode = Control.FOCUS_NONE
	return_to_title_button.pressed.connect(
		_on_return_to_title_pressed
	)

	get_viewport().size_changed.connect(_layout_ui)

func show_game_over(
	reason: String = "You were overwhelmed by the blight."
) -> void:
	reason_label.text = reason

	root_control.visible = true
	_layout_ui()

	get_tree().paused = true

func is_game_over_open() -> bool:
	return root_control.visible

func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()

	panel_style.bg_color = Color(0.13, 0.025, 0.025, 1.0)
	panel_style.border_color = Color(0.86, 0.19, 0.15, 1.0)

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

	var panel_size := Vector2(470.0, 250.0)

	center_panel.position = (
		viewport_size - panel_size
	) * 0.5

	center_panel.size = panel_size

	title_label.position = Vector2(20.0, 38.0)
	title_label.size = Vector2(430.0, 46.0)

	reason_label.position = Vector2(36.0, 100.0)
	reason_label.size = Vector2(398.0, 44.0)

	return_to_title_button.position = Vector2(105.0, 178.0)
	return_to_title_button.size = Vector2(260.0, 42.0)

func _on_return_to_title_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
