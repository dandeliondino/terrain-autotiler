@tool
extends Control


var tile_set : TileSet
var terrain_set : int

@onready var primary_peering_terrains_control: VBoxContainer = %PrimaryPeeringTerrainsControl
@onready var priorities_control: VBoxContainer = %PrioritiesControl
@onready var alternatives_control: VBoxContainer = %AlternativesControl


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	tile_set.changed.connect(_on_tile_set_changed)

	primary_peering_terrains_control.setup(tile_set, terrain_set)
	priorities_control.setup(tile_set, terrain_set)
	alternatives_control.setup(tile_set, terrain_set)

	update_section_buttons.call_deferred()



func _on_tile_set_changed() -> void:
	primary_peering_terrains_control.update()
	priorities_control.update()
	alternatives_control.update()


func update_section_buttons() -> void:
	var editor_plugin := EditorPlugin.new()
	var editor_interface := editor_plugin.get_editor_interface()

	var section_buttons := editor_interface.get_base_control().find_children("*", "EditorInspectorSection", true, false)
	if section_buttons.size() > 0:
		var height : int = section_buttons[0].size.y
		for node in get_tree().get_nodes_in_group("ta_section_button"):
			node.custom_minimum_size.y = height

