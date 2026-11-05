@tool
class_name BouncePadBehavior
extends ObjectBehavior

## Baustein: Sprung-Plattform / Trampolin (BouncePadBehavior).
## Katapultiert den Spieler oder Kisten/Blöcke mit einstellbarer Kraft in die Luft.
## Unterstützt Super-Bounce (erhöhte Sprungkraft bei Jump-Tastendruck im Moment des Aufpralls),
## elastisches Durchfedern (Rebound-Animation), Soundeffekte und Zielfernsteuerung.

signal bounced(body: Node, force: float, is_super: bool)

enum LaunchDirectionMode {
	WORLD_UP = 0,             ## Immer absolut senkrecht nach oben (Vector3.UP)
	PAD_UP = 1,               ## Entlang der Plattform-Ausrichtung (Basis-Y, für geneigte Katapulte)
	PLAYER_FORWARD_BIASED = 2 ## Senkrecht nach oben + dynamischer Schub in Spieler-Blickrichtung
}

@export_group("Jump Settings")
@export_range(5.0, 50.0, 0.5) var bounce_velocity: float = 16.0:
	set(val):
		bounce_velocity = val
		notify_state_changed()

@export var allow_super_bounce: bool = true:
	set(val):
		allow_super_bounce = val
		notify_state_changed()

@export_range(5.0, 60.0, 0.5) var super_bounce_velocity: float = 22.0:
	set(val):
		super_bounce_velocity = val
		notify_state_changed()

@export var launch_direction_mode: LaunchDirectionMode = LaunchDirectionMode.WORLD_UP:
	set(val):
		launch_direction_mode = val
		notify_state_changed()

@export_range(0.0, 30.0, 0.5) var forward_boost: float = 0.0:
	set(val):
		forward_boost = val
		notify_state_changed()

@export_range(0.05, 1.0, 0.05) var cooldown: float = 0.2:
	set(val):
		cooldown = val
		notify_state_changed()

@export_group("Filter & Detection")
@export var trigger_by_player: bool = true
@export var trigger_by_blocks: bool = true
@export var trigger_area_path: NodePath = NodePath("TriggerArea")

@export_group("Visual Feedback & Audio")
@export var visual_node_path: NodePath = NodePath("Visual")
@export var rebound_animation_enabled: bool = true
@export_range(0.05, 0.6, 0.05) var rebound_depth: float = 0.25
@export_range(0.1, 0.8, 0.02) var rebound_duration: float = 0.32
@export var bounce_sound: AudioStream = null
@export var sound_pitch_min: float = 0.95
@export var sound_pitch_max: float = 1.12

@export_group("Water Bobbing")
@export var water_bob_enabled: bool = false
@export_range(0.0, 0.4, 0.01) var water_bob_height: float = 0.07
@export_range(0.2, 6.0, 0.1) var water_bob_speed: float = 2.0
@export_range(0.0, 20.0, 0.5) var water_bob_tilt_deg: float = 4.5

@export_group("Targets & Remote Control")
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()

@export var target_method: String = "activate"

@export_group("Toast Feedback")
@export var activate_toast_badge: String = "🦘"
@export var activate_toast_title: String = "TRAMPOLIN"
@export var activate_toast_message: String = ""

var _overlapping_bodies: Array[Node] = []
var _cooldown_timer: float = 0.0
var _rebound_tween: Tween = null
var _base_visual_scale: Vector3 = Vector3.ONE
var _base_visual_pos: Vector3 = Vector3.ZERO
var _base_visual_rot: Vector3 = Vector3.ZERO
var _initialized_transforms: bool = false
var _audio_player: AudioStreamPlayer3D = null
var _bob_time: float = 0.0
var _bob_phase: float = 0.0
var _bob_dip: float = 0.0
var _bob_impact_tilt: Vector2 = Vector2.ZERO

func _ready() -> void:
	target_objects = target_objects.duplicate()
	_resolve_hub()
	_cache_visual_transform()
	_setup_trigger_area()
	if hub and hub is Node3D:
		var gp := (hub as Node3D).global_position
		_bob_phase = gp.x * 0.45 + gp.z * 0.35
	if not Engine.is_editor_hint():
		call_deferred("_setup_audio_player")

## Sprung-Plattformen werden rein physisch betreten, nicht mit der Taste 'E' bedient.
func can_interact(_player: Node) -> bool:
	return false

func get_prompt() -> String:
	return ""

func _exit_tree() -> void:
	var area := _get_trigger_area()
	if area:
		if area.body_entered.is_connected(_on_body_entered):
			area.body_entered.disconnect(_on_body_entered)
		if area.body_exited.is_connected(_on_body_exited):
			area.body_exited.disconnect(_on_body_exited)
	if _rebound_tween and _rebound_tween.is_valid():
		_rebound_tween.kill()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if _cooldown_timer > 0.0:
		_cooldown_timer = maxf(0.0, _cooldown_timer - delta)

	# Wasser-Wippen (Sanftes Schaukeln auf Wellen + Einknicken beim Aufprall)
	if water_bob_enabled:
		var vis := _get_visual_node()
		if vis:
			_cache_visual_transform()
			if _bob_phase == 0.0 and hub and hub is Node3D:
				var gp := (hub as Node3D).global_position
				_bob_phase = gp.x * 0.45 + gp.z * 0.35
			_bob_time += delta * water_bob_speed
			_bob_dip = lerpf(_bob_dip, 0.0, 1.0 - exp(-6.5 * delta))
			_bob_impact_tilt = _bob_impact_tilt.lerp(Vector2.ZERO, 1.0 - exp(-5.5 * delta))
			var wave_y := sin(_bob_time + _bob_phase) * water_bob_height - _bob_dip
			var tilt_rad := deg_to_rad(water_bob_tilt_deg)
			var wave_rx := sin(_bob_time * 0.85 + _bob_phase * 1.3) * tilt_rad + _bob_impact_tilt.x
			var wave_rz := cos(_bob_time * 0.95 + _bob_phase * 0.9) * tilt_rad + _bob_impact_tilt.y
			vis.position = Vector3(_base_visual_pos.x, _base_visual_pos.y + wave_y, _base_visual_pos.z)
			vis.rotation = Vector3(_base_visual_rot.x + wave_rx, _base_visual_rot.y, _base_visual_rot.z + wave_rz)

	# Prüfen, ob Körper auf der Plattform stehen oder landen
	if _cooldown_timer <= 0.0 and not _overlapping_bodies.is_empty():
		for body in _overlapping_bodies:
			if not is_instance_valid(body):
				continue
			if body is CharacterBody3D:
				var cb := body as CharacterBody3D
				# Auslösen, wenn der Körper nach unten fällt oder auf dem Boden steht
				if cb.velocity.y <= 1.5 or cb.is_on_floor():
					trigger_bounce(cb)
					break
			elif body is RigidBody3D:
				var rb := body as RigidBody3D
				if rb.linear_velocity.y <= 1.5:
					trigger_bounce(rb)
					break

func _cache_visual_transform() -> void:
	if _initialized_transforms:
		return
	var vis := _get_visual_node()
	if vis:
		_base_visual_scale = vis.scale
		_base_visual_pos = vis.position
		_base_visual_rot = vis.rotation
		_initialized_transforms = true

func _get_visual_node() -> Node3D:
	_resolve_hub()
	var vis: Node3D = null
	if hub and not visual_node_path.is_empty():
		vis = hub.get_node_or_null(visual_node_path) as Node3D
	if not vis and not visual_node_path.is_empty():
		vis = get_node_or_null(visual_node_path) as Node3D
	if not vis and hub:
		vis = hub.find_child("Visual", false, false) as Node3D
	if not vis and hub and hub is Node3D:
		vis = hub as Node3D
	return vis

func _get_trigger_area() -> Area3D:
	_resolve_hub()
	var area: Area3D = null
	if hub and not trigger_area_path.is_empty():
		area = hub.get_node_or_null(trigger_area_path) as Area3D
	if not area and not trigger_area_path.is_empty():
		area = get_node_or_null(trigger_area_path) as Area3D
	if not area and hub:
		area = hub.find_child("TriggerArea", true, false) as Area3D
	if not area and hub:
		area = hub.find_child("BounceArea", true, false) as Area3D
	return area

func _setup_trigger_area() -> void:
	var area := _get_trigger_area()
	if not area:
		return
	if not area.body_entered.is_connected(_on_body_entered):
		area.body_entered.connect(_on_body_entered)
	if not area.body_exited.is_connected(_on_body_exited):
		area.body_exited.connect(_on_body_exited)

func _setup_audio_player() -> void:
	if _audio_player or not is_inside_tree():
		return
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "BounceAudio"
	_audio_player.unit_size = 12.0
	_audio_player.max_distance = 35.0
	var parent_node: Node = _get_visual_node()
	if not parent_node and hub:
		parent_node = hub
	if not parent_node:
		parent_node = self
	parent_node.add_child(_audio_player)

func _is_valid_body(body: Node) -> bool:
	if not body or not is_instance_valid(body):
		return false
	if trigger_by_player:
		if body is CharacterBody3D or body.is_in_group("player") or body.name == "Player":
			return true
	if trigger_by_blocks:
		if body.is_in_group("pushables") or body is RigidBody3D:
			return true
		if body.get_parent() and body.get_parent().is_in_group("pushables"):
			return true
	return false

func _on_body_entered(body: Node) -> void:
	if not _is_valid_body(body):
		return
	if not _overlapping_bodies.has(body):
		_overlapping_bodies.append(body)

func _on_body_exited(body: Node) -> void:
	_overlapping_bodies.erase(body)

## Löst den Katapult-Sprung für den übergebenen Körper (oder den ersten anwesenden) aus.
func trigger_bounce(body: Node = null) -> void:
	if not is_inside_tree() and body == null:
		return

	if body == null:
		if not _overlapping_bodies.is_empty():
			body = _overlapping_bodies[0]
		else:
			# Fallback: Spieler in Szene suchen
			body = get_tree().get_first_node_in_group("player")

	if not body or not is_instance_valid(body):
		return

	# Super-Bounce Ermittlung: Drückt oder hält der Spieler im Moment des Aufpralls die Sprungtaste?
	var is_super := false
	if allow_super_bounce:
		if body.has_method("_is_jump_held") and body.call("_is_jump_held"):
			is_super = true
		elif body.has_method("_is_jump_just_pressed") and body.call("_is_jump_just_pressed"):
			is_super = true
		elif "jump_buffer_timer" in body and body.get("jump_buffer_timer") > 0.0:
			is_super = true
		elif Input.is_action_pressed("jump") or Input.is_action_pressed("ui_accept"):
			is_super = true

	var effective_force := super_bounce_velocity if is_super else bounce_velocity

	# Berechne Richtungsvektor
	var launch_vec := Vector3.ZERO
	match launch_direction_mode:
		LaunchDirectionMode.WORLD_UP:
			launch_vec = Vector3.UP * effective_force
			if forward_boost > 0.0:
				var fwd := _get_body_forward_direction(body)
				launch_vec += fwd * forward_boost
		LaunchDirectionMode.PAD_UP:
			var pad_basis := Basis()
			var vis := _get_visual_node()
			if vis:
				pad_basis = vis.global_transform.basis
			elif hub and hub is Node3D:
				pad_basis = (hub as Node3D).global_transform.basis
			var pad_up := pad_basis.y.normalized()
			launch_vec = pad_up * effective_force
			if forward_boost > 0.0:
				var pad_fwd := -pad_basis.z.normalized()
				launch_vec += pad_fwd * forward_boost
		LaunchDirectionMode.PLAYER_FORWARD_BIASED:
			launch_vec = Vector3.UP * effective_force
			var fwd := _get_body_forward_direction(body)
			launch_vec += fwd * maxf(forward_boost, 4.5)

	# Impuls auf den Körper übertragen
	if body.has_method("bounce"):
		var horiz_boost := Vector3(launch_vec.x, 0.0, launch_vec.z)
		body.bounce(launch_vec.y, horiz_boost, is_super)
	elif body is CharacterBody3D:
		var cb := body as CharacterBody3D
		cb.velocity = launch_vec
		if "_air_spin_counter" in cb: cb.set("_air_spin_counter", 0)
		if "_air_dash_counter" in cb: cb.set("_air_dash_counter", 0)
		if "_spin_timer" in cb: cb.set("_spin_timer", 0.0)
		if "_dash_timer" in cb: cb.set("_dash_timer", 0.0)
	elif body is RigidBody3D:
		var rb := body as RigidBody3D
		rb.linear_velocity = launch_vec

	# Visuelle Feder-Animation (Squash & Rebound) + Wipp-Impuls
	if water_bob_enabled:
		_bob_dip = 0.22 * (1.3 if is_super else 1.0)
		if body is Node3D and hub and hub is Node3D:
			var offset := (body as Node3D).global_position - (hub as Node3D).global_position
			_bob_impact_tilt = Vector2(
				clampf(offset.z * 0.18, -0.22, 0.22),
				clampf(-offset.x * 0.18, -0.22, 0.22)
			)
	_play_rebound_animation(is_super)

	# Sound abspielen
	_play_bounce_audio(is_super)

	# Cooldown setzen
	_cooldown_timer = cooldown

	# Signale und Hub-Events
	bounced.emit(body, effective_force, is_super)
	_resolve_hub()
	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"bounced", {
			"body": body,
			"force": effective_force,
			"is_super": is_super
		})

	# Ziel-Objekte ansteuern
	_trigger_targets()

	# Optional Toast Feedback
	if not activate_toast_message.is_empty():
		_show_toast(activate_toast_message)

func _get_body_forward_direction(body: Node) -> Vector3:
	if not body:
		return Vector3.FORWARD
	if "move_direction" in body and body.get("move_direction") != Vector3.ZERO:
		return (body.get("move_direction") as Vector3).normalized()
	if body is Node3D:
		var n3d := body as Node3D
		# Prüfe, ob Visual existiert
		var vis := n3d.find_child("Visual", false, false) as Node3D
		if vis:
			return -vis.global_transform.basis.z.normalized()
		return -n3d.global_transform.basis.z.normalized()
	return Vector3.FORWARD

func _play_rebound_animation(is_super: bool = false) -> void:
	if not rebound_animation_enabled:
		return
	var vis := _get_visual_node()
	if not vis:
		return
	_cache_visual_transform()

	if _rebound_tween and _rebound_tween.is_valid():
		_rebound_tween.kill()

	var depth := rebound_depth * (1.3 if is_super else 1.0)
	var dur := rebound_duration

	_rebound_tween = create_tween()
	# Phase 1: Schnell nach unten eindrücken und seitlich ausbeulen
	var squash_scale := Vector3(
		_base_visual_scale.x * (1.0 + depth * 0.4),
		_base_visual_scale.y * maxf(0.3, 1.0 - depth),
		_base_visual_scale.z * (1.0 + depth * 0.4)
	)
	_rebound_tween.tween_property(vis, "scale", squash_scale, dur * 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Phase 2: Elastisch nach oben überschwingen (Rebound Launch)
	var stretch_scale := Vector3(
		_base_visual_scale.x * (1.0 - depth * 0.2),
		_base_visual_scale.y * (1.0 + depth * 0.5),
		_base_visual_scale.z * (1.0 - depth * 0.2)
	)
	_rebound_tween.tween_property(vis, "scale", stretch_scale, dur * 0.38)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Phase 3: Sanft zurück in die Ausgangsform ausschwingen
	_rebound_tween.tween_property(vis, "scale", _base_visual_scale, dur * 0.4)\
		.set_trans(Tween.TRANS_SPRING).set_ease(Tween.EASE_OUT)
	_rebound_tween.tween_callback(func():
		if is_instance_valid(vis):
			vis.scale = _base_visual_scale
	)

func _play_bounce_audio(is_super: bool = false) -> void:
	if not bounce_sound:
		return
	if not _audio_player:
		_setup_audio_player()
	if _audio_player and is_instance_valid(_audio_player):
		_audio_player.stream = bounce_sound
		var base_pitch: float = randf_range(sound_pitch_min, sound_pitch_max)
		_audio_player.pitch_scale = base_pitch * (1.14 if is_super else 1.0)
		_audio_player.play()

func _trigger_targets() -> void:
	for target_path in target_objects:
		if target_path.is_empty():
			continue
		var target: Node = null
		if hub:
			target = hub.get_node_or_null(target_path)
		if not target:
			target = get_node_or_null(target_path)
		if not target and get_tree() and get_tree().current_scene:
			target = get_tree().current_scene.get_node_or_null(target_path)

		if target and target.has_method(target_method):
			target.call(target_method)

func _show_toast(msg: String) -> void:
	_resolve_hub()
	if hub and hub.has_method("show_toast"):
		hub.call("show_toast", activate_toast_badge, activate_toast_title, msg)
	elif get_tree():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.call("show_toast", activate_toast_badge, activate_toast_title, msg)
