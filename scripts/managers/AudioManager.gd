extends Node

@export_group("Music and Ambience")
@export_file("*.wav", "*.ogg", "*.mp3") var farm_music_path: String = "res://assets/audio/music/farm_ambient_loop.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var night_ambience_path: String = "res://assets/audio/ambience/night_ambience_loop.wav"

@export var farm_music_volume_db: float = -10.0
@export var farm_music_night_volume_db: float = -24.0
@export var night_ambience_volume_db: float = -8.0
@export var muted_volume_db: float = -80.0
@export var fade_duration: float = 2.0

@export_group("Sound Effects")
@export_file("*.wav", "*.ogg", "*.mp3") var pistol_shot_sfx_path: String = "res://assets/audio/sfx/pistol_shot.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var reload_sfx_path: String = "res://assets/audio/sfx/reload.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var enemy_hit_sfx_path: String = "res://assets/audio/sfx/enemy_hit.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var enemy_death_sfx_path: String = "res://assets/audio/sfx/enemy_death.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var pickup_collected_sfx_path: String = "res://assets/audio/sfx/pickup_collected.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var turret_fire_sfx_path: String = "res://assets/audio/sfx/turret_fire.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var night_starts_sfx_path: String = "res://assets/audio/sfx/night_starts.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var button_click_sfx_path: String = "res://assets/audio/sfx/button_click.wav"

@export var sfx_volume_db: float = -6.0
@export var max_simultaneous_sfx: int = 16
@export var automatic_button_click_sfx: bool = true
@export var debug_audio: bool = false

var music_player: AudioStreamPlayer
var night_ambience_player: AudioStreamPlayer

var current_mode: String = ""
var connected_time_manager: Node = null
var active_tweens: Array[Tween] = []
var sfx_streams: Dictionary = {}

var audio_watchdog_timer: float = 0.0
var button_scan_timer: float = 0.0
var night_start_sfx_played_today: bool = false


func _ready() -> void:
	add_to_group("audio_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_audio_players()
	_load_audio_streams()
	_load_sfx_streams()

	play_day_audio(false)

	if debug_audio:
		call_deferred("_debug_audio_state")


func _process(delta: float) -> void:
	_try_connect_to_time_manager()

	audio_watchdog_timer -= delta
	if audio_watchdog_timer <= 0.0:
		audio_watchdog_timer = 0.5
		_keep_active_audio_playing()

	if automatic_button_click_sfx:
		button_scan_timer -= delta
		if button_scan_timer <= 0.0:
			button_scan_timer = 0.75
			_connect_button_sfx_recursive(get_tree().root)


func _create_audio_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "FarmMusicPlayer"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.volume_db = muted_volume_db
	music_player.bus = "Master"
	add_child(music_player)

	night_ambience_player = AudioStreamPlayer.new()
	night_ambience_player.name = "NightAmbiencePlayer"
	night_ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
	night_ambience_player.volume_db = muted_volume_db
	night_ambience_player.bus = "Master"
	add_child(night_ambience_player)


func _load_audio_streams() -> void:
	music_player.stream = _load_stream(farm_music_path, true)
	night_ambience_player.stream = _load_stream(night_ambience_path, true)


func _load_sfx_streams() -> void:
	sfx_streams.clear()
	sfx_streams["pistol_shot"] = _load_stream(pistol_shot_sfx_path, false)
	sfx_streams["reload"] = _load_stream(reload_sfx_path, false)
	sfx_streams["enemy_hit"] = _load_stream(enemy_hit_sfx_path, false)
	sfx_streams["enemy_death"] = _load_stream(enemy_death_sfx_path, false)
	sfx_streams["pickup_collected"] = _load_stream(pickup_collected_sfx_path, false)
	sfx_streams["turret_fire"] = _load_stream(turret_fire_sfx_path, false)
	sfx_streams["night_starts"] = _load_stream(night_starts_sfx_path, false)
	sfx_streams["button_click"] = _load_stream(button_click_sfx_path, false)


func _load_stream(path: String, should_loop: bool) -> AudioStream:
	var stream: AudioStream = load(path) as AudioStream

	if stream == null:
		push_warning("[AudioManager] Missing audio stream: " + path)
		return null

	if should_loop and stream is AudioStreamWAV:
		var wav_stream: AudioStreamWAV = stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	return stream


func _try_connect_to_time_manager() -> void:
	var time_manager: Node = get_tree().get_first_node_in_group(
		"time_manager"
	)

	if time_manager == null:
		connected_time_manager = null
		return

	if connected_time_manager == time_manager:
		return

	connected_time_manager = time_manager

	if time_manager.has_signal("time_changed"):
		if not time_manager.time_changed.is_connected(_on_time_changed):
			time_manager.time_changed.connect(_on_time_changed)

	if time_manager.has_signal("night_started"):
		if not time_manager.night_started.is_connected(_on_night_started):
			time_manager.night_started.connect(_on_night_started)

	if time_manager.has_signal("day_started"):
		if not time_manager.day_started.is_connected(_on_day_started):
			time_manager.day_started.connect(_on_day_started)

	_apply_initial_audio_state()


func _apply_initial_audio_state() -> void:
	if connected_time_manager != null:
		if connected_time_manager.has_method("is_nighttime"):
			if bool(connected_time_manager.call("is_nighttime")):
				play_night_audio(false)
				return

	play_day_audio(false)


func _on_time_changed(
	_day_number: int,
	_hour: int,
	_minute: int,
	phase: String
) -> void:
	if phase == "night" or phase == "night_cleanup":
		play_night_audio(true)
	else:
		play_day_audio(true)


func _on_night_started() -> void:
	play_night_audio(true)

	if not night_start_sfx_played_today:
		night_start_sfx_played_today = true
		play_sfx("night_starts", 0.0, 0.0)


func _on_day_started(_day_number: int) -> void:
	night_start_sfx_played_today = false
	play_day_audio(true)


func play_day_audio(use_fade: bool = true) -> void:
	if current_mode == "day":
		return

	current_mode = "day"

	_set_player_volume(
		music_player,
		farm_music_volume_db,
		use_fade
	)

	_set_player_volume(
		night_ambience_player,
		muted_volume_db,
		use_fade
	)

	_play_player_if_needed(
		music_player,
		"FarmMusicPlayer"
	)

	if night_ambience_player != null:
		night_ambience_player.stop()


func play_night_audio(use_fade: bool = true) -> void:
	if current_mode == "night":
		return

	current_mode = "night"

	_set_player_volume(
		music_player,
		farm_music_night_volume_db,
		use_fade
	)

	_set_player_volume(
		night_ambience_player,
		night_ambience_volume_db,
		use_fade
	)

	_play_player_if_needed(
		music_player,
		"FarmMusicPlayer"
	)

	_play_player_if_needed(
		night_ambience_player,
		"NightAmbiencePlayer"
	)


func _keep_active_audio_playing() -> void:
	if current_mode == "day":
		_play_player_if_needed(
			music_player,
			"FarmMusicPlayer"
		)

	elif current_mode == "night":
		_play_player_if_needed(
			music_player,
			"FarmMusicPlayer"
		)

		_play_player_if_needed(
			night_ambience_player,
			"NightAmbiencePlayer"
		)


func _play_player_if_needed(
	player: AudioStreamPlayer,
	label: String
) -> void:
	if player == null:
		return

	if player.stream == null:
		if debug_audio:
			print("[AudioManager] ", label, " stream is NULL.")
		return

	if player.playing:
		return

	player.play(0.0)

	if debug_audio:
		print(
			"[AudioManager] Started/restarted ",
			label,
			" | length: ",
			player.stream.get_length(),
			" | volume: ",
			player.volume_db
		)


func play_sfx(
	sfx_name: String,
	volume_offset_db: float = 0.0,
	pitch_variation: float = 0.04
) -> void:
	var stream: AudioStream = sfx_streams.get(sfx_name, null) as AudioStream

	if stream == null:
		if debug_audio:
			print("[AudioManager] Missing SFX: ", sfx_name)
		return

	if _get_active_sfx_count() >= max_simultaneous_sfx:
		return

	var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
	sfx_player.name = "SFX_" + sfx_name
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_player.bus = "Master"
	sfx_player.stream = stream
	sfx_player.volume_db = sfx_volume_db + _get_sfx_volume_offset(sfx_name) + volume_offset_db

	if pitch_variation > 0.0:
		sfx_player.pitch_scale = randf_range(
			1.0 - pitch_variation,
			1.0 + pitch_variation
		)
	else:
		sfx_player.pitch_scale = 1.0

	add_child(sfx_player)
	sfx_player.finished.connect(sfx_player.queue_free)
	sfx_player.play()


func _get_sfx_volume_offset(sfx_name: String) -> float:
	match sfx_name:
		"pistol_shot":
			return -2.0
		"reload":
			return -3.0
		"enemy_hit":
			return -4.0
		"enemy_death":
			return -3.0
		"pickup_collected":
			return -2.0
		"turret_fire":
			return -4.0
		"night_starts":
			return 0.0
		"button_click":
			return -8.0
		_:
			return 0.0


func _get_active_sfx_count() -> int:
	var count: int = 0

	for child: Node in get_children():
		if child is AudioStreamPlayer:
			if String(child.name).begins_with("SFX_"):
				count += 1

	return count


func _connect_button_sfx_recursive(node: Node) -> void:
	if node is BaseButton:
		var base_button: BaseButton = node as BaseButton

		if not base_button.has_meta("audio_click_sfx_connected"):
			base_button.set_meta("audio_click_sfx_connected", true)

			if not base_button.pressed.is_connected(_on_any_button_pressed):
				base_button.pressed.connect(_on_any_button_pressed)

	for child: Node in node.get_children():
		_connect_button_sfx_recursive(child)


func _on_any_button_pressed() -> void:
	play_sfx("button_click", 0.0, 0.0)


func _set_player_volume(
	player: AudioStreamPlayer,
	target_volume_db: float,
	use_fade: bool
) -> void:
	if player == null:
		return

	if not use_fade or fade_duration <= 0.0:
		player.volume_db = target_volume_db
		return

	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		player,
		"volume_db",
		target_volume_db,
		fade_duration
	)

	active_tweens.append(tween)
	tween.finished.connect(_cleanup_finished_tweens)


func _cleanup_finished_tweens() -> void:
	var remaining_tweens: Array[Tween] = []

	for tween: Tween in active_tweens:
		if tween != null and tween.is_running():
			remaining_tweens.append(tween)

	active_tweens = remaining_tweens


func _debug_audio_state() -> void:
	await get_tree().create_timer(1.0).timeout

	var master_bus_index: int = AudioServer.get_bus_index("Master")

	print("[AudioManager] ---- AUDIO DEBUG ----")	
	print("[AudioManager] Master muted: ", AudioServer.is_bus_mute(master_bus_index))
	print("[AudioManager] Master volume db: ", AudioServer.get_bus_volume_db(master_bus_index))

	if music_player != null:
		print("[AudioManager] Farm stream: ", music_player.stream)
		print("[AudioManager] Farm length: ", music_player.stream.get_length() if music_player.stream != null else -1.0)
		print("[AudioManager] Farm playing: ", music_player.playing)
		print("[AudioManager] Farm volume db: ", music_player.volume_db)
		print("[AudioManager] Farm playback position: ", music_player.get_playback_position())

	if night_ambience_player != null:
		print("[AudioManager] Night stream: ", night_ambience_player.stream)
		print("[AudioManager] Night length: ", night_ambience_player.stream.get_length() if night_ambience_player.stream != null else -1.0)
		print("[AudioManager] Night playing: ", night_ambience_player.playing)
		print("[AudioManager] Night volume db: ", night_ambience_player.volume_db)
		print("[AudioManager] Night playback position: ", night_ambience_player.get_playback_position())
