@tool
extends Control


const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

var context : Context

var _viewport_control : Control
var _viewport_xform : Transform2D

var editor_font : Font

var paint_icon : Texture2D
var eraser_icon : Texture2D
var picker_icon : Texture2D
var lock_icon : Texture2D
var unlock_icon : Texture2D
var debug_icon : Texture2D
var error_icon : Texture2D
var inspect_icon : Texture2D

func setup(p_context : Context) -> void:
	context = p_context

	editor_font = get_theme_font("main_bold_msdf", "EditorFonts")
	paint_icon = get_theme_icon("CanvasItem", "EditorIcons")
	eraser_icon = get_theme_icon("Eraser", "EditorIcons")
	picker_icon = get_theme_icon("ColorPick", "EditorIcons")
	lock_icon = get_theme_icon("Lock", "EditorIcons")
	unlock_icon = get_theme_icon("Unlock", "EditorIcons")
	debug_icon = get_theme_icon("Search", "EditorIcons")
	error_icon = get_theme_icon("StatusError", "EditorIcons")
	inspect_icon = get_theme_icon("Search", "EditorIcons")


func _forward_canvas_draw_over_viewport(p_viewport_control: Control):
	_viewport_control = p_viewport_control
	_viewport_xform = _get_viewport_transform()

	var input_mode := context.get_current_input_mode()

	if input_mode == Context.InputMode.LOCK:
		# will handle selection and hover here
		_draw_lock_overlay()
		return
	if input_mode == Context.InputMode.DEBUG:
		_draw_debug_overlay()
		return

	if context.has_selected_cells():
		if context.get_current_paint_tool() == Context.PaintTool.DRAW:
			_draw_hover_cell_draw_mode()
			return
		_draw_selected_cells(input_mode)
	else:
		_draw_hover_cell(input_mode)




func _draw_debug_overlay() -> void:
	var last_update_result := context.get_current_update_result()
	if not last_update_result:
		# something has gone wrong -- shouldn't have allowed
		# entering this mode
		return

	var current_cell := context.get_current_cell()
	var current_debug_cell := context.get_current_debug_cell()

	for coords in last_update_result.cell_pattern_types:
		var color := Color.WHITE
		var show_error_icon := false

		if last_update_result.cell_errors.has(coords):
			color = Color.SALMON
			show_error_icon = true
		elif last_update_result.cell_warnings.has(coords):
			color = Color.GOLD
			show_error_icon = true


		if coords == current_cell:
			_draw_cell_filled(coords, color, 0.9)
		elif coords == current_debug_cell:
			_draw_cell_filled(coords, color, 0.66)
		_draw_cell_outline(coords, color)

		if show_error_icon:
			_draw_cell_icon(coords, error_icon, Color.WHITE, false)

		if coords == current_cell:
			_draw_cell_icon(coords, inspect_icon)
		else:
			const INVALID_INDEX := -1
			const STATIC_UPDATE_INDEX := 0
			var idx : int = last_update_result.cell_update_indexes.get(coords, INVALID_INDEX)
			if idx < STATIC_UPDATE_INDEX:
				pass
			else:
				_draw_cell_text(coords, idx)









func _draw_lock_overlay() -> void:
	var selected_cells := context.get_selected_cells()
#	var pressed := context.is_mouse_pressed()
	var lock := (context.get_current_button_index() == MOUSE_BUTTON_LEFT)

	var is_hovering := selected_cells.is_empty()
	var is_locking := not selected_cells.is_empty() && lock
	var is_unlocking := not selected_cells.is_empty() && not lock

	var locked_cells := Autotiler.get_locked_cells(context.get_current_tile_map(), context.get_current_layer())
	var current_cell := context.get_current_cell()

	var drawn_cells := {}
	if is_hovering:
		_draw_hover_cell_lock(current_cell)
		drawn_cells[current_cell] = true

	for coords in selected_cells:
		if is_unlocking:
			if locked_cells.has(coords):
				_draw_selected_cell_unlock(coords)
				drawn_cells[coords] = true
			continue # skip overlay if unlocking and cell not locked

		if locked_cells.has(coords):
			continue # skip overlay if cell already locked

		_draw_selected_cell_lock(coords)
		drawn_cells[coords] = true

	for coords in locked_cells:
		if drawn_cells.has(coords):
			continue
		_draw_locked_cell(coords)







func _draw_hover_cell_draw_mode() -> void:
	var current_cell := context.get_current_cell()
	_draw_cell_outline(current_cell, Color.WHITE)

	var locked_cells := Autotiler.get_locked_cells(context.get_current_tile_map(), context.get_current_layer())
	for coords in locked_cells:
		_draw_locked_cell(coords)





func _draw_hover_cell(p_input_mode : Context.InputMode) -> void:
	var color : Color
	var icon : Texture2D

	# skip lock input mode (handled separately)
	if p_input_mode == Context.InputMode.PAINT:
		if context.get_current_paint_tool() == Context.PaintTool.BUCKET:
			# if there is no selection, bucket can't be used here
			return
		var current_terrain := context.get_current_terrain()
		color = _get_terrain_color(current_terrain)
		if current_terrain == Autotiler.EMPTY_TERRAIN:
			icon = eraser_icon
		else:
			icon = paint_icon
	elif p_input_mode == Context.InputMode.PICKER:
		color = Color.DARK_GRAY
		icon = picker_icon
	else: # DEBUG
		color = Color.DARK_GRAY
		icon = debug_icon

	var current_cell := context.get_current_cell()
	_draw_cell_outline(current_cell, color)
	_draw_cell_icon(current_cell, icon, color)




# input mode will always be paint here
func _draw_selected_cells(p_input_mode : Context.InputMode) -> void:
	var color : Color
	var icon : Texture2D
#	if p_input_mode == Context.InputMode.PAINT:
	if context.get_current_button_index() == MOUSE_BUTTON_LEFT:
		var current_terrain := context.get_current_terrain()
		color = _get_terrain_color(current_terrain)
		if current_terrain == Autotiler.EMPTY_TERRAIN:
			icon = eraser_icon
		else:
			icon = paint_icon
	else: # MOUSE_BUTTON_RIGHT
		color = _get_terrain_color(Autotiler.EMPTY_TERRAIN)
		icon = eraser_icon


	var locked_cells := Autotiler.get_locked_cells(context.get_current_tile_map(), context.get_current_layer())

	if context.is_mouse_pressed():
		for coords in context.get_selected_cells():
			if locked_cells.has(coords):
				continue
			_draw_cell_filled(coords, color)
			_draw_cell_outline(coords, color)
			_draw_cell_icon(coords, icon)
	else: # certain hover tools (like bucket) will create selection when not pressed
		for coords in context.get_selected_cells():
			if locked_cells.has(coords):
				continue
			_draw_cell_outline(coords, color)
			_draw_cell_icon(coords, icon, color)

	# less confusing if full lock overlay is drawn instead of one cell at a time
	for coords in locked_cells:
		_draw_locked_cell(coords)



# -------------------------------
# 	DRAW HELPER FUNCTIONS
# -------------------------------

func _draw_hover_cell_lock(p_coords : Vector2i) -> void:
	_draw_icon_cell_outline(p_coords, lock_icon, Color.WHITE)


func _draw_selected_cell_lock(p_coords : Vector2i) -> void:
	_draw_icon_cell_filled(p_coords, lock_icon, Color.DIM_GRAY, Color.BLACK)


func _draw_selected_cell_unlock(p_coords : Vector2i) -> void:
	_draw_icon_cell_filled(p_coords, unlock_icon, Color.DIM_GRAY, Color.WHITE)


func _draw_locked_cell(p_coords : Vector2i) -> void:
	var fill_color := Color.DIM_GRAY
	fill_color.a = 0.25
	var outline_color := Color.BLACK
	outline_color.a = 0.5
	_draw_icon_cell_filled(p_coords, lock_icon, fill_color, outline_color)


func _get_terrain_color(p_terrain : int) -> Color:
	if p_terrain == Autotiler.EMPTY_TERRAIN:
		return Color.DIM_GRAY
	if p_terrain == Autotiler.NULL_TERRAIN:
		return Color.WHITE
	return context.get_current_tile_map().tile_set.get_terrain_color(
		context.get_current_terrain_set(),
		p_terrain,
	)


func _draw_icon_cell_outline(coords : Vector2i, icon : Texture2D, color : Color) -> void:
	var outline_size := 1.0 * _viewport_xform.get_scale().x
	var rect = _get_cell_rect(coords).grow(-outline_size)

	# icon
	var icon_pos := rect.get_center() - icon.get_size()/2.0
	_viewport_control.draw_texture(icon, icon_pos, color)

	# outline
	_viewport_control.draw_rect(rect, color, false, outline_size)


func _draw_icon_cell_filled(coords : Vector2i, icon : Texture2D, fill_color : Color, outline_color : Color = Color.TRANSPARENT) -> void:
	var outline_size := 1.0 * _viewport_xform.get_scale().x
	var rect = _get_cell_rect(coords).grow(-outline_size)

	if outline_color == Color.TRANSPARENT:
		outline_color = fill_color
	fill_color.a = 0.66

	# fill
	_viewport_control.draw_rect(rect, fill_color)

	# icon
	var icon_pos := rect.get_center() - icon.get_size()/2.0
	_viewport_control.draw_texture(icon, icon_pos, outline_color)

	# outline
	_viewport_control.draw_rect(rect, outline_color, false, outline_size)



func _draw_cell_filled(coords : Vector2i, color : Color, alpha := 0.66) -> void:
	var rect = _get_cell_rect(coords)
	color.a = alpha
	_viewport_control.draw_rect(rect, color)


func _draw_cell_outline(coords : Vector2i, color : Color, alpha := 1.0) -> void:
	var outline_size := 1.0 * _viewport_xform.get_scale().x
	var rect = _get_cell_rect(coords).grow(-outline_size)
	color.a = alpha
	_viewport_control.draw_rect(rect, color, false, outline_size)


# scaling can get slow/ugly, so don't bother unless it turns out to be a problem
func _draw_cell_icon(coords : Vector2i, icon : Texture2D, color := Color.WHITE, align_center := true) -> void:
	var pos : Vector2
	if align_center:
		pos = _get_cell_rect(coords).get_center() - icon.get_size()/2.0
	else:
		pos = _get_cell_rect(coords).end - icon.get_size() - Vector2(4,4)

	_viewport_control.draw_texture(icon, pos, color)


func _draw_cell_text(coords : Vector2i, p_text, color := Color.BLACK, centered := true) -> void:
	var tile_size := Vector2(context.get_current_tile_map().tile_set.tile_size)
	var font_size := tile_size.x/4 * _viewport_xform.get_scale().x
	var rect := _get_cell_rect(coords)
	var text := str(p_text)
	var string_size := editor_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos : Vector2
	if centered:
		pos = rect.get_center() + Vector2(-string_size.x/2.0, string_size.y/4.0)
	else:
		pos = Vector2(rect.position.x, rect.get_center().y)
	_viewport_control.draw_string(editor_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _get_cell_rect(coords : Vector2i) -> Rect2:
	var tile_size := Vector2(context.get_current_tile_map().tile_set.tile_size)
	var local_pos := context.get_current_tile_map().map_to_local(coords) - tile_size/2.0
	var pos := _local_to_viewport_pos(local_pos)
	var rect_size := _local_to_viewport_size(tile_size)
	return Rect2(pos, rect_size)



func _local_to_viewport_pos(p_pos : Vector2) -> Vector2:
	return _viewport_xform * p_pos


func _local_to_viewport_size(p_size : Vector2) -> Vector2:
	return _viewport_xform.get_scale() * p_size


# setting a transform matrix will also alter the rulers on the main screen
# so will calculate transforms per item
func _get_viewport_transform() -> Transform2D:
	var tile_map := context.get_current_tile_map()
	return tile_map.get_viewport_transform() * tile_map.get_global_transform()













