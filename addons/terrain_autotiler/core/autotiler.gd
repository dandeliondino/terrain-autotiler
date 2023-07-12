@tool
class_name Autotiler
extends RefCounted

## The public class of the Terrain Autotiler plugin.
## Provides terrain tile placement and update functions
## and the ability to change plugin-specific Metadata.
##
## Initialize a new [b]Autotiler[/b] with a [TileMap],
## and then use it to access functions including
## [method set_cells_terrain_connect], [method set_cells_terrain_path],
## [method set_cells_terrains], and [method update_terrain_tiles].
## [codeblock]
##     var autotiler = Autotiler.new($TileMap)
##     autotiler.set_cells_terrain_connect(0, [Vector2i(0,0)], 0, 1)
## [/codeblock]
## The [b]Autotiler[/b] instance caches terrain data and calculations,
## so it is recommended to reuse it for the same TileMap.
## See [method update_terrains_data] for details.
## [br][br]
## However, static functions that change a TileMap or TileSet's plugin-specific Metadata and can be called directly.
## [codeblock]
##     Autotiler.set_cells_locked($TileMap, 0, [Vector2i(0,0)], true)
## [/codeblock]
##
## @tutorial(Readme):            https://github.com/dandeliondino/terrain-autotiler
## @tutorial(Wiki):            https://github.com/dandeliondino/terrain-autotiler/wiki





const _PLUGIN_NAME := "TERRAIN_AUTOTILER"
const _PLUGIN_CONFIG_PATH := "res://addons/terrain_autotiler/plugin.cfg"

const _IGNORE_TERRAIN_NAME := "@ignore"

const UPDATE_SIZE_NO_EXPANSION := Vector2i.ZERO
const UPDATE_SIZE_NO_LIMIT := Vector2i(-1, -1)

const NULL_TERRAIN_SET := -1
const NULL_TERRAIN := -99
const EMPTY_TERRAIN := -1
const _EMPTY_RECT := Rect2i()

enum MatchMode {
	MINIMAL = 0,
	FULL = 1,
}

const _DEFAULT_MATCH_MODE := MatchMode.MINIMAL


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
## Relevant for updates called with [method set_cells_terrain_connect] or [method set_cells_terrains] with [param connect] set to [code]true[/code].
## [br][br]
## [constant UPDATE_SIZE_NO_EXPANSION] disables any expansion.
## [br]
## [constant UPDATE_SIZE_NO_LIMIT] allows expansion to the entire layer.
## [br][br]
## Connect mode always begins by updating only
## up to a distance of 2 cells away from the provided coordinates.
## But, in order for all tiles to match, sometimes cells further away need to be changed.
## In these cases, the update will expand according to the [member maximum_update_size].
## [codeblock]
##    var autotiler = Autotiler.new($TileMap)
##
##    # only update the provided cells
##    autotiler.set_cells_terrain_path(0, [Vector2i(1,1)], 0, 1)
##
##    # update the surrounding cells but no others
##    autotiler.maximum_update_size = Autotiler.UPDATE_SIZE_NO_EXPANSION
##    autotiler.set_cells_terrain_connect(0, [Vector2i(1,1)], 0, 1)
##
##    # update the entire layer if necessary
##    autotiler.maximum_update_size = Autotiler.UPDATE_SIZE_NO_LIMIT
##    autotiler.set_cells_terrain_connect(0, [Vector2i(1,1)], 0, 1)
##
##    # update up to a maximum region of 32 x 32 cells
##    autotiler.maximum_update_size = Vector2i(32,32)
##    autotiler.set_cells_terrain_connect(0, [Vector2i(1,1)], 0, 1)
## [/codeblock]
## Updating the entire layer ([member UPDATE_SIZE_NO_LIMIT])
## will yield the most accurate and consistent results, but
## will be slow if the TileMap is large.
## (Layer-wide updates can also be called separately with [method update_terrain_tiles].)
## [br][br]
## The situation that leads to expanded updates can be avoided entirely by ensuring full sets of transition tiles between terrains,
## or with careful terrain placement.
## For more discussion, see the Github issue
## [url=https://github.com/dandeliondino/terrain-autotiler/issues/1]Handling Local Non-Matching Tiles when Matching Solutions May Exist[/url].
var maximum_update_size := Vector2i(64,64)

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


## Manually reloads the [TileSet] terrains data and updates calculations
## for the matching algorithm.
## This cached data is automatically queued for update
## whenever [signal TileSet.changed] is emitted, and then updated when
## the next terrain tile placement function is called.
## [b]update_terrains_data()[/b] instead forces an immediate update and clears the queue.
## [br][br]
## [b]This method is not recommended for most cases.[/b]
## It is only useful if [TileSet], [TileSetAtlasSource] or
## [TileData] objects are being changed at runtime.
## If they are, manually timing the update can prevent lag when the next
## [method set_cells_terrain_connect] or similar method is called.
## It can also ensure that a change that does not emit [signal TileSet.changed]
## is not get missed.
## [br][br]
## In contrast, [TileMap] data, including placed tiles and [b]Terrain Autotiler's[/b] locked cells,
## are fully reloaded for every update and do not require special management.
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

## [i]Static.[/i] Sets a Corners and Sides terrain set's match mode. Only
## relevant for terrain sets with terrain mode set to [constant TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES].
## [br][br]
## [member MatchMode.MINIMAL] is the default mode. It is the same as the base Corners and Sides mode in Godot 4 and 3x3 Minimal mode in Godot 3. [b]A full set requires 47 tiles.[/b]
## [br][br]
## [member MatchMode.FULL] matches diagonal tiles individually. It is the same as 3x3 mode in Godot 3. [b]A full set requires 256 tiles.[/b]
## [br][br]
## See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler Wiki: Additional Features[/url].
static func set_match_mode(tile_set : TileSet, terrain_set : int, match_mode : MatchMode) -> void:
	# Metadata will emit tile_set.changed to queue update for any relevant Autotiler instance
	_Metadata.set_match_mode(tile_set, terrain_set, match_mode)


## [i]Static.[/i] See [method set_match_mode].
static func get_match_mode(tile_set : TileSet, terrain_set : int) -> MatchMode:
	return _Metadata.get_match_mode(tile_set, terrain_set)

## [i]Static.[/i]
## Locks or unlocks cells in the provided [param cells] array of [Vector2i] coordinates
## according to the [param locked] value.
## See also [method get_locked_cells].
## [br][br]
## A locked cell retains its current tile during [b]Autotiler[/b] terrain placement or update functions.
## This can be useful for preserving the tiles chosen by [method set_cells_terrain_path].
## [codeblock]
##    # draw a path and lock the cells
##    var path_layer = 0
##    var path_cells = [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)]
##    var autotiler = Autotiler.new($TileMap)
##    autotiler.set_cells_terrain_path(path_layer, path_cells, 0, 0)
##    Autotiler.set_cells_locked($TileMap, path_layer, path_cells, true)
##
##    # update all other terrain tiles on the layer without changing path tiles
##    autotiler.update_terrain_tiles(path_layer)
##
##    # unlock the path cells and connect them to their neighbors
##    Autotiler.set_cells_locked($TileMap, path_layer, path_cells, false)
##    autotiler.update_terrain_tiles(path_layer)
## [/codeblock]
## For more information on locked cells, see [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler Wiki: Additional Features[/url].
static func set_cells_locked(tile_map : TileMap, layer : int, cells : Array, locked : bool) -> void:
	_Metadata.set_cells_locked(tile_map, layer, cells, locked)

## [i]Static.[/i]
## Returns an [Array] of [Vector2i] coordinates marked as locked on the provided [param tile_map] and [param layer]. See [method set_cells_locked].
static func get_locked_cells(tile_map : TileMap, layer : int) -> Array:
	return _Metadata.get_locked_cells(tile_map, layer)


## [i]Static.[/i] Sets the primary peering terrain for a tile terrain. If not set, the primary peering terrain
## defaults to the tile terrain. This can be used, for example, to create
## tile terrains that are painted separately, but share the same primary peering terrain,
## so that they join together as if they are the same terrain when tiles are placed.
## [br][br]See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler Wiki: Additional Features[/url].
static func set_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int, peering_terrain : int) -> void:
	# Metadata will emit tile_set.changed to queue update for any relevant Autotiler instance
	_Metadata.set_primary_peering_terrain(tile_set, terrain_set, tile_terrain, peering_terrain)


## [i]Static.[/i] See [method set_primary_peering_terrain].
static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	return _Metadata.get_primary_peering_terrain(tile_set, terrain_set, tile_terrain)






# -----------------------------------------------------------------------------
#	TERRAIN TILE PLACEMENT FUNCTIONS
# -----------------------------------------------------------------------------
# GDScript cannot coerce untyped arrays into typed arrays in function parameters (C++ can).
# If cells is defined as Array[Vector2i], then calling it with untyped Array will throw error.
# These functions should therefore accept any array of cells.




## Updates all the cells in the [param cells] array of [Vector2i] coordinates with tiles
## of the provided [param terrain_set] and [param terrain]. Updates surrounding cells
## of the same [param terrain_set], and the update may be expanded up to the [member maximum_update_size].
## See [member maximum_update_size] for details.
## [br][br]
## Equivalent of [method TileMap.set_cells_terrain_connect],
## except the parameter [param ignore_empty_terrains] is deprecated.
## Peering bits that are empty (set to [code]-1[/code]) will always be used to match to empty cells
## or other empty peering bits.
## To specify peering bits to be ignored, use an [b]@ignore[/b] terrain.
## See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler: Additional Features[/url].
## [br][br]
## See also [method set_cells_terrain_path] and [method set_cells_terrains].
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
		maximum_update_size,
	)

## Updates all the cells in the [param cells] array of [Vector2i] coordinates with tiles
## of the provided [param terrain_set] and [param terrain]. Does not update any surrounding cells.
## [br][br]
## Use [method Autotiler.set_cells_locked] to prevent future updates from connecting
## them to their neighbors.
## [br][br]
## Equivalent of [method TileMap.set_cells_terrain_path],
## except the parameter [param ignore_empty_terrains] is deprecated.
## Peering bits that are empty (set to [code]-1[/code]) will always be used to match to empty cells
## or other empty peering bits.
## To specify peering bits to be ignored, use an [b]@ignore[/b] terrain.
## See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features]Terrain Autotiler: Additional Features[/url].
## [br][br]
## See also [method set_cells_terrain_connect] and [method set_cells_terrains].
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
		maximum_update_size,
	)

## Updates cells according to the provided [param cells_terrains] dictionary
## with [Vector2i] [b]coordinates[/b] as keys and [int] [b]terrains[/b] as values.
## Faster than updating terrains individually with multiple calls to
## [method set_cells_terrain_connect]. Can be used to update
## large regions or procedurally generated maps.
## To update all the terrain tiles on a layer [i]without[/i] assigning new terrains,
## use [method update_terrain_tiles].
## [codeblock]
##    var cells_terrains = {
##        Vector2i(1,1): 1,
##        Vector2i(1,2): 0,
##        Vector2i(1,3): 1,
##        Vector2i(1,4): 2,
##    }
##
##    var autotiler = Autotiler.new($TileMap)
##    autotiler.set_cells_terrains(0, cells_terrains, 0, true)
## [/codeblock]
## If [param connect] is [code]true[/code], cells will be connected
## to surrounding cells of the same [param terrain_set], and the update may be
## expanded up to the [member maximum_update_size].
## See [method set_cells_terrain_connect].
## [br][br]
## If [param connect] is [code]false[/code], no surrounding cells will be updated.
## See [method set_cells_terrain_path].
func set_cells_terrains(layer : int, cells_terrains : Dictionary, terrain_set : int, connect : bool) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := _TilesUpdater.new(_tile_map, layer, terrains_data, _cell_logging)
	_last_update_result = tiles_updater.paint_multiple_terrains(
		cells_terrains,
		connect,
		maximum_update_size,
	)



## Recalculates and updates all the existing terrain tiles on a given [param layer].
## If [param terrain_set] is the index of a valid terrain set,
## only tiles belonging to that terrain set will be updated.
## Otherwise, tiles of all terrain sets will be updated.
## By default, [param terrain_set] is set to [member NULL_TERRAIN_SET].
## [br][br]
## To assign [i]new[/i] terrains to an entire layer, use [method set_cells_terrains].
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
	_last_update_result = tiles_updater.update_terrain_tiles(_EMPTY_RECT)


func _on_tile_set_changed() -> void:
	_queue_terrains_data_update()









