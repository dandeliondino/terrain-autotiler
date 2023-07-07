@tool
extends Button


const LABEL_MARGIN_ADJUST := -6


@export var label_text := "Inspector Section" :
	set(value):
		label_text = value
		if is_instance_valid(label):
			_update_label_text()

@export var expand_container_path : NodePath


var expand_container : Control

var icon_expanded : Texture2D
var icon_collapsed : Texture2D

var normal_color : Color
var hover_color : Color

@onready var background_rect: ColorRect = %BackgroundRect
@onready var arrow_rect: TextureRect = %ArrowRect
@onready var label: Label = %Label
@onready var arrow_margin_container: MarginContainer = $ArrowMarginContainer
@onready var label_margin_container: MarginContainer = $LabelMarginContainer



func _ready() -> void:
	_update_label_text()
	if has_theme_icon("GuiTreeArrowDown", "EditorIcons"):
		setup()


func setup() -> void:
	expand_container = get_node_or_null(expand_container_path)
	if expand_container == null:
		return

	icon_expanded = get_theme_icon("GuiTreeArrowDown", "EditorIcons")
	icon_collapsed = get_theme_icon("GuiTreeArrowRight", "EditorIcons")
	_toggle_expanded(false)

	normal_color = get_theme_color("prop_subsection", "Editor")
	normal_color.a = normal_color.a * 0.4
	hover_color = normal_color.lightened(0.2)
	_toggle_hover(false)

	var left_margin = round(2 * EditorPlugin.new().get_editor_interface().get_editor_scale())
	arrow_margin_container.set("theme_override_constants/margin_left", left_margin)

	var label_margin = left_margin + icon_expanded.get_size().x + LABEL_MARGIN_ADJUST
	label_margin_container.set("theme_override_constants/margin_left", label_margin)

	label.set("theme_override_fonts/font", get_theme_font("bold", "EditorFonts"))
	label.set("theme_override_font_sizes/font_size", get_theme_font_size("bold_size", "EditorFonts"))
	label.set("theme_override_colors/font_color", get_theme_color("font_color", "Editor"))
	label.set("theme_override_colors/font_pressed_color", get_theme_color("font_color", "Editor"))
	label.set("theme_override_colors/font_hover_color", get_theme_color("font_color", "Editor"))
	label.set("theme_override_colors/font_focus_color", get_theme_color("font_color", "Editor"))
	label.set("theme_override_colors/font_hover_pressed_color", get_theme_color("font_color", "Editor"))

#	custom_minimum_size.y = size.y + 4



func _update_label_text() -> void:
	label.text = label_text


func _toggle_expanded(value : bool) -> void:
	if value:
		if is_instance_valid(expand_container):
			expand_container.show()
		arrow_rect.texture = icon_expanded
	else:
		if is_instance_valid(expand_container):
			expand_container.hide()
		arrow_rect.texture = icon_collapsed


func _toggle_hover(value : bool) -> void:
	if value:
		background_rect.color = hover_color
	else:
		background_rect.color = normal_color


func _on_mouse_entered() -> void:
	_toggle_hover(true)


func _on_mouse_exited() -> void:
	_toggle_hover(false)


func _on_toggled(p_button_pressed: bool) -> void:
	_toggle_expanded(p_button_pressed)
