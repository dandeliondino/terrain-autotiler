extends RefCounted


enum CellError {
	EXPAND_PROGENITOR,
	INVALID_SEARCH_CONFLICTING_NEIGHBORS,
	NO_PATTERN_ASSIGNED,
	NO_PATTERN_FOUND,
	NO_PATTERN_EXISTS,
	NO_MATCH_TO_EMPTY,
}

const CellErrorTexts := {
	CellError.EXPAND_PROGENITOR: "EXPAND_PROGENITOR",
	CellError.INVALID_SEARCH_CONFLICTING_NEIGHBORS: "INVALID_SEARCH_CONFLICTING_NEIGHBORS",
	CellError.NO_PATTERN_ASSIGNED: "NO_PATTERN_ASSIGNED",
	CellError.NO_PATTERN_FOUND: "NO_PATTERN_FOUND",
	CellError.NO_PATTERN_EXISTS: "NO_PATTERN_EXISTS",
	CellError.NO_MATCH_TO_EMPTY: "NO_MATCH_TO_EMPTY",
}

enum PatternType {
	NONE,
	NEIGHBOR,
	STATIC_UPDATE_EMPTY,
	STATIC_UPDATE_MISSING,
	STATIC_UPDATE_SINGLE_PATTERN,
	STATIC_UPDATE_PRIMARY_PATTERN,
	COMPLEX_TOP_PATTERN,
	COMPLEX_BEST_PATTERN,
	SIMPLE_TOP_PATTERN,
	SIMPLE_BEST_PATTERN,
	NON_MATCHING_BEST_PATTERN,
	MAX,
}

var PatternTypeTexts := {
	PatternType.NONE: "NONE",
	PatternType.NEIGHBOR: "NEIGHBOR",
	PatternType.STATIC_UPDATE_EMPTY: "STATIC_UPDATE_EMPTY",
	PatternType.STATIC_UPDATE_MISSING: "STATIC_UPDATE_MISSING",
	PatternType.STATIC_UPDATE_SINGLE_PATTERN: "STATIC_UPDATE_SINGLE_PATTERN",
	PatternType.STATIC_UPDATE_PRIMARY_PATTERN: "STATIC_UPDATE_PRIMARY_PATTERN",
	PatternType.COMPLEX_TOP_PATTERN: "COMPLEX_TOP_PATTERN",
	PatternType.COMPLEX_BEST_PATTERN: "COMPLEX_BEST_PATTERN",
	PatternType.SIMPLE_TOP_PATTERN: "SIMPLE_TOP_PATTERN",
	PatternType.SIMPLE_BEST_PATTERN: "SIMPLE_BEST_PATTERN",
	PatternType.NON_MATCHING_BEST_PATTERN: "NON_MATCHING_BEST_PATTERN",
}

const BIT_TEMPLATES := {
	TileSet.TILE_SHAPE_SQUARE:
			"\n\t\t{TOP_LEFT_CORNER} {TOP_SIDE} {TOP_RIGHT_CORNER}\n" \
		+ 	"\t\t{LEFT_SIDE} {TERRAIN} {RIGHT_SIDE}\n" \
		+ 	"\t\t{BOTTOM_LEFT_CORNER} {BOTTOM_SIDE} {BOTTOM_RIGHT_CORNER}\n",
	TileSet.TILE_SHAPE_ISOMETRIC:
			"\n\t\t  {TOP_CORNER}\n" \
		+	"\t\t{TOP_LEFT_SIDE}   {TOP_RIGHT_SIDE}\n" \
		+	"\t\t{LEFT_CORNER} {TERRAIN} {RIGHT_CORNER}\n" \
		+	"\t\t{BOTTOM_LEFT_SIDE}   {BOTTOM_RIGHT_SIDE}\n" \
		+	"\t\t  {BOTTOM_CORNER}\n",
	TileSet.TILE_SHAPE_HEXAGON: {
		TileSet.TILE_OFFSET_AXIS_HORIZONTAL:
				"\n\t\t{TOP_LEFT_SIDE} {TOP_CORNER} {TOP_RIGHT_SIDE}\n" \
			+	"\t\t{TOP_LEFT_CORNER}   {TOP_RIGHT_CORNER}\n" \
			+ 	"\t\t{LEFT_SIDE} {TERRAIN} {RIGHT_SIDE}\n" \
			+	"\t\t{BOTTOM_LEFT_CORNER} {BOTTOM_RIGHT_CORNER}\n" \
			+	"\t\t{BOTTOM_LEFT_SIDE} {BOTTOM_CORNER} {BOTTOM_RIGHT_SIDE}\n",
		TileSet.TILE_OFFSET_AXIS_VERTICAL:
				"\n\t\t{TOP_LEFT_CORNER} {TOP_SIDE} {TOP_RIGHT_CORNER}\n" \
			+	"\t\t{TOP_LEFT_SIDE}   {TOP_RIGHT_SIDE}\n" \
			+	"\t\t{LEFT_CORNER} {TERRAIN} {RIGHT_CORNER}\n" \
			+	"\t\t{BOTTOM_LEFT_SIDE}   {BOTTOM_RIGHT_SIDE}\n" \
			+	"\t\t{BOTTOM_LEFT_CORNER} {BOTTOM_SIDE} {BOTTOM_RIGHT_CORNER}\n",
	},
}

const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")
const SearchPattern := preload("res://addons/terrain_autotiler/core/search_pattern.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")

var cell_errors := {}
var cell_warnings := {}
var cell_pattern_types := {}
var cell_update_indexes := {}
var cell_logs := {}

var terrains_data : TerrainsData
var bit_template : String

var cell_tiles_before := {} # {coords : TileLocation}
var cell_tiles_after := {} # {coords : TileLocation}

var edge_cells : Array[Vector2i]

var _current_update_index := 0

func assign_next_update_index(p_coords : Vector2i) -> void:
	_current_update_index += 1
	set_cell_update_index(p_coords, _current_update_index)



func _init(p_terrains_data : TerrainsData) -> void:
	terrains_data = p_terrains_data
	bit_template = _get_bit_template()

func get_cell_pattern_type_text(coords : Vector2i) -> String:
	var pattern_type : PatternType = cell_pattern_types.get(coords, PatternType.NONE)
	return PatternTypeTexts[pattern_type]


func add_cell_log(coords : Vector2i, data) -> void:
	if not cell_logs.has(coords):
		cell_logs[coords] = []
	if not cell_pattern_types.has(coords):
		set_cell_pattern_type(coords, PatternType.NONE)
	if not data is Array:
		data = [data]

	for log_data in data:
		if log_data is String:
			cell_logs[coords].append(log_data)
		elif log_data is SearchPattern:
			cell_logs[coords].append(_get_search_pattern_text(log_data))
		elif log_data is TerrainPattern:
			cell_logs[coords].append(_get_terrain_pattern_text(log_data))
		else:
			cell_logs[coords].append(str(log_data))




func add_cell_error(coords : Vector2i, error : CellError) -> void:
	cell_errors[coords] = error
	add_cell_log(coords, "[color=salmon]Error added: %s[/color]" % CellErrorTexts[error])


func add_cell_warning(coords : Vector2i, error : CellError) -> void:
	cell_warnings[coords] = error
	add_cell_log(coords, "[color=gold]Warning added: %s[/color]" % CellErrorTexts[error])


func set_cell_pattern_type(coords : Vector2i, pattern_type : PatternType) -> void:
	cell_pattern_types[coords] = pattern_type
	add_cell_log(coords, "Assigning pattern type: %s" % PatternTypeTexts[pattern_type])


func set_cell_update_index(coords : Vector2i, index : int) -> void:
	cell_update_indexes[coords] = index
	add_cell_log(coords, "Update index: %s" % index)




func get_stats_text() -> String:
	var total := 0
	var pattern_counts := {}

	for coords in cell_pattern_types:
		total += 1
		var pattern_type : PatternType = cell_pattern_types[coords]
		if pattern_counts.has(pattern_type):
			pattern_counts[pattern_type] += 1
		else:
			pattern_counts[pattern_type] = 1

	var s := "\nTotal cells evaluated: %s" % total
	s += "\nTiles changed: %s" % cell_tiles_after.size()
	s += "\n\nPattern types:"
	for pattern_type in PatternType.MAX:
		var pattern_text : String = PatternTypeTexts[pattern_type]
		var count : int = pattern_counts.get(pattern_type, 0)
		s += "\n\t%s: %s" % [pattern_text, count]
	return s


func get_errors_text() -> String:
	if cell_errors.is_empty() and cell_warnings.is_empty():
		return "\n\nNo errors or warnings"

	var s := ""

	if not cell_errors.is_empty():
		s += "\n\n[color=salmon]%s Errors[/color]" % cell_errors.size()
		for coords in cell_errors:
			var error : CellError = cell_errors[coords]
			s += "\n\t%s: %s" % [coords, CellErrorTexts[error]]


	if not cell_warnings.is_empty():
		s += "\n\n[color=gold]%s Warnings[/color]" % cell_warnings.size()
		var warnings := {}
		for coords in cell_warnings:
			var error : CellError = cell_warnings[coords]
			if warnings.has(error):
				warnings[error] += 1
			else:
				warnings[error] = 1

		for warning in warnings:
			s += "\n\t%s: %s" % [CellErrorTexts[warning], warnings[warning]]

	return s


func get_cell_log_texts(coords : Vector2i) -> Array:
	return cell_logs.get(coords, [])



func _get_search_pattern_text(pattern : SearchPattern) -> String:
	var s := "\nSearch pattern created:"
	s += _get_bits_text(pattern.tile_terrain, pattern.get_bit_peering_terrains_dict())
	for bit in pattern.get_peering_bits():
		if pattern.get_bit_peering_terrain(bit) != Autotiler.NULL_TERRAIN:
			continue
		var peering_bit_scores := pattern.get_bit_scores(bit)
		if peering_bit_scores.is_empty():
			continue
		s += "\n\t%s:" % CellNeighbors.get_text(bit)
		for peering_terrain in peering_bit_scores:
			var score : int = peering_bit_scores[peering_terrain]
			s += "\n\t\t%s - %s" % [terrains_data.get_formatted_terrain_string(peering_terrain, true), score]

	return s


func _get_terrain_pattern_text(pattern : TerrainPattern) -> String:
	var s := ""
	s += _get_bits_text(pattern.tile_terrain, pattern.get_bit_peering_terrains_dict())
	return s


func _get_bits_text(terrain : int, bit_dict : Dictionary) -> String:
	var format_dict := {}
	for bit in CellNeighbors.CellNeighborsTexts:
		var s : String
		var peering_terrain : int = bit_dict.get(bit, Autotiler.NULL_TERRAIN)
		if peering_terrain == Autotiler.NULL_TERRAIN:
			if bit in terrains_data.cn.get_peering_bits():
				s = "*"
			else:
				s = "-"
		else:
			s = terrains_data.get_formatted_terrain_string(peering_terrain, true)
		format_dict[bit] = s

	format_dict["TERRAIN"] = terrains_data.get_formatted_terrain_string(terrain, true)
	return bit_template.format(format_dict)







func _get_bit_template() -> String:
	var template : String
	var tile_shape := terrains_data.tile_set.tile_shape

	if tile_shape == TileSet.TILE_SHAPE_HEXAGON:
		var offset_axis := terrains_data.tile_set.tile_offset_axis
		template = BIT_TEMPLATES[tile_shape][offset_axis]
	else:
		template = BIT_TEMPLATES[tile_shape]

	for neighbor in CellNeighbors.CellNeighborsTexts:
		var text : String = "{%s}" % CellNeighbors.CellNeighborsTexts[neighbor]
		var id : String = "{%s}" % neighbor
		template = template.replace(text, id)

	return template


# ---------------------
# 	PROFILER
# ---------------------

var current_timers := {}
var recorded_timers := {}
var single_timers := {}


func get_tiles_updater_timer_text() -> String:
	var times : Array = recorded_timers["tiles_updater"]
	if times.is_empty():
		return ""
	var time : int = times[0]

	var s := "Terrain tiles update complete in %s msec\n" % [to_msec(time)]
	return s


func start_timer(p_name : String) -> void:
	assert(not current_timers.has(p_name))
	current_timers[p_name] = Time.get_ticks_usec()


func stop_timer(p_name : String) -> void:
	if not current_timers.has(p_name):
		return
	var elapsed_time : int = Time.get_ticks_usec() - current_timers[p_name]
	if not recorded_timers.has(p_name):
		recorded_timers[p_name] = [elapsed_time]
	else:
		recorded_timers[p_name].append(elapsed_time)
	current_timers.erase(p_name)


static func to_msec(usec : int) -> int:
	return int(float(usec)/1000.0)


static func to_sec(usec : int) -> float:
	var sec := float(usec)/1000000.0
	return snapped(sec, 0.001)


func print_timers() -> void:
	var stats := {}
	for timer in recorded_timers:
		stats[timer] = {}
		var times : Array = recorded_timers[timer]
		stats[timer]["count"] = times.size()
		stats[timer]["min (msec)"] = to_msec(times.min())
		stats[timer]["max (msec)"] = to_msec(times.max())
		var total_usec : int = times.reduce(
			func(accum, a):
				return accum + a
		)
		var average_usec := int(float(total_usec)/float(times.size()))

		stats[timer]["average (msec)"] = to_msec(average_usec)
		stats[timer]["total (sec)"] = to_sec(total_usec)

	# var timers_by_average_time := stats.keys().duplicate()
	# timers_by_average_time.sort_custom(
	# 	func(a,b):
	# 		return stats[a]["average (msec)"] > stats[b]["average (msec)"]
	# )
	# _print_sorted_timers("Average Time", timers_by_average_time, stats)

	var timers_by_total_time := stats.keys().duplicate()
	timers_by_total_time.sort_custom(
		func(a,b):
			return stats[a]["total (sec)"] > stats[b]["total (sec)"]
	)
	_print_sorted_timers("Total Time", timers_by_total_time, stats)



func _print_sorted_timers(p_name : String, sorted_list : Array, stats : Dictionary) -> void:
	print("\n-----------------")
	print(p_name)
	print("-----------------")
	for i in sorted_list.size():
		var timer : String = sorted_list[i]
		var timer_stats : Dictionary = stats[timer]
		var timer_string := "%s. %s : " % [i, timer]
		for key in stats[timer]:
			var msec : float = stats[timer][key]
#			var sec : float = float(msec) * 0.001
#			sec = snapped(sec, 0.001)
			timer_string += "%s: %s | " % [key, msec]
		print(timer_string)
	print()
