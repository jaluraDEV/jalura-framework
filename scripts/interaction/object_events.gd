class_name ObjectEvents
extends RefCounted

## Standardisierte Konstanten für Objekt-Events im Barnaby Weltobjekt-System.

const READ: StringName = &"read"
const OPENED: StringName = &"opened"
const CLOSED: StringName = &"closed"
const EMPTIED: StringName = &"emptied"
const PICKED_UP: StringName = &"picked_up"
const SHAKEN: StringName = &"shaken"
const DEPLETED: StringName = &"depleted"
const INVENTORY_FULL: StringName = &"inventory_full"
const PUSHED: StringName = &"pushed"
const PULLED: StringName = &"pulled"
const ACTIVATED: StringName = &"activated"
const DEACTIVATED: StringName = &"deactivated"
const TALKED: StringName = &"talked"
const UNLOCKED: StringName = &"unlocked"
const UNLOCK_FAILED: StringName = &"unlock_failed"
const TOGGLED: StringName = &"toggled"

const HINT_LIST: String = "read,opened,closed,emptied,picked_up,shaken,depleted,inventory_full,pushed,pulled,activated,deactivated,toggled,talked,unlocked,unlock_failed,custom"
