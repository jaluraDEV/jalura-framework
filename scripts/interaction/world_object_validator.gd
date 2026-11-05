@tool
class_name WorldObjectValidator
extends RefCounted

## Validierungswerkzeug für das modulare Weltobjekt-System und die Weltkarte in Barnaby.
## Überprüft Szenen, Instanzen und das Wegenetz auf häufige Fehlerquellen im Leveldesign:
## - Doppelte object_ids
## - Ungültige oder leere target_objects Pfade
## - Unbekannte item_ids in Truhen, Pickups, Bäumen und Ausgängen
## - Unbekannte quest_ids und flags in Triggern und Bedingungen
## - Fehlende oder inaktive Kollisionen
## - Weltkarten-Validierung: Registry-Integrität, Spawns, Erreichbarkeit, Doku-Sync

static func validate_scene(scene_root: Node) -> Dictionary:
	var result := {
		"valid": true,
		"object_count": 0,
		"errors": [] as Array[String],
		"warnings": [] as Array[String],
		"info": [] as Array[String]
	}

	if not scene_root:
		result["valid"] = false
		result["errors"].append("Szenen-Wurzelknoten ist null!")
		return result

	var objects := _find_all_interactive_objects(scene_root)
	result["object_count"] = objects.size()

	# 1. Eindeutigkeit der object_ids
	var ids_seen := {}
	for obj in objects:
		var oid := obj.object_id
		var obj_path: String = str(obj.get_path()) if obj.is_inside_tree() else String(obj.name)
		if oid.is_empty():
			result["warnings"].append("Objekt '%s' hat eine leere object_id! (Wird zur Laufzeit automatisch generiert)" % obj_path)
		elif ids_seen.has(oid):
			result["errors"].append("Doppelte object_id '%s' gefunden bei '%s' und '%s'!" % [oid, obj_path, ids_seen[oid]])
			result["valid"] = false
		else:
			ids_seen[oid] = obj_path

	# 2. Autoloads für Referenzprüfungen ermitteln
	var tree := scene_root.get_tree() if scene_root.is_inside_tree() else (Engine.get_main_loop() as SceneTree)
	var inv: Node = tree.root.get_node_or_null("InventoryManager") if tree and tree.root else null
	var qm: Node = tree.root.get_node_or_null("QuestManager") if tree and tree.root else null
	var gf: Node = tree.root.get_node_or_null("GameFlags") if tree and tree.root else null

	# 3. Baustein- und Trigger-Prüfungen pro Objekt
	for obj in objects:
		_validate_object(obj, inv, qm, gf, result)

	# 4. Wasser-Zonen Prüfungen (Phase 3)
	_validate_water_zones(scene_root, result)

	if not result["errors"].is_empty():
		result["valid"] = false

	return result

static func _find_all_interactive_objects(node: Node) -> Array[InteractiveObject]:
	var list: Array[InteractiveObject] = []
	if node is InteractiveObject:
		list.append(node)
	for child in node.get_children():
		list.append_array(_find_all_interactive_objects(child))
	return list

static func _find_all_nodes_of_type(node: Node, target_type) -> Array[Node]:
	var list: Array[Node] = []
	if is_instance_of(node, target_type):
		list.append(node)
	for child in node.get_children():
		list.append_array(_find_all_nodes_of_type(child, target_type))
	return list

static func _validate_object(obj: InteractiveObject, inv: Node, qm: Node, gf: Node, result: Dictionary) -> void:
	var obj_path: String = str(obj.get_path()) if obj.is_inside_tree() else String(obj.name)

	# Bausteine vorhanden?
	var behaviors := obj.get_behaviors()
	if behaviors.is_empty():
		result["warnings"].append("Objekt '%s' hat keine ObjectBehavior-Bausteine als Kinder." % obj_path)

	# Falls ObjExit ohne Kind-Behavior genutzt wird
	if obj is ObjExit:
		var oe := obj as ObjExit
		var has_tb := false
		for b in behaviors:
			if b is TransitionBehavior:
				has_tb = true
				break
		if not has_tb:
			if oe.target_scene_id.is_empty():
				result["errors"].append("Ausgang '%s': target_scene_id ist leer!" % obj_path)
				result["valid"] = false
			if oe.is_locked and oe.key_item_id.is_empty() and oe.lock_conditions.is_empty() and not oe.key_item:
				result["warnings"].append("Ausgang '%s' ist verschlossen, hat aber weder key_item noch lock_conditions!" % obj_path)

	# Kollision vorhanden?
	if obj.collision_mode != 0: # Nicht NONE
		var col_shape := obj.find_child("CollisionShape3D", true, false)
		if not col_shape and not obj.find_child("BodyCollider", true, false):
			result["info"].append("Objekt '%s' nutzt automatische Kollisionserzeugung (%d)." % [obj_path, obj.collision_mode])

	# Prüfe einzelne Bausteine
	for b in behaviors:
		# A. ContainerBehavior (Truhen)
		if b is ContainerBehavior:
			var cb := b as ContainerBehavior
			if cb.is_locked and cb.key_item_id.is_empty() and cb.lock_conditions.is_empty():
				result["warnings"].append("Truhe '%s' ist verschlossen, hat aber weder key_item_id noch lock_conditions!" % obj_path)
			if not cb.key_item_id.is_empty() and inv and inv.has_method("get_item_data"):
				if not inv.get_item_data(cb.key_item_id):
					result["warnings"].append("Truhe '%s': key_item_id '%s' ist im InventoryManager unbekannt!" % [obj_path, cb.key_item_id])
			for item in cb.contents:
				var item_id: String = str(item.get("item_id", item.get("id", "")))
				if not item_id.is_empty() and inv and inv.has_method("get_item_data"):
					if not inv.get_item_data(item_id):
						result["warnings"].append("Truhe '%s': Inhalt enthält unbekanntes Item '%s'!" % [obj_path, item_id])

		# B. PickableBehavior (Pickups)
		elif b is PickableBehavior:
			var pb := b as PickableBehavior
			if not pb.item_id.is_empty() and inv and inv.has_method("get_item_data"):
				if not inv.get_item_data(pb.item_id):
					result["warnings"].append("Pickup '%s': item_id '%s' ist im InventoryManager unbekannt!" % [obj_path, pb.item_id])

		# C. ShakeableBehavior (Bäume)
		elif b is ShakeableBehavior:
			var sb := b as ShakeableBehavior
			if not sb.drop_item_id.is_empty() and inv and inv.has_method("get_item_data"):
				if not inv.get_item_data(sb.drop_item_id):
					result["warnings"].append("Schüttelobjekt '%s': drop_item_id '%s' ist im InventoryManager unbekannt!" % [obj_path, sb.drop_item_id])

		# D. DoorBehavior (Türen)
		elif b is DoorBehavior:
			var db := b as DoorBehavior
			if db.is_locked and db.key_item_id.is_empty() and db.lock_conditions.is_empty():
				result["warnings"].append("Tür '%s' ist verschlossen, hat aber weder key_item_id noch lock_conditions!" % obj_path)
			_validate_conditions(db.lock_conditions, obj_path, "Tür", qm, gf, inv, result)
			_validate_conditions(db.auto_open_conditions, obj_path, "Tür (auto_open)", qm, gf, inv, result)

		# E. SwitchBehavior (Hebel / Schalter)
		elif b is SwitchBehavior:
			var sw := b as SwitchBehavior
			for target_path in sw.target_objects:
				var target_node: Node = obj.get_node_or_null(target_path)
				if not target_node:
					target_node = sw.get_node_or_null(target_path)
				if not target_node and obj.get_tree() and obj.get_tree().current_scene:
					target_node = obj.get_tree().current_scene.get_node_or_null(target_path)
				if not target_node and obj.get_tree():
					target_node = obj.get_tree().root.get_node_or_null(target_path)

				if not target_node:
					result["errors"].append("Schalter '%s': target_objects Pfad '%s' existiert nicht!" % [obj_path, str(target_path)])
					result["valid"] = false
				elif not target_node.has_method(sw.target_method) and not (target_node is InteractiveObject and target_node.has_method(sw.target_method)):
					result["warnings"].append("Schalter '%s': Ziel '%s' besitzt Methode '%s' nicht!" % [obj_path, str(target_path), sw.target_method])

		# F. PressurePlateBehavior (Druckplatten)
		elif b is PressurePlateBehavior:
			var ppb := b as PressurePlateBehavior
			for target_path in ppb.target_objects:
				var target_node: Node = obj.get_node_or_null(target_path)
				if not target_node:
					target_node = ppb.get_node_or_null(target_path)
				if not target_node and obj.get_tree() and obj.get_tree().current_scene:
					target_node = obj.get_tree().current_scene.get_node_or_null(target_path)
				if not target_node and obj.get_tree():
					target_node = obj.get_tree().root.get_node_or_null(target_path)

				if not target_node:
					result["errors"].append("Druckplatte '%s': target_objects Pfad '%s' existiert nicht!" % [obj_path, str(target_path)])
					result["valid"] = false

		# G. NPCBehavior (NPCs)
		elif b is NPCBehavior:
			var npcb := b as NPCBehavior
			if not npcb.npc_id.is_empty() and qm and qm.has_method("has_quest_for_npc"):
				pass

		# H. BouncePadBehavior (Sprung-Plattformen & Trampoline)
		elif b is BouncePadBehavior:
			var bpb := b as BouncePadBehavior
			if bpb.bounce_velocity <= 0.0:
				result["warnings"].append("Sprung-Plattform '%s': bounce_velocity sollte > 0 sein (Standard: 16.0)!" % obj_path)
			for target_path in bpb.target_objects:
				var target_node: Node = obj.get_node_or_null(target_path)
				if not target_node:
					target_node = bpb.get_node_or_null(target_path)
				if not target_node and obj.get_tree() and obj.get_tree().current_scene:
					target_node = obj.get_tree().current_scene.get_node_or_null(target_path)
				if not target_node and obj.get_tree():
					target_node = obj.get_tree().root.get_node_or_null(target_path)

				if not target_node:
					result["errors"].append("Sprung-Plattform '%s': target_objects Pfad '%s' existiert nicht!" % [obj_path, str(target_path)])
					result["valid"] = false
				elif not target_node.has_method(bpb.target_method) and not (target_node is InteractiveObject and target_node.has_method(bpb.target_method)):
					result["warnings"].append("Sprung-Plattform '%s': Ziel '%s' besitzt Methode '%s' nicht!" % [obj_path, str(target_path), bpb.target_method])

		# I. TransitionBehavior (Ausgänge / Szenenwechsel)
		elif b is TransitionBehavior:
			var tb := b as TransitionBehavior
			if tb.target_scene_id.is_empty():
				result["errors"].append("Ausgang '%s': target_scene_id ist leer!" % obj_path)
				result["valid"] = false
			else:
				var wm: WorldMap = null
				if ResourceLoader.exists("res://resources/world/world_map.tres"):
					wm = load("res://resources/world/world_map.tres") as WorldMap
				if wm and not wm.has_scene(tb.target_scene_id):
					result["errors"].append("Ausgang '%s': Ziel-Szene '%s' ist nicht in WorldMap registriert!" % [obj_path, str(tb.target_scene_id)])
					result["valid"] = false

			if tb.target_spawn_id.is_empty():
				result["warnings"].append("Ausgang '%s': target_spawn_id ist leer! (Nutzt Fallback-Spawn)" % obj_path)

			if tb.is_locked and tb.key_item_id.is_empty() and tb.lock_conditions.is_empty() and not tb.key_item:
				result["warnings"].append("Ausgang '%s' ist verschlossen, hat aber weder key_item noch lock_conditions!" % obj_path)

			if not tb.key_item_id.is_empty() and inv and inv.has_method("get_item_data"):
				if not inv.get_item_data(tb.key_item_id):
					result["warnings"].append("Ausgang '%s': key_item_id '%s' ist im InventoryManager unbekannt!" % [obj_path, tb.key_item_id])

			_validate_conditions(tb.lock_conditions, obj_path, "Ausgang", qm, gf, inv, result)

	# 4. Trigger & Aktionen prüfen
	for trig in obj.triggers:
		if not trig:
			continue
		if trig.actions.is_empty():
			result["warnings"].append("Objekt '%s': Trigger für Event '%s' hat keine Aktionen!" % [obj_path, trig.event])
		for act in trig.actions:
			if act is ActivateTargetAction:
				var ata := act as ActivateTargetAction
				if not ata.target_path.is_empty():
					var target_node: Node = obj.get_node_or_null(ata.target_path)
					if not target_node and obj.get_tree() and obj.get_tree().current_scene:
						target_node = obj.get_tree().current_scene.get_node_or_null(ata.target_path)
					if not target_node and obj.get_tree():
						target_node = obj.get_tree().root.get_node_or_null(ata.target_path)
					if not target_node:
						result["errors"].append("Objekt '%s': ActivateTargetAction Zielpfad '%s' existiert nicht!" % [obj_path, str(ata.target_path)])
						result["valid"] = false
			elif act is StartQuestAction or act is CompleteQuestAction:
				var q_id: String = act.get("quest_id")
				if not q_id.is_empty() and qm and qm.has_method("has_quest"):
					if not qm.has_quest(q_id):
						result["warnings"].append("Objekt '%s': Quest-Aktion verweist auf unbekannte Quest '%s'!" % [obj_path, q_id])
			elif act is SetFlagAction:
				var sfa := act as SetFlagAction
				if sfa.flag_id.is_empty():
					result["warnings"].append("Objekt '%s': SetFlagAction hat eine leere flag_id!" % obj_path)

static func _validate_conditions(conditions: Array[QuestCondition], obj_path: String, prefix: String, qm: Node, gf: Node, inv: Node, result: Dictionary) -> void:
	for cond in conditions:
		if not cond:
			continue
		if cond is ItemCondition:
			var ic := cond as ItemCondition
			if not ic.item_id.is_empty() and inv and inv.has_method("get_item_data"):
				if not inv.get_item_data(ic.item_id):
					result["warnings"].append("%s '%s': ItemCondition verweist auf unbekanntes Item '%s'!" % [prefix, obj_path, ic.item_id])
		elif cond is FlagCondition:
			var fc := cond as FlagCondition
			if fc.flag_id.is_empty():
				result["warnings"].append("%s '%s': FlagCondition hat eine leere flag_id!" % [prefix, obj_path])
			elif gf and gf.has_method("has_flag"):
				if not gf.has_flag(fc.flag_id):
					result["info"].append("%s '%s': FlagCondition prüft Flag '%s'." % [prefix, obj_path, fc.flag_id])
		elif cond is CompositeCondition:
			var cc := cond as CompositeCondition
			_validate_conditions(cc.conditions, obj_path, "%s (Composite)" % prefix, qm, gf, inv, result)
		else:
			var q_id: String = str(cond.get("quest_id"))
			if not q_id.is_empty() and qm and qm.has_method("has_quest"):
				if not qm.has_quest(q_id):
					result["warnings"].append("%s '%s': QuestCondition verweist auf unbekannte Quest '%s'!" % [prefix, obj_path, q_id])

## Validiert die gesamte Weltkarte, alle registrierten Szenen, Spawns, Verbindungen und Graph-Erreichbarkeit.
static func validate_world_map(world_map: WorldMap = null) -> Dictionary:
	var result := {
		"valid": true,
		"scene_count": 0,
		"connection_count": 0,
		"errors": [] as Array[String],
		"warnings": [] as Array[String],
		"info": [] as Array[String]
	}

	if not world_map:
		if ResourceLoader.exists("res://resources/world/world_map.tres"):
			world_map = load("res://resources/world/world_map.tres") as WorldMap
		else:
			result["valid"] = false
			result["errors"].append("Keine WorldMap angegeben und 'res://resources/world/world_map.tres' existiert nicht!")
			return result

	if not world_map:
		result["valid"] = false
		result["errors"].append("WorldMap konnte nicht geladen werden!")
		return result

	var entries := world_map.scenes
	result["scene_count"] = entries.size()

	# 1. Start-Scene Prüfung
	if world_map.start_scene_id.is_empty():
		result["warnings"].append("WorldMap: start_scene_id ist nicht gesetzt!")
	elif not world_map.has_scene(world_map.start_scene_id):
		result["errors"].append("WorldMap: start_scene_id '%s' ist nicht in den Szenen registriert!" % str(world_map.start_scene_id))
		result["valid"] = false

	# 2. Eindeutigkeit der scene_ids & Datei-Existenz
	var seen_ids := {}
	for entry in entries:
		if not entry:
			result["warnings"].append("WorldMap: Ein Eintrag ist null!")
			continue
		var sid := str(entry.scene_id)
		if sid.is_empty():
			result["errors"].append("WorldMap: Eintrag mit leerer scene_id gefunden!")
			result["valid"] = false
			continue
		if seen_ids.has(sid):
			result["errors"].append("WorldMap: Doppelte scene_id '%s' gefunden!" % sid)
			result["valid"] = false
		else:
			seen_ids[sid] = entry.scene_path

		if entry.scene_path.is_empty():
			result["errors"].append("WorldMap: Szene '%s' hat keinen scene_path!" % sid)
			result["valid"] = false
		elif not ResourceLoader.exists(entry.scene_path) and not FileAccess.file_exists(entry.scene_path):
			result["errors"].append("WorldMap: Szene '%s' Datei existiert nicht: '%s'!" % [sid, entry.scene_path])
			result["valid"] = false

	# 3. Szenen instanziieren, Spawns & Exits erfassen
	var scene_spawns := {}
	var scene_exits := {}
	var instanced_scenes := {}

	for entry in entries:
		if not entry or entry.scene_id.is_empty() or entry.scene_path.is_empty():
			continue
		var sid: StringName = entry.scene_id
		scene_spawns[sid] = [] as Array[StringName]
		scene_exits[sid] = [] as Array[Dictionary]

		if not ResourceLoader.exists(entry.scene_path) and not FileAccess.file_exists(entry.scene_path):
			continue

		var packed := load(entry.scene_path) as PackedScene
		if not packed:
			result["errors"].append("WorldMap: Szene '%s' konnte nicht als PackedScene geladen werden: '%s'!" % [str(sid), entry.scene_path])
			result["valid"] = false
			continue

		var inst = packed.instantiate()
		if not inst:
			result["errors"].append("WorldMap: Szene '%s' konnte nicht instanziiert werden!" % str(sid))
			result["valid"] = false
			continue

		instanced_scenes[sid] = inst

		# Spawns erfassen
		var spawn_nodes := _find_all_nodes_of_type(inst, SpawnPoint)
		for sp in spawn_nodes:
			var sp_point := sp as SpawnPoint
			if not sp_point.spawn_id.is_empty():
				scene_spawns[sid].append(sp_point.spawn_id)

		# Wenn keine SpawnPoint-Nodes mit spawn_id da sind, nach Standard-Spawn suchen
		if scene_spawns[sid].is_empty():
			var default_sp = inst.find_child("SpawnPoint", true, false)
			if default_sp:
				scene_spawns[sid].append(&"SpawnPoint")
			else:
				result["warnings"].append("Szene '%s' (%s) hat keine erkennbaren SpawnPoints!" % [str(sid), entry.scene_path])

		# Exits erfassen: A) TransitionBehavior an InteractiveObjects
		var interactive_objs := _find_all_interactive_objects(inst)
		for iobj in interactive_objs:
			for b in iobj.get_behaviors():
				if b is TransitionBehavior:
					var tb := b as TransitionBehavior
					scene_exits[sid].append({
						"target_scene_id": tb.target_scene_id,
						"target_spawn_id": tb.target_spawn_id,
						"obj_name": iobj.name,
						"is_locked": tb.is_locked,
						"lock_conditions": tb.lock_conditions
					})
					result["connection_count"] += 1

		# Exits erfassen: B) Legacy DoorTrigger3D oder Nodes mit target_scene_path
		var all_children := inst.find_children("*", "Area3D", true, false)
		for child in all_children:
			var target_path = child.get("target_scene_path")
			if target_path != null and not str(target_path).is_empty():
				var target_sid := world_map.find_scene_id_by_path(str(target_path))
				var raw_sp = child.get("target_spawn_id")
				var target_sp := StringName("")
				if raw_sp != null and not str(raw_sp).is_empty() and str(raw_sp) != "<null>":
					target_sp = StringName(str(raw_sp))
				scene_exits[sid].append({
					"target_scene_id": target_sid,
					"target_spawn_id": target_sp,
					"obj_name": child.name,
					"is_locked": false,
					"lock_conditions": []
				})
				result["connection_count"] += 1

	# 4. Exits validieren (Ziel-Szene & Ziel-Spawn)
	for from_sid in scene_exits:
		for exit_info in scene_exits[from_sid]:
			var to_sid: StringName = exit_info["target_scene_id"]
			var to_spawn: StringName = exit_info["target_spawn_id"]

			if to_sid.is_empty():
				result["errors"].append("Szene '%s' Objekt '%s': Ziel-Szene ist leer!" % [str(from_sid), exit_info["obj_name"]])
				result["valid"] = false
				continue

			if not world_map.has_scene(to_sid):
				result["errors"].append("Szene '%s' Objekt '%s': Ziel-Szene '%s' ist nicht in der WorldMap registriert!" % [str(from_sid), exit_info["obj_name"], str(to_sid)])
				result["valid"] = false
			else:
				# Prüfe Ziel-Spawn
				if not to_spawn.is_empty() and str(to_spawn) != "<null>" and scene_spawns.has(to_sid):
					var spawns: Array = scene_spawns[to_sid]
					if not spawns.has(to_spawn):
						result["warnings"].append("Szene '%s' Objekt '%s': Ziel-Spawn '%s' existiert in Ziel-Szene '%s' nicht!" % [str(from_sid), exit_info["obj_name"], str(to_spawn), str(to_sid)])

	# 5. Gegenstück-Prüfung (Hinweis bei einseitigen Verbindungen)
	for from_sid in scene_exits:
		for exit_info in scene_exits[from_sid]:
			var to_sid: StringName = exit_info["target_scene_id"]
			if not scene_exits.has(to_sid):
				continue
			var has_return := false
			for return_exit in scene_exits[to_sid]:
				if return_exit["target_scene_id"] == from_sid:
					has_return = true
					break
			if not has_return:
				result["info"].append("Einseitige Verbindung: '%s' -> '%s' hat kein direktes Gegenstück in '%s' (erlaubt)." % [str(from_sid), str(to_sid), str(to_sid)])

	# 6. Graph-Erreichbarkeitsprüfung von start_scene_id aus
	var start_sid := world_map.start_scene_id
	if world_map.has_scene(start_sid):
		var reachable := {}
		var queue: Array[StringName] = [start_sid]
		reachable[start_sid] = true

		while not queue.is_empty():
			var curr: StringName = queue.pop_front()
			if scene_exits.has(curr):
				for exit_info in scene_exits[curr]:
					var nxt: StringName = exit_info["target_scene_id"]
					if world_map.has_scene(nxt) and not reachable.has(nxt):
						reachable[nxt] = true
						queue.append(nxt)

		for entry in world_map.get_game_entries():
			var sid: StringName = entry.scene_id
			if not reachable.has(sid):
				result["warnings"].append("Szene '%s' ist von start_scene_id '%s' aus über das Wegenetz unerreichbar!" % [str(sid), str(start_sid)])

	# 7. Doku-Konsistenzprüfung (docs/world_map.md)
	if FileAccess.file_exists("res://docs/world_map.md"):
		var doc_file := FileAccess.open("res://docs/world_map.md", FileAccess.READ)
		if doc_file:
			var doc_text := doc_file.get_as_text()
			for entry in world_map.get_game_entries():
				if not doc_text.contains(str(entry.scene_id)):
					result["warnings"].append("Doku-Abweichung: Szene '%s' wird in 'docs/world_map.md' nicht erwähnt!" % str(entry.scene_id))

	# Cleanup Memory der instanziierten Szenen
	for sid in instanced_scenes:
		var n: Node = instanced_scenes[sid]
		if is_instance_valid(n):
			n.free()

	if not result["errors"].is_empty():
		result["valid"] = false

	return result

## Führt eine Gesamtvalidierung über die Weltkarte und alle enthaltenen Szenen durch.
static func validate_all(world_map: WorldMap = null) -> Dictionary:
	var map_result := validate_world_map(world_map)
	if not world_map and ResourceLoader.exists("res://resources/world/world_map.tres"):
		world_map = load("res://resources/world/world_map.tres") as WorldMap

	if world_map:
		for entry in world_map.get_game_entries():
			if not entry.scene_path.is_empty() and ResourceLoader.exists(entry.scene_path):
				var packed := load(entry.scene_path) as PackedScene
				if packed:
					var inst := packed.instantiate()
					if inst:
						var scene_res := validate_scene(inst)
						for err in scene_res["errors"]:
							map_result["errors"].append("[%s] %s" % [entry.scene_id, err])
						for wrn in scene_res["warnings"]:
							map_result["warnings"].append("[%s] %s" % [entry.scene_id, wrn])
						for inf in scene_res["info"]:
							map_result["info"].append("[%s] %s" % [entry.scene_id, inf])
						if not scene_res["valid"]:
							map_result["valid"] = false
						inst.free()

	return map_result

const WaterZoneClass = preload("res://scripts/interaction/water_zone.gd")

static func _validate_water_zones(scene_root: Node, result: Dictionary) -> void:
	var water_zones := _find_all_water_zones(scene_root)
	var names_seen := {}

	for zone in water_zones:
		var zname: String = zone.zone_name.strip_edges()
		var zpath: String = str(zone.get_path()) if zone.is_inside_tree() else String(zone.name)

		# 1. Name prüfen & Dopplungen verhindern
		if zname.is_empty():
			result["warnings"].append("WaterZone '%s' hat einen leeren zone_name!" % zpath)
		elif names_seen.has(zname):
			result["errors"].append("Doppelter WaterZone-Name '%s' bei '%s' und '%s'!" % [zname, zpath, names_seen[zname]])
			result["valid"] = false
		else:
			names_seen[zname] = zpath

		# 2. Größe prüfen (muss positiv und > 0 sein)
		if zone.size.x <= 0.0 or zone.size.y <= 0.0:
			result["errors"].append("WaterZone '%s' hat keine gültige Größe: %s (Größe muss > 0 sein)!" % [zpath, zone.size])
			result["valid"] = false

		# 3. Respawn-Prüfung
		if zone.respawn_mode == WaterZoneClass.RespawnMode.FIXED_SPAWN_POINT:
			var target_pos: Vector3 = zone.get_respawn_position()
			if not is_instance_valid(zone.fixed_respawn_point) and zone.fixed_respawn_position == Vector3.ZERO:
				result["errors"].append("WaterZone '%s' nutzt FIXED_SPAWN_POINT, hat aber weder fixed_respawn_point noch fixed_respawn_position zugewiesen!" % zpath)
				result["valid"] = false
			elif target_pos.y <= zone.get_surface_y():
				result["warnings"].append("WaterZone '%s': Fester Respawn-Punkt liegt auf oder unter der Wasseroberfläche (Y=%.2f <= Surface=%.2f)!" % [zpath, target_pos.y, zone.get_surface_y()])

static func _find_all_water_zones(node: Node) -> Array:
	var list: Array = []
	if is_instance_of(node, WaterZoneClass):
		list.append(node)
	for child in node.get_children():
		list.append_array(_find_all_water_zones(child))
	return list
