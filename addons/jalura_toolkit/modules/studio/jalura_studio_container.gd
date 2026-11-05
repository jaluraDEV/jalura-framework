@tool
class_name JaluraStudioContainer
extends VBoxContainer

## Zentraler Hauptbildschirm-Container für das Jalura Toolkit.
## Bietet eine integrierte Navigationsleiste zum nahtlosen Wechseln
## zwischen dem '🗺️ Weltkarten-Graph' und dem '📜 Quest Studio'.

const WorldMapGraphViewScript = preload("res://addons/jalura_toolkit/modules/world_map_graph/world_map_graph_view.gd")
const QuestStudioViewScript = preload("res://addons/jalura_toolkit/modules/quest_studio/quest_studio_view.gd")

enum StudioTab {
	WORLD_MAP = 0,
	QUEST_STUDIO = 1
}

var current_tab: StudioTab = StudioTab.WORLD_MAP

# UI
var btn_tab_map: Button
var btn_tab_quests: Button
var content_container: MarginContainer
var world_map_view: Control
var quest_studio_view: Control


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	# 1. Obere Studio-Navigationsleiste
	var nav_bar := PanelContainer.new()
	var nav_hbox := HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 12)

	var brand_lbl := Label.new()
	brand_lbl.text = "🧭 Jalura Studio"
	brand_lbl.add_theme_font_size_override("font_size", 14)
	brand_lbl.modulate = Color(0.4, 0.8, 1.0)
	nav_hbox.add_child(brand_lbl)

	nav_hbox.add_child(VSeparator.new())

	# Mode Switch Buttons
	var btn_group := ButtonGroup.new()

	btn_tab_map = Button.new()
	btn_tab_map.text = "🗺️ World Map Graph"
	btn_tab_map.toggle_mode = true
	btn_tab_map.button_group = btn_group
	btn_tab_map.button_pressed = (current_tab == StudioTab.WORLD_MAP)
	btn_tab_map.custom_minimum_size = Vector2(160, 32)
	btn_tab_map.pressed.connect(func(): switch_to_tab(StudioTab.WORLD_MAP))
	nav_hbox.add_child(btn_tab_map)

	btn_tab_quests = Button.new()
	btn_tab_quests.text = "📜 Quest Studio"
	btn_tab_quests.toggle_mode = true
	btn_tab_quests.button_group = btn_group
	btn_tab_quests.button_pressed = (current_tab == StudioTab.QUEST_STUDIO)
	btn_tab_quests.custom_minimum_size = Vector2(160, 32)
	btn_tab_quests.pressed.connect(func(): switch_to_tab(StudioTab.QUEST_STUDIO))
	nav_hbox.add_child(btn_tab_quests)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_hbox.add_child(spacer)

	var ver_lbl := Label.new()
	ver_lbl.text = "Jalura Framework • v1.2"
	ver_lbl.modulate = Color(0.5, 0.6, 0.7)
	ver_lbl.add_theme_font_size_override("font_size", 11)
	nav_hbox.add_child(ver_lbl)

	nav_bar.add_child(nav_hbox)
	add_child(nav_bar)

	# 2. Inhalts-Bereich
	content_container = MarginContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("margin_top", 4)
	content_container.add_theme_constant_override("margin_bottom", 4)
	content_container.add_theme_constant_override("margin_left", 4)
	content_container.add_theme_constant_override("margin_right", 4)
	add_child(content_container)

	# Sub-Views instanziieren
	world_map_view = WorldMapGraphViewScript.new()
	content_container.add_child(world_map_view)

	quest_studio_view = QuestStudioViewScript.new()
	content_container.add_child(quest_studio_view)

	# Initialen Tab anzeigen
	switch_to_tab(current_tab)


func switch_to_tab(tab: StudioTab) -> void:
	current_tab = tab

	if btn_tab_map:
		btn_tab_map.button_pressed = (tab == StudioTab.WORLD_MAP)
	if btn_tab_quests:
		btn_tab_quests.button_pressed = (tab == StudioTab.QUEST_STUDIO)

	if world_map_view:
		world_map_view.visible = (tab == StudioTab.WORLD_MAP)
		if world_map_view.visible and world_map_view.has_method("load_and_build_graph"):
			world_map_view.call("load_and_build_graph")

	if quest_studio_view:
		quest_studio_view.visible = (tab == StudioTab.QUEST_STUDIO)
		if quest_studio_view.visible and quest_studio_view.has_method("refresh_all"):
			quest_studio_view.call("refresh_all")


func refresh_active_tab() -> void:
	switch_to_tab(current_tab)
