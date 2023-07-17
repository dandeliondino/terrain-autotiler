extends RefCounted

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")

var request : Request
var cells : Dictionary


func place_tiles(p_request : Request, p_cells : Dictionary) -> void:
	if not p_request or p_cells.is_empty():
		return

	request = p_request
	cells = p_cells

	var cell_tiles_before := {}
	var cell_tiles_after := {}

	request.update_result.cell_tiles_before = cell_tiles_before
	request.update_result.cell_tiles_after = cell_tiles_after
