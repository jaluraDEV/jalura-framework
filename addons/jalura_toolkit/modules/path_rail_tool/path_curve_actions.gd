@tool
extends RefCounted

## One complete curve snapshot per user action, including handles and tilt.
static func perform(path: Path3D, method: String, args: Array, history: EditorUndoRedoManager) -> void:
	if not is_instance_valid(path):
		return
	if not path.has_method(method):
		method = "_" + method
	if not path.has_method(method):
		return
	var before: Curve3D = path.curve.duplicate(true) if path.curve else null
	# Work on a private copy even when two scene instances share a curve.
	path.toolkit_restore_curve(before)
	path.callv(method, args)
	var after: Curve3D = path.curve.duplicate(true) if path.curve else null
	if history:
		history.create_action("Weg / Schiene bearbeiten", UndoRedo.MERGE_DISABLE, path)
		history.add_do_method(path, "toolkit_restore_curve", after)
		history.add_undo_method(path, "toolkit_restore_curve", before)
		history.commit_action(false)
