@tool
extends Button


@export var url : String


func _enter_tree() -> void:
	icon = get_theme_icon("HelpSearch", "EditorIcons")
	disabled = url.is_empty()


func _exit_tree() -> void:
	icon = null


func _on_pressed() -> void:
	OS.shell_open(url)
