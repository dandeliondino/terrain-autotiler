@tool
extends RefCounted

const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")

var tile_terrain := Autotiler.NULL_TERRAIN
var _peering_bits : Array
var _bit_peering_terrains : Dictionary
var _peering_terrains_set : Dictionary

var _tiles := []
var _max_probability := 0.0
var _tiles_accum_probabilities := {}


func _init(p_peering_bits : Array) -> void:
	_peering_bits = p_peering_bits


func create_from_tile_data(p_tile_data : TileData) -> TerrainPattern:
	tile_terrain = p_tile_data.terrain
	for bit in get_peering_bits():
		set_bit_peering_terrain(bit, p_tile_data.get_terrain_peering_bit(bit))
	return self


func create_empty_pattern() -> TerrainPattern:
	tile_terrain = Autotiler.EMPTY_TERRAIN
	for bit in get_peering_bits():
		set_bit_peering_terrain(bit, Autotiler.EMPTY_TERRAIN)
	return self


func get_peering_bits() -> Array:
	return _peering_bits


# The pattern lookup iterator is formed after all patterns are created and
# tiles are assigned. Therefore, an ID is used temporarily for lookups to ensure multiple
# tiles with the same pattern do not result in duplicate patterns.
# This is more efficient than
# iterating through all patterns to see if bits match (and using the
# recursive dictionary lookup is more efficient than using this id).
# Patterns do not currently cache their id's as they are only needed one time.
# TODO: see about creating the dictionary lookup on the fly to avoid the need for this temporary method
func get_id() -> StringName:
	var sorted_bits := _peering_bits.duplicate()
	sorted_bits.sort()
	var bit_strings := []
	for bit in sorted_bits:
		var bit_terrain := get_bit_peering_terrain(bit)
		var text := str(bit) + ":" + str(bit_terrain)
		bit_strings.append(text)
	return str(tile_terrain) + "::" + "::".join(bit_strings)


func set_bit_peering_terrain(p_bit : TileSet.CellNeighbor, p_peering_terrain : int) -> void:
	_bit_peering_terrains[p_bit] = p_peering_terrain
	if p_peering_terrain != Autotiler.NULL_TERRAIN:
		_peering_terrains_set[p_peering_terrain] = true


func get_bit_peering_terrain(p_bit : TileSet.CellNeighbor) -> int:
	return _bit_peering_terrains.get(p_bit, Autotiler.NULL_TERRAIN)


func get_bit_peering_terrains_dict() -> Dictionary:
	return _bit_peering_terrains.duplicate()


func get_peering_terrains() -> Array:
	return _peering_terrains_set.keys()


func has_peering_terrain(p_peering_terrain : int) -> bool:
	return _peering_terrains_set.has(p_peering_terrain)


func add_tile(p_tile_location : TileLocation) -> void:
	_tiles.append(p_tile_location)


func get_first_tile() -> TileLocation:
	if _tiles.size() == 0:
		return null
	return _tiles[0]


func get_tile() -> TileLocation:
	if _tiles.size() == 0:
		return null
	elif _tiles.size() == 1:
		return _tiles[0]

	if _tiles_accum_probabilities.is_empty():
		_setup_tile_probabilities()

	var r := randf_range(0.0, _max_probability)
	for tile in _tiles_accum_probabilities:
		if _tiles_accum_probabilities[tile] >= r:
			return tile

	return null


func _setup_tile_probabilities() -> void:
	for tile in _tiles:
		_max_probability += tile.probability
		_tiles_accum_probabilities[tile] = _max_probability
