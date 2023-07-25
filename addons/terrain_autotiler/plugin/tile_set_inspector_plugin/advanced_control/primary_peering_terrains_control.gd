@tool
extends Control

const TerrainItem := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/terrain_item.gd")
const TerrainItemScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/terrain_item.tscn")
const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

var tile_set : TileSet
var terrain_set : int

@onready var terrain_items_container: VBoxContainer = %TerrainItemsContainer

func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	update()


func update() -> void:
	for child in terrain_items_container.get_children():
		child.queue_free()

	for tile_terrain in Metadata.get_primary_peering_terrains(tile_set, terrain_set):
		var tile_terrain_name := tile_set.get_terrain_name(terrain_set, tile_terrain)
		var terrain_item : TerrainItem = TerrainItemScene.instantiate()
		terrain_items_container.add_child(terrain_item)
		terrain_item.setup(tile_set, terrain_set, tile_terrain)




