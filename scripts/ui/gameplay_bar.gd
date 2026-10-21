extends PanelContainer
## The gameplay bar under the map: play / pause, the upgrade buttons and the game menu.
##
##   Pause | Upgrades for <colony>: Attack, Health, Speed, Carry more, Cut faster, Faster spawn | Menu
##
## The upgrades are for our colony, or for a rival colony while its nest is selected (see
## SimulationView.target_colony); the title says which. Each upgrade button shows its level
## and its cost in food. The Menu button opens: Restart level, Save level, Load level,
## Settings, Main menu. (Building / testing tools and all the data are in the side panel.)

enum MenuItem { RESTART, SAVE, LOAD, SETTINGS, MAIN_MENU }

const MENU_LABELS := {
	MenuItem.RESTART: "Restart level",
	MenuItem.SAVE: "Save level",
	MenuItem.LOAD: "Load level",
	MenuItem.SETTINGS: "Settings",
	MenuItem.MAIN_MENU: "Main menu",
}

var _view: Node2D
var _main: Node
var _pause_button: Button
var _upgrades_title: Label
var _upgrade_buttons := {}    ## ColonyUpgrades.Kind -> Button
var _menu: PopupMenu

var _button_size: float = GameSettings.get_setting("ui", "tool_button_size")
var _upgrade_button_width: float = GameSettings.get_setting("ui", "upgrade_button_width")
var _tool_font_size: int = GameSettings.get_setting("ui", "tool_font_size")


## Builds the bar. Called by main.gd once everything exists.
func setup(view: Node2D, main: Node) -> void:
	_view = view
	_main = main
	var row := HBoxContainer.new()
	add_child(row)

	_pause_button = _bar_button("", Vector2(_button_size, _button_size))
	_pause_button.pressed.connect(func() -> void: _view.is_paused = not _view.is_paused)
	row.add_child(_pause_button)
	row.add_child(VSeparator.new())

	_upgrades_title = Label.new()
	_upgrades_title.custom_minimum_size.x = _button_size
	_upgrades_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrades_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_upgrades_title)
	for kind in ColonyUpgrades.Kind.values():
		var button := _bar_button("", Vector2(_upgrade_button_width, _button_size))
		button.pressed.connect(func() -> void: _view.simulation.buy_upgrade(_view.target_colony(), kind))
		_upgrade_buttons[kind] = button
		row.add_child(button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var menu_button := _bar_button("Menu\n(%s)" % _keys("main_menu"), Vector2(_button_size, _button_size))
	menu_button.pressed.connect(open_menu)
	row.add_child(menu_button)
	_build_menu()


func _process(_delta: float) -> void:
	if _view == null:
		return
	_pause_button.text = "%s\n(%s)" % ["Play" if _view.is_paused else "Pause", _keys("pause")]
	var colony: Colony = _view.target_colony()
	_upgrades_title.text = "Upgrades\n%s" % colony.name
	_update_upgrade_buttons(colony)


func _update_upgrade_buttons(colony: Colony) -> void:
	var upgrades := colony.upgrades
	for kind in _upgrade_buttons:
		var button: Button = _upgrade_buttons[kind]
		var level_text := "lv %d/%d" % [upgrades.level_of(kind), upgrades.max_level()]
		button.tooltip_text = upgrades.describe_bonus(kind)
		if upgrades.is_maxed(kind):
			button.text = "%s\n%s\nmaxed" % [ColonyUpgrades.LABELS[kind], level_text]
			button.disabled = true
		else:
			button.text = "%s\n%s\n%d food" % [ColonyUpgrades.LABELS[kind], level_text, upgrades.cost(kind)]
			button.disabled = colony.food_stored < upgrades.cost(kind)


# --- The game menu ---------------------------------------------------------------------

## Opens the game menu just above the Menu button's corner of the screen.
func open_menu() -> void:
	_menu.reset_size()
	var bottom_right := get_global_rect().end
	_menu.position = Vector2i(bottom_right - Vector2(_menu.size.x, _menu.size.y + size.y))
	_menu.popup()


func _build_menu() -> void:
	_menu = PopupMenu.new()
	for item in MENU_LABELS:
		_menu.add_item(MENU_LABELS[item], item)
	_menu.id_pressed.connect(_on_menu_item)
	add_child(_menu)


func _on_menu_item(item: int) -> void:
	match item:
		MenuItem.RESTART:
			_view.restart_level()
		MenuItem.SAVE:
			_main.open_save_dialog()
		MenuItem.LOAD:
			_main.open_load_dialog()
		MenuItem.SETTINGS:
			_main.open_settings_menu()
		MenuItem.MAIN_MENU:
			_main.go_to_main_menu()


# --- Helpers ---------------------------------------------------------------------------

## A bar button: never takes keyboard focus (so Space still pauses instead of clicking it).
func _bar_button(text: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = minimum_size
	button.add_theme_font_size_override("font_size", _tool_font_size)
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.add_click_animation(button)
	return button


## The key(s) of a [controls] action, for button texts.
func _keys(action: String) -> String:
	return ", ".join(GameSettings.get_list("controls", action))
