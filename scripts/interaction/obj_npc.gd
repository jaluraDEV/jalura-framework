@tool
class_name ObjNPC
extends InteractiveObject

## Vorlage für modulare NPCs (ObjNPC).
## Exponiert alle Dialog- und Quest-Einstellungen direkt auf dem Wurzel-Node im Inspector,
## sodass diese ohne "Editable Children" konfiguriert werden können.
## Leitet Einstellungen an das untergeordnete NPCBehavior weiter.

@export_group("NPC Identification")
@export var npc_id: String = "":
	set(val):
		npc_id = val
		_sync_npc_properties()

@export var display_name: String = "NPC":
	set(val):
		display_name = val
		_sync_npc_properties()

@export_group("Dialogue & Prompts")
@export var prompt_text: String = "Talk":
	set(val):
		prompt_text = val
		_sync_npc_properties()

@export var idle_dialogue: Array = ["Ahoi! Wie kann ich dir helfen?"]:
	set(val):
		var typed: Array[String] = []
		for line in val:
			typed.append(str(line))
		idle_dialogue = typed
		_sync_npc_properties()

@export_group("Behavior & Visuals")
@export var face_player: bool = true:
	set(val):
		face_player = val
		_sync_npc_properties()

@export var turn_speed: float = 0.25:
	set(val):
		turn_speed = val
		_sync_npc_properties()

func _ready() -> void:
	super._ready()
	_sync_npc_properties()
	_start_idle_animation()

func _start_idle_animation() -> void:
	if Engine.is_editor_hint():
		return
	var ap := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap and ap.has_animation("idle") and not ap.is_playing():
		ap.play("idle")

func _sync_npc_properties() -> void:
	var nb := get_npc_behavior()
	if nb:
		nb.npc_id = npc_id
		nb.display_name = display_name
		nb.prompt_text = prompt_text
		nb.idle_dialogue = idle_dialogue
		nb.face_player = face_player
		nb.turn_speed = turn_speed
		refresh_prompt()

func get_npc_behavior() -> NPCBehavior:
	return find_child("NPCBehavior", false, false) as NPCBehavior

## Startet das Gespräch programmatisch (z. B. durch Cutscenes oder Trigger)
func talk(player: Node) -> bool:
	var nb := get_npc_behavior()
	if nb:
		return nb.interact(player)
	return false
