extends PanelContainer
## The tool bar under the map, organised like in management games. Square buttons with a
## picture and a name:
##
##   main page   Inspect | Food | Obstacles | Terrain | Nest | Erase | brush size
##   Food        Back | Blueberry, Strawberry, Seed, Larva, Dead spider...  (click the map to place)
##   Obstacles   Back | Rock, Twig, High grass, Pine cone, Dead leaf, Tree trunk...
##   Terrain     Back | Dirt, Grass, Water | brush size
##
## Food (an apple), Obstacles (a stop sign) and Terrain (mountains) turn the whole bar into
## that page; Back (or the Backspace key) returns. On those pages each button shows the
## thing itself (its sprite or tile). The food and obstacle kinds come from [objects].
## The game buttons (pause, save...) are in the side panel.

enum Page { MAIN, FOOD, OBSTACLES, TERRAIN }

## Terrain the Terrain page offers, with its button text.
const TERRAIN_CHOICES := {
	GroundMap.Type.DIRT: "Dirt",
	GroundMap.Type.GRASS: "Grass",
	GroundMap.Type.WATER: "Water",
}
## Main page icons, in sprites/icons/ (made by tools/make_art.py).
const ICON_FOLDER := "icons"

var _view: Node2D
var _brush: Node2D
var _row: HBoxContainer
var _page := Page.MAIN
var _choice_buttons := {}     ## what each button selects -> Button (on the current page)
var _brush_size_label: Label

var _sprite_folder: String = GameSettings.get_setting("iso_view", "sprite_folder")
var _tile_folder: String = GameSettings.get_setting("ground", "tile_image_folder")
var _button_size: float = GameSettings.get_setting("ui", "tool_button_size")
var _icon_size: int = GameSettings.get_setting("ui", "tool_icon_size")
var _tool_font_size: int = GameSettings.get_setting("ui", "tool_font_size")
var _small_button_size: float = GameSettings.get_setting("ui", "small_button_size")


## Builds the bar. Called by main.gd once everything exists.
func setup(view: Node2D, brush: Node2D) -> void:
	_view = view
	_brush = brush
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	_add_choice("inspect", "Inspect", "tool_inspect", _icon("inspect"), group, func() -> void: _pick_tool(_brush.Tool.INSPECT))
	_add_choice("food", "Food", "menu_food", _icon("food"), group, _open_page.bind(Page.FOOD))
	_add_choice("obstacles", "Obstacles", "menu_obstacles", _icon("obstacles"), group, _open_page.bind(Page.OBSTACLES))
	_add_choice("terrain", "Terrain", "menu_terrain", _icon("terrain"), group, _open_page.bind(Page.TERRAIN))
	_add_choice("nest", "Nest", "tool_nest", _icon("nest"), group, func() -> void: _pick_tool(_brush.Tool.NEST))
	_add_choice("erase", "Erase", "tool_erase", _icon("erase"), group, func() -> void: _pick_tool(_brush.Tool.ERASE))
	_add_brush_size()


func _build_sub_page(page: Page) -> void:
	var back := _tool_button("< Back", "toolbar_back", null)
	back.pressed.connect(_show_page.bind(Page.MAIN))
	_row.add_child(back)
	_row.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	if page == Page.TERRAIN:
		for type in TERRAIN_CHOICES:
			var tile: Texture2D = load("%s/%s.png" % [_tile_folder, GroundMap.TYPE_NAMES[type]])
			_add_choice(type, TERRAIN_CHOICES[type], "", tile, group, _pick_terrain.bind(type))
		_add_brush_size()
		_row.add_child(_label("Hold the left mouse button to paint."))
		return
	var kinds: ObjectKinds = _view.simulation.object_kinds
	for kind in _kinds_of_page(page):
		var picture: Texture2D = load("%s/objects/%s.png" % [_sprite_folder, kind])
		_add_choice(kind, kinds.label(kind), "", picture, group, _pick_object.bind(kind))
	_row.add_child(_label("Click on the map to place it.\nRight click erases."))


func _add_brush_size() -> void:
	_row.add_child(VSeparator.new())
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(_label("Brush size"))
	var row := HBoxContainer.new()
	var smaller := _small_button("-")
	smaller.pressed.connect(func() -> void: _brush.change_size(-1))
	row.add_child(smaller)
	_brush_size_label = _label("")
	_brush_size_label.custom_minimum_size.x = _small_button_size
	_brush_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_brush_size_label)
	var bigger := _small_button("+")
	bigger.pressed.connect(func() -> void: _brush.change_size(1))
	row.add_child(bigger)
	column.add_child(row)
	_row.add_child(column)


## A toggle button in `group`; `key` is what it selects (see _current_choice).
func _add_choice(key: Variant, text: String, action: String, picture: Texture2D, group: ButtonGroup, on_pressed: Callable) -> void:
	var button := _tool_button(text, action, picture)
	button.toggle_mode = true
	button.button_group = group
	button.pressed.connect(on_pressed)
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


# --- Buttons ---------------------------------------------------------------------------

## A square button: the picture on top, the name (and its key, if any) under it.
## It never takes keyboard focus (so Space still pauses instead of clicking it).
func _tool_button(text: String, action: String, picture: Texture2D) -> Button:
	var button := Button.new()
	button.text = text if action.is_empty() else "%s (%s)" % [text, _keys(action)]
	button.icon = _fit_icon(picture) if picture != null else null
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(_button_size, _button_size)
	button.add_theme_font_size_override("font_size", _tool_font_size)
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.add_click_animation(button)
	return button


func _small_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(_small_button_size, _small_button_size)
	button.focus_mode = Control.FOCUS_NONE
	UiTheme.add_click_animation(button)
	return button


## The picture scaled (keeping its shape, crisp pixels) to fit in a tool_icon_size square.
func _fit_icon(picture: Texture2D) -> Texture2D:
	var image := picture.get_image()
	var scale := float(_icon_size) / maxf(image.get_width(), image.get_height())
	image.resize(maxi(int(image.get_width() * scale), 1), maxi(int(image.get_height() * scale), 1), Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


func _icon(name: String) -> Texture2D:
	return load("%s/%s/%s.png" % [_sprite_folder, ICON_FOLDER, name])


## The key(s) of a [controls] action, for button texts.
func _keys(action: String) -> String:
	return ", ".join(GameSettings.get_list("controls", action))


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label
