extends Control
class_name OptionsMenu

signal closed

@onready var master_slider: HSlider = %MasterSlider
@onready var master_label: Label = %MasterValLabel
@onready var music_slider: HSlider = %MusicSlider
@onready var music_label: Label = %MusicValLabel
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_label: Label = %SfxValLabel

@onready var window_option: OptionButton = %WindowOption
@onready var res_option: OptionButton = %ResOption
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var fps_limit_check: CheckButton = %FpsLimitCheck
@onready var fps_slider: HSlider = %FpsSlider
@onready var fps_val_label: Label = %FpsValLabel
@onready var show_fps_check: CheckButton = %ShowFpsCheck

@onready var preset_option: OptionButton = %PresetOption
@onready var aa_option: OptionButton = %AaOption
@onready var shadow_option: OptionButton = %ShadowOption
@onready var lod_option: OptionButton = %LodOption
@onready var clutter_option: OptionButton = %ClutterOption
@onready var pixel_option: OptionButton = %PixelOption
@onready var fog_check: CheckButton = %FogCheck
@onready var glow_check: CheckButton = %GlowCheck
@onready var dof_check: CheckButton = %DofCheck

@onready var cam_sens_slider: HSlider = get_node_or_null("%CamSensSlider")
@onready var cam_sens_val_label: Label = get_node_or_null("%CamSensValLabel")
@onready var cam_invert_check: CheckButton = get_node_or_null("%CamInvertCheck")

@onready var back_btn: Button = %BackButton
@onready var close_btn: Button = get_node_or_null("%CloseButton")

var _sm_cache: Node = null

func _get_sm() -> Node:
	if not _sm_cache:
		_sm_cache = get_node_or_null("/root/SettingsManager")
	return _sm_cache

func _ready() -> void:
	_populate_dropdowns()
	_sync_ui_from_settings()
	_connect_signals()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	if visible:
		_sync_ui_from_settings()

func _populate_dropdowns() -> void:
	var sm := _get_sm()
	if not sm:
		return
		
	if window_option:
		window_option.clear()
		window_option.add_item("Windowed", 0)
		window_option.add_item("Borderless Window", 1)
		window_option.add_item("Exclusive Fullscreen", 2)
		
	if res_option:
		res_option.clear()
		for r in sm.RESOLUTIONS:
			res_option.add_item("%d x %d" % [r.x, r.y])
			
	if preset_option:
		preset_option.clear()
		for i in range(sm.PRESET_NAMES.size()):
			preset_option.add_item(sm.PRESET_NAMES[i], i)
			
	if aa_option:
		aa_option.clear()
		for i in range(sm.AA_NAMES.size()):
			aa_option.add_item(sm.AA_NAMES[i], i)
			
	if shadow_option:
		shadow_option.clear()
		shadow_option.add_item("Off", 0)
		shadow_option.add_item("Medium", 1)
		shadow_option.add_item("High", 2)
		
	if lod_option:
		lod_option.clear()
		lod_option.add_item("Low (Performance)", 0)
		lod_option.add_item("Medium", 1)
		lod_option.add_item("High (Default)", 2)
		lod_option.add_item("Ultra (No LOD pop)", 3)
		
	if clutter_option:
		clutter_option.clear()
		clutter_option.add_item("Near (35m)", 0)
		clutter_option.add_item("Medium (55m)", 1)
		clutter_option.add_item("Far (85m)", 2)
		clutter_option.add_item("Maximum (No Culling)", 3)
		
	if pixel_option:
		pixel_option.clear()
		pixel_option.add_item("Off (Native HD)", 0)
		pixel_option.add_item("Soft (Subtle)", 1)
		pixel_option.add_item("Classic (Retro 360p)", 2)
		pixel_option.add_item("Nostalgia (PS1 / 240p)", 3)

func _sync_ui_from_settings() -> void:
	var sm := _get_sm()
	if not sm:
		return
		
	# Audio
	if master_slider:
		master_slider.value = sm.master_volume * 100.0
		_update_slider_label(master_label, sm.master_volume)
	if music_slider:
		music_slider.value = sm.music_volume * 100.0
		_update_slider_label(music_label, sm.music_volume)
	if sfx_slider:
		sfx_slider.value = sm.sfx_volume * 100.0
		_update_slider_label(sfx_label, sm.sfx_volume)
		
	# Video / Display
	if window_option:
		window_option.select(sm.window_mode)
	if res_option:
		res_option.select(sm.resolution_idx)
	if vsync_check:
		vsync_check.button_pressed = sm.vsync_enabled
	if fps_limit_check:
		fps_limit_check.button_pressed = sm.fps_limit_enabled
	if fps_slider:
		fps_slider.value = sm.max_fps
		fps_slider.editable = sm.fps_limit_enabled
	_update_fps_slider_label()
	if show_fps_check:
		show_fps_check.button_pressed = sm.show_fps
		
	# Graphics
	if preset_option:
		preset_option.select(sm.get_matching_preset())
	if aa_option:
		aa_option.select(sm.anti_aliasing_mode)
	if shadow_option:
		shadow_option.select(sm.shadow_quality)
	if lod_option:
		lod_option.select(sm.lod_quality)
	if clutter_option:
		clutter_option.select(sm.clutter_culling_idx)
	if pixel_option:
		pixel_option.select(sm.pixel_art_mode)
	if fog_check:
		fog_check.button_pressed = sm.volumetric_fog_enabled
	if glow_check:
		glow_check.button_pressed = sm.glow_enabled
	if dof_check:
		dof_check.button_pressed = sm.dof_enabled

	# Controls
	var cm = get_node_or_null("/root/CameraManager")
	if cm:
		if cam_sens_slider:
			cam_sens_slider.value = round((cm.mouse_sensitivity / 0.0025) * 100.0)
			if cam_sens_val_label:
				cam_sens_val_label.text = "%d%%" % int(cam_sens_slider.value)
		if cam_invert_check:
			cam_invert_check.button_pressed = cm.invert_y

func _update_slider_label(label: Label, val_normalized: float) -> void:
	if label:
		label.text = "%d%%" % int(round(val_normalized * 100.0))

func _update_fps_slider_label() -> void:
	var sm := _get_sm()
	if fps_val_label and sm:
		if sm.fps_limit_enabled:
			fps_val_label.text = "%d FPS" % sm.max_fps
		else:
			fps_val_label.text = "Aus"

func _connect_signals() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_changed)
	if music_slider:
		music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_changed)
		
	if window_option:
		window_option.item_selected.connect(_on_window_mode_selected)
	if res_option:
		res_option.item_selected.connect(_on_resolution_selected)
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	if fps_limit_check:
		fps_limit_check.toggled.connect(_on_fps_limit_toggled)
	if fps_slider:
		fps_slider.value_changed.connect(_on_fps_slider_changed)
	if show_fps_check:
		show_fps_check.toggled.connect(_on_show_fps_toggled)
		
	if preset_option:
		preset_option.item_selected.connect(_on_preset_selected)
	if aa_option:
		aa_option.item_selected.connect(_on_aa_selected)
	if shadow_option:
		shadow_option.item_selected.connect(_on_shadow_selected)
	if lod_option:
		lod_option.item_selected.connect(_on_lod_selected)
	if clutter_option:
		clutter_option.item_selected.connect(_on_clutter_selected)
	if pixel_option:
		pixel_option.item_selected.connect(_on_pixel_selected)
	if fog_check:
		fog_check.toggled.connect(_on_fog_toggled)
	if glow_check:
		glow_check.toggled.connect(_on_glow_toggled)
	if dof_check:
		dof_check.toggled.connect(_on_dof_toggled)
		
	if cam_sens_slider:
		cam_sens_slider.value_changed.connect(_on_cam_sens_changed)
	if cam_invert_check:
		cam_invert_check.toggled.connect(_on_cam_invert_toggled)
		
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if close_btn:
		close_btn.pressed.connect(_on_back_pressed)

func _on_master_changed(val: float) -> void:
	var sm := _get_sm()
	if sm:
		sm.master_volume = val / 100.0
		_update_slider_label(master_label, sm.master_volume)
		sm.apply_audio_settings()

func _on_music_changed(val: float) -> void:
	var sm := _get_sm()
	if sm:
		sm.music_volume = val / 100.0
		_update_slider_label(music_label, sm.music_volume)
		sm.apply_audio_settings()

func _on_sfx_changed(val: float) -> void:
	var sm := _get_sm()
	if sm:
		sm.sfx_volume = val / 100.0
		_update_slider_label(sfx_label, sm.sfx_volume)
		sm.apply_audio_settings()

func _on_window_mode_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.window_mode = idx
		sm.apply_display_settings()

func _on_resolution_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.resolution_idx = idx
		sm.apply_display_settings()

func _on_vsync_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.vsync_enabled = toggled
		sm.apply_display_settings()

func _on_fps_limit_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.fps_limit_enabled = toggled
		if fps_slider:
			fps_slider.editable = toggled
		_update_fps_slider_label()
		sm.apply_fps_limit()

func _on_fps_slider_changed(val: float) -> void:
	var sm := _get_sm()
	if sm:
		sm.max_fps = int(val)
		_update_fps_slider_label()
		sm.apply_fps_limit()

func _on_show_fps_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.show_fps = toggled
		sm.settings_changed.emit("video")

func _on_preset_selected(idx: int) -> void:
	var sm := _get_sm()
	if not sm:
		return
	if idx < 5:
		sm.apply_preset(idx)
		_sync_ui_from_settings()
	else:
		sm.graphics_preset = 5

func _update_preset_selection() -> void:
	var sm := _get_sm()
	if preset_option and sm:
		preset_option.select(sm.get_matching_preset())

func _on_aa_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.anti_aliasing_mode = idx
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_shadow_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.shadow_quality = idx
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_lod_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.lod_quality = idx
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_clutter_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.clutter_culling_idx = idx
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_pixel_selected(idx: int) -> void:
	var sm := _get_sm()
	if sm:
		sm.pixel_art_mode = idx
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_fog_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.volumetric_fog_enabled = toggled
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_glow_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.glow_enabled = toggled
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_dof_toggled(toggled: bool) -> void:
	var sm := _get_sm()
	if sm:
		sm.dof_enabled = toggled
		sm.apply_graphics_settings()
		_update_preset_selection()

func _on_back_pressed() -> void:
	var sm := _get_sm()
	if sm:
		sm.save_settings()
	closed.emit()

func _on_cam_sens_changed(val: float) -> void:
	var cm = get_node_or_null("/root/CameraManager")
	if cm:
		cm.set_mouse_sensitivity((val / 100.0) * 0.0025)
		cm.set_stick_sensitivity((val / 100.0) * 3.2)
		if cam_sens_val_label:
			cam_sens_val_label.text = "%d%%" % int(val)

func _on_cam_invert_toggled(pressed: bool) -> void:
	var cm = get_node_or_null("/root/CameraManager")
	if cm:
		cm.set_invert_y(pressed)
