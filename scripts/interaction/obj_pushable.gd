@tool
class_name ObjPushable
extends InteractiveObject

## Vorlage für schiebbare Objekte (Kisten, Steinblöcke, Statuen).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Schiebedistanz, Raster und Prompts an das untergeordnete PushableBehavior weiter.
@export_group("Push Properties")
@export var push_trigger: PushableBehavior.PushTrigger = PushableBehavior.PushTrigger.INTERACT:
	set(val):
		push_trigger = val
		_sync_pushable_properties()

@export var bump_hold_time: float = 0.2:
	set(val):
		bump_hold_time = val
		_sync_pushable_properties()

@export var step_distance: float = 1.5:
	set(val):
		step_distance = val
		_sync_pushable_properties()

@export var push_duration: float = 0.38:
	set(val):
		push_duration = val
		_sync_pushable_properties()

@export var push_axis: PushableBehavior.PushAxis = PushableBehavior.PushAxis.ALL:
	set(val):
		push_axis = val
		_sync_pushable_properties()

@export var can_push: bool = true:
	set(val):
		can_push = val
		_sync_pushable_properties()

@export var can_pull: bool = false:
	set(val):
		can_pull = val
		_sync_pushable_properties()

@export var snap_to_grid: bool = true:
	set(val):
		snap_to_grid = val
		_sync_pushable_properties()

@export var check_collision: bool = true:
	set(val):
		check_collision = val
		_sync_pushable_properties()

@export var check_floor: bool = true:
	set(val):
		check_floor = val
		_sync_pushable_properties()

@export_group("Prompts & Text")
@export var push_prompt: String = "Push":
	set(val):
		push_prompt = val
		_sync_pushable_properties()

@export var pull_prompt: String = "Pull":
	set(val):
		pull_prompt = val
		_sync_pushable_properties()

@export var blocked_message: String = "Blockiert! Der Weg ist versperrt.":
	set(val):
		blocked_message = val
		_sync_pushable_properties()

@export_group("Persistence")
@export var save_position: bool = true:
	set(val):
		save_position = val
		_sync_pushable_properties()

func _ready() -> void:
	super._ready()
	_sync_pushable_properties()

func _sync_pushable_properties() -> void:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		pb.push_trigger = push_trigger
		pb.bump_hold_time = bump_hold_time
		pb.step_distance = step_distance
		pb.push_duration = push_duration
		pb.push_axis = push_axis
		pb.can_push = can_push
		pb.can_pull = can_pull
		pb.snap_to_grid = snap_to_grid
		pb.check_collision = check_collision
		pb.check_floor = check_floor
		pb.push_prompt = push_prompt
		pb.pull_prompt = pull_prompt
		pb.blocked_message = blocked_message
		pb.save_position = save_position
		refresh_prompt()

func push(direction: Vector3, player: Node = null, animate: bool = true) -> bool:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		return pb.push(direction, player, animate)
	return false

func bump(player: Node, push_direction: Vector3 = Vector3.ZERO) -> bool:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		return pb.bump(player, push_direction)
	return false

func can_interact(player: Node) -> bool:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		return pb.can_interact(player)
	return false

func reset_to_initial_position() -> void:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		pb.reset_to_initial_position()

func reset_position() -> void:
	reset_to_initial_position()

func set_initial_position(pos: Vector3) -> void:
	var pb := find_child("PushableBehavior", false, false) as PushableBehavior
	if pb:
		pb.set_initial_position(pos)
