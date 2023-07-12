@tool
extends RefCounted

# redefine to avoid extra lookups
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN
const NULL_TERRAIN := Autotiler.NULL_TERRAIN
const NULL_COORDS := Vector2i(-999,-999)
const EMPTY_RECT := Rect2i()

const UPDATE_SIZE_NO_EXPANSION := Autotiler.UPDATE_SIZE_NO_EXPANSION
const UPDATE_SIZE_NO_LIMIT := Autotiler.UPDATE_SIZE_NO_LIMIT

const COMPLEX_TERRAIN_COUNT := 3

const UPDATE := true
const NO_UPDATE := false
const SUCCESS := true
const EXPANDED_UPDATE_REQUESTED := false

const PRINT_TIMERS := false

const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")
const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")


var tile_map : TileMap
var layer : int
var terrains_data : TerrainsData
var cn : CellNeighbors
var peering_bits : Array
var result : UpdateResult
var cell_logging : bool

var _has_non_empty_neighbors := false

# if false, then expanded update is not possible or has already been used
# if true, can get all cells in _expanded_update_rect
# if _expanded_update_rect is empty, then get all cells on layer
var _expanded_update_available := false
var _expanded_update_rect : Rect2i


# list of coordinates of all neighbors that can constrain a cell's peering bits
# cached to avoid re-constructing multiple times
var _all_peering_bit_neighbors : Array

var _tile_map_has_locked_cells := false
var _tile_map_locked_cells_set := {}
var _locked_cells_set := {}
var _expandable_neighbors_set := {}

var _cell_search_patterns := {}
var _cell_terrains := {}
var _cell_patterns := {}
var _cell_all_neighbor_coords := {}
var _cell_unique_neighbor_terrains := {}

var _update_cells : Array[Vector2i] = []

var _non_matching_cells_set := {}


# this is a lot of arguments, and using TileUpdater means calling 2 functions
# might be better to have a UpdateRequest object to store these params,
# and pass it when calling the relevant function
func _init(p_tile_map : TileMap, p_layer : int, p_terrains_data : TerrainsData, p_cell_logging : bool) -> void:
	tile_map = p_tile_map
	layer = p_layer
	terrains_data = p_terrains_data
	cell_logging = p_cell_logging

	cn = terrains_data.cn
	peering_bits = cn.get_peering_bits()
	_all_peering_bit_neighbors = cn.get_all_peering_bit_cell_neighbors()
	result = UpdateResult.new(terrains_data)

	for coords in Autotiler.get_locked_cells(tile_map, layer):
		_tile_map_locked_cells_set[coords] = true

	_tile_map_has_locked_cells = _tile_map_locked_cells_set.size() > 0


func update_terrain_tiles(p_rect : Rect2i) -> UpdateResult:
	result.start_timer("tiles_updater")
	var update_all_cells := (p_rect.size == Vector2i.ZERO)


	for coords in tile_map.get_used_cells(layer):
		if not update_all_cells && not p_rect.has_point(coords):
			continue
		if _tile_map_has_locked_cells && _tile_map_locked_cells_set.has(coords):
			continue
		_add_cell_from_tile_data(coords, UPDATE)

	_load_surrounding_cells(_update_cells, NO_UPDATE)
	_assign_patterns(_update_cells)
	_update_map()
	result.stop_timer("tiles_updater")

	if PRINT_TIMERS:
		result.print_timers()

	return result


func paint_single_terrain(p_cells : Array[Vector2i], p_terrain : int, p_update_neighbors : bool, p_max_update_size : Vector2i) -> UpdateResult:
	result.start_timer("tiles_updater")
	for coords in p_cells:
		if _tile_map_has_locked_cells && _tile_map_locked_cells_set.has(coords):
			continue
		_add_painted_cell(coords, p_terrain)

	_load_surrounding_cells(_update_cells, p_update_neighbors)

	if p_update_neighbors:
		# result.start_timer("_setup_expanded_update_availability()")
		_setup_expanded_update_availability(_update_cells, p_max_update_size)
		# result.stop_timer("_setup_expanded_update_availability()")

	if _assign_patterns(_update_cells) == EXPANDED_UPDATE_REQUESTED:
		# will only return EXPANDED_UPDATE_REQUESTED if an expanded update is available
		_restart_with_expanded_update()

	_update_map()
	result.stop_timer("tiles_updater")

	if PRINT_TIMERS:
		result.print_timers()

	return result


func paint_multiple_terrains(p_cell_terrains : Dictionary, p_update_neighbors : bool, p_max_update_size : Vector2i) -> UpdateResult:
	result.start_timer("tiles_updater")
	for coords in p_cell_terrains:
		if _tile_map_has_locked_cells && _tile_map_locked_cells_set.has(coords):
			continue
		_add_painted_cell(coords, p_cell_terrains[coords])

	_load_surrounding_cells(_update_cells, p_update_neighbors)
	if p_update_neighbors:
		# result.start_timer("_setup_expanded_update_availability()")
		_setup_expanded_update_availability(_update_cells, p_max_update_size)
		# result.stop_timer("_setup_expanded_update_availability()")

	if _assign_patterns(_update_cells) == EXPANDED_UPDATE_REQUESTED:
		# will only return EXPANDED_UPDATE_REQUESTED if an expanded update is available
		_restart_with_expanded_update()

	_update_map()
	result.stop_timer("tiles_updater")

	if PRINT_TIMERS:
		result.print_timers()
	return result


# --------------------------
#   LOAD SURROUNDING CELLS
# --------------------------

func _load_surrounding_cells(p_cells : Array[Vector2i], p_update_neighbors : bool) -> void:
	# result.start_timer("_load_surrounding_cells()")
	if p_update_neighbors:
		# save edge cells so we don't have to iterate all the updated cells
		# to find neighbors at the edges
		var edge_cells := _add_surrounding_cells_to_update(p_cells, true)
		edge_cells = _add_surrounding_cells_to_update(edge_cells, false)
		_add_surrounding_cells_as_neighbors(edge_cells)
	else:
		_add_surrounding_cells_as_neighbors(p_cells)
	# result.stop_timer("_load_surrounding_cells()")



func _add_surrounding_cells_to_update(p_cells : Array[Vector2i], p_add_neighbors_of_empty : bool) -> Array[Vector2i]:
	var edge_cells_set := {}
	for coords in p_cells.duplicate():
		if not p_add_neighbors_of_empty:
			var tile_terrain : int = _cell_terrains[coords]
			if tile_terrain == EMPTY_TERRAIN or terrains_data.single_pattern_terrains.has(tile_terrain):
				# if empty or single pattern terrains were painted, need to update their neighbors
				# but if they were added *as* neighbors, do not need to add *their* neighbors
				continue

		for neighbor_coords in _cell_all_neighbor_coords[coords]:
			if _cell_terrains.has(neighbor_coords):
				continue
			if _tile_map_locked_cells_set.has(neighbor_coords):
				edge_cells_set[coords] = true
				continue
			_add_cell_from_tile_data(neighbor_coords, UPDATE)
			edge_cells_set[neighbor_coords] = true

	var edge_cells : Array[Vector2i] = []
	edge_cells.assign(edge_cells_set.keys())
	return edge_cells




func _add_surrounding_cells_as_neighbors(p_cells : Array[Vector2i]) -> void:
	for coords in p_cells:
		var tile_terrain : int = _cell_terrains[coords]
		if tile_terrain == EMPTY_TERRAIN:
			# (don't skip single pattern terrain here, need to know if expandable)
			# skip empty cells
			# even if they are painted, we can update them
			# without knowing their neighbors
			# (neighbors are only needed if they themselves need updating)
			continue

		for neighbor_coords in _cell_all_neighbor_coords[coords]:
			if _cell_terrains.has(neighbor_coords):
				continue
			_add_cell_from_tile_data(neighbor_coords, NO_UPDATE)


func _add_cell_from_tile_data(p_coords : Vector2i, p_update : bool) -> void:
	var tile_data := tile_map.get_cell_tile_data(layer, p_coords)

	if tile_data == null or tile_data.terrain_set != terrains_data.terrain_set:
		# these are empty cells or tiles not in this terrain set
		# add them to the more permanent _tile_map_locked_cells_set
		# so that if expanded update, will know should not be replaced
		_tile_map_locked_cells_set[p_coords] = true
		_add_neighbor_cell(p_coords, terrains_data.empty_pattern)
		return

	if p_update:
		_add_painted_cell(p_coords, tile_data.terrain)
		return

	if not _tile_map_has_locked_cells or not _tile_map_locked_cells_set.has(p_coords):
		_has_non_empty_neighbors = true

	var pattern := TerrainPattern.new(peering_bits).create_from_tile_data(tile_data)
	_add_neighbor_cell(p_coords, pattern)


func _add_painted_cell(p_coords : Vector2i, p_terrain : int) -> void:
	_cell_terrains[p_coords] = p_terrain
	_update_cells.append(p_coords)

	var cell_neighbor_array : Array[Vector2i] = []
	for neighbor in _all_peering_bit_neighbors:
		var neighbor_coords := tile_map.get_neighbor_cell(p_coords, neighbor)
		cell_neighbor_array.append(neighbor_coords)
	_cell_all_neighbor_coords[p_coords] = cell_neighbor_array

	if cell_logging:
		_log_add_painted_cell(p_coords, p_terrain)


func _add_neighbor_cell(p_coords : Vector2i, p_pattern : TerrainPattern) -> void:
	_cell_terrains[p_coords] = p_pattern.tile_terrain
	_cell_patterns[p_coords] = p_pattern
	_locked_cells_set[p_coords] = true
	if not _tile_map_locked_cells_set.has(p_coords):
		_expandable_neighbors_set[p_coords] = true
	if cell_logging:
		_log_add_neighbor_cell(p_coords, p_pattern)


# --------------------------
#   EXPANDED UPDATE
# --------------------------
# expanded updates can only occur when painting single or multiple terrains
# in connect mode

# This function makes its priority to disable expanded updates whenever possible.
# They are expensive and should never be attempted when there is no chance of
# an improved outcome.
func _setup_expanded_update_availability(p_current_update_cells : Array[Vector2i], p_max_update_size : Vector2i) -> void:
	if not _has_non_empty_neighbors:
		_expanded_update_available = false
		return

	if p_max_update_size == UPDATE_SIZE_NO_EXPANSION:
		_expanded_update_available = false
		return

	var painted_rect := _get_rect_from_points(p_current_update_cells)
	if p_max_update_size != UPDATE_SIZE_NO_LIMIT && p_max_update_size.x <= painted_rect.size.x && p_max_update_size.y <= painted_rect.size.y:
		# update is already larger than max update size
		_expanded_update_available = false
		return

	# tile_map.get_used_rect() includes all layers
	# so use tile_map.get_used_cells() and create new rect instead
	var used_and_painted_cells := tile_map.get_used_cells(layer) + p_current_update_cells
	var used_and_painted_rect := _get_rect_from_points(used_and_painted_cells)

	if used_and_painted_rect == painted_rect:
		# layer is empty or painting completely overlaps used cells
		_expanded_update_available = false
		return

	if p_max_update_size == UPDATE_SIZE_NO_LIMIT:
		# having determined there are possible cells to include,
		# if there is no limit, update entire layer
		_expanded_update_available = true
		_expanded_update_rect = EMPTY_RECT
		return

	if used_and_painted_rect.size.x <= p_max_update_size.x && used_and_painted_rect.size.y <= p_max_update_size.y:
		# adding all used cells is smaller than max update size,
		# so update entire layer
		_expanded_update_available = true
		_expanded_update_rect = EMPTY_RECT
		return

	# if cells that can be added make rect larger than max size,
	# then create max size expanded update rect with painted cells at center
	var center_pos := painted_rect.get_center()
	var start_pos := center_pos - p_max_update_size/2
	_expanded_update_available = true
	_expanded_update_rect = Rect2i(start_pos, p_max_update_size)


func _restart_with_expanded_update() -> void:
#	print("_restart_with_expanded_update")

	# result.start_timer("_restart_with_expanded_update()")
	# only get one chance at this
	_expanded_update_available = false

	# keep data that includes the painted cells
	# and the original neighbors:
	# 	_update_cells
	# 	_cell_terrains

	_locked_cells_set.clear()
	_cell_patterns.clear()
	_non_matching_cells_set.clear()
	_cell_search_patterns.clear()

	# turn _update_cells into a dict for faster lookups
	var updated_cells_set := {}
	for coords in _update_cells:
		updated_cells_set[coords] = true

	var cells : Array[Vector2i] = []

	if _expanded_update_rect == EMPTY_RECT:
		cells.assign(tile_map.get_used_cells(layer))
	else:
		cells = _get_cells_in_rect(_expanded_update_rect)

	for coords in cells:
		if updated_cells_set.has(coords):
			# previously added as cell to update
			# no additional data needed
			continue
		if _cell_terrains.has(coords):
			# previously added as locked neighbor
			# only need to add to _update_cells dictionary
			if _tile_map_locked_cells_set.has(coords):
				_locked_cells_set[coords] = true
				continue
			if _cell_terrains[coords] == EMPTY_TERRAIN:
				# will be neighbor, not painted, if it was not
				# in updated_cells_set
				continue
			_add_painted_cell(coords, _cell_terrains[coords])
			_update_cells.append(coords)
			continue
		# no data previously loaded for cell
		_add_cell_from_tile_data(coords, UPDATE)
	_add_surrounding_cells_as_neighbors(_update_cells)

	_assign_patterns(_update_cells)
	# result.stop_timer("_restart_with_expanded_update()")


func _get_cells_in_rect(p_rect : Rect2i) -> Array[Vector2i]:
	var cells : Array[Vector2i] = []
	for x in range(p_rect.position.x, p_rect.end.x + 1):
		for y in range(p_rect.position.y, p_rect.end.y + 1):
			cells.append(Vector2i(x,y))
	return cells


# TODO: refactor more efficiently (low priority, impact < 1ms)
func _get_rect_from_points(p_points : Array) -> Rect2i:
	var points := p_points.duplicate()
	if points.is_empty():
		return EMPTY_RECT
	points.sort_custom(func(a,b): return a.x < b.x)
	var x : int = points.front().x
	var width : int = points.back().x + 1 - x
	points.sort_custom(func(a,b): return a.y < b.y)
	var y : int = points.front().y
	var height : int = points.back().y + 1 - y
	return Rect2i(x,y,width,height)




# ----------------------------
# 	ASSIGN PATTERNS
# ----------------------------

func _assign_patterns(p_cells : Array[Vector2i]) -> bool:
	# result.start_timer("_assign_patterns")
	# result.start_timer("_assign_static_patterns")
	var next_cells := _assign_static_patterns(p_cells)
	# result.stop_timer("_assign_static_patterns")

	var cells_to_update := {} # [constraint #][terrain]
	# result.start_timer("create cells_to_update")

	# skip sorting for simple tilesets
	var tile_terrains_count := terrains_data.tile_terrains.size()
	if tile_terrains_count == 1:
		cells_to_update = {2: _create_dictionary_by_terrain(next_cells)}
	elif tile_terrains_count == 2:
		var skip_complex_match := true
		for tile_terrain in terrains_data.tile_terrains:
			if terrains_data.can_match_to_empty(tile_terrain):
				# this means there can be 3 terrains to consider
				skip_complex_match = false
		if skip_complex_match:
			cells_to_update = {2: _create_dictionary_by_terrain(next_cells)}

	if cells_to_update.is_empty():
		for coords in next_cells:
			if not _cell_needs_pattern(coords):
				continue
			var search_pattern := _get_or_create_search_pattern(coords)
			var unique_peering_terrains_count := search_pattern.get_unique_peering_terrains().size()
			var tile_terrain := search_pattern.tile_terrain
			if not cells_to_update.has(unique_peering_terrains_count):
				cells_to_update[unique_peering_terrains_count] = {}
			if not cells_to_update[unique_peering_terrains_count].has(tile_terrain):
				var array : Array[Vector2i] = []
				cells_to_update[unique_peering_terrains_count][tile_terrain] = array
			cells_to_update[unique_peering_terrains_count][tile_terrain].append(coords)
			if cell_logging:
				result.add_cell_log(coords, "Sorted with unique count = %s" % unique_peering_terrains_count)
	# result.stop_timer("create cells_to_update")

	# result.start_timer("assign loop")
	var tile_terrains := terrains_data.sorted_tile_terrains
	for unique_terrain_count in range(12, -1, -1):
		var cells_by_terrain : Dictionary = cells_to_update.get(unique_terrain_count, {})
		if cells_by_terrain.is_empty():
			continue
		for tile_terrain in tile_terrains:
			if not cells_by_terrain.has(tile_terrain):
				continue
			var assign_result : bool
			if unique_terrain_count >= COMPLEX_TERRAIN_COUNT:
				# result.start_timer("_assign_complex_patterns")
				assign_result = _assign_complex_patterns(cells_by_terrain[tile_terrain], true)
				# result.stop_timer("_assign_complex_patterns")
			else:
				if terrains_data.full_set_tile_terrains_set.has(tile_terrain):
					# result.start_timer("_assign_simple_patterns")
					assign_result = _assign_simple_patterns(cells_by_terrain[tile_terrain])
					# result.stop_timer("_assign_simple_patterns")
				else:
					# if a terrain does not have a full set, it may
					# require backtracking
					# result.start_timer("_assign_simple_patterns")
					assign_result = _assign_complex_patterns(cells_by_terrain[tile_terrain], false)
					# result.stop_timer("_assign_simple_patterns")
			if assign_result != SUCCESS:
				# will only occur if need expanded update
				# & already confirmed it is available
				# result.stop_timer("assign loop")
				# result.stop_timer("_assign_patterns")
				return EXPANDED_UPDATE_REQUESTED
	# result.stop_timer("assign loop")

	# result.start_timer("_assign_non_matching_patterns")
	_assign_non_matching_patterns()
	# result.stop_timer("_assign_non_matching_patterns")
	# result.stop_timer("_assign_patterns")

	return SUCCESS


func _create_dictionary_by_terrain(p_cells : Array[Vector2i]) -> Dictionary:
	var cells_by_terrain := {}
	for coords in p_cells:
		var tile_terrain : int = _cell_terrains[coords]
		if not cells_by_terrain.has(tile_terrain):
			var array : Array[Vector2i] = []
			cells_by_terrain[tile_terrain] = array
		cells_by_terrain[tile_terrain].append(coords)
	return cells_by_terrain



# --------------------------
# 	STATIC PATTERNS
# --------------------------

func _assign_static_patterns(p_cells : Array[Vector2i]) -> Array[Vector2i]:
	const STATIC_UPDATE_INDEX := 0

	var next_cells : Array[Vector2i] = []
	var cell_primary_patterns := {}

	for coords in p_cells:
		var tile_terrain : int = _cell_terrains[coords]
		if tile_terrain == EMPTY_TERRAIN:
			_cell_patterns[coords] = terrains_data.empty_pattern
			_locked_cells_set[coords] = true
			if cell_logging:
				_log_assign_pattern(
					coords,
					terrains_data.empty_pattern,
					true,
					UpdateResult.PatternType.STATIC_UPDATE_EMPTY,
					1,
				)
			continue

		if not terrains_data.tile_terrains.has(tile_terrain):
			# if terrain wasn't added to tile terrains, it means it has no patterns
			_cell_patterns[coords] = terrains_data.empty_pattern
			_locked_cells_set[coords] = true
			result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
			if cell_logging:
				_log_assign_pattern(
					coords,
					terrains_data.empty_pattern,
					true,
					UpdateResult.PatternType.STATIC_UPDATE_MISSING,
					STATIC_UPDATE_INDEX,
				)
			continue

		if terrains_data.single_pattern_terrains.has(tile_terrain):
			_cell_patterns[coords] = terrains_data.get_patterns_by_terrain(tile_terrain)[0]
			_locked_cells_set[coords] = true
			if cell_logging:
				_log_assign_pattern(
					coords,
					terrains_data.get_patterns_by_terrain(tile_terrain)[0],
					true,
					UpdateResult.PatternType.STATIC_UPDATE_SINGLE_PATTERN,
					STATIC_UPDATE_INDEX,
				)
			continue

		# creating SearchPatterns here would make the code much shorter/simpler
		# but doing this manually is 2x faster
		var neighbor_terrains_set := {}
		for neighbor_coords in _cell_all_neighbor_coords[coords]:
			var neighbor_terrain : int = _cell_terrains[neighbor_coords]
			neighbor_terrains_set[neighbor_terrain] = true
		if not terrains_data.can_match_to_empty(tile_terrain):
			# will count as own terrain
			neighbor_terrains_set.erase(EMPTY_TERRAIN)
		_cell_unique_neighbor_terrains[coords] = neighbor_terrains_set.keys()

		# result.start_timer("_can_assign_primary_pattern()")
		var primary_pattern := terrains_data.get_primary_pattern(tile_terrain)
		if primary_pattern && _can_assign_primary_pattern(coords, tile_terrain):
			cell_primary_patterns[coords] = primary_pattern
			# result.stop_timer("_can_assign_primary_pattern()")
			continue
		# result.stop_timer("_can_assign_primary_pattern()")

		next_cells.append(coords)

	# waiting to assign patterns until after all primary patterns have been
	# found saves time since having fewer neighbors with patterns allows
	# an early exit from _can_assign_primary_pattern
	for coords in cell_primary_patterns:
		_cell_patterns[coords] = cell_primary_patterns[coords]
		_locked_cells_set[coords] = true
		if cell_logging:
			_log_assign_pattern(
				coords,
				cell_primary_patterns[coords],
				true,
				result.PatternType.STATIC_UPDATE_PRIMARY_PATTERN,
				STATIC_UPDATE_INDEX,
			)

	return next_cells


func _can_assign_primary_pattern(p_coords : Vector2i, p_tile_terrain : int) -> bool:
	var coords := p_coords
	var tile_terrain : int = p_tile_terrain

	# a somewhat quicker exit? (0.004s -> 0.003s for 32x32 map)
	var unique_neighbor_terrains : Array = _cell_unique_neighbor_terrains[p_coords]
	if unique_neighbor_terrains.size() == 1 && unique_neighbor_terrains[0] == p_tile_terrain:
		var no_neighbor_patterns := true
		for neighbor_coords in _cell_all_neighbor_coords[p_coords]:
			if _cell_patterns.has(neighbor_coords):
				no_neighbor_patterns = false
				break
		if no_neighbor_patterns:
			return true

	var primary_peering_terrain := terrains_data.get_primary_peering_terrain(tile_terrain)
	var allow_empty := not terrains_data.can_match_to_empty(tile_terrain)

	for neighbor in _all_peering_bit_neighbors:
		var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)
		var neighbor_terrain : int = _cell_terrains[neighbor_coords]

		if _cell_patterns.has(neighbor_coords):
			if allow_empty && neighbor_terrain == EMPTY_TERRAIN:
				continue
			var neighbor_pattern : TerrainPattern = _cell_patterns[neighbor_coords]
			var neighbor_overlapping_bits := cn.get_neighbor_overlapping_bits(neighbor)
			for bit in neighbor_overlapping_bits:
				if neighbor_pattern.get_bit_peering_terrain(bit) != primary_peering_terrain:
					return false
			continue

			return false

		if neighbor_terrain == tile_terrain:
			continue

		# used in case of custom primary peering terrains
		if terrains_data.get_primary_peering_terrain(neighbor_terrain) == primary_peering_terrain:
			continue
		return false

	return true


# --------------------------
# 	COMPLEX PATTERNS
# --------------------------

# this is an unpleasantly long function, with duplicates from _assign_simple_patterns
# would be nice to divide it up, but need to be prudent in avoiding extra function calls
func _assign_complex_patterns(p_cells : Array[Vector2i], p_test_neighbor_complexity : bool) -> bool:
	var next_cells := p_cells
	while next_cells.size():
		var coords : Vector2i = next_cells.pop_back()
		if not _cell_needs_pattern(coords):
			continue

		if cell_logging:
			result.add_cell_log(coords, ["_assign_complex_patterns()"])

		var success := _assign_matching_pattern(coords, true)
		var neighbors_verified := false

		if not success:
			var is_match_possible := _is_match_possible(coords)
			if is_match_possible:
				var backtrack_result := _backtrack_at_coords(coords)
				if backtrack_result["success"] == false:
					if backtrack_result["expanded_update_requested"] == true:
						result.add_cell_warning(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
						return EXPANDED_UPDATE_REQUESTED
					# re-add the neighbors patterns we just cleared
					# but don't bother checking or adding other neighbors
					# if coords does not have a pattern assigned
					next_cells.append_array(backtrack_result["neighbors_needing_new_patterns"])
					result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
					continue
				# else - continue onward; if we've already backtracked, we know neighbors can match
				# (or we've given up on them)
				neighbors_verified = true
			else:
				# don't check or add neighbors
				_non_matching_cells_set[coords] = true
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
				continue

		if not neighbors_verified:
			# TODO: this should be a separate function
			var neighbors_can_match := true
			for neighbor_coords in _get_neighbors_needing_matches(coords):
				if cell_logging:
					result.add_cell_log(coords, "Evaluating neighbor for possible matches: %s" % neighbor_coords)
				var neighbor_search_pattern := _create_search_pattern(neighbor_coords)
				var neighbor_possible_patterns := terrains_data.find_patterns(neighbor_search_pattern)
				if cell_logging:
					result.add_cell_log(neighbor_coords, "complex neighbor: possible patterns = %s" % neighbor_possible_patterns.size())
				if neighbor_possible_patterns.is_empty():
					if not _is_match_possible(neighbor_coords):
						_non_matching_cells_set[neighbor_coords] = true
						continue
					neighbors_can_match = false

			if not neighbors_can_match:
				var backtrack_result := _backtrack_at_coords(coords)
				if backtrack_result["expanded_update_requested"] == true:
					return EXPANDED_UPDATE_REQUESTED
				next_cells.append_array(backtrack_result["neighbors_needing_new_patterns"])

		if not p_test_neighbor_complexity:
			continue

		for neighbor_coords in _get_neighbors_needing_matches(coords):
			if next_cells.has(neighbor_coords):
				continue
			if not _cell_needs_pattern(neighbor_coords):
				continue
			var neighbor_search_pattern := _get_or_create_search_pattern(neighbor_coords)
			if not neighbor_search_pattern:
				continue
			var unique_peering_terrain_count := neighbor_search_pattern.get_unique_peering_terrains().size()
			if unique_peering_terrain_count >= COMPLEX_TERRAIN_COUNT:
				next_cells.append(neighbor_coords)

	return SUCCESS


func _backtrack_at_coords(p_coords : Vector2i) -> Dictionary:
#	print("_backtrack_at_coords: %s" % p_coords)
	var backtrack_result := {
		"expanded_update_requested": false,
		"neighbors_needing_new_patterns": [],
		"success": true,
	}

	if cell_logging:
		result.add_cell_log(p_coords, "**********\nbacktracking starting here")

	var neighbors_needing_new_patterns := _clear_cells_for_backtracking(p_coords)

	# don't need to add search_pattern to list
	# it will not be needed for these coords anymore
	var search_pattern := _create_search_pattern(p_coords)
	var possible_patterns := terrains_data.find_patterns(search_pattern)
	if possible_patterns.size() == 0:
		backtrack_result["success"] = false
		if cell_logging:
			result.add_cell_log(p_coords, "unable to find pattern for p_coords")
		if _expanded_update_available:
			# already checked to see that coords can match
			backtrack_result["expanded_update_requested"] = true
		else:
			_non_matching_cells_set[p_coords] = true
			backtrack_result["neighbors_needing_new_patterns"] = neighbors_needing_new_patterns
		return backtrack_result

	var highest_score_pattern := _get_max_score_pattern(search_pattern, possible_patterns, false)
	var next_pattern := highest_score_pattern

	_move_unmatchable_neighbors_to_non_matching(p_coords)
	var matchable_neighbors := _get_neighbors_needing_matches(p_coords)

	while next_pattern:
		var success := true

		# don't update neighbor search patterns here
		# since we are manually creating them
		_cell_patterns[p_coords] = next_pattern


		if cell_logging:
			result.add_cell_log(p_coords, "backtrack progenitor: assigning next_pattern")
			_log_assign_pattern(
				p_coords,
				next_pattern,
				false,
				result.PatternType.COMPLEX_BEST_PATTERN,
			)

		for neighbor_coords in matchable_neighbors:
			var neighbor_search_pattern := _create_search_pattern(neighbor_coords)
			var neighbor_possible_patterns := terrains_data.find_patterns(neighbor_search_pattern)
			if cell_logging:
				result.add_cell_log(neighbor_coords, "backtrack neighbor: possible patterns = %s" % neighbor_possible_patterns.size())

			if neighbor_possible_patterns.is_empty():
				if possible_patterns.is_empty():
					_non_matching_cells_set[neighbor_coords] = true
					neighbors_needing_new_patterns.erase(neighbor_coords)
					continue

				success = false
				break

		if success:
			break

		possible_patterns.erase(next_pattern)
		if possible_patterns.is_empty():
			backtrack_result["success"] = false
			if _expanded_update_available:
				backtrack_result["expanded_update_requested"] = true
				return backtrack_result
			# else: no expanded update available
			next_pattern = highest_score_pattern
		else:
			next_pattern = _get_max_score_pattern(search_pattern, possible_patterns, false)

	_locked_cells_set[p_coords] = true # don't allow changing this cell again
	backtrack_result["neighbors_needing_new_patterns"] = neighbors_needing_new_patterns
	return backtrack_result


func _clear_cells_for_backtracking(p_coords : Vector2i) -> Array[Vector2i]:
	var neighbors_with_erased_patterns : Array[Vector2i] = []

	_cell_search_patterns[p_coords] = null
	_cell_patterns.erase(p_coords)

	for neighbor_coords in _cell_all_neighbor_coords[p_coords]:
		# doesn't matter if neighbor has pattern or not, ok to set to null
		# will only re-create if needed
		_cell_search_patterns.erase(neighbor_coords)
		if _locked_cells_set.has(neighbor_coords):
			continue

		if _cell_patterns.has(neighbor_coords):
			_cell_patterns.erase(neighbor_coords)
			neighbors_with_erased_patterns.append(neighbor_coords)
			for second_neighbor_coords in _cell_all_neighbor_coords[neighbor_coords]:
				# leave second level neighbor patterns
				# but clear the search patterns
				_cell_search_patterns.erase(second_neighbor_coords)
	return neighbors_with_erased_patterns


func _move_unmatchable_neighbors_to_non_matching(p_coords : Vector2i) -> void:
	for neighbor_coords in _get_neighbors_needing_matches(p_coords):
		if _is_match_possible(neighbor_coords):
			continue
		_non_matching_cells_set[neighbor_coords] = true



func _get_neighbors_needing_matches(p_coords : Vector2i) -> Array[Vector2i]:
	var matchable_neighbors : Array[Vector2i] = []
	for neighbor_coords in _cell_all_neighbor_coords[p_coords]:
		if not _cell_needs_pattern(neighbor_coords):
			continue
		matchable_neighbors.append(neighbor_coords)
	return matchable_neighbors


func _cell_needs_pattern(p_coords : Vector2i, p_exclude_non_matching := true) -> bool:
	if p_exclude_non_matching && _non_matching_cells_set.has(p_coords):
		return false
	if _cell_patterns.has(p_coords):
		return false
	if _cell_terrains[p_coords] == EMPTY_TERRAIN:
		return false
	return true



# --------------------------
# 	SIMPLE PATTERNS
# --------------------------

func _assign_simple_patterns(p_cells : Array[Vector2i]) -> bool:
	while p_cells.size():
		var coords : Vector2i = p_cells.pop_back()
		if not _cell_needs_pattern(coords):
			continue

		if cell_logging:
			result.add_cell_log(coords, ["_assign_simple_patterns()"])

		var success := _assign_matching_pattern(coords, false)

		if not success:
			var is_match_possible := _is_match_possible(coords)
			if _expanded_update_available && is_match_possible:
				# exit and restart with larger update area
				result.add_cell_warning(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
				return EXPANDED_UPDATE_REQUESTED
			_non_matching_cells_set[coords] = true
			if is_match_possible:
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
			else:
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
			continue

	return SUCCESS




# --------------------------
# 	NON-MATCHING PATTERNS
# --------------------------

func _assign_non_matching_patterns() -> void:
	for coords in _non_matching_cells_set:
		if not _cell_needs_pattern(coords, false):
			continue
		var search_pattern := _get_or_create_search_pattern(coords)
		var possible_patterns := terrains_data.get_patterns_by_terrain(search_pattern.tile_terrain)
		var pattern := _get_max_score_pattern(search_pattern, possible_patterns, true)
		_set_cell_pattern_and_update_search(coords, search_pattern, pattern)
		if cell_logging:
			_log_assign_pattern(
				coords,
				pattern,
				false,
				result.PatternType.NON_MATCHING_BEST_PATTERN,
			)



# --------------------------
# 	MATCH HELPER FUNCTIONS
# --------------------------

func _assign_matching_pattern(p_coords : Vector2i, p_complex : bool) -> bool:
	# have already checked to ensure that needs a matching pattern
	var search_pattern : SearchPattern = _get_or_create_search_pattern(p_coords)

	if cell_logging:
		result.add_cell_log(p_coords, ["-- _assign_matching_pattern: update #%s --" % (result._current_update_index + 1), search_pattern])

	var matching_pattern_result := _get_matching_pattern(search_pattern, p_complex)
	var pattern : TerrainPattern = matching_pattern_result["pattern"]

	if not pattern:
		if cell_logging:
			result.add_cell_log(p_coords, "No pattern found.")
		if search_pattern.can_match_to_empty && search_pattern.has_empty_neighbor():
			if cell_logging:
				result.add_cell_log(p_coords, "Simulating no match to empty...")
			search_pattern = _create_search_pattern(p_coords, false, false)
			matching_pattern_result = _get_matching_pattern(search_pattern, p_complex)
			pattern = matching_pattern_result["pattern"]

	if pattern:
		_set_cell_pattern_and_update_search(p_coords, search_pattern, pattern)
		if cell_logging:
			_log_assign_pattern(
				p_coords,
				pattern,
				false,
				matching_pattern_result["pattern_type"],
			)
		return SUCCESS

	return FAILED



func _get_matching_pattern(p_search_pattern : SearchPattern, p_complex : bool) -> Dictionary:
	var pattern : TerrainPattern

	var top_pattern := p_search_pattern.get_top_pattern()
	var pattern_type := UpdateResult.PatternType.SIMPLE_BEST_PATTERN
	if p_complex:
		pattern_type = UpdateResult.PatternType.COMPLEX_BEST_PATTERN

	if top_pattern:
		pattern = terrains_data.get_pattern(top_pattern)
		if pattern:
			if p_complex:
				pattern_type = UpdateResult.PatternType.COMPLEX_TOP_PATTERN
			else:
				pattern_type = result.PatternType.SIMPLE_TOP_PATTERN

	if not pattern:
		var possible_patterns := terrains_data.find_patterns(p_search_pattern)
		pattern = _get_max_score_pattern(p_search_pattern, possible_patterns, false)

	return {"pattern_type": pattern_type, "pattern": pattern}


func _get_max_score_pattern(p_search_pattern : SearchPattern, p_patterns : Array, p_allow_non_matching : bool) -> TerrainPattern:
	# result.start_timer("_get_max_score_pattern()")
	if cell_logging:
		result.add_cell_log(p_search_pattern.coords, "get max score pattern:")
	var max_score := -1000000
	var max_score_pattern : TerrainPattern

	for pattern in p_patterns:
		var score := p_search_pattern.get_match_score(pattern, p_allow_non_matching)
		if cell_logging:
			result.add_cell_log(
				p_search_pattern.coords,
				[
					"score = %s" % score,
					pattern,
					"------",
				]
			)
		if score > max_score:
			max_score = score
			max_score_pattern = pattern
	# result.stop_timer("_get_max_score_pattern()")
	return max_score_pattern



func _is_match_possible(p_coords : Vector2i) -> bool:
	# result.start_timer("_is_match_possible()")
	var search_pattern := _create_search_pattern(p_coords, true)
	# result.start_timer("find_patterns")
	var possible_patterns := terrains_data.find_patterns(search_pattern)
	# result.stop_timer("find_patterns")
	if cell_logging:
		result.add_cell_log(p_coords, "_is_match_possible() = %s" % not possible_patterns.is_empty())
	# result.stop_timer("_is_match_possible()")
	return not possible_patterns.is_empty()



func _set_cell_pattern_and_update_search(p_coords : Vector2i, p_search_pattern : SearchPattern, p_pattern : TerrainPattern) -> void:
	_cell_patterns[p_coords] = p_pattern
	p_search_pattern.pattern = p_pattern
	# this will automatically update all neighbor search patterns
	for neighbor_coords in _cell_all_neighbor_coords[p_coords]:
		# only need to update search patterns that actually exist, so don't use _get_or_create here
		var neighbor_search_pattern : SearchPattern = _cell_search_patterns.get(neighbor_coords, null)
		if not neighbor_search_pattern:
			continue
		if neighbor_search_pattern.pattern:
			# if neighbor already has pattern assigned, no need to update its search
			continue
		neighbor_search_pattern.add_neighbor_pattern(p_coords, p_pattern)


func _get_or_create_search_pattern(p_coords : Vector2i) -> SearchPattern:
	# result.start_timer("_get_or_create_search_pattern()")
	var search_pattern : SearchPattern = _cell_search_patterns.get(p_coords, null)
	if not search_pattern:
		search_pattern = _create_search_pattern(p_coords)
		_cell_search_patterns[p_coords] = search_pattern
	# result.stop_timer("_get_or_create_search_pattern()")

	if cell_logging:
		result.add_cell_log(p_coords, ["-- %s --" % result._current_update_index, search_pattern])

	return search_pattern


# p_use_terrain_for_locked_neighbors is only used for hypothetical testing
# if match is possible
# p_allow_match_to_empty is used to try to force cells to simulate empty match if they
# only sometimes match to empty
func _create_search_pattern(p_coords : Vector2i, p_no_pattern_for_locked_neighbors := false, p_allow_match_to_empty := true) -> SearchPattern:
	# result.start_timer("_create_search_pattern()")
	var coords := p_coords
	var tile_terrain : int = _cell_terrains[p_coords]
	var search_pattern = SearchPattern.new(terrains_data, tile_terrain, p_allow_match_to_empty)
	search_pattern.coords = coords

	for bit in peering_bits:
		for neighbor in cn.get_peering_bit_cell_neighbors(bit):
			var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)
			var neighbor_bit := cn.get_peering_bit_cell_neighbor_peering_bit(bit, neighbor)
			var neighbor_terrain : int = _cell_terrains.get(neighbor_coords, EMPTY_TERRAIN)
			search_pattern.add_neighbor(bit, neighbor_coords, neighbor_bit, neighbor_terrain)
			if p_no_pattern_for_locked_neighbors:
				if not _locked_cells_set.has(neighbor_coords):
					continue
				if _expandable_neighbors_set.has(neighbor_coords):
					continue

			var neighbor_pattern : TerrainPattern = _cell_patterns.get(neighbor_coords, null)
			if neighbor_pattern:
				var error := search_pattern.add_neighbor_pattern(neighbor_coords, neighbor_pattern)
				if error:
					result.add_cell_error(p_coords, UpdateResult.CellError.INVALID_SEARCH_CONFLICTING_NEIGHBORS)

	# result.stop_timer("_create_search_pattern()")
	return search_pattern



# --------------------------
# UPDATE MAP
# --------------------------

# this isn't as slow as it feels like it should be
# still, it seems like there should be a more efficient way to do this
# but we currently only find the patterns for cells we're *not* updating
# and for most cells that *are* updated, we never look at TileData until now

func _update_map() -> void:
	# result.start_timer("_update_map()")
	var old_tiles := {}
	var new_tiles := {}

	for coords in _update_cells:
		var pattern : TerrainPattern = _cell_patterns.get(coords, null)
		if not pattern:
			result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_ASSIGNED)
			continue

		var tile_data := tile_map.get_cell_tile_data(layer, coords)
		var old_pattern : TerrainPattern
		if not tile_data or tile_data.terrain_set == Autotiler.NULL_TERRAIN_SET or tile_data.terrain == Autotiler.EMPTY_TERRAIN:
			old_pattern = terrains_data.empty_pattern
		else:
			var tile_data_pattern := TerrainPattern.new(cn.get_peering_bits()).create_from_tile_data(tile_data)
			old_pattern = terrains_data.get_pattern(tile_data_pattern, true)
		if old_pattern == pattern:
			continue

		old_tiles[coords] = _get_tile_location_from_cell(coords)

		if pattern.tile_terrain == Autotiler.EMPTY_TERRAIN:
			tile_map.erase_cell(layer, coords)
			new_tiles[coords] = null
			continue

		var tile_location := pattern.get_tile()
		if not tile_location or not tile_location.validate():
			push_error("No valid tile found for pattern")
			continue

		new_tiles[coords] = tile_location

		tile_map.set_cell(
			layer,
			coords,
			tile_location.source_id,
			tile_location.atlas_coords,
			tile_location.alternative_tile_id,
		)

	result.cell_tiles_before = old_tiles
	result.cell_tiles_after = new_tiles

	if cell_logging:
		_log_map_update(_update_cells, new_tiles)
	# result.stop_timer("_update_map()")



func _get_tile_location_from_cell(p_coords : Vector2i) -> TileLocation:
	var source_id := tile_map.get_cell_source_id(layer, p_coords)
	var atlas_coords := tile_map.get_cell_atlas_coords(layer, p_coords)
	var alternative_tile_id := tile_map.get_cell_alternative_tile(layer, p_coords)
	return TileLocation.new(source_id, atlas_coords, alternative_tile_id)



# -------------------
# LOG FUNCTIONS
# -------------------

func _log_assign_pattern(
		p_coords : Vector2i,
		p_pattern : TerrainPattern,
		p_locked : bool,
		p_type : UpdateResult.PatternType,
		p_update_index := -99,
	) -> void:

	if p_update_index == -99:
		result.assign_next_update_index(p_coords)
	else:
		result.set_cell_update_index(p_coords, p_update_index)
	result.set_cell_pattern_type(p_coords, p_type)
	result.add_cell_log(p_coords, [p_pattern, "locked=%s" % str(p_locked)])


func _log_add_painted_cell(p_coords : Vector2i, p_terrain : int) -> void:
	result.set_cell_update_index(p_coords, -1)
	result.add_cell_log(p_coords, "Added as painted cell (terrain=%s)" % terrains_data.terrain_names[p_terrain])


func _log_add_neighbor_cell(p_coords : Vector2i, p_pattern : TerrainPattern) -> void:
	_log_assign_pattern(
		p_coords,
		p_pattern,
		true,
		UpdateResult.PatternType.NEIGHBOR,
		-1,
	)

func _log_map_update(p_cells : Array[Vector2i], p_changed_cells : Dictionary) -> void:
	for coords in p_cells:
		if p_changed_cells.has(coords):
			result.add_cell_log(coords, "Map tile changed")
		else:
			result.add_cell_log(coords, "Map tile unchanged")

