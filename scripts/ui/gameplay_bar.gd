extends PanelContainer
## The gameplay bar under the map:
##
##   Pause | Hatch 1, Hatch 5, Infinite hatch, hatching queue | Behaviour, Tech tree | food,
##   ants, maturity, larvae | Menu
##
## The hatch buttons put stored larvae in the hatching queue (Infinite hatch is a toggle:
## every larva joins the queue as soon as it is laid). Larvae hatch one after the other: the
## queue shows how many are waiting and a bar that fills until the next ant pops out. Behaviour opens sliders for the colony's ants; Tech tree
## opens the upgrades. They act on our colony, or on a rival colony while its nest is
## selected (see SimulationView.target_colony). The Menu button opens: Restart level,
## Save level, Load level, Settings, Main menu.
## (Building / testing tools and all the data are in the side panel.)

enum MenuItem { RESTART, SAVE, LOAD, SETTINGS, MAIN_MENU }

const MENU_LABELS := {
	MenuItem.RESTART: "Restart level",
	MenuItem.SAVE: "Save level",
	MenuItem.LOAD: "Load level",
	MenuItem.SETTINGS: "Settings",
	MenuItem.MAIN_MENU: "Main menu",
}
const BehaviourMenu := preload("res://scripts/ui/behaviour_menu.gd")
const TechTreeMenu := preload("res://scripts/ui/tech_tree_menu.gd")

var _view: Node2D
var _main: Node
var _pause_button: Button
var _infinite_button: Button
var _hatching_label: Label
var _hatching_bar: ProgressBar
var _status: Label
var _menu: PopupMenu
var _behaviour_menu: PopupPanel
var _tech_tree_menu: PopupPanel

var _sprite_folder: String = GameSettings.get_setting("iso_view", "sprite_folder")
var _button_size: float = GameSettings.get_setting("ui", "tool_button_size")
var _icon_size: int = GameSettings.get_setting("ui", "tool_icon_size")
var _tool_font_size: int = GameSettings.get_setting("ui", "tool_font_size")


## Builds the bar. Called by main.gd once everything exists.
func setup(view: Node2D, main: Node, brush: Node2D) -> void:
	_view = view
	_main = main
	var row := HBoxContainer.new()
	add_child(row)

	_pause_button = _bar_button("", null)
	_pause_button.pressed.connect(func() -> void: _view.is_paused = not _view.is_paused)
	row.add_child(_pause_button)
	row.add_child(VSeparator.new())

	var larva := _icon("larva")
	var hatch_one := _bar_button("Hatch 1", larva)
	hatch_one.pressed.connect(func() -> void: _view.target_colony().hatch(1))
	row.add_child(hatch_one)
	var hatch_five := _bar_button("Hatch 5", larva)
	hatch_five.pressed.connect(func() -> void: _view.target_colony().hatch(5))
	row.add_child(hatch_five)
	_infinite_button = _bar_button("Hatch all", larva)
	_infinite_button.toggle_mode = true
	_infinite_button.toggled.connect(func(on: bool) -> void: _view.target_colony().infinite_hatch = on)
	row.add_child(_infinite_button)
	row.add_child(_hatching_queue())
	row.add_child(VSeparator.new())

	_behaviour_menu = BehaviourMenu.new()
	add_child(_behaviour_menu)
	_behaviour_menu.setup(view)
	var behaviour := _bar_button("Behaviour", _icon("behaviour"))
	behaviour.pressed.connect(_behaviour_menu.open)
	row.add_child(behaviour)
	_tech_tree_menu = TechTreeMenu.new()
	add_child(_tech_tree_menu)
	_tech_tree_menu.setup(view, brush)
	var tech_tree := _bar_button("Tech tree", _icon("tech_tree"))
	tech_tree.pressed.connect(_tech_tree_menu.open)
	row.add_child(tech_tree)
	row.add_child(VSeparator.new())

	_status = Label.new()
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)
	var menu_button := _bar_button("Menu\n(%s)" % _keys("main_menu"), null)
	menu_button.pressed.connect(open_menu)
	row.add_child(menu_button)
	_build_menu()


func _process(_delta: float) -> void:
	if _view == null:
		return
	var sim: ColonySimulation = _view.simulation
	var colony: Colony = _view.target_colony()
	_pause_button.text = "%s\n(%s)" % ["Play" if _view.is_paused else "Pause", _keys("pause")]
	_infinite_button.set_pressed_no_signal(colony.infinite_hatch)
	_infinite_button.text = "Hatch all\n%s" % ("ON" if colony.infinite_hatch else "off")
	var next_level := sim.ants_for_next_maturity(colony)
	var maturity_text := "Maturity %d" % colony.maturity
	if next_level > 0:
		maturity_text += " (next at %d ants)" % next_level
	_status.text = "%s\nFood: %d   Ants: %d\n%s\nLarvae stored: %d" % [
		colony.name, colony.food_stored, colony.ant_count, maturity_text, colony.larvae]
	_hatching_bar.value = colony.hatch_progress()
	if colony.hatching == 0:
		_hatching_label.text = "Hatching\nnone"
	else:
		_hatching_label.text = "Hatching: %d\nnext in %.1f s" % [colony.hatching, colony.hatch_time_left]


## "Hatching: 3 / next in 1.2 s" over a bar that fills while the current larva hatches.
func _hatching_queue() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	_hatching_label = Label.new()
	_hatching_label.add_theme_font_size_override("font_size", _tool_font_size)
	column.add_child(_hatching_label)
	_hatching_bar = ProgressBar.new()
	_hatching_bar.max_value = 1.0
	_hatching_bar.show_percentage = false
	_hatching_bar.custom_minimum_size = Vector2(GameSettings.get_setting("ui", "hatching_bar_width"), GameSettings.get_setting("ui", "progress_bar_height"))
	column.add_child(_hatching_bar)
	return column


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

## A square bar button with an optional picture on top. Never takes keyboard focus (so
## Space still pauses instead of clicking it).
func _bar_button(text: String, picture: Texture2D) -> Button:
	var button := Button.new()
	button.text = text
	button.icon = picture
	button.expand_icon = picture != null
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(_button_size, _button_size)
	button.add_theme_font_size_override("font_size", _tool_font_size)
	button.add_theme_constant_override("icon_max_width", _icon_size)
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.add_click_animation(button)
	return button


func _icon(name: String) -> Texture2D:
	return load("%s/icons/%s.png" % [_sprite_folder, name])


## The key(s) of a [controls] action, for button texts.
func _keys(action: String) -> String:
	return ", ".join(GameSettings.get_list("controls", action))
