extends Node

const SETTINGS_PATH := "user://audio_settings.cfg"

var sounds = {
	"fireball": preload("res://assets/sound/floraphonic-fireball-whoosh-1-179125.mp3"),
	"blast": preload("res://assets/sound/yodguard-fire-magic-6-378641.mp3"),
	"click": preload("res://assets/sound/universfield-click-button-140881.mp3"),
	"ting": preload("res://assets/sound/freesound_community-glass-ting-89283.mp3"),
	"explode": preload("res://assets/sound/synthetic_explosion_1.wav")
}

var music_tracks = {
	"menu": preload("res://assets/sound/menu.ogg"),
	"gameplay": preload("res://assets/sound/defide.mp3")
}

var bgm_player: AudioStreamPlayer
var current_track: String = ""
var current_volume: float = 0.0
var current_volume_offset: float = 0.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_audio_settings()
	
	bgm_player = AudioStreamPlayer.new()
	bgm_player.process_mode = Node.PROCESS_MODE_ALWAYS
	bgm_player.bus = "Master"
	add_child(bgm_player)
	
	for track_name in music_tracks:
		var track = music_tracks[track_name]
		if track and "loop" in track:
			track.loop = true

func play_music(track_name: String, volume_db: float = 0.0) -> void:
	if not music_tracks.has(track_name):
		push_warning("Musik tidak ditemukan: " + track_name)
		return

	current_volume_offset = volume_db
	current_volume = _volume_to_db(music_volume) + current_volume_offset
	if music_tween:
		music_tween.kill()

	if current_track == track_name and bgm_player.playing:
		bgm_player.volume_db = current_volume
		bgm_player.stream_paused = false
		return

	current_track = track_name
	var stream = music_tracks[track_name]
	stream.loop = true

	bgm_player.stream = stream
	bgm_player.volume_db = current_volume
	bgm_player.stream_paused = false
	bgm_player.play()

func pause_music() -> void:
	if not bgm_player.playing:
		push_warning("Musik tidak sedang dimainkan.")
		return
	if bgm_player.stream_paused:
		push_warning("Musik sudah dijeda.")
		return
	
	bgm_player.stream_paused = true

func resume_music() -> void:
	if bgm_player.playing and not bgm_player.stream_paused:
		push_warning("Musik sedang dimainkan")
		return

	bgm_player.volume_db = current_volume
	bgm_player.stream_paused = false

func is_playing() -> bool:
	if bgm_player.has_stream_playback() and not bgm_player.stream_paused:
		return true
	else: return false

func stop_music() -> void:
	bgm_player.stop()
	current_track = ""

func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not sounds.has(sound_name):
		push_warning("Sound tidak ditemukan: " + sound_name)
		return

	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.stream = sounds[sound_name]
	player.pitch_scale = pitch
	player.volume_db = _volume_to_db(sfx_volume) + volume_db

	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	current_volume = _volume_to_db(music_volume) + current_volume_offset
	if music_tween:
		music_tween.kill()
	if bgm_player:
		bgm_player.volume_db = current_volume
	var dup := get_tree().root.get_node_or_null("Audiomanager")
	if dup and dup != self:
		dup.music_volume = music_volume
		dup.current_volume = current_volume
		if dup.bgm_player:
			dup.bgm_player.volume_db = current_volume
	_save_audio_settings()

func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	var dup := get_tree().root.get_node_or_null("Audiomanager")
	if dup and dup != self:
		dup.sfx_volume = sfx_volume
	_save_audio_settings()

func _volume_to_db(value: float) -> float:
	return linear_to_db(value) if value > 0.0 else -80.0

func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	music_volume = clampf(float(config.get_value("audio", "music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", sfx_volume)), 0.0, 1.0)
	current_volume = _volume_to_db(music_volume)

func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % error_string(error))

func fade_out(duration: float = 1.0) -> void:
	if music_tween:
		music_tween.kill()
		
	music_tween = create_tween()
	music_tween.tween_property(bgm_player, "volume_db", -80.0, duration)
	music_tween.tween_callback(bgm_player.stop)
	music_tween.tween_callback(func(): bgm_player.volume_db = current_volume)

func fade_in(duration: float = 1.0) -> void:
	if music_tween:
		music_tween.kill()
		
	bgm_player.volume_db = -80.0
	bgm_player.play(0.0)
	
	music_tween = create_tween()
	music_tween.tween_property(bgm_player, "volume_db", current_volume, duration)

func reset_volume() -> void:
	if music_tween:
		music_tween.kill()
	bgm_player.volume_db = current_volume

func reset_track() -> void:
	if music_tween:
		music_tween.kill()
	
	bgm_player.seek(0.0)
