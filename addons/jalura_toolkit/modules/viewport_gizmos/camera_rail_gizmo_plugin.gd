@tool
class_name CameraRailGizmoPlugin
extends EditorNode3DGizmoPlugin

## 3D-Viewport Gizmo Plugin für DioramaCamera3D.
## Zeichnet im Godot-3D-Editor interaktive Schienen, Bewegungsgrenzen
## und Blickrichtungs-Linien für Leveldesigner.

const DioramaCamera3D = preload("res://scripts/camera/diorama_camera_3d.gd")

func _init() -> void:
	# Cyan für die Kameraschiene
	create_material("camera_rail", Color(0.2, 0.85, 1.0, 0.9), false, true)
	# Gelb / Bernstein für die Bewegungsgrenzen
	create_material("camera_bounds", Color(1.0, 0.75, 0.2, 0.6), false, true)
	# Grün für Ziel-Fokuslinie
	create_material("camera_target_line", Color(0.3, 1.0, 0.5, 0.7), false, true)

func _get_gizmo_name() -> String:
	return "Diorama Camera Rail & Bounds"

func _has_gizmo(for_node_3d: Node3D) -> bool:
	return for_node_3d is DioramaCamera3D

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var cam := gizmo.get_node_3d() as DioramaCamera3D
	if not cam:
		return

	# Nur zeichnen, wenn Diorama-Modus aktiv ist
	if "camera_mode" in cam and cam.camera_mode == DioramaCamera3D.Mode.FREE_360_ORBIT:
		return

	var mat_rail := get_material("camera_rail", gizmo)
	var mat_bounds := get_material("camera_bounds", gizmo)
	var mat_target := get_material("camera_target_line", gizmo)

	var pan_left: float = cam.max_pan_left if "max_pan_left" in cam else 3.0
	var pan_right: float = cam.max_pan_right if "max_pan_right" in cam else 3.0
	var pan_up: float = cam.max_pan_up if "max_pan_up" in cam else 1.5
	var pan_down: float = cam.max_pan_down if "max_pan_down" in cam else 1.0

	# 1. Haupt-Bewegungsschiene (X-Achse im lokalen Kameraraum)
	var rail_lines: PackedVector3Array = PackedVector3Array([
		Vector3(-pan_left, 0, 0),
		Vector3(pan_right, 0, 0),
		# End-Marker links
		Vector3(-pan_left, -0.4, 0),
		Vector3(-pan_left, 0.4, 0),
		# End-Marker rechts
		Vector3(pan_right, -0.4, 0),
		Vector3(pan_right, 0.4, 0),
		# Mittelpunkt-Marker (Startposition)
		Vector3(0, -0.2, 0),
		Vector3(0, 0.2, 0)
	])
	gizmo.add_lines(rail_lines, mat_rail, false)

	# 2. Begrenzungs-Box (Rechteck für X / Y Bewegung)
	var box_lines: PackedVector3Array = PackedVector3Array([
		# Oben
		Vector3(-pan_left, pan_up, 0), Vector3(pan_right, pan_up, 0),
		# Unten
		Vector3(-pan_left, -pan_down, 0), Vector3(pan_right, -pan_down, 0),
		# Links
		Vector3(-pan_left, -pan_down, 0), Vector3(-pan_left, pan_up, 0),
		# Rechts
		Vector3(pan_right, -pan_down, 0), Vector3(pan_right, pan_up, 0)
	])
	gizmo.add_lines(box_lines, mat_bounds, false)

	# 3. Fokuslinie nach vorne (in Blickrichtung der Kamera)
	var forward_lines: PackedVector3Array = PackedVector3Array([
		Vector3.ZERO,
		Vector3(0, 0, -6.0)
	])
	gizmo.add_lines(forward_lines, mat_target, false)
