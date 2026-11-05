extends Node

## Robust Quest Manager for Jalura.
## Vollständig modular, datengetrieben und signal-basiert.
## Lädt alle Quests automatisch aus res://resources/quests/ (inkl. Unterordnern).
## Unterstützt Item-, Orts-, Interaktions-, Gesprächs- und Custom-Event-Ziele.

signal quest_started(quest: QuestData)
signal quest_ready_to_turn_in(quest: QuestData)
signal quest_completed(quest: QuestData, reward_energy: int)
signal quest_celebration_started(quest: QuestData)
signal quest_celebration_ended(quest: QuestData)
signal quest_objective_updated(quest: QuestData, objective: QuestObjective)
signal quest_objective_completed(quest: QuestData, objective: QuestObjective)

const QUESTS_DIR: String = "res://resources/quests"

var _quest_registry: Dictionary = {} # quest_id -> QuestData
var _quest_states: Dictionary = {}   # quest_id -> QuestData.QuestState
var _quest_aliases: Dictionary = {}  # alias_id -> canonical_id

func _ready() -> void:
	load_all_quests()
	_connect_inventory_signals()
	check_auto_start_quests()

## Lädt alle Quests rekursiv aus dem Ordner
func load_all_quests() -> void:
	_load_quests_from_folder(QUESTS_DIR)

func reload_quests() -> void:
	_quest_registry.clear()
	_quest_aliases.clear()
	load_all_quests()
	check_auto_start_quests()

## Löst flexible Quest-IDs auf (z. B. "q_apple_for_grantelbart" -> "apple_for_grantelbart" oder umgekehrt)
func resolve_quest_id(quest_id: String) -> String:
	if quest_id.is_empty():
		return ""
	if _quest_registry.has(quest_id):
		return quest_id
	if _quest_aliases.has(quest_id):
		return _quest_aliases[quest_id]
	if quest_id.begins_with("q_"):
		var stripped := quest_id.substr(2)
		if _quest_registry.has(stripped):
			return stripped
		if _quest_aliases.has(stripped):
			return _quest_aliases[stripped]
	var prefixed := "q_" + quest_id
	if _quest_registry.has(prefixed):
		return prefixed
	if _quest_aliases.has(prefixed):
		return _quest_aliases[prefixed]
	return quest_id

func _register_quest_alias(alias_name: String, target_id: String) -> void:
	if alias_name.is_empty() or target_id.is_empty():
		return
	_quest_aliases[alias_name] = target_id
	if alias_name.begins_with("q_"):
		_quest_aliases[alias_name.substr(2)] = target_id
	else:
		_quest_aliases["q_" + alias_name] = target_id

func _load_quests_from_folder(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir() and not file_name.begins_with("."):
			_load_quests_from_folder(dir_path + "/" + file_name)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path := dir_path + "/" + file_name
			var res = load(full_path)
			if res is QuestData:
				var file_base := file_name.get_basename()
				# Wenn im Resource-File keine ID eingetragen ist: Dateinamen nutzen!
				if res.id.is_empty():
					res.id = file_base
				register_quest(res)
				_register_quest_alias(file_base, res.id)
		file_name = dir.get_next()

func register_quest(quest: QuestData) -> void:
	if quest and not quest.id.is_empty():
		var instance: QuestData = quest.duplicate(true)
		
		# Abwärtskompatibilität: Falls eine alte Quest keine Objectives hat, aber target_item_id besitzt:
		if instance.objectives.is_empty() and not instance.target_item_id.is_empty():
			var obj := ItemObjective.new()
			obj.item_id = instance.target_item_id
			obj.target_amount = maxi(instance.target_item_count, 1)
			obj.description = "Sammle %s" % instance.target_item_id
			instance.objectives.append(obj)
			
		_quest_registry[instance.id] = instance
		_register_quest_alias(instance.id, instance.id)
		if not _quest_states.has(instance.id):
			_quest_states[instance.id] = QuestData.QuestState.NOT_STARTED

func _connect_inventory_signals() -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv and inv.has_signal("item_added"):
		if not inv.item_added.is_connected(_on_inventory_item_added):
			inv.item_added.connect(_on_inventory_item_added)

func _on_inventory_item_added(item_id: String, count: int, _total: int) -> void:
	notify_item_collected(item_id, count)

# ==========================================
# EVENT HANDLERS
# ==========================================

## Wird aufgerufen, wenn Barnaby ein Item aufsammelt
func notify_item_collected(item_id: String, count: int = 1) -> void:
	for quest in _get_active_quests():
		for obj in quest.get_active_objectives():
			if obj is ItemObjective and obj.item_id == item_id and not obj.is_completed():
				var was_completed := obj.is_completed()
				obj.add_progress(count)
				quest_objective_updated.emit(quest, obj)
				if not was_completed and obj.is_completed():
					quest_objective_completed.emit(quest, obj)
				_check_quest_completion_readiness(quest)

## Wird aufgerufen, wenn Barnaby einen Ort/Trigger betritt
func notify_location_reached(location_id: String) -> void:
	for quest in _get_active_quests():
		for obj in quest.get_active_objectives():
			if obj is LocationObjective and obj.location_id == location_id and not obj.is_completed():
				var was_completed := obj.is_completed()
				obj.add_progress(1)
				quest_objective_updated.emit(quest, obj)
				if not was_completed and obj.is_completed():
					quest_objective_completed.emit(quest, obj)
				_check_quest_completion_readiness(quest)

## Wird aufgerufen, wenn Barnaby mit einem Objekt interagiert (z. B. Baum, Hebel)
func notify_interaction(interactable_id: String) -> void:
	if interactable_id.is_empty():
		return
	for quest in _get_active_quests():
		for obj in quest.get_active_objectives():
			if obj is InteractObjective and obj.interactable_id == interactable_id and not obj.is_completed():
				var was_completed := obj.is_completed()
				obj.add_progress(1)
				quest_objective_updated.emit(quest, obj)
				if not was_completed and obj.is_completed():
					quest_objective_completed.emit(quest, obj)
				_check_quest_completion_readiness(quest)

## Wird aufgerufen, wenn Barnaby mit einem NPC spricht
func notify_npc_talked(npc_id: String) -> void:
	if npc_id.is_empty():
		return
	for quest in _get_active_quests():
		for obj in quest.get_active_objectives():
			if obj is TalkObjective and obj.npc_id == npc_id and not obj.is_completed():
				var was_completed := obj.is_completed()
				obj.add_progress(1)
				quest_objective_updated.emit(quest, obj)
				if not was_completed and obj.is_completed():
					quest_objective_completed.emit(quest, obj)
				_check_quest_completion_readiness(quest)

## Wird aufgerufen bei beliebigen individuellen Spielereignissen
func notify_event(event_name: String, _data: Variant = null) -> void:
	if event_name.is_empty():
		return
	for quest in _get_active_quests():
		for obj in quest.get_active_objectives():
			if obj is CustomEventObjective and obj.event_name == event_name and not obj.is_completed():
				var was_completed := obj.is_completed()
				obj.add_progress(1)
				quest_objective_updated.emit(quest, obj)
				if not was_completed and obj.is_completed():
					quest_objective_completed.emit(quest, obj)
				_check_quest_completion_readiness(quest)

func _check_quest_completion_readiness(quest: QuestData) -> void:
	if quest.are_all_objectives_completed():
		_quest_states[quest.id] = QuestData.QuestState.READY_TO_TURN_IN
		quest_ready_to_turn_in.emit(quest)

# ==========================================
# QUEST LEBENSZYKLUS
# ==========================================

func start_quest(quest_id: String) -> bool:
	var resolved_id := resolve_quest_id(quest_id)
	var q := get_quest(resolved_id)
	if not q:
		return false
	if get_quest_state(resolved_id) != QuestData.QuestState.NOT_STARTED:
		return false
		
	if not are_prerequisites_met(q):
		return false
		
	_quest_states[resolved_id] = QuestData.QuestState.ACTIVE
	
	# Prüfen, ob Items bereits im Inventar liegen
	_check_inventory_for_quest(q)
	
	quest_started.emit(q)
	_check_quest_completion_readiness(q)
	return true

func _check_inventory_for_quest(quest: QuestData) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
	for obj in quest.objectives:
		if obj is ItemObjective:
			var current_count: int = inv.get_item_count(obj.item_id)
			if current_count > 0:
				obj.current_amount = mini(current_count, obj.target_amount)
				quest_objective_updated.emit(quest, obj)

func complete_quest(quest_id: String, force: bool = false) -> bool:
	var resolved_id := resolve_quest_id(quest_id)
	var q := get_quest(resolved_id)
	if not q:
		return false
		
	var state := get_quest_state(resolved_id)
	if not force and state != QuestData.QuestState.ACTIVE and state != QuestData.QuestState.READY_TO_TURN_IN:
		return false
		
	# Falls noch als ACTIVE markiert, prüfen ob Objectives fertig sind
	if not force and not q.are_all_objectives_completed():
		_check_inventory_for_quest(q)
		if not q.are_all_objectives_completed():
			return false

	if q.consume_items_on_turn_in:
		_consume_quest_items(q)

	_quest_states[resolved_id] = QuestData.QuestState.COMPLETED
	_grant_rewards(q)
	
	quest_completed.emit(q, q.energy_reward)
	_start_celebration(q)
	
	# Prüfen, ob neue Quests durch den Abschluss freigeschaltet wurden (Auto-Start)
	check_auto_start_quests()
	return true

func force_complete_quest(quest_id: String) -> bool:
	return complete_quest(quest_id, true)

func _grant_rewards(q: QuestData) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if inv:
		if q.energy_reward > 0:
			inv.add_energy(q.energy_reward)
		if q.coin_reward > 0 and inv.has_method("add_coins"):
			inv.call("add_coins", q.coin_reward)
		if not q.reward_item_id.is_empty() and inv.has_method("add_item"):
			var count: int = maxi(q.reward_item_count, 1)
			if inv.has_method("can_add_item") and not inv.can_add_item(q.reward_item_id, count):
				_notify_reward_inventory_full(q.reward_item_id, count)
			else:
				inv.add_item(q.reward_item_id, count)
		# Zusätzliche Dictionary-Belohnungen
		for r_item in q.reward_items.keys():
			var r_count: int = int(q.reward_items[r_item])
			if inv.has_method("can_add_item") and not inv.can_add_item(str(r_item), r_count):
				_notify_reward_inventory_full(str(r_item), r_count)
			else:
				inv.add_item(str(r_item), r_count)

func _notify_reward_inventory_full(item_id: String, _count: int) -> void:
	var tree := get_tree()
	if not tree:
		return
	var hud = tree.root.find_child("HUD", true, false)
	if hud and hud.has_method("show_toast"):
		var inv = get_node_or_null("/root/InventoryManager")
		var item_data = inv.get_item_data(item_id) if inv and inv.has_method("get_item_data") else null
		var item_name: String = item_data.name if item_data else item_id
		hud.show_toast("🎒", "INVENTORY FULL", "No inventory space for quest reward: %s!" % item_name, Color(1.0, 0.4, 0.4))

func _start_celebration(quest: QuestData) -> void:
	quest_celebration_started.emit(quest)
	var tree := get_tree()
	if tree and quest.completion_dance_duration > 0.0:
		await tree.create_timer(quest.completion_dance_duration).timeout
	quest_celebration_ended.emit(quest)

func check_auto_start_quests() -> void:
	for id in _quest_registry.keys():
		var q: QuestData = _quest_registry[id]
		if q.auto_start and get_quest_state(id) == QuestData.QuestState.NOT_STARTED and are_prerequisites_met(q):
			start_quest(id)

# ==========================================
# GETTER & STATUS-ABFRAGEN
# ==========================================

func get_quest(quest_id: String) -> QuestData:
	return _quest_registry.get(resolve_quest_id(quest_id), null)

func has_quest(quest_id: String) -> bool:
	if quest_id.is_empty():
		return false
	return get_quest(quest_id) != null

func get_quest_state(quest_id: String) -> QuestData.QuestState:
	return _quest_states.get(resolve_quest_id(quest_id), QuestData.QuestState.NOT_STARTED)

func is_quest_active(quest_id: String) -> bool:
	var s: QuestData.QuestState = get_quest_state(quest_id)
	return s == QuestData.QuestState.ACTIVE or s == QuestData.QuestState.READY_TO_TURN_IN

func is_quest_ready_to_turn_in(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestData.QuestState.READY_TO_TURN_IN

func is_quest_completed(quest_id: String) -> bool:
	return get_quest_state(quest_id) == QuestData.QuestState.COMPLETED

func _get_active_quests() -> Array[QuestData]:
	var active: Array[QuestData] = []
	for id in _quest_states.keys():
		if is_quest_active(id):
			active.append(_quest_registry[id])
	return active

func get_active_quests() -> Array[QuestData]:
	return _get_active_quests()

func get_all_quests() -> Array[QuestData]:
	var all_q: Array[QuestData] = []
	for q in _quest_registry.values():
		all_q.append(q)
	return all_q

# ==========================================
# VORAUSSETZUNGEN & NPC-DIALOGE
# ==========================================

func are_prerequisites_met(quest: QuestData) -> bool:
	for cond in quest.prerequisites:
		if cond and not cond.is_met(self):
			return false
	return true

func is_quest_available(quest_id: String) -> bool:
	var resolved_id := resolve_quest_id(quest_id)
	var q := get_quest(resolved_id)
	return q != null \
		and get_quest_state(resolved_id) == QuestData.QuestState.NOT_STARTED \
		and are_prerequisites_met(q)

func get_npc_dialogue(npc_id: String) -> Dictionary:
	var quests := _get_quests_of_npc(npc_id)

	# 1. Quest abgeben
	for q in quests:
		if _get_turn_in_npc(q) == npc_id and is_quest_ready_to_turn_in(q.id):
			return {"lines": q.turn_in_dialogue, "on_finished": complete_quest.bind(q.id)}

	# 2. Laufende Quest -> Erinnerung
	for q in quests:
		if q.giver_npc_id == npc_id and is_quest_active(q.id):
			return {"lines": q.reminder_dialogue}

	# 3. Neue, freigeschaltete Quest anbieten
	for q in quests:
		if q.giver_npc_id == npc_id and is_quest_available(q.id):
			return {"lines": q.offer_dialogue, "on_finished": start_quest.bind(q.id)}

	# 4. Zuletzt abgeschlossene Quest dieses NPCs -> Danke-Dialog
	for i in range(quests.size() - 1, -1, -1):
		var q: QuestData = quests[i]
		if q.giver_npc_id == npc_id and is_quest_completed(q.id) and not q.after_dialogue.is_empty():
			return {"lines": q.after_dialogue}

	return {}

func npc_has_quest_to_offer(npc_id: String) -> bool:
	for q in _get_quests_of_npc(npc_id):
		if q.giver_npc_id == npc_id and is_quest_available(q.id):
			return true
	return false

func npc_has_turn_in(npc_id: String) -> bool:
	for q in _get_quests_of_npc(npc_id):
		if _get_turn_in_npc(q) == npc_id and is_quest_ready_to_turn_in(q.id):
			return true
	return false

func _get_turn_in_npc(quest: QuestData) -> String:
	return quest.turn_in_npc_id if not quest.turn_in_npc_id.is_empty() else quest.giver_npc_id

func _get_quests_of_npc(npc_id: String) -> Array[QuestData]:
	var result: Array[QuestData] = []
	for q in _quest_registry.values():
		if q.giver_npc_id == npc_id or q.turn_in_npc_id == npc_id:
			result.append(q)
	result.sort_custom(func(a: QuestData, b: QuestData) -> bool: return a.priority < b.priority)
	return result

func _consume_quest_items(quest: QuestData) -> void:
	var inv = get_node_or_null("/root/InventoryManager")
	if not inv:
		return
	for obj in quest.objectives:
		if obj is ItemObjective and obj.consume_on_turn_in:
			inv.remove_item(obj.item_id, obj.target_amount)
	# Legacy-Support: Einzelnes target_item_id
	if not quest.target_item_id.is_empty() and quest.consume_items_on_turn_in:
		if inv.has_item(quest.target_item_id, quest.target_item_count):
			inv.remove_item(quest.target_item_id, quest.target_item_count)

func get_completed_quest_count() -> int:
	var count := 0
	for s in _quest_states.values():
		if s == QuestData.QuestState.COMPLETED:
			count += 1
	return count

func get_total_quest_count() -> int:
	return _quest_registry.size()

func reset() -> void:
	for id in _quest_registry.keys():
		_quest_states[id] = QuestData.QuestState.NOT_STARTED
		var q: QuestData = _quest_registry[id]
		q.reset_objectives()

# ==========================================
# SAVE / LOAD
# ==========================================

func get_save_data() -> Dictionary:
	var data: Dictionary = {}
	for k in _quest_states.keys():
		data[str(k)] = int(_quest_states[k])
		
	var prog: Dictionary = {}
	for id in _quest_registry.keys():
		var q: QuestData = _quest_registry[id]
		var obj_prog: Array = []
		for obj in q.objectives:
			obj_prog.append(obj.current_amount)
		prog[id] = obj_prog
	data["_progress"] = prog
	return data

func load_save_data(data: Dictionary) -> void:
	reset()
	var states_dict: Dictionary = data.get("states", data)
	for k in states_dict.keys():
		var id := str(k)
		if id.begins_with("_"):
			continue
		if _quest_registry.has(id):
			_quest_states[id] = int(states_dict[k]) as QuestData.QuestState
			
	var prog_dict: Dictionary = data.get("progress", data.get("_progress", {}))
	for id in prog_dict.keys():
		if _quest_registry.has(id):
			var q: QuestData = _quest_registry[id]
			var saved_arr: Array = prog_dict[id]
			for i in range(mini(saved_arr.size(), q.objectives.size())):
				q.objectives[i].current_amount = int(saved_arr[i])
	check_auto_start_quests()
