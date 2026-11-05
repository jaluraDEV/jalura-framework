@tool
class_name WorldMapGraphView
extends VBoxContainer

## Visueller Weltkarten- & Wegenetz-Graph für Jalura.
## Zeigt alle Dioramen/Szenen aus 'world_map.tres' als interaktive GraphNodes,
## listet Spawns und Exits sauber auf und zeichnet begehbare Verbindungen.

const Scanner = preload("res://addons/jalura_toolkit/modules/world_map_graph/world_map_scanner.gd")
const WORLD_MAP_PATH = "res://resources/world/world_map.tres"
const LAYOUT_PATH = "res://resources/world/world_map_layout.json"

var graph_edit: GraphEdit
var search_edit: LineEdit
var status_label: Label
var file_dialog: EditorFileDialog
var world_map: WorldMap

# Map von scene_id -> GraphNode
var _node_map: Dictionary = {}
# Gespeicherte Positionen
var _saved_layout: Dictionary = {}


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_setup_ui()
	load_and_build_graph()


func _setup_ui() -> void:
	# 1. Top Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)

	var title_lbl := Label.new()
	title_lbl.text = "🗺️ Jalura World Map Graph"
	title_lbl.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(title_lbl)

	toolbar.add_child(VSeparator.new())

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔍 Filter scenes..."
	search_edit.custom_minimum_size = Vector2(180, 0)
	search_edit.clear_button_enabled = true
	search_edit.text_changed.connect(_on_search_changed)
	toolbar.add_child(search_edit)

	var btn_reload := Button.new()
	btn_reload.text = "🔄 Reload"
	btn_reload.tooltip_text = "Reloads the world map and rescans all scene files"
	btn_reload.pressed.connect(load_and_build_graph)
	toolbar.add_child(btn_reload)

	var btn_autolayout := Button.new()
	btn_autolayout.text = "📐 Auto-Layout"
	btn_autolayout.tooltip_text = "Arranges all scenes clearly in columns by network"
	btn_autolayout.pressed.connect(_apply_auto_layout)
	toolbar.add_child(btn_autolayout)

	var btn_save_layout := Button.new()
	btn_save_layout.text = "💾 Save Layout"
	btn_save_layout.tooltip_text = "Saves current node positions persistently"
	btn_save_layout.pressed.connect(save_current_layout)
	toolbar.add_child(btn_save_layout)

	toolbar.add_child(VSeparator.new())

	var btn_add_scene := Button.new()
	btn_add_scene.text = "➕ Register Scene"
	btn_add_scene.tooltip_text = "Add an existing .tscn file to the world map"
	btn_add_scene.pressed.connect(_on_add_scene_pressed)
	toolbar.add_child(btn_add_scene)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	status_label = Label.new()
	status_label.text = "🔵 Entrance (Spawn)  |  🟢 Open  |  🟠 Locked 🔒"
	status_label.modulate = Color(0.8, 0.85, 0.9)
	toolbar.add_child(status_label)

	# 2. GraphEdit
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.snapping_enabled = true
	graph_edit.snapping_distance = 20
	graph_edit.minimap_enabled = true
	graph_edit.minimap_size = Vector2(200, 140)
	graph_edit.show_grid = true

	# Verbindungs-Signale
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	graph_edit.end_node_move.connect(_on_end_node_move)

	add_child(graph_edit)

	# 3. FileDialog für neue Szenen
	file_dialog = EditorFileDialog.new()
	file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	file_dialog.add_filter("*.tscn", "Godot Scenes")
	file_dialog.title = "Add New Scene to World Map"
	file_dialog.file_selected.connect(_on_scene_file_selected)
	add_child(file_dialog)


## Lädt die Weltkarte und baut den Graphen komplett auf
func load_and_build_graph() -> void:
	if not graph_edit:
		return
	_node_map.clear()
	graph_edit.clear_connections()

	# Vorhandene Knoten entfernen
	for child in graph_edit.get_children():
		if child is GraphNode:
			graph_edit.remove_child(child)
			child.queue_free()

	# Layout laden
	_load_layout_file()

	if not ResourceLoader.exists(WORLD_MAP_PATH):
		status_label.text = "❌ 'world_map.tres' not found!"
		return

	world_map = ResourceLoader.load(WORLD_MAP_PATH, "", ResourceLoader.CACHE_MODE_REPLACE) as WorldMap
	if not world_map:
		status_label.text = "❌ Error loading 'world_map.tres'!"
		return

	# Knoten für jede Szene erstellen
	var scenes_to_scan: Array[Dictionary] = []

	for entry in world_map.scenes:
		if not entry:
			continue

		var scan_data := Scanner.scan_scene_file(entry.scene_path, world_map)
		var gnode := _create_scene_graph_node(entry, scan_data)
		graph_edit.add_child(gnode)
		_node_map[str(entry.scene_id)] = gnode

		scenes_to_scan.append({
			"entry": entry,
			"scan": scan_data,
			"gnode": gnode
		})

	# Verbindungen anhand von target_scene_id & target_spawn_id knüpfen
	_build_connections(scenes_to_scan)

	status_label.text = "✔ %d Scenes loaded | 🔵 Spawns | 🟢 Open | 🟠 Locked 🔒" % scenes_to_scan.size()


func _create_scene_graph_node(entry: WorldMapEntry, scan_data: Dictionary) -> GraphNode:
	var gnode := GraphNode.new()
	gnode.name = "GraphNode_" + str(entry.scene_id)
	gnode.title = entry.display_name + (" [TEST]" if entry.is_test else "")
	gnode.resizable = false
	gnode.set_meta("scene_id", str(entry.scene_id))
	gnode.set_meta("scene_path", entry.scene_path)

	# Position aus gespeicherten Koordinaten oder Default
	var s_id := str(entry.scene_id)
	if _saved_layout.has(s_id):
		gnode.position_offset = Vector2(_saved_layout[s_id].get("x", 100), _saved_layout[s_id].get("y", 100))
	else:
		gnode.position_offset = Vector2(100 + _node_map.size() * 250, 150)

	var slot_idx := 0

	# 1. Header Row mit ID und Button "In 3D öffnen"
	var header_box := HBoxContainer.new()
	var id_lbl := Label.new()
	id_lbl.text = "ID: " + s_id
	id_lbl.modulate = Color(0.7, 0.75, 0.8)
	id_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(id_lbl)

	var btn_open := Button.new()
	btn_open.text = "📂 Open in 3D"
	btn_open.tooltip_text = "Opens scene '%s' in Godot 3D editor" % entry.scene_path
	btn_open.pressed.connect(func(): _open_scene(entry.scene_path))
	header_box.add_child(btn_open)

	gnode.add_child(header_box)
	gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	slot_idx += 1

	# Start-Szene Kennzeichnung
	if world_map and world_map.start_scene_id == entry.scene_id:
		var start_lbl := Label.new()
		start_lbl.text = "⭐ START SCENE DIORAMA"
		start_lbl.modulate = Color(1.0, 0.85, 0.2)
		gnode.add_child(start_lbl)
		gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		slot_idx += 1

	# 2. Eingänge (SpawnPoints)
	var spawn_header := Label.new()
	spawn_header.text = "--- 📍 ENTRANCES (%d) ---" % scan_data["spawns"].size()
	spawn_header.modulate = Color(0.4, 0.7, 0.9)
	spawn_header.add_theme_font_size_override("font_size", 11)
	gnode.add_child(spawn_header)
	gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	slot_idx += 1

	var spawns: Array = scan_data["spawns"]
	if spawns.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "  (No spawns defined)"
		empty_lbl.modulate = Color(0.5, 0.5, 0.5)
		gnode.add_child(empty_lbl)
		gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		slot_idx += 1
	else:
		for sp in spawns:
			var sp_box := HBoxContainer.new()
			var sp_lbl := Label.new()
			var def_mark: String = " ⭐" if sp.get("is_default", false) else ""
			sp_lbl.text = "  📍 " + str(sp["spawn_id"]) + def_mark
			sp_lbl.tooltip_text = "Spawn-Node: " + str(sp["node_name"])
			sp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sp_box.add_child(sp_lbl)

			gnode.add_child(sp_box)
			# Linker Port aktiviert (Cyan für Eingänge)
			gnode.set_slot(slot_idx, true, 0, Color(0.2, 0.85, 1.0), false, 0, Color.WHITE)
			sp_box.set_meta("spawn_id", str(sp["spawn_id"]))
			slot_idx += 1

	# 3. Ausgänge (Exits / TransitionBehavior)
	var exit_header := Label.new()
	exit_header.text = "--- 🚪 EXITS (%d) ---" % scan_data["exits"].size()
	exit_header.modulate = Color(0.4, 0.85, 0.5)
	exit_header.add_theme_font_size_override("font_size", 11)
	gnode.add_child(exit_header)
	gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
	slot_idx += 1

	var exits: Array = scan_data["exits"]
	if exits.is_empty():
		var empty_exit := Label.new()
		empty_exit.text = "  (No exits defined)"
		empty_exit.modulate = Color(0.5, 0.5, 0.5)
		gnode.add_child(empty_exit)
		gnode.set_slot(slot_idx, false, 0, Color.WHITE, false, 0, Color.WHITE)
		slot_idx += 1
	else:
		for ex in exits:
			var ex_box := HBoxContainer.new()
			var ex_lbl := Label.new()
			var lock_mark: String = " 🔒" if ex.get("is_locked", false) else ""
			var target_sp: String = " (" + str(ex["target_spawn_id"]) + ")" if not str(ex["target_spawn_id"]).is_empty() else ""
			ex_lbl.text = "  🚪 ➔ " + str(ex["target_scene_id"]) + target_sp + lock_mark
			ex_lbl.tooltip_text = "Exit: %s | Target: %s | Lock: %s" % [ex["node_name"], ex["target_scene_id"], "Locked" if ex["is_locked"] else "Open"]
			ex_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ex_box.add_child(ex_lbl)

			gnode.add_child(ex_box)
			# Rechter Port aktiviert (Grün für offen, Orange für gesperrt)
			var port_col: Color = Color(1.0, 0.55, 0.15) if ex.get("is_locked", false) else Color(0.2, 1.0, 0.4)
			gnode.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, port_col)

			ex_box.set_meta("target_scene_id", str(ex["target_scene_id"]))
			ex_box.set_meta("target_spawn_id", str(ex["target_spawn_id"]))
			slot_idx += 1

	return gnode


## Verbindet alle Ausgänge mit den entsprechenden Ziel-Spawns
func _build_connections(scene_items: Array[Dictionary]) -> void:
	for item in scene_items:
		var src_entry: WorldMapEntry = item["entry"]
		var src_gnode: GraphNode = item["gnode"]
		var exits: Array = item["scan"]["exits"]

		for ex in exits:
			var target_id: String = str(ex["target_scene_id"])
			var target_sp: String = str(ex["target_spawn_id"])

			if not _node_map.has(target_id):
				continue

			var dst_gnode: GraphNode = _node_map[target_id]

			# 1. Ausgangs-Port ermitteln
			var from_slot := -1
			for i in range(src_gnode.get_child_count()):
				var c := src_gnode.get_child(i)
				if c.has_meta("target_scene_id") and c.get_meta("target_scene_id") == target_id:
					if target_sp.is_empty() or c.get_meta("target_spawn_id") == target_sp:
						from_slot = i
						break

			if from_slot == -1:
				continue

			var from_port: int = _get_output_port_for_slot(src_gnode, from_slot)
			if from_port == -1:
				continue

			# 2. Ziel-Spawn-Port ermitteln
			var to_slot := -1
			for i in range(dst_gnode.get_child_count()):
				var c := dst_gnode.get_child(i)
				if c.has_meta("spawn_id"):
					if not target_sp.is_empty() and c.get_meta("spawn_id") == target_sp:
						to_slot = i
						break
					elif target_sp.is_empty() and to_slot == -1:
						to_slot = i # Erster verfügbarer Spawn als Fallback

			if to_slot == -1:
				# Falls kein passender Spawn gefunden wurde, ersten Eingang wählen
				for i in range(dst_gnode.get_child_count()):
					if dst_gnode.is_slot_enabled_left(i):
						to_slot = i
						break

			if to_slot == -1:
				continue

			var to_port: int = _get_input_port_for_slot(dst_gnode, to_slot)
			if to_port != -1:
				graph_edit.connect_node(src_gnode.name, from_port, dst_gnode.name, to_port)


func _get_output_port_for_slot(gnode: GraphNode, target_slot: int) -> int:
	if not gnode.is_slot_enabled_right(target_slot):
		return -1
	var port := 0
	for s in range(target_slot):
		if gnode.is_slot_enabled_right(s):
			port += 1
	return port


func _get_input_port_for_slot(gnode: GraphNode, target_slot: int) -> int:
	if not gnode.is_slot_enabled_left(target_slot):
		return -1
	var port := 0
	for s in range(target_slot):
		if gnode.is_slot_enabled_left(s):
			port += 1
	return port


## Manuelle Verbindung durch User im Graph
func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var src_node := graph_edit.get_node_or_null(NodePath(str(from_node))) as GraphNode
	var dst_node := graph_edit.get_node_or_null(NodePath(str(to_node))) as GraphNode

	if not src_node or not dst_node:
		return

	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	var src_id: String = src_node.get_meta("scene_id", "")
	var dst_id: String = dst_node.get_meta("scene_id", "")
	print_rich("[color=green][b]✔ [World Map][/b][/color] Graph connection created: %s ➔ %s" % [src_id, dst_id])


## Manuelle Trennung durch User
func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)


func _on_end_node_move() -> void:
	# Layout merken
	for scene_id in _node_map:
		var gnode: GraphNode = _node_map[scene_id]
		if is_instance_valid(gnode):
			_saved_layout[scene_id] = {
				"x": int(gnode.position_offset.x),
				"y": int(gnode.position_offset.y)
			}


func _open_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	EditorInterface.open_scene_from_path(scene_path)


func _on_search_changed(query: String) -> void:
	var q := query.strip_edges().to_lower()
	for scene_id in _node_map:
		var gnode: GraphNode = _node_map[scene_id]
		if not is_instance_valid(gnode):
			continue
		if q.is_empty():
			gnode.modulate = Color.WHITE
		elif scene_id.to_lower().contains(q) or gnode.title.to_lower().contains(q):
			gnode.modulate = Color(1.2, 1.2, 1.0) # Highlight
			graph_edit.scroll_offset = gnode.position_offset - Vector2(100, 100)
		else:
			gnode.modulate = Color(0.5, 0.5, 0.5, 0.4) # Dimmed


func _apply_auto_layout() -> void:
	var default_coords := {
		"bootskabine": Vector2(100, 240),
		"overworld": Vector2(580, 240),
		"hafen": Vector2(440, 240),
		"dorfplatz": Vector2(820, 100),
		"see": Vector2(820, 500),
		"omas_vorgarten": Vector2(1240, 100),
		"kramerladen": Vector2(1240, 500),
		"pumpenhaus": Vector2(1240, 800),
		"omas_haus": Vector2(1660, 100),
		"test_scene_a": Vector2(2080, 160),
		"test_scene_b": Vector2(2080, 520)
	}

	for s_id in _node_map:
		var gnode: GraphNode = _node_map[s_id]
		if is_instance_valid(gnode):
			if default_coords.has(s_id):
				gnode.position_offset = default_coords[s_id]
			_saved_layout[s_id] = {
				"x": int(gnode.position_offset.x),
				"y": int(gnode.position_offset.y)
			}

	save_current_layout()
	status_label.text = "✔ Auto-layout applied and saved successfully!"


func _load_layout_file() -> void:
	_saved_layout.clear()
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var text := FileAccess.get_file_as_string(LAYOUT_PATH)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_saved_layout = parsed


func save_current_layout() -> void:
	for scene_id in _node_map:
		var gnode: GraphNode = _node_map[scene_id]
		if is_instance_valid(gnode):
			_saved_layout[scene_id] = {
				"x": int(gnode.position_offset.x),
				"y": int(gnode.position_offset.y)
			}

	var file := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_saved_layout, "  "))
		file.close()
		status_label.text = "💾 Layout saved successfully!"
		print_rich("[color=green][b]✔ [World Map][/b][/color] Layout saved to '%s'." % LAYOUT_PATH)


func _on_add_scene_pressed() -> void:
	if file_dialog:
		file_dialog.popup_file_dialog()


func _on_scene_file_selected(path: String) -> void:
	if not world_map or path.is_empty():
		return

	var basename := path.get_file().get_basename()
	var s_id := StringName(basename)

	if world_map.has_scene(s_id):
		status_label.text = "⚠️ Scene '%s' is already registered in the world map!" % s_id
		return

	var new_entry := WorldMapEntry.new(s_id, basename.capitalize(), path, basename.contains("test"))
	world_map.scenes.append(new_entry)
	var err := ResourceSaver.save(world_map, WORLD_MAP_PATH)
	if err == OK:
		print_rich("[color=green][b]✔ [World Map][/b][/color] New scene '%s' registered successfully!" % s_id)
		load_and_build_graph()
	else:
		status_label.text = "❌ Error saving world map (Code: %d)" % err
