extends RefCounted

var update : Dictionary





# --------------------------
#   LOAD SURROUNDING CELLS
# --------------------------
#
#func _load_surrounding_cells(p_cells : Array[Vector2i], p_update_neighbors : bool) -> void:
#	# result.start_timer("_load_surrounding_cells()")
#	if p_update_neighbors:
#		# save edge cells so we don't have to iterate all the updated cells
#		# to find neighbors at the edges
#		var edge_cells := _add_surrounding_cells_to_update(p_cells, true)
#		edge_cells = _add_surrounding_cells_to_update(edge_cells, false)
#		_add_surrounding_cells_as_neighbors(edge_cells)
#	else:
#		_add_surrounding_cells_as_neighbors(p_cells)
#	# result.stop_timer("_load_surrounding_cells()")
#
#
#
#func _add_surrounding_cells_to_update(p_cells : Array[Vector2i], p_add_neighbors_of_empty : bool) -> Array[Vector2i]:
#	var edge_cells_set := {}
#	for coords in p_cells.duplicate():
#		if not p_add_neighbors_of_empty:
#			var tile_terrain : int = _cell_terrains[coords]
#			if tile_terrain == EMPTY_TERRAIN or terrains_data.single_pattern_terrains.has(tile_terrain):
#				# if empty or single pattern terrains were painted, need to update their neighbors
#				# but if they were added *as* neighbors, do not need to add *their* neighbors
#				continue
#
#		for neighbor_coords in _cell_all_neighbor_coords[coords]:
#			if _cell_terrains.has(neighbor_coords):
#				continue
#			if _tile_map_locked_cells_set.has(neighbor_coords):
#				edge_cells_set[coords] = true
#				continue
#			_add_cell_from_tile_data(neighbor_coords, UPDATE)
#			edge_cells_set[neighbor_coords] = true
#
#	var edge_cells : Array[Vector2i] = []
#	edge_cells.assign(edge_cells_set.keys())
#	return edge_cells
#
#
#
#
#func _add_surrounding_cells_as_neighbors(p_cells : Array[Vector2i]) -> void:
#	for coords in p_cells:
#		var tile_terrain : int = _cell_terrains[coords]
#		if tile_terrain == EMPTY_TERRAIN:
#			# (don't skip single pattern terrain here, need to know if expandable)
#			# skip empty cells
#			# even if they are painted, we can update them
#			# without knowing their neighbors
#			# (neighbors are only needed if they themselves need updating)
#			continue
#
#		for neighbor_coords in _cell_all_neighbor_coords[coords]:
#			if _cell_terrains.has(neighbor_coords):
#				continue
#			_add_cell_from_tile_data(neighbor_coords, NO_UPDATE)
#
#
#func _add_cell_from_tile_data(p_coords : Vector2i, p_update : bool) -> void:
#	var tile_data := tile_map.get_cell_tile_data(layer, p_coords)
#
#	if tile_data == null or tile_data.terrain_set != terrains_data.terrain_set:
#		# these are empty cells or tiles not in this terrain set
#		# add them to the more permanent _tile_map_locked_cells_set
#		# so that if expanded update, will know should not be replaced
#		_tile_map_locked_cells_set[p_coords] = true
#		_add_neighbor_cell(p_coords, terrains_data.empty_pattern)
#		return
#
#	if p_update:
#		_add_painted_cell(p_coords, tile_data.terrain)
#		return
#
#	if not _tile_map_has_locked_cells or not _tile_map_locked_cells_set.has(p_coords):
#		_has_non_empty_neighbors = true
#
#	var pattern := TerrainPattern.new(peering_bits).create_from_tile_data(tile_data)
#	_add_neighbor_cell(p_coords, pattern)
#
#
#func _add_painted_cell(p_coords : Vector2i, p_terrain : int) -> void:
#	_cell_terrains[p_coords] = p_terrain
#	_update_cells.append(p_coords)
#
#	var cell_neighbor_array : Array[Vector2i] = []
#	for neighbor in _all_peering_bit_neighbors:
#		var neighbor_coords := tile_map.get_neighbor_cell(p_coords, neighbor)
#		cell_neighbor_array.append(neighbor_coords)
#	_cell_all_neighbor_coords[p_coords] = cell_neighbor_array
#
#	if cell_logging:
#		_log_add_painted_cell(p_coords, p_terrain)
#
#
#func _add_neighbor_cell(p_coords : Vector2i, p_pattern : TerrainPattern) -> void:
#	_cell_terrains[p_coords] = p_pattern.tile_terrain
#	_cell_patterns[p_coords] = p_pattern
#	_locked_cells_set[p_coords] = true
#	if not _tile_map_locked_cells_set.has(p_coords):
#		_expandable_neighbors_set[p_coords] = true
#	if cell_logging:
#		_log_add_neighbor_cell(p_coords, p_pattern)
