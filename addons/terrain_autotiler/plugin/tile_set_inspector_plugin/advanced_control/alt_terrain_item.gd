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

	var peering_terrain_name : String
	var peering_terrain_color : Color

	if terrain == Autotiler.EMPTY_TERRAIN:
		peering_terrain_name = "<EMPTY>"
		peering_terrain_color = Color.DIM_GRAY
	else:
		peering_terrain_name = tile_set.get_terrain_name(terrain_set, terrain)
		peering_terrain_color = tile_set.get_terrain_color(terrain_set, terrain)

	color_rect.color = peering_terrain_color
	label.text = TERRAIN_NAME_TEMPLATE.format({
		"index": terrain,
		"name": peering_terrain_name,
	})

	set("theme_override_styles/panel", get_theme_stylebox("child_bg", "EditorProperty"))
