@tool
class_name ObjShakeable
extends InteractiveObject

## Vorlage für schüttelbare Welt-Objekte (z. B. Bäume, Sträucher, Kisten, Automaten).
## Exponiert wichtige Baustein-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" bearbeitet werden können.
## Leitet Drops, Cooldowns, Limits und Prompts an das untergeordnete ShakeableBehavior weiter.
@export_group("Drop Settings")
@export var drop_item_data: ItemData:
	set(val):
		drop_item_data = val
		_sync_shakeable_properties()

@export var drop_item_id: String = "":
	set(val):
		drop_item_id = val
		_sync_shakeable_properties()

@export var drop_amount: int = 1:
	set(val):
		drop_amount = maxi(1, val)
		_sync_shakeable_properties()

## Maximale Anzahl Drops pro Spielstand (-1 oder 0 für unendlich)
@export var max_drops: int = 1:
	set(val):
		max_drops = val
		_sync_shakeable_properties()

@export var drop_scene: PackedScene:
	set(val):
		drop_scene = val
		_sync_shakeable_properties()

@export_group("Shake & Cooldown")
@export var shake_cooldown: float = 0.8:
	set(val):
		shake_cooldown = val
		_sync_shakeable_properties()

@export_group("Prompts & Text")
@export var prompt_shake: String = "Shake":
	set(val):
		prompt_shake = val
		_sync_shakeable_properties()

@export var prompt_depleted: String = "Empty":
	set(val):
		prompt_depleted = val
		_sync_shakeable_properties()

@export var depleted_toast_text: String = "Nothing left here.":
	set(val):
		depleted_toast_text = val
		_sync_shakeable_properties()

@export_group("Node References")
@export var visual_node_path: NodePath:
	set(val):
		visual_node_path = val
		_sync_shakeable_properties()

@export var drop_spawn_point_path: NodePath:
	set(val):
		drop_spawn_point_path = val
		_sync_shakeable_properties()

@export var hanging_mesh_path: NodePath:
	set(val):
		hanging_mesh_path = val
		_sync_shakeable_properties()

var shakes_count: int:
	get:
		var sb := find_child("ShakeableBehavior", false, false) as ShakeableBehavior
		return sb.shakes_count if sb else 0

var drops_spawned: int:
	get:
		var sb := find_child("ShakeableBehavior", false, false) as ShakeableBehavior
		return sb.drops_spawned if sb else 0

var is_depleted: bool:
	get:
		var sb := find_child("ShakeableBehavior", false, false) as ShakeableBehavior
		return sb.is_depleted if sb else false

func _ready() -> void:
	super._ready()
	_sync_shakeable_properties()

func _sync_shakeable_properties() -> void:
	var sb := find_child("ShakeableBehavior", false, false) as ShakeableBehavior
	if sb:
		sb.drop_item_data = drop_item_data
		sb.drop_item_id = drop_item_id
		sb.drop_amount = drop_amount
		sb.max_drops = max_drops
		if drop_scene:
			sb.drop_scene = drop_scene
		sb.shake_cooldown = shake_cooldown
		sb.prompt_shake = prompt_shake
		sb.prompt_depleted = prompt_depleted
		sb.depleted_toast_text = depleted_toast_text
		if not visual_node_path.is_empty():
			sb.visual_node_path = visual_node_path
		if not drop_spawn_point_path.is_empty():
			sb.drop_spawn_point_path = drop_spawn_point_path
		if not hanging_mesh_path.is_empty():
			sb.hanging_mesh_path = hanging_mesh_path
		refresh_prompt()
