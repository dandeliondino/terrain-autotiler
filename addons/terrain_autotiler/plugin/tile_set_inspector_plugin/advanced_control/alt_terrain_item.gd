@tool
extends PanelContainer

const TERRAIN_NAME_TEMPLATE := "({index}) {name}"

var tile_set : TileSet
var terrain_set : int
var terrain : int

@onready var color_rect: ColorRect = %ColorRect
@onready var label: Label = %Label
@onready var remove_button: Button = %RemoveButton


func setup(p_tile_set : TileSet, p_terrain_set : int, p_terrain : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	terrain = p_terrain

	color_rect.color = tile_set.get_terrain_color(terrain_set, terrain)
	label.text = TERRAIN_NAME_TEMPLATE.format({
		"index": terrain,
		"name": tile_set.get_terrain_name(terrain_set, terrain),
	})
