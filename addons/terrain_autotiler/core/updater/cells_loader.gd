extends RefCounted

enum CellType {
	PAINTED,
	UPDATE,
	NEIGHBOR,
}

const NULL_TERRAIN_SET := Autotiler.NULL_TERRAIN_SET
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN
const EMPTY_RECT := Autotiler._EMPTY_RECT

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
	can_expand = false,
	expand_rect = EMPTY_RECT,
}

var has_non_empty_neighbors := false

# ---------------------------------------------------------------------------

func load_cells(p_request : Request) -> Dictionary:
	if not p_request:
		return {}

	request = p_request
	print("load_cells() max_update_size=%s" % request.max_update_size)

	if request.scope == Request.Scope.LAYER:
		_add_cells(request.tile_map.get_used_cells(request.layer), CellType.UPDATE)
		_add_surrounding_cells_as_empty_neighbors()
	else:
		_add_cells(request.painted_cells.keys(), CellType.PAINTED)
		if request.scope == Request.Scope.NEIGHBORS:
			_add_surrounding_cells_to_update()
		_add_surrounding_cells_as_neighbors()

	if request.scope == Request.Scope.NEIGHBORS:
		_setup_expanded_update_availability()


	return cells


func expand_loaded_cells(p_request : Request, p_cells : Dictionary) -> Dictionary:
	# TODO: if this is slow, optimizing by using old data
	# but much simpler to simply re-create the cells dictionary
	if not p_request or p_cells.is_empty():
		return {}

	request = p_request
	var old_cells : Dictionary = p_cells
	var painted_cells := request.painted_cells

	_add_cells(painted_cells.keys(), CellType.PAINTED)

	var expand_cells := []
	if old_cells.expand_rect == Autotiler._EMPTY_RECT:
		# expand to all eligible cells in layer
		for coords in request.tile_map.get_used_cells(request.layer):
			if painted_cells.has(coords):
				continue
			expand_cells.append(coords)
		_add_cells(expand_cells, CellType.UPDATE)
		_add_surrounding_cells_as_empty_neighbors()
	else:
		expand_cells = _get_rect_cells(old_cells.expand_rect)
		_add_cells(expand_cells, CellType.UPDATE)
		_add_surrounding_cells_as_neighbors()

	return cells


# ---------------------------------------------------------------------------
#	ADD SURROUNDING CELLS
# ---------------------------------------------------------------------------

func _add_surrounding_cells_to_update() -> void:
	# immediate neighbors
	var surrounding_cells := _get_surrounding_cells(cells.sets.update.keys(), true)
	_add_cells(surrounding_cells, CellType.UPDATE)
	# neighbors two cells away, only needed if immediate neighbor was not empty
	surrounding_cells = _get_surrounding_cells(cells.sets.update.keys(), false)
	_add_cells(surrounding_cells, CellType.UPDATE)


func _add_surrounding_cells_as_neighbors() -> void:
	var surrounding_cells := _get_surrounding_cells(cells.sets.update.keys(), false)
#	prints("_add_surrounding_cells_as_neighbors()", surrounding_cells)
	_add_cells(surrounding_cells, CellType.NEIGHBOR)


func _add_surrounding_cells_as_empty_neighbors() -> void:
	var empty_pattern := request.terrains_data.empty_pattern
	var surrounding_cells := _get_surrounding_cells(cells.sets.update.keys(), false)

	for coords in surrounding_cells:
		cells.terrains[coords] = EMPTY_TERRAIN
		cells.patterns[coords] = empty_pattern
		request.tile_map_locked_cells_set[coords] = true
		cells.sets.neighbors[coords] = true
		cells.sets.locked[coords] = true



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



# ---------------------------------------------------------------------------
#	ADD CELLS
# ---------------------------------------------------------------------------


func _add_cells(p_cells : Array, p_cell_type  : CellType) -> void:
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
				tile_map_locked_cells_set[coords] = true
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
			if not tile_map_locked_cells_set.has(coords):
#				print("cell=%s, terrain=%s, not in tile_map_locked_cells_set" % [coords, pattern.tile_terrain])
				has_non_empty_neighbors = true
			continue

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



# ---------------------------------------------------------------------------
#	SETUP EXPANDED UPDATE ELIGIBILITY
# ---------------------------------------------------------------------------

# default value is false, so we are assessing if we can change it to true
# default rect is EMPTY_RECT (=update layer), so we are assessing if it needs
# to be changed
func _setup_expanded_update_availability() -> void:
	if not has_non_empty_neighbors:
		print("_setup_expanded_update_availability() - false - not has_non_empty_neighbors")
		return

	var max_update_size := request.max_update_size
	print("_setup_expanded_update_availability() max update size = %s" % max_update_size)

	if max_update_size == Autotiler.UPDATE_SIZE_NO_EXPANSION:
		print("_setup_expanded_update_availability() - false - max_update_size == Autotiler.UPDATE_SIZE_NO_EXPANSION")
		return

	var update_rect := _get_rect_from_cells(cells.sets.update.keys())
	if max_update_size != Autotiler.UPDATE_SIZE_NO_LIMIT:
		if max_update_size.x <= update_rect.size.x && max_update_size.y <= update_rect.size.y:
			# update is already larger than max update size
			print("_setup_expanded_update_availability() - false - update is already larger than max update size")
			return


	var layer_rect := update_rect.merge(_get_eligible_layer_cells_rect())
	if update_rect == layer_rect:
		# update already includes all eligible cells in the layer
		print("_setup_expanded_update_availability() - false - update_rect == layer_rect")
		return

	cells.can_expand = true

	if max_update_size == Autotiler.UPDATE_SIZE_NO_LIMIT:
		# leave expand_rect = EMPTY_RECT so can expand to whole layer
		print("_setup_expanded_update_availability() - layer - max_update_size == Autotiler.UPDATE_SIZE_NO_LIMIT")
		return

	if layer_rect.size.x <= max_update_size.x && layer_rect.size.y <= max_update_size.y:
		# adding all used cells is smaller than max update size,
		# so update entire layer
		print("_setup_expanded_update_availability() - layer - all used cells is smaller than max update size")
		return

	var center_pos : Vector2i = update_rect.get_center()
	var start_pos : Vector2i = center_pos - max_update_size/2
	var expand_rect := Rect2i(start_pos, max_update_size)
	# in case of irregular shape, merge with original update
	cells.expand_rect = update_rect.merge(expand_rect)
	print("_setup_expanded_update_availability() - %s" % expand_rect)


func _get_eligible_layer_cells_rect() -> Rect2i:
	var eligible_cells = _get_eligible_layer_cells()
	return _get_rect_from_cells(eligible_cells)


func _get_eligible_layer_cells() -> Array:
	var tile_map := request.tile_map
	var layer := request.layer
	return _get_eligible_expand_cells(tile_map.get_used_cells(layer))


func _get_rect_cells(rect : Rect2i) -> Array:
	var rect_cells := []
	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			rect_cells.append(Vector2i(x,y))
	return rect_cells


func _get_eligible_expand_cells(p_cells : Array) -> Array:
	var eligible_layer_cells := []
	var tile_map := request.tile_map
	var layer := request.layer
	var terrain_set := request.terrains_data.terrain_set
	for coords in p_cells:
		var tile_data := tile_map.get_cell_tile_data(layer, coords)
		if not tile_data:
			continue
		if tile_data.terrain_set != terrain_set:
			continue
		if tile_data.terrain == EMPTY_TERRAIN:
			continue
		eligible_layer_cells.append(coords)
	return eligible_layer_cells




func _get_rect_from_cells(p_cells : Array) -> Rect2i:
	var min_x := p_cells.reduce(func(min, a): return a.x if (a.x < min) else min, 10000)
	var max_x := p_cells.reduce(func(max, a): return a.x if (a.x > max) else max, -10000)
	var min_y := p_cells.reduce(func(min, a): return a.y if (a.y < min) else min, 10000)
	var max_y := p_cells.reduce(func(max, a): return a.y if (a.y > max) else max, -10000)
	var pos := Vector2i(min_x, min_y)
	var end := Vector2i(max_x, max_y)
	var size := end - pos
	return Rect2i(pos, size)










