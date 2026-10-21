extends PopupPanel
## A small Settings window, opened from the main menu or the tool bar.
## The window resolution, fullscreen (also F11), and the music and sound effects volumes.

var _resolution_choice: OptionButton
var _fullscreen: CheckBox
var _note: Label
var _music_volume: HSlider
var _effects_volume: HSlider


## Builds the menu. Called by the screen that owns it once everything exists.
func setup() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	var title := Label.new()
	title.text = "Settings"
	column.add_child(title)
	column.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = "Resolution (16:9):"
	row.add_child(label)
	_resolution_choice = OptionButton.new()
	for choice in GameSettings.get_list("window", "resolutions"):
		_resolution_choice.add_item(choice)
	_resolution_choice.item_selected.connect(_on_resolution_selected)
	row.add_child(_resolution_choice)

	_fullscreen = CheckBox.new()
	_fullscreen.text = "Fullscreen (%s)" % ", ".join(GameSettings.get_list("controls", "toggle_fullscreen"))
	_fullscreen.toggled.connect(func(on: bool) -> void:
		PlayerSettings.save_fullscreen(on)
		Startup.apply_resolution()
		_update_note())
	column.add_child(_fullscreen)

	_note = Label.new()
	column.add_child(_note)

	_music_volume = _volume_row(column, "Music:", func(volume: float) -> void:
		PlayerSettings.save_music_volume(volume)
		Sounds.apply_volumes())
	_effects_volume = _volume_row(column, "Sound effects:", func(volume: float) -> void:
		PlayerSettings.save_effects_volume(volume)
		Sounds.play("click"))

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	column.add_child(close)


func open() -> void:
	var current := PlayerSettings.resolution()
	for index in _resolution_choice.item_count:
		if _resolution_choice.get_item_text(index) == current:
			_resolution_choice.select(index)
	_fullscreen.set_pressed_no_signal(PlayerSettings.fullscreen())
	_music_volume.set_value_no_signal(PlayerSettings.music_volume())
	_effects_volume.set_value_no_signal(PlayerSettings.effects_volume())
	_update_note()
	popup_centered()


## A labelled slider from 0 (off) to 1, calling `on_changed` with the new volume.
func _volume_row(column: VBoxContainer, text: String, on_changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = GameSettings.get_setting("ui", "slider_label_width")
	row.add_child(label)
	var slider := HSlider.new()
	slider.max_value = 1.0
	slider.step = GameSettings.get_setting("ui", "volume_slider_step")
	slider.custom_minimum_size.x = GameSettings.get_setting("ui", "slider_width")
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(on_changed)
	row.add_child(slider)
	return slider


func _on_resolution_selected(index: int) -> void:
	var choice := _resolution_choice.get_item_text(index)
	PlayerSettings.save_resolution(choice)
	Startup.apply_resolution()
	_update_note()


## Tells the player when the window had to be shrunk to fit their screen.
func _update_note() -> void:
	var wanted := PlayerSettings.parse_resolution(PlayerSettings.resolution())
	var actual := get_tree().root.size
	var shrunk := not PlayerSettings.fullscreen() and actual != wanted
	_note.text = "Shrunk to %dx%d to fit your screen." % [actual.x, actual.y] if shrunk else ""
