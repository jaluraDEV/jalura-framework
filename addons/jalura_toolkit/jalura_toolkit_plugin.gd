@tool
extends EditorPlugin

## Jalura Toolkit: Zentrales Editor-Plugin für Leveldesign, Wegenetz und Objekterstellung.

const Generator = preload("res://addons/jalura_toolkit/modules/object_converter/object_converter_generator.gd")
const ContextMenuPlugin = preload("res://addons/jalura_toolkit/modules/object_converter/object_converter_context_menu.gd")
const ConverterDialog = preload("res://addons/jalura_toolkit/modules/object_converter/object_converter_dialog.gd")
const ValidatorDock = preload("res://addons/jalura_toolkit/modules/live_validator/validator_dock.gd")
const TargetLinkGizmoPlugin = preload("res://addons/jalura_toolkit/modules/viewport_gizmos/target_link_gizmo_plugin.gd")
const CameraRailGizmoPlugin = preload("res://addons/jalura_toolkit/modules/viewport_gizmos/camera_rail_gizmo_plugin.gd")
const JaluraStudioContainer = preload("res://addons/jalura_toolkit/modules/studio/jalura_studio_container.gd")
const AssetPaletteDock = preload("res://addons/jalura_toolkit/modules/asset_palette/asset_palette_dock.gd")
const ItemConverterGenerator = preload("res://addons/jalura_toolkit/modules/item_converter/item_converter_generator.gd")
const ItemConverterDialog = preload("res://addons/jalura_toolkit/modules/item_converter/item_converter_dialog.gd")
const PathRailInspectorPluginClass = preload("res://addons/jalura_toolkit/modules/path_rail_tool/path_rail_inspector_plugin.gd")

var context_menu_plugin: EditorContextMenuPlugin
var converter_dialog: ConfirmationDialog
var item_converter_dialog: ConfirmationDialog
var validator_dock: Control
var validator_button: Button
var target_link_gizmo: EditorNode3DGizmoPlugin
var camera_rail_gizmo: EditorNode3DGizmoPlugin
var studio_container: JaluraStudioContainer
var palette_dock: Control
var path_rail_inspector_plugin: EditorInspectorPlugin

func _enter_tree() -> void:
	# 1. Dialoge initialisieren
	converter_dialog = ConverterDialog.new()
	EditorInterface.get_base_control().add_child(converter_dialog)

	item_converter_dialog = ItemConverterDialog.new()
	EditorInterface.get_base_control().add_child(item_converter_dialog)

	# 2. FileSystem-Kontextmenü für 3D-Modelle registrieren
	if ClassDB.class_exists("EditorContextMenuPlugin"):
		context_menu_plugin = ContextMenuPlugin.new()
		context_menu_plugin.convert_requested.connect(_on_convert_requested)
		add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, context_menu_plugin)

	# 3. Menüeinträge unter Projekt -> Tools
	add_tool_menu_item("Jalura Toolkit: Object Converter...", _open_converter_dialog)
	add_tool_menu_item("Jalura Toolkit: New Inventory Item...", _open_item_converter_dialog)

	# 4. Live-Diagnose & Validator Dock (Bottom Panel)
	validator_dock = ValidatorDock.new()
	validator_button = add_control_to_bottom_panel(validator_dock, "🛡️ Jalura Diagnose")
	if validator_dock is JaluraValidatorDock:
		(validator_dock as JaluraValidatorDock).bottom_bar_button = validator_button

	# 5. 3D Viewport Gizmos (Verbindungslinien für Hebel, Schalter & Türen)
	target_link_gizmo = TargetLinkGizmoPlugin.new()
	add_node_3d_gizmo_plugin(target_link_gizmo)

	# 5b. 3D Viewport Gizmos (Diorama-Kameraschienen & Bewegungsgrenzen)
	camera_rail_gizmo = CameraRailGizmoPlugin.new()
	add_node_3d_gizmo_plugin(camera_rail_gizmo)

	# 6. Zentrales Studio (Hauptansicht im Editor: Weltkarte & Quests)
	studio_container = JaluraStudioContainer.new()
	EditorInterface.get_editor_main_screen().add_child(studio_container)
	studio_container.hide()

	# 7. Leveldesign Asset-Palette (Dock in Seitenleiste)
	palette_dock = AssetPaletteDock.new()
	if palette_dock is JaluraAssetPaletteDock:
		(palette_dock as JaluraAssetPaletteDock).plugin = self
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, palette_dock)
	set_input_event_forwarding_always_enabled()

	# 8. Inspector Plugin für Wege (TrailPath3D) & Rails (Rail3D)
	path_rail_inspector_plugin = PathRailInspectorPluginClass.new()
	(path_rail_inspector_plugin as PathRailInspectorPlugin).toolkit_plugin = self
	add_inspector_plugin(path_rail_inspector_plugin)

	# Auto-Refresh für Gizmos bei Selektion und Szenenwechsel
	if EditorInterface.get_selection():
		EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	scene_changed.connect(_on_scene_changed)

	# Aktuell geöffnete Szene sofort aktualisieren
	call_deferred("_refresh_current_scene_gizmos")

	print_rich("[color=green][b]✔ [Jalura Toolkit][/b][/color] Editor Plugin loaded successfully.")


func _exit_tree() -> void:
	if EditorInterface.get_selection() and EditorInterface.get_selection().selection_changed.is_connected(_on_selection_changed):
		EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)

	if studio_container:
		studio_container.queue_free()
		studio_container = null

	if palette_dock:
		remove_control_from_docks(palette_dock)
		palette_dock.queue_free()
		palette_dock = null

	if path_rail_inspector_plugin:
		remove_inspector_plugin(path_rail_inspector_plugin)
		path_rail_inspector_plugin = null

	if context_menu_plugin:
		remove_context_menu_plugin(context_menu_plugin)
		context_menu_plugin = null

	remove_tool_menu_item("Jalura Toolkit: Object Converter...")
	remove_tool_menu_item("Jalura Toolkit: New Inventory Item...")

	if validator_dock:
		remove_control_from_bottom_panel(validator_dock)
		validator_dock.queue_free()
		validator_dock = null

	if target_link_gizmo:
		remove_node_3d_gizmo_plugin(target_link_gizmo)
		target_link_gizmo = null

	if camera_rail_gizmo:
		remove_node_3d_gizmo_plugin(camera_rail_gizmo)
		camera_rail_gizmo = null

	if converter_dialog:
		converter_dialog.queue_free()
		converter_dialog = null

	if item_converter_dialog:
		item_converter_dialog.queue_free()
		item_converter_dialog = null

	print("[Jalura Toolkit] Plugin deaktiviert.")


# ==========================================
# HAUPTANSICHT (MAIN SCREEN TAB: 🧭 Jalura Studio)
# ==========================================

func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "🧭 Jalura Studio"


func _get_plugin_icon() -> Texture2D:
	if EditorInterface.get_editor_theme().has_icon("Node", "EditorIcons"):
		return EditorInterface.get_editor_theme().get_icon("Node", "EditorIcons")
	return null


func _make_visible(visible: bool) -> void:
	if studio_container:
		studio_container.visible = visible
		if visible:
			studio_container.refresh_active_tab()


# ==========================================
# 3D VIEWPORT INPUT FORWARDING (STEMPEL & WEG/RAIL ZEICHNEN)
# ==========================================

func _forward_3d_gui_input(viewport_camera: Camera3D, event: InputEvent) -> int:
	if palette_dock and palette_dock is JaluraAssetPaletteDock:
		var dock := palette_dock as JaluraAssetPaletteDock
		if dock.is_stamp_active or dock.is_path_draw_active:
			return dock.handle_3d_gui_input(viewport_camera, event, get_undo_redo())
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _on_selection_changed() -> void:
	if not EditorInterface.get_selection():
		return
	var nodes := EditorInterface.get_selection().get_selected_nodes()
	for node in nodes:
		if node is Node3D:
			node.update_gizmos()
	if palette_dock and palette_dock is JaluraAssetPaletteDock:
		(palette_dock as JaluraAssetPaletteDock).on_editor_selection_changed(nodes)


func _on_scene_changed(root: Node) -> void:
	if root:
		_refresh_gizmos_recursive(root)


func _refresh_current_scene_gizmos() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root:
		_refresh_gizmos_recursive(root)


func _refresh_gizmos_recursive(node: Node) -> void:
	if node is Node3D:
		node.update_gizmos()
	for child in node.get_children():
		_refresh_gizmos_recursive(child)


func _on_convert_requested(paths: PackedStringArray, type_key: String) -> void:
	if paths.is_empty():
		return

	# 1. Neues modulares Inventar-Item Dialog
	if type_key == "item_dialog":
		for p in paths:
			var ext := p.get_extension().to_lower()
			if ext in ["glb", "gltf", "obj"]:
				if item_converter_dialog:
					item_converter_dialog.open_for_model(p)
				return
		return

	# 2. Neues modulares Inventar-Item (Schnell-Modus)
	if type_key == "item_quick":
		var item_count := 0
		for p in paths:
			var ext := p.get_extension().to_lower()
			if ext not in ["glb", "gltf", "obj"]:
				continue
			var res := ItemConverterGenerator.create_item_from_model(p)
			if res.get("success", false):
				item_count += 1
		if item_count > 0:
			print_rich("[color=green][b]✔ [Jalura Toolkit][/b][/color] Quick creation: %d item(s) & pickups generated successfully." % item_count)
		return

	# 3. Weltobjekt Benutzerdefiniert Dialog
	if type_key == "custom":
		for p in paths:
			var ext := p.get_extension().to_lower()
			if ext in ["glb", "gltf", "obj"]:
				converter_dialog.open_for_model(p, "chest")
				return
		return

	# 4. Direkte 1-Klick Konvertierung für Weltobjekte
	var count := 0
	var single_target := (paths.size() == 1)

	for p in paths:
		var ext := p.get_extension().to_lower()
		if ext not in ["glb", "gltf", "obj"]:
			continue

		var res := Generator.convert_model(p, type_key, {
			"open_scene": single_target
		})
		if res.get("success", false):
			count += 1

	if paths.size() > 1:
		print_rich("[color=green][b]✔ [Jalura Toolkit][/b][/color] Batch creation completed: %d / %d objects generated." % [count, paths.size()])


func _open_converter_dialog() -> void:
	if converter_dialog:
		converter_dialog.open_for_model("", "chest")


func _open_item_converter_dialog() -> void:
	if item_converter_dialog:
		item_converter_dialog.open_for_model("")
