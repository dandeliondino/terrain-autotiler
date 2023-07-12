@tool
extends Object




const META_NAME := "terrain_autotiler"
const META_VERSION := "version"

# TileMap
const META_LAYERS := "layers"
const META_LOCKED_CELLS := "locked_cells"

# TileSet
const META_TERRAIN_SETS := "terrain_sets"
const META_MATCH_MODE := "match_mode"
const META_PRIMARY_PEERING_TERRAINS := "primary_peering_terrains"




static func validate_metadata(tile_map : TileMap) -> void:
	if not tile_map:
		return
	_validate_tile_map_metadata(tile_map)

	var tile_set := tile_map.tile_set
	if not tile_set:
		return
	validate_tile_set_metadata(tile_set)


static func _validate_tile_map_metadata(tile_map : TileMap) -> void:
	if not tile_map.has_meta(META_NAME):
		tile_map.set_meta(META_NAME, {})
	var meta : Dictionary = tile_map.get_meta(META_NAME)
	if not meta.has(META_VERSION):
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



static func validate_tile_set_metadata(tile_set : TileSet) -> void:
	if not tile_set.has_meta(META_NAME):
		tile_set.set_meta(META_NAME, {})
	var meta : Dictionary = tile_set.get_meta(META_NAME)
	if not meta.has(META_VERSION):
		meta[META_VERSION] = get_plugin_version()
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
		terrain_set_meta[META_PRIMARY_PEERING_TERRAINS] = {}

	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]

	for terrain in primary_peering_terrains:
		if terrain >= tile_set.get_terrains_count(terrain_set):
			primary_peering_terrains.erase(terrain)

	for terrain in tile_set.get_terrains_count(terrain_set):
		if tile_set.get_terrain_name(terrain_set, terrain) == Autotiler._IGNORE_TERRAIN_NAME:
			continue
		var primary_terrain : int = primary_peering_terrains.get(terrain, Autotiler.NULL_TERRAIN)
		if primary_terrain == Autotiler.NULL_TERRAIN or primary_terrain >= tile_set.get_terrains_count(terrain_set):
			primary_peering_terrains[terrain] = terrain


static func set_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int, peering_terrain : int) -> void:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	primary_peering_terrains[tile_terrain] = peering_terrain
	tile_set.changed.emit()


static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	var terrain_set_meta := _get_terrain_set_meta(tile_set, terrain_set)
	_validate_primary_peering_terrains(terrain_set_meta, tile_set, terrain_set)
	var primary_peering_terrains : Dictionary = terrain_set_meta[META_PRIMARY_PEERING_TERRAINS]
	# in case something has gone wrong (it shouldn't), default to returning the tile terrain
	return primary_peering_terrains.get(tile_terrain, tile_terrain)




static func get_plugin_version() -> String:
	var config := ConfigFile.new()
	config.load("res://addons/terrain_autotiler/plugin.cfg")
	return config.get_value("plugin", "version", "0.0.0")
