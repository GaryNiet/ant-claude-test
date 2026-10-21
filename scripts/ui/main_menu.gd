extends Control
## The first screen: pick a level to play (Level 1, 2 or 3), open the settings, or quit.
## The levels are listed in [menu] levels in game_settings.cfg.

@onready var _settings_menu: PopupPanel = $SettingsMenu


func _ready() -> void:
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_menu.setup()

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", GameSettings.get_setting("menu", "button_spacing"))
	panel.add_child(column)

	var title := Label.new()
	title.text = GameSettings.get_setting("window", "title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", GameSettings.get_setting("menu", "title_font_size"))
	column.add_child(title)
	column.add_child(HSeparator.new())

	var levels := GameSettings.get_list("menu", "levels")
	for number in levels.size():
		var path := levels[number]
		column.add_child(_button("Level %d: %s" % [number + 1, _level_name(path)],
			func() -> void: GameSession.play_level(get_tree(), path)))
	column.add_child(HSeparator.new())
	column.add_child(_button("Settings", _settings_menu.open))
	column.add_child(_button("Quit", get_tree().quit))


## The name written in the level file (or the file name if it can't be read).
func _level_name(path: String) -> String:
	var level := Level.load_file(path)
	return level.name if level != null else path.get_file()


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = GameSettings.get_setting("menu", "button_width")
	button.add_theme_font_size_override("font_size", GameSettings.get_setting("menu", "button_font_size"))
	button.pressed.connect(on_pressed)
	return button
