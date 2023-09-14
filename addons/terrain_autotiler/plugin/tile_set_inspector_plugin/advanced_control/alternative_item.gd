@tool
extends Control

const TERRAIN_NAME_TEMPLATE := "({index}) {name}"
const EMPTY_ID := 999

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
@onready var add_terrain_button: MenuButton = %AddTerrainButton
@onready var add_terrain_popup : PopupMenu = add_terrain_button.get_popup()
@onready var terrains_list_panel: PanelContainer = %TerrainsListPanel
@onready var alt_name_panel: PanelContainer = %AltNamePanel
@onready var content_panel: PanelContainer = %ContentPanel


func setup(p_tile_set : TileSet, p_terrain_set : int, p_terrain : int) -> void:
	tile_set = p_tile_set
	terrain_set = p_terrain_set
	terrain = p_terrain

	alt_name = tile_set.get_terrain_name(terrain_set, terrain)
	var color := tile_set.get_terrain_color(terrain_set, terrain)

	color_rect.color = color
	label.text = alt_name

	match_any = Metadata.get_alternative_match_all(tile_set, terrain_set, terrain)

	match_any_check_box.set_pressed_no_signal(match_any)
	match_terrains_check_box.set_pressed_no_signal(not match_any)

	if not match_any_check_box.toggled.is_connected(_on_match_any_toggled):
		match_any_check_box.toggled.connect(_on_match_any_toggled)

	if not match_terrains_check_box.toggled.is_connected(_on_match_terrains_toggled):
		match_terrains_check_box.toggled.connect(_on_match_terrains_toggled)

	populate_terrain_items()

	if match_any:
		terrains_list_panel.hide()
	else:
		add_terrain_button.icon = get_theme_icon("Add", "EditorIcons")
		populate_add_terrain_popup()


#	set("theme_override_styles/panel", get_theme_stylebox("sub_inspector_bg8", "Editor"))
#	set("theme_override_styles/panel", get_theme_stylebox("panel", "ItemList"))
	alt_name_panel.set("theme_override_styles/panel", get_theme_stylebox("sub_inspector_property_bg0", "Editor"))
	content_panel.set("theme_override_styles/panel", get_theme_stylebox("sub_inspector_bg0", "Editor"))
#	terrains_list_panel.set("theme_override_styles/panel", get_theme_stylebox("sub_inspector_bg8", "Editor"))
#	terrains_list_panel.set("theme_override_styles/panel", get_theme_stylebox("Content", "EditorStyles"))
	label.set("theme_override_fonts/font", get_theme_font("main_button_font", "EditorFonts"))
	label.set("theme_override_font_sizes/font_size", get_theme_font_size("main_button_font_size", "EditorFonts"))


func populate_terrain_items() -> void:
	for child in terrain_items_container.get_children():
		child.queue_free()

	if match_any:
		return

	var match_terrains := Metadata.get_alternative_match_terrains(tile_set, terrain_set, terrain)
	if not match_terrains.size():
		empty_label.show()
		return

	empty_label.hide()

	for match_terrain in match_terrains:
		var terrain_item : AltTerrainItem = AltTerrainItemScene.instantiate()
		terrain_items_container.add_child(terrain_item)
		if not terrain_item.is_node_ready():
			await terrain_item.ready

		terrain_item.setup(tile_set, terrain_set, match_terrain)
		terrain_item.remove_button.pressed.connect(_on_remove_button_pressed.bind(match_terrain))


func populate_add_terrain_popup() -> void:
	add_terrain_popup.clear()

	var terrains_to_add := Metadata.get_alternative_match_terrains_can_add(tile_set, terrain_set, terrain)
	if terrains_to_add.size() == 0:
		add_terrain_popup.add_item("<none>")
		return

	for peering_terrain in terrains_to_add:
		var peering_terrain_name : String
		var peering_terrain_color : Color

		if peering_terrain == Autotiler.EMPTY_TERRAIN:
			peering_terrain_name = "<empty>"
			peering_terrain_color = Color.DIM_GRAY
		else:
			peering_terrain_name = tile_set.get_terrain_name(terrain_set, peering_terrain)
			peering_terrain_color = tile_set.get_terrain_color(terrain_set, peering_terrain)

		var id := peering_terrain
		if id == -1:
			id = EMPTY_ID

		add_terrain_popup.add_icon_item(
			_get_icon(peering_terrain_color),
			TERRAIN_NAME_TEMPLATE.format({
				"index": peering_terrain,
				"name": peering_terrain_name,
			}),
			id,
		)

	add_terrain_popup.id_pressed.connect(_on_add_terrain_popup_id_pressed)




func _get_icon(color : Color) -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
	image.fill(color)
	return ImageTexture.create_from_image(image)



func _on_add_terrain_popup_id_pressed(p_terrain : int) -> void:
	if p_terrain == EMPTY_ID:
		p_terrain = Autotiler.EMPTY_TERRAIN
	Metadata.add_alternative_match_terrain(tile_set, terrain_set, terrain, p_terrain)


func _on_remove_button_pressed(p_terrain : int) -> void:
	Metadata.remove_alternative_match_terrain(tile_set, terrain_set, terrain, p_terrain)



func _on_match_any_toggled(value : bool) -> void:
	Metadata.set_alternative_match_all(tile_set, terrain_set, terrain, value)


func _on_match_terrains_toggled(value : bool) -> void:
	Metadata.set_alternative_match_all(tile_set, terrain_set, terrain, not value)


