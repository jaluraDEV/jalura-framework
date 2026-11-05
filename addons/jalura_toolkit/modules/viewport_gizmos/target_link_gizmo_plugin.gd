@tool
class_name JaluraTargetLinkGizmoPlugin
extends EditorNode3DGizmoPlugin

## 3D Viewport Gizmo Plugin that renders colored direction lines and arrows
## between switches, levers, pressure plates and their target doors, gates or mechanisms.

const InteractiveObject = preload("res://scripts/interaction/interactive_object.gd")
const ActivateTargetAction = preload("res://scripts/interaction/actions/activate_target_action.gd")

func _init() -> void:
	# Unshaded colored materials for connection lines (on_top=true for X-Ray visibility)
	create_material("link_open", Color(0.2, 1.0, 0.3, 1.0), false, true)     # Green: open / activate
	create_material("link_toggle", Color(1.0, 0.85, 0.1, 1.0), false, true)   # Yellow: toggle
	create_material("link_close", Color(1.0, 0.25, 0.2, 1.0), false, true)    # Red: close / deactivate
	create_material("link_default", Color(0.2, 0.75, 1.0, 1.0), false, true)  # Cyan: custom / generic
	create_material("link_broken", Color(1.0, 0.1, 0.1, 1.0), false, true)   # Deep Red: missing target


func _get_gizmo_name() -> String:
	return "Jalura Target Links"


func _has_gizmo(for_node_3d: Node3D) -> bool:
	if not for_node_3d:
		return false

	# Check for target_objects property on root or children
	if "target_objects" in for_node_3d:
		return true

	for child in for_node_3d.get_children():
		if "target_objects" in child:
			return true

	if for_node_3d is InteractiveObject:
		var hub := for_node_3d as InteractiveObject
		# Check triggers for ActivateTargetAction
		for trig in hub.triggers:
			if trig:
				for act in trig.actions:
					if act is ActivateTargetAction:
						return true

	return false


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var node := gizmo.get_node_3d()
	if not node:
		return

	# Collect all (target_path, method) pairs
	var links: Array[Dictionary] = []
	_collect_links(node, links)

	if links.is_empty():
		return

	var start_local := Vector3(0, 0.3, 0)
	var up_offset := Vector3(0, 1.0, 0)

	for link in links:
		var target_path: NodePath = link["target_path"]
		var method: String = link["method"].to_lower()

		var target_node := _resolve_target_node(node, target_path)

		if target_node:
			var target_pos_local := node.to_local(target_node.global_position + up_offset)
			var lines := PackedVector3Array()

			# Main line
			lines.push_back(start_local)
			lines.push_back(target_pos_local)

			# 3D Arrowhead at target
			_append_arrow_head(lines, start_local, target_pos_local)

			# Small 3D cross marker at start
			_append_marker(lines, start_local, 0.25)

			# Choose material
			var mat_name := "link_default"
			if method in ["open", "activate", "unlock"]:
				mat_name = "link_open"
			elif method in ["close", "deactivate", "lock"]:
				mat_name = "link_close"
			elif method in ["toggle", "trigger"]:
				mat_name = "link_toggle"

			var mat := get_material(mat_name, gizmo)
			gizmo.add_lines(lines, mat, false)
			print_rich("[color=yellow][b]🔗 [Jalura Gizmo][/b][/color] Verbindung aktiv: [b]%s[/b] ➔ [b]%s[/b] (Aktion: %s)" % [node.name, target_node.name, method])
		else:
			# Target node is missing/broken - draw a warning cross
			var broken_lines := PackedVector3Array()
			var broken_mat := get_material("link_broken", gizmo)
			_append_broken_indicator(broken_lines, start_local)
			gizmo.add_lines(broken_lines, broken_mat, false)
			print_rich("[color=red][b]⚠️ [Jalura Gizmo][/b][/color] Ungültiges Ziel bei [b]%s[/b]: Pfad '%s' nicht gefunden!" % [node.name, str(target_path)])


func _append_marker(lines: PackedVector3Array, pos: Vector3, radius: float) -> void:
	lines.push_back(pos + Vector3(-radius, 0, 0))
	lines.push_back(pos + Vector3(radius, 0, 0))
	lines.push_back(pos + Vector3(0, -radius, 0))
	lines.push_back(pos + Vector3(0, radius, 0))
	lines.push_back(pos + Vector3(0, 0, -radius))
	lines.push_back(pos + Vector3(0, 0, radius))


func _collect_links(node: Node3D, out_links: Array[Dictionary]) -> void:
	# 1. Direct target_objects on node
	if "target_objects" in node:
		var paths = node.get("target_objects")
		var method: String = str(node.get("target_method")) if "target_method" in node else "toggle"
		if paths is Array:
			for p in paths:
				if p is NodePath and not p.is_empty():
					out_links.append({"target_path": p, "method": method})

	# 2. Child behaviors (e.g. SwitchBehavior, PressurePlateBehavior)
	for child in node.get_children():
		if "target_objects" in child:
			var paths = child.get("target_objects")
			var method: String = str(child.get("target_method")) if "target_method" in child else "toggle"
			if paths is Array:
				for p in paths:
					if p is NodePath and not p.is_empty():
						out_links.append({"target_path": p, "method": method})

	# 3. Triggers with ActivateTargetAction
	if node is InteractiveObject:
		var hub := node as InteractiveObject
		for trig in hub.triggers:
			if trig:
				for act in trig.actions:
					if act is ActivateTargetAction:
						var ata := act as ActivateTargetAction
						if not ata.target_path.is_empty():
							out_links.append({
								"target_path": ata.target_path,
								"method": ata.method if not ata.method.is_empty() else "activate"
							})


func _resolve_target_node(source_node: Node3D, target_path: NodePath) -> Node3D:
	if target_path.is_empty():
		return null

	# Check relative to source node
	var res := source_node.get_node_or_null(target_path)

	# Check relative to source's parent
	if not res and source_node.get_parent():
		res = source_node.get_parent().get_node_or_null(target_path)

	# Check relative to scene root
	if not res and source_node.is_inside_tree():
		var scene_root := source_node.get_tree().edited_scene_root
		if not scene_root:
			scene_root = source_node.get_tree().current_scene
		if scene_root:
			res = scene_root.get_node_or_null(target_path)
			if not res:
				res = scene_root.find_child(str(target_path).get_file(), true, false)

	return res as Node3D if res is Node3D else null


func _append_arrow_head(lines: PackedVector3Array, from_pos: Vector3, to_pos: Vector3) -> void:
	var delta := to_pos - from_pos
	var dist := delta.length()
	if dist < 0.2:
		return

	var dir := delta.normalized()
	var wing_length: float = minf(0.5, dist * 0.25)
	var wing_width: float = wing_length * 0.55

	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var right := dir.cross(up).normalized() * wing_width
	var vert := dir.cross(right).normalized() * wing_width
	var back := -dir * wing_length

	# 4 wing lines to form a 3D pyramid/arrowhead
	lines.push_back(to_pos)
	lines.push_back(to_pos + back + right)

	lines.push_back(to_pos)
	lines.push_back(to_pos + back - right)

	lines.push_back(to_pos)
	lines.push_back(to_pos + back + vert)

	lines.push_back(to_pos)
	lines.push_back(to_pos + back - vert)


func _append_broken_indicator(lines: PackedVector3Array, origin: Vector3) -> void:
	var s := 0.25
	# Red warning X
	lines.push_back(origin + Vector3(-s, s, 0))
	lines.push_back(origin + Vector3(s, -s, 0))

	lines.push_back(origin + Vector3(s, s, 0))
	lines.push_back(origin + Vector3(-s, -s, 0))
