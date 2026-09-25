extends Node3D
class_name SteamHammer

@export var cycle_interval: float = 34.0
@export var active_duration: float = 8.5
var timer: float = 6.0 # start soon after mission begins
var is_active: bool = false
var audio_player: AudioStreamPlayer3D

@onready var hammer_mesh: MeshInstance3D = $HammerHead
@onready var steam_particles: GPUParticles3D = $SteamParticles

func _ready() -> void:
	_setup_audio()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.stream = AudioManager.get_stream("steam_press")
	audio_player.volume_db = 8.0
	audio_player.unit_size = 35.0
	audio_player.max_distance = 650.0
	add_child(audio_player)

func _process(delta: float) -> void:
	timer += delta
	if not is_active:
		if timer >= cycle_interval:
			_start_cycle()
	else:
		if timer >= active_duration:
			_stop_cycle()

func _start_cycle() -> void:
	is_active = true
	timer = 0.0
	audio_player.play()
	SoundEventManager.set_masking(true, 1.0)
	SoundEventManager.emit_sound(global_position, 550.0, "industrial_press", self)

	if steam_particles:
		steam_particles.emitting = true


func _stop_cycle() -> void:
	is_active = false
	timer = 0.0
	SoundEventManager.set_masking(false, 0.0)

	if steam_particles:
		steam_particles.emitting = false
