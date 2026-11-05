class_name PlayerAnimator
extends Node

## PlayerAnimator
## Modular animation controller for Barnaby.
## Handles AnimationPlayer playback, procedural AnimationTree state machine with xfade,
## bone-filtered upper body flashlight holding blend, and state-to-animation mapping.

var player: CharacterBody3D
var anim_player: AnimationPlayer
var anim_tree: AnimationTree
var _tree_playback: AnimationNodeStateMachinePlayback
var _arm_blend_tween: Tween

var current_anim: String = ""

@export_group("Animation Names")
@export var anim_idle: String = "Idle"
@export var anim_walk: String = "Walk"
@export var anim_run: String = "Run"
@export var anim_jump: String = "Jump"
@export var anim_fall: String = "Fall"
@export var anim_gliding: String = "Gliding"
@export var anim_grind: String = "Grind"
@export var anim_celebration: String = "dance"
@export var anim_dash: String = "Dash"
@export var anim_spin: String = "Spin"
@export var anim_dive: String = "Dive"
@export var anim_backflip: String = "Backflip"
@export var anim_brake: String = "Brake"
@export var anim_crouch: String = "Crouch"
@export var anim_crawl: String = "Crawl"

func setup(p_player: CharacterBody3D, p_anim_player: AnimationPlayer) -> void:
	player = p_player
	anim_player = p_anim_player

	if not anim_player and player:
		anim_player = player.find_child("AnimationPlayer", true, false) as AnimationPlayer

	_setup_animation_loops()
	_setup_animation_tree()

	# Start in idle animation
	var idle_name := get_idle_anim()
	play_anim(idle_name, 0.0)

# ==============================================================================
# ANIMATION LIBRARY & LOOPS
# ==============================================================================

func _setup_animation_loops() -> void:
	if not anim_player:
		return

	var looping_anims := [
		anim_idle, "Idle", "idle",
		anim_walk, "Walk", "walk", "walking",
		anim_run, "Run", "run", "running",
		anim_fall, "Fall", "floating",
		"Swim", "SwimIdle", "swimming_overwater", "swimming_underwater",
		anim_crouch, "Crouch",
		anim_crawl, "Crawl", "CrawlIdle",
		"ClimbIdle", "LedgeHangingIdle",
		anim_gliding, "Gliding", "gliding",
		anim_grind, "Grind", "grind"
	]
	for a_name in looping_anims:
		if a_name != "" and anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_LINEAR

	var non_looping_anims := [
		anim_jump, "Jump", "jump",
		anim_backflip, "Backflip", "backflip",
		anim_brake, "Brake", "brake",
		anim_dash, "Dash", "dash",
		anim_spin, "Spin", "spin",
		anim_dive, "AirDive", "Dive", "dive",
		"Throw", "Stomp", "Hurt", "Die"
	]
	for a_name in non_looping_anims:
		if a_name != "" and anim_player.has_animation(a_name):
			anim_player.get_animation(a_name).loop_mode = Animation.LOOP_NONE

# ==============================================================================
# FLASHLIGHT ARM HOLD POSE & ANIMATION TREE (WEG 2)
# ==============================================================================

func _create_flashlight_hold_animation() -> void:
	if not anim_player or anim_player.has_animation("flashlight_hold"):
		return

	var idle_name := get_idle_anim()
	var idle := anim_player.get_animation(idle_name)
	if not idle:
		return

	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR

	var right_bones := [
		"Armature/Skeleton3D:mixamorig_RightShoulder",
		"Armature/Skeleton3D:mixamorig_RightArm",
		"Armature/Skeleton3D:mixamorig_RightForeArm",
		"Armature/Skeleton3D:mixamorig_RightHand",
		"Armature/Skeleton3D:mixamorig_RightHandIndex1",
		"Armature/Skeleton3D:mixamorig_RightHandIndex2",
		"Armature/Skeleton3D:mixamorig_RightHandIndex3",
		"Armature/Skeleton3D:mixamorig_RightHandIndex4"
	]

	for i in range(idle.get_track_count()):
		var p := str(idle.track_get_path(i))
		if p in right_bones:
			var t_type := idle.track_get_type(i)
			var new_t := anim.add_track(t_type)
			anim.track_set_path(new_t, p)
			var val0 = idle.track_get_key_value(i, 0)

			if t_type == Animation.TYPE_ROTATION_3D:
				var q: Quaternion = val0
				if "mixamorig_RightArm" in p:
					q = q * Quaternion(Vector3.UP, deg_to_rad(15.0))
				elif "mixamorig_RightForeArm" in p:
					q = q * Quaternion(Vector3.FORWARD, deg_to_rad(35.0))
				elif "mixamorig_RightHandIndex1" in p:
					q = q * Quaternion(Vector3.FORWARD, deg_to_rad(40.0))
				elif "mixamorig_RightHandIndex2" in p:
					q = q * Quaternion(Vector3.FORWARD, deg_to_rad(50.0))
				elif "mixamorig_RightHandIndex3" in p:
					q = q * Quaternion(Vector3.FORWARD, deg_to_rad(20.0))
				anim.rotation_track_insert_key(new_t, 0.0, q)
				anim.rotation_track_insert_key(new_t, 1.0, q)
			elif t_type == Animation.TYPE_POSITION_3D:
				anim.position_track_insert_key(new_t, 0.0, val0)
				anim.position_track_insert_key(new_t, 1.0, val0)

	var lib := anim_player.get_animation_library("")
	if not lib:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
	lib.add_animation("flashlight_hold", anim)

func _setup_animation_tree() -> void:
	if not anim_player:
		return

	var parent_node := anim_player.get_parent()
	if not parent_node:
		return

	_create_flashlight_hold_animation()

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	parent_node.add_child(anim_tree)
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)

	var blend_tree := AnimationNodeBlendTree.new()

	# 1. State machine for base movement
	var sm := AnimationNodeStateMachine.new()
	var anim_list := anim_player.get_animation_list()
	for a in anim_list:
		if a == "RESET" or a == "shooting" or a == "flashlight_hold":
			continue
		var node := AnimationNodeAnimation.new()
		node.animation = a
		sm.add_node(a, node)

	# Connect all states with crossfade
	for a1 in anim_list:
		for a2 in anim_list:
			if a1 != a2 and sm.has_node(a1) and sm.has_node(a2):
				var trans := AnimationNodeStateMachineTransition.new()
				if a2 == "Jump" or a2.to_lower() == "jump":
					trans.xfade_time = 0.08
				elif a2 == "Dash" or a2 == "Spin" or a2 == "Backflip" or a2 == "Brake" or a2 == "AirDive":
					trans.xfade_time = 0.08
				else:
					trans.xfade_time = 0.2
				sm.add_transition(a1, a2, trans)

	blend_tree.add_node("base_locomotion", sm)

	# 2. TimeScale node
	var time_scale := AnimationNodeTimeScale.new()
	blend_tree.add_node("loco_time_scale", time_scale)
	blend_tree.connect_node("loco_time_scale", 0, "base_locomotion")

	# 3. Flashlight pose
	var flash_node := AnimationNodeAnimation.new()
	flash_node.animation = "flashlight_hold" if anim_player.has_animation("flashlight_hold") else get_idle_anim()
	blend_tree.add_node("flashlight_pose", flash_node)

	# 4. Blend2 with right arm bone filter
	var blend2 := AnimationNodeBlend2.new()
	blend2.filter_enabled = true
	var right_bones := [
		"Armature/Skeleton3D:mixamorig_RightShoulder",
		"Armature/Skeleton3D:mixamorig_RightArm",
		"Armature/Skeleton3D:mixamorig_RightForeArm",
		"Armature/Skeleton3D:mixamorig_RightHand",
		"Armature/Skeleton3D:mixamorig_RightHandIndex1",
		"Armature/Skeleton3D:mixamorig_RightHandIndex2",
		"Armature/Skeleton3D:mixamorig_RightHandIndex3",
		"Armature/Skeleton3D:mixamorig_RightHandIndex4"
	]
	for bone in right_bones:
		blend2.set_filter_path(bone, true)

	blend_tree.add_node("blend_flashlight", blend2)
	blend_tree.connect_node("blend_flashlight", 0, "loco_time_scale")
	blend_tree.connect_node("blend_flashlight", 1, "flashlight_pose")
	blend_tree.connect_node("output", 0, "blend_flashlight")

	anim_tree.tree_root = blend_tree
	anim_tree.active = true

	_tree_playback = anim_tree.get("parameters/base_locomotion/playback")
	var start_anim := get_idle_anim()
	if _tree_playback and sm.has_node(start_anim):
		_tree_playback.start(start_anim)
	anim_tree.set("parameters/blend_flashlight/blend_amount", 0.0)
	anim_tree.set("parameters/loco_time_scale/scale", 1.0)

# ==============================================================================
# PLAYBACK & CONTROL
# ==============================================================================

func play_anim(anim_name: String, blend_time: float = 0.2) -> void:
	if not anim_player or not anim_player.has_animation(anim_name):
		return
	if current_anim == anim_name:
		return
	current_anim = anim_name
	if _tree_playback:
		_tree_playback.travel(anim_name)
	else:
		anim_player.play(anim_name, blend_time)

func set_anim_speed(speed: float) -> void:
	if anim_tree and anim_tree.active:
		anim_tree.set("parameters/loco_time_scale/scale", speed)
	if anim_player:
		anim_player.speed_scale = speed

func get_current_anim() -> String:
	return current_anim

# ==============================================================================
# ANIMATION NAME RESOLVERS
# ==============================================================================

func get_walk_anim() -> String:
	if anim_player and anim_player.has_animation(anim_walk):
		return anim_walk
	for a in ["Walk", "walking", "walk"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return anim_walk

func get_run_anim() -> String:
	if anim_player and anim_player.has_animation(anim_run):
		return anim_run
	for a in ["Run", "running", "run"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return anim_run

func get_idle_anim() -> String:
	if anim_player and anim_player.has_animation(anim_idle):
		return anim_idle
	for a in ["Idle", "idle"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return anim_idle

func get_jump_anim() -> String:
	if anim_player and anim_player.has_animation(anim_jump):
		return anim_jump
	for a in ["Jump", "jump"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return anim_jump

func get_fall_anim() -> String:
	if anim_player and anim_player.has_animation(anim_fall):
		return anim_fall
	for a in ["Fall", "floating"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_jump_anim()

func get_gliding_anim() -> String:
	if anim_player and anim_player.has_animation(anim_gliding):
		return anim_gliding
	for a in ["Gliding", "gliding"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_fall_anim()

func get_grind_anim() -> String:
	if anim_player and anim_player.has_animation(anim_grind):
		return anim_grind
	for a in ["Grind", "grind", "Skate", "skate"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_fall_anim()

func get_celebration_anim() -> String:
	if anim_player and anim_player.has_animation(anim_celebration):
		return anim_celebration
	for a in ["dance", "Spin", "Backflip"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_idle_anim()

func get_dash_anim() -> String:
	if anim_player and anim_player.has_animation(anim_dash):
		return anim_dash
	for a in ["Dash", "dash", "Run", "run"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_run_anim()

func get_spin_anim() -> String:
	if anim_player and anim_player.has_animation(anim_spin):
		return anim_spin
	for a in ["Spin", "spin", "dance"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_jump_anim()

func get_dive_anim() -> String:
	if anim_player and anim_player.has_animation(anim_dive):
		return anim_dive
	return get_spin_anim()

func get_backflip_anim() -> String:
	if anim_player and anim_player.has_animation(anim_backflip):
		return anim_backflip
	for a in ["Backflip", "backflip"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_jump_anim()

func get_brake_anim() -> String:
	if anim_player and anim_player.has_animation(anim_brake):
		return anim_brake
	for a in ["Brake", "brake"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_idle_anim()

func get_crouch_anim() -> String:
	if anim_player and anim_player.has_animation(anim_crouch):
		return anim_crouch
	for a in ["Crouch", "crouch"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_idle_anim()

func get_crawl_anim() -> String:
	if anim_player and anim_player.has_animation(anim_crawl):
		return anim_crawl
	for a in ["Crawl", "crawl"]:
		if anim_player and anim_player.has_animation(a):
			return a
	return get_crouch_anim()

# ==============================================================================
# STATE-TO-ANIMATION MAPPING
# ==============================================================================

## Matches Player State enum (0: IDLE, 1: WALK, 2: BRAKE, 3: JUMP, 4: FALL, 5: CROUCH,
## 6: CRAWL, 7: DASH, 8: SPIN, 9: BACKFLIP, 10: LONG_JUMP, 11: AIR_DIVE, 12: DIVE_SLIDE,
## 13: GLIDE, 14: RAIL_GRIND) to corresponding animation and scaled playback speed.
func update_animation(
	current_state: int,
	horiz_spd: float,
	sprint_input: bool,
	walk_speed: float,
	run_speed: float,
	crawling_speed: float,
	rail_grind_speed: float,
	rail_grind_min_speed: float
) -> void:
	if not anim_player:
		return

	var walk_anim := get_walk_anim()
	var run_anim := get_run_anim()
	var idle_anim := get_idle_anim()
	var jump_anim := get_jump_anim()
	var fall_anim := get_fall_anim()
	var dash_anim := get_dash_anim()
	var spin_anim := get_spin_anim()
	var backflip_anim := get_backflip_anim()
	var brake_anim := get_brake_anim()
	var crouch_anim := get_crouch_anim()
	var crawl_anim := get_crawl_anim()

	match current_state:
		7: # DASH
			play_anim(dash_anim, 0.06)
			set_anim_speed(1.45)

		8: # SPIN
			play_anim(spin_anim, 0.05)
			set_anim_speed(1.65)

		10: # LONG_JUMP
			play_anim(jump_anim, 0.06)
			set_anim_speed(1.25)

		9: # BACKFLIP
			play_anim(backflip_anim, 0.08)
			set_anim_speed(1.2)

		2: # BRAKE
			if anim_player.has_animation(brake_anim):
				play_anim(brake_anim, 0.08)
				set_anim_speed(1.2)

		6: # CRAWL
			play_anim(crawl_anim, 0.15)
			set_anim_speed(clampf((horiz_spd / maxf(crawling_speed, 0.1)) * 1.2, 0.8, 1.5))

		5: # CROUCH
			play_anim(crouch_anim, 0.15)
			set_anim_speed(1.0)

		3: # JUMP
			if anim_player.has_animation(jump_anim):
				play_anim(jump_anim, 0.08)
				set_anim_speed(1.25)

		4: # FALL
			if anim_player.has_animation(fall_anim):
				play_anim(fall_anim, 0.18)
				set_anim_speed(1.1)
			elif anim_player.has_animation(jump_anim):
				play_anim(jump_anim, 0.12)
				set_anim_speed(1.25)

		13: # GLIDE
			play_anim(get_gliding_anim(), 0.1)
			set_anim_speed(1.0)

		14: # RAIL_GRIND
			play_anim(get_grind_anim(), 0.08)
			set_anim_speed(clampf(rail_grind_speed / maxf(rail_grind_min_speed, 1.0), 0.9, 1.8))

		0: # IDLE
			play_anim(idle_anim, 0.2)
			set_anim_speed(1.0)

		1: # WALK
			if sprint_input and horiz_spd > walk_speed * 0.75:
				play_anim(run_anim, 0.12)
				var run_ratio := clampf(horiz_spd / maxf(run_speed, 1.0), 0.7, 1.35)
				set_anim_speed(run_ratio * 1.55) # Snappy cartoon sprint
			else:
				play_anim(walk_anim, 0.14)
				var walk_ratio := clampf(horiz_spd / maxf(walk_speed, 1.0), 0.65, 1.35)
				set_anim_speed(walk_ratio * 1.35) # Bouncy walk

# ==============================================================================
# FLASHLIGHT ARM BLEND SUPPRESSION & TWEENING
# ==============================================================================

func update_arm_blend(delta: float, current_state: int, flashlight_enabled: bool) -> void:
	if not anim_tree or not anim_tree.active:
		return

	# Suppress upper-body blend during acrobatic states
	var suppress: bool = current_state in [7, 8, 10, 9, 2, 6, 5, 13, 14]
	var target_blend: float = 0.0 if (suppress or not flashlight_enabled) else 1.0
	var cur_blend: float = anim_tree.get("parameters/blend_flashlight/blend_amount")
	if not is_equal_approx(cur_blend, target_blend):
		anim_tree.set("parameters/blend_flashlight/blend_amount", move_toward(cur_blend, target_blend, 12.0 * delta))

func tween_arm_blend(target_blend: float, duration: float = 0.2, callback: Callable = Callable()) -> void:
	if not anim_tree or not anim_tree.active:
		return
	if _arm_blend_tween and _arm_blend_tween.is_valid():
		_arm_blend_tween.kill()

	var cur_blend: float = anim_tree.get("parameters/blend_flashlight/blend_amount")
	_arm_blend_tween = create_tween()
	_arm_blend_tween.tween_property(anim_tree, "parameters/blend_flashlight/blend_amount", target_blend, duration).from(cur_blend)
	if callback.is_valid():
		_arm_blend_tween.tween_callback(callback)
