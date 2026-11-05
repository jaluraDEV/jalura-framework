@tool
class_name Rail3D
extends Path3D

## Rail3D
## Dynamische Schiene für Barnaby Rail-Grinding.
## Basiert auf Path3D: Im Editor können Kurvenpunkte frei platziert und mit Bezier-Handles gebogen werden.
## Erzeugt automatisch in Echtzeit ein 3D-Rohr-Mesh (Einzel- oder Doppelschiene) mit UVs und Normalen.

@export_group("🛠️ Rail Toolkit (Editor Helpers)")
## Dupliziert die Kurve, damit Änderungen an dieser Rail NICHT andere Rails oder die Original-Szene verändern!
@export var make_curve_unique: bool = false:
	set(v):
		if v:
			_toolkit_make_curve_unique()
			make_curve_unique = false
			notify_property_list_changed()

## Wähle eine fertige Kurvenform aus, um sofort eine saubere Strecke zu erhalten.
@export_enum("--- Select Preset ---", "Standard S-Curve (20m)", "Straight Line (25m)", "Big Jump / Kicker", "U-Turn (180 Deg)", "Endless Loop") var apply_preset: String = "--- Select Preset ---":
	set(v):
		if v != "--- Select Preset ---":
			_toolkit_apply_preset(v)
			apply_preset = "--- Select Preset ---"

## Berechnet automatisch weiche, harmonische Bezier-Griffe (Tangenten) für alle Punkte, um Kanten/Knicke zu entfernen.
@export var auto_smooth_tangents: bool = false:
	set(v):
		if v:
			_toolkit_auto_smooth()
			auto_smooth_tangents = false
			notify_property_list_changed()

## Kehrt Start- und Endpunkt sowie Fahrtrichtung der Schiene um.
@export var reverse_direction: bool = false:
	set(v):
		if v:
			_toolkit_reverse()
			reverse_direction = false
			notify_property_list_changed()

## Verlängert die Schiene am Ende um 5 Meter in Fahrtrichtung.
@export var extend_rail_5m: bool = false:
	set(v):
		if v:
			_toolkit_extend(5.0)
			extend_rail_5m = false
			notify_property_list_changed()

## Löscht den letzten Punkt der Schiene (mindestens 2 Punkte bleiben erhalten).
@export var remove_last_point: bool = false:
	set(v):
		if v:
			_toolkit_remove_last()
			remove_last_point = false
			notify_property_list_changed()

## Passt alle Kurvenpunkte automatisch an die Geländehöhe (Boden/Insel/Docks) an (+ ground_offset).
@export var snap_points_to_ground: bool = false:
	set(v):
		if v:
			_toolkit_snap_to_ground()
			snap_points_to_ground = false
			notify_property_list_changed()

@export var ground_offset: float = 1.2 ## Gewünschte Schienenhöhe über dem Boden beim Snappen (Standard: 1.2m)

@export_group("Visuals & Profile")
@export var rail_material: Material:
	set(v):
		rail_material = v
		_regenerate_mesh()
@export var pipe_radius: float = 0.075:
	set(v):
		pipe_radius = maxf(0.01, v)
		_regenerate_mesh()
@export var pipe_sides: int = 8:
	set(v):
		pipe_sides = maxi(3, v)
		_regenerate_mesh()
@export var double_pipe: bool = false:
	set(v):
		double_pipe = v
		_regenerate_mesh()
@export var pipe_spacing: float = 0.35:
	set(v):
		pipe_spacing = maxf(0.05, v)
		_regenerate_mesh()
@export var smooth_step_dist: float = 0.35:
	set(v):
		smooth_step_dist = maxf(0.05, v)
		_regenerate_mesh()

@export_group("🏗️ Support Pillars")
## Erzeugt automatisch vertikale Stützpfeiler von der Schiene zum Boden
@export var generate_pillars: bool = true:
	set(v):
		generate_pillars = v
		_regenerate_mesh()

## Abstand zwischen zwei Stützpfeilern in Metern (z.B. 6.0m)
@export_range(1.0, 30.0, 0.5) var pillar_spacing: float = 6.0:
	set(v):
		pillar_spacing = maxf(1.0, v)
		_regenerate_mesh()

## Radius der zylindrischen Stützpfeiler (z.B. 0.055m)
@export_range(0.02, 0.25, 0.005) var pillar_radius: float = 0.055:
	set(v):
		pillar_radius = maxf(0.01, v)
		_regenerate_mesh()

## Maximale Höhe / Tiefe, bis zu der ein Pfeiler nach unten reicht
@export var max_pillar_height: float = 35.0:
	set(v):
		max_pillar_height = maxf(1.0, v)
		_regenerate_mesh()

## Eigenes Material für die Stützpfeiler (falls leer, wird das Rail-Material genutzt)
@export var pillar_material: Material:
	set(v):
		pillar_material = v
		_regenerate_mesh()

@export_group("Grind Gameplay")
@export var min_grind_speed: float = 10.5         ## Mindest-Grind-Geschwindigkeit (m/s)
@export var max_grind_speed: float = 21.0         ## Maximale Grind-Geschwindigkeit (m/s)
@export var grind_downhill_accel: float = 15.0    ## Beschleunigung bei Gefälle (m/s^2)
@export var grind_uphill_decel: float = 9.5       ## Abbremsung bei Steigung (m/s^2)
@export var grind_brake_force: float = 16.0       ## Bremse bei gehaltener Ducken-Taste (m/s^2)
@export var grind_dash_boost: float = 8.5         ## Speed-Impuls bei Dash-Taste auf der Schiene
@export var snap_distance: float = 1.35           ## Max. Distanz, ab der Barnaby auf die Schiene einrastet

var _mesh_instance: MeshInstance3D
var _pillars_mesh: MeshInstance3D

func _enter_tree() -> void:
	_auto_ensure_unique_curve()
	if curve and not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	_ensure_mesh_instance()
	_ensure_pillars_mesh()
	_regenerate_mesh()
	update_configuration_warnings()

func _ready() -> void:
	add_to_group("rails")
	if not rail_material:
		rail_material = preload("res://assets/umgebung/plattformen/rail_material.tres")
		
	_auto_ensure_unique_curve()
	_ensure_mesh_instance()
	_ensure_pillars_mesh()
	_regenerate_mesh()
	
	if curve and not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	update_configuration_warnings()

func _auto_ensure_unique_curve() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree() or not curve:
		return
	var edited_root := get_tree().edited_scene_root if get_tree() else null
	# Wenn diese Instanz in einer übergeordneten Szene (z.B. overworld.tscn) liegt,
	# trennen wir sie automatisch vom Template ab, um synchrone Verformungen zu verhindern!
	if edited_root and edited_root != self:
		if curve.resource_path.begins_with("res://szenen/world/rail_3d.tscn") or curve.resource_name == "template_curve":
			curve = curve.duplicate(true)
			if not curve.changed.is_connected(_on_curve_changed):
				curve.changed.connect(_on_curve_changed)
			update_configuration_warnings()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not curve:
		warnings.append("Deine Schiene hat noch keine Strecke. Wähle oben eine fertige Form oder klicke auf Strecke weiterzeichnen.")
	elif curve.point_count < 2:
		warnings.append("Deine Schiene braucht mindestens zwei Punkte. Zeichne einen weiteren Punkt auf den Boden.")
	elif curve.get_baked_length() < 0.1:
		warnings.append("Die Schiene ist zu kurz. Setze den nächsten Punkt weiter entfernt.")
	return warnings

func _on_curve_changed() -> void:
	_regenerate_mesh()
	update_configuration_warnings()

func _ensure_mesh_instance() -> void:
	_mesh_instance = get_node_or_null("RailMesh") as MeshInstance3D
	if not _mesh_instance:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "RailMesh"
		add_child(_mesh_instance)

func _ensure_pillars_mesh() -> void:
	_pillars_mesh = get_node_or_null("PillarsMesh") as MeshInstance3D
	if not _pillars_mesh:
		_pillars_mesh = MeshInstance3D.new()
		_pillars_mesh.name = "PillarsMesh"
		add_child(_pillars_mesh)

## Regeneriert das 3D-Mesh der Schiene entlang des Path3D-Pfades
func _regenerate_mesh() -> void:
	if not is_inside_tree():
		return
	if not curve or curve.point_count < 2:
		if _mesh_instance:
			_mesh_instance.mesh = null
		if _pillars_mesh:
			_pillars_mesh.mesh = null
		return
		
	_ensure_mesh_instance()
	_ensure_pillars_mesh()
	if not _mesh_instance:
		return
		
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var length := curve.get_baked_length()
	if length <= 0.05:
		return
		
	var steps := int(ceil(length / smooth_step_dist))
	steps = maxi(steps, 2)
	
	# Generate single or double pipe
	if double_pipe:
		_build_pipe_vertices(st, length, steps, -pipe_spacing * 0.5, 0)
		_build_pipe_vertices(st, length, steps, pipe_spacing * 0.5, (steps + 1) * pipe_sides)
	else:
		_build_pipe_vertices(st, length, steps, 0.0, 0)
		
	var m := st.commit()
	if rail_material:
		m.surface_set_material(0, rail_material)
	_mesh_instance.mesh = m

	_regenerate_pillars_mesh()

## Generiert vertikale Stützpfeiler (Support Pillars) von der Schiene zum Untergrund
func _regenerate_pillars_mesh() -> void:
	_ensure_pillars_mesh()
	if not _pillars_mesh:
		return
	if not generate_pillars or not curve or curve.point_count < 2:
		_pillars_mesh.mesh = null
		return

	var length := curve.get_baked_length()
	if length < 0.5:
		_pillars_mesh.mesh = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var space_state: PhysicsDirectSpaceState3D = null
	if is_inside_tree() and get_world_3d():
		space_state = get_world_3d().direct_space_state

	var pillar_offsets: Array[float] = []
	var start_offset := minf(1.0, length * 0.25)
	var end_offset := maxf(start_offset, length - minf(1.0, length * 0.25))

	var curr_dist := start_offset
	while curr_dist <= end_offset:
		pillar_offsets.append(curr_dist)
		curr_dist += pillar_spacing

	if pillar_offsets.is_empty() or absf(pillar_offsets[-1] - end_offset) > pillar_spacing * 0.4:
		if end_offset > start_offset:
			pillar_offsets.append(end_offset)

	var sides := 8
	var total_pillar_verts := 0

	for d_offset in pillar_offsets:
		var trans := curve.sample_baked_with_rotation(d_offset, true, true)
		var rail_center_local := trans.origin
		var rail_center_world := to_global(rail_center_local)

		var ground_world: Vector3 = Vector3.INF
		if space_state:
			var ray_from := rail_center_world - Vector3(0, 0.05, 0)
			var ray_to := rail_center_world + Vector3.DOWN * max_pillar_height
			var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, 1)
			var res := space_state.intersect_ray(query)
			if res and res.has("position"):
				ground_world = res["position"]

		if ground_world == Vector3.INF:
			if rail_center_world.y > 0.3:
				ground_world = Vector3(rail_center_world.x, 0.0, rail_center_world.z)
			else:
				continue

		var ground_local := to_local(ground_world)
		var height := rail_center_local.y - ground_local.y
		if height < 0.2:
			continue

		var base_vert_idx := total_pillar_verts
		var pillar_top := Vector3(rail_center_local.x, rail_center_local.y - pipe_radius * 0.8, rail_center_local.z)
		var pillar_bot := ground_local

		for s in range(sides):
			var angle := (float(s) / float(sides)) * TAU
			var norm := Vector3(cos(angle), 0, sin(angle))
			var u := float(s) / float(sides)

			# Unten
			st.set_normal(norm)
			st.set_uv(Vector2(u, 0.0))
			st.add_vertex(pillar_bot + norm * (pillar_radius * 1.3))

			# Oben
			st.set_normal(norm)
			st.set_uv(Vector2(u, height))
			st.add_vertex(pillar_top + norm * pillar_radius)

		for s in range(sides):
			var s_next := (s + 1) % sides
			var b0 := base_vert_idx + s * 2
			var t0 := base_vert_idx + s * 2 + 1
			var b1 := base_vert_idx + s_next * 2
			var t1 := base_vert_idx + s_next * 2 + 1

			st.add_index(b0)
			st.add_index(t0)
			st.add_index(b1)

			st.add_index(b1)
			st.add_index(t0)
			st.add_index(t1)

		total_pillar_verts += sides * 2

		# Bei Doppelschiene: Horizontale Querverbindung (Crossbar Bracket)
		if double_pipe:
			var bar_base_idx := total_pillar_verts
			var half_span := pipe_spacing * 0.5
			var bar_left := rail_center_local - trans.basis.x * half_span
			var bar_right := rail_center_local + trans.basis.x * half_span
			var bar_rad := pillar_radius * 0.75
			var bar_sides := 6

			for s in range(bar_sides):
				var angle := (float(s) / float(bar_sides)) * TAU
				var local_norm := Vector3(0, cos(angle), sin(angle))
				var world_norm := (trans.basis.y * local_norm.y + trans.basis.z * local_norm.z).normalized()
				var u := float(s) / float(bar_sides)

				st.set_normal(world_norm)
				st.set_uv(Vector2(u, 0.0))
				st.add_vertex(bar_left + world_norm * bar_rad)

				st.set_normal(world_norm)
				st.set_uv(Vector2(u, 1.0))
				st.add_vertex(bar_right + world_norm * bar_rad)

			for s in range(bar_sides):
				var s_next := (s + 1) % bar_sides
				var l0 := bar_base_idx + s * 2
				var r0 := bar_base_idx + s * 2 + 1
				var l1 := bar_base_idx + s_next * 2
				var r1 := bar_base_idx + s_next * 2 + 1

				st.add_index(l0)
				st.add_index(r0)
				st.add_index(l1)

				st.add_index(l1)
				st.add_index(r0)
				st.add_index(r1)

			total_pillar_verts += bar_sides * 2

	if total_pillar_verts == 0:
		_pillars_mesh.mesh = null
		return

	var mesh := st.commit()
	var mat := pillar_material if pillar_material else rail_material
	if mat:
		mesh.surface_set_material(0, mat)
	_pillars_mesh.mesh = mesh


func _build_pipe_vertices(st: SurfaceTool, length: float, steps: int, x_offset: float, base_idx: int) -> void:
	for i in range(steps + 1):
		var d := clampf(float(i) / float(steps) * length, 0.0, length)
		var trans := curve.sample_baked_with_rotation(d, true, true)
		var center := trans.origin + trans.basis.x * x_offset
		var v_coord := d * 0.5 # UV tiling along the pipe
		
		for s in range(pipe_sides):
			var angle := (float(s) / float(pipe_sides)) * TAU
			var normal_local := Vector3(cos(angle), sin(angle), 0.0)
			var normal_world := (trans.basis.x * normal_local.x + trans.basis.y * normal_local.y).normalized()
			var v_pos := center + normal_world * pipe_radius
			var u_coord := float(s) / float(pipe_sides)
			
			st.set_normal(normal_world)
			st.set_uv(Vector2(u_coord, v_coord))
			st.add_vertex(v_pos)
			
	var ring_size := pipe_sides
	for i in range(steps):
		var r0 := base_idx + i * ring_size
		var r1 := base_idx + (i + 1) * ring_size
		for s in range(pipe_sides):
			var s_next := (s + 1) % pipe_sides
			var a := r0 + s
			var b := r0 + s_next
			var c := r1 + s
			var d_idx := r1 + s_next
			
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			
			st.add_index(b)
			st.add_index(d_idx)
			st.add_index(c)

# ---------------------------------------------------------
# Toolkit Helper Funktionen
# ---------------------------------------------------------

func _toolkit_make_curve_unique() -> void:
	if curve:
		curve = curve.duplicate(true)
	else:
		curve = Curve3D.new()
	if not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	_regenerate_mesh()
	notify_property_list_changed()
	update_configuration_warnings()
	print("[Rail3D] 🔀 Kurve ist jetzt 100% unabhängig (Unique)!")

func _toolkit_apply_preset(preset_name: String) -> void:
	var c := Curve3D.new()
	match preset_name:
		"Standard S-Curve (20m)":
			c.add_point(Vector3(0, 1.2, 0), Vector3(0, 0, 0), Vector3(0, 0, 4))
			c.add_point(Vector3(0, 2.5, 10), Vector3(0, 0, -4), Vector3(0, 0, 4))
			c.add_point(Vector3(3.5, 3.2, 20), Vector3(0, 0, -4), Vector3(0, 0, 0))
		"Straight Line (25m)":
			c.add_point(Vector3(0, 1.2, 0), Vector3(0, 0, 0), Vector3(0, 0, 0))
			c.add_point(Vector3(0, 1.2, 25), Vector3(0, 0, 0), Vector3(0, 0, 0))
		"Big Jump / Kicker":
			c.add_point(Vector3(0, 1.0, 0), Vector3(0, 0, 0), Vector3(0, 0, 5))
			c.add_point(Vector3(0, 2.0, 15), Vector3(0, 0, -5), Vector3(0, 0.6, 5))
			c.add_point(Vector3(0, 5.5, 25), Vector3(0, -1.0, -4), Vector3(0, 0, 0))
		"U-Turn (180 Deg)":
			c.add_point(Vector3(0, 1.2, 0), Vector3(0, 0, 0), Vector3(0, 0, 6))
			c.add_point(Vector3(6, 1.2, 12), Vector3(-4, 0, 0), Vector3(4, 0, 0))
			c.add_point(Vector3(12, 1.2, 0), Vector3(0, 0, 6), Vector3(0, 0, 0))
		"Endless Loop":
			c.add_point(Vector3(0, 1.5, 0), Vector3(-3.3, 0, 0), Vector3(3.3, 0, 0))
			c.add_point(Vector3(8, 1.5, 8), Vector3(0, 0, -3.3), Vector3(0, 0, 3.3))
			c.add_point(Vector3(0, 1.5, 16), Vector3(3.3, 0, 0), Vector3(-3.3, 0, 0))
			c.add_point(Vector3(-8, 1.5, 8), Vector3(0, 0, 3.3), Vector3(0, 0, -3.3))
			c.add_point(Vector3(0, 1.5, 0), Vector3(-3.3, 0, 0), Vector3(3.3, 0, 0))
			
	curve = c
	if not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	_regenerate_mesh()
	notify_property_list_changed()
	update_configuration_warnings()
	print("[Rail3D] 🎨 Preset '%s' erfolgreich angewendet!" % preset_name)

func _toolkit_auto_smooth() -> void:
	if not curve or curve.point_count < 2:
		return
	var count := curve.point_count
	var is_closed := curve.get_point_position(0).distance_squared_to(curve.get_point_position(count - 1)) < 0.05
	
	for i in range(count):
		var p_curr := curve.get_point_position(i)
		var p_prev: Vector3
		var p_next: Vector3
		
		if i == 0:
			if is_closed:
				p_prev = curve.get_point_position(count - 2)
			else:
				p_prev = p_curr - (curve.get_point_position(1) - p_curr)
			p_next = curve.get_point_position(1)
		elif i == count - 1:
			p_prev = curve.get_point_position(count - 2)
			if is_closed:
				p_next = curve.get_point_position(1)
			else:
				p_next = p_curr + (p_curr - p_prev)
		else:
			p_prev = curve.get_point_position(i - 1)
			p_next = curve.get_point_position(i + 1)
			
		var dir := (p_next - p_prev).normalized()
		var d_prev := p_curr.distance_to(p_prev)
		var d_next := p_curr.distance_to(p_next)
		
		if i == 0 and not is_closed:
			curve.set_point_in(i, Vector3.ZERO)
			curve.set_point_out(i, dir * (d_next * 0.35))
		elif i == count - 1 and not is_closed:
			curve.set_point_in(i, -dir * (d_prev * 0.35))
			curve.set_point_out(i, Vector3.ZERO)
		else:
			curve.set_point_in(i, -dir * (d_prev * 0.35))
			curve.set_point_out(i, dir * (d_next * 0.35))
			
	_regenerate_mesh()
	notify_property_list_changed()
	print("[Rail3D] ✨ Alle Kurventangenten wurden harmonisch geglättet!")

func _toolkit_reverse() -> void:
	if not curve or curve.point_count < 2:
		return
	var count := curve.point_count
	var new_curve := Curve3D.new()
	for i in range(count - 1, -1, -1):
		var pos := curve.get_point_position(i)
		var tin := -curve.get_point_out(i)
		var tout := -curve.get_point_in(i)
		var tilt := curve.get_point_tilt(i)
		new_curve.add_point(pos, tin, tout)
		new_curve.set_point_tilt(new_curve.point_count - 1, tilt)
	curve = new_curve
	if not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	_regenerate_mesh()
	notify_property_list_changed()
	print("[Rail3D] 🔄 Fahrtrichtung erfolgreich umgekehrt!")

func _toolkit_extend(dist: float) -> void:
	if not curve or curve.point_count < 2:
		return
	var count := curve.point_count
	var last_pos := curve.get_point_position(count - 1)
	var prev_pos := curve.get_point_position(count - 2)
	var dir := (last_pos - prev_pos).normalized()
	var last_out := curve.get_point_out(count - 1)
	if last_out.length_squared() > 0.01:
		dir = last_out.normalized()
	var new_pos := last_pos + dir * dist
	curve.add_point(new_pos, -dir * (dist * 0.35), Vector3.ZERO)
	_regenerate_mesh()
	notify_property_list_changed()
	print("[Rail3D] ➕ Schiene um %.1f Meter verlängert (Neuer Endpunkt: %s)!" % [dist, new_pos])

func _toolkit_remove_last() -> void:
	if not curve or curve.point_count <= 2:
		print("[Rail3D] ⚠️ Mindestens 2 Punkte müssen erhalten bleiben!")
		return
	curve.remove_point(curve.point_count - 1)
	_regenerate_mesh()
	notify_property_list_changed()
	print("[Rail3D] ➖ Letzter Punkt entfernt (Verbleibende Punkte: %d)!" % curve.point_count)

func _toolkit_snap_to_ground() -> void:
	if not curve or curve.point_count == 0:
		return
	var world_3d := get_world_3d()
	if not world_3d:
		print("[Rail3D] Kein World3D verfügbar zum Snappen.")
		return
	var space_state := world_3d.direct_space_state
	if not space_state:
		print("[Rail3D] Kein SpaceState verfügbar zum Snappen.")
		return
	var snapped_count := 0
	for i in range(curve.point_count):
		var local_p := curve.get_point_position(i)
		var world_p := to_global(local_p)
		var ray_from := world_p + Vector3.UP * 50.0
		var ray_to := world_p + Vector3.DOWN * 50.0
		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
		var result := space_state.intersect_ray(query)
		if result and result.has("position"):
			var hit_pos: Vector3 = result["position"]
			var new_world_p := hit_pos + Vector3.UP * ground_offset
			curve.set_point_position(i, to_local(new_world_p))
			snapped_count += 1
	_regenerate_mesh()
	notify_property_list_changed()
	print("[Rail3D] 🏔️ %d / %d Kurvenpunkte an Boden/Kollision angepasst (%.1fm über Boden)!" % [snapped_count, curve.point_count, ground_offset])

# ---------------------------------------------------------
# Öffentliche API für Toolkit & Zeichenmodus
# ---------------------------------------------------------

func toolkit_make_curve_unique() -> void:
	_toolkit_make_curve_unique()

func toolkit_auto_smooth() -> void:
	_toolkit_auto_smooth()

func toolkit_reverse() -> void:
	_toolkit_reverse()

func toolkit_extend(dist: float = 5.0) -> void:
	_toolkit_extend(dist)

func toolkit_remove_last() -> void:
	_toolkit_remove_last()

func toolkit_snap_to_ground() -> void:
	_toolkit_snap_to_ground()

## Fügt einen neuen Schienenpunkt per Klick im 3D-Viewport hinzu (Click-to-Draw)
func toolkit_add_point_at_world_pos(world_pos: Vector3, auto_smooth: bool = true) -> void:
	if not curve:
		curve = Curve3D.new()
		if not curve.changed.is_connected(_on_curve_changed):
			curve.changed.connect(_on_curve_changed)

	var local_pos := to_local(world_pos) if is_inside_tree() else (world_pos - position)
	local_pos.y += ground_offset

	var count := curve.point_count
	if count == 0:
		curve.add_point(local_pos)
	elif count == 1:
		var p0 := curve.get_point_position(0)
		var dir := (local_pos - p0).normalized()
		var dist := p0.distance_to(local_pos)
		curve.set_point_out(0, dir * (dist * 0.25))
		curve.add_point(local_pos, -dir * (dist * 0.25), Vector3.ZERO)
	else:
		var p_prev := curve.get_point_position(count - 1)
		var dir := (local_pos - p_prev).normalized()
		var dist := p_prev.distance_to(local_pos)
		curve.add_point(local_pos, -dir * (dist * 0.25), Vector3.ZERO)

	if auto_smooth and curve.point_count >= 3:
		_toolkit_auto_smooth()
	else:
		_regenerate_mesh()

	print("[Rail3D] ✏️ Neuer Schienenpunkt an Position %s hinzugefügt! (Gesamtpunkte: %d)" % [world_pos, curve.point_count])


# ---------------------------------------------------------
# Grind Gameplay Abfragen
# ---------------------------------------------------------

## Gibt den nächsten Offset entlang der Schiene zu einem Weltpunkt zurück
func get_closest_offset_to_world_point(world_pt: Vector3) -> float:
	if not curve:
		return 0.0
	var local_pt := to_local(world_pt)
	return curve.get_closest_offset(local_pt)

## Gibt Weltposition und Orientierungstransform an einem Offset zurück
func get_world_transform_at_offset(offset_dist: float) -> Transform3D:
	if not curve:
		return global_transform
	var local_trans := curve.sample_baked_with_rotation(offset_dist, true, true)
	return global_transform * local_trans

## Berechnet Tangente / Vorwärtsrichtung an einem Offset in Weltkoordinaten
func get_forward_at_offset(offset_dist: float) -> Vector3:
	if not curve or curve.point_count < 2:
		return -global_transform.basis.z
	var local_trans := curve.sample_baked_with_rotation(offset_dist, true, false)
	return (global_transform.basis * (-local_trans.basis.z)).normalized()

## Berechnet stabilen Up-Vector an einem Offset in Weltkoordinaten (immer zur oberen Hemisphäre).
## Verhindert das Umklappen (Frenet-Inversion), das bei 3D-Kurven mit Wendepunkten auftritt.
func get_up_at_offset(offset_dist: float) -> Vector3:
	if not curve or curve.point_count < 2:
		return global_transform.basis.y
	var fwd := get_forward_at_offset(offset_dist)
	var side := fwd.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = fwd.cross(Vector3.FORWARD)
		if side.length_squared() < 0.0001:
			side = fwd.cross(Vector3.RIGHT)
	side = side.normalized()
	var surface_up := side.cross(fwd).normalized()
	if surface_up.dot(Vector3.UP) < 0.0:
		surface_up = -surface_up
	return surface_up

## Liefert Weltposition, Vorwärtsvektor, stabiles UP und die vollständige 3D-Orientierungsbasis
## für das Grinden an einem bestimmten Offset.
func sample_grind_pose(offset_dist: float, direction: float = 1.0) -> Dictionary:
	var total_len := get_rail_length()
	var d := clampf(offset_dist, 0.0, total_len) if total_len > 0.0 else 0.0
	var world_pos: Vector3 = to_global(curve.sample_baked(d)) if curve else global_position
	
	var curve_fwd := get_forward_at_offset(d)
	var travel_fwd := curve_fwd * (1.0 if direction >= 0.0 else -1.0)
	var surface_up := get_up_at_offset(d)
	
	var right := travel_fwd.cross(surface_up).normalized()
	var ortho_up := right.cross(travel_fwd).normalized()
	var grind_basis := Basis(right, ortho_up, -travel_fwd)
	
	# Banking / Neigung in Kurven (leichte Zentrifugalkraft-Neigung)
	if total_len > 1.0:
		var sample_step := 0.8 * (1.0 if direction >= 0.0 else -1.0)
		var ahead_d := clampf(d + sample_step, 0.0, total_len)
		var ahead_fwd := get_forward_at_offset(ahead_d) * (1.0 if direction >= 0.0 else -1.0)
		var turn_yaw := travel_fwd.cross(ahead_fwd).y
		var bank_angle := clampf(turn_yaw * 2.5, -0.35, 0.35)
		grind_basis = grind_basis.rotated(travel_fwd, bank_angle)
		
	return {
		"position": world_pos,
		"forward": travel_fwd,
		"up": surface_up,
		"basis": grind_basis
	}

## Gesamtlänge der Schiene
func get_rail_length() -> float:
	return curve.get_baked_length() if curve else 0.0

## Prüft ob die Schiene ein geschlossener Loop ist
func is_rail_closed() -> bool:
	if not curve or curve.point_count < 3:
		return false
	var len_val := curve.get_baked_length()
	return curve.sample_baked(0.0).distance_squared_to(curve.sample_baked(len_val)) < 0.1


## Restores a private working copy; stored undo snapshots are never edited.
func toolkit_restore_curve(snapshot: Curve3D) -> void:
	if curve and curve.changed.is_connected(_on_curve_changed):
		curve.changed.disconnect(_on_curve_changed)
	curve = snapshot.duplicate(true) if snapshot else null
	if curve:
		curve.changed.connect(_on_curve_changed)
	_regenerate_mesh()
	update_configuration_warnings()
