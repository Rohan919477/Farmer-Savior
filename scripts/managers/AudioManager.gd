extends Node

@export_file("*.wav", "*.ogg", "*.mp3") var farm_music_path: String = "res://assets/audio/music/farm_ambient_loop.wav"
@export_file("*.wav", "*.ogg", "*.mp3") var night_ambience_path: String = "res://assets/audio/ambience/night_ambience_loop.wav"

@export var farm_music_volume_db: float = -4.0
@export var farm_music_night_volume_db: float = -16.0
@export var night_ambience_volume_db: float = -4.0
@export var muted_volume_db: float = -80.0
@export var fade_duration: float = 0.0

var music_player: AudioStreamPlayer
var night_ambience_player: AudioStreamPlayer

var current_mode: String = ""
var connected_time_manager: Node = null
var active_tweens: Array[Tween] = []

var audio_watchdog_timer: float = 0.0


func _ready() -> void:
	add_to_group("audio_manager")
	process_mode = Node.PROCESS_MODE_ALWAYS

	_create_audio_players()
	_load_audio_streams()

	music_player.volume_db = 0.0
	music_player.play()

	print("[AudioManager TEST] Farm stream: ", music_player.stream)
	print("[AudioManager TEST] Farm length: ", music_player.stream.get_length())
	print("[AudioManager TEST] Farm playing after play(): ", music_player.playing)


#func _process(delta: float) -> void:
#	_try_connect_to_time_manager()
#
#	audio_watchdog_timer -= delta
#
#	if audio_watchdog_timer <= 0.0:
#		audio_watchdog_timer = 0.5
#		_keep_active_audio_playing()


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
	music_player.stream = _load_stream(farm_music_path)
	night_ambience_player.stream = _load_stream(night_ambience_path)


func _load_stream(path: String) -> AudioStream:
	var stream: AudioStream = load(path) as AudioStream

	if stream == null:
		push_warning("[AudioManager] Missing audio stream: " + path)
		return null

	if stream is AudioStreamWAV:
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


func _on_day_started(_day_number: int) -> void:
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
		print("[AudioManager] ", label, " stream is NULL.")
		return

	if player.playing:
		return

	player.play(0.0)

	print(
		"[AudioManager] Started/restarted ",
		label,
		" | length: ",
		player.stream.get_length(),
		" | volume: ",
		player.volume_db
	)


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
