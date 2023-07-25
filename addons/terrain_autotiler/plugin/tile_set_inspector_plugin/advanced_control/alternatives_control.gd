@tool
extends Control

const AlternativeItem := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/alternative_item.gd")
const AlternativeItemScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/alternative_item.tscn")

const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

var tile_set : TileSet
var terrain_set : int

@onready var alternatives_container: VBoxContainer = %AlternativesContainer


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	update()


func update() -> void:
	for child in alternatives_container.get_children():
		child.queue_free()

	var alternatives_list := Metadata.get_alternatives_list(tile_set, terrain_set)
	for alt_name in alternatives_list:
		var terrain := get_terrain_from_name(alt_name)
		var alternative_item : AlternativeItem = AlternativeItemScene.instantiate()
		alternatives_container.add_child(alternative_item)
		alternative_item.setup(tile_set, terrain_set, terrain, alt_name)




func get_terrain_from_name(p_terrain_name) -> int:
	for terrain in tile_set.get_terrains_count(terrain_set):
		if tile_set.get_terrain_name(terrain_set, terrain) == p_terrain_name:
			return terrain
	return Autotiler.NULL_TERRAIN
