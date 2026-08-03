extends TextureButton

var normal_scale: Vector2 = Vector2.ONE
var hover_scale: Vector2 = Vector2(1.08, 1.08)


func _ready() -> void:
	normal_scale = scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	modulate = Color(1.25, 1.15, 0.75, 1.0)
	scale = hover_scale


func _on_mouse_exited() -> void:
	modulate = Color.WHITE
	scale = normal_scale
