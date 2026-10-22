extends PopupPanel
## The Behaviour menu (from the gameplay bar): sliders that set how the colony's ants behave.
##   Aggressivity       how willing ants are to fight (added to each ant's random will to fight)
##   Exploring distance how far ants explore away from the nest (their explore time)
## Only ants hatched after a change get the new values. Acts on SimulationView.target_colony.

var _view: Node2D
var _title: Label
var _aggressivity: HSlider
var _exploring: HSlider
var _aggressivity_value: Label
var _exploring_value: Label


func setup(view: Node2D) -> void:
	_view = view
	theme = UiTheme.make()
	UiTheme.close_on_right_click(self)
	var column := VBoxContainer.new()
	add_child(column)
	_title = Label.new()
	column.add_child(_title)
	column.add_child(HSeparator.new())

	_aggressivity = _slider(0.0, 1.0, func(value: float) -> void: _view.target_colony().aggressivity = value)
	_aggressivity_value = Label.new()
	column.add_child(_row("Aggressivity", _aggressivity, _aggressivity_value))
	_exploring = _slider(GameSettings.get_setting("behaviour", "exploring_min"), GameSettings.get_setting("behaviour", "exploring_max"),
		func(value: float) -> void: _view.target_colony().exploring = value)
	_exploring_value = Label.new()
	column.add_child(_row("Exploring distance", _exploring, _exploring_value))

	var note := Label.new()
	note.text = "Only ants hatched after a change behave the new way."
	column.add_child(note)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	UiTheme.add_click_animation(close)
	column.add_child(close)


func open() -> void:
	var colony: Colony = _view.target_colony()
	_title.text = "Behaviour of %s" % colony.name
	_aggressivity.set_value_no_signal(colony.aggressivity)
	_exploring.set_value_no_signal(colony.exploring)
	popup_centered()


func _process(_delta: float) -> void:
	if visible:
		_aggressivity_value.text = "%.0f%%" % (_aggressivity.value * 100.0)
		_exploring_value.text = "x %.2f" % _exploring.value


func _slider(minimum: float, maximum: float, on_changed: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.custom_minimum_size.x = GameSettings.get_setting("ui", "slider_width")
	slider.value_changed.connect(on_changed)
	return slider


func _row(text: String, slider: HSlider, value: Label) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = GameSettings.get_setting("ui", "slider_label_width")
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value)
	return row
