extends PopupPanel
## The Tech tree menu (from the gameplay bar): the upgrades, bought with food stored in the
## nest. One column per vocation (fighting, hatching, harvesting), one row per maturity
## level. In each box, the first node of the small tree comes first and the nodes that need
## it are indented under it. A button is:
##   pushed in   owned
##   normal      can be bought now (click to buy)
##   greyed out  not yet: the button says why (maturity, a node needed first, or food)
## Acts on SimulationView.target_colony. Buying Nuptial flights switches the brush to
## placing the new allied nest.

var _view: Node2D
var _brush: Node2D
var _title: Label
var _buttons := {}   ## node -> Button


func setup(view: Node2D, brush: Node2D) -> void:
	_view = view
	_brush = brush
	theme = UiTheme.make()
	UiTheme.close_on_right_click(self)
	var column := VBoxContainer.new()
	add_child(column)
	_title = Label.new()
	column.add_child(_title)
	column.add_child(HSeparator.new())
	column.add_child(_build_grid())
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	UiTheme.add_click_animation(close)
	column.add_child(close)


## Header row with the vocations, then one row per maturity level.
func _build_grid() -> GridContainer:
	var tree: TechTree = _view.simulation.tech_tree
	var grid := GridContainer.new()
	grid.columns = tree.vocations.size() + 1
	grid.add_theme_constant_override("h_separation", GameSettings.get_setting("ui", "tech_column_gap"))
	grid.add_child(Label.new())
	for vocation in tree.vocations:
		var header := Label.new()
		header.text = vocation.capitalize()
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(header)
	for level in range(1, _view.simulation.max_maturity() + 1):
		var row_title := Label.new()
		row_title.text = "Maturity %d" % level
		grid.add_child(row_title)
		for vocation in tree.vocations:
			grid.add_child(_tree_box(tree, vocation, level))
	return grid


## The nodes of one vocation and maturity level: the ones that need another node of the box
## are indented under it.
func _tree_box(tree: TechTree, vocation: String, level: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	var nodes := tree.nodes_in(vocation, level)
	for node in nodes:
		var button := Button.new()
		button.custom_minimum_size.x = GameSettings.get_setting("ui", "tech_button_width")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = tree.description(node)
		button.pressed.connect(_buy.bind(node))
		UiTheme.add_click_animation(button)
		var indent := MarginContainer.new()
		var needs_one_of_this_box := false
		for needed in tree.requires(node):
			if needed in nodes:
				needs_one_of_this_box = true
		indent.add_theme_constant_override("margin_left", GameSettings.get_setting("ui", "tech_indent") if needs_one_of_this_box else 0)
		indent.add_child(button)
		box.add_child(indent)
		_buttons[node] = button
	return box


func open() -> void:
	_refresh()
	popup_centered()


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	var tree: TechTree = _view.simulation.tech_tree
	var colony: Colony = _view.target_colony()
	_title.text = "Tech tree of %s   (food stored: %d, maturity %d)   Hover a node to read what it does." % [colony.name, colony.food_stored, colony.maturity]
	for node in _buttons:
		var button: Button = _buttons[node]
		var reason := tree.why_not(colony, node)
		button.set_pressed_no_signal(reason == "owned")
		button.disabled = reason != "" and reason != "owned"
		var state := "owned" if reason == "owned" else ("%d food" % tree.cost(node) if reason == "" else reason)
		button.text = "%s\n%s" % [tree.label(node), state]


func _buy(node: String) -> void:
	var colony: Colony = _view.target_colony()
	if _view.simulation.buy_tech(colony, node) and node == "nuptial_flights":
		_brush.selected_tool = _brush.Tool.FOUND_NEST
		hide()
	_refresh()
