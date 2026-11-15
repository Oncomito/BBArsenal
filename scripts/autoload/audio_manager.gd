extends Node

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
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
	
	if current_track == track_name and bgm_player.playing:
		return
	
	current_track = track_name
	var stream = music_tracks[track_name]
	if stream and "loop" in stream:
		stream.loop = true
		
	bgm_player.stream = stream
	bgm_player.volume_db = volume_db
	bgm_player.play()

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
	player.volume_db = volume_db

	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
