extends Object

const META_NAME := "terrain_autotiler"
const META_VERSION := "version"

# TileMap
const META_LAYERS := "layers"
const META_LOCKED_CELLS := "locked_cells"



static func validate_metadata(tile_map : TileMap) -> void:
	if not tile_map:
		return
	_validate_tile_map_metadata(tile_map)

	var tile_set := tile_map.tile_set
	if not tile_set:
		return
	validate_tile_set_metadata(tile_set)


# ---------------------------
# 	TILEMAP
# ---------------------------

static func _validate_tile_map_metadata(tile_map : TileMap) -> void:
	if not tile_map.has_meta(META_NAME):
		tile_map.set_meta(META_NAME, {})
	var meta : Dictionary = tile_map.get_meta(META_NAME)
	meta[META_VERSION] = get_plugin_version()

	if not meta.has(META_LAYERS):
		meta[META_LAYERS] = {}

	for layer in meta[META_LAYERS]:
		if layer >= tile_map.get_layers_count():
			meta[META_LAYERS].erase(layer)

	for layer in tile_map.get_layers_count():
		if not meta[META_LAYERS].has(layer):
			meta[META_LAYERS][layer] = {}
		var layer_meta : Dictionary = meta[META_LAYERS][layer]
		# early versions assigned an array here (no users affected)
		if not layer_meta.has(META_LOCKED_CELLS) or not layer_meta[META_LOCKED_CELLS] is Dictionary:
			layer_meta[META_LOCKED_CELLS] = {}



static func _get_locked_cells_dict(tile_map : TileMap, layer : int) -> Dictionary:
	_validate_tile_map_metadata(tile_map)
	var meta : Dictionary = tile_map.get_meta(META_NAME)
	var layers_meta : Dictionary = meta[META_LAYERS]
	return layers_meta[layer][META_LOCKED_CELLS]



static func get_locked_cells(tile_map : TileMap, layer : int) -> Array:
	return _get_locked_cells_dict(tile_map, layer).keys()


# using dict as set
static func set_cells_locked(tile_map : TileMap, layer : int, cells : Array, locked : bool) -> void:
	var locked_cells_dict := _get_locked_cells_dict(tile_map, layer)
	for coords in cells:
		if locked:
#			print("locking coords: %s" % coords)
			locked_cells_dict[coords] = true
		else:
#			print("erasing coords: %s" % coords)
			locked_cells_dict.erase(coords)
#			assert(not _get_locked_cells_dict(tile_map, layer).has(coords))
	tile_map.changed.emit()


# ---------------------------
# 	TILESET
# ---------------------------

# TileSet
const META_TERRAIN_SETS := "terrain_sets"
const META_MATCH_MODE := "match_mode"
const META_PRIMARY_PEERING_TERRAINS := "primary_peering_terrains"



static func validate_tile_set_metadata(tile_set : TileSet) -> void:
	if not is_instance_valid(tile_set):
		return

	if not tile_set.has_meta(META_NAME):
		tile_set.set_meta(META_NAME, {})
	var meta : Dictionary = tile_set.get_meta(META_NAME)
	meta[META_VERSION] = get_plugin_version() # always update version
	if not meta.has(META_TERRAIN_SETS):
		meta[META_TERRAIN_SETS] = {}

	var terrain_set_metas : Dictionary = meta[META_TERRAIN_SETS]

	# erase deleted terrain sets
	for terrain_set in terrain_set_metas:
		if terrain_set >= tile_set.get_terrain_sets_count():
			meta.erase(terrain_set)

	# verify/populate terrain set metas
	for terrain_set in tile_set.get_terrain_sets_count():
		if not terrain_set_metas.has(terrain_set):
			terrain_set_metas[terrain_set] = {}
		var terrain_set_meta : Dictionary = terrain_set_metas[terrain_set]
		_validate_match_mode(terrain_set_meta, tile_set)
		_validate_terrains(terrain_set_meta, tile_set, terrain_set)
		_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
		_validate_priorities(terrain_set_meta, tile_set, terrain_set)
		_validate_alternatives(terrain_set_meta, tile_set, terrain_set)


# calling this function will automatically validate terrains
static func _get_terrain_set_meta(tile_set : TileSet, terrain_set : int) -> Dictionary:
	var meta : Dictionary = tile_set.get_meta(META_NAME, {})
	var terrain_set_metas : Dictionary = meta.get(META_TERRAIN_SETS, {})
	var terrain_set_meta : Dictionary = terrain_set_metas.get(terrain_set, {})
	if terrain_set_meta.is_empty():
		return {}

	_validate_terrains(terrain_set_meta, tile_set, terrain_set)

	return terrain_set_meta




# ------------------------------------------------------
# 	MATCH MODE
# ------------------------------------------------------


static func _validate_match_mode(terrain_set_meta : Dictionary, tile_set : TileSet) -> void:
	if not terrain_set_meta.has(META_MATCH_MODE):
		terrain_set_meta[META_MATCH_MODE] = Autotiler._DEFAULT_MATCH_MODE


static func get_match_mode(tile_set : TileSet, terrain_set : int) -> Autotiler.MatchMode:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	return terrain_set_meta.get(META_MATCH_MODE, Autotiler._DEFAULT_MATCH_MODE)


static func set_match_mode(tile_set : TileSet, terrain_set : int, match_mode : Autotiler.MatchMode) -> void:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	terrain_set_meta[META_MATCH_MODE] = match_mode
	tile_set.changed.emit()


# ------------------------------------------------------
# 	TERRAINS
# ------------------------------------------------------
# terrain_set_meta[META_TERRAINS] = {terrain_id : {"index": int, "name" : String}

const META_TERRAINS := "terrains"
const TERRAIN_INDEX := "terrain_index"
const TERRAIN_NAME := "terrain_name"
const INVALID_IDENTIFIER := -99

static func _validate_terrains(
	terrain_set_meta : Dictionary,
	tile_set : TileSet,
	terrain_set : int) -> void:

	if not terrain_set_meta.has(META_TERRAINS):
		_create_terrains(terrain_set_meta, tile_set, terrain_set)
		return

	var terrains : Dictionary = terrain_set_meta[META_TERRAINS]
	var indexes_to_validate := []
	var ids_to_validate := terrains.keys()

	# validate all terrains with unchanged index-name pairs
	for terrain_index in tile_set.get_terrains_count(terrain_set):
		var validated := false
		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain_index)
		for next_terrain_id in ids_to_validate.duplicate():
			var next_terrain_dict : Dictionary = terrains.get(next_terrain_id, {})
			if next_terrain_dict.is_empty():
				continue
			var next_terrain_name : String = next_terrain_dict.get(TERRAIN_NAME, "")
			var next_terrain_index : int = next_terrain_dict.get(TERRAIN_INDEX, INVALID_IDENTIFIER)
			if terrain_index == next_terrain_index && terrain_name == next_terrain_name:
				ids_to_validate.erase(next_terrain_id)
				validated = true
				print("found terrain: %s - %s" % [terrain_index, terrain_name])
				break

		if not validated:
			indexes_to_validate.append(terrain_index)

	# Re-link index-names when one has changed.
	# To avoid errors if there are duplicate names,
	# limit search scope to unvalidated terrain ids only.

	# First, update terrains with the same name but different index
	for terrain_index in indexes_to_validate.duplicate():
		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain_index)
		for next_terrain_id in ids_to_validate.duplicate():
			var next_terrain_dict : Dictionary = terrains.get(next_terrain_id, {})
			if next_terrain_dict.is_empty():
				continue
			var next_terrain_name : String = next_terrain_dict.get(TERRAIN_NAME, "")
			if next_terrain_name == terrain_name:
				# if the name matches, replace the index with the current one
				print("Terrain Autotiler: Detected index change for '%s' terrain: new index = %s" % [terrain_name, terrain_index])
				next_terrain_dict[TERRAIN_INDEX] = terrain_index
				ids_to_validate.erase(next_terrain_id)
				indexes_to_validate.erase(terrain_index)
				break


	# Then update terrains with different names but the same index
	for terrain_index in indexes_to_validate.duplicate():
		var found := false
		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain_index)
		for next_terrain_id in ids_to_validate.duplicate():
			var next_terrain_dict : Dictionary = terrains.get(next_terrain_id, {})
			if next_terrain_dict.is_empty():
				continue
			var next_terrain_index : int = next_terrain_dict.get(TERRAIN_INDEX, INVALID_IDENTIFIER)
			if next_terrain_index == terrain_index:
				# if the index matches, replace the name with the current one
				print("Terrain Autotiler: Detected name change for terrain %s: new name = %s" % [terrain_index, terrain_name])
				next_terrain_dict[TERRAIN_NAME] = terrain_name
				ids_to_validate.erase(next_terrain_id)
				indexes_to_validate.erase(terrain_index)
				break

	# Remove data for unused terrain ids
	for terrain_id in ids_to_validate:
		print("Terrain Autotiler: Detected deleted terrain")
		terrains.erase(terrain_id)

	# Add new entries for missing terrain index-name pairs
	for terrain_index in indexes_to_validate:
		print("Terrain Autotiler: Detected new terrain")
		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain_index)
		var terrain_id := 0
		while terrains.has(terrain_id):
			terrain_id += 1
		terrains[terrain_id] = {
			TERRAIN_INDEX: terrain_index,
			TERRAIN_NAME: terrain_name,
		}


static func _create_terrains(
	terrain_set_meta : Dictionary,
	tile_set : TileSet,
	terrain_set : int) -> void:

	var terrains := {}

	# use index as id when first setting up
	for terrain_index in tile_set.get_terrains_count(terrain_set):
		var terrain_id : int = terrain_index
		terrains[terrain_id] = {
			TERRAIN_INDEX : terrain_index,
			TERRAIN_NAME : tile_set.get_terrain_name(terrain_set, terrain_index)
		}

	terrain_set_meta[META_TERRAINS] = terrains


static func _get_terrain_ids_list(terrain_set_meta : Dictionary, include_empty : bool) -> PackedInt32Array:
	var terrain_ids := PackedInt32Array(terrain_set_meta.get(META_TERRAINS, {}).keys())
	if include_empty:
		terrain_ids.append(Autotiler.EMPTY_TERRAIN)
	return terrain_ids


static func _terrain_ids_list_to_indexes(terrain_set_meta : Dictionary, id_list : Array) -> PackedInt32Array:
	var index_list := PackedInt32Array()
	for terrain_id in id_list:
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		index_list.append(terrain_index)
	return index_list




static func _is_terrain_id_valid(terrain_set_meta : Dictionary, terrain_id : int, allow_empty : bool) -> bool:
	if terrain_id == Autotiler.EMPTY_TERRAIN:
		return allow_empty
	var terrains : Dictionary = terrain_set_meta.get(META_TERRAINS, {})
	return terrains.has(terrain_id)


static func _get_terrain_id_name(terrain_set_meta : Dictionary, p_id : int) -> String:
	if p_id == Autotiler.EMPTY_TERRAIN:
		return "empty"

	var terrains : Dictionary = terrain_set_meta.get(META_TERRAINS, {})
	var terrain_dict : Dictionary = terrains.get(p_id, {})
	return terrain_dict.get(TERRAIN_NAME, "")


static func _terrain_index_to_id(terrain_set_meta : Dictionary, p_index : int) -> int:
	if p_index == Autotiler.EMPTY_TERRAIN:
		return Autotiler.EMPTY_TERRAIN

	var terrains : Dictionary = terrain_set_meta[META_TERRAINS]
	for terrain_id in terrains:
		var terrain_index : int = terrains[terrain_id].get(TERRAIN_INDEX, INVALID_IDENTIFIER)
		if terrain_index == INVALID_IDENTIFIER:
			continue
		if terrain_index == p_index:
			return terrain_id
	return INVALID_IDENTIFIER


static func _terrain_id_to_index(terrain_set_meta : Dictionary, p_id : int) -> int:
	if p_id == Autotiler.EMPTY_TERRAIN:
		return Autotiler.EMPTY_TERRAIN

	var terrains : Dictionary = terrain_set_meta.get(META_TERRAINS, {})
	var terrain_dict : Dictionary = terrains.get(p_id, {})
	return terrain_dict.get(TERRAIN_INDEX, INVALID_IDENTIFIER)


# returns first terrain id that matches terrain name
static func _terrain_name_to_id(terrain_set_meta : Dictionary, p_name : String) -> int:
	var terrains : Dictionary = terrain_set_meta[META_TERRAINS]
	for terrain_id in terrains:
		var terrain_name : String = terrains[terrain_id].get(TERRAIN_NAME, "")
		if p_name == terrain_name:
			return terrain_id
	return INVALID_IDENTIFIER





# ------------------------------------------------------
# 	PRIMARY PEERING TERRAINS
# ------------------------------------------------------


static func _validate_primary_peering_terrains(
	terrain_set_meta : Dictionary,
	tile_set : TileSet,
	terrain_set : int) -> void:

	if not terrain_set_meta.has(META_PRIMARY_PEERING_TERRAINS):
		_reset_primary_peering_terrains(terrain_set_meta)
		return

	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]

	for terrain_id in primary_peering_terrains.keys():
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		if terrain_index == INVALID_IDENTIFIER or \
			_is_terrain_id_alternative(terrain_set_meta, terrain_id):

			primary_peering_terrains.erase(terrain_id)

	var terrain_ids_list := _get_terrain_ids_list(terrain_set_meta, false)
	for terrain_id in terrain_ids_list:
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		if _is_terrain_id_alternative(terrain_set_meta, terrain_id):
			continue
		var primary_terrain_id : int = primary_peering_terrains.get(terrain_id, INVALID_IDENTIFIER)
		if primary_terrain_id == INVALID_IDENTIFIER or \
			not terrain_ids_list.has(primary_terrain_id):

			primary_peering_terrains[terrain_id] = terrain_id

# call externally
static func reset_primary_peering_terrains(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)

	_reset_primary_peering_terrains(terrain_set_meta)
	tile_set.changed.emit()


# call internally
static func _reset_primary_peering_terrains(terrain_set_meta : Dictionary) -> void:
	var primary_peering_terrains := {}

	for terrain_id in _get_terrain_ids_list(terrain_set_meta, false):
		primary_peering_terrains[terrain_id] = terrain_id

	terrain_set_meta[META_PRIMARY_PEERING_TERRAINS] = primary_peering_terrains


static func set_primary_peering_terrain(
	tile_set : TileSet,
	terrain_set : int,
	tile_terrain : int,
	peering_terrain : int) -> void:

	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)

	var tile_terrain_id := _terrain_index_to_id(terrain_set_meta, tile_terrain)
	if tile_terrain_id == INVALID_IDENTIFIER or tile_terrain_id == Autotiler.EMPTY_TERRAIN:
		printerr("Terrain Autotiler: set_primary_peering_terrain() called with invalid tile terrain")
		return

	var peering_terrain_id := _terrain_index_to_id(terrain_set_meta, peering_terrain)
	if peering_terrain_id == INVALID_IDENTIFIER or peering_terrain_id == Autotiler.EMPTY_TERRAIN:
		printerr("Terrain Autotiler: set_primary_peering_terrain() called with invalid peering terrain")
		return

	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta.get(META_PRIMARY_PEERING_TERRAINS, {})
	primary_peering_terrains[tile_terrain_id] = peering_terrain_id
	tile_set.changed.emit()


static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	if terrain_set_meta.is_empty():
		return Autotiler.NULL_TERRAIN

	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta.get(META_PRIMARY_PEERING_TERRAINS, {})

	var tile_terrain_id : int = _terrain_index_to_id(terrain_set_meta, tile_terrain)
	# if something has gone wrong, default to returning the tile terrain
	var peering_terrain_id : int = primary_peering_terrains.get(tile_terrain_id, tile_terrain_id)
	var peering_terrain_index := _terrain_id_to_index(terrain_set_meta, peering_terrain_id)

	if peering_terrain_index == INVALID_IDENTIFIER:
		return Autotiler.NULL_TERRAIN

	return peering_terrain_index


static func get_primary_peering_terrains(tile_set : TileSet, terrain_set : int) -> Dictionary:
	if not is_instance_valid(tile_set):
		return {}
	if terrain_set >= tile_set.get_terrain_sets_count():
		return {}

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]

	var primary_peering_terrains_by_index := {}
	for tile_terrain_id in primary_peering_terrains:
		var tile_terrain_index := _terrain_id_to_index(terrain_set_meta, tile_terrain_id)
		var peering_terrain_id : int = primary_peering_terrains.get(tile_terrain_id, INVALID_IDENTIFIER)
		var peering_terrain_index := _terrain_id_to_index(terrain_set_meta, peering_terrain_id)
		primary_peering_terrains_by_index[peering_terrain_index] = peering_terrain_index

	return primary_peering_terrains_by_index






# ------------------------------------------------------
# 	PEERING TERRAIN PRIORITIES
# ------------------------------------------------------
# terrain_set_meta[META_PRIORITIES] = PackedInt32Array
# 			index = priority
#			value = terrain index

const META_PRIORITIES := "peering_terrain_priorities"
const META_PRIORITIES_USE_CUSTOM := "custom_priorities"
const META_PRIORITIES_LIST := "priorities_list"

static func _validate_priorities(terrain_set_meta : Dictionary, tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	# create if doesn't exist or invalid
	if not terrain_set_meta.has(META_PRIORITIES) \
		or not terrain_set_meta[META_PRIORITIES].has(META_PRIORITIES_USE_CUSTOM) \
		or not terrain_set_meta[META_PRIORITIES].has(META_PRIORITIES_LIST):

		_reset_priorities(terrain_set_meta)
		return

	# if not using custom priorities, set the list to default
	if terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM] == false:
		terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = _get_default_priorities_list(terrain_set_meta)
		return

	# if using custom priorities, validate the list
	var priorities : PackedInt32Array = terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]
	var terrain_ids_list := _get_terrain_ids_list(terrain_set_meta, true)

	# remove invalid terrain ids
	for terrain_id in priorities.duplicate():
		if not terrain_ids_list.has(terrain_id):
			var priority_index := priorities.find(terrain_id)
			priorities.remove_at(priority_index)

	# append missing terrains to the end
	for terrain_id in terrain_ids_list:
		if not priorities.has(terrain_id):
			priorities.append(terrain_id)

	# remove any duplicates (shouldn't occur)
	if priorities.size() != terrain_ids_list.size():
		var priorities_set := {}
		for terrain_id in priorities:
			priorities_set[terrain_id] = true
		priorities = PackedInt32Array(priorities_set.keys())

	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = priorities


# call internally
static func _reset_priorities(terrain_set_meta : Dictionary) -> void:
	terrain_set_meta[META_PRIORITIES] = {
		META_PRIORITIES_USE_CUSTOM : false,
		META_PRIORITIES_LIST : _get_default_priorities_list(terrain_set_meta),
	}


# call externally
static func reset_priorities_list(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_reset_priorities(terrain_set_meta)


static func _get_default_priorities_list(terrain_set_meta : Dictionary) -> PackedInt32Array:
	var terrain_ids_list := _get_terrain_ids_list(terrain_set_meta, false)
	var priorities := PackedInt32Array()
	priorities.resize(terrain_ids_list.size())

	for terrain_id in terrain_ids_list:
		# order by their index by default
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		priorities[terrain_index] = terrain_id

	priorities.append(Autotiler.EMPTY_TERRAIN) # empty terrain is last by default
	return priorities


static func increase_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain : int) -> void:
	_alter_peering_terrain_priority(tile_set, terrain_set, terrain, 1)


static func decrease_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain : int) -> void:
	_alter_peering_terrain_priority(tile_set, terrain_set, terrain, -1)


static func _alter_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain_index : int, amount : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_priorities(terrain_set_meta, tile_set, terrain_set)

	var priorities : PackedInt32Array = terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]

	var terrain_id := _terrain_index_to_id(terrain_set_meta, terrain_index)

	const INDEX_NOT_FOUND := -1
	var old_priority_index := priorities.find(terrain_id)
	if old_priority_index == INDEX_NOT_FOUND:
		return

	var new_priority_index = old_priority_index + amount
	new_priority_index = maxi(new_priority_index, 0)
	new_priority_index = mini(new_priority_index, priorities.size() - 1)

	if new_priority_index == old_priority_index:
		return

	priorities.remove_at(old_priority_index)
	priorities.insert(new_priority_index, terrain_id)

	# priorities is a PackedInt32Array, so we manipulated its value, not reference
	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = priorities
	tile_set.changed.emit()


static func set_use_custom_priorities(tile_set : TileSet, terrain_set : int, value : bool) -> void:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_priorities(terrain_set_meta, tile_set, terrain_set)

	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM] = value
	tile_set.changed.emit()


static func get_use_custom_priorities(tile_set : TileSet, terrain_set : int) -> bool:
	if not is_instance_valid(tile_set):
		return false
	if terrain_set >= tile_set.get_terrain_sets_count():
		return false

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_priorities(terrain_set_meta, tile_set, terrain_set)

	return terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM]


static func get_priorities_list(tile_set : TileSet, terrain_set : int) -> PackedInt32Array:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_priorities(terrain_set_meta, tile_set, terrain_set)

	var priorities : PackedInt32Array = terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]
	var priorities_by_index := PackedInt32Array()

	for terrain_id in priorities:
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		priorities_by_index.append(terrain_index)

	return priorities_by_index







# ------------------------------------------------------
# 	PEERING TERRAIN ALTERNATIVES
# ------------------------------------------------------

# terrain_set_meta[META_ALTERNATIVES][terrain_id] =
# 		{
#			"META_ALTERNATIVE_MATCH_ALL" : bool,
#			"META_ALTERNATIVE_MATCH_TERRAINS": PackedInt32Array,
#		}

const META_ALTERNATIVES := "peering_terrain_alternatives" # dictionary
const META_ALTERNATIVE_MATCH_ALL := "match_all" # bool
const META_ALTERNATIVE_MATCH_TERRAINS := "match_terrains" # PackedInt32Array


static func _validate_alternatives(terrain_set_meta : Dictionary, tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	# create if doesn't exist or invalid
	if not terrain_set_meta.has(META_ALTERNATIVES):
		terrain_set_meta[META_ALTERNATIVES] = {}

	var alternatives : Dictionary = terrain_set_meta[META_ALTERNATIVES]

	var terrain_set_alternatives := _get_alternative_terrain_ids_from_terrain_set(terrain_set_meta)

	# validate terrain ids
	for terrain_id in alternatives.keys():
		# early dev versions of 0.3 used names instead of ids, convert to id if found
		if typeof(terrain_id) == TYPE_STRING or typeof(terrain_id) == TYPE_STRING_NAME:
			var id_from_name := _terrain_name_to_id(terrain_set_meta, terrain_id)
			if id_from_name == INVALID_IDENTIFIER:
				# if name isn't found, erase the entry
				print("Terrain Autotiler: Unable to convert alternative terrain %s" % terrain_id)
				alternatives.erase(terrain_id)
			else:
				print("Terrain Autotiler: Converting alternative terrain meta for %s" % terrain_id)
				var dict : Dictionary = alternatives.get(terrain_id, {})
				alternatives[id_from_name] = dict
				alternatives.erase(terrain_id)

		if not terrain_set_alternatives.has(terrain_id):
			print("Terrain Autotiler: Detected alternative terrain removed")
			alternatives.erase(terrain_id)

	# add alternatives not in list
	for terrain_id in terrain_set_alternatives:
		if not alternatives.has(terrain_id):
			alternatives[terrain_id] = {}

	# validate individual alternatives
	for terrain_id in alternatives:
		var alternative_dict : Dictionary = alternatives[terrain_id]
		if not alternative_dict.has(META_ALTERNATIVE_MATCH_ALL):
			# default MATCH_ALL = true
			alternative_dict[META_ALTERNATIVE_MATCH_ALL] = true
		if not alternative_dict.has(META_ALTERNATIVE_MATCH_TERRAINS):
			# default list is empty
			alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array()

		if alternative_dict[META_ALTERNATIVE_MATCH_ALL] == true:
			alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array()
			continue

		# validate match terrains
		var match_list : PackedInt32Array = alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS]

		# remove duplicates
		var match_terrains_set := {}
		for match_terrain_id in match_list:
			match_terrains_set[match_terrain_id] = true

		# remove invalid terrains
		for match_terrain_id in match_terrains_set.keys():
			if not _is_terrain_id_valid(terrain_set_meta, match_terrain_id, false):
				match_terrains_set.erase(match_terrain_id)

		# sort
		var new_match_list := PackedInt32Array(match_terrains_set.keys())
		new_match_list.sort()

		alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array(new_match_list)



static func _get_alternative_terrain_ids_from_terrain_set(terrain_set_meta : Dictionary) -> PackedInt32Array:
	var terrain_ids_list := _get_terrain_ids_list(terrain_set_meta, false)
	var alternative_terrain_ids_list := PackedInt32Array()
	for terrain_id in terrain_ids_list:
		if _is_terrain_id_alternative(terrain_set_meta, terrain_id):
			alternative_terrain_ids_list.append(terrain_id)
	return alternative_terrain_ids_list



static func get_alternatives_list(tile_set : TileSet, terrain_set : int) -> PackedInt32Array:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	if terrain_set_meta.is_empty():
		return PackedInt32Array()

	var alternatives : Dictionary = terrain_set_meta[META_ALTERNATIVES]
	var alternative_ids := PackedInt32Array(alternatives.keys())

	var alternative_indexes := PackedInt32Array()
	for terrain_id in alternative_ids:
		var terrain_index := _terrain_id_to_index(terrain_set_meta, terrain_id)
		alternative_indexes.append(terrain_id)

	return alternative_indexes


static func set_alternative_match_all(
	tile_set : TileSet,
	terrain_set : int,
	terrain : int,
	value : bool) -> void:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, terrain)
	if alternative_dict.is_empty():
		return

	alternative_dict[META_ALTERNATIVE_MATCH_ALL] = value
	tile_set.changed.emit()



static func get_alternative_match_all(
	tile_set : TileSet,
	terrain_set : int,
	terrain : int) -> bool:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, terrain)
	return alternative_dict.get(META_ALTERNATIVE_MATCH_ALL, true)


static func add_alternative_match_terrain(
	tile_set : TileSet,
	terrain_set : int,
	alt_terrain_index : int,
	match_terrain_index : int) -> void:

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var alt_dict := _get_alternative_dict(tile_set, terrain_set, alt_terrain_index)
	if alt_dict.is_empty():
		return

	var match_terrain_id := _terrain_index_to_id(terrain_set_meta, match_terrain_index)
	var match_terrains_list : PackedInt32Array = alt_dict[META_ALTERNATIVE_MATCH_TERRAINS]
	match_terrains_list.append(match_terrain_id)
	alt_dict[META_ALTERNATIVE_MATCH_TERRAINS] = match_terrains_list
	tile_set.changed.emit()



static func remove_alternative_match_terrain(
	tile_set : TileSet,
	terrain_set : int,
	alt_terrain_index : int,
	match_terrain_index : int) -> void:

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var alt_dict := _get_alternative_dict(tile_set, terrain_set, alt_terrain_index)
	if alt_dict.is_empty():
		return

	var match_terrain_id := _terrain_index_to_id(terrain_set_meta, match_terrain_index)
	var match_terrains_list : PackedInt32Array = alt_dict[META_ALTERNATIVE_MATCH_TERRAINS]

	const INDEX_NOT_FOUND := -1
	var list_index := match_terrains_list.find(match_terrain_id)
	if list_index == INDEX_NOT_FOUND:
		return

	match_terrains_list.remove_at(list_index)
	alt_dict[META_ALTERNATIVE_MATCH_TERRAINS] = match_terrains_list
	tile_set.changed.emit()


static func get_alternative_match_terrains(
	tile_set : TileSet,
	terrain_set : int,
	alt_terrain_index : int) -> PackedInt32Array:

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var alt_dict := _get_alternative_dict(tile_set, terrain_set, alt_terrain_index)
	if alt_dict.is_empty():
		return PackedInt32Array()

	var match_terrain_ids_list : PackedInt32Array

	if alt_dict[META_ALTERNATIVE_MATCH_ALL] == true:
		match_terrain_ids_list = _get_alternative_match_all_terrain_ids(terrain_set_meta)
	else:
		match_terrain_ids_list = alt_dict[META_ALTERNATIVE_MATCH_TERRAINS]

	var match_terrain_indexes_list := _terrain_ids_list_to_indexes(terrain_set_meta, match_terrain_ids_list)
	return match_terrain_indexes_list


static func get_alternative_match_terrains_can_add(
	tile_set : TileSet,
	terrain_set : int,
	alt_terrain_index : int) -> PackedInt32Array:

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var alt_dict := _get_alternative_dict(tile_set, terrain_set, alt_terrain_index)
	if alt_dict.is_empty():
		return PackedInt32Array()

	var can_add_terrain_ids_list := PackedInt32Array()

	for terrain_id in _get_terrain_ids_list(terrain_set_meta, true):
		if _is_terrain_id_alternative(terrain_set_meta, terrain_id):
			continue
		can_add_terrain_ids_list.append(terrain_id)

	var can_add_terrain_indexes_list := _terrain_ids_list_to_indexes(terrain_set_meta, can_add_terrain_ids_list)

	can_add_terrain_indexes_list.sort()
	return can_add_terrain_indexes_list



static func _get_alternative_match_all_terrain_ids(terrain_set_meta : Dictionary) -> PackedInt32Array:
	var terrain_ids_list := _get_terrain_ids_list(terrain_set_meta, true)
	var match_all_list := PackedInt32Array()
	for terrain_id in terrain_ids_list:
		if _is_terrain_id_alternative(terrain_set_meta, terrain_id):
			continue
		match_all_list.append(terrain_id)

	return match_all_list


# if anything is invalid, returns an empty dict
static func _get_alternative_dict(tile_set : TileSet, terrain_set : int, terrain_index : int) -> Dictionary:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var alternatives : Dictionary = terrain_set_meta.get(META_ALTERNATIVES, {})
	var terrain_id := _terrain_index_to_id(terrain_set_meta, terrain_index)
	var dict : Dictionary = alternatives.get(terrain_id, {})
	return dict


static func _is_terrain_id_alternative(terrain_set_meta : Dictionary, terrain_id : int) -> bool:
	var terrain_name := _get_terrain_id_name(terrain_set_meta, terrain_id)
	return terrain_name.begins_with("@")


static func get_plugin_version() -> String:
	var config := ConfigFile.new()
	config.load("res://addons/terrain_autotiler/plugin.cfg")
	return config.get_value("plugin", "version", "0.0.0")



