extends RefCounted

const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN
const STATIC_UPDATE_INDEX := 0

const Request := preload("res://addons/terrain_autotiler/core/updater/request.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")

var request : Request
var cells : Dictionary
var terrains_data : TerrainsData
var tile_map : TileMap
var cell_logging : bool
var result : UpdateResult

var all_peering_bit_neighbors := []
var cell_unique_neighbor_terrains := {}


func assign_static_patterns(p_request : Request, p_cells : Dictionary) -> Array[Vector2i]:
	var unassigned_cells : Array[Vector2i] = []

	if not p_request or p_cells.is_empty():
		return unassigned_cells

	request = p_request
	result = request.update_result
	cells = p_cells
	terrains_data = request.terrains_data
	all_peering_bit_neighbors = terrains_data.cn.get_all_peering_bit_cell_neighbors()
	tile_map = request.tile_map
	cell_logging = request.cell_logging

	var empty_pattern := request.terrains_data.empty_pattern
	var single_pattern_terrains := request.terrains_data.single_pattern_terrains

	var cell_primary_patterns := {}

	for coords in cells.sets.update:
		# assign empty patterns
		var tile_terrain : int = cells.terrains[coords]
		if tile_terrain == EMPTY_TERRAIN:
			cells.patterns[coords] = empty_pattern
			cells.sets.locked[coords] = true
			if cell_logging:
				result.log_assign_pattern(
					coords,
					empty_pattern,
					true,
					UpdateResult.PatternType.STATIC_UPDATE_EMPTY,
					STATIC_UPDATE_INDEX,
				)
			continue

		# assign missing patterns
		if not terrains_data.tile_terrains.has(tile_terrain):
			# if terrain wasn't added to tile terrains, it means it has no patterns
			cells.patterns[coords] = terrains_data.empty_pattern
			cells.sets.locked[coords] = true
			result.add_cell_error(coords, UpdateResult.CellError.NO_PATTERN_EXISTS)
			if cell_logging:
				result.log_assign_pattern(
					coords,
					empty_pattern,
					true,
					UpdateResult.PatternType.STATIC_UPDATE_MISSING,
					STATIC_UPDATE_INDEX,
				)
			continue


		# assign single-pattern terrains
		var single_pattern : TerrainPattern = single_pattern_terrains.get(tile_terrain, null)
		if single_pattern:
			cells.patterns[coords] = single_pattern
			cells.sets.locked[coords] = true
			if cell_logging:
				result.log_assign_pattern(
					coords,
					single_pattern,
					true,
					UpdateResult.PatternType.STATIC_UPDATE_SINGLE_PATTERN,
					STATIC_UPDATE_INDEX,
				)
			continue

		# assign primary patterns
		# creating SearchPatterns here would make the code much shorter/simpler
		# but doing this manually is 2x faster
		var neighbor_terrains_set := {}
		for neighbor_coords in cells.neighbors_coords[coords]:
			var neighbor_terrain : int = cells.terrains[neighbor_coords]
			neighbor_terrains_set[neighbor_terrain] = true
		if not terrains_data.can_match_to_empty(tile_terrain): # TODO: make into lookup
			# will count as own terrain
			neighbor_terrains_set.erase(EMPTY_TERRAIN)
		cell_unique_neighbor_terrains[coords] = neighbor_terrains_set.keys()

		var primary_pattern := terrains_data.get_primary_pattern(tile_terrain) # TODO: make into lookup
		if primary_pattern && _can_assign_primary_pattern(coords, tile_terrain):
			cell_primary_patterns[coords] = primary_pattern
			# result.stop_timer("_can_assign_primary_pattern()")
			continue

		# assign remaining cells to list to return
		unassigned_cells.append(coords)

	# waiting to assign patterns until after all primary patterns have been
	# found saves time since having fewer neighbors with patterns allows
	# an early exit from _can_assign_primary_pattern
	for coords in cell_primary_patterns:
		cells.patterns[coords] = cell_primary_patterns[coords]
		cells.sets.locked[coords] = true
		if cell_logging:
			result.log_assign_pattern(
				coords,
				cell_primary_patterns[coords],
				true,
				UpdateResult.PatternType.STATIC_UPDATE_PRIMARY_PATTERN,
				STATIC_UPDATE_INDEX,
			)

	return unassigned_cells




func _can_assign_primary_pattern(p_coords : Vector2i, p_tile_terrain : int) -> bool:
	var coords := p_coords
	var tile_terrain : int = p_tile_terrain

	# a somewhat quicker exit? (0.004s -> 0.003s for 32x32 map)
	var unique_neighbor_terrains : Array = cell_unique_neighbor_terrains[coords]
	if unique_neighbor_terrains.size() == 1 && unique_neighbor_terrains[0] == p_tile_terrain:
		var no_neighbor_patterns := true
		for neighbor_coords in cells.neighbors_coords[p_coords]:
			if cells.patterns.has(neighbor_coords):
				no_neighbor_patterns = false
				break
		if no_neighbor_patterns:
			return true

	var primary_peering_terrain := terrains_data.get_primary_peering_terrain(tile_terrain)
	var allow_empty := not terrains_data.can_match_to_empty(tile_terrain)

	for neighbor in all_peering_bit_neighbors:
		var neighbor_coords := tile_map.get_neighbor_cell(coords, neighbor)
		var neighbor_terrain : int = cells.terrains[neighbor_coords]

		if cells.patterns.has(neighbor_coords):
			if allow_empty && neighbor_terrain == EMPTY_TERRAIN:
				continue
			var neighbor_pattern : TerrainPattern = cells.patterns[neighbor_coords]
			var neighbor_overlapping_bits := terrains_data.cn.get_neighbor_overlapping_bits(neighbor)
			for bit in neighbor_overlapping_bits:
				if neighbor_pattern.get_bit_peering_terrain(bit) != primary_peering_terrain:
					return false
			continue

		if neighbor_terrain == tile_terrain:
			continue

		# used in case of custom primary peering terrains
		if terrains_data.get_primary_peering_terrain(neighbor_terrain) == primary_peering_terrain:
			continue
		return false

	return true
