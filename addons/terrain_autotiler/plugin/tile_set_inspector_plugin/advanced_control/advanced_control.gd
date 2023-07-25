@tool
extends Control


var tile_set : TileSet
var terrain_set : int

@onready var primary_peering_terrains_control: VBoxContainer = %PrimaryPeeringTerrainsControl


func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set

	primary_peering_terrains_control.setup(tile_set, terrain_set)

	update_section_buttons.call_deferred()



func update_section_buttons() -> void:
	var editor_plugin := EditorPlugin.new()
	var editor_interface := editor_plugin.get_editor_interface()

	var section_buttons := editor_interface.get_base_control().find_children("*", "EditorInspectorSection", true, false)
	if section_buttons.size() > 0:
		var height : int = section_buttons[0].size.y
		print("height=%s" % height)
		for node in get_tree().get_nodes_in_group("ta_section_button"):
			node.custom_minimum_size.y = height

