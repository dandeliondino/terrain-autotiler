@tool
extends RefCounted

var source_id := -1
var atlas_coords := Vector2i(-1,-1)
var alternative_tile_id := -1
var probability := 1.0


func _init(	p_source_id := -1,
			p_atlas_coords := Vector2i(-1,-1),
			p_alternative_tile_id := -1,
			p_probability := 1.0) -> void:

	source_id = p_source_id
	atlas_coords = p_atlas_coords
	alternative_tile_id = p_alternative_tile_id
	probability = p_probability


func is_empty() -> bool:
	if source_id < 0:
		return true
	if atlas_coords < Vector2i.ZERO:
		return true
	if alternative_tile_id < 0:
		return true
	return false

