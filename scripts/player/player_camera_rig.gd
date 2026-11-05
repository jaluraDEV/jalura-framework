class_name PlayerCameraRig
extends Node

## PlayerCameraRig
## Unified camera controller for Barnaby.
## Single authoritative owner for $CameraPivot, SpringArm3D, and Camera3D transforms.
## Manages mouse/gamepad orbit, vertical step offset absorption, water surface clamping/freezing,
## dynamic FOV kicks, and proximity dither dissolving.

signal camera_snapped(yaw: float, pitch: float)
signal camera_frozen_at_water(surface_y: float)
signal camera_unfrozen

@export_group("Orbit & Sensitivity")
@export var mouse_sensitivity: float = 0.002
@export var stick_sensitivity: float = 3.2
@export var min_pitch: float = -60.0 # Degrees looking up
@export var max_pitch: float = 30.0  # Degrees looking down

@export_group("Proximity Fade")
@export var camera_fade_enabled: bool = true
@export var fade_start_distance: float = 1.30 ## Distance where model begins to dissolve
@export var fade_end_distance: float = 0.45   ## Distance where model is completely invisible
@export_enum("Dither", "Smooth Alpha") var fade_style: int = 0

@export_group("Dynamic FOV")
@export var camera_fov_kick_enabled: bool = true
@export var fov_smooth_speed: float = 7.5

@export_group("Water Surface Clamping")
@export var camera_min_y_above_water: float = 0.85 ## Minimum camera pivot height above water surface
@export var camera_min_lens_above_water: float = 0.40 ## Minimum Camera3D lens height above water surface

@export_group("Base Pivot Placement")
@export var base_pivot_offset: Vector3 = Vector3(0.0, 1.45, 0.0)

var player: CharacterBody3D
var camera_pivot: Node3D
var spring_arm: SpringArm3D
var camera: Camera3D
var visual: Node3D

var visual_offset: float = 0.0
var is_water_frozen: bool = false
var _frozen_pivot_transform: Transform3D = Transform3D.IDENTITY
var _water_surface_y: float = 0.0
var _water_min_above: float = 0.85

# FOV state
var _base_camera_fov: float = 70.0
var _target_camera_fov: float = 70.0

# Proximity fade state
var _fade_meshes: Array[GeometryInstance3D] = []
var _current_fade_alpha: float = 1.0

func setup(
	p_player: CharacterBody3D,
	p_camera_pivot: Node3D,
	p_camera: Camera3D,
	p_spring_arm: SpringArm3D,
	p_visual: Node3D
) -> void:
	player = p_player
	camera_pivot = p_camera_pivot
	camera = p_camera
	spring_arm = p_spring_arm
	visual = p_visual

	if camera_pivot:
		base_pivot_offset = camera_pivot.position

	setup_camera_fov()
	if camera_fade_enabled:
		setup_proximity_fade()

## Sets the vertical step offset reported by PlayerStepClimber
func set_vertical_step_offset(offset: float) -> void:
	visual_offset = offset
	if not is_water_frozen and camera_pivot:
		camera_pivot.position = base_pivot_offset + Vector3(0.0, visual_offset, 0.0)

## Returns the current vertical step offset
func get_vertical_step_offset() -> float:
	return visual_offset

## Freezes camera above water surface to prevent seeing underneath the water shader
func freeze_at_water(surface_y: float, min_above_water: float = 0.85) -> void:
	if not camera_pivot:
		return
	is_water_frozen = true
	_water_surface_y = surface_y
	_water_min_above = min_above_water
	_frozen_pivot_transform = camera_pivot.global_transform
	var min_y := surface_y + min_above_water
	if _frozen_pivot_transform.origin.y < min_y:
		_frozen_pivot_transform.origin.y = min_y
	camera_pivot.global_transform = _frozen_pivot_transform
	camera_frozen_at_water.emit(surface_y)

## Releases the water freeze and positions camera behind Barnaby at safe yaw
func unfreeze_water(respawn_yaw: float = 0.0) -> void:
	is_water_frozen = false
	if camera_pivot:
		camera_pivot.position = base_pivot_offset
		camera_pivot.rotation.y = respawn_yaw
		camera_pivot.rotation.x = deg_to_rad(-12.0)
		camera_pivot.rotation.z = 0.0
	camera_unfrozen.emit()

func is_frozen() -> bool:
	return is_water_frozen

## Snaps the camera pivot immediately to target orientation (e.g. after scene transition)
func snap_camera(yaw: float, pitch_deg: float = -12.0) -> void:
	is_water_frozen = false
	if camera_pivot:
		camera_pivot.position = base_pivot_offset + Vector3(0.0, visual_offset, 0.0)
		camera_pivot.rotation.y = yaw
		camera_pivot.rotation.x = deg_to_rad(pitch_deg)
		camera_pivot.rotation.z = 0.0
	camera_snapped.emit(yaw, deg_to_rad(pitch_deg))

## Handles mouse look input (only active when player camera is the active viewport camera)
func process_orbit_mouse(event: InputEventMouseMotion) -> void:
	if is_water_frozen or not camera_pivot:
		return
	if camera and not camera.current:
		return

	var cm = get_node_or_null("/root/CameraManager")
	var sens: float = cm.mouse_sensitivity if cm else mouse_sensitivity
	var invert: float = -1.0 if (cm and cm.invert_y) else 1.0

	camera_pivot.rotate_y(-event.relative.x * sens)
	camera_pivot.rotation.x = clamp(
		camera_pivot.rotation.x - event.relative.y * sens * invert,
		deg_to_rad(min_pitch),
		deg_to_rad(max_pitch)
	)
	camera_pivot.rotation.z = 0.0

## Handles gamepad right-stick orbit (only active when player camera is active)
func process_orbit_gamepad(delta: float) -> void:
	if is_water_frozen or not camera_pivot:
		return
	if camera and not camera.current:
		return

	var rx := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var ry := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var r_vec := Vector2(rx, ry)
	if r_vec.length() > 0.15:
		var r_len := r_vec.length()
		var remapped := clampf((r_len - 0.15) / (1.0 - 0.15), 0.0, 1.0)
		var curved_speed := remapped * remapped # Smooth quadratic ease-in
		var r_dir := r_vec.normalized()

		var cm = get_node_or_null("/root/CameraManager")
		var s_sens: float = cm.stick_sensitivity if cm else stick_sensitivity
		var invert: float = -1.0 if (cm and cm.invert_y) else 1.0

		camera_pivot.rotate_y(-r_dir.x * curved_speed * s_sens * delta)
		camera_pivot.rotation.x = clamp(
			camera_pivot.rotation.x - r_dir.y * curved_speed * s_sens * delta * invert,
			deg_to_rad(min_pitch),
			deg_to_rad(max_pitch)
		)
		camera_pivot.rotation.z = 0.0

## Updates camera transforms, FOV, and proximity dither. Single authoritative caller per frame.
func update_camera(delta: float, current_state: int = 0, current_speed: float = 0.0) -> void:
	if not camera_pivot:
		return

	if is_water_frozen:
		camera_pivot.global_transform = _frozen_pivot_transform
		var min_pivot_y := _water_surface_y + _water_min_above
		if camera_pivot.global_position.y < min_pivot_y:
			camera_pivot.global_position.y = min_pivot_y
		if camera and camera.global_position.y < _water_surface_y + camera_min_lens_above_water:
			camera.global_position.y = _water_surface_y + camera_min_lens_above_water
		return

	# Normal camera pivot position with stair absorption offset
	camera_pivot.position = base_pivot_offset + Vector3(0.0, visual_offset, 0.0)

	if camera_fov_kick_enabled:
		_update_camera_fov(delta, current_state, current_speed)

	if camera_fade_enabled:
		_update_camera_proximity_fade(delta)

# --- Dynamic FOV ---

func setup_camera_fov() -> void:
	if camera:
		_base_camera_fov = camera.fov
		_target_camera_fov = _base_camera_fov

func _update_camera_fov(delta: float, current_state: int, current_speed: float) -> void:
	if not camera or not camera_fov_kick_enabled:
		return

	# State enum matching player.gd (7: DASH, 10: LONG_JUMP, 11: AIR_DIVE, 13: GLIDE, 14: RAIL_GRIND)
	if current_state == 7 or current_state == 11: # DASH or AIR_DIVE
		_target_camera_fov = _base_camera_fov + 5.5
	elif current_state == 10: # LONG_JUMP
		_target_camera_fov = _base_camera_fov + 4.0
	elif current_state == 13: # GLIDE
		_target_camera_fov = _base_camera_fov + 2.0
	elif current_state == 14 and current_speed > 9.0: # RAIL_GRIND
		_target_camera_fov = _base_camera_fov + 2.5
	else:
		_target_camera_fov = _base_camera_fov

	camera.fov = lerp(camera.fov, _target_camera_fov, fov_smooth_speed * delta)

# --- Camera Proximity Dither / Dissolve ---

func setup_proximity_fade() -> void:
	_fade_meshes.clear()
	if visual:
		for node in visual.find_children("*", "GeometryInstance3D", true, false):
			if node is GeometryInstance3D:
				_fade_meshes.append(node)
				_apply_fade_material(node)

func _apply_fade_material(geom: GeometryInstance3D) -> void:
	var mode := BaseMaterial3D.TRANSPARENCY_ALPHA_HASH if fade_style == 0 else BaseMaterial3D.TRANSPARENCY_ALPHA
	
	if geom is MeshInstance3D and geom.mesh:
		var mesh_inst := geom as MeshInstance3D
		for s in range(mesh_inst.mesh.get_surface_count()):
			var mat: Material = mesh_inst.get_active_material(s)
			if mat is StandardMaterial3D:
				var dup := mat.duplicate() as StandardMaterial3D
				dup.transparency = mode
				mesh_inst.set_surface_override_material(s, dup)
				
	if geom.material_override is StandardMaterial3D:
		var dup := geom.material_override.duplicate() as StandardMaterial3D
		dup.transparency = mode
		geom.material_override = dup

func set_camera_fade_enabled(p_enabled: bool) -> void:
	camera_fade_enabled = p_enabled
	if not p_enabled:
		_current_fade_alpha = 1.0
		for geom in _fade_meshes:
			if is_instance_valid(geom):
				geom.transparency = 0.0
				_sync_prop_visibility(geom, 1.0)
	else:
		setup_proximity_fade()

func get_fade_alpha() -> float:
	return _current_fade_alpha

func _update_camera_proximity_fade(delta: float) -> void:
	if not camera_fade_enabled or not camera or not camera_pivot or _fade_meshes.is_empty():
		return

	# If player camera is not the active viewport camera (e.g. Diorama mode), smoothly restore full opacity
	if not camera.current:
		if _current_fade_alpha < 1.0:
			_current_fade_alpha = move_toward(_current_fade_alpha, 1.0, delta * 14.0)
			var cur_transparency := 1.0 - _current_fade_alpha
			for geom in _fade_meshes:
				if is_instance_valid(geom):
					geom.transparency = cur_transparency
					_sync_prop_visibility(geom, _current_fade_alpha)
		return

	var focus_point := camera_pivot.global_position
	var cam_dist := camera.global_position.distance_to(focus_point)

	var span := maxf(fade_start_distance - fade_end_distance, 0.01)
	var target_alpha := clampf((cam_dist - fade_end_distance) / span, 0.0, 1.0)

	_current_fade_alpha = move_toward(_current_fade_alpha, target_alpha, delta * 14.0)
	var transparency_val := 1.0 - _current_fade_alpha

	for geom in _fade_meshes:
		if is_instance_valid(geom):
			geom.transparency = transparency_val
			_sync_prop_visibility(geom, _current_fade_alpha)

func _sync_prop_visibility(geom: GeometryInstance3D, alpha: float) -> void:
	if player and player.has_method("_sync_prop_fade_visibility"):
		player._sync_prop_fade_visibility(geom, alpha)
	else:
		geom.visible = (alpha > 0.01)
