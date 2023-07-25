@tool
extends Control

const TERRAIN_NAME_TEMPLATE := "({index}) {name}"

const Metadata := preload("res://addons/terrain_autotiler/core/metadata.gd")
const AltTerrainItem := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/alt_terrain_item.gd")
const AltTerrainItemScene := preload("res://addons/terrain_autotiler/plugin/tile_set_inspector_plugin/advanced_control/alt_terrain_item.tscn")

var tile_set : TileSet
var terrain_set : int
var terrain : int
var alt_name : String
var match_any : bool

@onready var color_rect: ColorRect = %ColorRect
@onready var label: Label = %Label
@onready var match_any_check_box: CheckBox = %MatchAnyCheckBox
@onready var match_terrains_check_box: CheckBox = %MatchTerrainsCheckBox
@onready var terrain_items_container: VBoxContainer = %TerrainItemsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var terrain_option_button: OptionButton = %TerrainOptionButton


func setup(p_tile_set : TileSet, p_terrain_set : int, p_terrain : int, p_alt_name : String) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	terrain = p_terrain
	alt_name = p_alt_name

	color_rect.color = tile_set.get_terrain_color(terrain_set, terrain)
	label.text = alt_name

	match_any = Metadata.get_alternative_match_all(tile_set, terrain_set, alt_name)

	match_any_check_box.set_pressed_no_signal(match_any)
	match_terrains_check_box.set_pressed_no_signal(not match_any)

	if not match_any_check_box.toggled.is_connected(_on_match_any_toggled):
		match_any_check_box.toggled.connect(_on_match_any_toggled)

	if not match_terrains_check_box.toggled.is_connected(_on_match_terrains_toggled):
		match_terrains_check_box.toggled.connect(_on_match_terrains_toggled)

	populate_terrain_items()
	populate_terrain_option_button()


func populate_terrain_items() -> void:
	for child in terrain_items_container.get_children():
		child.queue_free()

	if match_any:
		return

	var terrains := Metadata.get_alternative_match_terrains(tile_set, terrain_set, alt_name)
	if not terrains.size():
		empty_label.show()
		return

	empty_label.hide()

	for terrain in terrains:
		var terrain_item : AltTerrainItem = AltTerrainItemScene.instantiate()
		terrain_items_container.add_child(terrain_item)
		if not terrain_item.is_node_ready():
			await terrain_item.ready

		terrain_item.setup(tile_set, terrain_set, terrain)
		terrain_item.remove_button.pressed.connect(_on_remove_button_pressed.bind(terrain))


func populate_terrain_option_button() -> void:
	terrain_option_button.clear()

	var terrains_to_add := Metadata.get_alternative_match_terrains_can_add(tile_set, terrain_set, alt_name)
	if terrains_to_add.size() == 0:
		terrain_option_button.add_item("<none>")
		terrain_option_button.select(0)
		terrain_option_button.disabled = true
		return

	terrain_option_button.disabled = false

	for peering_terrain in terrains_to_add:
		var peering_terrain_name := tile_set.get_terrain_name(terrain_set, peering_terrain)
		var peering_terrain_color := tile_set.get_terrain_color(terrain_set, peering_terrain)

		terrain_option_button.add_icon_item(
			_get_icon(peering_terrain_color),
			TERRAIN_NAME_TEMPLATE.format({
				"index": peering_terrain,
				"name": peering_terrain_name,
			}),
			peering_terrain,
		)

	terrain_option_button.select(0)
	terrain_option_button.item_selected.connect(_on_terrain_option_button_item_selected)




func _get_icon(color : Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)



func _on_terrain_option_button_item_selected(idx : int) -> void:
	var terrain := terrain_option_button.get_item_id(idx)
	Metadata.add_alternative_match_terrain(tile_set, terrain_set, alt_name, terrain)


func _on_remove_button_pressed(terrain : int) -> void:
	Metadata.remove_alternative_match_terrain(tile_set, terrain_set, alt_name, terrain)



func _on_match_any_toggled(value : bool) -> void:
	print("_on_match_any_toggled")
	Metadata.set_alternative_match_all(tile_set, terrain_set, alt_name, value)


func _on_match_terrains_toggled(value : bool) -> void:
	Metadata.set_alternative_match_all(tile_set, terrain_set, alt_name, not value)


