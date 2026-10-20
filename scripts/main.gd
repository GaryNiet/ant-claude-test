extends Node2D
## Root of the game. Applies window settings and keyboard controls from game_settings.cfg.

const MOVE_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]


func _ready() -> void:
	_apply_window_settings()
	_register_controls()


func _apply_window_settings() -> void:
	var window := get_window()
	window.title = GameSettings.get_setting("window", "title")
	window.size = Vector2i(
		GameSettings.get_setting("window", "width"),
		GameSettings.get_setting("window", "height"))
	RenderingServer.set_default_clear_color(GameSettings.get_color("window", "background_color"))


## Creates each input action and binds it to the keys listed in [controls].
func _register_controls() -> void:
	for action in MOVE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key_name in GameSettings.get_list("controls", action):
			var key_event := InputEventKey.new()
			key_event.physical_keycode = OS.find_keycode_from_string(key_name)
			if key_event.physical_keycode == KEY_NONE:
				push_error("Unknown key name '%s' for %s" % [key_name, action])
				continue
			InputMap.action_add_event(action, key_event)
