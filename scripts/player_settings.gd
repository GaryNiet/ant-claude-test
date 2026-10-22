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


## True if the player chose fullscreen (default from game_settings.cfg).
static func fullscreen() -> bool:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	return file.get_value("window", "fullscreen", GameSettings.get_setting("window", "default_fullscreen"))


static func save_fullscreen(on: bool) -> void:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	file.set_value("window", "fullscreen", on)
	file.save(FILE_PATH)


## Music volume the player chose, 0 (off) .. 1 (default from game_settings.cfg [sound]).
static func music_volume() -> float:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	return file.get_value("sound", "music_volume", GameSettings.get_setting("sound", "default_music_volume"))


static func save_music_volume(volume: float) -> void:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	file.set_value("sound", "music_volume", volume)
	file.save(FILE_PATH)


## Sound effects volume the player chose, 0 (off) .. 1.
static func effects_volume() -> float:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	return file.get_value("sound", "effects_volume", GameSettings.get_setting("sound", "default_effects_volume"))


static func save_effects_volume(volume: float) -> void:
	var file := ConfigFile.new()
	file.load(FILE_PATH)
	file.set_value("sound", "effects_volume", volume)
	file.save(FILE_PATH)


## "1920x1080" -> Vector2i(1920, 1080)
static func parse_resolution(choice: String) -> Vector2i:
	var parts := choice.split("x")
	return Vector2i(parts[0].to_int(), parts[1].to_int())
