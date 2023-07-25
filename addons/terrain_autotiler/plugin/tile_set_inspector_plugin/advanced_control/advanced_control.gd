@tool
extends Control


var tile_set : TileSet
var terrain_set : int

@onready var primary_peering_terrains_control: VBoxContainer = %PrimaryPeeringTerrainsControl


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	primary_peering_terrains_control.setup(tile_set, terrain_set)
