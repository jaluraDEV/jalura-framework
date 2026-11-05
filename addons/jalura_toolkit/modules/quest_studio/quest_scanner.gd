@tool
class_name JaluraQuestScanner
extends RefCounted

## Scanner und Daten-Hilfsklasse für das Jalura Quest Studio.
## Liest alle Quests (.tres) aus res://resources/quests/ aus,
## scannt verfügbare Items und sammelt bekannte NPCs.

const QUESTS_DIR: String = "res://resources/quests"
const ITEMS_DIR: String = "res://resources/items"
const QuestDataScript = preload("res://scripts/data/quest_data.gd")
const ItemDataScript = preload("res://scripts/data/item_data.gd")


## Scannt alle Quests im Projekt und gibt ein Array von Quest-Info-Dictionaries zurück
static func scan_all_quests() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	_scan_quests_recursive(QUESTS_DIR, results)
	
	# Sortieren: Zuerst nach Kategorie (Hauptquest -> Nebenquest -> Geheimnis), dann nach Priorität / ID
	results.sort_custom(func(a, b):
		if a["category"] != b["category"]:
			return a["category"] < b["category"]
		if a["priority"] != b["priority"]:
			return a["priority"] < b["priority"]
		return a["id"] < b["id"]
	)
	
	return results


static func _scan_quests_recursive(dir_path: String, out_results: Array[Dictionary]) -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		return

	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_quests_recursive(dir_path.path_join(file_name), out_results)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path := dir_path.path_join(file_name)
			var res := ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REUSE)
			if res is QuestData:
				var qd := res as QuestData
				out_results.append(_create_quest_info(qd, full_path))
		file_name = dir.get_next()


static func _create_quest_info(qd: QuestData, file_path: String) -> Dictionary:
	var q_id := qd.id
	if q_id.is_empty():
		q_id = file_path.get_file().get_basename()

	var q_title := qd.title
	if q_title.is_empty():
		q_title = q_id.replace("_", " ").capitalize()

	var cat_name := "Side Quest"
	var cat_icon := "⚓"
	match qd.category:
		QuestData.QuestCategory.MAIN:
			cat_name = "Main Quest"
			cat_icon = "🏆"
		QuestData.QuestCategory.DISCOVERY:
			cat_name = "Secret / Discovery"
			cat_icon = "🔍"

	# Belohnungs-Zusammenfassung
	var reward_parts: Array[String] = []
	if qd.coin_reward > 0:
		reward_parts.append("🪙 %d" % qd.coin_reward)
	if qd.energy_reward > 0:
		reward_parts.append("⚡ %d" % qd.energy_reward)
	if not qd.reward_item_id.is_empty():
		reward_parts.append("🎁 %s" % qd.reward_item_id)
	for it_id in qd.reward_items.keys():
		reward_parts.append("🎁 %s" % it_id)

	var reward_summary := " • ".join(reward_parts)
	if reward_summary.is_empty():
		reward_summary = "No Reward"

	# Voraussetzungen Zusammenfassung
	var prereq_ids: Array[String] = []
	for pr in qd.prerequisites:
		var q_req = pr.get("quest_id")
		if q_req != null and not str(q_req).is_empty():
			prereq_ids.append(str(q_req))
		elif pr is QuestCondition:
			prereq_ids.append(pr.get_class())

	return {
		"file_path": file_path,
		"id": q_id,
		"title": q_title,
		"description": qd.description,
		"category": qd.category,
		"category_name": cat_name,
		"category_icon": cat_icon,
		"giver_npc_id": qd.giver_npc_id,
		"turn_in_npc_id": qd.turn_in_npc_id if not qd.turn_in_npc_id.is_empty() else qd.giver_npc_id,
		"priority": qd.priority,
		"objectives_count": qd.objectives.size(),
		"prerequisites_count": qd.prerequisites.size(),
		"prerequisites": prereq_ids,
		"reward_summary": reward_summary,
		"coin_reward": qd.coin_reward,
		"energy_reward": qd.energy_reward,
		"reward_item_id": qd.reward_item_id,
		"sequential_objectives": qd.sequential_objectives,
		"quest_data": qd
	}


## Scannt alle verfügbaren Items aus res://resources/items/
static func scan_all_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(ITEMS_DIR) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ITEMS_DIR)):
		return items

	var dir := DirAccess.open(ITEMS_DIR)
	if not dir:
		dir = DirAccess.open(ProjectSettings.globalize_path(ITEMS_DIR))
	if not dir:
		return items

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var full_path := ITEMS_DIR.path_join(file_name)
			var base_name := file_name.get_basename()
			var it_id := base_name
			var it_name := base_name.capitalize()
			var it_cat := "Gegenstand"
			var it_icon: Texture2D = null

			var res := ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REUSE)
			if res != null:
				var rid = res.get("id")
				if rid != null and not str(rid).is_empty():
					it_id = str(rid)
				var rname = res.get("name")
				if rname != null and not str(rname).is_empty():
					it_name = str(rname)
				if res.has_method("get_category_name"):
					it_cat = res.call("get_category_name")
				var ricon = res.get("icon")
				if ricon is Texture2D:
					it_icon = ricon

			items.append({
				"id": it_id,
				"name": it_name,
				"category": it_cat,
				"file_path": full_path,
				"icon": it_icon
			})
		file_name = dir.get_next()

	items.sort_custom(func(a, b): return a["name"] < b["name"])
	return items


## Ermittelt bekannte NPCs aus existierenden Quests und Szenen
static func get_known_npcs() -> Array[String]:
	var npcs: Dictionary = {
		"grantelbart": true,
		"hildegard": true
	}

	# Quests scannen
	var quests := scan_all_quests()
	for q in quests:
		var g: String = q.get("giver_npc_id", "")
		if not g.is_empty():
			npcs[g] = true
		var t: String = q.get("turn_in_npc_id", "")
		if not t.is_empty():
			npcs[t] = true

	var npc_list: Array[String] = []
	for k in npcs.keys():
		npc_list.append(k)
	npc_list.sort()
	return npc_list
