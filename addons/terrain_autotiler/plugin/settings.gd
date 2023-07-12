extends RefCounted


func _init() -> void:
	_load_config()


# --------------------------------------
# 	SETTINGS
# --------------------------------------

signal setting_changed(setting, value)


const REPLACE_TERRAIN_GUI := &"REPLACE_TERRAIN_GUI"
const TERRAINS_PANEL_SHOW_ICONS := &"TERRAINS_PANEL_SHOW_ICONS"
const TERRAINS_PANEL_HIDE_TERRAINS := &"TERRAINS_PANEL_HIDE_TERRAINS"
const TERRAINS_PANEL_ICON_SCALE := &"TERRAINS_PANEL_ICON_SCALE"
const LAST_PAINT_TOOL := &"LAST_PAINT_TOOL"
const PAINT_MODE := &"PAINT_MODE"
const SHOW_DEBUG_PANEL := &"SHOW_DEBUG_PANEL"
const ENABLE_CELL_LOGGING := &"ENABLE_CELL_LOGGING"

# these function as the default values for a new project
var _settings := {
	REPLACE_TERRAIN_GUI : true,
	TERRAINS_PANEL_SHOW_ICONS : true,
	TERRAINS_PANEL_HIDE_TERRAINS : true,
	TERRAINS_PANEL_ICON_SCALE : 2,
	LAST_PAINT_TOOL : 1,
	PAINT_MODE : 0,
	SHOW_DEBUG_PANEL : false,
	ENABLE_CELL_LOGGING : false,
}


func set_value(p_setting : StringName, p_value : Variant) -> void:
	if _settings[p_setting] == p_value:
		return
	_settings[p_setting] = p_value
	setting_changed.emit(p_setting, p_value)


func get_value(p_setting : StringName) -> Variant:
	return _settings[p_setting]



# --------------------------------------
# 	SAVE/LOAD
# --------------------------------------

const EDITOR_LAYOUT_PATHS := [
	"res://.godot/editor/editor_layout.cfg",
	"res://godot/editor/editor_layout.cfg",
]

# Called from EditorPlugin._get_window_layout()
func save_config(config : ConfigFile) -> void:
	if not config:
		return

	for setting in _settings:
		var value = get_value(setting)
		config.set_value(Autotiler._PLUGIN_NAME, setting, value)


# Called once, on plugin activation.
# Bypasses _set_window_layout, as this is only called on editor load,
# not plugin entering tree.
func _load_config() -> void:
	var config := _get_configuration()
	if not config:
		return

	if not config.has_section(Autotiler._PLUGIN_NAME):
		return

	for setting in _settings:
		if not config.has_section_key(Autotiler._PLUGIN_NAME, setting):
			continue

		var value = config.get_value(Autotiler._PLUGIN_NAME, setting, null)
		_settings[setting] = value


func _get_configuration() -> ConfigFile:
	var config := ConfigFile.new()
	for path in EDITOR_LAYOUT_PATHS:
		if FileAccess.file_exists(path):
			var result := config.load(path)
			if result == OK:
				return config
	push_error("editor_layout.cfg not found")
	return null
