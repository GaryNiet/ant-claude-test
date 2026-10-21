extends PanelContainer
## The bar at the top of the window, organised like in management games:
##
##   main page   Inspect | Food > | Obstacles > | Terrain > | Nest | Erase | brush size |
##               pause, restart, fit map, view, trails | save, load | settings, menu
##   Food        Back | Blueberry, Strawberry, Seed, Larva, Dead spider...  (click the map to place)
##   Obstacles   Back | Rock, Twig, High grass, Pine cone, Dead leaf, Tree trunk...
##   Terrain     Back | Dirt, Grass, Water | brush size
##
## Clicking Food, Obstacles or Terrain turns the whole bar into that page; Back (or the
## Backspace key) returns to the main page. The food and obstacle kinds come from [objects].

enum Page { MAIN, FOOD, OBSTACLES, TERRAIN }

## Terrain the Terrain page offers, with its button text.
const TERRAIN_CHOICES := {
	GroundMap.Type.DIRT: "Dirt",
	GroundMap.Type.GRASS: "Grass",
	GroundMap.Type.WATER: "Water",
}

var _view: Node2D
var _brush: Node2D
var _main: Node
var _row: HBoxContainer
var _page := Page.MAIN
var _choice_buttons := {}     ## what each button selects -> Button (on the current page)
var _brush_size_label: Label
var _pause_button: Button
var _view_button: Button
var _trails_button: Button


## Builds the bar. Called by main.gd once everything exists.
func setup(view: Node2D, brush: Node2D, main: Node) -> void:
	_view = view
	_brush = brush
	_main = main
	_row = HBoxContainer.new()
	add_child(_row)
	_show_page(Page.MAIN)


func _unhandled_input(event: InputEvent) -> void:
	if _view == null:
		return
	if event.is_action_pressed("tool_inspect"):
		_pick_tool(_brush.Tool.INSPECT)
	elif event.is_action_pressed("tool_nest"):
		_pick_tool(_brush.Tool.NEST)
	elif event.is_action_pressed("tool_erase"):
		_pick_tool(_brush.Tool.ERASE)
	elif event.is_action_pressed("menu_food"):
		_open_page(Page.FOOD)
	elif event.is_action_pressed("menu_obstacles"):
		_open_page(Page.OBSTACLES)
	elif event.is_action_pressed("menu_terrain"):
		_open_page(Page.TERRAIN)
	elif event.is_action_pressed("toolbar_back"):
		_show_page(Page.MAIN)


func _process(_delta: float) -> void:
	if _view == null:
		return
	if _brush_size_label != null:
		_brush_size_label.text = "%d" % _brush.radius
	if _page == Page.MAIN:
		_pause_button.text = "Resume" if _view.is_paused else "Pause"
		_view_button.text = "%s view (%s)" % ["Debug" if _view.is_iso_view else "Iso", _keys("toggle_view")]
		_trails_button.text = "%s trails (%s)" % ["Hide" if _view.show_pheromones else "Show", _keys("toggle_pheromones")]
	var current: Variant = _current_choice()
	if _choice_buttons.has(current):
		_choice_buttons[current].button_pressed = true  # follows keyboard shortcuts too


## What is selected right now, as the key of the button that selects it: on the main page
## "inspect", "food", "obstacles", "terrain", "nest" or "erase"; on the other pages the
## object kind or the terrain type.
func _current_choice() -> Variant:
	match _brush.selected_tool:
		_brush.Tool.PLACE:
			if _page != Page.MAIN:
				return _brush.object_kind
			return "food" if _brush.object_kind in _view.simulation.object_kinds.food_kinds else "obstacles"
		_brush.Tool.TERRAIN:
			return _brush.ground_type if _page == Page.TERRAIN else "terrain"
		_brush.Tool.NEST:
			return "nest"
		_brush.Tool.ERASE:
			return "erase"
	return "inspect"


# --- Pages ----------------------------------------------------------------------

## Opens a page and selects its first choice if the brush isn't already on that page.
func _open_page(page: Page) -> void:
	_show_page(page)
	var kinds := _kinds_of_page(page)
	if page == Page.TERRAIN and _brush.selected_tool != _brush.Tool.TERRAIN:
		_pick_terrain(TERRAIN_CHOICES.keys()[0])
	elif not kinds.is_empty() and not (_brush.selected_tool == _brush.Tool.PLACE and _brush.object_kind in kinds):
		_pick_object(kinds[0])


func _kinds_of_page(page: Page) -> PackedStringArray:
	var kinds: ObjectKinds = _view.simulation.object_kinds
	if page == Page.FOOD:
		return kinds.food_kinds
	if page == Page.OBSTACLES:
		return kinds.obstacle_kinds
	return PackedStringArray()


func _show_page(page: Page) -> void:
	_page = page
	for child in _row.get_children():
		child.queue_free()
	_choice_buttons.clear()
	_brush_size_label = null
	if page == Page.MAIN:
		_build_main_page()
	else:
		_build_sub_page(page)


func _build_main_page() -> void:
	var group := ButtonGroup.new()
	_add_choice("inspect", "%s Inspect" % _keys("tool_inspect"), group, func() -> void: _pick_tool(_brush.Tool.INSPECT))
	_add_choice("food", "%s Food >" % _keys("menu_food"), group, _open_page.bind(Page.FOOD))
	_add_choice("obstacles", "%s Obstacles >" % _keys("menu_obstacles"), group, _open_page.bind(Page.OBSTACLES))
	_add_choice("terrain", "%s Terrain >" % _keys("menu_terrain"), group, _open_page.bind(Page.TERRAIN))
	_add_choice("nest", "%s Nest" % _keys("tool_nest"), group, func() -> void: _pick_tool(_brush.Tool.NEST))
	_add_choice("erase", "%s Erase" % _keys("tool_erase"), group, func() -> void: _pick_tool(_brush.Tool.ERASE))
	_add_brush_size()

	_row.add_child(VSeparator.new())
	_pause_button = _button("Pause", func() -> void: _view.is_paused = not _view.is_paused)
	_row.add_child(_pause_button)
	_row.add_child(_button("Restart", _view.restart_level))
	_row.add_child(_button("Fit map", _view.fit_map_to_area))
	_view_button = _button("", func() -> void: _view.set_iso_view(not _view.is_iso_view))
	_row.add_child(_view_button)
	_trails_button = _button("", func() -> void: _view.set_pheromones_visible(not _view.show_pheromones))
	_row.add_child(_trails_button)

	_row.add_child(VSeparator.new())
	_row.add_child(_button("Save level", _main.open_save_dialog))
	_row.add_child(_button("Load level", _main.open_load_dialog))

	_row.add_child(VSeparator.new())
	_row.add_child(_button("Settings", _main.open_settings_menu))
	_row.add_child(_button("Menu (%s)" % _keys("main_menu"), _main.go_to_main_menu))


func _build_sub_page(page: Page) -> void:
	_row.add_child(_button("< Back (%s)" % _keys("toolbar_back"), _show_page.bind(Page.MAIN)))
	_row.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	if page == Page.TERRAIN:
		_row.add_child(_label("Terrain:"))
		for type in TERRAIN_CHOICES:
			_add_choice(type, TERRAIN_CHOICES[type], group, _pick_terrain.bind(type))
		_add_brush_size()
		_row.add_child(_label("   Hold the left mouse button to paint."))
		return
	_row.add_child(_label("Food:" if page == Page.FOOD else "Obstacles:"))
	for kind in _kinds_of_page(page):
		_add_choice(kind, _view.simulation.object_kinds.label(kind), group, _pick_object.bind(kind))
	_row.add_child(_label("   Click on the map to place it. Right click erases."))


func _add_brush_size() -> void:
	_row.add_child(VSeparator.new())
	_row.add_child(_label("Brush:"))
	_row.add_child(_button("-", func() -> void: _brush.change_size(-1)))
	_brush_size_label = _label("")
	_row.add_child(_brush_size_label)
	_row.add_child(_button("+", func() -> void: _brush.change_size(1)))


## A toggle button in `group`; `key` is what it selects (see _current_choice).
func _add_choice(key: Variant, text: String, group: ButtonGroup, on_pressed: Callable) -> void:
	var button := _button(text, on_pressed)
	button.toggle_mode = true
	button.button_group = group
	_choice_buttons[key] = button
	_row.add_child(button)


# --- Choosing a tool ----------------------------------------------------------------

func _pick_tool(tool: int) -> void:
	_brush.selected_tool = tool


func _pick_object(kind: String) -> void:
	_brush.selected_tool = _brush.Tool.PLACE
	_brush.object_kind = kind


func _pick_terrain(type: GroundMap.Type) -> void:
	_brush.selected_tool = _brush.Tool.TERRAIN
	_brush.ground_type = type


# --- Helpers -------------------------------------------------------------------------

## The key(s) of a [controls] action, for button texts.
func _keys(action: String) -> String:
	return ", ".join(GameSettings.get_list("controls", action))


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
