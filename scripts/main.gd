extends Node2D
## Root of the game screen: screen layout (map, tool bar, side panel), saving / loading
## levels and going back to the main menu. The window and the controls are set up once
## by the Startup autoload.


@onready var _view: Node2D = $SimulationView
@onready var _toolbar: PanelContainer = $UI/Toolbar
@onready var _side_panel: PanelContainer = $UI/SidePanel
@onready var _settings_menu: PopupPanel = $UI/SettingsMenu

var _levels_folder: String = GameSettings.get_setting("game", "levels_folder")
var _was_paused_before_dialog := false


func _ready() -> void:
	_layout_ui()
	_toolbar.setup(_view, $SimulationView/MapSpace/Brush, self)
	_side_panel.setup(_view)
	_settings_menu.setup()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("main_menu"):
		go_to_main_menu()


func open_settings_menu() -> void:
	_settings_menu.open()


func go_to_main_menu() -> void:
	GameSession.back_to_main_menu(get_tree())


## Tool bar across the top, side panel on the right, both with the same look.
func _layout_ui() -> void:
	var toolbar_height: float = GameSettings.get_setting("ui", "toolbar_height")
	var side_panel_width: float = GameSettings.get_setting("ui", "side_panel_width")
	var theme := UiTheme.make()
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


## The current map (ground tiles, food, nest) becomes a level file named after the file.
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
