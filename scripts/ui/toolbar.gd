extends PanelContainer
## The bar at the top of the window: painting tools, brush size, pause/restart,
## save/load level, and "fit map" to reset the zoom.

var _view: Node2D
var _brush: Node2D
var _main: Node
var _tool_buttons := {}       ## Brush.Tool -> Button
var _brush_size_label: Label
var _pause_button: Button


## Builds the buttons. Called by main.gd once everything exists.
func setup(view: Node2D, brush: Node2D, main: Node) -> void:
	_view = view
	_brush = brush
	_main = main
	var row := HBoxContainer.new()
	add_child(row)

	row.add_child(_label("Tool:"))
	var tool_group := ButtonGroup.new()
	for tool in brush.TOOL_NAMES:
		var shortcut_keys := ", ".join(GameSettings.get_list("controls", brush.TOOL_ACTIONS[tool]))
		var button := _button("%s (%s)" % [brush.TOOL_NAMES[tool], shortcut_keys], _on_tool_pressed.bind(tool))
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
	row.add_child(_button("Restart level", _view.restart_level))
	row.add_child(_button("Fit map", _view.fit_map_to_area))

	row.add_child(VSeparator.new())
	row.add_child(_button("Save level", _main.open_save_dialog))
	row.add_child(_button("Load level", _main.open_load_dialog))


func _process(_delta: float) -> void:
	if _view == null:
		return
	_brush_size_label.text = "%d" % _brush.radius
	_pause_button.text = "Resume" if _view.is_paused else "Pause"
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
