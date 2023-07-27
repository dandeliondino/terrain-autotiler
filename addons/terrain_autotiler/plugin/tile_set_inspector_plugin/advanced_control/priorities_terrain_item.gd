@tool
extends PanelContainer

const TERRAIN_NAME_TEMPLATE := "({index}) {name}"

var tile_set : TileSet
var terrain_set : int
var terrain : int

@onready var up_button: Button = %UpButton
@onready var down_button: Button = %DownButton
@onready var color_rect: ColorRect = %ColorRect
@onready var label: Label = %Label


func setup(
	p_tile_set : TileSet,
	p_terrain_set : int,
	p_terrain : int,
	p_can_move_up : bool,
	p_can_move_down : bool) -> void:

	tile_set = p_tile_set
	terrain_set = p_terrain_set
	terrain = p_terrain

	up_button.disabled = not p_can_move_up
	down_button.disabled = not p_can_move_down

	var terrain_name : String
	var terrain_color : Color

	if terrain == Autotiler.EMPTY_TERRAIN:
		terrain_name = "<EMPTY>"
		terrain_color = Color.DIM_GRAY
	else:
		terrain_name = tile_set.get_terrain_name(terrain_set, terrain)
		terrain_color = tile_set.get_terrain_color(terrain_set, terrain)

	color_rect.color = terrain_color
	label.text = TERRAIN_NAME_TEMPLATE.format({
		"index": terrain,
		"name": terrain_name,
	})

	set("theme_override_styles/panel", get_theme_stylebox("child_bg", "EditorProperty"))
