extends Node
## Autoload that sets up the window and the controls once, when the game starts
## (before the main menu), so every screen shares them.


## Mouse buttons by the names used in game_settings.cfg.
const MOUSE_BUTTON_NAMES := {
	"Mouse Left": MOUSE_BUTTON_LEFT,
	"Mouse Right": MOUSE_BUTTON_RIGHT,
	"Mouse Middle": MOUSE_BUTTON_MIDDLE,
	"Wheel Up": MOUSE_BUTTON_WHEEL_UP,
	"Wheel Down": MOUSE_BUTTON_WHEEL_DOWN,
}


func _ready() -> void:
	_apply_window_settings()
	_register_controls()


## The screen is always laid out at [window] layout_width x layout_height and scaled
## to the window, so every 16:9 resolution shows exactly the same picture, just sharper.
func _apply_window_settings() -> void:
	var window := get_window()
	window.title = GameSettings.get_setting("window", "title")
	window.content_scale_size = Vector2i(
		GameSettings.get_setting("window", "layout_width"),
		GameSettings.get_setting("window", "layout_height"))
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	RenderingServer.set_default_clear_color(GameSettings.get_color("window", "background_color"))
	apply_resolution()


## Sizes the window to the chosen resolution. If the screen is too small for it, the window
## is shrunk (still 16:9) to fit the usable screen area.
func apply_resolution() -> void:
	var window := get_window()
	var wanted := Vector2(PlayerSettings.parse_resolution(PlayerSettings.resolution()))
	var screen := Vector2(DisplayServer.screen_get_usable_rect(window.current_screen).size)
	var shrink := minf(1.0, minf(screen.x / wanted.x, screen.y / wanted.y))
	window.size = Vector2i(wanted * shrink)
	window.move_to_center()


## Creates one input action per entry in [controls], bound to the keys/buttons listed there.
func _register_controls() -> void:
	for action in GameSettings.get_keys("controls"):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for input_name in GameSettings.get_list("controls", action):
			var event := _input_event_from_name(input_name)
			if event == null:
				push_error("Unknown key or button name '%s' for %s" % [input_name, action])
				continue
			InputMap.action_add_event(action, event)


## Turns a name like "Space", "A" or "Mouse Left" into an input event (null if unknown).
func _input_event_from_name(input_name: String) -> InputEvent:
	if MOUSE_BUTTON_NAMES.has(input_name):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_NAMES[input_name]
		return mouse_event
	var key_event := InputEventKey.new()
	key_event.physical_keycode = OS.find_keycode_from_string(input_name)
	if key_event.physical_keycode == KEY_NONE:
		return null
	return key_event
