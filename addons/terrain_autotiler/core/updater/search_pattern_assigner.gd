extends RefCounted

const EXPANDED_UPDATE_REQUESTED := Error.ERR_LOCKED
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN

const COMPLEX_TERRAIN_COUNT := 3


const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")
const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")

var request : Request
var cells : Dictionary
var expanded_update_available : bool

var terrains_data : TerrainsData
var tile_map : TileMap
var cell_logging : bool
var result : UpdateResult

var cn : CellNeighbors
var peering_bits : Array
#var all_peering_bit_neighbors := []

var cells_to_update := {} # nested terrain/priority dict
var non_matching_cells_set := {} # {coords : true}
var search_patterns := {} # {coords : SearchPattern}


func assign_search_patterns(
		p_request : Request,
		p_cells : Dictionary,
		p_unassigned_cells : Array[Vector2i]
	) -> Error:

	var unassigned_cells := p_unassigned_cells

	if not p_request or p_cells.is_empty():
		return Error.ERR_UNCONFIGURED

	request = p_request
	result = request.update_result
	cells = p_cells

	expanded_update_available = cells.can_expand
#	print("expanded_update_available = %s" % cells.can_expand)


	tile_map = request.tile_map
	cell_logging = request.cell_logging

	terrains_data = request.terrains_data
	cn = terrains_data.cn
	peering_bits = cn.get_peering_bits()
#	all_peering_bit_neighbors = terrains_data.cn.get_all_peering_bit_cell_neighbors()

	_create_cells_to_update(p_unassigned_cells)

	var tile_terrains := terrains_data.sorted_tile_terrains
	for unique_terrain_count in range(12, -1, -1):
		var cells_by_terrain : Dictionary = cells_to_update.get(unique_terrain_count, {})
		if cells_by_terrain.is_empty():
			continue
		for tile_terrain in tile_terrains:
			if not cells_by_terrain.has(tile_terrain):
				continue
			var error := Error.OK
			if unique_terrain_count >= COMPLEX_TERRAIN_COUNT:
				error = _assign_complex_patterns(cells_by_terrain[tile_terrain], true)
			else:
				if terrains_data.full_set_tile_terrains_set.has(tile_terrain):
					error = _assign_simple_patterns(cells_by_terrain[tile_terrain])
				else:
					# if a terrain does not have a full set, it may
					# require backtracking
					error = _assign_complex_patterns(cells_by_terrain[tile_terrain], false)
			if error != Error.OK:
				# will only occur if need expanded update
				# & already confirmed it is available
				return error

	_assign_non_matching_patterns()

	return Error.OK


# -----------------------------------------------------------------------------

func _create_cells_to_update(p_cells : Array[Vector2i]) -> void:
	# skip sorting for simple tilesets
	var tile_terrains_count := terrains_data.tile_terrains.size()
	if tile_terrains_count == 1:
		cells_to_update = {2: _create_dictionary_by_terrain(p_cells)}
	elif tile_terrains_count == 2:
		var skip_complex_match := true
		for tile_terrain in terrains_data.tile_terrains:
			if terrains_data.can_match_to_empty(tile_terrain):
				# this means there can be 3 terrains to consider
				skip_complex_match = false
		if skip_complex_match:
			cells_to_update = {2: _create_dictionary_by_terrain(p_cells)}

	if cells_to_update.is_empty():
		for coords in p_cells:
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


func _create_dictionary_by_terrain(p_cells : Array[Vector2i]) -> Dictionary:
	var cells_by_terrain := {}
	for coords in p_cells:
		var tile_terrain : int = cells.terrains[coords]
		if not cells_by_terrain.has(tile_terrain):
			var array : Array[Vector2i] = []
			cells_by_terrain[tile_terrain] = array
		cells_by_terrain[tile_terrain].append(coords)
	return cells_by_terrain





# -----------------------------------------------------------------------------


func _assign_complex_patterns(p_cells : Array[Vector2i], p_test_neighbor_complexity : bool) -> Error:
	var next_cells := p_cells
	while next_cells.size():
		var coords : Vector2i = next_cells.pop_back()
		if not _cell_needs_pattern(coords):
			continue

		if cell_logging:
			result.add_cell_log(coords, ["_assign_complex_patterns()"])

		var error := _assign_matching_pattern(coords, true)
		var neighbors_verified := false

		if error:
			var is_match_possible := _is_match_possible(coords)
			if cell_logging:
				result.add_cell_log(coords, ["_assign_matching_pattern() not successful", "is_match_possible=%s" % is_match_possible])

			if is_match_possible:
				var backtrack_result := _backtrack_at_coords(coords)
				if backtrack_result["success"] == false:
					if backtrack_result["expanded_update_requested"] == true:
						result.add_cell_warning(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
						return EXPANDED_UPDATE_REQUESTED
					# re-add the neighbors patterns we just cleared
					# but don't bother checking or adding other neighbors
					# if coords does not have a pattern assigned
					non_matching_cells_set[coords] = true
					next_cells.append_array(backtrack_result["neighbors_needing_new_patterns"])
					result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
					continue
				# else - continue onward; if we've already backtracked, we know neighbors can match
				# (or we've given up on them)
				neighbors_verified = true
			else:
				# don't check or add neighbors
				non_matching_cells_set[coords] = true
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
				continue

		if not neighbors_verified:
			var neighbors_can_match := _can_neighbors_match(coords)

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

	return Error.OK


func _can_neighbors_match(p_coords : Vector2i) -> bool:
	var coords := p_coords
	for neighbor_coords in _get_neighbors_needing_matches(coords):
		var neighbor_search_pattern := _create_search_pattern(neighbor_coords)
		var neighbor_possible_patterns := terrains_data.find_patterns(neighbor_search_pattern)
		if cell_logging:
			result.add_cell_log(coords, "neighbor at %s possible patterns: %s" % [neighbor_coords, neighbor_possible_patterns.size()])
			result.add_cell_log(neighbor_coords, "complex neighbor: possible patterns = %s" % neighbor_possible_patterns.size())
		if neighbor_possible_patterns.is_empty():
			if not _is_match_possible(neighbor_coords):
				# if the neighbor can't match no matter what,
				# disregard this neighbor
				non_matching_cells_set[neighbor_coords] = true
				continue
			return false
	return true



func _backtrack_at_coords(p_coords : Vector2i) -> Dictionary:
	var backtrack_result := {
		"expanded_update_requested": false,
		"neighbors_needing_new_patterns": [],
		"success": true,
	}

	if cell_logging:
		result.add_cell_log(p_coords, "**********\nbacktracking starting here")
		result.add_cell_warning(p_coords, UpdateResult.CellError.BACKTRACK_PROGENITOR)

	var neighbors_needing_new_patterns := _clear_cells_for_backtracking(p_coords)

	# don't need to add search_pattern to list
	# it will not be needed for these coords anymore
	var search_pattern := _create_search_pattern(p_coords)
	var possible_patterns := terrains_data.find_patterns(search_pattern)
	if possible_patterns.size() == 0:
		backtrack_result["success"] = false
		if cell_logging:
			result.add_cell_log(p_coords, "unable to find pattern for p_coords")
		if expanded_update_available:
			# already checked to see that coords can match
			backtrack_result["expanded_update_requested"] = true
		else:
			non_matching_cells_set[p_coords] = true
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
		cells.patterns[p_coords] = next_pattern


		if cell_logging:
			result.add_cell_log(p_coords, "backtrack progenitor: assigning next_pattern")
			result.log_assign_pattern(
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
					non_matching_cells_set[neighbor_coords] = true
					neighbors_needing_new_patterns.erase(neighbor_coords)
					continue

				success = false
				break

		if success:
			break

		possible_patterns.erase(next_pattern)
		if possible_patterns.is_empty():
			backtrack_result["success"] = false
			if cell_logging:
				result.add_cell_log(p_coords, "possible_patterns.is_empty(), expanded update available = %s" % expanded_update_available)
			if expanded_update_available:
				backtrack_result["expanded_update_requested"] = true
				return backtrack_result
			# else: no expanded update available
			next_pattern = highest_score_pattern
		else:
			next_pattern = _get_max_score_pattern(search_pattern, possible_patterns, false)

	cells.sets.locked[p_coords] = true # don't allow changing this cell again
	backtrack_result["neighbors_needing_new_patterns"] = neighbors_needing_new_patterns
	return backtrack_result



func _clear_cells_for_backtracking(p_coords : Vector2i) -> Array[Vector2i]:
	var neighbors_with_erased_patterns : Array[Vector2i] = []

	search_patterns[p_coords] = null
	cells.patterns.erase(p_coords)

	for neighbor_coords in cells.neighbors_coords[p_coords]:
		# doesn't matter if neighbor has pattern or not, ok to set to null
		# will only re-create if needed
		search_patterns.erase(neighbor_coords)
		if cells.sets.locked.has(neighbor_coords):
			continue

		if cells.patterns.has(neighbor_coords):
			if cell_logging:
				result.add_cell_log(neighbor_coords, "backtrack neighbor - erasing pattern")
			cells.patterns.erase(neighbor_coords)
			neighbors_with_erased_patterns.append(neighbor_coords)
			for second_neighbor_coords in cells.neighbors_coords[neighbor_coords]:
				# leave second level neighbor patterns
				# but clear the search patterns
				search_patterns.erase(second_neighbor_coords)
	return neighbors_with_erased_patterns


func _get_neighbors_needing_matches(p_coords : Vector2i) -> Array[Vector2i]:
	var matchable_neighbors : Array[Vector2i] = []
	for neighbor_coords in cells.neighbors_coords[p_coords]:
		if not _cell_needs_pattern(neighbor_coords):
			continue
		matchable_neighbors.append(neighbor_coords)
	return matchable_neighbors


func _move_unmatchable_neighbors_to_non_matching(p_coords : Vector2i) -> void:
	for neighbor_coords in _get_neighbors_needing_matches(p_coords):
		if _is_match_possible(neighbor_coords):
			continue
		non_matching_cells_set[neighbor_coords] = true


# -----------------------------------------------------------------------------

func _assign_simple_patterns(p_cells : Array[Vector2i]) -> Error:
	while p_cells.size():
		var coords : Vector2i = p_cells.pop_back()
		if not _cell_needs_pattern(coords):
			continue

		if cell_logging:
			result.add_cell_log(coords, ["_assign_simple_patterns()"])

		var error := _assign_matching_pattern(coords, false)

		if error:
			var is_match_possible := _is_match_possible(coords)
			if cell_logging:
				result.add_cell_log(coords, ["_assign_simple_patterns -> assign_matching_pattern() unsuccessful", "is_match_possible=%s" % is_match_possible])

			if expanded_update_available && is_match_possible:
				# exit and restart with larger update area
				result.add_cell_warning(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
				return EXPANDED_UPDATE_REQUESTED
			non_matching_cells_set[coords] = true
			if is_match_possible:
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
			else:
				result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
			continue

	return Error.OK


# -----------------------------------------------------------------------------

func _assign_non_matching_patterns() -> void:
	for coords in non_matching_cells_set:
		if not _cell_needs_pattern(coords, false):
			continue
		if not result.cell_errors.has(coords):
			result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_FOUND)
		var search_pattern := _get_or_create_search_pattern(coords)
		var possible_patterns := terrains_data.get_patterns_by_terrain(search_pattern.tile_terrain)
		var pattern := _get_max_score_pattern(search_pattern, possible_patterns, true)
		_set_cell_pattern_and_update_search(coords, search_pattern, pattern)
		if cell_logging:
			result.log_assign_pattern(
				coords,
				pattern,
				false,
				result.PatternType.NON_MATCHING_BEST_PATTERN,
			)




# -----------------------------------------------------------------------------

func _is_match_possible(p_coords : Vector2i) -> bool:
	var search_pattern := _create_search_pattern(p_coords, true)
	var possible_patterns := terrains_data.find_patterns(search_pattern)
	if cell_logging:
		result.add_cell_log(p_coords, "_is_match_possible() = %s" % not possible_patterns.is_empty())
	return not possible_patterns.is_empty()


func _assign_matching_pattern(p_coords : Vector2i, p_complex : bool) -> Error:
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
			result.log_assign_pattern(
				p_coords,
				pattern,
				false,
				matching_pattern_result["pattern_type"],
			)
		return Error.OK

	return Error.FAILED


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


func _set_cell_pattern_and_update_search(p_coords : Vector2i, p_search_pattern : SearchPattern, p_pattern : TerrainPattern) -> void:
	cells.patterns[p_coords] = p_pattern
	p_search_pattern.pattern = p_pattern
	# this will automatically update all neighbor search patterns
	for neighbor_coords in cells.neighbors_coords[p_coords]:
		# only need to update search patterns that actually exist, so don't use _get_or_create here
		var neighbor_search_pattern : SearchPattern = search_patterns.get(neighbor_coords, null)
		if not neighbor_search_pattern:
			continue
		if neighbor_search_pattern.pattern:
			# if neighbor already has pattern assigned, no need to update its search
			continue
		neighbor_search_pattern.add_neighbor_pattern(p_coords, p_pattern)


# -----------------------------------------------------------------------------


func _cell_needs_pattern(p_coords : Vector2i, p_exclude_non_matching := true) -> bool:
	if p_exclude_non_matching && non_matching_cells_set.has(p_coords):
		return false
	if cells.patterns.has(p_coords):
		return false
	return true


func _get_or_create_search_pattern(p_coords : Vector2i) -> SearchPattern:
	var search_pattern : SearchPattern = search_patterns.get(p_coords, null)
	if not search_pattern:
		search_pattern = _create_search_pattern(p_coords)
		search_patterns[p_coords] = search_pattern

	if cell_logging:
		result.add_cell_log(p_coords, ["-- Search Pattern: Update #%s --" % result._current_update_index, search_pattern])

	return search_pattern


# p_use_terrain_for_locked_neighbors is only used for hypothetical testing
# if match is possible
# p_allow_match_to_empty is used to try to force cells to simulate empty match if they
# only sometimes match to empty
func _create_search_pattern(p_coords : Vector2i, p_no_pattern_for_locked_neighbors := false, p_allow_match_to_empty := true) -> SearchPattern:
	var coords := p_coords
	var tile_terrain : int = cells.terrains[p_coords]
	var search_pattern = SearchPattern.new(terrains_data, tile_terrain, p_allow_match_to_empty)
	search_pattern.coords = coords

	for bit in peering_bits:
		for neighbor in cn.get_peering_bit_cell_neighbors(bit):
			var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)
			var neighbor_bit := cn.get_peering_bit_cell_neighbor_peering_bit(bit, neighbor)
			var neighbor_terrain : int = cells.terrains.get(neighbor_coords, EMPTY_TERRAIN)
			search_pattern.add_neighbor(bit, neighbor_coords, neighbor_bit, neighbor_terrain)
			if p_no_pattern_for_locked_neighbors:
				if not cells.sets.locked.has(neighbor_coords):
					continue
				if cells.sets.neighbors.has(neighbor_coords):
					if not request.tile_map_locked_cells_set.has(neighbor_coords):
						continue

			var neighbor_pattern : TerrainPattern = cells.patterns.get(neighbor_coords, null)
			if neighbor_pattern:
				var error := search_pattern.add_neighbor_pattern(neighbor_coords, neighbor_pattern)
				if error:
					result.add_cell_error(p_coords, UpdateResult.CellError.INVALID_SEARCH_CONFLICTING_NEIGHBORS)

	return search_pattern
