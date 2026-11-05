class_name PlayerWaterHazard
extends Node

## PlayerWaterHazard
## Modular component for water immersion detection, safe-ground respawning,
## camera surface clamping (never reveals the void under water shader),
## splash effects, and cartoon recovery ("wet cat shake").

signal water_entered(water_type: String, position: Vector3)
signal respawn_started(respawn_position: Vector3)
signal respawn_completed(respawn_position: Vector3)

@export var enabled: bool = true
@export var ocean_water_level: float = 0.0          ## Surface height of the main ocean plane
@export var submersion_depth: float = 0.30          ## How far player dips below water surface before wipeout triggers
@export var camera_min_y_above_water: float = 0.85  ## Guaranteed minimum camera pivot height above water
@export var safe_ground_min_height: float = 0.80    ## Minimum height above water to qualify as safe ground
@export var fade_duration: float = 0.28             ## Screen fade in/out duration
@export var shake_duration: float = 0.55            ## Duration of the "wet cat shake" at respawn

var player: CharacterBody3D
var visual: Node3D
var camera_pivot: Node3D
var camera: Camera3D
var camera_rig: Node = null

var last_safe_position: Vector3 = Vector3.ZERO
var last_safe_yaw: float = 0.0
var has_safe_position: bool = false
var is_recovering: bool = false

var _grounded_safe_timer: float = 0.0
var _camera_frozen: bool = false:
	set(v):
		_camera_frozen = v
		if not v and camera_rig and camera_rig.has_method("unfreeze_water"):
			camera_rig.is_water_frozen = false
var _frozen_pivot_transform: Transform3D = Transform3D.IDENTITY
var _active_water_level: float = 0.0
var _active_is_toxic: bool = false

# Sound effects
var _splash_sfx_0: AudioStream = null
var _splash_sfx_1: AudioStream = null
var _audio_player: AudioStreamPlayer3D

# Screen wipe overlay
var _canvas_layer: CanvasLayer
var _overlay_rect: ColorRect

# Registered local water bodies (e.g. crater lake, pools)
var _water_zones: Array[Dictionary] = []
var _water_zone_objects: Array[Node] = []
var _active_respawn_position: Vector3 = Vector3.ZERO

func setup(p_player: CharacterBody3D, p_visual: Node3D, p_camera_pivot: Node3D, p_camera: Camera3D, p_camera_rig: Node = null) -> void:
	player = p_player
	visual = p_visual
	camera_pivot = p_camera_pivot
	camera = p_camera
	camera_rig = p_camera_rig

	_setup_audio()
	_setup_overlay()
	_scan_existing_water_zones()
	_register_default_zones()

	# Initialize default safe position to player's starting transform
	if player:
		last_safe_position = player.global_position
		last_safe_yaw = visual.rotation.y if visual else 0.0
		has_safe_position = true

func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "WaterHazardAudio"
	_audio_player.bus = "Master"
	_audio_player.max_distance = 60.0
	_audio_player.unit_size = 10.0
	add_child(_audio_player)

func _setup_overlay() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.name = "WaterHazardOverlay"
	_canvas_layer.layer = 126 # Above game HUD and scene transition

	_overlay_rect = ColorRect.new()
	_overlay_rect.name = "WaterVignette"
	_overlay_rect.color = Color(0.04, 0.22, 0.45, 0.0) # Deep aquatic blue
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	_canvas_layer.add_child(_overlay_rect)
	add_child(_canvas_layer)

func register_water_zone_object(zone: Node) -> void:
	if zone and not _water_zone_objects.has(zone):
		_water_zone_objects.append(zone)

func unregister_water_zone_object(zone: Node) -> void:
	if zone:
		_water_zone_objects.erase(zone)

func _prune_invalid_water_zones() -> void:
	var i := _water_zone_objects.size() - 1
	while i >= 0:
		if not is_instance_valid(_water_zone_objects[i]):
			_water_zone_objects.remove_at(i)
		i -= 1

func _scan_existing_water_zones() -> void:
	var tree := get_tree()
	if not tree:
		return
	for node in tree.get_nodes_in_group("water_zones"):
		register_water_zone_object(node)

func _register_default_zones() -> void:
	# Feste Weltkoordinaten in Phase 3 entfernt.
	# Wasser-Zonen werden nun als modulare WaterZone-Weltobjekte in den Szenen platziert.
	pass

func register_water_zone(center: Vector3, size: Vector2, surface_y: float, toxic: bool = false, zone_name: String = "water") -> void:
	_water_zones.append({
		"center": center,
		"size": size,
		"surface_y": surface_y,
		"is_toxic": toxic,
		"name": zone_name
	})

func process_hazard(delta: float) -> void:
	if not enabled or not player:
		return

	# If camera is frozen above water during immersion wipeout, keep it pinned
	if _camera_frozen:
		if camera_rig and camera_rig.has_method("is_frozen") and camera_rig.is_frozen():
			return
		elif camera_pivot:
			camera_pivot.global_transform = _frozen_pivot_transform
			var min_pivot_y := _active_water_level + camera_min_y_above_water
			if camera_pivot.global_position.y < min_pivot_y:
				camera_pivot.global_position.y = min_pivot_y
			if camera and camera.global_position.y < _active_water_level + 0.40:
				camera.global_position.y = _active_water_level + 0.40
			return

	if is_recovering:
		return

	# Respect scene transitions, room manager transitions, and active dialogue
	var st: Node = get_node_or_null("/root/SceneTransition")
	if st and st.get("is_transitioning") == true:
		return
	var rm: Node = get_node_or_null("/root/RoomManager")
	if rm and rm.get("is_transitioning") == true:
		return
	var hud := _get_active_hud()
	if hud and "is_dialogue_active" in hud and hud.is_dialogue_active:
		return

	# 1. Track safe grounded position
	_update_safe_ground(delta)

	# 2. Check for water immersion or void fall
	_check_water_immersion()

func _get_active_hud() -> Node:
	if not player or not is_inside_tree():
		return null
	var hud := player.find_child("HUD", true, false)
	if not hud and get_tree() and get_tree().current_scene:
		hud = get_tree().current_scene.find_child("HUD", true, false)
	return hud

func _is_interior_scene() -> bool:
	var cur_scene := get_tree().current_scene if get_tree() else null
	if not cur_scene and player and player.is_inside_tree():
		var p: Node = player
		while p.get_parent() and p.get_parent() != get_tree().root:
			p = p.get_parent()
		cur_scene = p
	if not cur_scene:
		# Wenn weder Ocean noch aktuelle Szene ermittelbar ist, prüfen ob SceneTransition aktiv ist
		var st = get_node_or_null("/root/SceneTransition")
		if st and st.get("current_scene_id") in [&"bootskabine", &"kramerladen", &"omas_haus", &"pumpenhaus"]:
			return true
		return false
	if cur_scene.find_child("Ocean", true, false) != null:
		return false
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("is_in_interior") and rm.is_in_interior():
		return true
	var st = get_node_or_null("/root/SceneTransition")
	if st and st.get("current_scene_id") in [&"bootskabine", &"kramerladen", &"omas_haus", &"pumpenhaus"]:
		return true
	var sc_name := cur_scene.name.to_lower()
	if sc_name.contains("cabin") or sc_name.contains("interior") or sc_name.contains("ship"):
		return true
	return true

func _update_safe_ground(delta: float) -> void:
	if not player.is_on_floor():
		_grounded_safe_timer = 0.0
		return

	# In Außenbereichen: Muss über dem Ozean liegen (in Innenräumen entfällt diese Prüfung)
	if not _is_interior_scene():
		if player.global_position.y <= ocean_water_level + safe_ground_min_height:
			_grounded_safe_timer = 0.0
			return

	_prune_invalid_water_zones()

	# Check modular water zone objects
	for wz in _water_zone_objects:
		if not is_instance_valid(wz) or not wz.is_inside_tree() or not wz.enabled:
			continue
		var c: Vector3 = wz.get_center()
		var s: Vector2 = wz.size
		if absf(player.global_position.x - c.x) <= s.x * 0.5 and absf(player.global_position.z - c.z) <= s.y * 0.5:
			if player.global_position.y <= wz.get_surface_y() + safe_ground_min_height:
				_grounded_safe_timer = 0.0
				return

	# Check legacy raw water zones
	for zone in _water_zones:
		var c: Vector3 = zone["center"]
		var s: Vector2 = zone["size"]
		if absf(player.global_position.x - c.x) <= s.x * 0.5 and absf(player.global_position.z - c.z) <= s.y * 0.5:
			if player.global_position.y <= zone["surface_y"] + safe_ground_min_height:
				_grounded_safe_timer = 0.0
				return

	# Floor must be reasonably flat (normal.y >= 0.82)
	var floor_norm := player.get_floor_normal()
	if floor_norm.y < 0.82:
		_grounded_safe_timer = 0.0
		return

	# Must not be moving at extreme speed (e.g. being launched or skidding off a cliff)
	if Vector2(player.velocity.x, player.velocity.z).length() > 8.0:
		return

	_grounded_safe_timer += delta
	# Record position after staying grounded and stable for 0.22 seconds
	if _grounded_safe_timer >= 0.22:
		last_safe_position = player.global_position
		last_safe_yaw = visual.rotation.y if visual else 0.0
		has_safe_position = true

func _check_water_immersion() -> void:
	var pos := player.global_position

	# Check 1: Fall off world into void
	# In Innenräumen fängt die Schutzebene bereits 2m unter dem Boden (verhindert Fallen ins Endlose)
	var is_interior := _is_interior_scene()
	var void_limit: float = -2.0 if is_interior else -15.0
	if pos.y < void_limit:
		_trigger_respawn(ocean_water_level if not is_interior else 0.0, false, "void")
		return

	if is_interior:
		return

	_prune_invalid_water_zones()

	# Check 2: Modular WaterZone objects (Seen, Teiche, Becken)
	for wz in _water_zone_objects:
		if not is_instance_valid(wz) or not wz.is_inside_tree() or not wz.enabled:
			continue
		if wz.is_submerged(pos):
			var custom_respawn: Vector3 = wz.get_respawn_position()
			_trigger_respawn(wz.get_surface_y(), wz.is_toxic, wz.zone_name, custom_respawn)
			return

	# Check 2b: Legacy local water bodies
	for zone in _water_zones:
		var c: Vector3 = zone["center"]
		var s: Vector2 = zone["size"]
		if absf(pos.x - c.x) <= s.x * 0.5 and absf(pos.z - c.z) <= s.y * 0.5:
			var surface: float = zone["surface_y"]
			if pos.y <= surface - submersion_depth:
				_trigger_respawn(surface, zone["is_toxic"], zone["name"])
				return

	# Check 3: Global Ocean Water Plane
	if pos.y <= ocean_water_level - submersion_depth:
		_trigger_respawn(ocean_water_level, false, "ocean")

func _trigger_respawn(surface_y: float, is_toxic: bool, water_type: String, custom_respawn: Vector3 = Vector3.ZERO) -> void:
	if is_recovering:
		return

	is_recovering = true
	_active_water_level = surface_y
	_active_is_toxic = is_toxic
	_active_respawn_position = custom_respawn

	water_entered.emit(water_type, player.global_position)
	respawn_started.emit(last_safe_position)

	# 1. Freeze camera immediately above water level so it never dips under the water shader!
	_camera_frozen = true
	if camera_rig and camera_rig.has_method("freeze_at_water"):
		camera_rig.freeze_at_water(surface_y, camera_min_y_above_water)
	elif camera_pivot:
		_frozen_pivot_transform = camera_pivot.global_transform
		var min_y := surface_y + camera_min_y_above_water
		if _frozen_pivot_transform.origin.y < min_y:
			_frozen_pivot_transform.origin.y = min_y

	# 2. Halt player horizontal momentum and let them sink under surface
	player.velocity = Vector3(0.0, -1.5, 0.0)

	# 3. Audio & particle splash at water surface
	_play_splash_sound(surface_y, is_toxic)
	_spawn_splash_effect(Vector3(player.global_position.x, surface_y, player.global_position.z), is_toxic)

	# 4. Fade screen overlay
	_fade_screen(true)

	# 5. Wait for submersion & fade, then teleport and perform "wet cat shake"
	var timer := get_tree().create_timer(fade_duration + 0.15)
	timer.timeout.connect(_on_submerged_teleport)

func _play_splash_sound(surface_y: float, is_toxic: bool) -> void:
	if not _audio_player:
		return
	_audio_player.global_position = Vector3(player.global_position.x, surface_y, player.global_position.z)
	_audio_player.stream = _splash_sfx_0 if randf() < 0.5 else _splash_sfx_1
	_audio_player.pitch_scale = randf_range(0.92, 1.08)
	if is_toxic:
		_audio_player.pitch_scale *= 0.85 # Deeper toxic glop
	_audio_player.play()

func _spawn_splash_effect(splash_pos: Vector3, is_toxic: bool) -> void:
	# Create a lightweight cartoon droplet burst at the water surface
	var particles := CPUParticles3D.new()
	particles.name = "WaterSplashParticles"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 26
	particles.lifetime = 0.75

	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.10
	p_mesh.height = 0.20
	particles.mesh = p_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.92, 0.30, 0.95) if is_toxic else Color(0.70, 0.92, 1.0, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = mat

	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 45.0
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 6.0
	particles.gravity = Vector3(0.0, -14.0, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.4

	# Add to scene tree at water surface
	player.get_parent().add_child(particles)
	particles.global_position = splash_pos
	particles.emitting = true

	# Auto-free particles after finish
	var free_timer := get_tree().create_timer(1.2)
	free_timer.timeout.connect(particles.queue_free)

func _fade_screen(fade_in: bool) -> void:
	if not _overlay_rect:
		return
	var target_alpha := 0.95 if fade_in else 0.0
	var col := Color(0.08, 0.35, 0.15) if _active_is_toxic else Color(0.04, 0.20, 0.42)
	_overlay_rect.color.r = col.r
	_overlay_rect.color.g = col.g
	_overlay_rect.color.b = col.b

	var tween := create_tween()
	tween.tween_property(_overlay_rect, "color:a", target_alpha, fade_duration)

func _on_submerged_teleport() -> void:
	if not player:
		return

	# Szene und Ozean-Präsenz prüfen
	var cur_sc := get_tree().current_scene if get_tree() else null
	if not cur_sc and player and player.is_inside_tree():
		var p: Node = player
		while p.get_parent() and p.get_parent() != get_tree().root:
			p = p.get_parent()
		cur_sc = p
	var has_ocean: bool = cur_sc.find_child("Ocean", true, false) != null if cur_sc else false
	var is_interior: bool = not has_ocean

	# Zielposition ermitteln: Vorrang hat last_safe_position
	var target_pos := _active_respawn_position if _active_respawn_position != Vector3.ZERO else last_safe_position
	var is_valid_pos := has_safe_position and target_pos != Vector3.ZERO
	# Nur in echten Ozean-Außenszenen muss der Boden zwingend über dem Wasserspiegel liegen
	if is_valid_pos and has_ocean:
		is_valid_pos = target_pos.y > ocean_water_level + 0.1

	if not is_valid_pos:
		# Fallback 1: Finde einen SpawnPoint in der aktuellen Szene
		var sp := cur_sc.find_child("*Spawn*", true, false) as Node3D if cur_sc else null
		if sp:
			target_pos = sp.global_position
			last_safe_yaw = sp.global_rotation.y
		else:
			target_pos = Vector3(0.0, 0.5, 0.0) if is_interior else Vector3(0.0, 1.5, 4.0)

	player.global_position = target_pos
	player.velocity = Vector3.ZERO
	player.apply_floor_snap()

	# Unfreeze camera pivot and orient behind character
	_camera_frozen = false
	if camera_rig and camera_rig.has_method("unfreeze_water"):
		camera_rig.unfreeze_water(last_safe_yaw)
	elif camera_pivot:
		camera_pivot.position = Vector3(0.0, 1.45, 0.0)
		camera_pivot.rotation.y = last_safe_yaw
		camera_pivot.rotation.x = deg_to_rad(-12.0)
		camera_pivot.rotation.z = 0.0

	# Align visual facing
	if visual:
		visual.rotation.y = last_safe_yaw

	# Fade screen back in
	_fade_screen(false)

	# Execute the cartoon "Wet Cat Shake" (Barnaby shakes off water droplets!)
	_perform_wet_cat_shake()

func _perform_wet_cat_shake() -> void:
	if not visual:
		_finish_recovery()
		return

	# Spawn subtle flying droplet particles around Barnaby
	_spawn_droplet_spray()

	# Playful cartoon wobble shake tween
	var base_yaw := last_safe_yaw
	var shake_tween := create_tween()
	var step_t := shake_duration / 7.0

	shake_tween.tween_property(visual, "rotation:y", base_yaw + deg_to_rad(28.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw - deg_to_rad(28.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw + deg_to_rad(20.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw - deg_to_rad(20.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw + deg_to_rad(10.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw - deg_to_rad(10.0), step_t)
	shake_tween.tween_property(visual, "rotation:y", base_yaw, step_t)

	shake_tween.finished.connect(_finish_recovery)

func _spawn_droplet_spray() -> void:
	var droplets := CPUParticles3D.new()
	droplets.name = "WetShakeDroplets"
	droplets.emitting = false
	droplets.one_shot = true
	droplets.explosiveness = 0.7
	droplets.amount = 14
	droplets.lifetime = 0.45

	var d_mesh := SphereMesh.new()
	d_mesh.radius = 0.05
	d_mesh.height = 0.10
	droplets.mesh = d_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.75, 0.92, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	droplets.material_override = mat

	droplets.direction = Vector3(0.0, 0.5, 0.0)
	droplets.spread = 180.0
	droplets.initial_velocity_min = 1.5
	droplets.initial_velocity_max = 3.0
	droplets.gravity = Vector3(0.0, -9.8, 0.0)

	player.add_child(droplets)
	droplets.position = Vector3(0.0, 0.9, 0.0) # Chest height
	droplets.emitting = true

	var free_timer := get_tree().create_timer(0.8)
	free_timer.timeout.connect(droplets.queue_free)

func _finish_recovery() -> void:
	is_recovering = false
	respawn_completed.emit(player.global_position)
