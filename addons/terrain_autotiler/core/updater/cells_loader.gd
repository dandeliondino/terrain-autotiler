extends RefCounted

enum CellType {
	PAINTED,
	UPDATE,
	NEIGHBOR,
}

const NULL_TERRAIN_SET := Autotiler.NULL_TERRAIN_SET
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")

var request : Request

var cells := {
	original_tile_locations = {}, # {coords : TileLocation}
	original_patterns = {}, # {coords : TerrainPattern}
	patterns = {}, # {coords : TerrainPattern}
	terrains = {}, # {coords : tile_terrain}
	neighbors_coords = {}, # {coords : [Vector2i, Vector2i...]}
	sets = {
		update = {}, # {coords : true}
		neighbors = {}, # {coords : true}
		locked = {}, # {coords : true}
	},
}

# ---------------------------------------------------------------------------

func load_cells(p_request : Request) -> Dictionary:
	if not p_request:
		return {}

	request = p_request

	if request.scope == Request.Scope.LAYER:
		_add_cells(CellType.UPDATE, request.tile_map.get_used_cells(request.layer))
	else:
		_add_cells(CellType.PAINTED, request.painted_cells.keys())
		if request.scope == Request.Scope.NEIGHBORS:
			_add_surrounding_cells_to_update(cells.sets.update.keys())
		# else: scope == PAINTED

	_add_surrounding_cells_as_neighbors(cells.sets.update.keys())

	return cells


func expand_loaded_cells(p_request : Request, p_cells : Dictionary) -> Dictionary:
	if not p_request or p_cells.is_empty():
		return {}

	request = p_request
	var old_cells : Dictionary = p_cells

	return cells

# ---------------------------------------------------------------------------



func _add_surrounding_cells_to_update(p_cells : Array) -> void:
	# immediate neighbors
	var surrounding_cells := _get_surrounding_cells(p_cells, true)
	_add_cells(CellType.UPDATE, surrounding_cells)
	# neighbors two cells away, only needed if immediate neighbor was not empty
	surrounding_cells = _get_surrounding_cells(surrounding_cells, false)
	_add_cells(CellType.UPDATE, surrounding_cells)


func _add_surrounding_cells_as_neighbors(p_cells : Array) -> void:
	var surrounding_cells := _get_surrounding_cells(p_cells, false)
	_add_cells(CellType.NEIGHBOR, surrounding_cells)


func _add_surrounding_cells_as_empty_neighbors() -> void:
	var empty_pattern := request.terrains_data.empty_pattern
	var surrounding_cells := _get_surrounding_cells(cells.sets.update.keys(), false)

	for coords in surrounding_cells:
		cells.terrains[coords] = EMPTY_TERRAIN
		cells.patterns[coords] = empty_pattern
		cells.sets.neighbors[coords] = true



func _get_surrounding_cells(
		p_cells : Array,
		p_add_neighbors_of_empty : bool
	) -> Array[Vector2i]:

	var surrounding_cells_set := {}
	var single_pattern_terrains := request.terrains_data.single_pattern_terrains
	var tile_map_locked_cells_set := request.tile_map_locked_cells_set

	var cells_to_iterate : Array[Vector2i] = []
	cells_to_iterate.assign(p_cells)

	for coords in cells_to_iterate:
		if not p_add_neighbors_of_empty:
			# if empty or single pattern terrains were painted,
			# we need to update their neighbors
			# but if they were added *as* neighbors,
			# we do not need to add the neighbors' neighbors
			var tile_terrain : int = cells.terrains[coords]
			if tile_terrain == EMPTY_TERRAIN:
				continue
			elif single_pattern_terrains.has(tile_terrain):
				continue
		for neighbor_coords in cells.neighbors_coords[coords]:
			if cells.terrains.has(neighbor_coords):
				# already added
				continue
			surrounding_cells_set[neighbor_coords] = true

	var surrounding_cells : Array[Vector2i] = []
	surrounding_cells.assign(surrounding_cells_set.keys())
	return surrounding_cells







func _add_cells(p_cell_type  : CellType, p_cells : Array) -> void:
	var tile_map := request.tile_map
	var layer := request.layer
	var terrains_data := request.terrains_data
	var terrain_set := terrains_data.terrain_set
	var tile_map_locked_cells_set := request.tile_map_locked_cells_set

	var peering_bits := terrains_data.cn.get_peering_bits()
	var all_cell_neighbors := terrains_data.cn.get_all_peering_bit_cell_neighbors()

	var empty_pattern := terrains_data.empty_pattern

	var painted_cells := request.painted_cells

	var cells_to_add : Array[Vector2i] = []
	cells_to_add.assign(p_cells)

	for coords in cells_to_add:
		var tile_data := tile_map.get_cell_tile_data(layer, coords)
		var pattern : TerrainPattern

		var update := true
		if p_cell_type == CellType.NEIGHBOR:
			update = false
		elif tile_map_locked_cells_set.has(coords):
			update = false

		if not tile_data or tile_data.terrain_set != terrain_set or \
			tile_data.terrain == EMPTY_TERRAIN:
			# these are empty cells or tiles not in this terrain set
			pattern = empty_pattern
			if p_cell_type != CellType.PAINTED:
				# if not painted, add them to the tile_map_locked_cells_set
				# so we know cannot be replaced in expanded update
				request.tile_map_locked_cells_set[coords] = true
				update = false
		else:
			var tile_data_pattern := TerrainPattern.new(peering_bits).create_from_tile_data(tile_data)
			pattern = terrains_data.get_pattern(tile_data_pattern, true)

		if p_cell_type == CellType.PAINTED:
			cells.terrains[coords] = painted_cells[coords]
		else:
			cells.terrains[coords] = pattern.tile_terrain

		if not update:
			cells.sets.neighbors[coords] = true
			cells.sets.locked[coords] = true
			cells.patterns[coords] = pattern
			return

		cells.sets.update[coords] = true
		var neighbors_coords : Array[Vector2i] = []
		for neighbor in all_cell_neighbors:
			neighbors_coords.append(tile_map.get_neighbor_cell(coords, neighbor))
		cells.neighbors_coords[coords] = neighbors_coords

		cells.original_patterns[coords] = pattern
		cells.original_tile_locations[coords] = TileLocation.new(
			tile_map.get_cell_source_id(layer, coords),
			tile_map.get_cell_atlas_coords(layer, coords),
			tile_map.get_cell_alternative_tile(layer, coords),
		)























