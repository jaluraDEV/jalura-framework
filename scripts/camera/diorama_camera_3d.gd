@tool
class_name DioramaCamera3D
extends Camera3D

## Modulare, verschiebesichere Kamera für das Dankward Framework (Inspector First).
## Der Entwickler bestimmt direkt im Godot-Inspector, welcher Modus für die jeweilige
## Szene gilt (Diorama-Schiene, freie 360°-Kamera oder fester Raum).
## Kann im 3D-Editor an jede beliebige Stelle platziert werden, ohne dass
## hartcodierte Werte das Verhalten zerstören.

signal tracking_started
signal tracking_stopped

enum Mode {
	DIORAMA_RAIL = 0,    ## Folgt dem Spieler weich auf einer Schiene mit anpassbaren Grenzen
	FREE_360_ORBIT = 1,  ## Schaltet auf 360°-Spielerkamera (Maus & Analogstick)
	FIXED_ROOM = 2       ## Feste Kameraperspektive (starr im Raum, kein Mitschwenken)
}

enum Preset {
	CUSTOM = 0,
	HAFEN_STEG = 1,        ## X-Schiene mit leichtem Mitschwenken (Hafen-Typ)
	SCHIFFSKABINE = 2,     ## Kompakter Innenraum, kurze Schiene
	OFFENE_WELT_360 = 3,   ## Freie 360°-Spielerkamera
	FESTER_RAUM = 4        ## Fester Winkel (z.B. kleine Kammer oder Cutscene)
}

@export_group("🎬 Scene Camera Mode (Developer Default)")
@export var camera_mode: Mode = Mode.DIORAMA_RAIL:
	set(v):
		camera_mode = v
		_on_mode_changed()

@export_group("⚡ 1-Click Presets for Developers")
@export var apply_preset: Preset = Preset.CUSTOM:
	set(v):
		apply_preset = v
		_apply_preset_settings(v)

@export_group("🎯 Target & Rail Control")
@export var target_node: NodePath = ^"" ## Pfad zum Ziel (falls leer, wird automatisch 'Player' gesucht)
@export var tracking_enabled: bool = true ## Ob die Schienen-Verfolgung aktiv ist
@export var track_x: bool = true ## Horizontales Folgen (Links / Rechts entlang Schienenachse)
@export var track_y: bool = true ## Vertikales Folgen (Höhe / Springen)
@export var track_z: bool = true ## Tiefen-Folgen (Vor / Zurück entlang Tiefenachse)
@export var pan_influence: Vector3 = Vector3(0.70, 0.20, 0.15) ## Einflussstärke der Bewegung (0 = starr, 1 = 1:1)
@export var smooth_speed: float = 3.8 ## Weiche Dämpfungs-Geschwindigkeit (Lerp)

@export_group("📐 Rail Bounds (Box in 3D Viewport)")
@export var use_relative_bounds: bool = true ## Begrenzungen relativ zur im Editor platzierten Position
@export var max_pan_left: float = 3.5: ## Maximale Verschiebung nach links (Schiene)
	set(v):
		max_pan_left = v
		update_gizmos()
@export var max_pan_right: float = 4.0: ## Maximale Verschiebung nach rechts (Schiene)
	set(v):
		max_pan_right = v
		update_gizmos()
@export var max_pan_up: float = 1.5: ## Maximale Verschiebung nach oben
	set(v):
		max_pan_up = v
		update_gizmos()
@export var max_pan_down: float = 1.0: ## Maximale Verschiebung nach unten
	set(v):
		max_pan_down = v
		update_gizmos()
@export var max_pan_forward: float = 1.5 ## Maximale Verschiebung nach vorne
@export var max_pan_back: float = 1.5 ## Maximale Verschiebung nach hinten

@export_group("🔄 Dynamic Yaw Swivel")
@export var enable_yaw_swivel: bool = true ## Leichtes Mitschwenken der Kamera beim Verfolgen
@export var yaw_swivel_factor: float = 1.6 ## Schwenkwinkel in Grad pro Meter Verschiebung
@export var max_swivel_angle: float = 6.0 ## Maximaler Schwenkwinkel in Grad (relativ zur Start-Rotation)

@export_group("🔍 Field of View (FOV)")
@export var sync_with_global_fov: bool = true ## Wenn true, überschreibt CameraManager das FOV mit den Spiel-Settings. Wenn false, bleibt handjustiertes Designer-FOV erhalten.

var _target: Node3D = null
var _base_cam_pos: Vector3 = Vector3.ZERO
var _base_cam_rot_deg: Vector3 = Vector3.ZERO
var _base_cam_basis: Basis = Basis.IDENTITY
var _base_target_pos: Vector3 = Vector3.ZERO
var _is_initialized: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	_capture_base_transforms()
	_find_target()
	
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("register_diorama_camera"):
		cm.register_diorama_camera(self)
	else:
		_apply_mode_locally()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("unregister_diorama_camera"):
		cm.unregister_diorama_camera(self)

func _on_mode_changed() -> void:
	update_gizmos()
	if is_inside_tree() and not Engine.is_editor_hint():
		var cm = get_node_or_null("/root/CameraManager")
		if cm and cm.has_method("apply_camera_mode"):
			cm.apply_camera_mode(false)
		else:
			_apply_mode_locally()

func _apply_mode_locally() -> void:
	match camera_mode:
		Mode.DIORAMA_RAIL, Mode.FIXED_ROOM:
			current = true
		Mode.FREE_360_ORBIT:
			current = false
			if is_instance_valid(_target):
				var p_cam = _target.find_child("Camera3D", true, false) as Camera3D
				if p_cam:
					p_cam.current = true

func _apply_preset_settings(p: Preset) -> void:
	match p:
		Preset.HAFEN_STEG:
			camera_mode = Mode.DIORAMA_RAIL
			track_x = true
			track_y = true
			track_z = true
			pan_influence = Vector3(0.70, 0.20, 0.15)
			smooth_speed = 3.5
			use_relative_bounds = true
			max_pan_left = 3.5
			max_pan_right = 4.0
			max_pan_up = 1.5
			max_pan_down = 1.0
			enable_yaw_swivel = true
			yaw_swivel_factor = 1.6
			max_swivel_angle = 6.0
			sync_with_global_fov = true
		Preset.SCHIFFSKABINE:
			camera_mode = Mode.DIORAMA_RAIL
			track_x = true
			track_y = false
			track_z = false
			pan_influence = Vector3(0.32, 0.0, 0.0)
			smooth_speed = 5.0
			use_relative_bounds = true
			max_pan_left = 0.65
			max_pan_right = 0.65
			max_pan_up = 0.0
			max_pan_down = 0.0
			enable_yaw_swivel = false
			sync_with_global_fov = false
		Preset.OFFENE_WELT_360:
			camera_mode = Mode.FREE_360_ORBIT
			tracking_enabled = false
			enable_yaw_swivel = false
		Preset.FESTER_RAUM:
			camera_mode = Mode.FIXED_ROOM
			tracking_enabled = false
			enable_yaw_swivel = false
			sync_with_global_fov = false
		_:
			pass
	update_gizmos()
	notify_property_list_changed()

## Erfasst die im Godot-Editor platzierte Position als unveränderliche Referenzbasis
func _capture_base_transforms() -> void:
	_base_cam_pos = global_position
	_base_cam_rot_deg = rotation_degrees
	_base_cam_basis = global_transform.basis
	_is_initialized = true

func _find_target() -> void:
	if not target_node.is_empty():
		_target = get_node_or_null(target_node) as Node3D
	if not _target:
		_target = get_tree().root.find_child("Player", true, false) as Node3D
	if _target:
		_base_target_pos = _target.global_position

func _get_rail_lateral_dir() -> Vector3:
	var dir := Vector3(_base_cam_basis.x.x, 0.0, _base_cam_basis.x.z)
	if dir.length_squared() > 0.0001:
		return dir.normalized()
	return Vector3.RIGHT

func _get_rail_depth_dir() -> Vector3:
	var dir := Vector3(-_base_cam_basis.z.x, 0.0, -_base_cam_basis.z.z)
	if dir.length_squared() > 0.0001:
		return dir.normalized()
	return Vector3.FORWARD

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Im 360-Grad oder starren Modus führt die Schiene keine Bewegung aus
	if camera_mode != Mode.DIORAMA_RAIL:
		return
		
	if not current:
		return
		
	if not tracking_enabled:
		return
		
	if not is_instance_valid(_target):
		_find_target()
		if not is_instance_valid(_target):
			return
			
	_update_tracking(delta)

func _update_tracking(delta: float) -> void:
	var target_pos := _calculate_target_position()
	global_position = global_position.lerp(target_pos, delta * smooth_speed)
	
	if enable_yaw_swivel:
		var target_yaw := _calculate_target_yaw()
		var cur_rad := deg_to_rad(rotation_degrees.y)
		var tgt_rad := deg_to_rad(target_yaw)
		rotation_degrees.y = rad_to_deg(lerp_angle(cur_rad, tgt_rad, delta * smooth_speed))

func _calculate_pan_offsets() -> Vector3:
	var offset: Vector3 = _target.global_position - _base_target_pos
	var lateral_dir := _get_rail_lateral_dir()
	var depth_dir := _get_rail_depth_dir()
	
	var pan_x: float = 0.0
	var pan_y: float = 0.0
	var pan_z: float = 0.0
	
	if track_x:
		var lat_dist := offset.dot(lateral_dir)
		pan_x = lat_dist * pan_influence.x
		if use_relative_bounds:
			pan_x = clampf(pan_x, -max_pan_left, max_pan_right)
			
	if track_y:
		pan_y = offset.y * pan_influence.y
		if use_relative_bounds:
			pan_y = clampf(pan_y, -max_pan_down, max_pan_up)
			
	if track_z:
		var dep_dist := offset.dot(depth_dir)
		pan_z = dep_dist * pan_influence.z
		if use_relative_bounds:
			pan_z = clampf(pan_z, -max_pan_forward, max_pan_back)
			
	return Vector3(pan_x, pan_y, pan_z)

func _calculate_target_position() -> Vector3:
	var pans := _calculate_pan_offsets()
	var lateral_dir := _get_rail_lateral_dir()
	var depth_dir := _get_rail_depth_dir()
	return _base_cam_pos + (lateral_dir * pans.x) + (Vector3.UP * pans.y) + (depth_dir * pans.z)

func _calculate_target_yaw() -> float:
	var pan_x := _calculate_pan_offsets().x
	var target_yaw := _base_cam_rot_deg.y - (pan_x * yaw_swivel_factor)
	return clampf(target_yaw, _base_cam_rot_deg.y - max_swivel_angle, _base_cam_rot_deg.y + max_swivel_angle)

## Setzt die Kamera ohne weiche Gleitfahrt sofort auf die Zielposition
func snap_to_target() -> void:
	if not is_instance_valid(_target):
		_find_target()
	if not is_instance_valid(_target) or not _is_initialized:
		return
		
	if camera_mode != Mode.DIORAMA_RAIL:
		return
		
	global_position = _calculate_target_position()
	if enable_yaw_swivel:
		rotation_degrees.y = _calculate_target_yaw()
