extends CanvasLayer
class_name PixelFilter

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm:
		sm.settings_changed.connect(_on_settings_changed)
	_apply_filter()

func _on_settings_changed(setting_name: String) -> void:
	if setting_name == "graphics" or setting_name == "pixel_art":
		_apply_filter()

func _apply_filter() -> void:
	if not color_rect or not color_rect.material:
		return
		
	var mat := color_rect.material as ShaderMaterial
	if not mat:
		return
		
	var sm = get_node_or_null("/root/SettingsManager")
	var mode: int = sm.pixel_art_mode if sm else 0
	
	match mode:
		0: # Aus (Nativ HD)
			mat.set_shader_parameter("enabled", false)
			mat.set_shader_parameter("pixel_size", 1.0)
			color_rect.visible = false
		1: # Sanft
			mat.set_shader_parameter("enabled", true)
			mat.set_shader_parameter("pixel_size", 2.2)
			mat.set_shader_parameter("color_depth", 36)
			mat.set_shader_parameter("dither_strength", 0.02)
			color_rect.visible = true
		2: # Klassisch (360p)
			mat.set_shader_parameter("enabled", true)
			mat.set_shader_parameter("pixel_size", 3.6)
			mat.set_shader_parameter("color_depth", 24)
			mat.set_shader_parameter("dither_strength", 0.035)
			color_rect.visible = true
		3: # Nostalgie (PS1 / 240p)
			mat.set_shader_parameter("enabled", true)
			mat.set_shader_parameter("pixel_size", 5.2)
			mat.set_shader_parameter("color_depth", 16)
			mat.set_shader_parameter("dither_strength", 0.05)
			color_rect.visible = true
