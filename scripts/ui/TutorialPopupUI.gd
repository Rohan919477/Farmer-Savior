extends CanvasLayer
class_name TutorialPopupUI

signal acknowledged(tutorial_step: String)

@onready var root_control: Control = $RootControl
@onready var dim_overlay: ColorRect = $RootControl/DimOverlay
@onready var bubble_tail: Polygon2D = $RootControl/BubbleTail
@onready var bubble_panel: Panel = $RootControl/BubblePanel

@onready var explanation_label: Label = (
	$RootControl/BubblePanel/ExplanationLabel
)

@onready var understood_button: Button = (
	$RootControl/UnderstoodButton
)

var current_tutorial_step: String = ""

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

	dim_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	dim_overlay.color = Color(0.0, 0.0, 0.0, 0.20)

	explanation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.add_theme_font_size_override("font_size", 17)
	explanation_label.add_theme_color_override(
		"font_color",
		Color(0.04, 0.04, 0.04, 1.0)
	)

	understood_button.text = "UNDERSTOOD"
	understood_button.focus_mode = Control.FOCUS_NONE
	understood_button.pressed.connect(_on_understood_pressed)

	_apply_bubble_style()

	get_viewport().size_changed.connect(_layout_popup)

func show_popup(
	tutorial_step: String,
	message: String
) -> void:
	current_tutorial_step = tutorial_step
	explanation_label.text = message

	root_control.visible = true
	_layout_popup()

	get_tree().paused = true

func hide_popup(
	resume_simulation: bool = true
) -> void:
	root_control.visible = false

	if resume_simulation:
		get_tree().paused = false

func is_popup_open() -> bool:
	return root_control.visible

func _apply_bubble_style() -> void:
	var bubble_style := StyleBoxFlat.new()

	bubble_style.bg_color = Color(0.97, 0.94, 0.84, 1.0)
	bubble_style.border_color = Color(0.04, 0.04, 0.04, 1.0)

	bubble_style.set_border_width_all(4)
	bubble_style.set_corner_radius_all(34)

	bubble_panel.add_theme_stylebox_override(
		"panel",
		bubble_style
	)

func _layout_popup() -> void:
	var viewport_size: Vector2 = (
		get_viewport().get_visible_rect().size
	)

	dim_overlay.position = Vector2.ZERO
	dim_overlay.size = viewport_size

	var bubble_width: float = minf(
		520.0,
		viewport_size.x - 80.0
	)

	var bubble_height: float = 250.0

	bubble_panel.size = Vector2(
		bubble_width,
		bubble_height
	)

	bubble_panel.position = Vector2(
		(viewport_size.x - bubble_width) * 0.5,
		maxf(44.0, viewport_size.y * 0.16)
	)

	explanation_label.position = Vector2(28.0, 28.0)
	explanation_label.size = Vector2(
		bubble_width - 56.0,
		bubble_height - 56.0
	)

	var tail_left: Vector2 = bubble_panel.position + Vector2(
		56.0,
		bubble_height - 3.0
	)

	bubble_tail.polygon = PackedVector2Array([
		tail_left,
		tail_left + Vector2(74.0, 0.0),
		tail_left + Vector2(22.0, 40.0)
	])

	bubble_tail.color = Color(0.97, 0.94, 0.84, 1.0)

	understood_button.position = bubble_panel.position + Vector2(
		22.0,
		bubble_height + 54.0
	)

	understood_button.size = Vector2(180.0, 44.0)

func _on_understood_pressed() -> void:
	var acknowledged_step: String = current_tutorial_step

	hide_popup(true)
	acknowledged.emit(acknowledged_step)
