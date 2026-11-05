class_name GiveItemAction
extends ReactionAction

## Aktion: Fügt dem Spieler ein Item über das InventoryManager-System hinzu.

@export var item: ItemData
@export var item_id: String = "" ## Fallback/Direkt-ID falls keine Resource gewählt ist
@export var amount: int = 1

func execute(ctx: Dictionary) -> void:
	var final_id := ""
	if item and not item.id.is_empty():
		final_id = item.id
	elif not item_id.is_empty():
		final_id = item_id
	if final_id.is_empty() or amount <= 0:
		return
		
	var hub: Node = ctx.get("hub")
	var inv: Node = null
	if hub:
		inv = hub.get_node_or_null("/root/InventoryManager")
		if not inv and hub.get_tree():
			inv = hub.get_tree().root.get_node_or_null("InventoryManager")
	if not inv and Engine.has_singleton("InventoryManager"):
		inv = Engine.get_singleton("InventoryManager")
		
	if inv and inv.has_method("add_item"):
		inv.call("add_item", final_id, amount)
