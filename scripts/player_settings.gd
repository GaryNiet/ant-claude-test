class_name PlayerSettings
extends RefCounted
## Choices the player makes in the Settings menu, remembered between games in
## user://player_settings.cfg (Godot's per-user data folder, not the project).
## game_settings.cfg holds the defaults and the list of choices.

const FILE_PATH := "user://player_settings.cfg"


## The chosen resolution as "WIDTHxHEIGHT", or the default from game_settings.cfg.
static func resolution() -> String:
	var file := ConfigFile.new()
	file.load(FILE_PATH)  # missing file = nothing chosen yet
	return file.get_value("window", "resolution", GameSettings.get_setting("window", "default_resolution"))


static func save_resolution(choice: String) -> void:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	file.set_value("window", "resolution", choice)
	file.save(FILE_PATH)


## "1920x1080" -> Vector2i(1920, 1080)
static func parse_resolution(choice: String) -> Vector2i:
	var parts := choice.split("x")
	return Vector2i(parts[0].to_int(), parts[1].to_int())
