@tool
class_name JaluraValidatorDock
extends VBoxContainer

## Live Diagnostics & Validator Dock for Jalura.
## Binds the WorldObjectValidator directly to the Godot Editor.

const Validator = preload("res://scripts/interaction/world_object_validator.gd")
const InteractiveObject = preload("res://scripts/interaction/interactive_object.gd")

var tree_results: Tree
var lbl_status: Label
var btn_check_scene: Button
var btn_check_world: Button
var btn_auto_fix: Button
var opt_filter: OptionButton

var bottom_bar_button: Button = null

var _current_entries: Array[Dictionary] = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 220)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)

	_build_ui()


func _build_ui() -> void:
	# 1. Top Action Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	btn_check_scene = Button.new()
	btn_check_scene.text = "🔍 Validate Active Scene"
	btn_check_scene.tooltip_text = "Validates all InteractiveObjects in the active scene for IDs, paths, and collisions."
	btn_check_scene.pressed.connect(_on_check_scene_pressed)
	toolbar.add_child(btn_check_scene)

	btn_check_world = Button.new()
	btn_check_world.text = "🗺️ Validate Full World Map"
	btn_check_world.tooltip_text = "Validates all registered scenes, path networks, spawns, and conditions in world_map.tres."
	btn_check_world.pressed.connect(_on_check_world_pressed)
	toolbar.add_child(btn_check_world)

	btn_auto_fix = Button.new()
	btn_auto_fix.text = "⚡ Auto-Fix: Eindeutige IDs"
	btn_auto_fix.tooltip_text = "Vergibt automatisch saubere, eindeutige object_ids an Objekte mit leeren oder doppelten IDs."
	btn_auto_fix.pressed.connect(_on_auto_fix_pressed)
	toolbar.add_child(btn_auto_fix)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var lbl_filter := Label.new()
	lbl_filter.text = "Filter:"
	toolbar.add_child(lbl_filter)

	opt_filter = OptionButton.new()
	opt_filter.add_item("Alle Meldungen", 0)
	opt_filter.add_item("Errors only (🔴)", 1)
	opt_filter.add_item("Warnings only (🟡)", 2)
	opt_filter.item_selected.connect(func(_idx): _refresh_tree_view())
	toolbar.add_child(opt_filter)

	add_child(toolbar)

	# 2. Status Header
	lbl_status = Label.new()
	lbl_status.text = "Ready to validate. Click 'Validate Active Scene' or 'Validate Full World Map'."
	lbl_status.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	add_child(lbl_status)

	# 3. Diagnostics Tree
	tree_results = Tree.new()
	tree_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_results.columns = 3
	tree_results.column_titles_visible = true
	tree_results.set_column_title(0, "Status")
	tree_results.set_column_title(1, "Object / Scene")
	tree_results.set_column_title(2, "Diagnose & Details")
	tree_results.set_column_custom_minimum_width(0, 110)
	tree_results.set_column_custom_minimum_width(1, 200)
	tree_results.set_column_expand(0, false)
	tree_results.set_column_expand(1, false)
	tree_results.set_column_expand(2, true)
	tree_results.item_selected.connect(_on_item_selected)
	tree_results.item_activated.connect(_on_item_activated)
	add_child(tree_results)


func _on_check_scene_pressed() -> void:
	var edited_root := EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not edited_root:
		lbl_status.text = "No active scene open in editor!"
		lbl_status.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		return
	run_scene_validation(edited_root)


func _on_check_world_pressed() -> void:
	run_world_validation()


func _on_auto_fix_pressed() -> void:
	var edited_root := EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	if not edited_root:
		return
	var fixed := auto_fix_ids(edited_root)
	if fixed > 0:
		print_rich("[color=green][b]✔ [Jalura Toolkit][/b][/color] %d object_ids successfully repaired." % fixed)
		run_scene_validation(edited_root)
		lbl_status.text = "%d object_ids wurden automatisch repariert und eindeutig gemacht!" % fixed
		lbl_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		lbl_status.text = "All object_ids are already unique – no fix needed."
		lbl_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))


func run_scene_validation(scene_root: Node) -> Dictionary:
	_current_entries.clear()
	var raw_res: Dictionary = Validator.validate_scene(scene_root)
	var objects := _find_all_interactive_objects(scene_root)

	# 1. Parse errors
	for err_str in raw_res.get("errors", []):
		var target_path := _extract_node_path_from_msg(err_str)
		_current_entries.append({
			"severity": "error",
			"status": "🔴 Error",
			"object": target_path,
			"message": err_str,
			"node_path": target_path
		})

	# 2. Parse warnings
	for warn_str in raw_res.get("warnings", []):
		var target_path := _extract_node_path_from_msg(warn_str)
		_current_entries.append({
			"severity": "warning",
			"status": "🟡 Warning",
			"object": target_path,
			"message": warn_str,
			"node_path": target_path
		})

	# 3. Parse info
	for info_str in raw_res.get("info", []):
		var target_path := _extract_node_path_from_msg(info_str)
		_current_entries.append({
			"severity": "info",
			"status": "ℹ️ Info",
			"object": target_path,
			"message": info_str,
			"node_path": target_path
		})

	_update_header_and_badge(raw_res.get("object_count", objects.size()), raw_res.get("errors", []).size(), raw_res.get("warnings", []).size())
	_refresh_tree_view()
	return raw_res


func run_world_validation() -> Dictionary:
	_current_entries.clear()
	var raw_res: Dictionary = Validator.validate_world_map()

	for err_str in raw_res.get("errors", []):
		_current_entries.append({
			"severity": "error",
			"status": "🔴 Error",
			"object": "world_map.tres",
			"message": err_str,
			"node_path": ""
		})

	for warn_str in raw_res.get("warnings", []):
		_current_entries.append({
			"severity": "warning",
			"status": "🟡 Warning",
			"object": "world_map.tres",
			"message": warn_str,
			"node_path": ""
		})

	for info_str in raw_res.get("info", []):
		_current_entries.append({
			"severity": "info",
			"status": "ℹ️ Info",
			"object": "world_map.tres",
			"message": info_str,
			"node_path": ""
		})

	var scene_count: int = raw_res.get("scene_count", 0)
	var err_count: int = raw_res.get("errors", []).size()
	var warn_count: int = raw_res.get("warnings", []).size()

	if err_count == 0 and warn_count == 0:
		lbl_status.text = "🟢 World map perfect: %d registered scenes, all connections & spawns valid!" % scene_count
		lbl_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		lbl_status.text = "World map validated: %d scenes – 🔴 %d error(s), 🟡 %d warning(s) found." % [scene_count, err_count, warn_count]
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if err_count > 0 else Color(0.9, 0.8, 0.2))

	if bottom_bar_button:
		bottom_bar_button.text = "🛡️ Jalura Diagnose" + (" (🔴 %d)" % err_count if err_count > 0 else " (🟢)")

	_refresh_tree_view()
	return raw_res


func _update_header_and_badge(obj_count: int, err_count: int, warn_count: int) -> void:
	if err_count == 0 and warn_count == 0:
		lbl_status.text = "🟢 Scene valid: %d world objects checked – zero issues found!" % obj_count
		lbl_status.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		lbl_status.text = "Validation completed: %d objects – 🔴 %d error(s), 🟡 %d warning(s)." % [obj_count, err_count, warn_count]
		lbl_status.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if err_count > 0 else Color(0.9, 0.8, 0.2))

	if bottom_bar_button:
		if err_count > 0:
			bottom_bar_button.text = "🛡️ Jalura Diagnose (🔴 %d)" % err_count
		elif warn_count > 0:
			bottom_bar_button.text = "🛡️ Jalura Diagnose (🟡 %d)" % warn_count
		else:
			bottom_bar_button.text = "🛡️ Jalura Diagnose (🟢)"


func _refresh_tree_view() -> void:
	tree_results.clear()
	var root := tree_results.create_item()
	var filter_mode := opt_filter.selected

	var shown_count := 0
	for entry in _current_entries:
		var sev: String = entry["severity"]
		if filter_mode == 1 and sev != "error":
			continue
		if filter_mode == 2 and sev != "warning":
			continue

		var item := tree_results.create_item(root)
		item.set_text(0, entry["status"])
		item.set_text(1, entry["object"])
		item.set_text(2, entry["message"])

		if sev == "error":
			item.set_custom_color(0, Color(1.0, 0.4, 0.4))
			item.set_custom_color(1, Color(1.0, 0.6, 0.6))
		elif sev == "warning":
			item.set_custom_color(0, Color(1.0, 0.85, 0.3))
			item.set_custom_color(1, Color(1.0, 0.9, 0.5))
		else:
			item.set_custom_color(0, Color(0.4, 0.8, 1.0))

		item.set_metadata(0, entry["node_path"])
		shown_count += 1

	if shown_count == 0 and _current_entries.is_empty():
		var empty_item := tree_results.create_item(root)
		empty_item.set_text(0, "🟢 OK")
		empty_item.set_text(1, "-")
		empty_item.set_text(2, "Keine Diagnose-Meldungen vorhanden.")
		empty_item.set_custom_color(0, Color(0.3, 0.9, 0.4))


func _on_item_selected() -> void:
	var sel := tree_results.get_selected()
	if not sel or not Engine.is_editor_hint():
		return
	var path_str: String = sel.get_metadata(0)
	if path_str.is_empty():
		return

	var edited_root := EditorInterface.get_edited_scene_root()
	if not edited_root:
		return

	var target := edited_root.get_node_or_null(NodePath(path_str))
	if not target:
		target = edited_root.find_child(path_str.get_file(), true, false)

	if target:
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(target)
		EditorInterface.inspect_object(target)


func _on_item_activated() -> void:
	_on_item_selected()


static func auto_fix_ids(scene_root: Node) -> int:
	var objects := _find_all_interactive_objects(scene_root)
	var seen_ids := {}
	var fixed := 0

	for obj in objects:
		var oid := obj.object_id.strip_edges()
		if oid.is_empty():
			var generated := obj.name.to_snake_case()
			if seen_ids.has(generated):
				generated = "%s_%d" % [generated, randi() % 1000]
			obj.object_id = generated
			seen_ids[generated] = true
			fixed += 1
		elif seen_ids.has(oid):
			var new_id := "%s_%d" % [oid, randi() % 1000]
			obj.object_id = new_id
			seen_ids[new_id] = true
			fixed += 1
		else:
			seen_ids[oid] = true

	return fixed


static func _find_all_interactive_objects(node: Node) -> Array[InteractiveObject]:
	var list: Array[InteractiveObject] = []
	if node is InteractiveObject:
		list.append(node)
	for child in node.get_children():
		list.append_array(_find_all_interactive_objects(child))
	return list


static func _extract_node_path_from_msg(msg: String) -> String:
	# Extrahiert Text zwischen einfachen Anführungszeichen, z. B. Objekt 'Chest_1' hat...
	var start := msg.find("'")
	if start >= 0:
		var end := msg.find("'", start + 1)
		if end > start:
			return msg.substr(start + 1, end - start - 1)
	return ""
