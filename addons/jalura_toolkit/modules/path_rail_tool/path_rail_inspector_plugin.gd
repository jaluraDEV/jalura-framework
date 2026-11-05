@tool
class_name PathRailInspectorPlugin
extends EditorInspectorPlugin

## Inspector-Plugin für TrailPath3D und Rail3D.
## Ersetzt die unhandlichen Checkboxen durch echte, intuitive Buttons mit 1-Klick-Aktionen.

var toolkit_plugin: EditorPlugin = null

func _can_handle(object: Object) -> bool:
	return (object is Path3D) and (object.has_method("toolkit_make_curve_unique") or object.has_method("_toolkit_make_curve_unique"))

func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if name == "apply_preset":
		return object.get_script().resource_path.ends_with("/rail_3d.gd")
	# Verstecke die alten Checkbox-Trigger im Standard-Inspector, da sie oben als echte Buttons dargestellt werden
	if name in ["make_curve_unique", "snap_points_to_ground", "auto_smooth_tangents", "reverse_direction", "extend_path_5m", "extend_rail_5m", "remove_last_point"]:
		return true
	return false

func _parse_begin(object: Object) -> void:
	if not object is Path3D:
		return
	var path_node := object as Path3D

	var container := VBoxContainer.new()
	container.add_theme_constant_override("separation", 6)

	var header := Label.new()
	var script_path: String = path_node.get_script().resource_path if path_node.get_script() else ""
	var is_trail := script_path.contains("trail")
	header.text = "🛣️ Weg-Werkzeuge (TrailPath3D)" if is_trail else "🎢 Schienen-Werkzeuge (Rail3D)"
	header.modulate = Color(0.4, 0.8, 1.0)
	header.add_theme_font_size_override("font_size", 12)
	container.add_child(header)

	var guide := Label.new()
	guide.text = "1. Form wählen oder Strecke weiterzeichnen.\n2. Im 3D-Fenster auf den Boden klicken.\n3. Mit Esc oder Rechtsklick fertig werden.\nStrg+Z macht deine Werkzeug-Aktion rückgängig."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(guide)

	if not is_trail:
		var presets := OptionButton.new()
		presets.add_item("Select Preset Shape …")
		for title in ["Standard S-Kurve (20m)", "Gerade Linie (25m)", "Große Schanze / Kicker", "U-Turn (180 Grad)", "Endlos-Rundkurs (Loop)"]:
			presets.add_item(title)
		presets.tooltip_text = "Ersetzt die aktuelle Form. Mit Strg+Z bekommst du deine vorherige Strecke zurück."
		presets.item_selected.connect(func(index: int):
			if index > 0:
				var chosen := presets.get_item_text(index)
				presets.select(0)
				_run_action(path_node, "_toolkit_apply_preset", [chosen])
		)
		container.add_child(presets)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(status)
	var refresh_status := func():
		if not is_instance_valid(path_node):
			return
		var count := path_node.curve.point_count if path_node.curve else 0
		if count < 2:
			status.text = "Noch nicht fertig: Du brauchst mindestens zwei Punkte. Wähle eine Form oder zeichne weiter."
		elif path_node.curve.get_baked_length() < 0.1:
			status.text = "Die Punkte liegen zu dicht zusammen. Zeichne den nächsten Punkt weiter entfernt."
		else:
			status.text = "%d Punkte · %.1f m Strecke. Jetzt im Spiel ausprobieren!" % [count, path_node.curve.get_baked_length()]
	var timer := Timer.new()
	timer.wait_time = 0.4
	timer.autostart = true
	timer.timeout.connect(refresh_status)
	container.add_child(timer)
	refresh_status.call()

	# Click-to-Draw Button
	var btn_draw := Button.new()
	btn_draw.text = "✏️ Strecke weiterzeichnen"
	btn_draw.modulate = Color(0.4, 1.0, 0.6)
	btn_draw.custom_minimum_size = Vector2(0, 30)
	btn_draw.tooltip_text = "Aktiviert den Klick-Zeichenmodus: Klicke direkt im 3D-Viewport auf den Boden, um Punkte zu setzen!"
	btn_draw.pressed.connect(func():
		if toolkit_plugin and "palette_dock" in toolkit_plugin and toolkit_plugin.palette_dock:
			toolkit_plugin.palette_dock.set_path_draw_active_for(path_node, true)
	)
	container.add_child(btn_draw)

	var finish := Button.new()
	finish.text = "✓ Finish Drawing"
	finish.pressed.connect(func():
		if toolkit_plugin and toolkit_plugin.palette_dock:
			toolkit_plugin.palette_dock.set_path_draw_active(false)
	)
	container.add_child(finish)

	# Quick-Actions Grid (2 Spalten)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)

	# Extend +5m
	var btn_extend := Button.new()
	btn_extend.text = "➕ +5m Extend"
	btn_extend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_extend.tooltip_text = "Verlängert den Pfad um 5 Meter in Vorwärtsrichtung"
	btn_extend.pressed.connect(func():
		_run_action(path_node, "toolkit_extend", [5.0])
	)
	grid.add_child(btn_extend)

	# Remove Last
	var btn_remove := Button.new()
	btn_remove.text = "🗑️ Delete Last"
	btn_remove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_remove.tooltip_text = "Löscht den zuletzt gesetzten Kurvenpunkt"
	btn_remove.pressed.connect(func():
		_run_action(path_node, "toolkit_remove_last", [])
	)
	grid.add_child(btn_remove)

	# Auto Smooth
	var btn_smooth := Button.new()
	btn_smooth.text = "✨ Smooth Curve"
	btn_smooth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_smooth.tooltip_text = "Berechnet harmonische Bezier-Tangenten für alle Punkte"
	btn_smooth.pressed.connect(func():
		_run_action(path_node, "toolkit_auto_smooth", [])
	)
	grid.add_child(btn_smooth)

	# Snap Ground
	var btn_snap := Button.new()
	btn_snap.text = "📌 An Boden heften"
	btn_snap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_snap.tooltip_text = "Snappt alle Kontrollpunkte per Raycast an den Insel-Boden"
	btn_snap.pressed.connect(func():
		_run_action(path_node, "toolkit_snap_to_ground", [])
	)
	grid.add_child(btn_snap)

	# Reverse
	var btn_rev := Button.new()
	btn_rev.text = "🔄 Richtung umkehren"
	btn_rev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rev.tooltip_text = "Kehrt Start und Ende des Pfades/der Schiene um"
	btn_rev.pressed.connect(func():
		_run_action(path_node, "toolkit_reverse", [])
	)
	grid.add_child(btn_rev)

	# Make Unique
	var btn_unique := Button.new()
	btn_unique.text = "🔀 Make Unique"
	btn_unique.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_unique.tooltip_text = "Klont die Curve3D unabhängig, damit andere Szenen unberührt bleiben"
	btn_unique.pressed.connect(func():
		_run_action(path_node, "toolkit_make_curve_unique", [])
	)
	grid.add_child(btn_unique)

	container.add_child(grid)
	container.add_child(HSeparator.new())

	add_custom_control(container)


func _run_action(path: Path3D, method: String, args: Array) -> void:
	preload("res://addons/jalura_toolkit/modules/path_rail_tool/path_curve_actions.gd").perform(
		path, method, args, toolkit_plugin.get_undo_redo() if toolkit_plugin else null)
