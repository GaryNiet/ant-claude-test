extends PanelContainer
## The gameplay bar under the map:
##
##   Pause | Lay 1, Lay 5, laying queue | Hatch 1, Hatch 5, Auto hatch, hatching queue |
##   Focus | Behaviour, Tech tree | food, ants, maturity, larvae | Menu
##
## Lay buttons spend food_per_larva food per larva; larvae are laid one after the other
## (the laying queue shows how many and a bar that fills until the next one is laid).
## The hatch buttons put stored larvae in the hatching queue (Auto hatch is a toggle, on at
## the start: every larva joins the queue as soon as it is laid); they also hatch one after
## the other, with their own bar. Focus picks the Focus tool: click the map to send the
## attack ants there. Behaviour opens sliders for the colony's ants; Tech tree opens the
## upgrades. They act on our colony, or on a rival colony while its nest is selected (see
## SimulationView.target_colony). The Menu button opens: Restart level, Save level, Load
## level, Settings, Main menu.
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
var _brush: Node2D
var _pause_button: Button
var _lay_one: Button
var _lay_five: Button
var _infinite_button: Button
var _focus_button: Button
var _laying_label: Label
var _laying_bar: ProgressBar
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
	_brush = brush
	var row := HBoxContainer.new()
	add_child(row)

	_pause_button = _bar_button("", null)
	_pause_button.pressed.connect(func() -> void: _view.is_paused = not _view.is_paused)
	row.add_child(_pause_button)
	row.add_child(VSeparator.new())

	var egg := _icon("lay")
	_lay_one = _bar_button("", egg)
	_lay_one.pressed.connect(lay.bind(1))
	row.add_child(_lay_one)
	_lay_five = _bar_button("", egg)
	_lay_five.pressed.connect(lay.bind(5))
	row.add_child(_lay_five)
	var laying := _queue_column()
	_laying_label = laying.label
	_laying_bar = laying.bar
	row.add_child(laying.column)
	row.add_child(VSeparator.new())

	var larva := _icon("larva")
	var hatch_one := _bar_button("Hatch 1", larva)
	hatch_one.pressed.connect(func() -> void: _view.target_colony().hatch(1))
	row.add_child(hatch_one)
	var hatch_five := _bar_button("Hatch 5", larva)
	hatch_five.pressed.connect(func() -> void: _view.target_colony().hatch(5))
	row.add_child(hatch_five)
	_infinite_button = _bar_button("Auto hatch", larva)
	_infinite_button.toggle_mode = true
	_infinite_button.toggled.connect(func(on: bool) -> void: _view.target_colony().infinite_hatch = on)
	row.add_child(_infinite_button)
	var hatching := _queue_column()
	_hatching_label = hatching.label
	_hatching_bar = hatching.bar
	row.add_child(hatching.column)
	row.add_child(VSeparator.new())

	_focus_button = _bar_button("Focus (%s)" % _keys("tool_focus"), _icon("focus"))
	_focus_button.toggle_mode = true
	_focus_button.toggled.connect(_on_focus_toggled)
	row.add_child(_focus_button)
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


## Lays `count` larvae of the colony the bar acts on (as many as its food allows).
func lay(count: int) -> void:
	_view.simulation.lay_larvae(_view.target_colony(), count)


func _unhandled_input(event: InputEvent) -> void:
	if _view == null:
		return
	if event.is_action_pressed("tool_focus"):
		_focus_button.button_pressed = not _focus_button.button_pressed
	elif event.is_action_pressed("lay_larva"):
		lay(1)


## The Focus button picks the Focus tool (pressed again: back to Inspect).
func _on_focus_toggled(on: bool) -> void:
	if on:
		_brush.selected_tool = _brush.Tool.FOCUS
	elif _brush.selected_tool == _brush.Tool.FOCUS:
		_brush.selected_tool = _brush.Tool.INSPECT


func _process(_delta: float) -> void:
	if _view == null:
		return
	var sim: ColonySimulation = _view.simulation
	var colony: Colony = _view.target_colony()
	_pause_button.text = "%s\n(%s)" % ["Play" if _view.is_paused else "Pause", _keys("pause")]
	_focus_button.set_pressed_no_signal(_brush.selected_tool == _brush.Tool.FOCUS)
	_lay_one.text = "Lay 1 (%s)\n%d food" % [_keys("lay_larva"), sim.food_per_larva]
	_lay_five.text = "Lay 5\n%d food" % (5 * sim.food_per_larva)
	_lay_one.disabled = colony.food_stored < sim.food_per_larva
	_lay_five.disabled = colony.food_stored < sim.food_per_larva
	_laying_bar.value = colony.lay_progress(sim.tech_tree)
	if colony.laying == 0:
		_laying_label.text = "Laying\nnone"
	else:
		_laying_label.text = "Laying: %d\nnext in %.1f s" % [colony.laying, colony.lay_time_left]
	_infinite_button.set_pressed_no_signal(colony.infinite_hatch)
	_infinite_button.text = "Auto hatch\n%s" % ("ON" if colony.infinite_hatch else "off")
	var next_level := sim.ants_for_next_maturity(colony)
	var maturity_text := "Maturity %d" % colony.maturity
	if next_level > 0:
		maturity_text += " (%d at %d ants)" % [colony.maturity + 1, next_level]
	_status.text = "%s\nFood: %d   Ants: %d\n%s\nLarvae stored: %d" % [
		colony.name, colony.food_stored, colony.ant_count, maturity_text, colony.larvae]
	_hatching_bar.value = colony.hatch_progress()
	if colony.hatching == 0:
		_hatching_label.text = "Hatching\nnone"
	else:
		_hatching_label.text = "Hatching: %d\nnext in %.1f s" % [colony.hatching, colony.hatch_time_left]


## A queue display: "Hatching: 3 / next in 1.2 s" over a bar that fills while the first
## one in the queue is on its way. Returns {column, label, bar}.
func _queue_column() -> Dictionary:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	var label := Label.new()
	label.add_theme_font_size_override("font_size", _tool_font_size)
	column.add_child(label)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(GameSettings.get_setting("ui", "queue_bar_width"), GameSettings.get_setting("ui", "progress_bar_height"))
	column.add_child(bar)
	return {column = column, label = label, bar = bar}


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
