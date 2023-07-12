@tool
extends EditorInspectorPlugin

const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

const CellNeighbors := preload("res://addons/terrain_autotiler/core/cell_neighbors.gd")

const MatchModeControl := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/match_mode_control.gd")
const MatchModeControlScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/match_mode_control.tscn")

const IgnoreTerrainControl := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/ignore_terrain_control.gd")
const IgnoreTerrainControlScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/ignore_terrain_control.tscn")

const PrimaryPeeringTerrainsControl := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/primary_peering_terrains_control/primary_peering_terrains_control.gd")
const PrimaryPeeringTerrainsControlScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/primary_peering_terrains_control/primary_peering_terrains_control.tscn")

#var match_mode_option_button : MatchModeControl


func _can_handle(object: Object) -> bool:
	if object is TileSet:
		if CellNeighbors.is_tile_shape_supported(object.tile_shape):
			_validate_metadata.call_deferred(object)
			return true

	return false


func _validate_metadata(tile_set : TileSet) -> void:
	Metadata.validate_tile_set_metadata(tile_set)

# keep usage_flags as untyped since Godot 4.0.3 and 4.1 have different type signatures
func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags, wide: bool) -> bool:
#	prints("_parse_property", object, type, name, hint_type, hint_string)
	if object is TileSet and type == TYPE_INT and name.begins_with("terrain_set"):
		var tile_set := object as TileSet
		var terrain_set := _get_terrain_set_from_property(name)

		var placeholder := Control.new()
		placeholder.name = "PLACEHOLDER"
		add_custom_control(placeholder)

		# call deferred so can return this function
		# to allow editor to finish setting up its controls first
		_add_controls.call_deferred(placeholder, tile_set, terrain_set)
	return false



func _add_controls(p_placeholder : Control, p_tile_set : TileSet, p_terrain_set : int) -> void:
	if not p_placeholder.is_inside_tree():
		await p_placeholder.tree_entered
	var vbox : VBoxContainer = p_placeholder.get_parent()

	if p_tile_set.get_terrain_set_mode(p_terrain_set) == TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES:
		var match_mode_control : MatchModeControl = MatchModeControlScene.instantiate()
		var mode_control_idx := p_placeholder.get_index() + 1
		var mode_control : Control = vbox.get_child(mode_control_idx)
		mode_control.add_sibling(match_mode_control)
		match_mode_control.setup(p_tile_set, p_terrain_set)

	if not _has_ignore_terrain(p_tile_set, p_terrain_set):
		var ignore_terrain_control := IgnoreTerrainControlScene.instantiate()
		vbox.add_child(ignore_terrain_control)
		ignore_terrain_control.setup(p_tile_set, p_terrain_set)

	if p_tile_set.get_terrains_count(p_terrain_set) > 0:
		var primary_peering_terrains_control : PrimaryPeeringTerrainsControl = PrimaryPeeringTerrainsControlScene.instantiate()
		vbox.add_child(primary_peering_terrains_control)
		primary_peering_terrains_control.setup(p_tile_set, p_terrain_set)

	p_placeholder.queue_free()



func _get_terrain_set_from_property(p_property_name : String) -> int:
	var regex = RegEx.new()
	regex.compile("_(\\d+)\\/")
	var result := regex.search(p_property_name)
	return result.get_string(1).to_int()


func _has_ignore_terrain(p_tile_set : TileSet, p_terrain_set : int) -> bool:
	for terrain in p_tile_set.get_terrains_count(p_terrain_set):
		var terrain_name := p_tile_set.get_terrain_name(p_terrain_set, terrain)
		if terrain_name == Autotiler._IGNORE_TERRAIN_NAME:
			return true
	return false



func clean_up() -> void:
	pass
