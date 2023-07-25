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
		_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
		_validate_priorities(tile_set, terrain_set)
		_validate_alternatives(tile_set, terrain_set)


static func _get_terrain_set_meta(tile_set : TileSet, terrain_set : int) -> Dictionary:
	var meta : Dictionary = tile_set.get_meta(META_NAME, {})
	if meta.is_empty():
		return {}
	var terrain_set_metas : Dictionary = meta.get(META_TERRAIN_SETS, {})
	if terrain_set_metas.is_empty():
		return {}
	return terrain_set_metas.get(terrain_set, {})


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



static func _validate_primary_peering_terrains(terrain_set_meta : Dictionary, tile_set : TileSet, terrain_set : int) -> void:
	if not terrain_set_meta.has(META_PRIMARY_PEERING_TERRAINS):
		reset_primary_peering_terrains(tile_set, terrain_set)
		return

	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]

	for terrain in primary_peering_terrains.keys():
		if terrain >= tile_set.get_terrains_count(terrain_set) \
			or terrain < -1 \
			or _is_alternative_terrain(tile_set, terrain_set, terrain):

			primary_peering_terrains.erase(terrain)

	for terrain in tile_set.get_terrains_count(terrain_set):
#		print("_is_alternative_terrain() - %s = %s" % [terrain, _is_alternative_terrain(tile_set, terrain_set, terrain)])
		if _is_alternative_terrain(tile_set, terrain_set, terrain):
			continue
		var primary_terrain : int = primary_peering_terrains.get(terrain, Autotiler.NULL_TERRAIN)
		if primary_terrain == Autotiler.NULL_TERRAIN or primary_terrain >= tile_set.get_terrains_count(terrain_set):
			primary_peering_terrains[terrain] = terrain


static func reset_primary_peering_terrains(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	terrain_set_meta[META_PRIMARY_PEERING_TERRAINS] = {} # clear or create
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	for terrain in tile_set.get_terrains_count(terrain_set):
		primary_peering_terrains[terrain] = terrain
	tile_set.changed.emit()


static func set_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int, peering_terrain : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return
	if not _is_terrain_index_valid(tile_set, terrain_set, tile_terrain, false):
		return
	if not _is_terrain_index_valid(tile_set, terrain_set, peering_terrain, false):
		return

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	primary_peering_terrains[tile_terrain] = peering_terrain
	tile_set.changed.emit()


static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	if not is_instance_valid(tile_set):
		return Autotiler.NULL_TERRAIN
	if terrain_set >= tile_set.get_terrain_sets_count():
		return Autotiler.NULL_TERRAIN
	if not _is_terrain_index_valid(tile_set, terrain_set, tile_terrain, false):
		return Autotiler.NULL_TERRAIN

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	# in case something has gone wrong (it shouldn't), default to returning the tile terrain
	return primary_peering_terrains.get(tile_terrain, tile_terrain)


static func get_primary_peering_terrains(tile_set : TileSet, terrain_set : int) -> Dictionary:
	if not is_instance_valid(tile_set):
		return {}
	if terrain_set >= tile_set.get_terrain_sets_count():
		return {}

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	return primary_peering_terrains.duplicate()



# ------------------------------------------------------
# 	PEERING TERRAIN PRIORITIES
# ------------------------------------------------------
# terrain_set_meta[META_PRIORITIES] = PackedInt32Array
# 			index = priority
#			value = terrain index

const META_PRIORITIES := "peering_terrain_priorities"
const META_PRIORITIES_USE_CUSTOM := "custom_priorities"
const META_PRIORITIES_LIST := "priorities_list"

static func _validate_priorities(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	# create if doesn't exist or invalid
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	if not terrain_set_meta.has(META_PRIORITIES) \
		or not terrain_set_meta[META_PRIORITIES].has(META_PRIORITIES_USE_CUSTOM) \
		or not terrain_set_meta[META_PRIORITIES].has(META_PRIORITIES_LIST):

		_reset_priorities(tile_set, terrain_set)
		return

	# if not using custom priorities, set the list to default
	if terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM] == false:
		terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = _get_default_priorities_list(tile_set, terrain_set)
		return

	# if using custom priorities, validate the list
	var terrains_count := tile_set.get_terrains_count(terrain_set)
	var priorities : PackedInt32Array = terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]
	for terrain in priorities.duplicate():
		if terrain < Autotiler.EMPTY_TERRAIN or terrain >= terrains_count:
			var idx := priorities.find(terrain)
			priorities.remove_at(idx)
	for terrain in terrains_count:
		if not priorities.has(terrain):
			priorities.append(terrain)

	if priorities.size() != terrains_count + 1:
		# we know all the terrains are valid,
		# so we just need to eliminate duplicates
		var priorities_set := {}
		for terrain in priorities:
			priorities_set[terrain] = true
		priorities = PackedInt32Array(priorities_set.keys())

	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = priorities


static func _reset_priorities(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	terrain_set_meta[META_PRIORITIES] = {
		META_PRIORITIES_USE_CUSTOM : false,
		META_PRIORITIES_LIST : _get_default_priorities_list(tile_set, terrain_set),
	}



static func _get_default_priorities_list(tile_set : TileSet, terrain_set : int) -> PackedInt32Array:
	var priorities := PackedInt32Array()
	var terrains_count := tile_set.get_terrains_count(terrain_set)
	for terrain in terrains_count:
		priorities.append(terrain)

	priorities.append(Autotiler.EMPTY_TERRAIN) # empty terrain is last by default
	return priorities


static func increase_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain : int) -> void:
	_alter_peering_terrain_priority(tile_set, terrain_set, terrain, 1)


static func decrease_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain : int) -> void:
	_alter_peering_terrain_priority(tile_set, terrain_set, terrain, -1)


static func _alter_peering_terrain_priority(tile_set : TileSet, terrain_set : int, terrain : int, amount : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return
	if not _is_terrain_index_valid(tile_set, terrain_set, terrain, true):
		return

	_validate_priorities(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	var priorities : PackedInt32Array = terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]

	const INVALID_IDX := -1
	var old_index := priorities.find(terrain)
	if old_index == INVALID_IDX:
		return
	var new_index = old_index + amount
	new_index = maxi(new_index, 0)
	new_index = mini(new_index, priorities.size() - 1)

	if new_index == old_index:
		return

	priorities.remove_at(old_index)
	priorities.insert(new_index, terrain)

	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = priorities
	tile_set.changed.emit()


static func set_use_custom_priorities(tile_set : TileSet, terrain_set : int, value : bool) -> void:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	_validate_priorities(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM] = value
	tile_set.changed.emit()


static func get_use_custom_priorities(tile_set : TileSet, terrain_set : int) -> bool:
	if not is_instance_valid(tile_set):
		return false
	if terrain_set >= tile_set.get_terrain_sets_count():
		return false

	_validate_priorities(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	return terrain_set_meta[META_PRIORITIES][META_PRIORITIES_USE_CUSTOM]


static func get_priorities_list(tile_set : TileSet, terrain_set : int) -> PackedInt32Array:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	_validate_priorities(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	return terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST]


static func reset_priorities_list(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return PackedInt32Array()
	if terrain_set >= tile_set.get_terrain_sets_count():
		return PackedInt32Array()

	_validate_priorities(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	terrain_set_meta[META_PRIORITIES][META_PRIORITIES_LIST] = _get_default_priorities_list(tile_set, terrain_set)




# ------------------------------------------------------
# 	PEERING TERRAIN ALTERNATIVES
# ------------------------------------------------------

const META_ALTERNATIVES := "peering_terrain_alternatives" # dictionary
const META_ALTERNATIVE_MATCH_ALL := "match_all" # bool
const META_ALTERNATIVE_MATCH_TERRAINS := "match_terrains" # PackedInt32Array


static func _validate_alternatives(tile_set : TileSet, terrain_set : int) -> void:
	if not is_instance_valid(tile_set):
		return
	if terrain_set >= tile_set.get_terrain_sets_count():
		return

	# create if doesn't exist or invalid
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	if not terrain_set_meta.has(META_ALTERNATIVES):
		terrain_set_meta[META_ALTERNATIVES] = {}

	var alternatives : Dictionary = terrain_set_meta[META_ALTERNATIVES]

	var terrain_set_alternatives := _get_alternatives_from_terrain_set(tile_set, terrain_set)

	# remove alternatives that were deleted from terrain set
	for alternative_name in alternatives.keys():
		if not terrain_set_alternatives.has(alternative_name):
#			printerr("Terrain Autotiler Error: Alternative terrain %s not found" % alternative_name)
			alternatives.erase(alternative_name)

	# add alternatives not in list
	for alternative_name in terrain_set_alternatives:
		if not alternatives.has(alternative_name):
			alternatives[alternative_name] = {}

	# validate individual alternatives
	for alternative_name in alternatives:
		var alternative_dict : Dictionary = alternatives[alternative_name]
		if not alternative_dict.has(META_ALTERNATIVE_MATCH_ALL):
			# default MATCH_ALL = true
			alternative_dict[META_ALTERNATIVE_MATCH_ALL] = true
		if not alternative_dict.has(META_ALTERNATIVE_MATCH_TERRAINS):
			# default list is empty
			alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array()

		if alternative_dict[META_ALTERNATIVE_MATCH_ALL] == true:
			alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array()
			continue

		# validate terrains list
		var terrains_list : PackedInt32Array = alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS]

		# remove duplicates
		var terrains_set := {}
		for terrain in terrains_list:
			terrains_set[terrain] = true

		# remove invalid terrains
		for terrain in terrains_set.keys():
			if terrain < -1 \
				or terrain >= tile_set.get_terrains_count(terrain_set) \
				or _is_alternative_terrain(tile_set, terrain_set, terrain):

				terrains_set.erase(terrain)

		# sort
		var new_terrains_list := PackedInt32Array(terrains_set.keys())
		new_terrains_list.sort()

		alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = PackedInt32Array(new_terrains_list)



# returns dictionary of {terrain_name : terrain}
# for terrains that begin with @
static func _get_alternatives_from_terrain_set(tile_set : TileSet, terrain_set : int) -> Dictionary:
	var alternative_terrains := {}
	for terrain in tile_set.get_terrains_count(terrain_set):
		var terrain_name := tile_set.get_terrain_name(terrain_set, terrain)
		if terrain_name.begins_with("@"):
			if alternative_terrains.has(terrain_name):
				printerr("Terrain Autotiler Error: more than one alternative terrain found with name %s" % terrain_name)
				# will use the first one it found
				continue
			alternative_terrains[terrain_name] = terrain
	return alternative_terrains


static func set_alternative_match_all(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String,
	value : bool) -> void:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, alternative_name)
	if alternative_dict.is_empty():
		return

	alternative_dict[META_ALTERNATIVE_MATCH_ALL] = value


static func get_alternative_match_all(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String) -> bool:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, alternative_name)
	if alternative_dict.is_empty():
		return true

	return alternative_dict[META_ALTERNATIVE_MATCH_ALL]


static func add_alternative_match_terrain(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String,
	terrain : int) -> void:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, alternative_name)
	if alternative_dict.is_empty():
		return

	var terrains_list : PackedInt32Array = alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS]
	terrains_list.append(terrain)
	alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = terrains_list
	tile_set.changed.emit()



static func remove_alternative_match_terrain(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String,
	terrain : int) -> void:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, alternative_name)
	if alternative_dict.is_empty():
		return

	var terrains_list : PackedInt32Array = alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS]
	var idx := terrains_list.find(terrain)
	if idx != -1:
		terrains_list.remove_at(idx)
	alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS] = terrains_list
	tile_set.changed.emit()


static func get_alternative_match_terrains(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String) -> PackedInt32Array:

	var alternative_dict := _get_alternative_dict(tile_set, terrain_set, alternative_name)
	if alternative_dict.is_empty():
		return PackedInt32Array()

	if alternative_dict[META_ALTERNATIVE_MATCH_ALL] == true:
		return _get_alternative_match_all_terrains(tile_set, terrain_set)

	return alternative_dict[META_ALTERNATIVE_MATCH_TERRAINS]


static func get_alternative_match_terrains_can_add(
	tile_set : TileSet,
	terrain_set : int,
	alternative_name : String) -> PackedInt32Array:

	var alternative_terrains := get_alternative_match_terrains(tile_set, terrain_set, alternative_name)
	var all_terrains := _get_alternative_match_all_terrains(tile_set, terrain_set)
	var terrains_to_add := PackedInt32Array()

	for terrain in all_terrains:
		if alternative_terrains.has(terrain):
			continue
		terrains_to_add.append(terrain)
	return terrains_to_add



static func _get_alternative_dict(tile_set : TileSet, terrain_set : int, alternative_name : String) -> Dictionary:
	if not is_instance_valid(tile_set):
		return {}
	if terrain_set >= tile_set.get_terrain_sets_count():
		return {}

	_validate_alternatives(tile_set, terrain_set)
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	return terrain_set_meta[META_ALTERNATIVES].get(alternative_name, {})



static func _get_alternative_match_all_terrains(
	tile_set : TileSet,
	terrain_set : int) -> PackedInt32Array:

	var terrains := PackedInt32Array()
	for terrain in tile_set.get_terrains_count(terrain_set):
		if _is_alternative_terrain(tile_set, terrain_set, terrain):
			continue
		terrains.append(terrain)
	terrains.append(Autotiler.EMPTY_TERRAIN)

	return terrains


static func _is_alternative_terrain(
	tile_set : TileSet,
	terrain_set : int,
	terrain : int) -> bool:

	var terrain_name := tile_set.get_terrain_name(terrain_set, terrain)
	return terrain_name.begins_with("@")


static func _is_terrain_index_valid(p_tile_set : TileSet, p_terrain_set : int, p_terrain_index : int, p_allow_empty : bool) -> bool:
	if p_allow_empty && p_terrain_index < -1:
		return false
	if not p_allow_empty && p_terrain_index < 0:
		return false
	if p_terrain_index >= p_tile_set.get_terrains_count(p_terrain_set):
		return false
	return true



static func get_plugin_version() -> String:
	var config := ConfigFile.new()
	config.load("res://addons/terrain_autotiler/plugin.cfg")
	return config.get_value("plugin", "version", "0.0.0")



