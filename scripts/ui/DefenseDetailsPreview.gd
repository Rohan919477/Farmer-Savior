extends Control
class_name DefenseDetailsPreview

const ITEM_PESTICIDE_TURRET: String = "pesticide_turret"
const ITEM_FENCE: String = "fence"
const ITEM_NIGHTLIGHT: String = "nightlight"

const TURRET_TEXTURE: Texture2D = preload(
	"res://sprites/farm/PesticideTurret/PesticideTurret_idle_01.png"
)

var preview_item_id: String = ""
var preview_state: String = "perfect"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func show_defense(item_id: String, state: String = "perfect") -> void:
	preview_item_id = item_id
	preview_state = state
	visible = not preview_item_id.is_empty()
	queue_redraw()

func clear_preview() -> void:
	preview_item_id = ""
	preview_state = "perfect"
	visible = false
	queue_redraw()

func _draw() -> void:
	if preview_item_id.is_empty():
		return

	var preview_rect := Rect2(Vector2.ZERO, size)
	draw_rect(preview_rect, Color(0.05, 0.06, 0.05, 0.72), true)
	draw_rect(preview_rect, Color(0.42, 0.45, 0.36, 0.85), false, 1.0)

	match preview_item_id:
		ITEM_PESTICIDE_TURRET:
			_draw_turret_preview()
		ITEM_NIGHTLIGHT:
			_draw_nightlight_preview()
		ITEM_FENCE:
			_draw_fence_preview()

func _draw_turret_preview() -> void:
	if TURRET_TEXTURE == null:
		return

	var target_size: Vector2 = Vector2(78.0, 78.0)
	var target_position: Vector2 = (size - target_size) * 0.5
	var target_rect := Rect2(target_position, target_size)

	var tint: Color = Color.WHITE
	if preview_state == "damaged":
		tint = Color(0.88, 0.78, 0.55)
	elif preview_state == "broken":
		tint = Color(0.48, 0.45, 0.42)

	draw_texture_rect(TURRET_TEXTURE, target_rect, false, tint)

func _draw_nightlight_preview() -> void:
	var center: Vector2 = size * 0.5
	var glow_radius: float = 31.0

	var glow_color := Color(1.0, 0.72, 0.25, 0.28)
	var lamp_color := Color(1.0, 0.72, 0.25)

	if preview_state == "damaged":
		lamp_color = Color(0.82, 0.55, 0.22)
	elif preview_state == "broken":
		glow_color.a = 0.05
		lamp_color = Color(0.28, 0.25, 0.22)

	draw_circle(center, glow_radius, glow_color)
	draw_rect(
		Rect2(center + Vector2(-4.0, -2.0), Vector2(8.0, 31.0)),
		Color(0.30, 0.24, 0.18),
		true
	)
	draw_circle(center + Vector2(0.0, -10.0), 13.0, lamp_color)
	draw_circle(center + Vector2(0.0, -10.0), 5.0, Color(0.18, 0.13, 0.08))

func _draw_fence_preview() -> void:
	var center: Vector2 = size * 0.5
	var wood_color := Color(0.46, 0.27, 0.12)

	if preview_state == "damaged":
		wood_color = Color(0.58, 0.34, 0.12)
	elif preview_state == "broken":
		wood_color = Color(0.31, 0.16, 0.08)

	var left_x: float = center.x - 48.0
	var right_x: float = center.x + 48.0
	var top_y: float = center.y - 14.0
	var bottom_y: float = center.y + 14.0

	if preview_state == "broken":
		draw_line(Vector2(left_x, top_y), Vector2(center.x - 12.0, top_y), wood_color, 7.0)
		draw_line(Vector2(center.x + 14.0, top_y), Vector2(right_x, top_y), wood_color, 7.0)
		draw_line(Vector2(left_x, bottom_y), Vector2(center.x - 18.0, bottom_y), wood_color, 7.0)
		draw_line(Vector2(center.x + 9.0, bottom_y), Vector2(right_x, bottom_y), wood_color, 7.0)
	else:
		draw_line(Vector2(left_x, top_y), Vector2(right_x, top_y), wood_color, 7.0)
		draw_line(Vector2(left_x, bottom_y), Vector2(right_x, bottom_y), wood_color, 7.0)

	for x_offset in [-38.0, 0.0, 38.0]:
		draw_line(
			center + Vector2(x_offset, -28.0),
			center + Vector2(x_offset, 29.0),
			wood_color.darkened(0.12),
			7.0
		)
