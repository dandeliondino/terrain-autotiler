@tool
extends Control


@onready var button: Button = %Button

var tile_set : TileSet
var terrain_set : int

var terrains_control : Control


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	if not is_inside_tree():
		await tree_entered

	button.icon = get_theme_icon("Add", "EditorIcons")
	button.set("theme_override_styles/normal", get_theme_stylebox("normal", "InspectorActionButton"))
	button.set("theme_override_styles/hover", get_theme_stylebox("hover", "InspectorActionButton"))
	button.set("theme_override_styles/pressed", get_theme_stylebox("pressed", "InspectorActionButton"))
	button.set("theme_override_styles/disabled", get_theme_stylebox("disabled", "InspectorActionButton"))


	var terrains_children := get_parent_control().get_child(get_index() - 1).get_children()
	if terrains_children.size():
		terrains_control = terrains_children[0]
		terrains_control.visibility_changed.connect(_update_visibility)
		_update_visibility()


func _update_visibility() -> void:
	visible = terrains_control.is_visible_in_tree()


func _on_button_pressed() -> void:
	tile_set.add_terrain(terrain_set)
	var idx := tile_set.get_terrains_count(terrain_set) - 1
	tile_set.set_terrain_name(terrain_set, idx, Autotiler._IGNORE_TERRAIN_NAME)
	tile_set.set_terrain_color(terrain_set, idx, Color.LIGHT_SKY_BLUE)
