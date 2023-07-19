extends RefCounted

enum Scope {
	PAINTED,
	NEIGHBORS,
	LAYER,
}

const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")

var _valid_terrains : Array

var tile_map : TileMap
var layer : int
var terrains_data : TerrainsData
var scope : Scope
var max_update_size : Vector2i

var cell_logging : bool

var tile_map_locked_cells_set := {} # {coords Vector2i : true}

var painted_cells := {} # {coords Vector2i : terrain int}

var update_result : UpdateResult


func setup(
		p_tile_map : TileMap,
		p_layer : int,
		p_terrains_data : TerrainsData,
		p_scope : Scope,
		p_max_update_size : Vector2i,
		p_cell_logging : bool
	) -> Autotiler.TA_Error:

	tile_map = p_tile_map
	layer = p_layer
	terrains_data = p_terrains_data
	scope = p_scope
	max_update_size = p_max_update_size
	cell_logging = p_cell_logging


	if not is_instance_valid(tile_map) or tile_map.is_queued_for_deletion():
		return Autotiler.TA_Error.INVALID_TILE_MAP
	if not is_instance_valid(tile_map.tile_set):
		return Autotiler.TA_Error.INVALID_TILE_SET
	if not layer in range(0, tile_map.get_layers_count()):
		return Autotiler.TA_Error.INVALID_LAYER
	if not terrains_data or terrains_data._patterns_by_id.size() == 0:
		return Autotiler.TA_Error.INVALID_TERRAINS_DATA

	if max_update_size < Vector2i(-1,-1):
		max_update_size = Autotiler.UPDATE_SIZE_NO_EXPANSION

	update_result = UpdateResult.new(terrains_data)

	for coords in Autotiler.get_locked_cells(tile_map, layer):
		tile_map_locked_cells_set[coords] = true

	_valid_terrains = terrains_data.tile_terrains.duplicate()
	_valid_terrains.append(Autotiler.EMPTY_TERRAIN)

	return Autotiler.TA_Error.OK



func add_painted_cells_list(p_cells : Array, p_terrain : int) -> Autotiler.TA_Error:
	# validate terrain
	if not _valid_terrains.has(p_terrain):
		return Autotiler.TA_Error.INVALID_TERRAIN

	var has_locked_cells : bool = (tile_map_locked_cells_set.size() > 0)

	for coords in p_cells:
		# validate cell (don't checked locked here, have to check later anyways)
		if typeof(coords) != TYPE_VECTOR2I:
			return Autotiler.TA_Error.INVALID_CELLS
		painted_cells[coords] = p_terrain

	if painted_cells.size() == 0:
		return Autotiler.TA_Error.EMPTY_UPDATE

	return Autotiler.TA_Error.OK



func add_painted_cells_dict(p_cells_terrains : Dictionary) -> Autotiler.TA_Error:
	var has_locked_cells : bool = (tile_map_locked_cells_set.size() > 0)

	for coords in p_cells_terrains:
		# validate cell
		if typeof(coords) != TYPE_VECTOR2I:
			return Autotiler.TA_Error.INVALID_CELLS
		if has_locked_cells && tile_map_locked_cells_set.has(coords):
			# can be added later as a neighbor
			continue

		# validate terrain
		var terrain : int = p_cells_terrains[coords]
		if not _valid_terrains.has(terrain):
			return Autotiler.TA_Error.INVALID_TERRAIN

		painted_cells[coords] = terrain

	return Autotiler.TA_Error.OK








