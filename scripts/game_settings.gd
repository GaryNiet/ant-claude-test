extends Node
## Reads game_settings.cfg once at startup and hands values to the rest of the game.
##
## Usage from any script:
##     var speed: float = GameSettings.get_setting("player", "speed")
##     var tint: Color = GameSettings.get_color("player", "color")
##
## There are deliberately no fallback values in code: if a setting is missing
## from the file, an error is printed so you notice and add it there.

const SETTINGS_PATH := "res://game_settings.cfg"

var _file := ConfigFile.new()


func _init() -> void:
	var error := _file.load(SETTINGS_PATH)
	if error != OK:
		push_error("Could not load %s (error code %d)" % [SETTINGS_PATH, error])


## Returns the value of `key` in `[section]`, or null (with an error) if it's missing.
func get_setting(section: String, key: String) -> Variant:
	if not _file.has_section_key(section, key):
		push_error("Missing setting [%s] %s in %s" % [section, key, SETTINGS_PATH])
		return null
	return _file.get_value(section, key)


## Same as get_setting, but converts a "#RRGGBB" text value into a Color.
func get_color(section: String, key: String) -> Color:
	return Color(str(get_setting(section, key)))


## Returns a comma-separated text value as a list of trimmed strings.
func get_list(section: String, key: String) -> PackedStringArray:
	var items := PackedStringArray()
	for item in str(get_setting(section, key)).split(","):
		items.append(item.strip_edges())
	return items
