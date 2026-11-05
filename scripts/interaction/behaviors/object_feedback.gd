@tool
class_name ObjectFeedback
extends ObjectBehavior

## Component: Feedback & Juice (Squash & Stretch / Sounds / Highlights).
## Reagiert auf Hub-Events und erzeugt saftige, elastische Reaktionen:
## - Squash & Stretch (elastisches Stauchen und Dehnen per Tween)
## - In-Range Hervorhebung (sanftes Anheben/Aufpoppen bei Annäherung)
## - Wackeln / Wobble (drehendes Schütteln)
## - Sound-Effekte (3D-Audio mit zufälliger Pitch-Variation)
## - Partikel-Puff (Sternchen- oder Staub-Explosion)
## Alle Effekte sind einzeln und global pro Objekt konfigurierbar.

@export_group("Feedback Master")
@export var feedback_enabled: bool = true ## Globaler Schalter für alle Effekte dieses Bausteins
@export var visual_node_path: NodePath ## Optional: Pfad zum Visual/Mesh-Knoten. Wenn leer, wird automatisch 'Visual' oder der Hub genutzt.

@export_group("Focus & Highlight (In-Range)")
@export var enable_focus_highlight: bool = true ## Sanftes Anheben/Aufpoppen, wenn der Spieler in Reichweite kommt
@export var focus_bounce_height: float = 0.06 ## Höhe des kleinen Wippens in Metern
@export var focus_scale_boost: float = 1.04 ## Skalierungs-Faktor beim Anvisieren

@export_group("Squash & Stretch")
@export var enable_squash: bool = true ## Elastisches Stauchen und Strecken bei Interaktionen
@export var squash_scale: Vector3 = Vector3(1.18, 0.82, 1.18) ## Dehn-/Stauch-Faktor
@export var squash_duration: float = 0.35 ## Dauer des elastischen Zurückfederns
@export var squash_events: Array[StringName] = [&"opened", &"shaken", &"pushed", &"activated", &"deactivated", &"toggled", &"talked", &"interacted", &"picked_up", &"looted"]

@export_group("Wobble")
@export var enable_wobble: bool = true ## Schnelles Hin- und Herwackeln
@export var wobble_angle: float = 7.0 ## Wackel-Winkel in Grad
@export var wobble_duration: float = 0.4 ## Dauer des Wackelns
@export var wobble_events: Array[StringName] = [&"shaken", &"wobbled", &"blocked", &"unlock_failed", &"inventory_full"]

@export_group("Audio")
@export var enable_sound: bool = true
@export var default_sound: AudioStream = null ## Standard-Sound für Interaktionen
@export var event_sounds: Dictionary = {} ## Map: event_name (String) -> AudioStream
@export var sound_pitch_min: float = 0.95
@export var sound_pitch_max: float = 1.05

@export_group("Particles")
@export var enable_particles: bool = true
@export var custom_particles_scene: PackedScene = null ## Optionale eigene Partikelszene
@export var particle_events: Array[StringName] = [&"opened", &"shaken", &"depleted", &"activated", &"deactivated", &"toggled", &"unlocked", &"looted"]

var _base_scale: Vector3 = Vector3.ONE
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _initialized_transforms: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _current_tween: Tween = null
var _is_focused: bool = false

func _ready() -> void:
	_resolve_hub()
	_cache_base_transform()
	if enable_sound and not Engine.is_editor_hint():
		call_deferred("_setup_audio_player")
	if hub and hub.has_signal("event"):
		if not hub.event.is_connected(_on_hub_event):
			hub.event.connect(_on_hub_event)

func _get_visual_target() -> Node3D:
	if not visual_node_path.is_empty():
		var node := get_node_or_null(visual_node_path) as Node3D
		if node:
			return node
	_resolve_hub()
	if hub and is_instance_valid(hub):
		var vis := hub.find_child("Visual", false, false) as Node3D
		if vis:
			return vis
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

func _cache_base_transform() -> void:
	if _initialized_transforms:
		return
	var target := _get_visual_target()
	if target:
		_base_scale = target.scale
		_base_position = target.position
		_base_rotation = target.rotation
		_initialized_transforms = true

func _setup_audio_player() -> void:
	if _audio_player or not is_inside_tree():
		return
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "FeedbackAudio"
	_audio_player.unit_size = 10.0
	_audio_player.max_distance = 25.0
	var parent_3d: Node3D = _get_visual_target()
	if not parent_3d and hub and hub is Node3D:
		parent_3d = hub as Node3D
	if parent_3d and is_instance_valid(parent_3d):
		parent_3d.add_child.call_deferred(_audio_player)
	else:
		add_child.call_deferred(_audio_player)

func _on_hub_event(event_name: StringName, data: Dictionary = {}) -> void:
	if not feedback_enabled:
		return

	_cache_base_transform()

	# 1. In-Range Fokus Highlight (Annäherung)
	if event_name == &"focused":
		_play_focus_in()
		return
	elif event_name == &"unfocused":
		_play_focus_out()
		return

	# 2. Squash & Stretch
	if enable_squash and squash_events.has(event_name):
		play_squash()

	# 3. Wackeln / Wobble
	if enable_wobble and wobble_events.has(event_name):
		play_wobble()

	# 4. Sound abspielen
	if enable_sound:
		var sound: AudioStream = event_sounds.get(String(event_name), default_sound)
		if sound:
			play_sound(sound)

	# 5. Partikel puffen
	if enable_particles and particle_events.has(event_name):
		play_particle_puff()

## Spielt einen saftigen elastischen Squash & Stretch-Tween ab
func play_squash(scale_factor: Vector3 = Vector3.ZERO) -> void:
	var target := _get_visual_target()
	if not target or not is_inside_tree():
		return

	_kill_tween()
	var squash_mult := scale_factor if scale_factor != Vector3.ZERO else squash_scale
	var target_squash := _base_scale * squash_mult

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(target, "scale", target_squash, squash_duration * 0.3)
	_current_tween.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(target, "scale", _base_scale, squash_duration * 0.7)

## Spielt ein lebendiges Hin- und Herwackeln ab
func play_wobble(angle_deg: float = 0.0) -> void:
	var target := _get_visual_target()
	if not target or not is_inside_tree():
		return

	_kill_tween()
	var max_angle := deg_to_rad(angle_deg if angle_deg != 0.0 else wobble_angle)

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(target, "rotation:z", _base_rotation.z + max_angle, wobble_duration * 0.2)
	_current_tween.tween_property(target, "rotation:z", _base_rotation.z - max_angle * 0.7, wobble_duration * 0.25)
	_current_tween.tween_property(target, "rotation:z", _base_rotation.z + max_angle * 0.35, wobble_duration * 0.25)
	_current_tween.tween_property(target, "rotation:z", _base_rotation.z, wobble_duration * 0.3)

## Spielt das subtile Hervorheben beim Betreten der Interaktions-Reichweite ab
func _play_focus_in() -> void:
	if not enable_focus_highlight or _is_focused:
		return
	_is_focused = true
	var target := _get_visual_target()
	if not target or not is_inside_tree():
		return

	_kill_tween()
	var hop_pos := _base_position + Vector3(0.0, focus_bounce_height, 0.0)
	var hop_scale := _base_scale * focus_scale_boost

	_current_tween = create_tween().set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(target, "position", hop_pos, 0.2)
	_current_tween.tween_property(target, "scale", hop_scale, 0.2)

## Setzt das Objekt beim Verlassen der Reichweite wieder sanft zurück
func _play_focus_out() -> void:
	if not enable_focus_highlight or not _is_focused:
		return
	_is_focused = false
	var target := _get_visual_target()
	if not target or not is_inside_tree():
		return

	_kill_tween()
	_current_tween = create_tween().set_parallel(true)
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_current_tween.tween_property(target, "position", _base_position, 0.18)
	_current_tween.tween_property(target, "scale", _base_scale, 0.18)

## Spielt einen Sound-Effekt mit natürlicher Tonhöhen-Variation ab
func play_sound(stream: AudioStream) -> void:
	if not stream or not is_inside_tree():
		return
	_setup_audio_player()
	if _audio_player:
		_audio_player.stream = stream
		_audio_player.pitch_scale = randf_range(sound_pitch_min, sound_pitch_max)
		_audio_player.play()

## Creates a subtle particle puff (dust/stars)
func play_particle_puff() -> void:
	if not is_inside_tree():
		return

	var target := _get_visual_target()
	var spawn_pos: Vector3 = Vector3.ZERO
	if target:
		spawn_pos = target.global_position + Vector3(0.0, 0.5, 0.0)
	elif hub and hub is Node3D:
		spawn_pos = (hub as Node3D).global_position + Vector3(0.0, 0.5, 0.0)
	elif get_parent() is Node3D:
		spawn_pos = (get_parent() as Node3D).global_position + Vector3(0.0, 0.5, 0.0)

	# Finde einen 3D-Knoten in der Szene zum Einhängen
	var spawn_parent: Node = null
	if hub and hub is Node3D and is_instance_valid(hub):
		spawn_parent = hub
	elif get_parent() is Node3D:
		spawn_parent = get_parent()
	elif get_tree() and get_tree().current_scene:
		spawn_parent = get_tree().current_scene
	else:
		spawn_parent = self

	if custom_particles_scene:
		var part = custom_particles_scene.instantiate()
		spawn_parent.add_child(part)
		if part is Node3D:
			part.global_position = spawn_pos
		return

	# Prozeduraler, ultra-kompatibler CPUParticles3D-Puff
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 18
	particles.lifetime = 0.75
	particles.speed_scale = 1.0
	particles.direction = Vector3.UP
	particles.spread = 120.0
	particles.gravity = Vector3(0.0, -3.0, 0.0)
	particles.initial_velocity_min = 2.2
	particles.initial_velocity_max = 3.8
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.25

	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.92, 0.4, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.25)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	particles.mesh = sphere

	# Sanftes Schrumpfen / Ausfaden vor dem Verschwinden
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(0.65, 0.95))
	curve.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = curve

	spawn_parent.add_child(particles)
	if spawn_parent is Node3D:
		particles.global_position = spawn_pos
	else:
		particles.position = spawn_pos
	particles.emitting = true

	# Automatisch nach Lebenszeit freigeben
	var tree := get_tree()
	if tree:
		var timer := tree.create_timer(particles.lifetime + 0.15)
		timer.timeout.connect(func():
			if is_instance_valid(particles):
				particles.queue_free()
		)

func _kill_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = null
