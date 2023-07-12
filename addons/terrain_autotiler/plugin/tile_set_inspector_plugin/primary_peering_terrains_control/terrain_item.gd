@tool
extends Control


const TERRAIN_NAME_TEMPLATE := "({index}) {name}"

var tile_set : TileSet
var terrain_set : int
var tile_terrain : int

@onready var color_rect: ColorRect = %ColorRect
@onready var label: Label = %Label
@onready var option_button: OptionButton = %OptionButton



func setup(p_tile_set : TileSet, p_terrain_set : int, p_tile_terrain : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	tile_terrain = p_tile_terrain

	color_rect.color = tile_set.get_terrain_color(terrain_set, tile_terrain)
	label.text = TERRAIN_NAME_TEMPLATE.format({
		"index": tile_terrain,
		"name": tile_set.get_terrain_name(terrain_set, tile_terrain),
	})

	for peering_terrain in tile_set.get_terrains_count(terrain_set):
		var peering_terrain_name := tile_set.get_terrain_name(terrain_set, peering_terrain)
		if peering_terrain_name == Autotiler._IGNORE_TERRAIN_NAME:
			continue
		var peering_terrain_color := tile_set.get_terrain_color(terrain_set, peering_terrain)

		option_button.add_icon_item(
			_get_icon(peering_terrain_color),
			TERRAIN_NAME_TEMPLATE.format({
				"index": peering_terrain,
				"name": peering_terrain_name,
			}),
			peering_terrain,
		)

	var current_id := Autotiler.get_primary_peering_terrain(tile_set, terrain_set, tile_terrain)
	var current_index := option_button.get_item_index(current_id)

	option_button.select(current_index)



func _get_icon(color : Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)



func _on_option_button_item_selected(index: int) -> void:
	var peering_terrain := option_button.get_item_id(index)
	Autotiler.set_primary_peering_terrain(tile_set, terrain_set, tile_terrain, peering_terrain)
