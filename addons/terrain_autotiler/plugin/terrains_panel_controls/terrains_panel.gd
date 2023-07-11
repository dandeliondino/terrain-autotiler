@tool
extends Control

const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")
const TileLocation := preload("res://addons/terrain_autotiler/core/tile_location.gd")
const TerrainsData := preload("res://addons/terrain_autotiler/core/terrains_data.gd")
const TerrainPattern := preload("res://addons/terrain_autotiler/core/terrain_pattern.gd")

@onready var debug_panel: Control = %DebugPanel
@onready var paint_mode_buttons: HBoxContainer = %PaintModeButtons

@onready var terrain_sets_option_button: OptionButton = %TerrainSetsOptionButton
@onready var terrains_list: ItemList = %TerrainsList

@onready var icon_display_button: Button = %IconDisplayButton
@onready var text_display_button: Button = %TextDisplayButton

@onready var minus_button: Button = %MinusButton
@onready var plus_button: Button = %PlusButton
@onready var hide_terrains_check_box: CheckBox = %HideTerrainsCheckBox

var context : Context
var _tile_map : TileMap
var _tile_set : TileSet

var _empty_icon : Texture2D


func setup(p_context : Context) -> void:
	context = p_context
	debug_panel.visible = context.settings.get_value(Context.Settings.SHOW_DEBUG_PANEL)
	debug_panel.setup(context)
	paint_mode_buttons.setup(context)
	_setup_buttons()

	_empty_icon = _get_icon_texture(get_theme_icon("Eraser", "EditorIcons"), Color.DIM_GRAY)

	context.current_tile_map_changed.connect(_on_current_tile_map_changed)
	context.current_tile_set_changed.connect(_on_current_tile_set_changed)
	context.terrain_change_requested.connect(_on_terrain_change_requested)
	context.toggle_debug_panel_requested.connect(_on_toggle_debug_panel_requested)
	context.ed_no_tileset_label.visibility_changed.connect(update_panel_display)

	update_panel_display()


func _setup_buttons() -> void:
	var terrain_list_display_group := ButtonGroup.new()
	icon_display_button.button_group = terrain_list_display_group
	text_display_button.button_group = terrain_list_display_group
	icon_display_button.set_pressed_no_signal(
		context.settings.get_value(Context.Settings.TERRAINS_PANEL_SHOW_ICONS)
	)
	hide_terrains_check_box.set_pressed_no_signal(
		context.settings.get_value(Context.Settings.TERRAINS_PANEL_HIDE_TERRAINS)
	)
	_set_icon_scale(context.settings.get_value(Context.Settings.TERRAINS_PANEL_ICON_SCALE), false)


func _on_icon_display_button_toggled(p_button_pressed : bool) -> void:
	context.settings.set_value(Context.Settings.TERRAINS_PANEL_SHOW_ICONS, p_button_pressed)
	_update_terrains_list()


func _on_hide_terrains_check_box_toggled(p_button_pressed: bool) -> void:
	context.settings.set_value(Context.Settings.TERRAINS_PANEL_HIDE_TERRAINS, p_button_pressed)
	_update_terrains_list()


func _on_toggle_debug_panel_requested(p_value : bool) -> void:
	debug_panel.visible = p_value


# ------------------------------------------
#		TERRAINS
# ------------------------------------------

func update_panel_display() -> void:
#	print("update_panel_display()")
	if not context.is_terrain_tab_active() or not context.settings.get_value(Context.Settings.REPLACE_TERRAIN_GUI):
#		print("_update_panel_display() - not context.is_terrain_tab_active() -> hide()")
		hide()
#		print("update_panel_display() - not active - hiding panel")
		return

	if context.ed_no_tileset_label.is_visible_in_tree():
		hide()
#		print("update_panel_display() - no tileset label is shown - hiding panel")
		return

	context.clear_current_terrain_set()

	_tile_map = context.get_current_tile_map()
#	print("update_panel_display() - _tile_map=%s" % _tile_map)
	_tile_set = context.get_current_tile_set()
#	print("update_panel_display() - _tile_set=%s" % _tile_set)
	if not _tile_set or not _tile_set.get_source_count() > 0:
		hide()
#		print("update_panel_display() - no tile_set or source - hiding panel")
		return

	_update_filter_mode()
	context.update_current_autotiler()
	_update_terrain_sets_option_button()
	show()


func _on_terrain_change_requested(p_terrain_set : int, p_terrain : int) -> void:
	# if empty terrain, will ignore the terrain set provided
	# and select the empty terrain currently available
	if p_terrain == Autotiler.EMPTY_TERRAIN or p_terrain_set == context.get_current_terrain_set():
		# set current terrain only
		# to avoid refreshing/redrawing
		context.set_current_terrain(p_terrain)
		_select_terrain(p_terrain)
		return

	# terrain set index is the same as id
	terrain_sets_option_button.select(p_terrain_set)
	context.set_current_terrain_set(p_terrain_set)
	context.set_current_terrain(p_terrain)
	# updating the list will cause it to select the current terrain
	_update_terrains_list()



func _update_terrain_sets_option_button() -> void:
	terrain_sets_option_button.clear()

	if not _tile_map or not _tile_set or _tile_set.get_terrain_sets_count() == 0:
#		print("_update_terrain_sets_option_button() - no tile_map, no tile_set, or no terrain sets - disabling")
		terrain_sets_option_button.disabled = true
		context.clear_current_terrain_set()
		_update_terrains_list()
		return

	var terrain_sets_count := _tile_set.get_terrain_sets_count()
#	print("_update_terrain_sets_option_button() - terrain_sets_count=%s" % terrain_sets_count)

	for terrain_set in terrain_sets_count:
		terrain_sets_option_button.add_item("[%s] Terrain Set" % terrain_set, terrain_set)

	var first_terrain_set := 0
	terrain_sets_option_button.select(first_terrain_set)
	context.set_current_terrain_set(first_terrain_set)

	if terrain_sets_count == 1:
		terrain_sets_option_button.disabled = true
	else:
		terrain_sets_option_button.disabled = false

	_update_terrains_list()


func _on_terrain_sets_option_button_item_selected(_idx: int) -> void:
	var terrain_set := terrain_sets_option_button.get_selected_id()
	context.set_current_terrain_set(terrain_set)
	_update_terrains_list()


# originally had this called with argument of whether to select current terrain
# but ended up being more reliable and easier to let context make the
# current_terrain = NULL_TERRAIN whenever something got updated that made it obsolete
func _update_terrains_list() -> void:
	terrains_list.clear()
	if not context.has_current_terrain_set():
#		print("_update_terrains_list() - not context.has_current_terrain_set() - returning")
		return
	if not context.get_current_terrains_data():
#		print("_update_terrains_list() - not context.get_current_terrains_data() - returning")
		return

	var show_as_icons := icon_display_button.button_pressed
	var ui_scale := context.editor_interface.get_editor_scale()

	if show_as_icons:
		terrains_list.max_columns = 0
		terrains_list.icon_scale = ui_scale * IconScales[current_icon_scale_index] * ICON_SCALE_NO_TEXT_MODIFIER
	else:
		terrains_list.max_columns = 1
		terrains_list.icon_scale = ui_scale * IconScales[current_icon_scale_index] * ICON_SCALE_TEXT_MODIFIER

	_add_terrains_list_item(Autotiler.EMPTY_TERRAIN, _empty_icon, "Empty")

#	print("getting terrains_count")
	var terrains_count := _tile_set.get_terrains_count(context.get_current_terrain_set())

	for terrain in terrains_count:
		_add_terrain(terrain)

	var current_terrain := context.get_current_terrain()
	if current_terrain != Autotiler.NULL_TERRAIN:
		_select_terrain(current_terrain)
		return

	var erase_terrain_idx := 0
	var first_terrain_idx := 1
	var default_terrain_idx := erase_terrain_idx

	if terrains_list.item_count > 1:
		default_terrain_idx = first_terrain_idx

	terrains_list.select(default_terrain_idx)
	var default_terrain : int = terrains_list.get_item_metadata(default_terrain_idx)
	context.set_current_terrain(default_terrain)




func _select_terrain(p_terrain : int) -> void:
	for idx in terrains_list.item_count:
		var terrain : int = terrains_list.get_item_metadata(idx)
		if terrain == p_terrain:
			terrains_list.select(idx)
			return



func _add_terrain(p_terrain : int) -> void:
	var terrains_data := context.get_current_terrains_data()
	if not terrains_data:
		return

	var can_paint := terrains_data.tile_terrains.has(p_terrain)
	if not can_paint && hide_terrains_check_box.button_pressed:
		return

	var terrain_set := context.get_current_terrain_set()
	var icon : Texture2D

	var color := _tile_set.get_terrain_color(terrain_set, p_terrain)
	var display_pattern : TerrainPattern = terrains_data.terrain_display_patterns.get(p_terrain, null)
	if display_pattern:
		var tile_location := display_pattern.get_first_tile()
		if tile_location:
			icon = _get_tile_texture(tile_location, color)
	if not icon:
		icon = _get_color_texture(color)

	_add_terrains_list_item(
		p_terrain,
		icon,
		_tile_set.get_terrain_name(terrain_set, p_terrain),
		can_paint,
	)



func _add_terrains_list_item(p_id : int, p_icon : Texture2D, p_name : String, p_can_paint := true) -> void:
	var s := "%s (%s)" % [p_name, p_id]
	var idx := terrains_list.add_icon_item(p_icon)

	terrains_list.set_item_metadata(idx, p_id)
	if not icon_display_button.button_pressed:
		terrains_list.set_item_text(idx, s)

	if p_can_paint:
		terrains_list.set_item_tooltip(idx, s)
	else:
		terrains_list.set_item_tooltip(idx, s + " (no tiles assigned)")
		terrains_list.set_item_disabled(idx, true)






func _on_terrains_list_item_selected(index: int) -> void:
	var terrain : int = terrains_list.get_item_metadata(index)
	context.set_current_terrain(terrain)





# ------------------------------------------
#		ICON GENERATION
# ------------------------------------------


var icon_size := Vector2i(72,72)
var tile_icon_size := Vector2i(64,64)
var current_filter_mode := 0

func _update_filter_mode() -> void:
	current_filter_mode = _tile_map.texture_filter
	if current_filter_mode == 0:
		current_filter_mode = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") + 1


func _get_icon_texture(icon : Texture2D, color : Color) -> ImageTexture:
	var icon_image := icon.get_image()
	icon_image.resize(tile_icon_size.x, tile_icon_size.y, Image.INTERPOLATE_BILINEAR)
	var image := _get_color_image(color, icon_image.get_format())
	var inside_image := _get_color_image(color.lightened(0.2),  icon_image.get_format())
	image.blit_rect(inside_image, Rect2i(Vector2i.ZERO, tile_icon_size), Vector2i(4,4))

	image.blend_rect(icon_image, icon_image.get_used_rect(), Vector2i(4,4))
	return ImageTexture.create_from_image(image)


func _get_tile_texture(tile_location : TileLocation, color : Color) -> ImageTexture:
#	print("getting tile texture for: source_id=%s, atlas_coords=%s" % [tile_location.source_id, tile_location.atlas_coords])
	var source : TileSetAtlasSource = _tile_set.get_source(tile_location.source_id)
	var texture_region : Rect2i = source.get_tile_texture_region(tile_location.atlas_coords)
	var tile_image : Image = source.texture.get_image().get_region(texture_region)

	var interpolate_mode := Image.INTERPOLATE_BILINEAR
	if current_filter_mode == CanvasItem.TEXTURE_FILTER_NEAREST:
		interpolate_mode = Image.INTERPOLATE_NEAREST

	tile_image.resize(tile_icon_size.x, tile_icon_size.y, interpolate_mode)

	var image := _get_color_image(color, tile_image.get_format())
	var tile_rect := tile_image.get_used_rect()
	# allow space for border and center tile
	var offset := Vector2i(4,4) + Vector2i((tile_icon_size - tile_rect.size)/2.0)

	image.blit_rect(tile_image, tile_image.get_used_rect(), offset)
	return ImageTexture.create_from_image(image)


func _get_color_texture(color : Color) -> ImageTexture:
	var image := _get_color_image(color)
	return ImageTexture.create_from_image(image)


func _get_color_image(color : Color, format := Image.FORMAT_RGBA8) -> Image:
	var image := Image.create(icon_size.x, icon_size.y, false, format)
	image.fill(color)
	return image



# ---------------------------------------------
#	ICON SCALE
# ---------------------------------------------

const ICON_SCALE_TEXT_MODIFIER := 0.5
const ICON_SCALE_NO_TEXT_MODIFIER := 0.75

const IconScales := [
	0.25,
	0.5,
	0.75,
	1.0,
	1.5,
]

var current_icon_scale_index := 1

func _set_icon_scale(idx : int, p_update : bool) -> void:
	if idx < 0 or idx >= IconScales.size():
		return
	if current_icon_scale_index == idx:
		return

	minus_button.disabled = (idx == 0)
	plus_button.disabled = (idx == IconScales.size() - 1)

	current_icon_scale_index = idx
	context.settings.set_value(Context.Settings.TERRAINS_PANEL_ICON_SCALE, idx)

	if p_update:
		_update_terrains_list()


func _on_minus_button_pressed() -> void:
	_set_icon_scale(current_icon_scale_index - 1, true)


func _on_plus_button_pressed() -> void:
	_set_icon_scale(current_icon_scale_index + 1, true)



func _on_current_tile_map_changed(_tile_map : TileMap) -> void:
	if is_visible_in_tree():
		update_panel_display()


func _on_current_tile_set_changed(_tile_set : TileSet) -> void:
	if is_visible_in_tree():
		update_panel_display()
