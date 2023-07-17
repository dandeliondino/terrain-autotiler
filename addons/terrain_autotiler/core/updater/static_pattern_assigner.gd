extends RefCounted

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")

var request : Request
var cells : Dictionary


# Dictionaries are passed by reference, so no return value needed
func assign_static_patterns(p_request : Request, p_cells : Dictionary) -> void:
	if not p_request or p_cells.is_empty():
		return

	request = p_request
	cells = p_cells

