class_name Autotiler
extends RefCounted

## Description of Autotiler class.
## @tutorial:            https://github.com/dandeliondino/terrain-autotiler/wiki

signal terrains_data_updated

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


const UpdateResult := preload("res://addons/terrain_autotiler/core/update_result.gd")
const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")
const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const TilesUpdater := preload("res://addons/terrain_autotiler/core/tiles_updater.gd")

var _tile_map : TileMap
var _tile_set : TileSet
var _terrain_datas := {}

var _defer_data_updates := true
var _terrains_data_update_queued := false

var _last_update_result : UpdateResult

## Maximum size in cells than can be expanded to when setting cells via connect mode.
## To disallow any expansion, set to UPDATE_SIZE_NO_EXPANSION.
## To allow expansion to entire layer, set to UPDATE_SIZE_NO_LIMIT.
var max_update_size := Vector2i(64,64)

var cell_logging := false


func _init(p_tile_map : TileMap) -> void:
	_tile_map = p_tile_map
	_update_terrains_data()
	_tile_map.changed.connect(_verify_tile_set)



func _verify_tile_set() -> void:
	if _tile_set == _tile_map.tile_set:
		return

	if _tile_set and _tile_set.changed.is_connected(_on_tile_set_changed):
		_tile_set.changed.disconnect(_on_tile_set_changed)
	_queue_terrains_data_update()


func _get_terrains_data(terrain_set : int) -> TerrainsData:
#	print("_get_terrains_data() : terrain_set=%s; update_queued=%s" % [terrain_set, _terrains_data_update_queued])
	if _terrains_data_update_queued:
		_update_terrains_data()
	return _terrain_datas.get(terrain_set, null)


func _queue_terrains_data_update() -> void:
	if not _defer_data_updates:
		_update_terrains_data()
		return
	_terrains_data_update_queued = true


func _update_terrains_data() -> void:
	_terrains_data_update_queued = false
	_terrain_datas.clear()

	if not is_instance_valid(_tile_map):
		return

	Metadata.validate_metadata(_tile_map)

#	var start_time := Time.get_ticks_msec()

	_tile_set = _tile_map.tile_set
	if not _tile_set:
		return

	if not _tile_set.changed.is_connected(_on_tile_set_changed):
		_tile_set.changed.connect(_on_tile_set_changed)

	for terrain_set in _tile_set.get_terrain_sets_count():
		_terrain_datas[terrain_set] = TerrainsData.new(_tile_set, terrain_set)

#	var total_time := Time.get_ticks_msec() - start_time
#	print("update terrains data - %s msec" % total_time)

	terrains_data_updated.emit()



# -----------------------------------------------------------------------------
#	METADATA FUNCTIONS
# -----------------------------------------------------------------------------

## Sets the match mode for a terrain set using [enum MatchMode]. Only
## relevant for terrain sets with terrain mode set to [constant TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES].
static func set_match_mode(tile_set : TileSet, terrain_set : int, match_mode : MatchMode) -> void:
	Metadata.set_match_mode(tile_set, terrain_set, match_mode)


## See [method set_match_mode].
static func get_match_mode(tile_set : TileSet, terrain_set : int) -> MatchMode:
	return Metadata.get_match_mode(tile_set, terrain_set)


static func set_cells_locked(tile_map : TileMap, layer : int, cells : Array, locked : bool) -> void:
	Metadata.set_cells_locked(tile_map, layer, cells, locked)


static func get_locked_cells(tile_map : TileMap, layer : int) -> Array:
	return Metadata.get_locked_cells(tile_map, layer)


## Sets the primary peering terrain for a tile terrain. If not set, the primary peering terrain
## defaults to the tile terrain. This can be used, for example, to create
## tile terrains that are painted separately, but share the same primary peering terrain,
## so that they join together as if they are the same terrain when tiles are placed.
## See [url=https://github.com/dandeliondino/terrain-autotiler/wiki/Additional-Features#primary-peering-terrains]Terrain Autotiler: Additional Features[/url]
static func set_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int, peering_terrain : int) -> void:
	Metadata.set_primary_peering_terrain(tile_set, terrain_set, tile_terrain, peering_terrain)


## See [method set_primary_peering_terrain].
static func get_primary_peering_terrain(tile_set : TileSet, terrain_set : int, tile_terrain : int) -> int:
	return Metadata.get_primary_peering_terrain(tile_set, terrain_set, tile_terrain)






# -----------------------------------------------------------------------------
#	PUBLIC FUNCTIONS
# -----------------------------------------------------------------------------
# GDScript cannot coerce untyped arrays into typed arrays in function parameters (C++ can).
# If cells is defined as Array[Vector2i], then calling it with untyped Array will throw error.
# These functions should therefore accept an untyped array of cells.


## Determines whether to defer updating cached terrain data or update immediately
## when the TileSet is marked as changed. Set to `true` by default.
func set_defer_terrains_data_updates(value : bool) -> void:
	_defer_data_updates = value





func set_cells_terrain_connect(layer : int, cells : Array, terrain_set : int, terrain : int) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := TilesUpdater.new(_tile_map, layer, terrains_data, cell_logging)
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
	var tiles_updater := TilesUpdater.new(_tile_map, layer, terrains_data, cell_logging)
	var typed_cells : Array[Vector2i] = []
	typed_cells.assign(cells)
	_last_update_result = tiles_updater.paint_single_terrain(
		typed_cells,
		terrain,
		false,
		max_update_size,
	)


func set_cells_terrains(layer : int, cells_terrains : Dictionary, terrain_set : int, update_neighbors : bool) -> void:
	if not is_instance_valid(_tile_map):
		printerr("TileMap is not a valid instance")
		return
	var terrains_data := _get_terrains_data(terrain_set)
	var tiles_updater := TilesUpdater.new(_tile_map, layer, terrains_data, cell_logging)
	_last_update_result = tiles_updater.paint_multiple_terrains(
		cells_terrains,
		update_neighbors,
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
	var tiles_updater := TilesUpdater.new(_tile_map, layer, terrains_data, cell_logging)
	_last_update_result = tiles_updater.update_terrain_tiles(EMPTY_RECT)


func _on_tile_set_changed() -> void:
	_queue_terrains_data_update()









