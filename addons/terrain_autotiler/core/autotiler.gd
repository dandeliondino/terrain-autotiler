@tool
class_name Autotiler
extends RefCounted

## The public class of the Terrain Autotiler plugin.
## Provides terrain tile placement and update functions
## and the ability to change plugin-specific TileMap and TileSet metadata.
##
## Instantiate a new [b]Autotiler[/b] with a [TileMap],
## and then use it to call terrain placement and update functions including
## [method set_cells_terrain_connect], [method set_cells_terrain_path],
## [method set_cells_terrains], and [method update_terrain_tiles].
## [codeblock]
##     var autotiler = Autotiler.new($MyTileMap)
##     autotiler.set_cells_terrain_connect(0, [Vector2i(0,0)], 0, 1)
## [/codeblock]
## Immediately after a new Autotiler object is instantiated,
## it loads all the terrains and tiles from the [TileSet] and caches
## calculations for its matching algorithm.
## When calling multiple terrain placement or update functions,
## it is therefore most performant to reuse the same Autotiler. See also: [method update_terrains_data].
## [br][br]
## Static functions alter a TileMap or TileSet's plugin-specific Metadata and can be called directly.
## [codeblock]
##     Autotiler.set_cells_locked($MyTileMap, 0, [Vector2i(0,0)], true)
## [/codeblock]
##
## @tutorial(Terrain Autotiler Readme):            https://github.com/dandeliondino/terrain-autotiler


const PLUGIN_NAME := "TERRAIN_AUTOTILER"
const PLUGIN_CONFIG_PATH := "res://addons/terrain_autotiler/plugin.cfg"

const IGNORE_TERRAIN_NAME := "@ignore"

const UPDATE_SIZE_NO_EXPANSION := Vector2i.ZERO
const UPDATE_SIZE_NO_LIMIT := Vector2i(-1, -1)

const NULL_TERRAIN_SET := -1
const NULL_TERRAIN := -99
const EMPTY_TERRAIN := -1
const EMPTY_RECT := Rect2i()

enum MatchMode {
	MINIMAL = 0,
	FULL = 1,
}

const DEFAULT_MATCH_MODE := MatchMode.MINIMAL


const _UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const _Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")
const _CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")
const _TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const _TilesUpdater := preload("res://addons/terrain_autotiler/core/tiles_updater.gd")

var _tile_map : TileMap
var _tile_set : TileSet
var _terrain_datas := {}

var _defer_data_updates := true
var _terrains_data_update_queued := false

var _last_update_result : _UpdateResult

## For updates in connect mode, determines the maximum size in cells an update can expand to when needed.
## If smaller than the original update size, no expansion will occur.
## Relevant for updates called with [method set_cells_terrain_connect] and [method set_cells_terrains] (when [param connect] is set to [code]true[/code]).
## [br][br]
## [constant UPDATE_SIZE_NO_EXPANSION] disables any expansion.
## [br][br]
## [constant UPDATE_SIZE_NO_LIMIT] allows expansion to the entire layer.
var max_update_size := Vector2i(64,64)

var _cell_logging := false


func _init(p_tile_map : TileMap) -> void:
	_tile_map = p_tile_map
	update_terrains_data()
	_tile_map.changed.connect(_verify_tile_set)



func _verify_tile_set() -> void:
	if _tile_set == _tile_map.tile_set:
		return

	if _tile_set and _tile_set.changed.is_connected(_on_tile_set_changed):
		_tile_set.changed.disconnect(_on_tile_set_changed)
	_queue_terrains_data_update()


func _get_terrains_data(terrain_set : int) -> _TerrainsData:
#	print("_get_terrains_data() : terrain_set=%s; update_queued=%s" % [terrain_set, _terrains_data_update_queued])
	if _terrains_data_update_queued:
		update_terrains_data()
	return _terrain_datas.get(terrain_set, null)


# Determines whether to defer updating cached terrain data or update immediately
# when the TileSet is marked as changed. Set to `true` by default.
func _set_defer_terrains_data_updates(value : bool) -> void:
	_defer_data_updates = value


func _queue_terrains_data_update() -> void:
	if not _defer_data_updates:
		update_terrains_data()
		return
	_terrains_data_update_queued = true


## The terrains data cache is automatically queued for update
## whenever [signal TileSet.changed] is emitted, but the update
## does not occur until the next terrain tile placement function is called.
## Calling [method update_terrains_data] will force an immediate update of the cached data
## and clear the update queue.
func update_terrains_data() -> void:
	_terrains_data_update_queued = false
	_terrain_datas.clear()

	if not is_instance_valid(_tile_map):
		return

	_Metadata.validate_metadata(_tile_map)

#	var start_time := Time.get_ticks_msec()

	_tile_set = _tile_map.tile_set
	if not _tile_set:
		return

	if not _tile_set.changed.is_connected(_on_tile_set_changed):
		_tile_set.changed.connect(_on_tile_set_changed)

	for terrain_set in _tile_set.get_terrain_sets_count():
		_terrain_datas[terrain_set] = _TerrainsData.new(_tile_set, terrain_set)

#	var total_time := Time.get_ticks_msec() - start_time
#	print("update terrains data - %s msec" % total_time)




# -----------------------------------------------------------------------------
#	METADATA FUNCTIONS
# -----------------------------------------------------------------------------

## Sets a terrain set's [enum MatchMode]. Only
## relevant for terrain sets with terrain mode set to [constant TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES].
static func set_match_mode(tile_set : TileSet, terrain_set : int, match_mode : MatchMode) -> void:
	# Metadata will emit tile_set.changed to queue update for any relevant Autotiler instance
	_Metadata.set_match_mode(tile_set, terrain_set, match_mode)


## See [method set_match_mode].
static func get_match_mode(tile_set : TileSet, terrain_set : int) -> MatchMode:
	return _Metadata.get_match_mode(tile_set, terrain_set)

##
static func set_cells_locked(tile_map : TileMap, layer : int, cells : Array, locked : bool) -> void:
	_Metadata.set_cells_locked(tile_map, layer, cells, locked)


static func get_locked_cells(tile_map : TileMap, layer : int) -> Array:
	return _Metadata.get_locked_cells(tile_map, layer)


## Sets the primary peering terrain for a tile terrain. If not set, the primary peering terrain
## defaults to the tile terrain. This can be used, for example, to create
## tile terrains that are painted separately, but share the same primary peering terrain,
## so that they join together as if they are the same terrain when tiles are placed.
## See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features#primary-peering-terrains]Terrain Autotiler: Additional Features[/url]
static func set_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int, peering_terrain : int) -> void:
	# Metadata will emit tile_set.changed to queue update for any relevant Autotiler instance
	_Metadata.set_primary_peering_terrain(tile_set, terrain_set, tile_terrain, peering_terrain)


## See [method set_primary_peering_terrain].
static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	return _Metadata.get_primary_peering_terrain(tile_set, terrain_set, tile_terrain)






# -----------------------------------------------------------------------------
#	TERRAIN TILE PLACEMENT FUNCTIONS
# -----------------------------------------------------------------------------
# GDScript cannot coerce untyped arrays into typed arrays in function parameters (C++ can).
# If cells is defined as Array[Vector2i], then calling it with untyped Array will throw error.
# These functions should therefore accept any array of cells.




## Updates all the cells in the [param cells] coordinates array
## so that they use the given [param terrain] for the given [param terrain_set].
## [br][br]
## [param cells] can be an untyped Array or an Array[Vector2i]
## [br][br]
## Equivalent of [method TileMap.set_cells_terrain_connect],
## except the parameter [param ignore_empty_terrains] is deprecated.
## Peering bits that are empty (set to -1) will always be used to match to empty cells
## or other empty peering bits.
## [br][br]
## To specify peering bits to be ignored, use an [b]@ignore[/b] terrain.
## For instructions on using [b]@ignore[/b] terrains,
## see [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler: Additional Features[/url].
func set_cells_terrain_connect(layer : int, cells : Array, terrain_set : int, terrain : int) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := _TilesUpdater.new(_tile_map, layer, terrains_data, _cell_logging)
	var typed_cells : Array[Vector2i] = []
	typed_cells.assign(cells)
	_last_update_result = tiles_updater.paint_single_terrain(
		typed_cells,
		terrain,
		true,
		max_update_size,
	)


func set_cells_terrain_path(layer : int, cells : Array, terrain_set : int, terrain : int) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := _TilesUpdater.new(_tile_map, layer, terrains_data, _cell_logging)
	var typed_cells : Array[Vector2i] = []
	typed_cells.assign(cells)
	_last_update_result = tiles_updater.paint_single_terrain(
		typed_cells,
		terrain,
		false,
		max_update_size,
	)


func set_cells_terrains(layer : int, cells_terrains : Dictionary, terrain_set : int, connect : bool) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := _TilesUpdater.new(_tile_map, layer, terrains_data, _cell_logging)
	_last_update_result = tiles_updater.paint_multiple_terrains(
		cells_terrains,
		connect,
		max_update_size,
	)


func update_terrain_tiles(layer : int, terrain_set := NULL_TERRAIN_SET) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	if terrain_set != NULL_TERRAIN_SET:
		_update_terrain_set_tiles(layer, terrain_set)
		return

	for terrain_set_idx in _tile_map.tile_set.get_terrain_sets_count():
		_update_terrain_set_tiles(layer, terrain_set_idx)


func _update_terrain_set_tiles(layer : int, terrain_set : int) -> void:
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := _TilesUpdater.new(_tile_map, layer, terrains_data, _cell_logging)
	_last_update_result = tiles_updater.update_terrain_tiles(EMPTY_RECT)


func _on_tile_set_changed() -> void:
	_queue_terrains_data_update()









