@tool
class_name ItemData
extends Resource

## Datengetriebene Definition eines Gegenstands im Spiel.
## Kann als .tres-Datei im Ordner res://resources/items/ abgelegt werden
## und wird vom InventoryManager automatisch zur Laufzeit erkannt.

enum Category {
	GENERAL = 0,     ## Allgemeine Gegenstände
	CONSUMABLE = 1,  ## Essen, Trinken, Snacks (z. B. Apfel, Fisch)
	KEY_ITEM = 2,    ## Schlüssel-Gegenstände & Quest-Items
	CURRENCY = 3,    ## Währungen (z. B. Batterie, Münzen)
	TOOL = 4,        ## Werkzeuge & Ausrüstung (z. B. Laterne, Angel)
	COLLECTIBLE = 5  ## Sammlerstücke & Schätze
}

@export_group("Basic Info")
@export var id: String = ""              ## Eindeutige ID (z.B. "apple"). Falls leer, wird der Dateiname genutzt!
@export var name: String = ""            ## Anzeigename (z.B. "Saftiger Apfel")
@export_multiline var description: String = "" ## Beschreibung für Inventar-Detailansicht
@export var icon: Texture2D              ## 2D-Icon für Slots und HUD
@export var model_scene: PackedScene     ## 3D-Modell (GLB/TSCN) für 3D-Inventarvorschau & Drop in die Welt

@export_group("Properties")
@export var category: Category = Category.GENERAL
@export var max_stack: int = 99          ## Maximale Stapelgröße
@export var is_currency: bool = false    ## Ob dieses Item als Energie/Währung zählt
@export var currency_attribute: String = "energy" ## Welches Manager-Attribut synchronisiert werden soll
@export var value: int = 1               ## Münz- oder Tauschwert
@export var can_drop: bool = true        ## Kann das Item abgelegt werden

@export_group("Audio & Feedback")
@export var sound_pickup: AudioStream    ## Optionaler individueller Pickup-Sound

func get_category_name() -> String:
	match category:
		Category.CONSUMABLE:
			return "Proviant"
		Category.KEY_ITEM:
			return "Wichtiges Item"
		Category.CURRENCY:
			return "Currency"
		Category.TOOL:
			return "Werkzeug"
		Category.COLLECTIBLE:
			return "Collectible"
		_:
			return "Gegenstand"
