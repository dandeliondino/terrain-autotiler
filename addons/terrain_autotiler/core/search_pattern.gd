@tool
extends "res://addons/terrain_autotiler/core/terrain_pattern.gd"

# redefine to avoid lookups
const NULL_TERRAIN := Autotiler.NULL_TERRAIN
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN
const MULTIPLE_TERRAINS := 999

const INVALID_BIT := -1
const INVALID_SCORE := -1000000000

const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")

var _alt_terrain_peering_terrains : Dictionary
var _tile_terrain_alt_terrains : PackedInt32Array

var _bit_multiple_terrains := {} # [bit] = PackedInt32Array()

var _bit_scores := {}

# stores the corresponding bit
var _bit_neighbor_bits := {} # [bit][neighbor_coords] = neighbor_bit

# stores neighbor terrains indexed by coords
var _neighbor_terrains := {} # {neighbor_coords : tile_terrain}

# stores neighbor patterns indexed by coords
var _neighbor_patterns := {} # {neighbor_coords : pattern}



var coords : Vector2i

# this is set when a pattern is selected and search pattern is no longer needed
var pattern : TerrainPattern

var terrains_data : TerrainsData
var can_match_to_empty := true

var primary_peering_terrain := NULL_TERRAIN


func _init(p_terrains_data : TerrainsData, p_tile_terrain : int, p_allow_match_to_empty := true) -> void:
	terrains_data = p_terrains_data
	_peering_bits = terrains_data.cn.get_peering_bits()

	tile_terrain = p_tile_terrain
	primary_peering_terrain = terrains_data.get_primary_peering_terrain(tile_terrain)

	# keep local references to avoid lookups
	_alt_terrain_peering_terrains = terrains_data.alt_terrain_peering_terrains
	_tile_terrain_alt_terrains = terrains_data.tile_terrain_alt_terrains.get(tile_terrain, PackedInt32Array())

	if p_allow_match_to_empty:
		can_match_to_empty = terrains_data.can_match_to_empty(tile_terrain)
	else:
		can_match_to_empty = false

	for bit in _peering_bits:
		_bit_neighbor_bits[bit] = {}


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
				# don't make any changes
				# will use either another neighbor's peering bit or priorities
			continue

		if current_peering_terrain == NULL_TERRAIN:
			set_bit_peering_terrain(bit, neighbor_peering_terrain)
			continue

		# multiple terrains assigned to bit (prior neighbor pattern had alt terrain)
		if current_peering_terrain == MULTIPLE_TERRAINS:
			var current_possible_terrains : PackedInt32Array = _bit_multiple_terrains[bit]
			if _alt_terrain_peering_terrains.has(neighbor_peering_terrain):
				var combined_possible_terrains := PackedInt32Array()
				var neighbor_possible_terrains : PackedInt32Array = _alt_terrain_peering_terrains[neighbor_peering_terrain]
				for peering_terrain in current_possible_terrains:
					if neighbor_possible_terrains.has(peering_terrain):
						combined_possible_terrains.append(peering_terrain)
				_bit_multiple_terrains[bit] = combined_possible_terrains
			else:
				if not current_possible_terrains.has(neighbor_peering_terrain):
					# flag as a problem, and assign the new peering terrain
					conflicting_bit_terrains = true
				set_bit_peering_terrain(bit, neighbor_peering_terrain)

		# if current pattern's bit is alt terrain
		if _alt_terrain_peering_terrains.has(neighbor_peering_terrain):
			# PackedInt32Arrays are passed by value, so can assign without duplicating
			if current_peering_terrain == NULL_TERRAIN:
				_bit_multiple_terrains[bit] = _alt_terrain_peering_terrains[neighbor_peering_terrain]
				_bit_peering_terrains[bit] = MULTIPLE_TERRAINS
			elif not _alt_terrain_peering_terrains[neighbor_peering_terrain].has(current_peering_terrain):
				# leave it as the current_peering_terrain but flag as problem
				conflicting_bit_terrains = true
			# else leave it current peering terrain constraint
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
		if peering_terrain == MULTIPLE_TERRAINS:
			# TODO: worked with ignore terrain, but will this cause problems
			# with alt terrains?
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
	if peering_terrain == MULTIPLE_TERRAINS:
		return _bit_multiple_terrains[p_bit]
	if peering_terrain != NULL_TERRAIN:
		return PackedInt32Array([peering_terrain])
	return PackedInt32Array(get_bit_scores(p_bit).keys())


func get_match_score(p_pattern : TerrainPattern, p_allow_non_matching : bool) -> int:
	var score := 0

	var has_multiple_terrains : bool = _bit_peering_terrains.values().has(MULTIPLE_TERRAINS)

	# if the bits are matching and we don't need to calculate alt terrains
	# skip detailed scoring to save time
	var need_complex_score := true
	if not p_allow_non_matching:
		if _tile_terrain_alt_terrains.is_empty():
			if not has_multiple_terrains:
				need_complex_score = false


	for bit in _peering_bits:
		# NOTE: if this function is slow,
		# consider moving some pre-calculations to only where they're needed
		var search_peering_terrain := get_bit_peering_terrain(bit)
		var pattern_peering_terrain := p_pattern.get_bit_peering_terrain(bit)

		var pattern_terrain_is_alt : bool = _alt_terrain_peering_terrains.has(pattern_peering_terrain)
		var pattern_possible_terrains := PackedInt32Array()
		var pattern_alt_adjustment := INVALID_SCORE
		if pattern_terrain_is_alt:
			pattern_possible_terrains = _alt_terrain_peering_terrains[pattern_peering_terrain]
			pattern_alt_adjustment = terrains_data.get_score_alternative_adjustment(pattern_peering_terrain)

		var primary_peering_terrains : PackedInt32Array = _get_primary_peering_terrains_at_bit(bit)
		var pattern_is_primary := primary_peering_terrains.has(pattern_peering_terrain)

		# for alt terrains, matching score is based off of the highest score terrain it matches
		# but non-matching score is computed based off its peering terrain score
		# so is the same as non-alt terrains
		var non_matching_score := terrains_data.get_score_peering_terrain(pattern_peering_terrain, pattern_is_primary, true)
		var matching_score := INVALID_SCORE
		if not pattern_terrain_is_alt:
			matching_score = terrains_data.get_score_peering_terrain(pattern_peering_terrain, pattern_is_primary, false)
			# TEST
			var bit_peering_terrain_score := get_bit_peering_terrain_score(bit, pattern_peering_terrain)
			if bit_peering_terrain_score != INVALID_SCORE:
				if not can_match_to_empty && pattern_peering_terrain == EMPTY_TERRAIN:
					# in this case, we are simulating a non-match to empty
					# so the bit peering terrain score will not be accurate
					pass
				else:
					assert(bit_peering_terrain_score == matching_score)

		var bit_score := INVALID_SCORE

		# CASE: no bit set in search pattern
		# (no neighbors on that bit)
		if search_peering_terrain == NULL_TERRAIN:
			if not pattern_terrain_is_alt:
				bit_score = get_bit_peering_terrain_score(bit, pattern_peering_terrain)
			else:
				# give alt terrain the highest matching score, minus alt offset
				var sorted_bit_scores := get_bit_scores(bit)
				for peering_terrain in sorted_bit_scores:
					if pattern_possible_terrains.has(peering_terrain):
						var terrain_score : int = sorted_bit_scores[peering_terrain]
						bit_score = terrain_score - pattern_alt_adjustment
						break

			if bit_score == INVALID_SCORE:
				assert(p_allow_non_matching)
				if not p_allow_non_matching:
					# something went wrong
					return INVALID_SCORE
				bit_score = non_matching_score

			score += bit_score
			continue


		# CASE: don't need complex score
		# (all patterns will be skipped at this bit, so scores will still be comparable)
		if not need_complex_score:
			continue


		# CASE: bit terrains match
		if search_peering_terrain == pattern_peering_terrain:
			# if pattern's bit matches the neighbor's bit,
			# assign the score and continue
			# (alt terrains are not stored as bit peering terrains in SearchPattern
			# so this guarantees that neither is an alt terrain)
			bit_score = matching_score
			score += bit_score
			continue

		# CASE: bit terrains don't match and there are no special cases
		if search_peering_terrain != MULTIPLE_TERRAINS && not pattern_terrain_is_alt:
			bit_score = non_matching_score
			score += bit_score
			continue

		# CASE: search has multiple terrains
		# (neighbor bits had alt terrains)
		if search_peering_terrain == MULTIPLE_TERRAINS:
			var search_possible_terrains : PackedInt32Array = _bit_multiple_terrains[bit]

			# CASE: search has multiple terrains AND pattern peering terrain is NOT alt terrain
			if not pattern_terrain_is_alt:
				if search_possible_terrains.has(pattern_peering_terrain):
					bit_score = matching_score
				else:
					bit_score = non_matching_score
				score += bit_score
				continue

			# CASE: search has multiple terrains AND pattern peering terrain IS alt terrain
			var combined_possible_terrains := PackedInt32Array()
			for peering_terrain in search_possible_terrains:
				if pattern_possible_terrains.has(peering_terrain):
					combined_possible_terrains.append(peering_terrain)

			# if no combined terrains, assign non-matching score
			if combined_possible_terrains.is_empty():
				bit_score = non_matching_score
				score += bit_score
				continue

			# get the first (highest scoring) terrain that is in both lists
			var sorted_bit_scores := get_bit_scores(bit)
			for peering_terrain in sorted_bit_scores:
				if combined_possible_terrains.has(peering_terrain):
					bit_score = sorted_bit_scores[peering_terrain]
					break

			# if no score was listed (non-matching)
			if bit_score == INVALID_SCORE:
				assert(p_allow_non_matching)
				if not p_allow_non_matching:
					return INVALID_SCORE

				var max_score := -10000000
				for peering_terrain in combined_possible_terrains:
					var terrain_is_primary := primary_peering_terrains.has(peering_terrain)
					var terrain_score := terrains_data.get_score_peering_terrain(peering_terrain, terrain_is_primary)
					if terrain_score > max_score:
						max_score = terrain_score
				bit_score = max_score

			score += bit_score - pattern_alt_adjustment
			continue


		# If we are here, pattern terrain is alt and search has single terrain

		# CASE: pattern's alt terrain HAS search pattern's terrain
		if pattern_possible_terrains.has(search_peering_terrain):
			var terrain_score := get_bit_peering_terrain_score(bit, search_peering_terrain)
			if terrain_score == INVALID_SCORE:
				assert(p_allow_non_matching)
				if not p_allow_non_matching:
					return INVALID_SCORE
				var terrain_is_primary := primary_peering_terrains.has(search_peering_terrain)
				terrain_score = terrains_data.get_score_peering_terrain(search_peering_terrain, terrain_is_primary)
			bit_score = terrain_score - pattern_alt_adjustment

		# CASE: pattern's alt terrain does NOT have search pattern's terrain
		else:
			bit_score = non_matching_score

		score += bit_score


	return score


func _get_primary_peering_terrains_at_bit(p_bit : TileSet.CellNeighbor) -> PackedInt32Array:
	var primary_terrains_set := {terrains_data.get_primary_peering_terrain(tile_terrain): true}
	for neighbor_coords in _bit_neighbor_bits[p_bit]:
		var neighbor_tile_terrain : int = _neighbor_terrains[neighbor_coords]
		var neighbor_primary_peering_terrain := terrains_data.get_primary_peering_terrain(neighbor_tile_terrain)
		primary_terrains_set[neighbor_primary_peering_terrain] = true
	return PackedInt32Array(primary_terrains_set.keys())



func get_top_pattern() -> TerrainPattern:
	var pattern := TerrainPattern.new(get_peering_bits())
	pattern.tile_terrain = tile_terrain
	for bit in get_peering_bits():
		var peering_terrain := get_bit_peering_terrain(bit)
		if peering_terrain == MULTIPLE_TERRAINS:
			# match involves alt terrains, so don't allow top pattern
			return null

		if peering_terrain != NULL_TERRAIN:
			pattern.set_bit_peering_terrain(bit, peering_terrain)
			continue

		var bit_scores := get_bit_scores(bit)
		if bit_scores.is_empty():
			# if there is no assigned peering terrain or score,
			# cannot create a valid pattern
			return null

		var bit_terrain : int = bit_scores.keys().front()

		# because bit_scores are pre-sorted in descending order,
		# the first item will be the peering terrain with the highest score
		pattern.set_bit_peering_terrain(bit, bit_terrain)


	return pattern
