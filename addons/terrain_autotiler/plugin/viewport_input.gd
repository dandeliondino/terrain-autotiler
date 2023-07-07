@tool
extends Node


const Context := preload("res://addons/terrain_autotiler/plugin/context.gd")

var context : Context
var _main_screen_control : Control


enum InputType {
	HOVER,
	DRAG,
	MOUSE_DOWN,
	MOUSE_UP,
}

var _input_callables := {
	Context.InputMode.PAINT: {
		Context.PaintTool.DRAW: {
			InputType.MOUSE_DOWN: _start_draw_selection,
			InputType.DRAG: _update_draw_selection,
			InputType.MOUSE_UP: _finish_draw,
		},
		Context.PaintTool.LINE: {
			InputType.MOUSE_DOWN: _set_selection_start_cell,
			InputType.DRAG: _update_line_selection,
			InputType.MOUSE_UP: _paint_selection,
		},
		Context.PaintTool.RECT: {
			InputType.MOUSE_DOWN: _set_selection_start_cell,
			InputType.DRAG: _update_rect_selection,
			InputType.MOUSE_UP: _paint_selection,
		},
		Context.PaintTool.BUCKET: {
			InputType.HOVER: _set_bucket_selection,
			InputType.MOUSE_UP: _paint_selection,
		},
	},
	Context.InputMode.LOCK: {
		Context.PaintTool.NONE: {
			InputType.MOUSE_DOWN: _start_lock_selection,
			InputType.DRAG: _update_lock_selection,
			InputType.MOUSE_UP: _lock_selection,
		},
	},
	Context.InputMode.PICKER: {
		Context.PaintTool.NONE: {
			InputType.MOUSE_UP: _pick_terrain_from_tile,
		},
	},
	Context.InputMode.DEBUG: {
		Context.PaintTool.NONE: {
			InputType.MOUSE_UP: _set_debug_cell,
		},
	},
}


var _start_cell : Vector2i


func setup(p_context : Context, p_canvas_item_editor_viewport : Node) -> void:
	context = p_context
	_main_screen_control = p_canvas_item_editor_viewport.get_parent()


func _forward_canvas_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# monitor to remove overlay when mouse leaves main screen
		# TODO: better to use mouse_exited()?
		set_process(true)

		# allow context to determine if cell has changed
		# it will also emit signal if true
		var current_cell := _get_mouse_cell()
		var cell_changed := context.set_current_cell(current_cell)
		if not cell_changed:
			# no visual or selection updates needed if mouse has only moved
			# within the same cell, so allow a quick exit
			return

		if context.is_mouse_pressed():
			_handle_input(InputType.DRAG, current_cell)
		else:
			_handle_input(InputType.HOVER, current_cell)
		return

	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT and \
		event.button_index != MOUSE_BUTTON_RIGHT:
		# ignore middle button events (and potential others)
		return

	var current_cell := context.get_current_cell()
	if current_cell == context.INVALID_CELL:
		# Mouse has left the main screen
#		printerr("Something has gone wrong: current_cell == context.INVALID_CELL")
		context.reset_input()
		return

	if event.is_pressed():
		context.set_mouse_pressed(true)
		context.set_current_button_index(event.button_index)
		_handle_input(InputType.MOUSE_DOWN, current_cell)
	else:
		context.set_mouse_pressed(false)
		_handle_input(InputType.MOUSE_UP, current_cell)




func _handle_input(p_input_type : InputType, current_cell : Vector2i) -> void:
	var input_mode := context.get_current_input_mode()
	var paint_tool : Context.PaintTool
	if input_mode == Context.InputMode.PAINT:
		paint_tool = context.get_current_paint_tool()
	else:
		paint_tool = Context.PaintTool.NONE

#	print("input_type = %s" % p_input_type)
	var callable : Callable = _input_callables[input_mode][paint_tool].get(p_input_type, Callable())
	if callable.is_null():
		return

	callable.call()


func _process(delta: float) -> void:
	var mouse_pos := _main_screen_control.get_global_mouse_position()
	if _main_screen_control.get_global_rect().has_point(mouse_pos):
		return

	context.clear_current_cell()
	set_process(false)


func _get_mouse_cell() -> Vector2i:
	var pos := context.get_current_tile_map().get_local_mouse_position()
	return context.get_current_tile_map().local_to_map(pos)


# ------------------------------
# INPUT CALLABLES
# ------------------------------

# draw
func _start_draw_selection() -> void:
	context.clear_selected_cells()
	context.add_selected_cell(context.get_current_cell())
	context.actions.start_draw_selection()


func _update_draw_selection() -> void:
	var old_cell_count := context.get_selected_cells().size()
	context.add_selected_cell(context.get_current_cell())
	if context.get_selected_cells().size() == old_cell_count:
		# context will only add cells that aren't already selected
		# don't repaint on double back
		return
	context.actions.continue_draw_selection()

func _finish_draw() -> void:
	context.actions.finish_draw_selection()
	context.clear_selected_cells()


# line or rect
func _set_selection_start_cell() -> void:
	var current_cell := context.get_current_cell()
	_start_cell = current_cell
	context.set_selected_cells([current_cell] as Array[Vector2i])


func _update_line_selection() -> void:
	var current_cell := context.get_current_cell()
	var cells_set := {_start_cell : true, current_cell : true}
	var start_cellf := Vector2(_start_cell)
	var end_cellf := Vector2(current_cell)

	var distance : int = int(abs(start_cellf.distance_to(end_cellf)))
	var step_size := 1.0/float(distance)

	for i in distance:
		var next_cell := Vector2i(start_cellf.lerp(end_cellf, i * step_size))
		cells_set[next_cell] = true

	var cells : Array[Vector2i]
	cells.assign(cells_set.keys())
	context.set_selected_cells(cells)


func _update_rect_selection() -> void:
	var current_cell := context.get_current_cell()
	var x_pos : int = min(_start_cell.x, current_cell.x)
	var y_pos : int = min(_start_cell.y, current_cell.y)
	var x_end : int = max(_start_cell.x, current_cell.x)
	var y_end : int = max(_start_cell.y, current_cell.y)

	var cells : Array[Vector2i] = []
	for x in range(x_pos, x_end + 1):
		for y in range(y_pos, y_end + 1):
			cells.append(Vector2i(x,y))
	context.set_selected_cells(cells)


# bucket
# we will fill all side-adjacent cells with tiles of the same terrain
# (unlike the editor, which only fills the same exact tile)
# and we will skip the non-adjacent cells for now
# but consider adding additional options in the future
func _set_bucket_selection() -> void:
	var current_cell := context.get_current_cell()
	var terrain_dict := context.get_cell_terrain_dict(current_cell)

	# if the cell is a non-terrain tile, don't attempt to fill it
	if terrain_dict[Context.TERRAIN] == Autotiler.NULL_TERRAIN:
		context.clear_selected_cells()
		return

	var tile_map := context.get_current_tile_map()

	# we want used_rect instead of used_cells, because we can fill empty cells
	var used_rect := tile_map.get_used_rect()
	if not used_rect.has_point(current_cell):
		# can't use bucket outside of used rect
		context.clear_selected_cells()
		return

	var cells_set := {current_cell: true}
	var next_cells := [current_cell]

	while not next_cells.is_empty():
		var coords : Vector2i = next_cells.pop_back()
		# TileMap.get_surrounding_cells() returns sides neighbors only
		# which is wanted behavior here, so we'll use it instead of our CellNeighbors script
		for neighbor_coords in tile_map.get_surrounding_cells(coords):
			if cells_set.has(neighbor_coords) or not used_rect.has_point(neighbor_coords):
				continue
			var neighbor_terrain_dict := context.get_cell_terrain_dict(neighbor_coords)
			# dictionaries are compared by keys:values, not reference
			if not neighbor_terrain_dict == terrain_dict:
				continue

			cells_set[neighbor_coords] = true
			next_cells.push_back(neighbor_coords)

	var cells : Array[Vector2i]
	cells.assign(cells_set.keys())
	context.set_selected_cells(cells)


# any paint tool except draw
func _paint_selection() -> void:
	context.actions.paint_selection()
	context.clear_selected_cells()


# lock tool
func _start_lock_selection() -> void:
	context.clear_selected_cells()
	context.add_selected_cell(context.get_current_cell())

func _update_lock_selection() -> void:
	context.add_selected_cell(context.get_current_cell())

func _lock_selection() -> void:
	context.actions.lock_selection()
	context.clear_selected_cells()


func _set_debug_cell() -> void:
	if context.get_current_button_index() == MOUSE_BUTTON_RIGHT:
		context.set_current_input_mode(Context.InputMode.PAINT)
		return

	var current_cell := context.get_current_cell()
	var update_result := context.get_current_update_result()
	if not update_result:
		return
	if not update_result.cell_logs.has(current_cell):
		return

	context.set_current_debug_cell(context.get_current_cell())


func _pick_terrain_from_tile() -> void:
	# right-click exits without selecting
	if context.get_current_button_index() == MOUSE_BUTTON_RIGHT:
		context.set_current_input_mode(Context.InputMode.PAINT)
		return

	var current_cell := context.get_current_cell()
	var terrain_dict := context.get_cell_terrain_dict(current_cell)

	var terrain_set : int = terrain_dict[Context.TERRAIN_SET]
	var terrain : int = terrain_dict[Context.TERRAIN]

	if terrain_dict[Context.TERRAIN] == Autotiler.NULL_TERRAIN:
		# not a terrain tile
		return

	context.terrain_change_requested.emit(terrain_set, terrain)
	context.set_current_input_mode(Context.InputMode.PAINT)

