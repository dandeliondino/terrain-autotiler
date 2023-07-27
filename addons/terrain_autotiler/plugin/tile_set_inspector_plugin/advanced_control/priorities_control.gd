@tool
extends VBoxContainer


const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")

const TerrainItem := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/priorities_terrain_item.gd")
const TerrainItemScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/priorities_terrain_item.tscn")

var tile_set : TileSet
var terrain_set : int

@onready var default_button: CheckButton = %DefaultButton
@onready var terrains_container: VBoxContainer = %TerrainsContainer



func setup(p_tile_set : TileSet, p_terrain_set : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	update()


func update() -> void:
	for child in terrains_container.get_children():
		child.queue_free()

	var use_custom := Metadata.get_use_custom_priorities(tile_set, terrain_set)
	default_button.set_pressed_no_signal(not use_custom)

	if not default_button.toggled.is_connected(_on_default_button_toggled):
		default_button.toggled.connect(_on_default_button_toggled)

	if use_custom:
		populate_priorities()


func populate_priorities() -> void:
	var terrains_list := Metadata.get_priorities_list(tile_set, terrain_set)
	for idx in terrains_list.size():
		var terrain : int = terrains_list[idx]

		var terrain_item : TerrainItem = TerrainItemScene.instantiate()
		terrains_container.add_child(terrain_item)

		if not terrain_item.is_node_ready():
			await terrain_item.ready

		var can_move_up : bool = (idx != 0)
		var can_move_down : bool = (idx < terrains_list.size() - 1)
		terrain_item.setup(tile_set, terrain_set, terrain, can_move_up, can_move_down)

		terrain_item.up_button.pressed.connect(
			_on_move_up_button_pressed.bind(terrain)
		)
		terrain_item.down_button.pressed.connect(
			_on_move_down_button_pressed.bind(terrain)
		)


func _on_default_button_toggled(value : bool) -> void:
	Metadata.set_use_custom_priorities(tile_set, terrain_set, not value)


func _on_move_up_button_pressed(terrain : int) -> void:
	Metadata.decrease_peering_terrain_priority(tile_set, terrain_set, terrain)


func _on_move_down_button_pressed(terrain : int) -> void:
	Metadata.increase_peering_terrain_priority(tile_set, terrain_set, terrain)
