@tool
class_name DoorTrigger3D
extends Interactable

## DoorTrigger3D
## Flexibler Szenenwechsel-Trigger für Türen, Luken und Abfang-Zonen.
## Kann entweder als Laufzone (WALK_THROUGH - fängt den Spieler beim Reintreten ab)
## oder als Interaktionstaste (INTERACT_KEY - Taste [E]) oder beides (BOTH) genutzt werden.
## Im 3D-Editor wird eine transparente, anpassbare Box gerendert, damit man die Fangzone visuell exakt platzieren kann!

enum TriggerMode {
	WALK_THROUGH = 0, ## Spieler wird automatisch beim Betreten der Box abgefangen
	INTERACT_KEY = 1, ## Spieler drückt [E] zum Betreten
	BOTH = 2          ## Funktioniert sowohl mit Taste als auch beim Hineinlaufen
}

@export_group("Trigger Mode & Behavior")
@export var trigger_mode: TriggerMode = TriggerMode.WALK_THROUGH:
	set(v):
		trigger_mode = v
		_update_collision_layer()

@export var is_exit_door: bool = false
@export var target_scene_id: StringName = &""
@export var target_scene_path: String = ""
@export var target_spawn_id: StringName = &""
@export var spawn_point_id: String = "SpawnPoint"
@export var return_spawn_position: Vector3 = Vector3.ZERO
@export var return_spawn_yaw: float = 0.0

@export_group("Trigger Zone (Editor Box)")
## Größe der Abfang-Box (Breite X, Höhe Y, Tiefe Z) im 3D-Raum
@export var zone_size: Vector3 = Vector3(2.0, 2.5, 2.0):
	set(v):
		zone_size = Vector3(maxf(0.2, v.x), maxf(0.2, v.y), maxf(0.2, v.z))
		_update_zone_shape()

## Feinjustierung der Box-Position relativ zur Tür-Node
@export var zone_offset: Vector3 = Vector3.ZERO:
	set(v):
		zone_offset = v
		_update_zone_shape()

## Wähle eine fertige Box-Größe aus
@export_enum("--- Select Preset ---", "Standard Door (1.6m x 2.2m x 1.6m)", "Large Trigger Zone (2.5m x 2.5m x 2.5m)", "Breite Gang-Zone (4.0m x 2.5m x 2.0m)", "Schmale Luke (1.0m x 1.8m x 1.0m)") var apply_size_preset: String = "--- Select Preset ---":
	set(v):
		if v != "--- Select Preset ---":
			match v:
				"Standard Door (1.6m x 2.2m x 1.6m)":
					zone_size = Vector3(1.6, 2.2, 1.6)
				"Large Trigger Zone (2.5m x 2.5m x 2.5m)":
					zone_size = Vector3(2.5, 2.5, 2.5)
				"Breite Gang-Zone (4.0m x 2.5m x 2.0m)":
					zone_size = Vector3(4.0, 2.5, 2.0)
				"Schmale Luke (1.0m x 1.8m x 1.0m)":
					zone_size = Vector3(1.0, 1.8, 1.0)
			apply_size_preset = "--- Select Preset ---"
			notify_property_list_changed()

## Zeigt im 3D-Editor ein transparentes Farb-Volumen an, damit man die Zone genau sieht!
@export var show_editor_preview: bool = true:
	set(v):
		show_editor_preview = v
		_update_editor_preview()

## Farbe der visuellen Abfang-Box im Editor
@export var preview_color: Color = Color(0.18, 0.75, 1.0, 0.32):
	set(v):
		preview_color = v
		_update_editor_preview()

var _cooldown: bool = false
var _creation_time: float = 0.0
var _preview_mesh: MeshInstance3D = null

func _init() -> void:
	super._init()
	collision_mask = 2 # Player (Layer 2)

func _ready() -> void:
	super._ready()
	_creation_time = Time.get_ticks_msec() / 1000.0
	_update_collision_layer()
	_update_zone_shape()
	
	if Engine.is_editor_hint():
		_update_editor_preview()
	else:
		if _preview_mesh:
			_preview_mesh.visible = false
			
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _update_collision_layer() -> void:
	if trigger_mode == TriggerMode.INTERACT_KEY or trigger_mode == TriggerMode.BOTH:
		collision_layer = 9 # Layer 1 + Layer 8 (Interactable)
		if not is_in_group("interactables"):
			add_to_group("interactables")
	else:
		collision_layer = 1
		if is_in_group("interactables"):
			remove_from_group("interactables")

## Passt die CollisionShape3D an die eingestellte zone_size an
func _update_zone_shape() -> void:
	var col_shape := find_child("CollisionShape3D", true, false) as CollisionShape3D
	if not col_shape:
		col_shape = CollisionShape3D.new()
		col_shape.name = "CollisionShape3D"
		add_child(col_shape)
		
	if not col_shape.shape or not (col_shape.shape is BoxShape3D):
		col_shape.shape = BoxShape3D.new()
	elif not col_shape.shape.resource_path.is_empty():
		col_shape.shape = col_shape.shape.duplicate()
		
	var box := col_shape.shape as BoxShape3D
	box.size = zone_size
	col_shape.position = Vector3(0.0, zone_size.y * 0.5, 0.0) + zone_offset
	
	_update_editor_preview()

## Rendert eine visuelle Box im 3D-Editor
func _update_editor_preview() -> void:
	if not Engine.is_editor_hint():
		if _preview_mesh:
			_preview_mesh.visible = false
		return
		
	if not show_editor_preview:
		if _preview_mesh:
			_preview_mesh.visible = false
		return
		
	if not _preview_mesh:
		_preview_mesh = find_child("EditorPreviewBox", true, false) as MeshInstance3D
	if not _preview_mesh:
		_preview_mesh = MeshInstance3D.new()
		_preview_mesh.name = "EditorPreviewBox"
		_preview_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_preview_mesh)
		
	_preview_mesh.visible = true
	var box_mesh := _preview_mesh.mesh as BoxMesh
	if not box_mesh:
		box_mesh = BoxMesh.new()
		_preview_mesh.mesh = box_mesh
		
	box_mesh.size = zone_size
	_preview_mesh.position = Vector3(0.0, zone_size.y * 0.5, 0.0) + zone_offset
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = preview_color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_mesh.material_override = mat

func can_interact(_player: Node) -> bool:
	if not enabled or _cooldown:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - _creation_time < 0.8:
		return false
	return (trigger_mode == TriggerMode.INTERACT_KEY or trigger_mode == TriggerMode.BOTH)

## Entschärft die Türzone sofort, wenn der Spieler beim Szenenstart bereits darin steht
func disarm_if_overlapping(player_node: Node) -> void:
	if not player_node or not is_inside_tree():
		return
	if player_node is Node3D and overlaps_body(player_node as Node3D):
		_cooldown = true
		if not body_exited.is_connected(_on_disarm_body_exited):
			body_exited.connect(_on_disarm_body_exited)

func _on_disarm_body_exited(body: Node3D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		if body_exited.is_connected(_on_disarm_body_exited):
			body_exited.disconnect(_on_disarm_body_exited)
		# 0.4 Sekunden Puffer nach Verlassen der Türzone
		get_tree().create_timer(0.4).timeout.connect(func(): _cooldown = false)

func interact(player: Node) -> void:
	if can_interact(player):
		_trigger_transition()

func _on_body_entered(body: Node3D) -> void:
	if not enabled or _cooldown:
		return
		
	var now := Time.get_ticks_msec() / 1000.0
	if now - _creation_time < 0.8:
		return
		
	if trigger_mode == TriggerMode.INTERACT_KEY:
		return
		
	if body.is_in_group("player") or body.name == "Player":
		_trigger_transition()

func _trigger_transition() -> void:
	var st = get_node_or_null("/root/SceneTransition")
	var rm = get_node_or_null("/root/RoomManager")
	
	if st and st.get("is_transitioning") == true:
		return
	if rm and rm.is_transitioning:
		return
		
	_cooldown = true
	get_tree().create_timer(1.2).timeout.connect(func(): _cooldown = false)
	
	# Spieler-Momentum sofort stoppen (verhindert Hinauslaufen ins Leere während Fade-Out)
	var cur_scene := get_tree().current_scene if get_tree() else null
	if cur_scene:
		var p := cur_scene.find_child("Player", true, false) as CharacterBody3D
		if p:
			p.velocity = Vector3.ZERO
	
	# Bevorzuge modernes SceneTransition-System
	if st and st.world_map:
		var target_sid: StringName = target_scene_id
		var target_sp: StringName = target_spawn_id
		
		if not is_exit_door:
			# Wir betreten einen Innenraum / Schiffskabine: Ausgangsort sichern
			var curr_path := cur_scene.scene_file_path if cur_scene else ""
			var curr_sid: StringName = &""
			if not curr_path.is_empty():
				curr_sid = st.world_map.find_scene_id_by_path(curr_path)
			if curr_sid.is_empty():
				curr_sid = st.current_scene_id
				
			st.set("last_exterior_scene_id", curr_sid)
			st.set("last_exterior_scene_path", curr_path)
			
			if rm:
				rm.overworld_scene_path = curr_path
				rm.overworld_return_position = return_spawn_position if return_spawn_position != Vector3.ZERO else global_position
				rm.overworld_return_yaw = return_spawn_yaw
				
			if target_sid.is_empty() and not target_scene_path.is_empty():
				target_sid = st.world_map.find_scene_id_by_path(target_scene_path)
			if target_sid.is_empty():
				target_sid = st.current_scene_id
			if target_sp.is_empty():
				target_sp = &""
		else:
			# is_exit_door == true: Zurück zur Overworld oder Herkunftsszene
			var last_sid: StringName = st.get("last_exterior_scene_id") if "last_exterior_scene_id" in st else &""
			if last_sid.is_empty() and rm and not rm.overworld_scene_path.is_empty():
				last_sid = st.world_map.find_scene_id_by_path(rm.overworld_scene_path)
			
			if target_sid.is_empty():
				if not last_sid.is_empty():
					target_sid = last_sid
				elif not target_scene_path.is_empty():
					target_sid = st.world_map.find_scene_id_by_path(target_scene_path)
				
			if target_sid.is_empty():
				target_sid = &"overworld"
				
			if target_sp.is_empty():
				target_sp = &"von_bootskabine"
			
		st.go_to(target_sid, target_sp)
		return
		
	# Fallback auf Legacy RoomManager
	if rm:
		if is_exit_door:
			if return_spawn_position != Vector3.ZERO and rm.overworld_return_position == Vector3.ZERO:
				rm.overworld_return_position = return_spawn_position
				rm.overworld_return_yaw = return_spawn_yaw
			if not target_scene_path.is_empty() and rm.overworld_scene_path.is_empty():
				rm.overworld_scene_path = target_scene_path
			rm.exit_room()
		else:
			var ret_pos := return_spawn_position
			if ret_pos == Vector3.ZERO:
				ret_pos = global_position
			rm.enter_room(target_scene_path, spawn_point_id, ret_pos, return_spawn_yaw)
