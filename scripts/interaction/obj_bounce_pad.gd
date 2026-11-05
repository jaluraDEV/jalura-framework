@tool
class_name ObjBouncePad
extends InteractiveObject

const BouncePadBehavior = preload("res://scripts/interaction/behaviors/bounce_pad_behavior.gd")

## Vorlage für Sprung-Plattformen & Trampoline (ObjBouncePad).
## Exponiert alle wichtigen Einstellungen für Sprungkraft, Super-Bounce, Rebound-Animation
## und Zielansteuerung direkt auf dem Wurzel-Node im Inspector, sodass Leveldesigner
## und Entwickler jede Plattform individuell im Editor konfigurieren können.

@export_group("Jump Settings")
@export_range(5.0, 50.0, 0.5) var bounce_velocity: float = 16.0:
	set(val):
		bounce_velocity = val
		_sync_bounce_properties()

@export var allow_super_bounce: bool = true:
	set(val):
		allow_super_bounce = val
		_sync_bounce_properties()

@export_range(5.0, 60.0, 0.5) var super_bounce_velocity: float = 22.0:
	set(val):
		super_bounce_velocity = val
		_sync_bounce_properties()

@export var launch_direction_mode: BouncePadBehavior.LaunchDirectionMode = BouncePadBehavior.LaunchDirectionMode.WORLD_UP:
	set(val):
		launch_direction_mode = val
		_sync_bounce_properties()

@export_range(0.0, 30.0, 0.5) var forward_boost: float = 0.0:
	set(val):
		forward_boost = val
		_sync_bounce_properties()

@export_range(0.05, 1.0, 0.05) var cooldown: float = 0.2:
	set(val):
		cooldown = val
		_sync_bounce_properties()

@export_group("Filter & Detection")
@export var trigger_by_player: bool = true:
	set(val):
		trigger_by_player = val
		_sync_bounce_properties()

@export var trigger_by_blocks: bool = true:
	set(val):
		trigger_by_blocks = val
		_sync_bounce_properties()

@export_group("Visual Feedback & Audio")
@export var bounce_sound: AudioStream = null:
	set(val):
		bounce_sound = val
		_sync_bounce_properties()

@export_range(0.05, 0.6, 0.05) var rebound_depth: float = 0.25:
	set(val):
		rebound_depth = val
		_sync_bounce_properties()

@export_group("Water Bobbing")
@export var water_bob_enabled: bool = false:
	set(val):
		water_bob_enabled = val
		_sync_bounce_properties()

@export_range(0.0, 0.4, 0.01) var water_bob_height: float = 0.07:
	set(val):
		water_bob_height = val
		_sync_bounce_properties()

@export_range(0.2, 6.0, 0.1) var water_bob_speed: float = 2.0:
	set(val):
		water_bob_speed = val
		_sync_bounce_properties()

@export_range(0.0, 20.0, 0.5) var water_bob_tilt_deg: float = 4.5:
	set(val):
		water_bob_tilt_deg = val
		_sync_bounce_properties()

@export_group("Targets & Remote Control")
@export var target_objects: Array[NodePath] = []:
	set(val):
		target_objects = val.duplicate()
		_sync_bounce_properties()

@export var target_method: String = "activate":
	set(val):
		target_method = val
		_sync_bounce_properties()

func _setup_interactable() -> void:
	# Sprung-Plattformen werden rein physisch betreten, kein [E]-Interaktionsprompt nötig.
	var existing := find_child("Interactable", true, false)
	if existing:
		existing.queue_free()
	interactable = null

func _ready() -> void:
	add_to_group("bounce_pads")
	target_objects = target_objects.duplicate()
	super._ready()
	_sync_bounce_properties()

func _sync_bounce_properties() -> void:
	var bpb := get_bounce_behavior()
	if bpb:
		bpb.bounce_velocity = bounce_velocity
		bpb.allow_super_bounce = allow_super_bounce
		bpb.super_bounce_velocity = super_bounce_velocity
		bpb.launch_direction_mode = launch_direction_mode
		bpb.forward_boost = forward_boost
		bpb.cooldown = cooldown
		bpb.trigger_by_player = trigger_by_player
		bpb.trigger_by_blocks = trigger_by_blocks
		bpb.bounce_sound = bounce_sound
		bpb.rebound_depth = rebound_depth
		bpb.water_bob_enabled = water_bob_enabled
		bpb.water_bob_height = water_bob_height
		bpb.water_bob_speed = water_bob_speed
		bpb.water_bob_tilt_deg = water_bob_tilt_deg
		bpb.target_objects = target_objects.duplicate()
		bpb.target_method = target_method

func get_bounce_behavior() -> BouncePadBehavior:
	return find_child("BouncePadBehavior", false, false) as BouncePadBehavior

func trigger_bounce(body: Node = null) -> void:
	var bpb := get_bounce_behavior()
	if bpb:
		bpb.trigger_bounce(body)
