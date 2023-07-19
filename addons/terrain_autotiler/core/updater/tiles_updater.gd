extends RefCounted

const EXPANDED_UPDATE_REQUESTED := Error.ERR_LOCKED

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const CellsLoader := preload("res://addons/terrain_autotiler/core/updater/cells_loader.gd")
const PatternAssigner := preload("res://addons/terrain_autotiler/core/updater/pattern_assigner.gd")
const TilesPlacer := preload("res://addons/terrain_autotiler/core/updater/tiles_placer.gd")


# because objects and dictionaries are passed by reference,
# modifications made will persist without passing them back to this function

func update_tiles(p_request : Request) -> UpdateResult:
	if not p_request:
		return UpdateResult.new()

	var request : Request = p_request
	print("update_tiles() max update size =%s" % request.max_update_size)
	var cells : Dictionary = CellsLoader.new().load_cells(request)
	if cells.is_empty():
		return request.update_result

	request.update_result.start_timer("tiles_updater")

	var error := PatternAssigner.new().assign_patterns(request, cells)
#	print("PatternAssigner.new().assign_patterns(request, cells) -> %s" % error)
	if error == EXPANDED_UPDATE_REQUESTED:
		# retry with expanded update
		cells = CellsLoader.new().expand_loaded_cells(request, cells)
		error = PatternAssigner.new().assign_patterns(request, cells)
		if error != OK:
			# can only expand update once,
			# so any error here should result in exit
			printerr("Terrain Autotiler: An error occurred.")
			request.update_result.stop_timer("tiles_updater")
			return request.update_result
	elif error != OK:
		# if any other error, exit
		printerr("Terrain Autotiler: An error occurred.")
		request.update_result.stop_timer("tiles_updater")
		return request.update_result

	TilesPlacer.new().place_tiles(request, cells)

	request.update_result.stop_timer("tiles_updater")
	return request.update_result


