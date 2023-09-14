extends RefCounted

# redefine to avoid lookups
const NULL_TERRAIN := Autotiler.NULL_TERRAIN
const EMPTY_TERRAIN := Autotiler.EMPTY_TERRAIN


const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")
const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")
const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")
const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")


var tile_set : TileSet
var terrain_set : int
var terrain_mode : TileSet.TerrainMode
var cn : CellNeighbors

var empty_pattern : TerrainPattern

var _ordered_peering_bits : PackedInt32Array

var all_terrains := []
var tile_terrains := []
var sorted_tile_terrains := []
var peering_terrains := PackedInt32Array()

var terrain_display_patterns : Dictionary

# {tile_terrain : {peering_terrain: pattern count, ...}}
var _tile_peering_terrains_counts := {}

# ordered by the TileSet's peering terrains indexes
# with empty added at the end
var _peering_terrain_priorities := []

# {tile_terrain : peering_terrain}
var _primary_peering_terrains := {}

# {tile_terrain : terrain pattern}
var _primary_patterns := {}


var _pattern_lookup := {}

# {ID : terrain pattern}
var _patterns_by_id := {}

# {tile_terrain : [terrain_pattern, ...]}
var _patterns_by_terrain := {}

var _transition_peering_terrains := {}

# tile terrains who have full sets of patterns (per mode)
# for all their peering terrains
var full_set_tile_terrains_set := {}

var terrain_names := {}

var single_pattern_terrains := {} # {tile_terrain : pattern}

var alt_terrain_peering_terrains := {} # {alt_terrain int : [peering_terrain, peering_terrain, ...] PackedInt32Array}
var tile_terrain_alt_terrains := {} # {tile_terrain int : [alt_terrain, alt_terrain ...] PackedInt32Array}
#var profiler := Profiler.new()

# ----------------------------------------------------
#	SCORES
# ----------------------------------------------------

# SCORING
# Transition scores (PRIMARY, HIGH, LOW) are assigned in 100's
# so that the peering terrain priority index can be subtracted
# without risk of overlapping.

# PRIMARY_LOW is a compromise... they are not good choices since
# they have very few patterns. But if users have gone to the trouble
# of defining these patterns, they probably want them used and it is required
# for solving the bridge problem here:
# https://github.com/godotengine/godot-proposals/issues/5575#issuecomment-1278885451

# This score allows them to show up over an unwanted third terrain (even
# if the third terrain has higher likelihood of successful matching), but if
# the other primary terrain has a better chance of matching,
# it will still be prioritized.

# Having odd tiles like these in a TileSet will slow down processing since
# they will trigger more failures and therefore more
# best patterns (vs top patterns) and more backtracking.
# But users who don't have any odd tiles like this will be unaffected.

# The BIT scores only come into play when we already know that no matching tile
# exists for the cell. Before that time, the search results are limited
# only to bits that match.
# NON_MATCHING scores are large negative numbers. Every non-matching bit
# has a large incremental cost to ensure always choosing the pattern
# with the most matching bits.

enum Score {
	PRIMARY,
	SECONDARY,
	MATCHING_BIT,
	NON_MATCHING_BIT,
}

# peering terrains: subtract index * 10
# alternative terrains: get terrain from list, subtract index * 1
# matching bit: get terrain from list, score of original terrain

const ScoreValues := {
	Score.PRIMARY : 10000,
	Score.SECONDARY : 1000,
	Score.NON_MATCHING_BIT : -10000,
}

const PEERING_TERRAIN_PRIORITY_MULTIPLIER := 10
const ALTERNATIVE_TERRAIN_PRIORITY_MULTIPLIER := 1

static func get_score(p_score : Score) -> int:
	return ScoreValues[p_score]




# -----------------------------------------------
# 	INITIALIZATION FUNCTIONS
# -----------------------------------------------

func _init(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	terrain_mode = tile_set.get_terrain_set_mode(terrain_set)
	cn = CellNeighbors.new(
		tile_set.tile_shape,
		terrain_mode,
		Metadata.get_match_mode(tile_set, terrain_set),
		tile_set.tile_offset_axis,
	)
	_ordered_peering_bits = PackedInt32Array(cn.get_peering_bits())

	_setup_empty_terrain_data()

	# profiler.start_timer("_load_terrains()")
	_load_terrains()
	# profiler.stop_timer("_load_terrains()")
	# profiler.start_timer("_load_patterns()")
	_load_patterns()
	# profiler.stop_timer("_load_patterns()")
	# profiler.start_timer("_sort_tile_terrains()")
	_sort_tile_terrains()
	# profiler.stop_timer("_sort_tile_terrains()")
	# profiler.start_timer("_load_transitions()")
	_load_transitions()
	# profiler.stop_timer("_load_transitions()")
	# profiler.print_timers()


# -----------------------------------------------
# 	INITIALIZATION: LOAD TERRAINS
# -----------------------------------------------

func _setup_empty_terrain_data() -> void:
	empty_pattern = TerrainPattern.new(cn.get_peering_bits()).create_empty_pattern()
	_tile_peering_terrains_counts[EMPTY_TERRAIN] = {EMPTY_TERRAIN:1}
	_primary_peering_terrains[EMPTY_TERRAIN] = EMPTY_TERRAIN
	terrain_names[EMPTY_TERRAIN] = "EMPTY"
	terrain_names[NULL_TERRAIN] = "NULL"



func _load_terrains() -> void:
	for terrain in tile_set.get_terrains_count(terrain_set):
		all_terrains.append(terrain)

		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain)
		terrain_names[terrain] = terrain_name

		if terrain_name.begins_with("@"):
			alt_terrain_peering_terrains[terrain] = Metadata.get_alternative_match_terrains(tile_set, terrain_set, terrain)
			continue

		_primary_peering_terrains[terrain] = Metadata.get_primary_peering_terrain(tile_set, terrain_set, terrain)

	_peering_terrain_priorities = Metadata.get_priorities_list(tile_set, terrain_set)




# -----------------------------------------------
# 	INITIALIZATION: LOAD PATTERNS
# -----------------------------------------------

func _load_patterns() -> void:
	for source_idx in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(source_idx)
		if not tile_set.get_source(source_id) is TileSetAtlasSource:
			continue
		var source : TileSetAtlasSource = tile_set.get_source(source_id)
		for tile_index in range(source.get_tiles_count()):
			var atlas_coords := source.get_tile_id(tile_index)
			for alternative_tile_index in source.get_alternative_tiles_count(atlas_coords):
				var alternative_tile_id := source.get_alternative_tile_id(atlas_coords, alternative_tile_index)
				var tile_data := source.get_tile_data(atlas_coords, alternative_tile_id)
				if tile_data.terrain_set != terrain_set:
					continue

				var pattern := TerrainPattern.new(cn.get_peering_bits()).create_from_tile_data(tile_data)
				if alt_terrain_peering_terrains.has(pattern.tile_terrain):
					printerr(
						"Terrain Autotiler: Error loading tile." \
						+ " Alternative terrain used as tile terrain (center bit)." \
						+ " (source id=%s, atlas coords=%s)" % [source_id, atlas_coords])
					continue
				var id := _add_pattern(pattern)

				var tile_location := TileLocation.new(
						source_id,
						atlas_coords,
						alternative_tile_id,
						tile_data.probability
					)
				_patterns_by_id[id].add_tile(tile_location)

	_create_pattern_lookup()
	for pattern in _patterns_by_id.values():
		_add_pattern_to_lookup(pattern)

	for tile_terrain in _patterns_by_terrain:
		var patterns : Array = _patterns_by_terrain[tile_terrain]
		var pattern_count : int = patterns.size()
		if pattern_count == 1:
			single_pattern_terrains[tile_terrain] = patterns[0]

	_populate_primary_patterns()
	_populate_full_set_tile_terrains()
	_populate_terrain_display_patterns()


func _populate_primary_patterns() -> void:
	for tile_terrain in tile_terrains:
		var primary_peering_terrain := get_primary_peering_terrain(tile_terrain)
		var pattern := TerrainPattern.new(cn.get_peering_bits())
		pattern.tile_terrain = tile_terrain

		for bit in cn.get_peering_bits():
			pattern.set_bit_peering_terrain(bit, primary_peering_terrain)

#		print("finding primary pattern for %s..." % [terrain_names[tile_terrain]])
#		print("\tprimary peering terrain=%s" % [terrain_names[primary_peering_terrain]])

		var primary_pattern := get_pattern(pattern)
		if primary_pattern:
			_primary_patterns[tile_terrain] = primary_pattern


func _populate_full_set_tile_terrains() -> void:
	var full_set_count := cn.get_full_set_pattern_count()
	for tile_terrain in _tile_peering_terrains_counts:
		var full_set := true
		for peering_terrain in _tile_peering_terrains_counts[tile_terrain]:
			var count = _tile_peering_terrains_counts[tile_terrain][peering_terrain]
			if count < full_set_count:
				full_set = false
		if full_set:
			full_set_tile_terrains_set[tile_terrain] = true


func _populate_terrain_display_patterns() -> void:
	for tile_terrain in tile_terrains:
		var pattern := get_primary_pattern(tile_terrain)
		if pattern:
			terrain_display_patterns[tile_terrain] = pattern
			continue
		var max_score_pattern : TerrainPattern
		var max_score := -1
		var primary_peering_terrain := get_primary_peering_terrain(tile_terrain)
		for p in _patterns_by_terrain[tile_terrain]:
			var score := 0
			for bit in p.get_peering_bits():
				var peering_terrain : int = p.get_bit_peering_terrain(bit)
				if peering_terrain == primary_peering_terrain:
					score += 1
			if score > max_score:
				max_score = score
				max_score_pattern = p
		if max_score_pattern:
			terrain_display_patterns[tile_terrain] = max_score_pattern

# ------------------------------

func _add_pattern(pattern : TerrainPattern) -> StringName:
	var id : StringName = pattern.get_id()
	if _patterns_by_id.has(id):
		return id

	var tile_terrain := pattern.tile_terrain

	_patterns_by_id[id] = pattern
	if not all_terrains.has(tile_terrain): # in case of empty?
		return id

	if not tile_terrains.has(tile_terrain):
		tile_terrains.append(tile_terrain)
		_tile_peering_terrains_counts[tile_terrain] = {}
		_patterns_by_terrain[tile_terrain] = []

	_patterns_by_terrain[tile_terrain].append(pattern)

	for peering_terrain in pattern.get_peering_terrains():
		if not _tile_peering_terrains_counts[tile_terrain].has(peering_terrain):
			_tile_peering_terrains_counts[tile_terrain][peering_terrain] = 1
		else:
			_tile_peering_terrains_counts[tile_terrain][peering_terrain] += 1

		if alt_terrain_peering_terrains.has(peering_terrain):
			# if it is an alternative terrain
			if not tile_terrain_alt_terrains.has(tile_terrain):
				tile_terrain_alt_terrains[tile_terrain] = PackedInt32Array([peering_terrain])
			else:
				if not tile_terrain_alt_terrains[tile_terrain].has(peering_terrain):
					tile_terrain_alt_terrains[tile_terrain].append(peering_terrain)

		if not peering_terrains.has(peering_terrain):
			peering_terrains.append(peering_terrain)

	return id


# creates sorted_tile_terrains in descending order of # of patterns
func _sort_tile_terrains() -> void:
	sorted_tile_terrains = tile_terrains.duplicate()
	sorted_tile_terrains.sort_custom(
		func(a,b):
			var a_alt_terrain_count := _get_alt_terrain_count(a)
			var b_alt_terrain_count := _get_alt_terrain_count(b)
			if a_alt_terrain_count == b_alt_terrain_count:
				var a_primary_peering_terrain := get_primary_peering_terrain(a)
				var b_primary_peering_terrain := get_primary_peering_terrain(b)
				var a_to_b_count := _get_peering_terrain_pattern_count(a, b_primary_peering_terrain)
				var b_to_a_count := _get_peering_terrain_pattern_count(b, a_primary_peering_terrain)
				return a_to_b_count > b_to_a_count
			return a_alt_terrain_count > b_alt_terrain_count
	)


func _get_alt_terrain_count(p_tile_terrain : int) -> int:
	var count := 0
	for alt_terrain in tile_terrain_alt_terrains.get(p_tile_terrain, PackedInt32Array()):
		count += _get_peering_terrain_pattern_count(p_tile_terrain, alt_terrain)
	return count


# PATTERN DICT COMPREHENSION
func _create_pattern_lookup() -> void:
	_pattern_lookup = {}
	var bit_count := _ordered_peering_bits.size()
	var last_bit_index := bit_count - 1
	for tile_terrain in tile_terrains:
		_pattern_lookup[tile_terrain] = {}
		var peering_terrains_list : Array = _tile_peering_terrains_counts[tile_terrain].keys()
		_add_placeholder_bits_to_lookup(_pattern_lookup[tile_terrain], peering_terrains_list, last_bit_index)


func _add_placeholder_bits_to_lookup(dict : Dictionary, p_peering_terrains : Array, last_bit_index : int, current_bit_index := 0) -> void:
	for peering_terrain in p_peering_terrains:
		if current_bit_index < last_bit_index:
			dict[peering_terrain] = {}
			var next_bit_index := current_bit_index + 1
			_add_placeholder_bits_to_lookup(dict[peering_terrain], p_peering_terrains, last_bit_index, next_bit_index)
		else:
			dict[peering_terrain] = null


func _add_pattern_to_lookup(p_pattern : TerrainPattern) -> void:
	if p_pattern.tile_terrain == EMPTY_TERRAIN:
		return

	var dict : Dictionary = _pattern_lookup.get(p_pattern.tile_terrain, {})

	if dict.is_empty():
		push_error("_add_pattern_to_lookup(): Tile terrain not found (%s)" % p_pattern.tile_terrain)
		return
	var peering_bits := _ordered_peering_bits
	var bit_count := _ordered_peering_bits.size()
	var last_bit_index := bit_count - 1

	for i in bit_count:
		var bit : TileSet.CellNeighbor = peering_bits[i]
		var peering_terrain := p_pattern.get_bit_peering_terrain(bit)
		if i == last_bit_index:
			dict[peering_terrain] = p_pattern
			return
		dict = dict[peering_terrain]




# -----------------------------------------------
# 	INITIALIZATION: LOAD TRANSITIONS
# -----------------------------------------------

# pre-generate transition scores to avoid redundant calculations at runtime
# maximum 4 terrains to consider at each peering bit
func _load_transitions() -> void:
	var from_terrains := tile_terrains
	var to_terrains := tile_terrains + [EMPTY_TERRAIN]

	for a in from_terrains:
		_create_transition_scores_list([a])
		for b in to_terrains:
			if b == a:
				continue
			_create_transition_scores_list([a,b])
			for c in to_terrains:
				if c == a or c == b:
					continue
				_create_transition_scores_list([a,b,c])
				for d in to_terrains:
					if d == c or d == b or d == a:
						continue
					_create_transition_scores_list([a,b,c,d])



func _create_transition_scores_list(p_tile_terrains : Array) -> void:
	# profiler.start_timer("_get_transition_key()")
	var transition_key := _get_transition_key(p_tile_terrains)
	if _transition_peering_terrains.has(transition_key):
		# profiler.stop_timer("_get_transition_key()")
		return
	# profiler.stop_timer("_get_transition_key()")
	# profiler.start_timer("_create_transition_scores_list()")
	var peering_terrain_scores := {}
	var peering_terrains_with_empty := peering_terrains
	if not peering_terrains_with_empty.has(EMPTY_TERRAIN):
		peering_terrains_with_empty.append(EMPTY_TERRAIN)

	for peering_terrain in peering_terrains_with_empty:
		var missing := false
		var primary := false

		if alt_terrain_peering_terrains.has(peering_terrain):
			# add alts later
			continue

		for tile_terrain in p_tile_terrains:
			if not has_peering_terrain(tile_terrain, peering_terrain):
				# has_peering_terrain() includes alt terrains' peering terrains
				missing = true
				break
			elif get_primary_peering_terrain(tile_terrain) == peering_terrain:
				primary = true

		if missing:
			continue

		peering_terrain_scores[peering_terrain] = get_score_peering_terrain(peering_terrain, primary)


	var sorted_peering_terrains := peering_terrain_scores.keys()
	sorted_peering_terrains.sort_custom(
		func(a,b):
			return peering_terrain_scores[a] > peering_terrain_scores[b]
	)

	for tile_terrain in p_tile_terrains:
		var alt_terrains : PackedInt32Array = tile_terrain_alt_terrains.get(tile_terrain, PackedInt32Array())
		for alt_terrain in alt_terrains:
			var alt_peering_terrains : PackedInt32Array = alt_terrain_peering_terrains[alt_terrain]
			for peering_terrain in sorted_peering_terrains:
				if alt_peering_terrains.has(peering_terrain):
					var alt_adjustment := get_score_alternative_adjustment(alt_terrain)
					peering_terrain_scores[alt_terrain] = peering_terrain_scores[peering_terrain] - alt_adjustment
					var peering_terrain_idx := sorted_peering_terrains.find(peering_terrain)
					# insert after peering terrain to maintain sorting
					sorted_peering_terrains.insert(peering_terrain_idx + 1, alt_terrain)
					# break here because array was sorted
					# so we already got the highest score possible
					break

	var sorted_dict := {}
	for peering_terrain in sorted_peering_terrains:
		sorted_dict[peering_terrain] = peering_terrain_scores[peering_terrain]

	_transition_peering_terrains[transition_key] = sorted_dict

	# TEST
	if p_tile_terrains.has(EMPTY_TERRAIN):
		var match_to_empty := true
		for tile_terrain in p_tile_terrains:
			if not has_peering_terrain(tile_terrain, EMPTY_TERRAIN):
				match_to_empty = false
				break
		# if match_to_empty:
		# 	assert(peering_terrain_scores.has(EMPTY_TERRAIN))
		# 	assert(peering_terrain_scores[EMPTY_TERRAIN] == get_score_peering_terrain(EMPTY_TERRAIN, true))

	# profiler.stop_timer("_create_transition_scores_list()")




func get_score_peering_terrain(p_peering_terrain : int, p_primary : bool, p_non_matching := false) -> int:
	var priority_score := _peering_terrain_priorities.find(p_peering_terrain) * PEERING_TERRAIN_PRIORITY_MULTIPLIER
	var rank_score : int
	if p_primary:
		rank_score = ScoreValues[Score.PRIMARY]
	else:
		rank_score = ScoreValues[Score.SECONDARY]
	var non_matching_score := 0
	if p_non_matching:
		non_matching_score = ScoreValues[Score.NON_MATCHING_BIT]
	return rank_score + non_matching_score - priority_score


func get_score_alternative_terrain(p_alternative_terrain : int, p_peering_terrain : int, p_primary : bool, p_non_matching := false) -> int:
	var peering_terrain_score := get_score_peering_terrain(p_peering_terrain, p_primary, p_non_matching)
	var alt_priority_score := get_score_alternative_adjustment(p_alternative_terrain)
	return peering_terrain_score - alt_priority_score


func get_score_alternative_adjustment(p_alternative_terrain : int) -> int:
	# add 1 to ensure that it is always lower than peering_terrain_score
	return 1 + _peering_terrain_priorities.find(p_alternative_terrain) * ALTERNATIVE_TERRAIN_PRIORITY_MULTIPLIER



func get_transition_dict(p_tile_terrains : Array) -> Dictionary:
	var key := _get_transition_key(p_tile_terrains)
	return _transition_peering_terrains.get(key, {})


# over 2x faster to use Array rather than StringName
# slightly slower to use PackedInt32Array
func _get_transition_key(p_tile_terrains : Array) -> Array:
	var terrains_set := {}
	for tile_terrain in p_tile_terrains:
		terrains_set[tile_terrain] = true
	var sorted_terrains := terrains_set.keys()
	sorted_terrains.sort()
	return sorted_terrains



# must be regular array (not PackedInt32Array), since we need to sort custom
func _get_peering_terrains(p_tile_terrain : int) -> Array:
	return _tile_peering_terrains_counts[p_tile_terrain].keys()


func _get_peering_terrain_pattern_count(p_tile_terrain : int, p_peering_terrain : int) -> int:
	return _tile_peering_terrains_counts[p_tile_terrain].get(p_peering_terrain, 0)



# ------------------------------
# 	QUERIES AND LOOKUPS
# ------------------------------

# get_pattern() using lookup is almost 4x faster than
# get_pattern_by_id() using StringName as key
# for a terrain set with 188 patterns cached:
# get_pattern() - 3msec per 1000 calls
# get_pattern_by_id() - 11msec per 1000 calls
# (likely due to creating IDs, but that part can't be skipped)
# only returns exact matches
# does not look for substitutes for alt terrains
func get_pattern(p_pattern : TerrainPattern) -> TerrainPattern:
	var dict : Dictionary = _pattern_lookup.get(p_pattern.tile_terrain, {})
	if dict.is_empty():
		return null

	var peering_bits := _ordered_peering_bits
	var bit_count := _ordered_peering_bits.size()
	var last_bit_index := bit_count - 1

	for i in bit_count:
		var bit : TileSet.CellNeighbor = peering_bits[i]
		var peering_terrain := p_pattern.get_bit_peering_terrain(bit)
		if i == last_bit_index:
			return dict.get(peering_terrain, null)
		dict = dict.get(peering_terrain, {})
		if dict.is_empty():
			break
	return null



func get_patterns_by_terrain(tile_terrain : int) -> Array:
	return _patterns_by_terrain.get(tile_terrain, [])


func find_patterns(p_search_pattern : SearchPattern) -> Array:
	if not p_search_pattern:
		return []

	# get initial dictionary
	var tile_terrain := p_search_pattern.tile_terrain
	var tile_terrain_dict : Dictionary = _pattern_lookup.get(tile_terrain, {})
	if tile_terrain_dict.is_empty():
		return []

	var possible_alt_terrains = tile_terrain_alt_terrains.get(tile_terrain, PackedInt32Array())

	# setup bits
	var bit_count := _ordered_peering_bits.size()
	var last_bit_index := bit_count - 1

	var current_bit_index := 0
	var current_dicts : Array[Dictionary] = [tile_terrain_dict]
	var next_dicts : Array[Dictionary] = []

	var patterns := []

	while current_bit_index <= last_bit_index:
		var bit : int = _ordered_peering_bits[current_bit_index]
		var possible_terrains := p_search_pattern.get_all_bit_peering_terrains(bit)

		# if an alternative terrain is in the search pattern
		# it is looking only for the alt terrain, not its possible terrains
		# so don't add extra peering terrains

		# if the tile terrain has an alt terrain that contains
		# the search pattern's peering terrain,
		# append the alt terrain to possible terrains for the bit
		for alt_terrain in possible_alt_terrains:
			for peering_terrain in possible_terrains.duplicate():
				if alt_terrain_peering_terrains[alt_terrain].has(peering_terrain):
					if not possible_terrains.has(alt_terrain):
						possible_terrains.append(alt_terrain)

		for dict in current_dicts:
			for peering_terrain in possible_terrains:
				if current_bit_index < last_bit_index:
					var next_dict : Dictionary = dict.get(peering_terrain, {})
					if next_dict.is_empty():
						continue
					next_dicts.append(next_dict)
				else:
					var pattern : TerrainPattern = dict.get(peering_terrain, null)
					if not pattern:
						continue
					patterns.append(pattern)

		current_dicts = next_dicts
		next_dicts = []

		current_bit_index += 1

	return patterns


func get_primary_peering_terrain(p_tile_terrain : int) -> int:
	if p_tile_terrain == NULL_TERRAIN:
		return NULL_TERRAIN
	return _primary_peering_terrains[p_tile_terrain]


func has_peering_terrain(p_tile_terrain : int, p_peering_terrain : int) -> bool:
	if _get_peering_terrain_pattern_count(p_tile_terrain, p_peering_terrain) > 0:
		return true
	var alt_terrains : PackedInt32Array = alt_terrain_peering_terrains.get(p_tile_terrain, PackedInt32Array())
	for alt_terrain in alt_terrains:
		if alt_terrain_peering_terrains[alt_terrain].has(p_peering_terrain):
			return true
	return false


func can_match_to_empty(p_tile_terrain : int) -> bool:
	return has_peering_terrain(p_tile_terrain, EMPTY_TERRAIN)


func get_primary_pattern(p_tile_terrain : int) -> TerrainPattern:
	return _primary_patterns.get(p_tile_terrain, null)





# -----------------------------------------------
#  DEBUG TEXT
# -----------------------------------------------

func get_debug_text(p_show_transitions : bool) -> String:
	var text := "Terrain patterns cached: %s" % _patterns_by_id.size()
	text += "\nTile terrains: %s + EMPTY" % tile_terrains.size()
	text += "\nPeering terrains: %s" % peering_terrains.size()
	text += "\n"

	var tile_terrain_order := _get_debug_tile_terrain_order()
	text += _get_debug_update_order_text(tile_terrain_order)

	text += "\n"

	for tile_terrain in tile_terrain_order:
		text += _get_debug_tile_terrain_text(tile_terrain, p_show_transitions)
		text += "\n"


	return text


func _get_debug_tile_terrain_order() -> PackedInt32Array:
	var printed_tile_terrain_order := []
	for tile_terrain in sorted_tile_terrains:
		if get_patterns_by_terrain(tile_terrain).size() == 1:
			printed_tile_terrain_order.push_front(tile_terrain)
		else:
			printed_tile_terrain_order.push_back(tile_terrain)
	printed_tile_terrain_order.push_front(-1)
	return PackedInt32Array(printed_tile_terrain_order)


func _get_debug_tile_terrain_text(p_tile_terrain : int, p_show_transitions : bool) -> String:
	var text := ""

	text += "\n"
	text += _get_terrain_color_template(p_tile_terrain) % "************************************"
	text += "\n"
	text += get_formatted_terrain_string(p_tile_terrain)
	text += "\n"

	if p_tile_terrain == EMPTY_TERRAIN:
		text += _get_terrain_color_template(p_tile_terrain) % "************************************"
		return text

	text += "\nTotal patterns: %s" % [get_patterns_by_terrain(p_tile_terrain).size()]
	text += "\nHas primary pattern? %s" % [(get_primary_pattern(p_tile_terrain) != null)]
	text += "\nCan match to empty? %s" % [can_match_to_empty(p_tile_terrain)]
	text += "\nHas full sets of all peering terrains? %s" % [full_set_tile_terrains_set.has(p_tile_terrain)]
	text += "\nPeering terrains:"
	var peering_terrain_texts := []
	var sorted_peering_terrains := _get_peering_terrains(p_tile_terrain).duplicate()
	sorted_peering_terrains.sort_custom(
		func(a,b):
			return get_patterns_by_terrain(a).size() > get_patterns_by_terrain(b).size()
	)
	for peering_terrain in sorted_peering_terrains:
		var template := "%s - %s patterns"
		if peering_terrain == get_primary_peering_terrain(p_tile_terrain):
			template = "%s [PRIMARY] - %s patterns"
		var t := template % [get_formatted_terrain_string(peering_terrain), _tile_peering_terrains_counts[p_tile_terrain][peering_terrain]]
		peering_terrain_texts.append(t)
	text += "\n\t"
	text += "\n\t".join(peering_terrain_texts)

	if p_show_transitions:
		text += "\n\nTransition peering terrain scores:"
		var to_terrains := sorted_tile_terrains + [EMPTY_TERRAIN]
		var a := p_tile_terrain
		for b in to_terrains:
			text += _get_debug_transition_texts([a, b])

		for b in to_terrains:
			for c in to_terrains:
				var terrains_set := {}
				terrains_set[a] = true
				if terrains_set.has(b):
					continue
				terrains_set[b] = true
				if terrains_set.has(c):
					continue
				terrains_set[c] = true
				text += _get_debug_transition_texts(terrains_set.keys())

		for b in to_terrains:
			for c in to_terrains:
				for d in to_terrains:
					var terrains_set := {}
					terrains_set[a] = true
					if terrains_set.has(b):
						continue
					terrains_set[b] = true
					if terrains_set.has(c):
						continue
					terrains_set[c] = true
					if terrains_set.has(d):
						continue
					text += _get_debug_transition_texts(terrains_set.keys())

	text += "\n"
	text += _get_terrain_color_template(p_tile_terrain) % "************************************"
	return text


func get_debug_transitions_text() -> String:
	return ""




func _get_debug_transition_texts(p_terrains : Array) -> String:
	var to_terrains_texts := []
	for terrain in p_terrains:
		to_terrains_texts.append(get_formatted_terrain_string(terrain))
	var text := "\n\t"

	text += " <-> ".join(to_terrains_texts)

	var transition_dict := get_transition_dict(p_terrains)
	if transition_dict.is_empty():
		text += "\n\t\t[NONE]"
		return text

	for peering_terrain in transition_dict:
		var score : int = transition_dict[peering_terrain]
		text += "\n\t\t%s - %s" % [get_formatted_terrain_string(peering_terrain), score]
	return text


func _get_debug_update_order_text(p_tile_terrain_order : PackedInt32Array) -> String:
	var text := "\nCell Update Order"
	var terrain_order_texts : PackedStringArray = []

	for tile_terrain in p_tile_terrain_order:
		if tile_terrain == EMPTY_TERRAIN:
			var empty_order_text := "%s [STATIC:EMPTY]" % get_formatted_terrain_string(EMPTY_TERRAIN)
			terrain_order_texts.append(empty_order_text)
		elif get_patterns_by_terrain(tile_terrain).size() == 1:
			var terrain_order_text = "%s [STATIC:SINGLE_PATTERN]" % get_formatted_terrain_string(tile_terrain)
			terrain_order_texts.append(terrain_order_text)
		else:
			terrain_order_texts.append(get_formatted_terrain_string(tile_terrain))

	text += "\n\t"
	text += "\n\t".join(terrain_order_texts)

	return text


func get_formatted_terrain_string(p_terrain : int, p_single_char := false) -> String:
	if p_terrain == NULL_TERRAIN:
		return " "
	var terrain_name : String = terrain_names.get(p_terrain, str(p_terrain))
	var terrain_string : String
	if p_single_char:
		terrain_string = terrain_name.substr(0,1)
	else:
		terrain_string = "%s (%s)" % [terrain_name, p_terrain]

	return _get_terrain_color_template(p_terrain) % terrain_string


func _get_terrain_color_template(terrain : int) -> String:
	var terrain_color : Color
	if terrain == EMPTY_TERRAIN:
		terrain_color = Color.DARK_GRAY
	elif terrain == NULL_TERRAIN:
		terrain_color = Color.SALMON
	else:
		terrain_color = tile_set.get_terrain_color(terrain_set, terrain)
	var color_string := terrain_color.to_html(false)

	return "[color={color}]%s[/color]".format(
		{
			"color": color_string,
		}
	)




