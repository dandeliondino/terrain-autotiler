@tool
extends "res://addons/terrain_autotiler/core/terrain_pattern.gd"

# redefine to avoid lookups
const NULL_TERRAIN := Autotiler.NULL_TERRAIN
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN

const INVALID_BIT := -1
const INVALID_SCORE := -1

const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")

var _bit_scores := {}

# stores the corresponding bit
var _bit_neighbor_bits := {} # [bit][neighbor_coords] = neighbor_bit

# stores neighbor terrains indexed by coords
var _neighbor_terrains := {} # {neighbor_coords : tile_terrain}

# stores neighbor patterns indexed by coords
var _neighbor_patterns := {} # {neighbor_coords : pattern}

var _ignore_terrain := NULL_TERRAIN


var coords : Vector2i

# this is set when a pattern is selected and search pattern is no longer needed
var pattern : TerrainPattern

var terrains_data : TerrainsData
var can_match_to_empty := true

var primary_peering_terrain := NULL_TERRAIN


func _init(p_terrains_data : TerrainsData, p_tile_terrain : int, p_allow_match_to_empty := true) -> void:
	terrains_data = p_terrains_data
	_peering_bits = terrains_data.cn.get_peering_bits()
	_ignore_terrain = terrains_data.ignore_terrain

	tile_terrain = p_tile_terrain
	primary_peering_terrain = terrains_data.get_primary_peering_terrain(tile_terrain)

	if p_allow_match_to_empty:
		can_match_to_empty = terrains_data.can_match_to_empty(tile_terrain)
	else:
		can_match_to_empty = false

	for bit in _peering_bits:
		_bit_neighbor_bits[bit] = {}


# used to for lookups involving @ignore bits
func create_from_pattern(p_pattern : TerrainPattern) -> SearchPattern:
	tile_terrain = p_pattern.tile_terrain
	_bit_peering_terrains = p_pattern._bit_peering_terrains.duplicate()
	for bit in get_peering_bits():
		set_bit_peering_terrain(bit, p_pattern.get_bit_peering_terrain(bit))
	return self


func has_empty_neighbor() -> bool:
	for neighbor_coords in _neighbor_terrains:
		if _neighbor_terrains[neighbor_coords] == EMPTY_TERRAIN:
			return true
	return false


# adds neighbor_coords and the relevant bits
func add_neighbor(p_bit : TileSet.CellNeighbor, p_neighbor_coords : Vector2i, p_neighbor_bit : TileSet.CellNeighbor, p_neighbor_tile_terrain : int) -> void:
	_bit_neighbor_bits[p_bit][p_neighbor_coords] = p_neighbor_bit
	_neighbor_terrains[p_neighbor_coords] = p_neighbor_tile_terrain


# adds pattern to dict and sets all relevant bits
# the neighbor must be previously added via add_neighbor
func add_neighbor_pattern(p_neighbor_coords : Vector2i, p_pattern : TerrainPattern) -> bool:
	var conflicting_bit_terrains := false

	_neighbor_patterns[p_neighbor_coords] = p_pattern
	for bit in _peering_bits:
		var neighbor_bit : int = _bit_neighbor_bits[bit].get(p_neighbor_coords, INVALID_BIT)
		if neighbor_bit == INVALID_BIT:
			continue

		var current_peering_terrain := get_bit_peering_terrain(bit)
		var neighbor_peering_terrain = p_pattern.get_bit_peering_terrain(neighbor_bit)

		if current_peering_terrain == neighbor_peering_terrain:
			# no change needed
			continue

		if neighbor_peering_terrain == EMPTY_TERRAIN:
			if can_match_to_empty:
				# set to empty regardless of current_peering_terrain
				# (as other neighbors may be unable to match to empty and have set their own bits)
				set_bit_peering_terrain(bit, EMPTY_TERRAIN)
			#else:
				# will use either another neighbor's peering bit or priorities
			continue

		if neighbor_peering_terrain == _ignore_terrain:
			if current_peering_terrain == NULL_TERRAIN:
				set_bit_peering_terrain(bit, _ignore_terrain)
			# else leave it current peering terrain constraint
			continue

		if current_peering_terrain == NULL_TERRAIN or current_peering_terrain == _ignore_terrain:
			set_bit_peering_terrain(bit, neighbor_peering_terrain)
			continue

		if current_peering_terrain == EMPTY_TERRAIN:
			# this is opposite of above; the previously set neighbor was empty and set its bit
			# because this terrain can match to it
			# regardless of what the new pattern tries to set the bit to, keep empty terrain here
			continue

		# if we get here, then the two different terrains do not fall into exceptions above
		# and this is an error state
		# just keep the previously set terrain and flag it as an error
		# TODO: keeping data for mutiple terrains improve results when finding non-matching tiles,
		# maybe flag them as conflicting and calculate priorities for them only if needed?
		conflicting_bit_terrains = true
	return conflicting_bit_terrains


# use when resetting update
# keeps neighbor terrain data
func reset_patterns() -> void:
	_bit_peering_terrains.clear()
	_neighbor_patterns.clear()
	pattern = null


# gets unique peering terrains from own primary peering terrain, the assigned bits
# and, if neighbor has no pattern assigned,
# then from the top result for the match score to the neighbor
# used to assess complexity of match
func get_unique_peering_terrains() -> PackedInt32Array:
	var unique_terrains_set := {
		primary_peering_terrain : true,
	}

	for bit in _peering_bits:
		var peering_terrain := get_bit_peering_terrain(bit)
		if peering_terrain == NULL_TERRAIN:
			var bit_scores := get_bit_scores(bit)
			var bit_score_terrains := bit_scores.keys()
			if bit_score_terrains.size() == 0:
				continue
			peering_terrain = bit_score_terrains[0] # top transition peering terrain
		if peering_terrain == _ignore_terrain:
			continue
		if not can_match_to_empty && peering_terrain == EMPTY_TERRAIN:
			continue
		unique_terrains_set[peering_terrain] = true

	return PackedInt32Array(unique_terrains_set.keys())


# returns pre-sorted bit scores dict for supplied bit
# if they have not yet been calculated, it calculates them, saves the result, then returns them
# they only need to be calculated once, but not all bits need to have them calculated
func get_bit_scores(p_bit : TileSet.CellNeighbor) -> Dictionary:
	var bit_scores : Dictionary = _bit_scores.get(p_bit, {})
	if not bit_scores.is_empty():
		return bit_scores

	var tile_terrains_set := {tile_terrain : true}
	for neighbor_coords in _bit_neighbor_bits[p_bit]:
		var tile_terrain : int = _neighbor_terrains[neighbor_coords]
		if tile_terrain == EMPTY_TERRAIN && not can_match_to_empty:
			continue
		tile_terrains_set[tile_terrain] = true

	bit_scores = terrains_data.get_transition_dict(tile_terrains_set.keys())

	_bit_scores[p_bit] = bit_scores


	return bit_scores


func get_bit_peering_terrain_score(p_bit : TileSet.CellNeighbor, p_peering_terrain : int) -> int:
	return get_bit_scores(p_bit).get(p_peering_terrain, INVALID_SCORE)


# if there is a peering terrain in _bit_peering_terrains, it returns only that
# if not, it looks for scored peering terrains
func get_all_bit_peering_terrains(p_bit : TileSet.CellNeighbor) -> PackedInt32Array:
	var peering_terrain := get_bit_peering_terrain(p_bit)
	if peering_terrain != NULL_TERRAIN:
		return PackedInt32Array([peering_terrain])
	return PackedInt32Array(get_bit_scores(p_bit).keys())


func get_match_score(p_pattern : TerrainPattern, p_allow_non_matching : bool) -> int:
	var score := 0

	for bit in get_peering_bits():
		# if the pattern's bit is set to ignore, it will always be a valid match
		# so assign it the ignore score and move on
		var pattern_peering_terrain := p_pattern.get_bit_peering_terrain(bit)

		var peering_terrain := get_bit_peering_terrain(bit)

		if peering_terrain != Autotiler.NULL_TERRAIN:
			if p_allow_non_matching:
				if peering_terrain == pattern_peering_terrain:
					score += TerrainsData.ScoreValues[TerrainsData.Score.MATCHING_BIT]
				elif peering_terrain == _ignore_terrain:
					score += TerrainsData.ScoreValues[TerrainsData.Score.IGNORE]
				else:
					score += TerrainsData.ScoreValues[TerrainsData.Score.NON_MATCHING_BIT]
				continue
			else:
				if peering_terrain == pattern_peering_terrain:
					score += TerrainsData.ScoreValues[TerrainsData.Score.MATCHING_BIT]
				elif peering_terrain == _ignore_terrain or pattern_peering_terrain == _ignore_terrain:
					score += TerrainsData.ScoreValues[TerrainsData.Score.IGNORE]
				else:
					printerr("this shouldn't happen")
					pass
			continue


		var bit_score : int = get_bit_peering_terrain_score(bit, pattern_peering_terrain)
		if bit_score == INVALID_SCORE:
			# if there is no peering terrain set and no score set, cannot determine match
			# (this should not happen)
			return INVALID_SCORE

		# non-matching scores are negative, so if non-matching is not allowed
		# return invalid here
		if bit_score < 0 and not p_allow_non_matching:
			return INVALID_SCORE

		score += bit_score

	return score



func get_top_pattern() -> TerrainPattern:
	if terrains_data.has_ignore_terrain(tile_terrain):
		return null

	var pattern := TerrainPattern.new(get_peering_bits())
	pattern.tile_terrain = tile_terrain
	for bit in get_peering_bits():
		var peering_terrain := get_bit_peering_terrain(bit)
		if peering_terrain != NULL_TERRAIN:
			pattern.set_bit_peering_terrain(bit, peering_terrain)
			continue

		var bit_scores := get_bit_scores(bit)
		if bit_scores.is_empty():
			# if there is no assigned peering terrain or score,
			# cannot create a valid pattern
			return null

		# because bit_scores are pre-sorted in descending order,
		# the first item will be the peering terrain with the highest score
		pattern.set_bit_peering_terrain(bit, bit_scores.keys().front())

	return pattern
