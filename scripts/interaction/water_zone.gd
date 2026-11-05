@tool
class_name WaterZone
extends Node3D

## WaterZone
## Platzierbares Weltobjekt zur Definition lokaler Wasser- und Giftzonen (Seen, Teiche, Becken).
## Folgt dem Wurzel-Inspector-Prinzip: Größe, Oberflächenhöhe, Giftigkeit und Respawn-Regeln
## werden direkt auf dem Wurzelknoten im Inspector konfiguriert.
## Meldet sich beim Betreten der Szene dynamisch beim Wasser-Modul (PlayerWaterHazard) an
## und beim Verlassen der Szene wieder ab.

enum RespawnMode {
	LAST_SAFE_GROUND = 0, ## Rückkehr zum zuletzt betretenen sicheren Festland
	FIXED_SPAWN_POINT = 1 ## Rückkehr zu einem fest zugewiesenen Spawn-Punkt (Marker3D / Node3D)
}

@export_group("Water Zone")
@export var enabled: bool = true
@export var zone_name: String = "water_zone":
	set(val):
		zone_name = val
		update_configuration_warnings()

@export var size: Vector2 = Vector2(10.0, 10.0):
	set(val):
		size = val
		_update_debug_visual()
		update_configuration_warnings()

@export var water_height_offset: float = 0.0:
	set(val):
		water_height_offset = val
		_update_debug_visual()

@export var is_toxic: bool = false:
	set(val):
		is_toxic = val
		_update_debug_visual()

@export var submersion_depth: float = 0.30 ## Wie tief die Figur eintaucht, bevor der Wipeout auslöst

@export_group("Respawn Behavior")
@export var respawn_mode: RespawnMode = RespawnMode.LAST_SAFE_GROUND:
	set(val):
		respawn_mode = val
		update_configuration_warnings()

@export var fixed_respawn_point: Node3D = null:
	set(val):
		fixed_respawn_point = val
		update_configuration_warnings()

@export var fixed_respawn_position: Vector3 = Vector3.ZERO

@export_group("Editor Visualization")
@export var show_debug_mesh: bool = true:
	set(val):
		show_debug_mesh = val
		_update_debug_visual()

var _debug_mesh: MeshInstance3D
var _hazard_ref: Node = null

func _enter_tree() -> void:
	add_to_group("water_zones")
	_register_with_player()

func _exit_tree() -> void:
	_unregister_from_player()
	remove_from_group("water_zones")

func _ready() -> void:
	_update_debug_visual()
	_register_with_player()

func get_surface_y() -> float:
	return global_position.y + water_height_offset

func get_center() -> Vector3:
	return global_position

func contains_point(pos: Vector3) -> bool:
	if not enabled or size.x <= 0.0 or size.y <= 0.0:
		return false
	var c := global_position
	return absf(pos.x - c.x) <= size.x * 0.5 and absf(pos.z - c.z) <= size.y * 0.5

func is_submerged(pos: Vector3) -> bool:
	return contains_point(pos) and pos.y <= get_surface_y() - submersion_depth

func get_respawn_position() -> Vector3:
	if respawn_mode == RespawnMode.FIXED_SPAWN_POINT:
		if is_instance_valid(fixed_respawn_point):
			return fixed_respawn_point.global_position
		return fixed_respawn_position
	return Vector3.ZERO

func _register_with_player() -> void:
	if Engine.is_editor_hint():
		return
	var hazard := _find_water_hazard()
	if hazard and hazard.has_method("register_water_zone_object"):
		_hazard_ref = hazard
		hazard.register_water_zone_object(self)

func _unregister_from_player() -> void:
	if Engine.is_editor_hint():
		return
	if is_instance_valid(_hazard_ref) and _hazard_ref.has_method("unregister_water_zone_object"):
		_hazard_ref.unregister_water_zone_object(self)
	_hazard_ref = null

func _find_water_hazard() -> Node:
	var tree := get_tree()
	if tree and tree.root:
		var p: Node = tree.root.find_child("Player", true, false)
		if p and "water_hazard" in p and p.water_hazard:
			return p.water_hazard
	var curr: Node = get_parent()
	while curr:
		var p: Node = curr.find_child("Player", true, false)
		if p and "water_hazard" in p and p.water_hazard:
			return p.water_hazard
		curr = curr.get_parent()
	return null

func _update_debug_visual() -> void:
	if not Engine.is_editor_hint() and not show_debug_mesh:
		if is_instance_valid(_debug_mesh):
			_debug_mesh.queue_free()
		return

	if not is_instance_valid(_debug_mesh):
		_debug_mesh = get_node_or_null("DebugWaterMesh") as MeshInstance3D
		if not _debug_mesh:
			_debug_mesh = MeshInstance3D.new()
			_debug_mesh.name = "DebugWaterMesh"
			_debug_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_debug_mesh)

	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(maxf(size.x, 0.1), 0.1, maxf(size.y, 0.1))
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.85, 0.35, 0.35) if is_toxic else Color(0.1, 0.45, 0.95, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mesh.material = mat
	
	_debug_mesh.mesh = p_mesh
	_debug_mesh.position = Vector3(0.0, water_height_offset, 0.0)
	_debug_mesh.visible = show_debug_mesh

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if size.x <= 0.0 or size.y <= 0.0:
		warnings.append("WaterZone muss eine positive Größe (Breite X und Tiefe Z) größer als 0 haben.")
	if zone_name.strip_edges().is_empty():
		warnings.append("WaterZone sollte einen aussagekräftigen zone_name haben.")
	if respawn_mode == RespawnMode.FIXED_SPAWN_POINT and not is_instance_valid(fixed_respawn_point) and fixed_respawn_position == Vector3.ZERO:
		warnings.append("Im Modus FIXED_SPAWN_POINT muss ein fester Respawn-Punkt oder eine Koordinate angegeben werden.")
	return warnings
