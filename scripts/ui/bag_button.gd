extends TextureButton

var normal_scale: Vector2 = Vector2.ONE
var hover_scale: Vector2 = Vector2(1.06, 1.06)
var normal_modulate: Color = Color.WHITE
var hover_modulate: Color = Color(1.25, 1.15, 0.75, 1.0)


func _ready() -> void:
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = Vector2(96.0, 96.0)

	normal_scale = Vector2.ONE
	scale = normal_scale
	pivot_offset = size * 0.5

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5


func _on_mouse_entered() -> void:
	modulate = hover_modulate
	scale = hover_scale


func _on_mouse_exited() -> void:
	modulate = normal_modulate
	scale = normal_scale
