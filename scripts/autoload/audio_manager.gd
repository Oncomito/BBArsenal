extends Node

var sounds = {
	"fireball": preload("res://assets/sound/floraphonic-fireball-whoosh-1-179125.mp3"),
	"blast": preload("res://assets/sound/yodguard-fire-magic-6-378641.mp3"),
	"click": preload("res://assets/sound/universfield-click-button-140881.mp3"),
	"ting": preload("res://assets/sound/freesound_community-glass-ting-89283.mp3")
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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
