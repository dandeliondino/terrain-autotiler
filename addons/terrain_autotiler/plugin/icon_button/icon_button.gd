@tool
extends Button

@export var icon_name : String


func _ready() -> void:
	icon = get_theme_icon(icon_name, "EditorIcons")


func _exit_tree() -> void:
	icon = null
