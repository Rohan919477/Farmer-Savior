extends Node

const WINDOWED_SIZE: Vector2i = Vector2i(1152, 648)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[FullscreenManager] Ready.")


func _input(event: InputEvent) -> void:
	if _is_fullscreen_toggle(event):
		_toggle_fullscreen()


func _is_fullscreen_toggle(event: InputEvent) -> bool:
	if event.is_action_pressed("toggle_fullscreen"):
		return true

	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey

		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_F11:
				return true

	return false


func _toggle_fullscreen() -> void:
	var current_mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()

	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		print("[FullscreenManager] Windowed mode.")
		return

	if current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(WINDOWED_SIZE)
		print("[FullscreenManager] Windowed mode.")
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	print("[FullscreenManager] Fullscreen mode.")
