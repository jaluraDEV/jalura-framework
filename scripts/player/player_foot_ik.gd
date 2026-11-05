class_name PlayerFootIK
extends Node

## PlayerFootIK
## Modular procedural Inverse Kinematics component for natural foot planting
## on stairs, slopes, and uneven terrain.
## Tracks animated foot coordinates and adapts vertical placement to step treads.

@export var enabled: bool = true
@export var foot_offset: float = 0.05          ## Ankle joint height above surface (m)
@export var foot_offset_barefoot: float = 0.05  ## Calibrated ankle height for barefoot stance (m)
@export var foot_offset_shoes: float = 0.195    ## Calibrated ankle height with rail shoes equipped (m)
@export var ray_origin_height: float = 0.65    ## Raycast launch height above player origin (m)
@export var ray_length: float = 1.30           ## Total raycast reach downward (m)
@export var max_pelvis_drop: float = 0.20      ## Maximum hip lowering to allow legs to plant on lower treads (m)
@export var ik_blend_speed: float = 12.0       ## Interpolation speed for enabling/disabling IK influence
@export var ik_pos_smooth_speed: float = 24.0  ## Smoothing speed for foot target position tracking
@export_flags_3d_physics var raycast_collision_mask: int = 1 | 4  ## Physics layers tested for foot placement (1=World, 4=Props)

var player: CharacterBody3D
var skel: Skeleton3D

var _target_l: Marker3D
var _target_r: Marker3D
var _ik_l: SkeletonIK3D
var _ik_r: SkeletonIK3D

var _l_up_idx: int = -1
var _l_foot_idx: int = -1
var _r_up_idx: int = -1
var _r_foot_idx: int = -1

var _current_influence: float = 0.0
var _current_target_l_pos: Vector3 = Vector3.ZERO
var _current_target_r_pos: Vector3 = Vector3.ZERO
var _current_pelvis_drop: float = 0.0
var _orig_skel_y: float = 0.0

func setup(p_player: CharacterBody3D, p_skel: Skeleton3D) -> void:
	player = p_player
	skel = p_skel
	if not player or not skel:
		return
		
	_orig_skel_y = skel.position.y
	_l_up_idx = skel.find_bone("mixamorig_LeftUpLeg")
	_l_foot_idx = skel.find_bone("mixamorig_LeftFoot")
	_r_up_idx = skel.find_bone("mixamorig_RightUpLeg")
	_r_foot_idx = skel.find_bone("mixamorig_RightFoot")
	
	if _l_up_idx < 0 or _l_foot_idx < 0 or _r_up_idx < 0 or _r_foot_idx < 0:
		push_warning("PlayerFootIK: Leg bones not found in skeleton.")
		return

	# Setup Left Leg IK
	_target_l = Marker3D.new()
	_target_l.name = "FootIKTarget_L"
	skel.add_child(_target_l)
	
	_ik_l = SkeletonIK3D.new()
	_ik_l.name = "SkeletonIK_L"
	_ik_l.root_bone = "mixamorig_LeftUpLeg"
	_ik_l.tip_bone = "mixamorig_LeftFoot"
	_ik_l.target_node = _target_l.get_path()
	_ik_l.use_magnet = false # Preserves animation's natural forward knee bend
	_ik_l.override_tip_basis = false # Preserves natural shoe orientation
	skel.add_child(_ik_l)
	_ik_l.start()
	
	# Setup Right Leg IK
	_target_r = Marker3D.new()
	_target_r.name = "FootIKTarget_R"
	skel.add_child(_target_r)
	
	_ik_r = SkeletonIK3D.new()
	_ik_r.name = "SkeletonIK_R"
	_ik_r.root_bone = "mixamorig_RightUpLeg"
	_ik_r.tip_bone = "mixamorig_RightFoot"
	_ik_r.target_node = _target_r.get_path()
	_ik_r.use_magnet = false
	_ik_r.override_tip_basis = false
	skel.add_child(_ik_r)
	_ik_r.start()
	
	# Initialize target positions
	_current_target_l_pos = player.global_position
	_current_target_r_pos = player.global_position
	_target_l.global_position = _current_target_l_pos
	_target_r.global_position = _current_target_r_pos

	# Initialize foot offset according to equipped equipment state
	if player.has_method("has_rail_shoes"):
		set_shoes_equipped(player.has_rail_shoes())
	elif player.get("rail_grind_unlocked") == true:
		set_shoes_equipped(true)
	else:
		set_shoes_equipped(false)

## Adapts foot planting offset dynamically when Rail Shoes are equipped vs barefoot.
func set_shoes_equipped(equipped: bool) -> void:
	foot_offset = foot_offset_shoes if equipped else foot_offset_barefoot

func update(delta: float, is_air_state: bool, is_sprinting: bool, is_moving: bool) -> void:
	if not enabled or not _ik_l or not _ik_r or not player or not is_inside_tree():
		return
		
	# Determine target IK influence based on player locomotion state
	var target_influence := 0.0
	if not is_air_state and player.is_on_floor():
		if not is_moving:
			target_influence = 1.0 # Full stance foot planting when stationary on stairs/slopes
		elif is_sprinting:
			target_influence = 0.35 # Subtle foot grounding during fast sprint
		else:
			target_influence = 0.70 # Natural walk grounding
			
	_current_influence = lerp(_current_influence, target_influence, 1.0 - exp(-ik_blend_speed * delta))
	_ik_l.influence = _current_influence
	_ik_r.influence = _current_influence
	
	if _current_influence < 0.02:
		if skel and absf(_current_pelvis_drop) > 0.001:
			_current_pelvis_drop = lerp(_current_pelvis_drop, 0.0, 1.0 - exp(-ik_pos_smooth_speed * delta))
			skel.position.y = _orig_skel_y + _current_pelvis_drop
		return
		
	var space := player.get_world_3d().direct_space_state
	var center := player.global_position
	
	# Query current animated foot world positions
	var l_anim_world := skel.global_transform * skel.get_bone_global_pose(_l_foot_idx).origin
	var r_anim_world := skel.global_transform * skel.get_bone_global_pose(_r_foot_idx).origin
	
	# Launch vertical rays directly from above the animated feet
	var ray_top := center.y + ray_origin_height
	var ray_bottom := center.y - (ray_length - ray_origin_height)
	var l_ray_start := Vector3(l_anim_world.x, ray_top, l_anim_world.z)
	var r_ray_start := Vector3(r_anim_world.x, ray_top, r_anim_world.z)
	
	var mask := raycast_collision_mask # World geometry & props
	var l_query := PhysicsRayQueryParameters3D.create(l_ray_start, Vector3(l_anim_world.x, ray_bottom, l_anim_world.z), mask)
	l_query.exclude = [player.get_rid()]
	var r_query := PhysicsRayQueryParameters3D.create(r_ray_start, Vector3(r_anim_world.x, ray_bottom, r_anim_world.z), mask)
	r_query.exclude = [player.get_rid()]
	
	var l_hit := space.intersect_ray(l_query)
	var r_hit := space.intersect_ray(r_query)
	
	# Pelvis / Hips lowering: allow character to sit slightly lower when stepping on lower treads
	var target_pelvis_drop: float = 0.0
	var l_diff: float = (float(l_hit.position.y) - center.y) if not l_hit.is_empty() else 0.0
	var r_diff: float = (float(r_hit.position.y) - center.y) if not r_hit.is_empty() else 0.0
	var min_diff: float = minf(l_diff, r_diff)
	if min_diff < -0.01:
		target_pelvis_drop = clampf(min_diff, -max_pelvis_drop, 0.0)
		
	_current_pelvis_drop = lerp(_current_pelvis_drop, target_pelvis_drop * _current_influence, 1.0 - exp(-ik_pos_smooth_speed * delta))
	if skel:
		skel.position.y = _orig_skel_y + _current_pelvis_drop
	
	# Targets stay at animated foot X and Z, adapting ONLY Y to ground surface
	var l_goal_pos := l_anim_world
	if not l_hit.is_empty():
		l_goal_pos.y = float(l_hit.position.y) + foot_offset
		
	var r_goal_pos := r_anim_world
	if not r_hit.is_empty():
		r_goal_pos.y = float(r_hit.position.y) + foot_offset
		
	# Smoothly interpolate target positions
	var pos_w := 1.0 - exp(-ik_pos_smooth_speed * delta)
	_current_target_l_pos = lerp(_current_target_l_pos, l_goal_pos, pos_w)
	_current_target_r_pos = lerp(_current_target_r_pos, r_goal_pos, pos_w)
	
	_target_l.global_position = _current_target_l_pos
	_target_r.global_position = _current_target_r_pos
