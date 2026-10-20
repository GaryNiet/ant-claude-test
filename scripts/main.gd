extends Node2D
## Root of the game: window, controls, screen layout (map, tool bar, side panel)
## and saving / loading levels.


## Mouse buttons by the names used in game_settings.cfg.
const MOUSE_BUTTON_NAMES := {
	"Mouse Left": MOUSE_BUTTON_LEFT,
	"Mouse Right": MOUSE_BUTTON_RIGHT,
	"Mouse Middle": MOUSE_BUTTON_MIDDLE,
	"Wheel Up": MOUSE_BUTTON_WHEEL_UP,
	"Wheel Down": MOUSE_BUTTON_WHEEL_DOWN,
}


@onready var _view: Node2D = $SimulationView
@onready var _toolbar: PanelContainer = $UI/Toolbar
@onready var _side_panel: PanelContainer = $UI/SidePanel

var _levels_folder: String = GameSettings.get_setting("game", "levels_folder")
var _was_paused_before_dialog := false


func _ready() -> void:
	_apply_window_settings()
	_register_controls()
	_layout_ui()
	_toolbar.setup(_view, $SimulationView/Brush, self)
	_side_panel.setup(_view)


func _apply_window_settings() -> void:
	var window := get_window()
	window.title = GameSettings.get_setting("window", "title")
	window.size = Vector2i(
		GameSettings.get_setting("window", "width"),
		GameSettings.get_setting("window", "height"))
	window.move_to_center()
	RenderingServer.set_default_clear_color(GameSettings.get_color("window", "background_color"))


## Tool bar across the top, side panel on the right, both with the same look.
func _layout_ui() -> void:
	var toolbar_height: float = GameSettings.get_setting("ui", "toolbar_height")
	var side_panel_width: float = GameSettings.get_setting("ui", "side_panel_width")
	var theme := Theme.new()
	theme.default_font_size = GameSettings.get_setting("ui", "font_size")
	var background := StyleBoxFlat.new()
	background.bg_color = GameSettings.get_color("ui", "panel_color")
	background.set_content_margin_all(6)
	theme.set_stylebox("panel", "PanelContainer", background)
	theme.set_color("font_color", "Label", GameSettings.get_color("colors", "hud_text"))

	_toolbar.theme = theme
	_toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_toolbar.offset_bottom = toolbar_height
	_side_panel.theme = theme
	_side_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_side_panel.offset_left = -side_panel_width
	_side_panel.offset_top = toolbar_height


# --- Saving and loading levels -----------------------------------------------

func open_save_dialog() -> void:
	var dialog := _make_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, "Save level")
	dialog.current_file = _view.simulation.level.name.to_snake_case() + ".level"
	dialog.file_selected.connect(_save_level)


func open_load_dialog() -> void:
	var dialog := _make_file_dialog(FileDialog.FILE_MODE_OPEN_FILE, "Load level")
	dialog.file_selected.connect(_view.load_level)


## The current map (food, obstacles, nest) becomes a level file named after the file.
func _save_level(path: String) -> void:
	var level := Level.from_simulation(_view.simulation, path.get_file().get_basename().capitalize())
	var error := level.save_file(path)
	if error != OK:
		push_error("Could not save level to %s (error %d)" % [path, error])


## Opens a file dialog in the levels folder. The game pauses while it is open.
func _make_file_dialog(mode: FileDialog.FileMode, title: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.title = title
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.current_dir = ProjectSettings.globalize_path(_levels_folder)
	dialog.filters = PackedStringArray(["*.level ; Level files"])
	dialog.size = Vector2i(800, 500)
	$UI.add_child(dialog)
	_was_paused_before_dialog = _view.is_paused
	_view.is_paused = true
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			_view.is_paused = _was_paused_before_dialog
			dialog.queue_free())
	dialog.popup_centered()
	return dialog


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
