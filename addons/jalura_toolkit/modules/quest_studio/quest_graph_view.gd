@tool
class_name JaluraQuestGraphView
extends VBoxContainer

## Visueller Quest-Abhängigkeitsgraph & Flowchart-Editor für das Jalura Studio.
## Zeigt alle Quests als interaktive GraphNodes, visualisiert Voraussetzungen als Verbindungslinien,
## prüft automatisch auf fehlende Quest-IDs oder Zyklen und erlaubt 1-Klick-Öffnen im Editor.

const Scanner = preload("res://addons/jalura_toolkit/modules/quest_studio/quest_scanner.gd")
const QuestCompletedConditionScript = preload("res://scripts/data/quest_completed_condition.gd")
const LAYOUT_PATH = "res://resources/quests/quest_graph_layout.json"

signal open_quest_requested(quest_info: Dictionary)
signal delete_quest_requested(quest_info: Dictionary)

var graph_edit: GraphEdit
var search_edit: LineEdit
var status_label: Label
var btn_filter_all: Button
var btn_filter_main: Button
var btn_filter_side: Button
var btn_filter_discovery: Button

# Daten
var _all_quests: Array[Dictionary] = []
var _node_map: Dictionary = {} # quest_id -> GraphNode
var _info_map: Dictionary = {} # quest_id -> quest_info
var _saved_layout: Dictionary = {}
var _current_filter_cat: int = -1


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


var _ui_setup := false


func _ready() -> void:
	if not _ui_setup:
		_setup_ui()
	load_and_build_graph()


func _setup_ui() -> void:
	_ui_setup = true
	# 1. Top Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "🕸️ Jalura Quest Dependency Graph"
	title_lbl.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(title_lbl)

	toolbar.add_child(VSeparator.new())

	# Suchfeld
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔍 Filter quests by title, ID or NPC..."
	search_edit.custom_minimum_size = Vector2(240, 0)
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_edit)

	# Filter-Buttons
	btn_filter_all = Button.new()
	btn_filter_all.text = "Alle"
	btn_filter_all.pressed.connect(func(): _set_category_filter(-1))
	toolbar.add_child(btn_filter_all)

	btn_filter_main = Button.new()
	btn_filter_main.text = "🏆 Main Quests"
	btn_filter_main.pressed.connect(func(): _set_category_filter(0))
	toolbar.add_child(btn_filter_main)

	btn_filter_side = Button.new()
	btn_filter_side.text = "⚓ Side Quests"
	btn_filter_side.pressed.connect(func(): _set_category_filter(1))
	toolbar.add_child(btn_filter_side)

	btn_filter_discovery = Button.new()
	btn_filter_discovery.text = "🔍 Geheimnisse"
	btn_filter_discovery.pressed.connect(func(): _set_category_filter(2))
	toolbar.add_child(btn_filter_discovery)

	toolbar.add_child(VSeparator.new())

	# Action Buttons
	var btn_auto := Button.new()
	btn_auto.text = "📐 Auto-Layout"
	btn_auto.tooltip_text = "Arranges quests hierarchically from left to right by dependency tier"
	btn_auto.pressed.connect(_apply_auto_layout)
	toolbar.add_child(btn_auto)

	var btn_save := Button.new()
	btn_save.text = "💾 Save Layout"
	btn_save.tooltip_text = "Saves current quest node layout persistently to disk"
	btn_save.pressed.connect(save_current_layout)
	toolbar.add_child(btn_save)

	var btn_reload := Button.new()
	btn_reload.text = "🔄 Reload"
	btn_reload.tooltip_text = "Reloads all quests and dependencies freshly from disk"
	btn_reload.pressed.connect(load_and_build_graph)
	toolbar.add_child(btn_reload)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	status_label = Label.new()
	status_label.text = "Bereit"
	status_label.modulate = Color(0.4, 0.8, 1.0)
	status_label.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(status_label)

	add_child(HSeparator.new())

	# 2. GraphEdit
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.end_node_move.connect(_on_end_node_move)

	add_child(graph_edit)


## Lädt alle Quests und baut den Abhängigkeits-Graphen auf
func load_and_build_graph() -> void:
	if not _ui_setup:
		_setup_ui()
	if not graph_edit:
		return

	_node_map.clear()
	_info_map.clear()
	graph_edit.clear_connections()

	# Bestehende Knoten aufräumen
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()

	_load_layout_file()
	_all_quests = Scanner.scan_all_quests()

	# ID-Lookup füllen
	for q in _all_quests:
		_info_map[q["id"]] = q
		# Fallback für Dateinamen ohne "q_"
		var f_base: String = q["file_path"].get_file().get_basename()
		_info_map[f_base] = q
		_info_map[f_base.trim_prefix("q_")] = q

	# GraphNodes erzeugen
	var issues_found := 0
	for q in _all_quests:
		var gnode := _create_quest_graph_node(q)
		_node_map[q["id"]] = gnode
		_node_map[q["file_path"].get_file().get_basename()] = gnode
		graph_edit.add_child(gnode)

	# Verbindungen ziehen
	issues_found += _build_connections()

	# Statusmeldung aktualisieren
	if issues_found > 0:
		status_label.text = "⚠️ %d issue(s) detected in quest graph!" % issues_found
		status_label.modulate = Color(1.0, 0.45, 0.2)
	else:
		status_label.text = "✅ All %d quests & dependencies intact!" % _all_quests.size()
		status_label.modulate = Color(0.4, 1.2, 0.5)

	# Falls noch kein Layout gespeichert wurde, Auto-Layout anwenden
	if _saved_layout.is_empty():
		_apply_auto_layout()


func _create_quest_graph_node(q: Dictionary) -> GraphNode:
	var gnode := GraphNode.new()
	gnode.name = "Node_" + q["id"]
	gnode.title = "%s %s" % [q["category_icon"], q["title"]]
	gnode.resizable = false
	gnode.custom_minimum_size = Vector2(260, 0)
	gnode.set_meta("quest_id", q["id"])
	gnode.set_meta("file_path", q["file_path"])

	# Position wiederherstellen
	var q_id: String = q["id"]
	if _saved_layout.has(q_id):
		var pos_dict: Dictionary = _saved_layout[q_id]
		gnode.position_offset = Vector2(pos_dict.get("x", 80), pos_dict.get("y", 100))
	else:
		gnode.position_offset = Vector2(80 + (_node_map.size() % 4) * 320, 100 + (_node_map.size() / 4) * 240)

	# Slot 0: Header & I/O Ports
	# Links = Input (Prerequisites), Rechts = Output (Unlocks)
	var slot_col_left := Color(0.3, 0.7, 1.0)
	var slot_col_right := Color(1.0, 0.8, 0.2)
	gnode.set_slot(0, true, 0, slot_col_left, true, 0, slot_col_right)

	var io_row := HBoxContainer.new()
	var in_lbl := Label.new()
	in_lbl.text = "🔗 Requires"
	in_lbl.modulate = Color(0.4, 0.8, 1.0)
	in_lbl.add_theme_font_size_override("font_size", 10)
	io_row.add_child(in_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	io_row.add_child(spacer)

	var out_lbl := Label.new()
	out_lbl.text = "Next Quest 🚀"
	out_lbl.modulate = Color(1.0, 0.85, 0.3)
	out_lbl.add_theme_font_size_override("font_size", 10)
	io_row.add_child(out_lbl)
	gnode.add_child(io_row)

	# Slot 1: Quest-Details
	var details_vbox := VBoxContainer.new()
	details_vbox.add_theme_constant_override("separation", 3)

	var id_lbl := Label.new()
	id_lbl.text = "ID: %s • Prio %d" % [q["id"], q["priority"]]
	id_lbl.modulate = Color(0.65, 0.75, 0.85)
	id_lbl.add_theme_font_size_override("font_size", 10)
	details_vbox.add_child(id_lbl)

	var giver_lbl := Label.new()
	giver_lbl.text = "🗣️ NPC: %s ➔ 🎯 %s" % [q["giver_npc_id"].capitalize(), q["turn_in_npc_id"].capitalize()]
	giver_lbl.add_theme_font_size_override("font_size", 11)
	details_vbox.add_child(giver_lbl)

	var obj_lbl := Label.new()
	obj_lbl.text = "🎯 %d Aufgaben (Objectives)" % q["objectives_count"]
	obj_lbl.add_theme_font_size_override("font_size", 11)
	details_vbox.add_child(obj_lbl)

	var rew_lbl := Label.new()
	rew_lbl.text = "🎁 %s" % q["reward_summary"]
	rew_lbl.modulate = Color(0.4, 1.1, 0.6)
	rew_lbl.add_theme_font_size_override("font_size", 11)
	rew_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	details_vbox.add_child(rew_lbl)

	# Diagnosen & Warnungen prüfen
	var prereqs: Array = q.get("prerequisites", [])
	for p_id in prereqs:
		var p_str: String = str(p_id)
		if not _info_map.has(p_str) and not _info_map.has(p_str.trim_prefix("q_")):
			var warn_lbl := Label.new()
			warn_lbl.text = "⚠️ Unbekannte Voraussetzung: '%s'" % p_str
			warn_lbl.modulate = Color(1.0, 0.35, 0.35)
			warn_lbl.add_theme_font_size_override("font_size", 10)
			details_vbox.add_child(warn_lbl)

	# Buttons zum Öffnen im Editor & Löschen
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	var btn_edit := Button.new()
	btn_edit.text = "📝 Editor"
	btn_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_edit.custom_minimum_size = Vector2(0, 26)
	btn_edit.pressed.connect(func(): open_quest_requested.emit(q))
	btn_row.add_child(btn_edit)

	var btn_del := Button.new()
	btn_del.text = "🗑️"
	btn_del.tooltip_text = "Deletes this quest from the project"
	btn_del.modulate = Color(1.2, 0.45, 0.45)
	btn_del.pressed.connect(func(): delete_quest_requested.emit(q))
	btn_row.add_child(btn_del)

	details_vbox.add_child(btn_row)

	gnode.add_child(details_vbox)
	gnode.set_slot(1, false, 0, Color.WHITE, false, 0, Color.WHITE)

	return gnode


## Zieht alle Verbindungslinien basierend auf den Quest-Voraussetzungen
func _build_connections() -> int:
	var broken_count := 0
	for q in _all_quests:
		var target_id: String = q["id"]
		var dst_node: GraphNode = _node_map.get(target_id, null)
		if not is_instance_valid(dst_node):
			continue

		var prereqs: Array = q.get("prerequisites", [])
		for req_id in prereqs:
			var req_str: String = str(req_id)
			var src_node: GraphNode = _node_map.get(req_str, null)
			if not src_node:
				src_node = _node_map.get(req_str.trim_prefix("q_"), null)
			if not src_node:
				src_node = _node_map.get("q_" + req_str, null)

			if is_instance_valid(src_node):
				# Verbinde Ausgang (Port 0) von src mit Eingang (Port 0) von dst
				graph_edit.connect_node(src_node.name, 0, dst_node.name, 0)
			else:
				broken_count += 1

	return broken_count


## Verbindung im Graph gezogen: Neue Voraussetzung zur Zielquest hinzufügen!
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node := graph_edit.get_node_or_null(NodePath(str(from_node))) as GraphNode
	var dst_node := graph_edit.get_node_or_null(NodePath(str(to_node))) as GraphNode

	if not src_node or not dst_node or src_node == dst_node:
		return

	var src_id: String = src_node.get_meta("quest_id", "")
	var dst_id: String = dst_node.get_meta("quest_id", "")
	var dst_path: String = dst_node.get_meta("file_path", "")

	if src_id.is_empty() or dst_id.is_empty():
		return

	# Zyklen verhindern (z.B. A -> B -> A)
	if _would_create_cycle(src_id, dst_id):
		status_label.text = "❌ Connection rejected: Cyclic dependency detected!"
		status_label.modulate = Color(1.0, 0.35, 0.35)
		return

	# Quest-Ressource des Ziels laden und Voraussetzung hinzufügen
	var dst_qd = ResourceLoader.load(dst_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not dst_qd:
		return

	# Prüfen, ob Voraussetzung bereits existiert
	var exists := false
	for cond in dst_qd.prerequisites:
		if cond is QuestCompletedConditionScript and (cond as QuestCompletedConditionScript).quest_id == src_id:
			exists = true
			break

	if not exists:
		var new_cond = QuestCompletedConditionScript.new()
		new_cond.quest_id = src_id
		dst_qd.prerequisites.append(new_cond)
		var err := ResourceSaver.save(dst_qd, dst_path)
		if err == OK:
			graph_edit.connect_node(from_node, from_port, to_node, to_port)
			status_label.text = "✔ Prerequisite linked: '%s' unlocks '%s'!" % [src_id, dst_id]
			status_label.modulate = Color(0.3, 1.2, 0.5)
			print_rich("[color=green][b]✔ [Quest Graph][/b][/color] Prerequisite linked: [b]%s[/b] ➔ [b]%s[/b]" % [src_id, dst_id])
			_refresh_internal_data()


## Verbindung im Graph gelöst: Voraussetzung entfernen!
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node := graph_edit.get_node_or_null(NodePath(str(from_node))) as GraphNode
	var dst_node := graph_edit.get_node_or_null(NodePath(str(to_node))) as GraphNode

	if not src_node or not dst_node:
		return

	var src_id: String = src_node.get_meta("quest_id", "")
	var dst_id: String = dst_node.get_meta("quest_id", "")
	var dst_path: String = dst_node.get_meta("file_path", "")

	var dst_qd = ResourceLoader.load(dst_path, "", ResourceLoader.CACHE_MODE_REUSE)
	if not dst_qd:
		return

	var removed := false
	for i in range(dst_qd.prerequisites.size() - 1, -1, -1):
		var cond = dst_qd.prerequisites[i]
		if cond is QuestCompletedConditionScript:
			var c_id: String = (cond as QuestCompletedConditionScript).quest_id
			if c_id == src_id or c_id.trim_prefix("q_") == src_id.trim_prefix("q_"):
				dst_qd.prerequisites.remove_at(i)
				removed = true

	if removed:
		ResourceSaver.save(dst_qd, dst_path)
		graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
		status_label.text = "✔ Link between '%s' and '%s' removed." % [src_id, dst_id]
		status_label.modulate = Color(0.9, 0.8, 0.4)
		_refresh_internal_data()


## Prüft, ob das Hinzufügen einer Kante von src nach dst einen Zyklus erzeugen würde
func _would_create_cycle(src_id: String, dst_id: String) -> bool:
	if src_id == dst_id or src_id.trim_prefix("q_") == dst_id.trim_prefix("q_"):
		return true

	var visited: Dictionary = {}
	var queue: Array[String] = [src_id]

	while not queue.is_empty():
		var curr: String = queue.pop_front()
		var curr_clean: String = curr.trim_prefix("q_")
		if curr_clean == dst_id.trim_prefix("q_"):
			return true
		visited[curr_clean] = true

		# Suche nach allen Quests, die Voraussetzung von curr sind:
		for q in _all_quests:
			if q["id"].trim_prefix("q_") == curr_clean or q["file_path"].get_file().get_basename().trim_prefix("q_") == curr_clean:
				for p_id in q.get("prerequisites", []):
					var p_clean: String = str(p_id).trim_prefix("q_")
					if not visited.has(p_clean):
						queue.append(p_clean)

	return false


func _refresh_internal_data() -> void:
	_all_quests = Scanner.scan_all_quests()
	for q in _all_quests:
		_info_map[q["id"]] = q


## Knoten wurde verschoben: Layout speichern
func _on_end_node_move() -> void:
	for q_id in _node_map:
		var gnode: GraphNode = _node_map[q_id]
		if is_instance_valid(gnode):
			var clean_id: String = gnode.get_meta("quest_id", q_id)
			_saved_layout[clean_id] = {
				"x": int(gnode.position_offset.x),
				"y": int(gnode.position_offset.y)
			}


## Auto-Layout: Berechnet hierarchische Ebenen (Tiers) basierend auf Abhängigkeiten
func _apply_auto_layout() -> void:
	if _all_quests.is_empty():
		return

	# 1. Tiefenlevel für jede Quest ermitteln
	var depth_map: Dictionary = {}
	for q in _all_quests:
		depth_map[q["id"]] = _calculate_quest_depth(q["id"], {})

	# 2. Quests nach Ebenen gruppieren
	var tiers: Dictionary = {} # int -> Array[String]
	for q_id in depth_map:
		var d: int = depth_map[q_id]
		if not tiers.has(d):
			tiers[d] = []
		tiers[d].append(q_id)

	# 3. Positionen vergeben: X = Spalten nach Ebene, Y = Reihen
	var tier_keys: Array = tiers.keys()
	tier_keys.sort()

	for d in tier_keys:
		var quest_ids: Array = tiers[d]
		for row_idx in range(quest_ids.size()):
			var q_id: String = quest_ids[row_idx]
			var gnode: GraphNode = _node_map.get(q_id, null)
			if is_instance_valid(gnode):
				var new_pos := Vector2(80 + d * 380, 100 + row_idx * 270)
				gnode.position_offset = new_pos
				_saved_layout[q_id] = {
					"x": int(new_pos.x),
					"y": int(new_pos.y)
				}

	save_current_layout()
	status_label.text = "✔ Auto-Layout erfolgreich angewendet (%d Ebenen)!" % tier_keys.size()
	status_label.modulate = Color(0.4, 1.2, 0.5)


func _calculate_quest_depth(q_id: String, visited: Dictionary) -> int:
	if visited.has(q_id):
		return 0 # Zyklus abfangen
	visited[q_id] = true

	var info: Dictionary = _info_map.get(q_id, {})
	var prereqs: Array = info.get("prerequisites", [])
	if prereqs.is_empty():
		return 0

	var max_p_depth := 0
	for p_id in prereqs:
		var clean_p := str(p_id).trim_prefix("q_")
		var p_depth = _calculate_quest_depth(clean_p, visited.duplicate())
		if p_depth + 1 > max_p_depth:
			max_p_depth = p_depth + 1

	return max_p_depth


func _on_search_changed(query: String) -> void:
	var q := query.strip_edges().to_lower()
	for q_id in _node_map:
		var gnode: GraphNode = _node_map[q_id]
		if not is_instance_valid(gnode):
			continue
		if q.is_empty():
			gnode.modulate = Color.WHITE
		elif q_id.to_lower().contains(q) or gnode.title.to_lower().contains(q):
			gnode.modulate = Color(1.2, 1.2, 1.0)
			graph_edit.scroll_offset = gnode.position_offset - Vector2(100, 100)
		else:
			gnode.modulate = Color(0.4, 0.4, 0.4, 0.35)


func _set_category_filter(cat: int) -> void:
	_current_filter_cat = cat
	for q in _all_quests:
		var gnode: GraphNode = _node_map.get(q["id"], null)
		if not is_instance_valid(gnode):
			continue
		if cat == -1 or q["category"] == cat:
			gnode.visible = true
		else:
			gnode.visible = false


func _load_layout_file() -> void:
	_saved_layout.clear()
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var text := FileAccess.get_file_as_string(LAYOUT_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_saved_layout = parsed


func save_current_layout() -> void:
	_on_end_node_move()
	var file := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_saved_layout, "\t"))
		file.close()
		status_label.text = "💾 Layout gespeichert!"
		status_label.modulate = Color(0.4, 1.2, 0.5)
