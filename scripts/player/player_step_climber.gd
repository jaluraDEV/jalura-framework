class_name PlayerStepClimber
extends Node

## PlayerStepClimber
## Modular component for smooth stair climbing, curb step-up, and vertical camera/visual absorption.
## Completely eliminates stair chattering ("Zappel-Philipp") by maintaining continuous floor contact
## and absorbing discrete vertical snaps on both the character mesh and camera pivot.
##
## Features guaranteed clearance probe to ensure capsule bottom lands solidly on step tread
## even at slow walk speeds, without getting caught on beveled step nosings or curb lips.

@export var enabled: bool = true
@export var max_step_height: float = 0.42       ## Maximum obstacle/step height Barnaby can step over (meters)
@export var min_step_height: float = 0.02       ## Minimum height difference to count as a step
@export var min_step_probe_dist: float = 0.18   ## Minimum forward clearance probe distance (meters) ensuring capsule lands solidly on step tread even at slow walk speeds
@export var step_smooth_speed: float = 22.0     ## Damping speed for visual and camera height absorption
@export var min_walkable_normal_y: float = 0.40  ## Minimum normal.y to count as walkable surface (~66 deg)
@export var floor_max_angle_deg: float = 58.0    ## Floor max slope angle Barnaby can walk up without slipping (degrees)
@export var floor_snap_length: float = 0.55      ## Floor snap length to keep capsule glued to stair treads and ramps

var player: CharacterBody3D
var visual: Node3D
var camera_pivot: Node3D
var camera_rig: Node = null

var visual_offset: float = 0.0
var _orig_camera_pivot_y: float = 1.45

var _step_up_col: KinematicCollision3D = KinematicCollision3D.new()
var _step_down_col: KinematicCollision3D = KinematicCollision3D.new()

func setup(p_player: CharacterBody3D, p_visual: Node3D, p_camera_pivot: Node3D, p_camera_rig: Node = null) -> void:
	player = p_player
	visual = p_visual
	camera_pivot = p_camera_pivot
	camera_rig = p_camera_rig
	if camera_pivot:
		_orig_camera_pivot_y = camera_pivot.position.y
	if player:
		# Set floor_max_angle to smoothly handle step chamfers and dock curbs
		player.floor_max_angle = deg_to_rad(floor_max_angle_deg)

func process_step_movement(delta: float) -> void:
	if not player:
		return
		
	if not enabled:
		player.move_and_slide()
		return

	var orig_pos := player.global_position
	var orig_vel := player.velocity
	var was_grounded := player.is_on_floor()

	# Normal move attempt with floor snap
	player.floor_snap_length = floor_snap_length
	player.move_and_slide()
	if ("_bounce_timer" in player and player._bounce_timer > 0.0) or player.velocity.y > 1.0:
		player.floor_snap_length = 0.0
		decay_offset(delta)
		return
	var normal_end_pos := player.global_position

	var horiz_motion := Vector3(orig_vel.x, 0.0, orig_vel.z) * delta
	var intended_dist := horiz_motion.length()
	var actual_dist := Vector3(normal_end_pos.x - orig_pos.x, 0.0, normal_end_pos.z - orig_pos.z).length()

	var stepped := false

	# Test step-up if grounded and horizontal progress was obstructed by an obstacle
	if was_grounded and intended_dist > 0.005 and actual_dist < intended_dist * 0.85:
		# 1. Test headroom from original position
		var has_up := player.test_move(Transform3D(player.global_basis, orig_pos), Vector3(0.0, max_step_height, 0.0), _step_up_col)
		var actual_up: float = _step_up_col.get_travel().y if has_up else max_step_height

		if actual_up > min_step_height:
			var elevated_pos := orig_pos + Vector3(0.0, actual_up, 0.0)
			var elevated_xform := Transform3D(player.global_basis, elevated_pos)

			# 2. Test forward clearance at elevated height using at least min_step_probe_dist
			var probe_dist := maxf(intended_dist, min_step_probe_dist)
			var probe_motion := horiz_motion.normalized() * probe_dist
			var has_fwd := player.test_move(elevated_xform, probe_motion, _step_up_col)
			var fwd_travel: Vector3 = _step_up_col.get_travel() if has_fwd else probe_motion
			var elevated_dist := Vector3(fwd_travel.x, 0.0, fwd_travel.z).length()

			if elevated_dist > actual_dist + 0.005:
				# 3. Test downward from elevated forward position to find step tread surface
				var forward_xform := Transform3D(player.global_basis, elevated_pos + fwd_travel)
				var has_down := player.test_move(forward_xform, Vector3(0.0, -(actual_up + 0.20), 0.0), _step_down_col)

				if has_down:
					var norm := _step_down_col.get_normal()
					if norm.y >= min_walkable_normal_y:
						# Accept step-up!
						player.global_position = elevated_pos + fwd_travel + _step_down_col.get_travel()
						player.velocity = orig_vel
						player.velocity.y = 0.0
						player.apply_floor_snap()

						var step_diff := player.global_position.y - normal_end_pos.y
						visual_offset -= step_diff
						stepped = true

	# Downward step smoothing (when walking down stairs or descending small curbs)
	if not stepped and was_grounded and player.is_on_floor():
		var dy := player.global_position.y - orig_pos.y
		if dy < -min_step_height and dy >= -max_step_height:
			visual_offset -= dy

	# Smoothly decay visual offset towards zero
	visual_offset = lerp(visual_offset, 0.0, 1.0 - exp(-step_smooth_speed * delta))
	if absf(visual_offset) < 0.001:
		visual_offset = 0.0

	# Apply visual offset to character mesh
	if visual:
		visual.position.y = visual_offset

	# Report to camera rig (or fallback to camera pivot if rig not attached)
	if camera_rig and camera_rig.has_method("set_vertical_step_offset"):
		camera_rig.set_vertical_step_offset(visual_offset)
	elif camera_pivot:
		camera_pivot.position.y = _orig_camera_pivot_y + visual_offset

## Smoothly decays visual offset in the air (called when character is airborne)
func decay_offset(delta: float) -> void:
	visual_offset = lerp(visual_offset, 0.0, 1.0 - exp(-step_smooth_speed * delta))
	if absf(visual_offset) < 0.001:
		visual_offset = 0.0

	if visual:
		visual.position.y = visual_offset

	if camera_rig and camera_rig.has_method("set_vertical_step_offset"):
		camera_rig.set_vertical_step_offset(visual_offset)
	elif camera_pivot:
		camera_pivot.position.y = _orig_camera_pivot_y + visual_offset
