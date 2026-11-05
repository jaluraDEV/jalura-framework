class_name PlayerAudio
extends Node3D

## PlayerAudio
## Modular audio manager for Barnaby.
## Handles footsteps (surface-aware), voice/action SFX, jump/landing audio, and looping rail grind sound.
## Sounds are exposed as @export (AudioStream) properties with default asset fallbacks.

@export var enabled: bool = true

@export_group("Jump & Maneuver Sounds")
@export var sfx_jumps: Array[AudioStream] = []
@export var sfx_maneuver: Array[AudioStream] = []

@export_group("Footstep Sounds")
@export var sfx_footsteps_grass: Array[AudioStream] = []
@export var sfx_footsteps_wood: Array[AudioStream] = []

@export_group("Action Sounds")
@export var sfx_dash: AudioStream
@export var sfx_spin: AudioStream
@export var sfx_air_dive: AudioStream
@export var sfx_open_glider: AudioStream
@export var sfx_start_rail_grind: AudioStream
@export var sfx_rail_grind_loop: AudioStream

var player: CharacterBody3D
var _sfx_voice: AudioStreamPlayer3D
var _sfx_movement: AudioStreamPlayer3D
var _sfx_action: AudioStreamPlayer3D
var _sfx_grind_loop: AudioStreamPlayer3D

var _step_distance: float = 0.0

func setup(p_player: CharacterBody3D) -> void:
	player = p_player
	_setup_audio_players()
	_load_default_sounds()

func _setup_audio_players() -> void:
	_sfx_voice = AudioStreamPlayer3D.new()
	_sfx_voice.name = "SfxVoice"
	_sfx_voice.bus = &"SFX"
	_sfx_voice.max_polyphony = 3
	_sfx_voice.unit_size = 10.0
	_sfx_voice.max_distance = 60.0
	add_child(_sfx_voice)

	_sfx_movement = AudioStreamPlayer3D.new()
	_sfx_movement.name = "SfxMovement"
	_sfx_movement.bus = &"SFX"
	_sfx_movement.max_polyphony = 4
	_sfx_movement.unit_size = 10.0
	_sfx_movement.max_distance = 60.0
	add_child(_sfx_movement)

	_sfx_action = AudioStreamPlayer3D.new()
	_sfx_action.name = "SfxAction"
	_sfx_action.bus = &"SFX"
	_sfx_action.max_polyphony = 3
	_sfx_action.unit_size = 10.0
	_sfx_action.max_distance = 60.0
	add_child(_sfx_action)

	_sfx_grind_loop = AudioStreamPlayer3D.new()
	_sfx_grind_loop.name = "SfxGrindLoop"
	_sfx_grind_loop.bus = &"SFX"
	_sfx_grind_loop.unit_size = 10.0
	_sfx_grind_loop.max_distance = 100.0
	add_child(_sfx_grind_loop)

func _load_default_sounds() -> void:
	if sfx_jumps.is_empty():
		for i in range(5):
			var p := "res://assets/sound/chars/player/jump_%d.wav" % i
			if ResourceLoader.exists(p):
				sfx_jumps.append(load(p))

	if sfx_footsteps_grass.is_empty():
		for i in range(3):
			var p := "res://assets/sound/chars/player/footstep_grass_%d.wav" % i
			if ResourceLoader.exists(p):
				sfx_footsteps_grass.append(load(p))

	if sfx_footsteps_wood.is_empty():
		for i in [1, 2]:
			var p := "res://assets/sound/chars/player/footstep_wood_%d.wav" % i
			if ResourceLoader.exists(p):
				sfx_footsteps_wood.append(load(p))

	if sfx_maneuver.is_empty():
		for i in range(5):
			var p := "res://assets/sound/chars/player/maneuver_%d.wav" % i
			if ResourceLoader.exists(p):
				sfx_maneuver.append(load(p))

	if not sfx_dash and ResourceLoader.exists("res://assets/sound/chars/player/dash.wav"):
		sfx_dash = load("res://assets/sound/chars/player/dash.wav")

	if not sfx_spin:
		if ResourceLoader.exists("res://assets/sound/chars/player/spin.wav"):
			sfx_spin = load("res://assets/sound/chars/player/spin.wav")
		elif ResourceLoader.exists("res://assets/sound/chars/player/short_spin.wav"):
			sfx_spin = load("res://assets/sound/chars/player/short_spin.wav")

	if not sfx_air_dive and ResourceLoader.exists("res://assets/sound/chars/player/air_dive.wav"):
		sfx_air_dive = load("res://assets/sound/chars/player/air_dive.wav")

	if not sfx_open_glider and ResourceLoader.exists("res://assets/sound/chars/player/open_glider.wav"):
		sfx_open_glider = load("res://assets/sound/chars/player/open_glider.wav")

	if not sfx_start_rail_grind and ResourceLoader.exists("res://assets/sound/chars/player/start_rail_grind.wav"):
		sfx_start_rail_grind = load("res://assets/sound/chars/player/start_rail_grind.wav")

	if not sfx_rail_grind_loop and ResourceLoader.exists("res://assets/sound/chars/player/rail_grind.wav"):
		sfx_rail_grind_loop = load("res://assets/sound/chars/player/rail_grind.wav")
		if sfx_rail_grind_loop is AudioStreamWAV:
			var wav := sfx_rail_grind_loop as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.mix_rate * wav.get_length())

func handle_footsteps(delta: float, cur_spd: float, is_running: bool, is_grounded: bool, on_step_callback: Callable = Callable()) -> void:
	if not is_grounded or cur_spd < 0.25:
		_step_distance = 0.0
		return

	var interval := 1.35 if is_running else 0.92
	_step_distance += cur_spd * delta
	if _step_distance >= interval:
		_step_distance = 0.0
		play_footstep()
		if on_step_callback.is_valid():
			on_step_callback.call()

func play_footstep() -> void:
	if not enabled or not _sfx_movement:
		return
	var stream: AudioStream = null
	var pos_z: float = player.global_position.z if player else 0.0
	if pos_z > 70.0 and not sfx_footsteps_wood.is_empty():
		stream = sfx_footsteps_wood[randi() % sfx_footsteps_wood.size()]
	elif not sfx_footsteps_grass.is_empty():
		stream = sfx_footsteps_grass[randi() % sfx_footsteps_grass.size()]
	if stream:
		play_sfx(stream, _sfx_movement, 0.08, -6.0)

func play_jump() -> void:
	if not enabled or not _sfx_voice or sfx_jumps.is_empty():
		return
	var stream := sfx_jumps[randi() % sfx_jumps.size()]
	play_sfx(stream, _sfx_voice, 0.08, -1.0)

func play_landing(fall_velocity: float) -> void:
	if not enabled or not _sfx_movement or sfx_maneuver.is_empty():
		return
	var vol := clampf(absf(fall_velocity) / 20.0 * 6.0 - 6.0, -8.0, 1.0)
	var stream := sfx_maneuver[randi() % sfx_maneuver.size()]
	play_sfx(stream, _sfx_movement, 0.06, vol)

func play_dash() -> void:
	if not enabled or not _sfx_action or not sfx_dash:
		return
	play_sfx(sfx_dash, _sfx_action, 0.05, 0.5)

func play_spin() -> void:
	if not enabled or not _sfx_action or not sfx_spin:
		return
	play_sfx(sfx_spin, _sfx_action, 0.06, 1.0)

func play_backflip() -> void:
	if not enabled or not _sfx_voice or sfx_maneuver.is_empty():
		return
	var stream := sfx_maneuver[randi() % sfx_maneuver.size()]
	play_sfx(stream, _sfx_voice, 0.08, 0.5)

func play_glider_open() -> void:
	if not enabled or not _sfx_action or not sfx_open_glider:
		return
	_sfx_action.stream = sfx_open_glider
	_sfx_action.pitch_scale = randf_range(0.96, 1.04)
	_sfx_action.play()

func play_rail_start() -> void:
	if not enabled or not _sfx_action or not sfx_start_rail_grind:
		return
	play_sfx(sfx_start_rail_grind, _sfx_action, 0.06, 0.0)

func start_rail_grind_loop(speed_ratio: float = 1.0) -> void:
	if not enabled or not _sfx_grind_loop or not sfx_rail_grind_loop:
		return
	_sfx_grind_loop.stream = sfx_rail_grind_loop
	if not _sfx_grind_loop.playing:
		_sfx_grind_loop.play()
	_sfx_grind_loop.pitch_scale = lerp(0.85, 1.35, speed_ratio)

func update_rail_grind_loop(speed_ratio: float) -> void:
	if not enabled or not _sfx_grind_loop:
		return
	if not _sfx_grind_loop.playing and sfx_rail_grind_loop:
		_sfx_grind_loop.stream = sfx_rail_grind_loop
		_sfx_grind_loop.play()
	_sfx_grind_loop.pitch_scale = lerp(0.85, 1.35, speed_ratio)

func stop_rail_grind_loop() -> void:
	if _sfx_grind_loop and _sfx_grind_loop.playing:
		_sfx_grind_loop.stop()

func play_sfx(stream: AudioStream, sfx_player: AudioStreamPlayer3D, pitch_range: float = 0.08, vol_db: float = 0.0) -> void:
	if not stream or not sfx_player:
		return
	sfx_player.stream = stream
	sfx_player.pitch_scale = randf_range(1.0 - pitch_range, 1.0 + pitch_range)
	sfx_player.volume_db = vol_db
	sfx_player.play()
