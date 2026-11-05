extends CharacterBody3D
class_name Player


enum State {
	IDLE,
	WALK,
	BRAKE,
	JUMP,
	FALL,
	CROUCH,
	CRAWL,
	DASH,
	SPIN,
	BACKFLIP,
	LONG_JUMP,
	AIR_DIVE,
	DIVE_SLIDE,
	GLIDE,
	RAIL_GRIND
}

@export_group("Motion & Feel (Platformer Project Style)")
@export var walk_speed: float = 5.0             ## Base top speed for walk/jog
@export var run_speed: float = 7.5              ## Sprint top speed
@export var acceleration: float = 38.0          ## Ground acceleration rate (Snappy responsive grip!)
@export var deceleration: float = 42.0          ## Ground deceleration rate (Crisp stop!)
@export var friction: float = 38.0              ## Ground friction when letting go of stick
@export var air_acceleration: float = 22.0      ## In-air directional acceleration (Controlled air physics)
@export var turning_drag: float = 28.0          ## Turning resistance when walking
@export var running_turning_drag: float = 14.0  ## Turning resistance when sprinting - smooth drift!
@export var rotation_speed: float = 28.0        ## Angular turn speed in rad/s (Immediate body facing)

@export_group("Jump & Gravity")
@export var jump_velocity: float = 8.5          ## Full jump vertical launch (Unity: 17.0)
@export var min_jump_velocity: float = 4.8      ## Short hop cut-off speed (Unity: 10.0)
@export var gravity: float = 22.0               ## Ascent gravity (Unity: 38.0)
@export var fall_gravity: float = 38.0          ## Asymmetric fall gravity - punchy drop! (Unity: 65.0)
@export var terminal_velocity: float = 28.0     ## Max fall speed (Unity: 50.0)
const COYOTE_TIME: float = 0.15                 ## Coyote jump window (Unity: 0.15s)
const JUMP_BUFFER: float = 0.15                 ## Jump input buffer (Unity: 0.15s)

@export_group("Dash (Ground & Air Dash)")
@export var dash_enabled: bool = true
@export var dash_force: float = 14.5            ## Sprint rocket impulse (Unity: 25.0)
@export var dash_duration: float = 0.30         ## Burst length in seconds (Unity: 0.3s)
@export var dash_cooldown: float = 0.35         ## Ground dash cooldown in seconds (Unity: 0.5s)
@export var allowed_air_dashes: int = 1         ## Max mid-air dashes before touching floor

@export_group("Spin Attack")
@export var spin_enabled: bool = true
@export var spin_duration: float = 0.42         ## Pirouette spin duration (Unity: 0.5s)
@export var air_spin_lift: float = 5.8          ## Mid-air upward vertical boost (Unity: 10.0)
@export var allowed_air_spins: int = 1          ## Max mid-air spins before touching floor

@export_group("Long Jump")
@export var long_jump_enabled: bool = true
@export var long_jump_velocity: float = 5.8     ## Flatter jump arc for forward leap
@export var long_jump_forward_boost: float = 11.5 ## Forward leap launch speed
@export var long_jump_gravity: float = 19.0     ## Long jump gravity

@export_group("Backflip & Brake (C# Backflip & Brake States)")
@export var backflip_enabled: bool = true
@export var backflip_jump_velocity: float = 11.0 ## High vertical leap (Unity: 23.0)
@export var backflip_gravity: float = 18.0       ## Acrobatic floaty hang time (Unity: 35.0)
@export var backflip_turn_force: float = 7.5     ## Explosive backward launch from Skid Turnaround (Unity: 8.0)
@export var backflip_crouch_force: float = 4.0   ## Controlled backward launch from stationary Crouch (Unity: 4.0)
@export var brake_threshold: float = -0.75       ## Turnaround dot product to trigger Brake state (Unity: -0.8)
@export var crawling_speed: float = 2.4          ## Crawl speed when crouching (Unity: 2.5)
@export var crouch_friction: float = 12.0        ## Friction when crouching (Unity: 10.0)

@export_group("Glider")
@export var item_glider: ItemData = preload("res://resources/items/glider.tres")
@export var glider_enabled: bool = true              ## Enable / disable glider mechanics
@export var glider_unlocked: bool = false            ## If true, player can glide without collecting item first (for testing)
@export var glider_gravity: float = 7.5              ## Descent gravity while gliding (m/s^2)
@export var glider_max_fall_speed: float = 2.2       ## Maximum terminal fall speed while gliding (m/s)
@export var glider_speed: float = 6.8                ## Horizontal cruise speed while gliding (m/s)
@export var glider_acceleration: float = 16.0        ## In-air steering acceleration rate
@export var glider_turning_speed: float = 8.5        ## Steering turn rate in rad/s
@export var glider_lean_angle: float = 22.0          ## Maximum banking lean tilt in degrees
@export var glider_offset: Vector3 = Vector3(0.0, 1.88, -0.36) ## Glider model position relative to Visual
@export var glider_scale: Vector3 = Vector3(1.15, 1.15, 1.15)  ## Glider model scale

@export_group("Rail Grind / Shoes")
@export var item_rail_shoe: ItemData = preload("res://resources/items/rail_shoe.tres")
@export var rail_grind_enabled: bool = true          ## Enable / disable rail grinding
@export var rail_grind_unlocked: bool = false:        ## If true, shoes equipped and rail grind enabled without item (for testing)
	set(v):
		rail_grind_unlocked = v
		if equipment and equipment.has_method("apply_shoe_state"):
			equipment.apply_shoe_state()
@export var rail_snap_distance: float = 1.35         ## Maximum distance to snap onto rail
@export var rail_grind_min_speed: float = 10.5       ## Minimum cruise grinding speed
@export var rail_grind_max_speed: float = 21.0       ## Maximum grinding speed
@export var rail_grind_downhill_accel: float = 15.0  ## Downhill slope acceleration
@export var rail_grind_uphill_decel: float = 9.5     ## Uphill slope deceleration
@export var rail_grind_brake_force: float = 16.0     ## Grind braking rate when holding crouch/back
@export var rail_grind_dash_boost: float = 8.5       ## Instant speed impulse when pressing dash on rail
@export var rail_grind_height_offset: float = 0.26   ## Vertical offset above rail pipe (calibrated for flush shoe contact)
@export var rail_shoe_scale: Vector3 = Vector3(0.11, 0.11, 0.11)
@export var rail_shoe_left_offset: Vector3 = Vector3(0.0, 0.085, 0.022)
@export var rail_shoe_left_rotation: Vector3 = Vector3(0.0, 90.0, 126.0)
@export var rail_shoe_right_offset: Vector3 = Vector3(0.0238, 0.0859, 0.0054)
@export var rail_shoe_right_rotation: Vector3 = Vector3(0.0, 160.0, 126.0)
@export var rail_shoe_offset: Vector3 = Vector3(0.0, 0.085, 0.022)
@export var rail_shoe_rotation: Vector3 = Vector3(0.0, 90.0, 126.0)

@export_group("Camera")
@export var mouse_sensitivity: float = 0.0025
@export var min_pitch: float = -60.0 # Degrees looking up
@export var max_pitch: float = 30.0  # Degrees looking down

@export_group("Flashlight")
@export var item_flashlight: ItemData = preload("res://resources/items/flashlight.tres")
@export var flashlight_enabled: bool = false
@export var flashlight_energy: float = 4.2
@export var flashlight_range: float = 24.0
@export var flashlight_angle: float = 32.0
@export var flashlight_color: Color = Color(1.0, 0.98, 0.92)

@export_group("Camera Proximity Fade")
@export var camera_fade_enabled: bool = true
@export var fade_start_distance: float = 1.30 ## Distance from camera where model begins to dissolve/fade
@export var fade_end_distance: float = 0.45   ## Distance where model is completely invisible
@export_enum("Dither", "Smooth Alpha") var fade_style: int = 0

@export_group("Juice & Game Feel")
@export var lean_enabled: bool = true
@export var max_lean_deg: float = 14.0          ## Dynamic tilt banking into turns (Unity: 15.0 deg)
@export var squash_stretch_enabled: bool = true
@export var audio_sfx_enabled: bool = true       ## Movement, jump and impact sound effects
@export var particles_enabled: bool = true       ## Cartoon dust puffs on jump, land, skid and dash
@export var camera_fov_kick_enabled: bool = true ## Dynamic camera FOV boost on sprint and dash

@export_group("Stairs & Step-Up (Obstacle Step-Over)")
@export var step_up_enabled: bool = true        ## Allows Barnaby to smoothly walk over curbs, stones and stairs
@export var max_step_height: float = 0.42      ## Maximum obstacle / stair height Barnaby can step over (m)
@export var step_smooth_speed: float = 22.0    ## Smoothing speed for visual step offset (eliminates vertical pops)
@export var min_step_probe_dist: float = 0.18  ## Minimum forward probe distance (m) to clear step corners at slow walk speed

@onready var visual: Node3D = $Visual
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var anim_player: AnimationPlayer = $Visual/barnaby/AnimationPlayer

var current_state: State = State.IDLE
var current_anim: String = ""

# Jump & Air state
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var _bounce_timer: float = 0.0

# Action state timers & tracking
var _air_dash_counter: int = 0
var _last_dash_time: float = -10.0
var _dash_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _dash_buffer_timer: float = 0.0

var _air_spin_counter: int = 0
var _spin_timer: float = 0.0
var _spin_buffer_timer: float = 0.0

var _long_jump_direction: Vector3 = Vector3.ZERO
var _brake_timer: float = 0.0
var _backflip_lock_timer: float = 0.0
var _last_ground_speed: float = 0.0

# Step-Up & Stair Obstacle State (Modular PlayerStepClimber)
const PlayerStepClimberClass = preload("res://scripts/player/player_step_climber.gd")
var step_climber: Node

# Foot IK State (Modular PlayerFootIK)
const PlayerFootIKClass = preload("res://scripts/player/player_foot_ik.gd")
var foot_ik: Node

# Water Hazard & Fall Safety Component (Modular PlayerWaterHazard)
const PlayerWaterHazardClass = preload("res://scripts/player/player_water_hazard.gd")
var water_hazard: Node

# Unified Camera Rig (Modular PlayerCameraRig)
const PlayerCameraRigClass = preload("res://scripts/player/player_camera_rig.gd")
var camera_rig: Node

# Audio & SFX Component (Modular PlayerAudio)
const PlayerAudioClass = preload("res://scripts/player/player_audio.gd")
var audio: PlayerAudio

# VFX, Dust & Squash/Stretch Component (Modular PlayerEffects)
const PlayerEffectsClass = preload("res://scripts/player/player_effects.gd")
var effects: PlayerEffects

# Animation Component (Modular PlayerAnimator)
const PlayerAnimatorClass = preload("res://scripts/player/player_animator.gd")
var animator: Node

# Equipment Component (Modular PlayerEquipment)
const PlayerEquipmentClass = preload("res://scripts/player/player_equipment.gd")
var equipment: Node

# Interaction Component (Modular PlayerInteraction)
const PlayerInteractionClass = preload("res://scripts/player/player_interaction.gd")
var interaction: Node

# Procedural Game Feel state (Lean & Landing Impact)
var _current_lean: float = 0.0
var _last_fall_velocity: float = 0.0
var _was_on_floor: bool = true

# Backwards compatibility aliases for existing tests/scripts/inspectors
var is_jumping: bool:
	get: return current_state == State.JUMP or current_state == State.BACKFLIP or current_state == State.LONG_JUMP
	set(v):
		if not v and (current_state == State.JUMP or current_state == State.BACKFLIP or current_state == State.LONG_JUMP):
			current_state = State.IDLE if is_on_floor() else State.FALL
var is_dashing: bool:
	get: return current_state == State.DASH
	set(v):
		if v: current_state = State.DASH
		elif current_state == State.DASH: current_state = State.IDLE if is_on_floor() else State.FALL
var is_spinning: bool:
	get: return current_state == State.SPIN
	set(v):
		if v: current_state = State.SPIN
		elif current_state == State.SPIN: current_state = State.IDLE if is_on_floor() else State.FALL
var is_long_jumping: bool:
	get: return current_state == State.LONG_JUMP
	set(v):
		if v: current_state = State.LONG_JUMP
		elif current_state == State.LONG_JUMP: current_state = State.FALL
var is_diving: bool:
	get: return current_state == State.DASH
	set(v):
		if v: current_state = State.DASH
		elif current_state == State.DASH: current_state = State.FALL
var is_dive_sliding: bool:
	get: return false
	set(_v): pass
var is_backflipping: bool:
	get: return current_state == State.BACKFLIP
	set(v):
		if v: current_state = State.BACKFLIP
		elif current_state == State.BACKFLIP: current_state = State.FALL
var is_crouching: bool:
	get: return current_state == State.CROUCH or current_state == State.CRAWL
	set(v):
		if v: current_state = State.CROUCH
		elif current_state == State.CROUCH or current_state == State.CRAWL: current_state = State.IDLE

var air_dive_enabled: bool:
	get: return dash_enabled
	set(v): dash_enabled = v
var air_dive_force: float:
	get: return dash_force
	set(v): dash_force = v
var dive_enabled: bool:
	get: return dash_enabled
	set(v): dash_enabled = v
var dive_speed: float:
	get: return dash_force
	set(v): dash_force = v
var dive_hop_velocity: float = 7.6
var dive_upward_force: float = 0.0
var dive_slide_duration: float = 0.5
var dive_slide_timer: float = 0.0
var backflip_velocity: float:
	get: return backflip_jump_velocity
	set(v): backflip_jump_velocity = v
var backflip_backward_speed: float:
	get: return backflip_turn_force
	set(v): backflip_turn_force = v
var skid_backflip_window: float = 0.35

var is_gliding: bool:
	get: return current_state == State.GLIDE
	set(v):
		if v:
			if current_state != State.GLIDE:
				_execute_glide()
		elif current_state == State.GLIDE:
			_exit_glide()

var is_rail_grinding: bool:
	get: return current_state == State.RAIL_GRIND
	set(v):
		if not v and current_state == State.RAIL_GRIND:
			_exit_rail_grind(State.IDLE if is_on_floor() else State.FALL)

# Glider references (attached to Visual at runtime)
var _glider_model: Node3D = null

# Rail Grind & Shoe references (attached to foot bones at runtime)
var current_rail: Path3D = null
var rail_grind_offset: float = 0.0
var rail_grind_speed: float = 0.0
var rail_grind_direction: float = 1.0
var _rail_jump_cooldown: float = 0.0
var left_foot_attachment: BoneAttachment3D = null
var right_foot_attachment: BoneAttachment3D = null
var left_shoe_model: Node3D = null
var right_shoe_model: Node3D = null

# Flashlight references (attached to right hand bone at runtime)
var hand_bone_attachment: BoneAttachment3D
var hand_lamp_model: Node3D
var hand_flashlight: SpotLight3D
var hand_lens_glow: MeshInstance3D

# Backwards compatibility aliases for existing tests/scripts
var head_bone_attachment: BoneAttachment3D = null
var head_lamp_model: Node3D:
	get: return hand_lamp_model
	set(v): hand_lamp_model = v
var head_flashlight: SpotLight3D:
	get: return hand_flashlight
	set(v): hand_flashlight = v
var head_lens_glow: MeshInstance3D:
	get: return hand_lens_glow
	set(v): hand_lens_glow = v

# Animation Tree & Upper Body Layering
var anim_tree: AnimationTree
var _tree_playback: AnimationNodeStateMachinePlayback
var _arm_blend_tween: Tween

# Proximity fade state
func _get_fade_alpha() -> float:
	if camera_rig and camera_rig.has_method("get_fade_alpha"):
		return camera_rig.get_fade_alpha()
	return 1.0

# Interaction & Quest Celebration State
var hud: Node
var current_interactable: Interactable
var is_celebrating: bool = false
const INTERACTION_RANGE: float = 2.8

# Bump Pushable State (Phase 6 Zusatz)
var _bump_target_pb: PushableBehavior = null
var _bump_timer: float = 0.0

func _ready() -> void:
	# Fallback search for AnimationPlayer if node path differs
	if not anim_player:
		anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
		
	# Connect to QuestManager celebration signals
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_celebration_started.connect(_on_quest_celebration_started)
		qm.quest_celebration_ended.connect(_on_quest_celebration_ended)
		
	# Connect to InventoryManager to update flashlight state if inventory changes
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("inventory_updated"):
		inv.inventory_updated.connect(_on_inventory_updated)
	
	# Register with CameraManager
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("register_player"):
		cm.register_player(self)
	
	# Capture mouse on start
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Setup modular animator component
	animator = PlayerAnimatorClass.new()
	animator.name = "PlayerAnimator"
	add_child(animator)
	animator.setup(self, anim_player)
	anim_tree = animator.anim_tree
	_tree_playback = animator._tree_playback
	
	# Setup modular equipment component (Flashlight, Glider, Rail Shoes)
	equipment = PlayerEquipmentClass.new()
	equipment.name = "PlayerEquipment"
	add_child(equipment)
	equipment.item_glider = item_glider
	equipment.item_rail_shoe = item_rail_shoe
	equipment.item_flashlight = item_flashlight
	equipment.flashlight_enabled = flashlight_enabled
	equipment.flashlight_energy = flashlight_energy
	equipment.flashlight_range = flashlight_range
	equipment.flashlight_angle = flashlight_angle
	equipment.flashlight_color = flashlight_color
	equipment.glider_offset = glider_offset
	equipment.glider_scale = glider_scale
	equipment.rail_shoe_scale = rail_shoe_scale
	equipment.rail_shoe_left_offset = rail_shoe_left_offset
	equipment.rail_shoe_left_rotation = rail_shoe_left_rotation
	equipment.rail_shoe_right_offset = rail_shoe_right_offset
	equipment.rail_shoe_right_rotation = rail_shoe_right_rotation
	equipment.rail_shoe_offset = rail_shoe_offset
	equipment.rail_shoe_rotation = rail_shoe_rotation
	equipment.setup(self, visual, animator)
	
	# Sync backwards-compatibility references
	hand_bone_attachment = equipment.hand_bone_attachment
	hand_lamp_model = equipment.hand_lamp_model
	hand_flashlight = equipment.hand_flashlight
	hand_lens_glow = equipment.hand_lens_glow
	_glider_model = equipment.glider_model
	left_foot_attachment = equipment.left_foot_attachment
	left_shoe_model = equipment.left_shoe_model
	right_foot_attachment = equipment.right_foot_attachment
	right_shoe_model = equipment.right_shoe_model
	
	# Setup modular interaction component
	interaction = PlayerInteractionClass.new()
	interaction.name = "PlayerInteraction"
	add_child(interaction)
	interaction.interaction_range = INTERACTION_RANGE
	interaction.setup(self)
	
	# Start in idle animation
	_play_anim(_get_idle_anim())
	
	# Setup modular camera rig (Single authoritative owner of camera_pivot transforms)
	camera_rig = PlayerCameraRigClass.new()
	camera_rig.name = "PlayerCameraRig"
	add_child(camera_rig)
	camera_rig.setup(self, camera_pivot, camera, spring_arm, visual)
	camera_rig.mouse_sensitivity = mouse_sensitivity
	camera_rig.min_pitch = min_pitch
	camera_rig.max_pitch = max_pitch
	camera_rig.camera_fade_enabled = camera_fade_enabled
	camera_rig.fade_start_distance = fade_start_distance
	camera_rig.fade_end_distance = fade_end_distance
	camera_rig.fade_style = fade_style
	camera_rig.camera_fov_kick_enabled = camera_fov_kick_enabled

	# Setup modular step climber for smooth stair and obstacle traversal
	step_climber = PlayerStepClimberClass.new()
	step_climber.name = "StepClimber"
	add_child(step_climber)
	step_climber.setup(self, visual, camera_pivot, camera_rig)
	step_climber.enabled = step_up_enabled
	step_climber.max_step_height = max_step_height
	step_climber.step_smooth_speed = step_smooth_speed
	step_climber.min_step_probe_dist = min_step_probe_dist

	# Setup modular foot IK for dynamic foot planting on stairs and slopes
	var ik_skel: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if ik_skel:
		foot_ik = PlayerFootIKClass.new()
		foot_ik.name = "FootIK"
		add_child(foot_ik)
		foot_ik.setup(self, ik_skel)

	# Setup modular water hazard for safe-ground respawns, camera surface clamping & wet shake
	water_hazard = PlayerWaterHazardClass.new()
	water_hazard.name = "WaterHazard"
	add_child(water_hazard)
	water_hazard.setup(self, visual, camera_pivot, camera, camera_rig)

	# Setup modular audio manager
	audio = PlayerAudioClass.new()
	audio.name = "PlayerAudio"
	add_child(audio)
	audio.enabled = audio_sfx_enabled
	audio.setup(self)

	# Setup modular VFX and juice feedback
	effects = PlayerEffectsClass.new()
	effects.name = "PlayerEffects"
	add_child(effects)
	effects.particles_enabled = particles_enabled
	effects.squash_stretch_enabled = squash_stretch_enabled
	effects.setup(self, visual)
	

func _exit_tree() -> void:
	var cm = get_node_or_null("/root/CameraManager")
	if cm and cm.has_method("unregister_player"):
		cm.unregister_player(self)

func _process(delta: float) -> void:
	
	if camera_rig:
		camera_rig.update_camera(delta, current_state, absf(velocity.length()))
	_update_interactions()

func _on_inventory_updated() -> void:
	if equipment:
		equipment.on_inventory_updated()
		flashlight_enabled = equipment.flashlight_enabled

func _set_anim_speed(speed: float) -> void:
	if animator:
		animator.set_anim_speed(speed)

func toggle_flashlight() -> void:
	if equipment:
		equipment.toggle_flashlight()
		flashlight_enabled = equipment.flashlight_enabled

func has_rail_shoes() -> bool:
	if equipment:
		return equipment.has_rail_shoes()
	return rail_grind_unlocked

func set_camera_fade_enabled(enabled: bool) -> void:
	camera_fade_enabled = enabled
	if camera_rig:
		camera_rig.set_camera_fade_enabled(enabled)

## Snaps the camera pivot immediately to target orientation (e.g. after scene transitions or respawns)
func snap_camera(yaw: float = 0.0, pitch_deg: float = -12.0) -> void:
	if camera_rig:
		camera_rig.snap_camera(yaw, pitch_deg)
	elif camera_pivot:
		camera_pivot.rotation.y = yaw
		camera_pivot.rotation.x = deg_to_rad(pitch_deg)
		camera_pivot.rotation.z = 0.0

func _unhandled_input(event: InputEvent) -> void:
	# Interaction with E key or PS5 Square (Button 2) / Cross (Button 0)
	if event.is_action_pressed("interact") \
		or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E) \
		or (event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_X or event.button_index == JOY_BUTTON_A)):
		if hud and hud.is_dialogue_active:
			return
		if interaction:
			if interaction.interact():
				get_viewport().set_input_as_handled()
				return
		elif current_interactable and not is_celebrating:
			current_interactable.interact(self)
			get_viewport().set_input_as_handled()
			return

	# Toggle flashlight with 'L' or 'F' or PS5 Triangle (Button 3) / D-Pad Left / D-Pad Up
	if event.is_action_pressed("toggle_flashlight") \
		or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_L or event.keycode == KEY_F)) \
		or (event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_Y or event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_UP)):
		toggle_flashlight()
		get_viewport().set_input_as_handled()
		return
	
	# Camera rotation with mouse (only when player camera is active)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if camera_rig:
			camera_rig.process_orbit_mouse(event)
		elif camera_pivot and (not camera or camera.current):
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
	
	# Toggle mouse lock with Escape key
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Re-capture mouse on left click if visible
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# 1. Early-out checks (Water hazard, Quest celebrations, Dialogue pause)
	if _process_water(delta):
		return

	# 2. Ground detection and landing transitions
	var on_floor := _process_ground_detection(delta)

	# 3. Action buffer decays (Jump, Dash, Spin)
	_process_jump_and_buffers(delta)

	# 4. Input reading and aerial/ground action triggers
	var input_data := _process_input_and_movement(delta, on_floor)

	# 5. State machine physics & motion update
	if _process_state(delta, on_floor, input_data):
		return

	# 6. Movement execution (Step climber vs air move_and_slide)
	_process_step_and_physics(delta)

	# 7. Procedural feedback, foot IK, bump pushables and animations
	_process_juice(delta, input_data["is_running"])

## Handles camera gamepad orbit and early-exit pauses (water hazard, celebrations, dialogue, scene transitions).
## Returns true if normal movement should be skipped for this frame.
func _process_water(delta: float) -> bool:
	# If scene transition or room transition is active, completely freeze movement
	var st = get_node_or_null("/root/SceneTransition")
	var rm = get_node_or_null("/root/RoomManager")
	if (st and st.get("is_transitioning") == true) or (rm and rm.get("is_transitioning") == true):
		velocity = Vector3.ZERO
		_play_anim(_get_idle_anim(), 0.15)
		return true

	# Gamepad right-stick camera orbit (only when player camera is active)
	if camera_rig:
		camera_rig.process_orbit_gamepad(delta)

	# Modular water hazard & void safety processing
	if water_hazard:
		water_hazard.process_hazard(delta)
		if water_hazard.is_recovering:
			move_and_slide()
			_play_anim(_get_idle_anim())
			return true
		
	# If celebrating quest completion, play dance and pause movement
	if is_celebrating and interaction:
		if interaction.handle_celebration_movement(delta, deceleration, gravity):
			return true
		
	# If dialogue is open, pause movement
	if hud and hud.is_dialogue_active:
		velocity.x = lerp(velocity.x, 0.0, 1.0 - exp(-deceleration * delta))
		velocity.z = lerp(velocity.z, 0.0, 1.0 - exp(-deceleration * delta))
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_play_anim(_get_idle_anim(), 0.2)
		return true

	return false

## Detects floor contact, resets coyote time and air action counters,
## and triggers landing squash feedback and state transitions.
func _process_ground_detection(delta: float) -> bool:
	var on_floor := is_on_floor() if current_state != State.RAIL_GRIND else false
	# Do not treat active upward launch or fresh bounce as grounded landing
	if on_floor and (_bounce_timer > 0.30 or ((current_state == State.JUMP or current_state == State.BACKFLIP or current_state == State.LONG_JUMP) and velocity.y > 0.5)):
		on_floor = false
	if on_floor:
		coyote_timer = COYOTE_TIME
		_air_dash_counter = 0
		_air_spin_counter = 0
		
		# Landing transitions from air states
		if current_state == State.JUMP or current_state == State.FALL or current_state == State.BACKFLIP or current_state == State.LONG_JUMP or current_state == State.GLIDE:
			if current_state == State.GLIDE:
				_exit_glide(State.WALK if (Vector2(velocity.x, velocity.z).length() > 0.2) else State.IDLE)
			if not _was_on_floor and _last_fall_velocity < -2.2:
				if effects:
					effects.apply_landing_impact(_last_fall_velocity)
				_play_landing_feedback(_last_fall_velocity)
			if current_state == State.BACKFLIP:
				velocity.x = 0.0
				velocity.z = 0.0
				current_state = State.IDLE
			elif current_state != State.GLIDE and current_state != State.RAIL_GRIND:
				current_state = State.WALK if (Vector2(velocity.x, velocity.z).length() > 0.2) else State.IDLE
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)
		_last_fall_velocity = velocity.y
		if current_state != State.JUMP and current_state != State.FALL and current_state != State.DASH and current_state != State.SPIN and current_state != State.BACKFLIP and current_state != State.LONG_JUMP and current_state != State.GLIDE and current_state != State.RAIL_GRIND:
			current_state = State.FALL
			
	_was_on_floor = on_floor
	return on_floor

## Updates input buffer timers for Jump, Dash, and Spin actions.
func _process_jump_and_buffers(delta: float) -> void:
	if _rail_jump_cooldown > 0.0:
		_rail_jump_cooldown = maxf(0.0, _rail_jump_cooldown - delta)
	
	# Jump buffer decay
	if _is_jump_just_pressed():
		jump_buffer_timer = JUMP_BUFFER
	else:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
		
	# Dash buffer decay
	if _is_dash_just_pressed():
		_dash_buffer_timer = 0.15
	else:
		_dash_buffer_timer = maxf(0.0, _dash_buffer_timer - delta)

	# Spin buffer decay
	if _is_spin_just_pressed():
		_spin_buffer_timer = 0.15
	else:
		_spin_buffer_timer = maxf(0.0, _spin_buffer_timer - delta)

## Reads directional input, sprint and crouch states, and checks for action triggers
## (in-air rail snap, air spin, glider start, ground dash, ground spin).
func _process_input_and_movement(delta: float, on_floor: bool) -> Dictionary:
	var input_vector := _get_input_vector()
	var input_magnitude := input_vector.length()
	var is_running := _is_sprint_pressed()
	var move_direction := _get_camera_relative_direction(input_vector)
	var crouch_held := _is_crouch_held()

	# Action triggers (Dash, Spin, Glider & Rail Snap)
	if not on_floor:
		# In-air Rail Snap (when falling, jumping, or gliding near a rail with shoes equipped)
		if rail_grind_enabled and has_rail_shoes() and _rail_jump_cooldown <= 0.0 and current_state != State.RAIL_GRIND and velocity.y <= 5.5:
			var rails := get_tree().get_nodes_in_group("rails")
			for r_node in rails:
				var p3d := r_node as Path3D
				if p3d and p3d.curve and p3d.curve.point_count >= 2:
					var probe_pos: Vector3 = global_position + Vector3(0.0, 0.25, 0.0)
					var local_p: Vector3 = p3d.to_local(probe_pos)
					var r_offset: float = p3d.curve.get_closest_offset(local_p)
					var r_pt: Vector3 = p3d.to_global(p3d.curve.sample_baked(r_offset))
					var dist: float = minf(global_position.distance_to(r_pt), probe_pos.distance_to(r_pt))
					var max_snap: float = p3d.get("snap_distance") if "snap_distance" in p3d else rail_snap_distance
					if dist <= max_snap:
						_execute_rail_grind(p3d, r_offset)
						break
						
		# In air: action triggers the Air Spin!
		var can_air_spin: bool = spin_enabled and (_air_spin_counter < allowed_air_spins)
		if (_spin_buffer_timer > 0.0 or _dash_buffer_timer > 0.0) and can_air_spin and current_state != State.SPIN:
			_spin_buffer_timer = 0.0
			_dash_buffer_timer = 0.0
			if current_state == State.GLIDE:
				_exit_glide(State.SPIN)
			_execute_spin()
		elif _can_start_gliding():
			var want_glide: bool = _check_action("glide") or _is_jump_just_pressed() or (_is_jump_held() and current_state == State.FALL)
			if want_glide and current_state != State.GLIDE:
				jump_buffer_timer = 0.0
				_execute_glide()
	else:
		# Ground Rail Snap (allows walking directly onto a low rail start/end with shoes equipped)
		if rail_grind_enabled and has_rail_shoes() and _rail_jump_cooldown <= 0.0 and current_state != State.RAIL_GRIND and input_magnitude > 0.1:
			var rails := get_tree().get_nodes_in_group("rails")
			for r_node in rails:
				var p3d := r_node as Path3D
				if p3d and p3d.curve and p3d.curve.point_count >= 2:
					var probe_pos: Vector3 = global_position + Vector3(0.0, 0.25, 0.0)
					var local_p: Vector3 = p3d.to_local(probe_pos)
					var r_offset: float = p3d.curve.get_closest_offset(local_p)
					var r_pt: Vector3 = p3d.to_global(p3d.curve.sample_baked(r_offset))
					var dist: float = minf(global_position.distance_to(r_pt), probe_pos.distance_to(r_pt))
					var max_snap: float = minf(p3d.get("snap_distance") if "snap_distance" in p3d else rail_snap_distance, 1.05)
					if dist <= max_snap:
						_execute_rail_grind(p3d, r_offset)
						break

		# On ground: Dash burst or Spin attack
		var can_ground_dash: bool = dash_enabled and ((Time.get_ticks_msec() / 1000.0) - _last_dash_time > dash_cooldown)
		if _dash_buffer_timer > 0.0 and can_ground_dash and current_state != State.DASH:
			_dash_buffer_timer = 0.0
			_execute_dash()
		elif _spin_buffer_timer > 0.0 and spin_enabled and current_state != State.SPIN:
			_spin_buffer_timer = 0.0
			_execute_spin()

	return {
		"input_vector": input_vector,
		"input_magnitude": input_magnitude,
		"is_running": is_running,
		"move_direction": move_direction,
		"crouch_held": crouch_held
	}

## Executes kinematics and transitions for all 15 states in the match-block.
## Returns true if an early return from _physics_process is required (e.g. jumping off a rail).
func _process_state(delta: float, on_floor: bool, input_data: Dictionary) -> bool:
	var input_magnitude: float = input_data["input_magnitude"]
	var is_running: bool = input_data["is_running"]
	var move_direction: Vector3 = input_data["move_direction"]
	var crouch_held: bool = input_data["crouch_held"]

	match current_state:
		State.DASH:
			_dash_timer = maxf(0.0, _dash_timer - delta)
			velocity.x = _dash_direction.x * dash_force
			velocity.z = _dash_direction.z * dash_force
			velocity.y = 0.0 # Cancels fall gravity during dash
			
			if visual:
				visual.global_rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
				visual.rotation.z = 0.0

			# Jump cancel out of dash!
			if on_floor and (jump_buffer_timer > 0.0 or _is_jump_just_pressed()):
				jump_buffer_timer = 0.0
				_execute_long_jump()
			elif _dash_timer <= 0.0:
				if on_floor:
					velocity.x = _dash_direction.x * run_speed
					velocity.z = _dash_direction.z * run_speed
					current_state = State.WALK if (input_magnitude > 0.1) else State.IDLE
				else:
					velocity.x = _dash_direction.x * run_speed
					velocity.z = _dash_direction.z * run_speed
					current_state = State.FALL

		State.SPIN:
			_spin_timer = maxf(0.0, _spin_timer - delta)
			
			if on_floor:
				var fric_w := 1.0 - exp(-friction * delta)
				velocity.x = lerp(velocity.x, 0.0, fric_w)
				velocity.z = lerp(velocity.z, 0.0, fric_w)
				velocity.y = -0.1
			else:
				velocity.y -= gravity * 0.75 * delta
				velocity.y = maxf(velocity.y, -terminal_velocity)
				if move_direction != Vector3.ZERO:
					velocity.x = lerp(velocity.x, move_direction.x * walk_speed, 1.0 - exp(-10.0 * delta))
					velocity.z = lerp(velocity.z, move_direction.z * walk_speed, 1.0 - exp(-10.0 * delta))
					
			if visual:
				visual.rotation.z = 0.0
				
			if _spin_timer <= 0.0:
				if on_floor:
					current_state = State.WALK if (input_magnitude > 0.1) else State.IDLE
				else:
					current_state = State.FALL

		State.LONG_JUMP:
			velocity.y -= long_jump_gravity * delta
			velocity.y = maxf(velocity.y, -terminal_velocity)
			
			if move_direction != Vector3.ZERO:
				velocity.x = lerp(velocity.x, move_direction.x * long_jump_forward_boost, 1.0 - exp(-6.0 * delta))
				velocity.z = lerp(velocity.z, move_direction.z * long_jump_forward_boost, 1.0 - exp(-6.0 * delta))
				if visual:
					var target_angle := atan2(-move_direction.x, -move_direction.z)
					visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_angle, rotation_speed * 0.5 * delta)
					
			if visual:
				visual.rotation.z = 0.0

		State.BACKFLIP:
			_backflip_lock_timer = maxf(0.0, _backflip_lock_timer - delta)
			velocity.y -= backflip_gravity * delta
			velocity.y = maxf(velocity.y, -terminal_velocity)
			
			if _backflip_lock_timer <= 0.0 and move_direction != Vector3.ZERO:
				velocity.x = lerp(velocity.x, move_direction.x * walk_speed, 1.0 - exp(-12.0 * delta))
				velocity.z = lerp(velocity.z, move_direction.z * walk_speed, 1.0 - exp(-12.0 * delta))
				
			if visual:
				visual.rotation.z = 0.0

		State.BRAKE:
			_brake_timer = maxf(0.0, _brake_timer - delta)
			var decel_w := 1.0 - exp(-deceleration * delta)
			velocity.x = lerp(velocity.x, 0.0, decel_w)
			velocity.z = lerp(velocity.z, 0.0, decel_w)
			velocity.y = -0.1
			_emit_skid_dust()
			
			# Skid Turnaround Backflip!
			if jump_buffer_timer > 0.0 or _is_jump_just_pressed():
				_stop_skid_dust()
				jump_buffer_timer = 0.0
				_execute_backflip(backflip_turn_force)
			elif Vector2(velocity.x, velocity.z).length() < 0.25 or _brake_timer <= 0.0:
				_stop_skid_dust()
				current_state = State.WALK if (input_magnitude > 0.1) else State.IDLE

		State.CROUCH, State.CRAWL:
			var cur_crouch_spd := Vector2(velocity.x, velocity.z).length()
			if not crouch_held:
				current_state = State.IDLE
			elif jump_buffer_timer > 0.0 or _is_jump_just_pressed():
				jump_buffer_timer = 0.0
				if cur_crouch_spd > 1.2 and input_magnitude > 0.3:
					_execute_long_jump()
				else:
					_execute_backflip(backflip_crouch_force)
			elif input_magnitude > 0.1 and move_direction != Vector3.ZERO:
				current_state = State.CRAWL
				var target_vel := move_direction * crawling_speed * clampf(input_magnitude, 0.0, 1.0)
				velocity.x = lerp(velocity.x, target_vel.x, 1.0 - exp(-acceleration * delta))
				velocity.z = lerp(velocity.z, target_vel.z, 1.0 - exp(-acceleration * delta))
				if visual:
					var target_angle := atan2(-move_direction.x, -move_direction.z)
					visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_angle, rotation_speed * delta)
			else:
				current_state = State.CROUCH
				velocity.x = lerp(velocity.x, 0.0, 1.0 - exp(-crouch_friction * delta))
				velocity.z = lerp(velocity.z, 0.0, 1.0 - exp(-crouch_friction * delta))
			velocity.y = -0.1

		State.JUMP, State.FALL:
			if velocity.y > 0.0:
				var cur_grav: float = gravity
				# Apex Hang-Time: near peak of jump, reduce gravity for floaty jump apex!
				if velocity.y < 2.4:
					cur_grav = gravity * 0.48
				velocity.y -= cur_grav * delta
				# Variable jump height (releasing jump early clamps upward speed)
				if _bounce_timer > 0.0:
					_bounce_timer = maxf(0.0, _bounce_timer - delta)
				elif not _is_jump_held() and velocity.y > min_jump_velocity:
					velocity.y = min_jump_velocity
			else:
				current_state = State.FALL
				var cur_fall_grav: float = fall_gravity
				if velocity.y > -2.2:
					cur_fall_grav = fall_gravity * 0.65 # Smooth crest over apex
				velocity.y -= cur_fall_grav * delta
				velocity.y = maxf(velocity.y, -terminal_velocity)
				
			# In-air steering
			var target_spd := (run_speed if is_running else walk_speed) * clampf(input_magnitude, 0.0, 1.0)
			var target_vel := move_direction * target_spd
			velocity.x = lerp(velocity.x, target_vel.x, 1.0 - exp(-air_acceleration * delta))
			velocity.z = lerp(velocity.z, target_vel.z, 1.0 - exp(-air_acceleration * delta))
			
			if move_direction != Vector3.ZERO and visual:
				var target_angle := atan2(-move_direction.x, -move_direction.z)
				visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_angle, rotation_speed * 0.8 * delta)
				visual.rotation.z = 0.0

		State.GLIDE:
			if not _is_glide_held():
				_exit_glide(State.FALL)
			else:
				# Vertical descent physics: gentle gravity clamped at max fall speed
				velocity.y -= glider_gravity * delta
				velocity.y = maxf(velocity.y, -glider_max_fall_speed)
				
				# In-air steering & flight acceleration
				if input_magnitude > 0.05 and move_direction != Vector3.ZERO:
					var target_spd := glider_speed * clampf(input_magnitude, 0.4, 1.0)
					var target_vel := move_direction * target_spd
					var accel_w := 1.0 - exp(-glider_acceleration * delta)
					velocity.x = lerp(velocity.x, target_vel.x, accel_w)
					velocity.z = lerp(velocity.z, target_vel.z, accel_w)
					
					if visual:
						var target_angle := atan2(-move_direction.x, -move_direction.z)
						visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_angle, glider_turning_speed * delta)
						
						# Dynamic banking lean into flight curves
						if lean_enabled:
							var horiz_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
							var cross_y := move_direction.cross(horiz_dir).y
							var dot_val := clampf(move_direction.dot(horiz_dir), -1.0, 1.0)
							var signed_angle := atan2(cross_y, dot_val)
							var spd_ratio := clampf(Vector2(velocity.x, velocity.z).length() / glider_speed, 0.2, 1.0)
							var target_lean := clampf(signed_angle * spd_ratio * 1.5, -deg_to_rad(glider_lean_angle), deg_to_rad(glider_lean_angle))
							_current_lean = lerp(_current_lean, target_lean, 10.0 * delta)
						else:
							_current_lean = 0.0
						visual.rotation.z = _current_lean
				else:
					# Gentle aerodynamic drag when gliding without steering input
					var glide_drag := 1.0 - exp(-3.5 * delta)
					velocity.x = lerp(velocity.x, 0.0, glide_drag)
					velocity.z = lerp(velocity.z, 0.0, glide_drag)
					if visual:
						_current_lean = lerp(_current_lean, 0.0, 8.0 * delta)
						visual.rotation.z = _current_lean

		State.RAIL_GRIND:
			if not is_instance_valid(current_rail) or not current_rail.curve or current_rail.curve.point_count < 2:
				_exit_rail_grind(State.FALL)
			else:
				var min_spd: float = current_rail.get("min_grind_speed") if "min_grind_speed" in current_rail else rail_grind_min_speed
				var max_spd: float = current_rail.get("max_grind_speed") if "max_grind_speed" in current_rail else rail_grind_max_speed
				var downhill_acc: float = current_rail.get("grind_downhill_accel") if "grind_downhill_accel" in current_rail else rail_grind_downhill_accel
				var uphill_dec: float = current_rail.get("grind_uphill_decel") if "grind_uphill_decel" in current_rail else rail_grind_uphill_decel
				var brake_f: float = current_rail.get("grind_brake_force") if "grind_brake_force" in current_rail else rail_grind_brake_force
				var dash_bst: float = current_rail.get("grind_dash_boost") if "grind_dash_boost" in current_rail else rail_grind_dash_boost
				
				# 1. Slope Physics (Downhill accelerates, Uphill decelerates)
				var cur_pose := _get_rail_grind_pose(current_rail, rail_grind_offset, rail_grind_direction)
				var r_fwd: Vector3 = cur_pose.forward
				var slope := r_fwd.y # Negative when descending, positive when climbing
				if slope < -0.05:
					rail_grind_speed += absf(slope) * downhill_acc * delta
				elif slope > 0.05:
					rail_grind_speed -= slope * uphill_dec * delta
					
				# 2. Input: Grind Dash
				if _is_dash_just_pressed() or _is_spin_just_pressed():
					rail_grind_speed = minf(rail_grind_speed + dash_bst, max_spd * 1.35)
					_play_dash_sfx()
					
				# 3. Input: Grind Brake
				if crouch_held:
					rail_grind_speed = move_toward(rail_grind_speed, min_spd * 0.45, brake_f * delta)
					
				rail_grind_speed = clampf(rail_grind_speed, min_spd * 0.4, max_spd * 1.35)
				
				# 4. Audio Pitch modulation & continuous loop check
				var speed_ratio := clampf((rail_grind_speed - min_spd) / maxf(max_spd - min_spd, 1.0), 0.0, 1.5)
				if audio:
					audio.update_rail_grind_loop(speed_ratio)
					
				# 5. Jump off rail
				if jump_buffer_timer > 0.0 or _is_jump_just_pressed():
					jump_buffer_timer = 0.0
					var jump_vel := r_fwd * rail_grind_speed + Vector3.UP * (jump_velocity * 1.1)
					_exit_rail_grind(State.JUMP)
					velocity = jump_vel
					_rail_jump_cooldown = 0.28
					_play_jump_sfx()
					_play_anim(_get_jump_anim(), 0.08)
					return true
					
				# 6. Advance along curve
				var rail_len := current_rail.curve.get_baked_length()
				rail_grind_offset += rail_grind_direction * rail_grind_speed * delta
				
				var is_closed := current_rail.curve.sample_baked(0.0).distance_squared_to(current_rail.curve.sample_baked(rail_len)) < 0.1
				if is_closed:
					rail_grind_offset = fposmod(rail_grind_offset, rail_len)
				else:
					if rail_grind_offset >= rail_len or rail_grind_offset <= 0.0:
						# Launched off the end of the rail!
						var launch_vel := r_fwd * rail_grind_speed + Vector3.UP * 4.5
						_exit_rail_grind(State.JUMP)
						velocity = launch_vel
						_rail_jump_cooldown = 0.35
						_play_jump_sfx()
						return true
						
				# 7. Update Position & Orientation
				var new_pose := _get_rail_grind_pose(current_rail, rail_grind_offset, rail_grind_direction)
				var contact_h := _get_grind_height_offset(current_rail)
				global_position = new_pose.position + new_pose.up * contact_h
				velocity = Vector3.ZERO
				
				if visual:
					visual.global_transform.basis = new_pose.basis
					
				# 8. Sparks Particles Update
				if effects:
					var l_pos := left_shoe_model.global_position if left_shoe_model else global_position
					var r_pos := right_shoe_model.global_position if right_shoe_model else global_position
					effects.update_grind_sparks(l_pos, r_pos, new_pose.forward)

		State.IDLE, State.WALK:
			var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
			var cur_spd := horiz_vel.length()
			
			# Long Jump combo: Sprinting + Crouch + Jump
			if crouch_held and on_floor and cur_spd > walk_speed * 0.75 and (jump_buffer_timer > 0.0 or _is_jump_just_pressed()):
				jump_buffer_timer = 0.0
				_execute_long_jump()
			elif jump_buffer_timer > 0.0 and (on_floor or coyote_timer > 0.0):
				_execute_jump()
			elif crouch_held and on_floor:
				current_state = State.CROUCH
			else:
				velocity.y = -0.1
				var target_spd := (run_speed if is_running else walk_speed) * clampf(input_magnitude, 0.0, 1.0)
				
				# Check Brake / Skid turnaround (C# brakeThreshold = -0.8)
				if cur_spd > walk_speed * 0.75 and move_direction != Vector3.ZERO:
					var dot := move_direction.dot(horiz_vel.normalized())
					if dot < brake_threshold:
						current_state = State.BRAKE
						_brake_timer = 0.35
						_play_anim(_get_brake_anim(), 0.06)
						
				if current_state != State.BRAKE:
					if move_direction != Vector3.ZERO and target_spd > 0.05:
						var target_vel := move_direction * target_spd
						var accel_w := 1.0 - exp(-acceleration * delta)
						velocity.x = lerp(velocity.x, target_vel.x, accel_w)
						velocity.z = lerp(velocity.z, target_vel.z, accel_w)
						
						current_state = State.WALK
						_handle_footsteps(delta, cur_spd, is_running)
						
						if visual:
							var target_angle := atan2(-move_direction.x, -move_direction.z)
							visual.global_rotation.y = lerp_angle(visual.global_rotation.y, target_angle, rotation_speed * delta)
							
							# Procedural Banking / Lean (signed angle from PlayerLean.cs)
							if lean_enabled:
								var horiz_dir := Vector3(velocity.x, 0.0, velocity.z).normalized()
								var cross_y := move_direction.cross(horiz_dir).y
								var dot_val := clampf(move_direction.dot(horiz_dir), -1.0, 1.0)
								var signed_angle := atan2(cross_y, dot_val)
								var spd_ratio := clampf(cur_spd / run_speed, 0.2, 1.0)
								var target_lean := clampf(signed_angle * spd_ratio, -deg_to_rad(max_lean_deg), deg_to_rad(max_lean_deg))
								_current_lean = lerp(_current_lean, target_lean, 12.0 * delta)
							else:
								_current_lean = 0.0
							visual.rotation.z = _current_lean
					else:
						var fric_w := 1.0 - exp(-friction * delta)
						velocity.x = lerp(velocity.x, 0.0, fric_w)
						velocity.z = lerp(velocity.z, 0.0, fric_w)
						current_state = State.IDLE if (cur_spd < 0.1) else State.WALK
						if lean_enabled and visual:
							_current_lean = lerp(_current_lean, 0.0, 14.0 * delta)
							visual.rotation.z = _current_lean

	return false

## Executes physics step traversal, collaborating with PlayerStepClimber on ground
## and falling back to move_and_slide() for airborne actions or rail grinding.
func _process_step_and_physics(delta: float) -> void:
	var is_air_action := current_state == State.JUMP or current_state == State.DASH or current_state == State.SPIN or current_state == State.BACKFLIP or current_state == State.LONG_JUMP or current_state == State.GLIDE or current_state == State.RAIL_GRIND
	floor_snap_length = 0.0 if is_air_action else 0.55
	if current_state == State.RAIL_GRIND:
		pass
	elif is_air_action or not step_climber:
		move_and_slide()
		if step_climber:
			step_climber.decay_offset(delta)
	else:
		step_climber.process_step_movement(delta)

## Updates visual squash & stretch, foot IK planting, bump pushables,
## flashlight upper-body blend, and state animation playback.
func _process_juice(delta: float, is_running: bool) -> void:
	# Spring-based procedural squash & stretch (elastic cartoon bounce!)
	if squash_stretch_enabled and visual:
		_update_squash_stretch(delta)

	# Modular Foot IK update (plants feet on stairs, curbs and slopes)
	if foot_ik:
		var is_air := current_state == State.JUMP or current_state == State.FALL or current_state == State.DASH or current_state == State.SPIN or current_state == State.BACKFLIP or current_state == State.LONG_JUMP or current_state == State.GLIDE or current_state == State.RAIL_GRIND
		var is_moving := Vector2(velocity.x, velocity.z).length() > 0.25
		foot_ik.update(delta, is_air, is_running, is_moving)

	_handle_bump_pushables(delta)

	# Smoothly suppress upper-body flashlight arm blend during special moves
	if animator:
		animator.update_arm_blend(delta, current_state, flashlight_enabled and hand_flashlight and hand_flashlight.visible)

	# Update animation based on state
	_update_animation(is_running)

func _remap_deadzone(val: float, deadzone: float = 0.15) -> float:
	if absf(val) <= deadzone:
		return 0.0
	return signf(val) * ((absf(val) - deadzone) / (1.0 - deadzone))

func _get_input_vector() -> Vector2:
	# Cross deadzone from PlayerInputManager.cs
	var joy_x := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_y := -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(joy_x) > 0.15 or absf(joy_y) > 0.15:
		return Vector2(_remap_deadzone(joy_x), _remap_deadzone(joy_y))
		
	# Digital Keyboard / D-Pad
	var dir := Vector2.ZERO
	if _check_action("move_forward") or _check_action("ui_up") or Input.is_physical_key_pressed(KEY_W) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dir.y += 1.0
	if _check_action("move_back") or _check_action("ui_down") or Input.is_physical_key_pressed(KEY_S) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dir.y -= 1.0
	if _check_action("move_left") or _check_action("ui_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dir.x -= 1.0
	if _check_action("move_right") or _check_action("ui_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dir.x += 1.0
		
	return dir.normalized()

func _get_camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector == Vector2.ZERO:
		return Vector3.ZERO
		
	var active_cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var ref_cam_basis: Basis
	if active_cam:
		ref_cam_basis = active_cam.global_transform.basis
	elif camera_pivot:
		ref_cam_basis = camera_pivot.global_transform.basis
	else:
		ref_cam_basis = Basis.IDENTITY

	if active_cam or camera_pivot:
		var forward := -ref_cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		
		var right := ref_cam_basis.x
		right.y = 0.0
		right = right.normalized()
		
		return (forward * input_vector.y + right * input_vector.x).normalized()
	else:
		return Vector3(input_vector.x, 0.0, -input_vector.y).normalized()

func _is_crouch_held() -> bool:
	return _check_action("crouch") \
		or Input.is_physical_key_pressed(KEY_CTRL) \
		or Input.is_physical_key_pressed(KEY_C) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_B) \
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.4

func _execute_jump() -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.JUMP)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.JUMP)
	current_state = State.JUMP
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	velocity.y = jump_velocity
	if effects:
		effects.apply_jump_squash()
	_play_jump_sfx()
	_emit_jump_dust()
	_play_anim(_get_jump_anim(), 0.08)
	_set_anim_speed(1.25)

## Katapultiert Barnaby in die Luft (z. B. durch Trampoline, Sprung-Plattformen oder externe Impulse).
func bounce(force: float = 16.0, forward_boost: Vector3 = Vector3.ZERO, is_super: bool = false) -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.JUMP)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.JUMP)
	current_state = State.JUMP
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_bounce_timer = 0.45
	_was_on_floor = false
	floor_snap_length = 0.0
	_air_dash_counter = 0
	_air_spin_counter = 0
	_spin_timer = 0.0
	_dash_timer = 0.0
	velocity.y = force
	if forward_boost != Vector3.ZERO:
		velocity.x = forward_boost.x
		velocity.z = forward_boost.z
	if effects:
		effects.apply_bounce_squash(is_super)
	_play_jump_sfx()
	_emit_jump_dust()
	_play_anim(_get_jump_anim(), 0.06)
	_set_anim_speed(1.35 if is_super else 1.2)

func _execute_dash() -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.DASH)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.DASH)
	current_state = State.DASH
	_last_dash_time = Time.get_ticks_msec() / 1000.0
	_dash_timer = dash_duration
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_dash_buffer_timer = 0.0
	
	if not is_on_floor():
		_air_dash_counter += 1
		
	var input_vec := _get_input_vector()
	var heading := _get_camera_relative_direction(input_vec)
	if heading.length_squared() < 0.01:
		if visual:
			heading = -visual.global_transform.basis.z
			heading.y = 0.0
			heading = heading.normalized()
		else:
			heading = Vector3.FORWARD
			
	_dash_direction = heading
	velocity.y = 0.0
	velocity.x = _dash_direction.x * dash_force
	velocity.z = _dash_direction.z * dash_force
	
	if visual:
		visual.global_rotation.y = atan2(-_dash_direction.x, -_dash_direction.z)
		visual.rotation.z = 0.0
		if effects:
			effects.apply_dash_squash()
			
	_play_dash_sfx()
	_emit_dash_dust()
	_play_anim(_get_dash_anim(), 0.06)
	_set_anim_speed(1.45)

func _execute_spin() -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.SPIN)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.SPIN)
	current_state = State.SPIN
	_spin_timer = spin_duration
	_spin_buffer_timer = 0.0
	_dash_buffer_timer = 0.0
	
	if not is_on_floor():
		_air_spin_counter += 1
		velocity.y = air_spin_lift
		
		# If moving in air, give forward boost to carry momentum across gaps!
		var input_vec := _get_input_vector()
		var heading := _get_camera_relative_direction(input_vec)
		if heading != Vector3.ZERO:
			var cur_spd := Vector2(velocity.x, velocity.z).length()
			var spin_fwd := maxf(cur_spd, walk_speed * 1.15)
			velocity.x = heading.x * spin_fwd
			velocity.z = heading.z * spin_fwd
			if visual:
				var target_angle := atan2(-heading.x, -heading.z)
				visual.global_rotation.y = target_angle
	else:
		velocity.y = -0.1
		
	if effects:
		effects.apply_spin_squash()
		
	_play_spin_sfx()
	_play_anim(_get_spin_anim(), 0.05)
	_set_anim_speed(1.65)

func _execute_long_jump() -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.LONG_JUMP)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.LONG_JUMP)
	current_state = State.LONG_JUMP
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	
	var input_vec := _get_input_vector()
	var heading := _get_camera_relative_direction(input_vec)
	if heading.length_squared() < 0.01:
		if visual:
			heading = -visual.global_transform.basis.z
			heading.y = 0.0
			heading = heading.normalized()
		else:
			heading = Vector3.FORWARD
			
	_long_jump_direction = heading
	velocity.y = long_jump_velocity
	velocity.x = _long_jump_direction.x * long_jump_forward_boost
	velocity.z = _long_jump_direction.z * long_jump_forward_boost
	
	if visual:
		visual.global_rotation.y = atan2(-_long_jump_direction.x, -_long_jump_direction.z)
		visual.rotation.z = 0.0
		if effects:
			effects.apply_long_jump_squash()
			
	_play_jump_sfx()
	_emit_jump_dust()
	_play_anim(_get_jump_anim(), 0.06)
	_set_anim_speed(1.25)

func _execute_air_dive() -> void:
	_execute_spin() # Air spin requested by user

func _execute_backflip(force: float = -1.0) -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.BACKFLIP)
	elif current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.BACKFLIP)
	current_state = State.BACKFLIP
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_backflip_lock_timer = 0.22
	
	var actual_force: float = backflip_turn_force if force < 0.0 else force
	velocity.y = backflip_jump_velocity
	
	# Backward velocity relative to character orientation
	var backward_dir := Vector3.ZERO
	if visual:
		backward_dir = visual.global_transform.basis.z
		backward_dir.y = 0.0
		backward_dir = backward_dir.normalized()
	else:
		backward_dir = Vector3.BACK
		
	velocity.x = backward_dir.x * actual_force
	velocity.z = backward_dir.z * actual_force
	
	if visual:
		visual.rotation.z = 0.0
		if effects:
			effects.apply_backflip_squash()
			
	_play_backflip_sfx()
	_emit_jump_dust()
	_play_anim(_get_backflip_anim(), 0.08)
	_set_anim_speed(1.2)

func _check_action(action_name: String) -> bool:
	if InputMap.has_action(action_name):
		return Input.is_action_pressed(action_name)
	return false

func _is_sprint_pressed() -> bool:
	return _check_action("sprint") \
		or Input.is_physical_key_pressed(KEY_SHIFT) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) \
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT) > 0.4 \
		or Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT) > 0.4

func _is_jump_held() -> bool:
	return _check_action("jump") \
		or _check_action("ui_accept") \
		or Input.is_physical_key_pressed(KEY_SPACE) \
		or Input.is_joy_button_pressed(0, JOY_BUTTON_A)

func _is_jump_just_pressed() -> bool:
	return _check_action_just_pressed("jump") or _check_action_just_pressed("ui_accept")

func _is_dash_just_pressed() -> bool:
	return _check_action_just_pressed("dash")

func _is_spin_just_pressed() -> bool:
	return _check_action_just_pressed("spin")

func _check_action_just_pressed(action_name: String) -> bool:
	if InputMap.has_action(action_name):
		return Input.is_action_just_pressed(action_name)
	return false

func _is_glide_held() -> bool:
	return _check_action("glide") or _is_jump_held()

func _is_glide_just_pressed() -> bool:
	return _check_action_just_pressed("glide") or _is_jump_just_pressed()

func has_glider() -> bool:
	if equipment:
		return equipment.has_glider()
	if glider_unlocked:
		return true
	var inv = get_node_or_null("/root/InventoryManager")
	return inv != null and inv.has_item("glider")

func _can_start_gliding() -> bool:
	if not glider_enabled or not has_glider():
		return false
	if is_on_floor() or coyote_timer > 0.0:
		return false
	if current_state != State.JUMP and current_state != State.FALL and current_state != State.BACKFLIP:
		return false
	if _bounce_timer > 0.0 and velocity.y > 0.5:
		return false
	return velocity.y <= 0.5

func _execute_glide() -> void:
	if current_state == State.RAIL_GRIND:
		_exit_rail_grind(State.GLIDE)
	current_state = State.GLIDE
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_bounce_timer = 0.0
	
	# Parachute lift catch: zero out negative fall speed
	velocity.y = maxf(velocity.y, 0.0)
	
	if equipment:
		equipment.set_glider_visible(true)
	elif _glider_model:
		_glider_model.visible = true
		
	if effects:
		effects.apply_glider_squash()
		
	_play_glider_open_sfx()
	_play_anim(_get_gliding_anim(), 0.1)
	_set_anim_speed(1.0)

func _exit_glide(next_state: State = State.FALL) -> void:
	if current_state != State.GLIDE:
		return
	current_state = next_state
	if equipment:
		equipment.set_glider_visible(false)
	elif _glider_model:
		_glider_model.visible = false
	if visual:
		visual.rotation.z = 0.0

func _execute_rail_grind(rail: Path3D, start_offset: float) -> void:
	if current_state == State.GLIDE:
		_exit_glide(State.RAIL_GRIND)
		
	current_state = State.RAIL_GRIND
	current_rail = rail
	rail_grind_offset = start_offset
	coyote_timer = 0.0
	jump_buffer_timer = 0.0
	_bounce_timer = 0.0
	_air_dash_counter = 0
	_air_spin_counter = 0
	
	# Determine forward or backward grind direction along curve
	var initial_pose := _get_rail_grind_pose(rail, start_offset, 1.0)
	var vel_horiz := Vector3(velocity.x, 0.0, velocity.z)
	if vel_horiz.length() > 0.5 and vel_horiz.normalized().dot(initial_pose.forward) < -0.2:
		rail_grind_direction = -1.0
	else:
		rail_grind_direction = 1.0
		
	var incoming_spd := vel_horiz.length()
	var min_spd: float = rail.get("min_grind_speed") if "min_grind_speed" in rail else rail_grind_min_speed
	var max_spd: float = rail.get("max_grind_speed") if "max_grind_speed" in rail else rail_grind_max_speed
	rail_grind_speed = clampf(maxf(incoming_spd * 1.15, min_spd), min_spd, max_spd)
	
	velocity = Vector3.ZERO
	
	# Snap immediately to the rail curve
	var snap_pose := _get_rail_grind_pose(rail, start_offset, rail_grind_direction)
	var contact_h := _get_grind_height_offset(rail)
	global_position = snap_pose.position + snap_pose.up * contact_h
	if visual:
		visual.global_transform.basis = snap_pose.basis
	
	# Play sound effects & juice
	if effects:
		effects.apply_rail_grind_squash()
	if audio:
		audio.play_rail_start()
		audio.start_rail_grind_loop(1.0)
			
	# Animation
	_play_anim(_get_grind_anim(), 0.08)
	_set_anim_speed(1.2)

func _exit_rail_grind(next_state: State = State.FALL) -> void:
	if current_state != State.RAIL_GRIND:
		return
	current_state = next_state
	current_rail = null
	if audio:
		audio.stop_rail_grind_loop()
	if effects:
		effects.stop_grind_sparks()
	if visual:
		visual.rotation = Vector3.ZERO

## Dynamischer Höhenabstand basierend auf Schienenrohr-Radius (damit Schuhe immer bündig aufsitzen)
func _get_grind_height_offset(rail: Path3D) -> float:
	if rail and "pipe_radius" in rail:
		return float(rail.pipe_radius) + (rail_grind_height_offset - 0.075)
	return rail_grind_height_offset

## Berechnet stabile Weltposition, Fahrtrichtung, Normalenvektor und Drehungsbasis für Rails
func _get_rail_grind_pose(rail: Path3D, offset: float, direction: float) -> Dictionary:
	if not rail or not rail.curve:
		return {
			"position": global_position,
			"forward": -global_transform.basis.z * direction,
			"up": Vector3.UP,
			"basis": Basis.IDENTITY
		}
	if rail.has_method("sample_grind_pose"):
		return rail.sample_grind_pose(offset, direction)
		
	var total_len := rail.curve.get_baked_length()
	var d := clampf(offset, 0.0, total_len) if total_len > 0.0 else 0.0
	var world_pos := rail.to_global(rail.curve.sample_baked(d))
	
	var local_trans := rail.curve.sample_baked_with_rotation(d, true, false)
	var curve_fwd := (rail.global_transform.basis * (-local_trans.basis.z)).normalized()
	var travel_fwd := curve_fwd * (1.0 if direction >= 0.0 else -1.0)
	
	var side := curve_fwd.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = curve_fwd.cross(Vector3.FORWARD)
		if side.length_squared() < 0.0001:
			side = curve_fwd.cross(Vector3.RIGHT)
	side = side.normalized()
	var surface_up := side.cross(curve_fwd).normalized()
	if surface_up.dot(Vector3.UP) < 0.0:
		surface_up = -surface_up
		
	var right := travel_fwd.cross(surface_up).normalized()
	var ortho_up := right.cross(travel_fwd).normalized()
	var grind_basis := Basis(right, ortho_up, -travel_fwd)
	
	if total_len > 1.0:
		var step := 0.8 * (1.0 if direction >= 0.0 else -1.0)
		var ahead_d := clampf(d + step, 0.0, total_len)
		var local_ta := rail.curve.sample_baked_with_rotation(ahead_d, true, false)
		var ahead_fwd := (rail.global_transform.basis * (-local_ta.basis.z * (1.0 if direction >= 0.0 else -1.0))).normalized()
		var turn_yaw := travel_fwd.cross(ahead_fwd).y
		var bank_angle := clampf(turn_yaw * 2.5, -0.35, 0.35)
		grind_basis = grind_basis.rotated(travel_fwd, bank_angle)
		
	return {
		"position": world_pos,
		"forward": travel_fwd,
		"up": surface_up,
		"basis": grind_basis
	}

func _get_walk_anim() -> String:
	return animator.get_walk_anim() if animator else "Walk"

func _get_run_anim() -> String:
	return animator.get_run_anim() if animator else "Run"

func _get_idle_anim() -> String:
	return animator.get_idle_anim() if animator else "Idle"

func _get_jump_anim() -> String:
	return animator.get_jump_anim() if animator else "Jump"

func _get_fall_anim() -> String:
	return animator.get_fall_anim() if animator else "Fall"

func _get_gliding_anim() -> String:
	return animator.get_gliding_anim() if animator else "Gliding"

func _get_grind_anim() -> String:
	return animator.get_grind_anim() if animator else "Grind"

func _get_celebration_anim() -> String:
	return animator.get_celebration_anim() if animator else "dance"

func _get_dash_anim() -> String:
	return animator.get_dash_anim() if animator else "Dash"

func _get_spin_anim() -> String:
	return animator.get_spin_anim() if animator else "Spin"

func _get_dive_anim() -> String:
	return animator.get_dive_anim() if animator else "Dive"

func _get_backflip_anim() -> String:
	return animator.get_backflip_anim() if animator else "Backflip"

func _get_brake_anim() -> String:
	return animator.get_brake_anim() if animator else "Brake"

func _get_crouch_anim() -> String:
	return animator.get_crouch_anim() if animator else "Crouch"

func _get_crawl_anim() -> String:
	return animator.get_crawl_anim() if animator else "Crawl"

func _update_animation(sprint_input: bool) -> void:
	if animator:
		var horiz_spd := Vector2(velocity.x, velocity.z).length()
		animator.update_animation(
			current_state,
			horiz_spd,
			sprint_input,
			walk_speed,
			run_speed,
			crawling_speed,
			rail_grind_speed,
			rail_grind_min_speed
		)
		current_anim = animator.current_anim

func _play_anim(anim_name: String, blend_time: float = 0.2) -> void:
	if animator:
		animator.play_anim(anim_name, blend_time)
		current_anim = animator.current_anim

func _update_interactions() -> void:
	if interaction:
		interaction.update_interactions()
		if is_instance_valid(interaction.current_interactable):
			current_interactable = interaction.current_interactable
		else:
			current_interactable = null

func _on_quest_celebration_started(quest: QuestData = null) -> void:
	if interaction:
		interaction.on_quest_celebration_started(quest)
		is_celebrating = interaction.is_celebrating

func _on_quest_celebration_ended(quest: QuestData = null) -> void:
	if interaction:
		interaction.on_quest_celebration_ended(quest)
		is_celebrating = interaction.is_celebrating

func _handle_bump_pushables(delta: float) -> void:
	if interaction:
		interaction.handle_bump_pushables(delta)

# ==============================================================================
# JUICE, FEEDBACK, AUDIO & PARTICLES (GAME FEEL SYSTEM)
# ==============================================================================

# ==============================================================================
# AUDIO, PARTICLES & JUICE DELEGATIONS
# ==============================================================================

func _play_glider_open_sfx() -> void:
	if audio:
		audio.play_glider_open()

func _update_squash_stretch(delta: float) -> void:
	if effects:
		effects.update_squash_stretch(delta)

func _handle_footsteps(delta: float, cur_spd: float, is_running: bool) -> void:
	if audio:
		audio.handle_footsteps(delta, cur_spd, is_running, is_on_floor(), func():
			_emit_foot_dust()
		)

func _play_footstep() -> void:
	if audio:
		audio.play_footstep()

func _play_jump_sfx() -> void:
	if audio:
		audio.play_jump()

func _play_landing_feedback(fall_velocity: float) -> void:
	if effects:
		effects.emit_landing_dust()
	if audio:
		audio.play_landing(fall_velocity)

func _play_dash_sfx() -> void:
	if audio:
		audio.play_dash()

func _play_spin_sfx() -> void:
	if audio:
		audio.play_spin()

func _play_backflip_sfx() -> void:
	if audio:
		audio.play_backflip()

func _emit_jump_dust() -> void:
	if effects:
		effects.emit_jump_dust()

func _emit_dash_dust() -> void:
	if effects:
		effects.emit_dash_dust()

func _emit_skid_dust() -> void:
	if effects:
		effects.emit_skid_dust()

func _stop_skid_dust() -> void:
	if effects:
		effects.stop_skid_dust()

func _emit_foot_dust() -> void:
	if effects:
		effects.emit_foot_dust()
