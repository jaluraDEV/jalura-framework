@tool
extends Node3D

## ShipCabin - Interior Diorama Controller
## Handles diorama camera tracking, room boundaries, atmospheric materials, and cozy lighting.

@onready var player: Player = $Player
@onready var diorama_cam: Camera3D = $DioramaCamera

const CALM_GLASS_COLOR: Color = Color(0.25, 0.55, 0.85)
const CALM_GLASS_ENERGY: float = 0.45

var _porthole_material: StandardMaterial3D

const CAM_BASE_Y: float = 2.15
const CAM_BASE_Z: float = 4.35
const CAM_TRACK_FACTOR_X: float = 0.32
const CAM_LERP_SPEED: float = 5.0

func _ready() -> void:
	# Apply glowing porthole glass and warm quilt materials
	_setup_materials()
	
	if Engine.is_editor_hint():
		return
		
	if diorama_cam:
		diorama_cam.current = true
	if player:
		# Disable proximity fade in diorama cabin (no clipping danger from front diorama view)
		if player.has_method("set_camera_fade_enabled"):
			player.set_camera_fade_enabled(false)
		else:
			player.camera_fade_enabled = false
		# Lock player camera pivot to forward view in diorama room
		var pivot = player.find_child("CameraPivot", true, false) as Node3D
		if pivot:
			pivot.rotation = Vector3.ZERO

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if not is_instance_valid(player) or not is_instance_valid(diorama_cam):
		return
		
	# Smooth horizontal tracking following player (nur als Fallback, falls kein DioramaCamera3D)
	if not diorama_cam.has_method("snap_to_target"):
		var target_x: float = clampf(player.global_position.x * CAM_TRACK_FACTOR_X, -0.65, 0.65)
		diorama_cam.position.x = lerpf(diorama_cam.position.x, target_x, CAM_LERP_SPEED * delta)
	
	# Keep player camera pivot aligned with room orientation for consistent directional controls
	var pivot = player.find_child("CameraPivot", true, false) as Node3D
	if pivot:
		pivot.rotation.y = 0.0
		pivot.rotation.x = deg_to_rad(-18.0)

## Setzt die Kabinen-Dioramakamera sofort ohne Gleiten auf die Zielposition
func snap_camera() -> void:
	if diorama_cam and diorama_cam.has_method("snap_to_target"):
		diorama_cam.snap_to_target()
		return
	if not is_instance_valid(player) or not is_instance_valid(diorama_cam):
		return
	diorama_cam.position.x = clampf(player.global_position.x * CAM_TRACK_FACTOR_X, -0.65, 0.65)

func _setup_materials() -> void:
	# 1. Porthole glowing glass (instanced with calm blue marine ambient)
	var glow_mat_base = preload("res://assets/materials/porthole_glow_glass.tres")
	_porthole_material = glow_mat_base.duplicate() as StandardMaterial3D
	_porthole_material.emission = CALM_GLASS_COLOR
	_porthole_material.emission_energy_multiplier = CALM_GLASS_ENERGY
	
	var left_glass = find_child("Porthole_Back_Left_Glass", true, false) as MeshInstance3D
	if left_glass:
		left_glass.material_override = _porthole_material
	var right_glass = find_child("Porthole_Back_Right_Glass", true, false) as MeshInstance3D
	if right_glass:
		right_glass.material_override = _porthole_material
		
	# 2. Warm rose-coral quilt (creates distinct warm pink color bleeding on headboard and walls)
	var quilt_mat = preload("res://assets/materials/cabin_bed_quilt.tres")
	var duvet = find_child("Bed_Duvet_Blanket", true, false) as MeshInstance3D
	if duvet:
		duvet.material_override = quilt_mat
