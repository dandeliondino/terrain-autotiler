extends RefCounted



const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const StaticPatternAssigner := preload("res://addons/terrain_autotiler/core/updater/static_pattern_assigner.gd")
const SearchPatternAssigner := preload("res://addons/terrain_autotiler/core/updater/search_pattern_assigner.gd")

var request : Request
var cells : Dictionary


func assign_patterns(p_request : Request, p_cells : Dictionary) -> Error:
	if not p_request or p_cells.is_empty():
		return Error.ERR_CANT_CREATE

	request = p_request
	cells = p_cells

	var unassigned_cells : Array[Vector2i] = StaticPatternAssigner.new().assign_static_patterns(request, cells)
	var error := SearchPatternAssigner.new().assign_search_patterns(request, cells, unassigned_cells)
	return error

