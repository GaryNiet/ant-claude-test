extends PanelContainer
## The bar at the top of the window: painting tools, brush size, pause/restart,
## save/load level, "fit map" to reset the zoom, switch between the isometric and debug views,
## the settings menu and back to the main menu.

var _view: Node2D
var _brush: Node2D
var _main: Node
var _tool_buttons := {}       ## Brush.Tool -> Button
var _brush_size_label: Label
var _pause_button: Button
var _view_button: Button


## Builds the buttons. Called by main.gd once everything exists.
func setup(view: Node2D, brush: Node2D, main: Node) -> void:
	_view = view
	_brush = brush
	_main = main
	var row := HBoxContainer.new()
	add_child(row)

	var tool_group := ButtonGroup.new()
	for tool in brush.TOOL_NAMES:
		var shortcut_keys := ", ".join(GameSettings.get_list("controls", brush.TOOL_ACTIONS[tool]))
		var button := _button("%s %s" % [shortcut_keys, brush.TOOL_NAMES[tool]], _on_tool_pressed.bind(tool))
		button.toggle_mode = true
		button.button_group = tool_group
		_tool_buttons[tool] = button
		row.add_child(button)

	row.add_child(VSeparator.new())
	row.add_child(_label("Brush:"))
	row.add_child(_button("-", func() -> void: _brush.change_size(-1)))
	_brush_size_label = _label("")
	row.add_child(_brush_size_label)
	row.add_child(_button("+", func() -> void: _brush.change_size(1)))

	row.add_child(VSeparator.new())
	_pause_button = _button("Pause", func() -> void: _view.is_paused = not _view.is_paused)
	row.add_child(_pause_button)
	row.add_child(_button("Restart", _view.restart_level))
	row.add_child(_button("Fit map", _view.fit_map_to_area))
	_view_button = _button("", func() -> void: _view.set_iso_view(not _view.is_iso_view))
	row.add_child(_view_button)

	row.add_child(VSeparator.new())
	row.add_child(_button("Save level", _main.open_save_dialog))
	row.add_child(_button("Load level", _main.open_load_dialog))

	row.add_child(VSeparator.new())
	row.add_child(_button("Settings", _main.open_settings_menu))
	row.add_child(_button("Menu (%s)" % ", ".join(GameSettings.get_list("controls", "main_menu")), _main.go_to_main_menu))


func _process(_delta: float) -> void:
	if _view == null:
		return
	_brush_size_label.text = "%d" % _brush.radius
	_pause_button.text = "Resume" if _view.is_paused else "Pause"
	var view_key := ", ".join(GameSettings.get_list("controls", "toggle_view"))
	_view_button.text = "%s view (%s)" % ["Debug" if _view.is_iso_view else "Iso", view_key]
	_tool_buttons[_brush.selected_tool].button_pressed = true  # follows keyboard shortcuts too


func _on_tool_pressed(tool: int) -> void:
	_brush.selected_tool = tool


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


## A button that never takes keyboard focus (so Space still pauses instead of clicking it).
func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button
