@tool
class_name JaluraAssetPaletteDock
extends VBoxContainer

## Leveldesign Asset-Palette & 3D-Stempel-Werkzeug für Jalura.
## Erlaubt das Auswählen modularer Prefabs (Truhen, Türen, Hebel, Bäume, NPCs)
## und direktes Platzieren im 3D-Viewport mit Mauszeiger, Grid-Snapping und [R]-Drehung.
## Unterstützt auch das direkte Rotieren von im Editor ausgewählten Objekten.

signal stamp_mode_changed(active: bool)
signal asset_selected(prefab_path: String)

var plugin: EditorPlugin = null

const PREFABS = [
	{
		"category": "📦 Containers & Chests",
		"items": [
			{"name": "Wooden Chest / Crate", "path": "res://scenes/objects/obj_chest.tscn", "icon": "📦", "desc": "Interactive loot chest with item contents & audio"}
		]
	},
	{
		"category": "🚪 Doors & Transitions",
		"items": [
			{"name": "Wooden Door / Sliding Gate", "path": "res://scenes/objects/obj_door.tscn", "icon": "🚪", "desc": "Swing or sliding door with remote control & lock"},
			{"name": "Exit Door (Scene)", "path": "res://scenes/objects/obj_exit_door.tscn", "icon": "🚪", "desc": "Door triggering scene transition on interact [E]"},
			{"name": "Exit Trigger Zone", "path": "res://scenes/objects/obj_exit_zone.tscn", "icon": "🚶", "desc": "Invisible trigger zone for automatic scene transitions"}
		]
	},
	{
		"category": "⚡ Switches & Mechanics",
		"items": [
			{"name": "Floor Lever / Switch", "path": "res://scenes/objects/obj_lever.tscn", "icon": "🕹️", "desc": "Lever with animated arm for controlling gates and doors"},
			{"name": "Pressure Plate (Floor)", "path": "res://scenes/objects/obj_pressure_plate.tscn", "icon": "⏹️", "desc": "Floor plate triggered by player or pushable blocks"},
			{"name": "Bounce Pad / Trampoline", "path": "res://scenes/objects/obj_bounce_pad.tscn", "icon": "🦘", "desc": "Catapults the player high into the air with configurable force"},
			{"name": "Water Trampoline", "path": "res://scenes/objects/obj_water_trampoline.tscn", "icon": "🌊", "desc": "Floating trampoline with wave bobbing and super-bounce"}
		]
	},
	{
		"category": "🌳 Nature, Signs & Decor",
		"items": [
			{"name": "Notice Board / Sign", "path": "res://scenes/objects/obj_sign.tscn", "icon": "🪧", "desc": "Readable sign with toast message or dialogue"},
			{"name": "Wobble Decor", "path": "res://scenes/objects/obj_wobble.tscn", "icon": "📦", "desc": "Decor object that elastical bounces when bumped"}
		]
	},
	{
		"category": "🪨 Interaction & Physics",
		"items": [
			{"name": "Pushable Block (Crate)", "path": "res://scenes/objects/obj_pushable.tscn", "icon": "🧱", "desc": "Pushable cube for puzzles and pressure plates"},
			{"name": "Collectible Item (Pickup)", "path": "res://scenes/objects/obj_pickup.tscn", "icon": "✨", "desc": "Pickable 3D item for player inventory"}
		]
	},
	{
		"category": "👤 Characters & NPCs",
		"items": [
			{"name": "Villager (NPC)", "path": "res://scenes/objects/obj_npc_basic.tscn", "icon": "👤", "desc": "Interactive NPC with dialogue, head tracking & quests"},
			{"name": "Mara / Sailor (NPC)", "path": "res://scenes/objects/obj_npc_grantelbart.tscn", "icon": "⚓", "desc": "Animated harbor NPC with dialogue & quest logic"}
		]
	},
	{
		"category": "🌿 Environment, Rails & Zones",
		"items": [
			{"name": "Water Hazard Zone", "path": "res://scenes/objects/water_zone.tscn", "icon": "💧", "desc": "Water hazard trigger with splash effect & respawn"}
		]
	}
]

# Stempel-Status
var is_stamp_active: bool = false
var selected_prefab_path: String = ""
var selected_prefab_name: String = ""
var current_rotation: float = 0.0 # in Grad
var snap_distance: float = 0.5   # Meter
var snap_enabled: bool = true
var height_offset: float = 0.0

# Weg & Rail Zeichnen
var is_path_draw_active: bool = false
var active_curve_node: Node3D = null
var path_rail_toolbar: VBoxContainer
var lbl_curve_info: Label
var btn_toggle_curve_draw: Button

# UI Controls
var btn_toggle_stamp: Button
var btn_cancel_stamp: Button
var lbl_status_banner: Label
var chk_snap: CheckBox
var opt_snap_size: OptionButton
var lbl_rotation: Label
var spin_height: SpinBox
var search_input: LineEdit
var cards_container: VBoxContainer
var preview_instance: Node3D = null

# Kontext für im 3D-Editor ausgewählte Nodes
var selection_box: PanelContainer
var lbl_selected_info: Label
var btn_pick_asset: Button
var current_selected_node: Node3D = null


func _init() -> void:
	name = "🖌️ Palette"
	custom_minimum_size = Vector2(260, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# Header
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "🖌️ Jalura Palette"
	title.add_theme_font_size_override("font_size", 14)
	header.add_child(title)
	add_child(header)

	# Status-Banner / Stempel-Button
	btn_toggle_stamp = Button.new()
	btn_toggle_stamp.text = "🖌️ Stamp Mode: INACTIVE"
	btn_toggle_stamp.custom_minimum_size = Vector2(0, 32)
	btn_toggle_stamp.pressed.connect(toggle_stamp_mode)
	add_child(btn_toggle_stamp)

	# Schnell-Abbruch-Button (ESC / Rechtsklick)
	btn_cancel_stamp = Button.new()
	btn_cancel_stamp.text = "⏹️ Clear stamp (normal mode)"
	btn_cancel_stamp.modulate = Color(1.0, 0.45, 0.45)
	btn_cancel_stamp.visible = false
	btn_cancel_stamp.pressed.connect(func(): set_stamp_active(false))
	add_child(btn_cancel_stamp)

	lbl_status_banner = Label.new()
	lbl_status_banner.text = "Select an object below to stamp it into the 3D world."
	lbl_status_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_status_banner.modulate = Color(0.7, 0.75, 0.8)
	lbl_status_banner.add_theme_font_size_override("font_size", 11)
	add_child(lbl_status_banner)

	# Info-Box für aktuell im 3D-Viewport ausgewähltes Objekt
	_setup_selection_box()

	add_child(HSeparator.new())

	# Optionen: Snapping & Drehung
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 4)

	# Snapping
	var snap_row := HBoxContainer.new()
	chk_snap = CheckBox.new()
	chk_snap.text = "Grid Snap:"
	chk_snap.button_pressed = true
	chk_snap.toggled.connect(func(val): snap_enabled = val)
	snap_row.add_child(chk_snap)

	opt_snap_size = OptionButton.new()
	opt_snap_size.add_item("0.25 m", 0)
	opt_snap_size.add_item("0.5 m", 1)
	opt_snap_size.add_item("1.0 m", 2)
	opt_snap_size.add_item("2.0 m", 3)
	opt_snap_size.select(1) # Default 0.5m
	opt_snap_size.item_selected.connect(_on_snap_size_selected)
	snap_row.add_child(opt_snap_size)
	settings_box.add_child(snap_row)

	# Drehung (dreht Stempel ODER aktuell gewähltes Objekt!)
	var rot_row := HBoxContainer.new()
	var rot_title := Label.new()
	rot_title.text = "Drehung [R]:"
	rot_row.add_child(rot_title)

	var btn_rot_m45 := Button.new()
	btn_rot_m45.text = "↺ -45°"
	btn_rot_m45.tooltip_text = "Rotates the stamp or selected 3D object by -45°"
	btn_rot_m45.pressed.connect(func(): rotate_stamp(-45.0))
	rot_row.add_child(btn_rot_m45)

	var btn_rot_p45 := Button.new()
	btn_rot_p45.text = "↻ +45°"
	btn_rot_p45.tooltip_text = "Rotates the stamp or selected 3D object by +45°"
	btn_rot_p45.pressed.connect(func(): rotate_stamp(45.0))
	rot_row.add_child(btn_rot_p45)

	lbl_rotation = Label.new()
	lbl_rotation.text = "0°"
	lbl_rotation.custom_minimum_size = Vector2(35, 0)
	lbl_rotation.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rot_row.add_child(lbl_rotation)
	settings_box.add_child(rot_row)

	# Höhen-Offset
	var height_row := HBoxContainer.new()
	var height_lbl := Label.new()
	height_lbl.text = "Height Offset:"
	height_row.add_child(height_lbl)

	spin_height = SpinBox.new()
	spin_height.min_value = -5.0
	spin_height.max_value = 10.0
	spin_height.step = 0.1
	spin_height.value = 0.0
	spin_height.suffix = "m"
	spin_height.value_changed.connect(func(val): height_offset = val)
	height_row.add_child(spin_height)
	settings_box.add_child(height_row)

	add_child(settings_box)
	add_child(HSeparator.new())

	# Suche / Filter
	search_input = LineEdit.new()
	search_input.placeholder_text = "🔍 Filter assets..."
	search_input.clear_button_enabled = true
	search_input.text_changed.connect(_on_search_changed)
	add_child(search_input)

	# Asset-Liste (ScrollContainer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	cards_container = VBoxContainer.new()
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 8)
	scroll.add_child(cards_container)

	_build_asset_cards("")


func _setup_selection_box() -> void:
	selection_box = PanelContainer.new()
	var box_vbox := VBoxContainer.new()
	box_vbox.add_theme_constant_override("separation", 4)

	lbl_selected_info = Label.new()
	lbl_selected_info.text = "📌 No 3D object selected"
	lbl_selected_info.modulate = Color(0.6, 0.8, 1.0)
	lbl_selected_info.add_theme_font_size_override("font_size", 11)
	box_vbox.add_child(lbl_selected_info)

	btn_pick_asset = Button.new()
	btn_pick_asset.text = "🧪 Pick as Stamp (Eyedropper)"
	btn_pick_asset.add_theme_font_size_override("font_size", 11)
	btn_pick_asset.visible = false
	btn_pick_asset.pressed.connect(_on_pick_selected_as_stamp)
	box_vbox.add_child(btn_pick_asset)

	# Toolbar für Wege (TrailPath3D) & Rails (Rail3D)
	path_rail_toolbar = VBoxContainer.new()
	path_rail_toolbar.add_theme_constant_override("separation", 5)
	path_rail_toolbar.visible = false

	var sep := HSeparator.new()
	path_rail_toolbar.add_child(sep)

	var pr_header := Label.new()
	pr_header.text = "🛣️ Weg- & Rail-Editor"
	pr_header.modulate = Color(0.4, 0.9, 1.0)
	pr_header.add_theme_font_size_override("font_size", 12)
	path_rail_toolbar.add_child(pr_header)

	lbl_curve_info = Label.new()
	lbl_curve_info.text = "Points: 0  |  Length: 0.0m"
	lbl_curve_info.modulate = Color(0.8, 0.85, 0.9)
	lbl_curve_info.add_theme_font_size_override("font_size", 11)
	path_rail_toolbar.add_child(lbl_curve_info)

	btn_toggle_curve_draw = Button.new()
	btn_toggle_curve_draw.text = "✏️ 3D-Klick-Zeichnen STARTEN"
	btn_toggle_curve_draw.custom_minimum_size = Vector2(0, 32)
	btn_toggle_curve_draw.pressed.connect(toggle_path_draw_mode)
	path_rail_toolbar.add_child(btn_toggle_curve_draw)

	var actions_grid := GridContainer.new()
	actions_grid.columns = 3
	actions_grid.add_theme_constant_override("h_separation", 3)
	actions_grid.add_theme_constant_override("v_separation", 3)

	var btn_ext := Button.new()
	btn_ext.text = "➕ +5m"
	btn_ext.tooltip_text = "Extend path 5 meters forward"
	btn_ext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ext.pressed.connect(func(): _curve_action("toolkit_extend", [5.0]))
	actions_grid.add_child(btn_ext)

	var btn_rem := Button.new()
	btn_rem.text = "🗑️ Delete"
	btn_rem.tooltip_text = "Letzten Punkt entfernen"
	btn_rem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rem.pressed.connect(func(): _curve_action("toolkit_remove_last"))
	actions_grid.add_child(btn_rem)

	var btn_smo := Button.new()
	btn_smo.text = "✨ Smooth"
	btn_smo.tooltip_text = "Harmonische Kurventangenten berechnen"
	btn_smo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_smo.pressed.connect(func(): _curve_action("toolkit_auto_smooth"))
	actions_grid.add_child(btn_smo)

	var btn_snp := Button.new()
	btn_snp.text = "📌 Snappen"
	btn_snp.tooltip_text = "Alle Punkte per Raycast an den Boden heften"
	btn_snp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_snp.pressed.connect(func(): _curve_action("toolkit_snap_to_ground"))
	actions_grid.add_child(btn_snp)

	var btn_rev := Button.new()
	btn_rev.text = "🔄 Drehen"
	btn_rev.tooltip_text = "Weg- / Fahrtrichtung umkehren"
	btn_rev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rev.pressed.connect(func(): _curve_action("toolkit_reverse"))
	actions_grid.add_child(btn_rev)

	var btn_unq := Button.new()
	btn_unq.text = "🔀 Unique"
	btn_unq.tooltip_text = "Duplicate curve so modifications stay isolated"
	btn_unq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_unq.pressed.connect(func(): _curve_action("toolkit_make_curve_unique"))
	actions_grid.add_child(btn_unq)

	path_rail_toolbar.add_child(actions_grid)
	box_vbox.add_child(path_rail_toolbar)

	selection_box.add_child(box_vbox)
	selection_box.visible = false
	add_child(selection_box)


func _get_all_categories() -> Array:
	var list: Array = []
	for cat in PREFABS:
		list.append(cat)

	# Dynamische Items aus res://scenes/items/ scannen
	var equipment_items: Array = []
	var dynamic_items: Array = []
	var dir := DirAccess.open("res://scenes/items")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.begins_with("pickable_") and file_name.ends_with(".tscn"):
				var full_path = "res://scenes/items".path_join(file_name)
				var clean_name = file_name.trim_prefix("pickable_").trim_suffix(".tscn").replace("_", " ").capitalize()
				var icon_sym = "✨"
				var is_equip := false
				if "apple" in file_name or "apfel" in file_name:
					icon_sym = "🍎"
				elif "batt" in file_name or "coin" in file_name:
					icon_sym = "⚡"
				elif "key" in file_name or "schluessel" in file_name:
					icon_sym = "🔑"
				elif "lampe" in file_name or "light" in file_name or "torch" in file_name or "flash" in file_name:
					icon_sym = "🔦"
					is_equip = true
				elif "glider" in file_name:
					icon_sym = "🪂"
					is_equip = true
				elif "shoe" in file_name or "rail" in file_name or "schuh" in file_name:
					icon_sym = "👟"
					is_equip = true

				var entry := {
					"name": clean_name + (" (Equipment)" if is_equip else " (Pickup)"),
					"path": full_path,
					"icon": icon_sym,
					"desc": ("Equipment item for Jalura: " if is_equip else "Pickable 3D world item for inventory: ") + clean_name
				}
				if is_equip:
					equipment_items.append(entry)
				else:
					dynamic_items.append(entry)
			file_name = dir.get_next()

	if not equipment_items.is_empty():
		list.append({
			"category": "⚙️ Equipment & Tools",
			"items": equipment_items
		})
	if not dynamic_items.is_empty():
		list.append({
			"category": "🎒 Inventory & Collectibles",
			"items": dynamic_items
		})

	return list


func _build_asset_cards(query: String) -> void:
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()

	var q := query.strip_edges().to_lower()

	for cat in _get_all_categories():
		var cat_name: String = cat["category"]
		var items: Array = cat["items"]

		var matching_items: Array = []
		for item in items:
			if q.is_empty() or item["name"].to_lower().contains(q) or item["desc"].to_lower().contains(q):
				matching_items.append(item)

		if matching_items.is_empty():
			continue

		# Kategorie-Überschrift
		var cat_lbl := Label.new()
		cat_lbl.text = cat_name
		cat_lbl.modulate = Color(0.4, 0.75, 1.0)
		cat_lbl.add_theme_font_size_override("font_size", 12)
		cards_container.add_child(cat_lbl)

		# Buttons für jedes Item
		for item in matching_items:
			var btn := Button.new()
			btn.text = "%s %s" % [item["icon"], item["name"]]
			btn.tooltip_text = "%s\nPfad: %s" % [item["desc"], item["path"]]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(0, 30)

			var p_path: String = item["path"]
			var p_name: String = item["name"]
			btn.pressed.connect(func(): select_asset(p_path, p_name))
			cards_container.add_child(btn)


func _on_snap_size_selected(index: int) -> void:
	match index:
		0: snap_distance = 0.25
		1: snap_distance = 0.5
		2: snap_distance = 1.0
		3: snap_distance = 2.0


func _on_search_changed(query: String) -> void:
	_build_asset_cards(query)


## Wählt ein Asset aus und schaltet den Stempel-Modus direkt scharf
func select_asset(prefab_path: String, prefab_name: String) -> void:
	selected_prefab_path = prefab_path
	selected_prefab_name = prefab_name
	is_stamp_active = true
	_update_stamp_ui()
	_update_preview_ghost()
	asset_selected.emit(prefab_path)
	stamp_mode_changed.emit(true)
	print_rich("[color=yellow][b]🖌️ [Jalura Palette][/b][/color] Stamp selected: [b]%s[/b] (Click in 3D to place, [R] to rotate, ESC to cancel)" % prefab_name)


func toggle_stamp_mode() -> void:
	set_stamp_active(not is_stamp_active)


func set_stamp_active(active: bool) -> void:
	if active and selected_prefab_path.is_empty():
		select_asset("res://scenes/objects/obj_chest.tscn", "Wooden Chest / Crate")
		return

	is_stamp_active = active
	_update_stamp_ui()
	if not is_stamp_active:
		_cleanup_preview_ghost()
	else:
		_update_preview_ghost()
	stamp_mode_changed.emit(is_stamp_active)


## Dreht den Stempel ODER das aktuell im 3D-Editor ausgewählte Objekt
func rotate_stamp(delta_deg: float) -> void:
	current_rotation = fposmod(current_rotation + delta_deg, 360.0)
	lbl_rotation.text = "%d°" % int(current_rotation)

	# 1. Preview Ghost drehen
	if preview_instance and is_instance_valid(preview_instance):
		preview_instance.rotation_degrees.y = current_rotation

	# 2. Wenn ein Objekt in der 3D-Szene markiert ist, dieses ebenfalls drehen!
	var ur: EditorUndoRedoManager = null
	if plugin:
		ur = plugin.get_undo_redo()

	var selection: EditorSelection = null
	if plugin and plugin.get_editor_interface() and plugin.get_editor_interface().get_selection():
		selection = plugin.get_editor_interface().get_selection()
	elif Engine.is_editor_hint() and EditorInterface.has_method("get_selection"):
		selection = EditorInterface.get_selection()

	if selection:
		var selected = selection.get_selected_nodes()
		for node in selected:
			if node is Node3D and node != preview_instance:
				var n := node as Node3D
				var old_deg := n.rotation_degrees.y
				var new_deg := fposmod(old_deg + delta_deg, 360.0)
				if ur:
					ur.create_action("Jalura Palette: " + n.name + " drehen")
					ur.add_do_property(n, "rotation_degrees:y", new_deg)
					ur.add_undo_property(n, "rotation_degrees:y", old_deg)
					ur.commit_action()
				else:
					n.rotation_degrees.y = new_deg
				print("[Jalura Palette] Object rotated: %s -> %d°" % [n.name, int(new_deg)])


func _update_stamp_ui() -> void:
	if is_stamp_active:
		btn_toggle_stamp.text = "🟢 STAMP ACTIVE: %s" % selected_prefab_name
		btn_toggle_stamp.modulate = Color(0.3, 1.2, 0.4)
		btn_cancel_stamp.visible = true
		lbl_status_banner.text = "Left-click in 3D: Stamp object\n[R]: Rotate 45°  |  Right-click / ESC: Cancel"
		lbl_status_banner.modulate = Color(1.0, 0.9, 0.3)
	else:
		btn_toggle_stamp.text = "⚪ STAMP INACTIVE (Normal Mode)"
		btn_toggle_stamp.modulate = Color.WHITE
		btn_cancel_stamp.visible = false
		lbl_status_banner.text = "Click an object below to activate stamp mode."
		lbl_status_banner.modulate = Color(0.7, 0.75, 0.8)


## Wird aufgerufen, wenn der Benutzer im 3D-Editor ein anderes Node auswählt
func on_editor_selection_changed(nodes: Array[Node]) -> void:
	current_selected_node = null
	for node in nodes:
		if node is Node3D and node != preview_instance:
			current_selected_node = node as Node3D
			break

	if current_selected_node:
		selection_box.visible = true
		lbl_selected_info.text = "📌 Selected: %s (%d°)" % [current_selected_node.name, int(current_selected_node.rotation_degrees.y)]
		lbl_rotation.text = "%d°" % int(current_selected_node.rotation_degrees.y)
		btn_pick_asset.visible = true

		# Prüfen, ob es ein Weg (TrailPath3D) oder eine Schiene (Rail3D) ist
		if current_selected_node is Path3D and (current_selected_node.has_method("toolkit_make_curve_unique") or current_selected_node.has_method("_toolkit_make_curve_unique")):
			active_curve_node = current_selected_node
			_update_path_rail_info()
		else:
			active_curve_node = null
			if path_rail_toolbar:
				path_rail_toolbar.visible = false
			if is_path_draw_active:
				set_path_draw_active(false)
	else:
		selection_box.visible = false
		btn_pick_asset.visible = false
		active_curve_node = null
		if path_rail_toolbar:
			path_rail_toolbar.visible = false
		if is_path_draw_active:
			set_path_draw_active(false)


func set_path_draw_active_for(node: Node3D, active: bool) -> void:
	active_curve_node = node
	current_selected_node = node
	if selection_box:
		selection_box.visible = true
	set_path_draw_active(active)


func toggle_path_draw_mode() -> void:
	set_path_draw_active(not is_path_draw_active)


func set_path_draw_active(active: bool) -> void:
	is_path_draw_active = active
	if is_path_draw_active:
		if is_stamp_active:
			set_stamp_active(false)
		if btn_toggle_curve_draw:
			btn_toggle_curve_draw.text = "🟢 DRAWING ACTIVE: Click in 3D for point"
			btn_toggle_curve_draw.modulate = Color(0.3, 1.3, 0.5)
		lbl_status_banner.text = "✏️ Click-draw active: Left-click in 3D world to place curve points!\nRight-click / ESC: Finish drawing"
		lbl_status_banner.modulate = Color(1.0, 0.9, 0.3)
	else:
		if btn_toggle_curve_draw:
			btn_toggle_curve_draw.text = "✏️ 3D-Klick-Zeichnen STARTEN"
			btn_toggle_curve_draw.modulate = Color.WHITE
		_update_stamp_ui()
	_update_path_rail_info()


func _update_path_rail_info() -> void:
	if not active_curve_node or not is_instance_valid(active_curve_node):
		if path_rail_toolbar:
			path_rail_toolbar.visible = false
		return
	if path_rail_toolbar:
		path_rail_toolbar.visible = true
	var p_count := 0
	var length := 0.0
	if active_curve_node is Path3D and (active_curve_node as Path3D).curve:
		var c: Curve3D = (active_curve_node as Path3D).curve
		p_count = c.point_count
		length = c.get_baked_length()
	if lbl_curve_info:
		lbl_curve_info.text = "Points: %d  |  Length: %.1f m" % [p_count, length]


func _curve_action(method_name: String, args: Array = []) -> void:
	if not active_curve_node or not is_instance_valid(active_curve_node):
		return
	preload("res://addons/jalura_toolkit/modules/path_rail_tool/path_curve_actions.gd").perform(
		active_curve_node as Path3D, method_name, args, plugin.get_undo_redo() if plugin else null)
	_update_path_rail_info()


func _on_pick_selected_as_stamp() -> void:
	if not current_selected_node:
		return

	# Prüfen, ob die Szene einem unserer Prefabs entspricht
	var scene_path := current_selected_node.scene_file_path
	var found_name := current_selected_node.name

	for cat in PREFABS:
		for item in cat["items"]:
			if item["path"] == scene_path:
				found_name = item["name"]
				break

	if not scene_path.is_empty():
		select_asset(scene_path, found_name)
		print("[Jalura Palette] Pipette sampled: %s" % found_name)


# ==========================================
# 3D VORSCHAU GHOST
# ==========================================

func _update_preview_ghost() -> void:
	_cleanup_preview_ghost()
	if not is_stamp_active or selected_prefab_path.is_empty():
		return

	var scene := ResourceLoader.load(selected_prefab_path) as PackedScene
	if not scene:
		return

	preview_instance = scene.instantiate() as Node3D
	if not preview_instance:
		return

	preview_instance.name = "__JaluraStampPreview__"
	preview_instance.rotation_degrees.y = current_rotation
	preview_instance.visible = false # Erst sichtbar machen, wenn Maus im 3D-Viewport ist!

	# Vorschau transparent machen und Kollisionen VOLLSTÄNDIG abklemmen
	_strip_ghost_physics_and_style(preview_instance)

	var edited_root := _get_edited_root()
	if edited_root:
		edited_root.add_child(preview_instance)


func _cleanup_preview_ghost() -> void:
	if preview_instance and is_instance_valid(preview_instance):
		preview_instance.queue_free()
		preview_instance = null

	var edited_root := _get_edited_root()
	if edited_root:
		var old = edited_root.find_child("__JaluraStampPreview__", false, false)
		if old:
			old.queue_free()


func _get_edited_root() -> Node:
	if is_inside_tree() and get_tree():
		return get_tree().edited_scene_root
	return null


func _strip_ghost_physics_and_style(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	if node is CollisionObject3D:
		var co := node as CollisionObject3D
		co.collision_layer = 0
		co.collision_mask = 0
		co.input_ray_pickable = false
		co.process_mode = Node.PROCESS_MODE_DISABLED
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.transparency = 0.45
	for child in node.get_children():
		_strip_ghost_physics_and_style(child)


func _get_all_collision_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_get_all_collision_rids(child, rids)


# ==========================================
# 3D VIEWPORT INPUT HANDLING (FORWARDED)
# ==========================================

func handle_3d_gui_input(camera: Camera3D, event: InputEvent, undo_redo: EditorUndoRedoManager) -> int:
	# 1. Klick-Zeichenmodus für Wege & Rails
	if is_path_draw_active and active_curve_node and is_instance_valid(active_curve_node):
		if event is InputEventKey and event.pressed:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_ESCAPE:
				set_path_draw_active(false)
				return 1 # AFTER_GUI_INPUT_STOP

		if event is InputEventMouseButton and event.pressed:
			var mouse_btn := event as InputEventMouseButton
			if mouse_btn.button_index == MOUSE_BUTTON_RIGHT:
				# Rechtsklick = Zeichnen beenden
				set_path_draw_active(false)
				return 1 # AFTER_GUI_INPUT_STOP
			elif mouse_btn.button_index == MOUSE_BUTTON_LEFT:
				# Linksklick = Neuen Punkt an Mausklick-Position anfügen!
				var hit_pos := _raycast_ground(camera, mouse_btn.position)
				if hit_pos != Vector3.INF:
					preload("res://addons/jalura_toolkit/modules/path_rail_tool/path_curve_actions.gd").perform(
						active_curve_node as Path3D, "toolkit_add_point_at_world_pos", [hit_pos, true], undo_redo)
					_update_path_rail_info()
					return 1 # AFTER_GUI_INPUT_STOP

				lbl_status_banner.text = "No ground found here. Click on a surface with collision. ESC finishes drawing."
				return 1

		return 0 # AFTER_GUI_INPUT_PASS

	if not is_stamp_active or selected_prefab_path.is_empty():
		return 0 # AFTER_GUI_INPUT_PASS

	# Taste [R] zum Drehen oder [Escape] zum Abbrechen
	if event is InputEventKey and event.pressed:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_R:
			rotate_stamp(45.0)
			return 1 # AFTER_GUI_INPUT_STOP
		elif key_event.keycode == KEY_ESCAPE:
			set_stamp_active(false)
			return 1 # AFTER_GUI_INPUT_STOP

	# Mausbewegung: Position aktualisieren
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var hit_pos := _raycast_ground(camera, mouse_event.position)
		if hit_pos != Vector3.INF:
			_update_ghost_position(hit_pos)
		return 0 # AFTER_GUI_INPUT_PASS

	# Mausklick: Platzieren oder Abbrechen
	if event is InputEventMouseButton and event.pressed:
		var mouse_btn := event as InputEventMouseButton
		if mouse_btn.button_index == MOUSE_BUTTON_RIGHT:
			# Rechtsklick = Stempel-Modus beenden
			set_stamp_active(false)
			return 1 # AFTER_GUI_INPUT_STOP

		elif mouse_btn.button_index == MOUSE_BUTTON_LEFT:
			# Linksklick = Platzieren!
			var hit_pos := _raycast_ground(camera, mouse_btn.position)
			if hit_pos != Vector3.INF:
				_stamp_object_at(hit_pos, undo_redo)
				return 1 # AFTER_GUI_INPUT_STOP

	return 0 # AFTER_GUI_INPUT_PASS


func _raycast_ground(camera: Camera3D, mouse_pos: Vector2) -> Vector3:
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)

	# 1. Physics Raycast gegen den Boden/Collider in der Welt (z.B. Pier)
	var space_state := camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1000.0)

	# Ghost-Collider ausschließen
	var exclude_rids: Array[RID] = []
	if preview_instance and is_instance_valid(preview_instance):
		_get_all_collision_rids(preview_instance, exclude_rids)
	query.exclude = exclude_rids

	var result := space_state.intersect_ray(query)
	var raw_pos := Vector3.INF

	if not result.is_empty() and result.has("position"):
		raw_pos = result["position"]
	else:
		# Fallback: Schnittpunkt mit Bodenebene Y = 0
		var plane := Plane(Vector3.UP, 0.0)
		var intersect = plane.intersects_ray(from, dir)
		if intersect != null:
			raw_pos = intersect

	if raw_pos == Vector3.INF:
		return Vector3.INF

	# Grid Snapping anwenden
	var final_pos := raw_pos
	if snap_enabled and snap_distance > 0.0:
		final_pos.x = roundf(raw_pos.x / snap_distance) * snap_distance
		final_pos.z = roundf(raw_pos.z / snap_distance) * snap_distance

	final_pos.y += height_offset
	return final_pos


func _update_ghost_position(pos: Vector3) -> void:
	if not preview_instance or not is_instance_valid(preview_instance):
		_update_preview_ghost()

	if preview_instance and is_instance_valid(preview_instance):
		preview_instance.global_position = pos
		preview_instance.rotation_degrees.y = current_rotation
		preview_instance.visible = true


func _stamp_object_at(pos: Vector3, undo_redo: EditorUndoRedoManager) -> void:
	var edited_root := _get_edited_root()
	if not edited_root:
		return

	var scene := ResourceLoader.load(selected_prefab_path) as PackedScene
	if not scene:
		return

	var instance := scene.instantiate() as Node3D
	if not instance:
		return

	# Sauberer Name: z.B. ObjChest_01
	var clean_base: String = selected_prefab_name.get_slice(" ", 0).capitalize().replace(" ", "")
	if clean_base.is_empty():
		clean_base = "WorldObject"
	instance.name = clean_base

	instance.position = pos
	instance.rotation_degrees.y = current_rotation

	# Automatische Kurven-Isolation für Wege & Rails (verhindert geteilte SubResource-Kurven)
	if instance is Path3D and (instance as Path3D).curve:
		(instance as Path3D).curve = (instance as Path3D).curve.duplicate(true)

	# Ziel-Container suchen (z.B. WorldObjects oder direkt unter Root)
	var target_parent: Node = edited_root
	var objects_folder := edited_root.find_child("WorldObjects", false, false)
	if objects_folder:
		target_parent = objects_folder

	# Undo / Redo Aktion registrieren
	if undo_redo:
		undo_redo.create_action("Jalura Palette: " + selected_prefab_name + " platzieren")
		undo_redo.add_do_method(target_parent, "add_child", instance)
		undo_redo.add_do_property(instance, "owner", edited_root)
		undo_redo.add_do_reference(instance)
		undo_redo.add_undo_method(target_parent, "remove_child", instance)
		undo_redo.commit_action()
	else:
		target_parent.add_child(instance)
		instance.owner = edited_root

	print_rich("[color=green][b]✔ [Jalura Palette][/b][/color] Platziert: [b]%s[/b] an Position %s (Drehung: %d°)" % [instance.name, str(pos), int(current_rotation)])

	# Preview an aktueller Position auffrischen
	_update_preview_ghost()
