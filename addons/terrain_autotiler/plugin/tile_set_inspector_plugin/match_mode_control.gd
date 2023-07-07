@tool
extends Control

const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

#var editor_mode_option_button : Control
var tile_set : TileSet
var terrain_set : int

@onready var option_button: OptionButton = %OptionButton


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	if not is_inside_tree():
		await tree_entered

	option_button.add_item("Minimal (47 tiles)", Autotiler.MatchMode.MINIMAL)
	option_button.add_item("Full (256 tiles)", Autotiler.MatchMode.FULL)
	option_button.set("theme_override_styles/normal", get_theme_stylebox("child_bg", "EditorProperty"))
	option_button.set("theme_override_styles/hover", get_theme_stylebox("child_bg", "EditorProperty"))
	option_button.set("theme_override_styles/pressed", get_theme_stylebox("child_bg", "EditorProperty"))
	option_button.update_minimum_size()

	var current_match_mode := Metadata.get_match_mode(tile_set, terrain_set)
	var current_match_mode_idx := option_button.get_item_index(current_match_mode)
	option_button.select(current_match_mode_idx)


func _on_option_button_item_selected(index: int) -> void:
	var match_mode := option_button.get_item_id(index)
	Metadata.set_match_mode(tile_set, terrain_set, match_mode)

