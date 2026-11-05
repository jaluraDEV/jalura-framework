@tool
class_name NPCBehavior
extends ObjectBehavior

## Baustein: NPC & QuestGiver-Brücke (ObjNPC).
## Verbindet modulare InteractiveObjects mit dem QuestManager und Dialogue-System.
## Unterstützt Plandialoge (idle_dialogue), automatische Blickrichtung zum Spieler,
## Quest-Lifecycle-Events ('talked', 'talk_finished', 'quest_started', 'quest_completed')
## und Auslöser/Trigger auf Dialog-Abschluss.

signal talk_started(player: Node)
signal talk_finished(player: Node)

@export_group("NPC Identification")
@export var npc_id: String = "" ## ID für Quests im QuestManager (z. B. "grantelbart", "hildegard"). Wenn leer, wird idle_dialogue genutzt.
@export var display_name: String = "NPC" ## Angezeigter Name im Dialogfenster

@export_group("Dialogue & Prompts")
@export var prompt_text: String = "Sprechen":
	set(val):
		prompt_text = val
		notify_state_changed()

@export var idle_dialogue: Array = ["Ahoi! Wie kann ich dir helfen?"]:
	set(val):
		var typed: Array[String] = []
		for line in val:
			typed.append(str(line))
		idle_dialogue = typed
		notify_state_changed()
@export var priority: int = 20 ## Hohe Priorität (20), damit Gesprächs-Prompt Vorrang vor allgemeinen Aktionen hat

@export_group("Behavior & Visuals")
@export var face_player: bool = true ## Dreht den NPC beim Ansprechen zum Spieler
@export var turn_speed: float = 0.25 ## Dauer der Drehung in Sekunden

var _is_talking: bool = false
var _current_player: Node = null

func _ready() -> void:
	_resolve_hub()
	_connect_quest_manager()

func _connect_quest_manager() -> void:
	var qm := get_node_or_null("/root/QuestManager")
	if not qm:
		return
	if qm.has_signal("quest_started") and not qm.quest_started.is_connected(_on_qm_quest_started):
		qm.quest_started.connect(_on_qm_quest_started)
	if qm.has_signal("quest_completed") and not qm.quest_completed.is_connected(_on_qm_quest_completed):
		qm.quest_completed.connect(_on_qm_quest_completed)

func _get_target_node() -> Node3D:
	_resolve_hub()
	if hub and hub is Node3D:
		return hub as Node3D
	if get_parent() is Node3D:
		return get_parent() as Node3D
	return null

func can_interact(_player: Node) -> bool:
	var hud := get_tree().root.find_child("HUD", true, false) if get_tree() else null
	if hud and hud.get("is_dialogue_active"):
		return false
	return not _is_talking

func get_priority() -> int:
	return priority

func get_prompt() -> String:
	if not prompt_text.is_empty():
		return prompt_text
	return "Mit %s sprechen" % display_name

func interact(player: Node) -> bool:
	if _is_talking:
		return false

	var hud := get_tree().root.find_child("HUD", true, false) if get_tree() else null
	if hud and hud.get("is_dialogue_active"):
		return false

	_current_player = player

	# Zum Spieler drehen
	if face_player and player is Node3D:
		_face_node(player as Node3D)

	# Dialog aus QuestManager oder Fallback holen
	var lines: Array = []
	var on_finished: Callable = Callable()

	var qm := get_node_or_null("/root/QuestManager")
	if qm and not npc_id.is_empty() and qm.has_method("get_npc_dialogue"):
		var result: Dictionary = qm.get_npc_dialogue(npc_id)
		lines = result.get("lines", [])
		on_finished = result.get("on_finished", Callable())
		if qm.has_method("notify_npc_talked"):
			qm.notify_npc_talked(npc_id)

	if lines.is_empty():
		lines = idle_dialogue.duplicate()

	_is_talking = true
	talk_started.emit(player)

	if hub and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"talked", {
			"player": player,
			"source": self,
			"npc_id": npc_id,
			"display_name": display_name
		})

	# Dialog über HUD starten
	if hud and hud.has_method("start_dialogue"):
		hud.start_dialogue(display_name, lines, func():
			_on_dialogue_finished(on_finished)
		)
	else:
		# Fallback ohne HUD (z. B. Headless Tests)
		call_deferred("_on_dialogue_finished", on_finished)

	return true

func _on_dialogue_finished(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

	_is_talking = false
	var finished_player := _current_player
	_current_player = null

	talk_finished.emit(finished_player)

	if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
		hub.call("emit_object_event", &"talk_finished", {
			"player": finished_player,
			"source": self,
			"npc_id": npc_id,
			"display_name": display_name
		})

	notify_state_changed()

func _face_node(target: Node3D) -> void:
	var my_node := _get_target_node()
	if not my_node or not target:
		return
	var look_dir: Vector3 = target.global_position - my_node.global_position
	look_dir.y = 0.0
	if look_dir.length_squared() <= 0.001:
		return
	var current_yaw := my_node.global_rotation.y
	var target_yaw := atan2(look_dir.x, look_dir.z)
	var diff_yaw := wrapf(target_yaw - current_yaw, -PI, PI)

	if is_inside_tree() and turn_speed > 0.0:
		var tween := create_tween()
		tween.tween_property(my_node, "global_rotation:y", current_yaw + diff_yaw, turn_speed) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		my_node.global_rotation.y = current_yaw + diff_yaw

func _on_qm_quest_started(quest: QuestData) -> void:
	if not quest:
		return
	if quest.giver_npc_id == npc_id:
		if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"quest_started", {
				"quest": quest,
				"quest_id": quest.id,
				"npc_id": npc_id
			})

func _on_qm_quest_completed(quest: QuestData, _reward_energy: int = 0) -> void:
	if not quest:
		return
	var turn_in := quest.turn_in_npc_id if not quest.turn_in_npc_id.is_empty() else quest.giver_npc_id
	if turn_in == npc_id:
		if hub and is_instance_valid(hub) and hub.has_method("emit_object_event"):
			hub.call("emit_object_event", &"quest_completed", {
				"quest": quest,
				"quest_id": quest.id,
				"npc_id": npc_id
			})
