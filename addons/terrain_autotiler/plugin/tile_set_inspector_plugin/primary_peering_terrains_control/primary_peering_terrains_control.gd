@tool
extends Control

const TerrainItem := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/primary_peering_terrains_control/terrain_item.gd")
const TerrainItemScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/primary_peering_terrains_control/terrain_item.tscn")
const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

var tile_set : TileSet
var terrain_set : int

@onready var terrain_items_container: VBoxContainer = %TerrainItemsContainer

func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	Metadata.validate_tile_set_metadata(tile_set)

	for tile_terrain in tile_set.get_terrains_count(terrain_set):
		var tile_terrain_name := tile_set.get_terrain_name(terrain_set, tile_terrain)
		if tile_terrain_name == Autotiler._IGNORE_TERRAIN_NAME:
			continue
		var terrain_item : TerrainItem = TerrainItemScene.instantiate()
		terrain_items_container.add_child(terrain_item)
		terrain_item.setup(tile_set, terrain_set, tile_terrain)

