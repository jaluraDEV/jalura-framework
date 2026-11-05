extends Node

const DioramaCamera3D = preload("res://scripts/camera/diorama_camera_3d.gd")

## Globaler CameraManager für das Dankward Framework.
## Verwaltet Kamera-Modi (Diorama vs. 360° Free Orbit), sanfte Übergänge,
## Eingabe-Empfindlichkeiten (Maus/Stick), Invert-Y und FOV.

signal camera_mode_changed(new_mode: int)
signal camera_settings_changed

enum CameraMode {
	SCENE_DEFAULT = 0, ## Szene entscheidet selbst (z. B. Hafen startet in Diorama)
	DIORAMA = 1,       ## Immer feste Diorama-Schiene bevorzugen
	FREE_360 = 2       ## Immer freie 360°-Orbit-Kamera um Barnaby
}

const CONFIG_PATH: String = "user://camera_settings.cfg"

var current_mode: CameraMode = CameraMode.SCENE_DEFAULT
var mouse_sensitivity: float = 0.0025
var stick_sensitivity: float = 3.2
var invert_y: bool = false
var default_fov: float = 70.0

# Referenzen auf die aktiven Kameras in der aktuellen Szene
var active_diorama_cam: DioramaCamera3D = null
var active_player_cam: Camera3D = null
var active_player_pivot: Node3D = null
var active_player: Node3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()

## Registriert eine DioramaCamera3D beim Laden einer Szene
func register_diorama_camera(cam: DioramaCamera3D) -> void:
	active_diorama_cam = cam
	apply_camera_mode(false)

func unregister_diorama_camera(cam: DioramaCamera3D) -> void:
	if active_diorama_cam == cam:
		active_diorama_cam = null

## Registriert den Spieler und dessen 360°-Kamerasystem
func register_player(player: Node3D) -> void:
	active_player = player
	if player:
		active_player_cam = player.find_child("Camera3D", true, false) as Camera3D
		active_player_pivot = player.find_child("CameraPivot", true, false) as Node3D
	apply_camera_mode(false)

func unregister_player(player: Node3D) -> void:
	if active_player == player:
		active_player = null
		active_player_cam = null
		active_player_pivot = null

## Schaltet zwischen Diorama und 360° hin und her
func toggle_camera_mode() -> void:
	if not active_diorama_cam:
		_show_hud_toast("🎥", "CAMERA", "Only 360° camera available in this scene", Color(1.0, 0.8, 0.4))
		return
		
	var target_mode: CameraMode
	if is_diorama_active():
		target_mode = CameraMode.FREE_360
	else:
		target_mode = CameraMode.DIORAMA
		
	set_camera_mode(target_mode, true)

func set_camera_mode(mode: CameraMode, notify: bool = true) -> void:
	current_mode = mode
	apply_camera_mode(notify)
	save_settings()
	camera_mode_changed.emit(current_mode)

## Prüft, ob aktuell die Diorama-Kamera das Bild rendert
func is_diorama_active() -> bool:
	if active_diorama_cam and active_diorama_cam.current:
		return true
	return false

## Wendet den gewählten Kamera-Modus auf die Kameras in der Szene an
func apply_camera_mode(notify: bool = false) -> void:
	var use_diorama := false
	
	if active_diorama_cam:
		match active_diorama_cam.camera_mode:
			DioramaCamera3D.Mode.FREE_360_ORBIT:
				use_diorama = false
			DioramaCamera3D.Mode.DIORAMA_RAIL, DioramaCamera3D.Mode.FIXED_ROOM:
				use_diorama = true
	else:
		use_diorama = false

	# Kameras umschalten
	if use_diorama and active_diorama_cam:
		active_diorama_cam.current = true
		if active_player_cam:
			active_player_cam.current = false
		if active_player:
			if active_player.has_method("set_camera_fade_enabled"):
				active_player.set_camera_fade_enabled(false)
			elif "camera_fade_enabled" in active_player:
				active_player.camera_fade_enabled = false
	else:
		if active_player_cam:
			active_player_cam.current = true
		if active_diorama_cam:
			active_diorama_cam.current = false
		if active_player:
			if active_player.has_method("set_camera_fade_enabled"):
				active_player.set_camera_fade_enabled(true)
			elif "camera_fade_enabled" in active_player:
				active_player.camera_fade_enabled = true

	_apply_fov()

func snap_active_camera() -> void:
	if is_diorama_active() and active_diorama_cam and active_diorama_cam.has_method("snap_to_target"):
		active_diorama_cam.snap_to_target()

func _apply_fov() -> void:
	if active_diorama_cam and active_diorama_cam.get("sync_with_global_fov") == true:
		active_diorama_cam.fov = default_fov
	if active_player_cam:
		active_player_cam.fov = default_fov

func set_mouse_sensitivity(val: float) -> void:
	mouse_sensitivity = clampf(val, 0.0005, 0.01)
	save_settings()
	camera_settings_changed.emit()

func set_stick_sensitivity(val: float) -> void:
	stick_sensitivity = clampf(val, 0.5, 8.0)
	save_settings()
	camera_settings_changed.emit()

func set_invert_y(val: bool) -> void:
	invert_y = val
	save_settings()
	camera_settings_changed.emit()

func set_fov(val: float) -> void:
	default_fov = clampf(val, 50.0, 100.0)
	_apply_fov()
	save_settings()
	camera_settings_changed.emit()

func _show_hud_toast(badge: String, title: String, text: String, color: Color) -> void:
	var tree := get_tree()
	if not tree:
		return
	var hud = tree.root.find_child("HUD", true, false)
	if hud and hud.has_method("show_toast"):
		hud.show_toast(badge, title, text, color)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH) # Bestehende Werte beibehalten
	config.set_value("camera", "mode", int(current_mode))
	config.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("camera", "stick_sensitivity", stick_sensitivity)
	config.set_value("camera", "invert_y", invert_y)
	config.set_value("camera", "fov", default_fov)
	config.save(CONFIG_PATH)

func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(CONFIG_PATH)
	if err == OK:
		current_mode = int(config.get_value("camera", "mode", CameraMode.SCENE_DEFAULT)) as CameraMode
		mouse_sensitivity = float(config.get_value("camera", "mouse_sensitivity", 0.0025))
		stick_sensitivity = float(config.get_value("camera", "stick_sensitivity", 3.2))
		invert_y = bool(config.get_value("camera", "invert_y", false))
		default_fov = float(config.get_value("camera", "fov", 70.0))
