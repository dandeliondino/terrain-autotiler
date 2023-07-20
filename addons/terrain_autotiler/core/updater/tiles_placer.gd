extends RefCounted

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")

var request : Request
var cells : Dictionary
var result : UpdateResult


func place_tiles(p_request : Request, p_cells : Dictionary) -> void:
	if not p_request or p_cells.is_empty():
		return

	request = p_request
	cells = p_cells
	result = request.update_result
	var empty_pattern := request.terrains_data.empty_pattern

	var cell_tiles_before := {}
	var cell_tiles_after := {}

	var tile_map := request.tile_map
	var layer := request.layer

	for coords in cells.sets.update:
		var pattern : TerrainPattern = cells.patterns.get(coords, null)
		if not pattern:
			result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_ASSIGNED)
			continue

		# may have been tile of other terrain set that want to erase
		if pattern == empty_pattern:
			cell_tiles_before[coords] = cells.original_tile_locations[coords]
			cell_tiles_after[coords] = null
			tile_map.erase_cell(layer, coords)
			continue

		if pattern == cells.original_patterns[coords]:
			continue

		cell_tiles_before[coords] = cells.original_tile_locations[coords]

		var tile_location := pattern.get_tile()
		if not tile_location:
			push_error("No valid tile found for pattern")
			continue

		cell_tiles_after[coords] = tile_location

		tile_map.set_cell(
			layer,
			coords,
			tile_location.source_id,
			tile_location.atlas_coords,
			tile_location.alternative_tile_id,
		)

	request.update_result.cell_tiles_before = cell_tiles_before
	request.update_result.cell_tiles_after = cell_tiles_after
