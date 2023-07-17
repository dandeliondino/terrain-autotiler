extends RefCounted


const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const CellsLoader := preload("res://addons/terrain_autotiler/core/updater/cells_loader.gd")
const StaticPatternAssigner := preload("res://addons/terrain_autotiler/core/updater/static_pattern_assigner.gd")
const PatternAssigner := preload("res://addons/terrain_autotiler/core/updater/pattern_assigner.gd")
const TilesPlacer := preload("res://addons/terrain_autotiler/core/updater/tiles_placer.gd")


# because objects and dictionaries are passed by reference,
# modifications made will persist without passing them back to this function

func update_tiles(p_request : Request) -> UpdateResult:
	if not p_request:
		return UpdateResult.new()

	var request : Request = p_request
	var cells : Dictionary = CellsLoader.new().load_cells(request)
	if cells.is_empty():
		return request.update_result

	StaticPatternAssigner.new().assign_static_patterns(request, cells)

	var error := PatternAssigner.new().assign_patterns(request, cells)
	if error == PatternAssigner.EXPANDED_UPDATE_REQUESTED:
		# retry with expanded update
		cells = CellsLoader.new().expand_loaded_cells(request, cells)
		StaticPatternAssigner.new().assign_static_patterns(request, cells)
		error = PatternAssigner.new().assign_patterns(request, cells)
		if error != OK:
			# can only expand update once,
			# so any error here should result in exit
			return request.update_result
	elif error != OK:
		# if any other error, exit
		return request.update_result

	TilesPlacer.new().place_tiles(request, cells)

	return request.update_result


