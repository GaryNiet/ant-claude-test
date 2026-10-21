extends PanelContainer
## The panel on the right: the building / testing tools and all the data.
##   - building tools: inspect, place food and obstacles, paint terrain, move the nest, erase
##     (see paint_tools.gd)
##   - debug buttons: fit map, isometric / debug view, show / hide trails
##   - level and timer, information about whatever the player clicked on with the Inspect
##     tool, and colony statistics (our colony, or a rival colony while its nest is selected)
## (The gameplay buttons, upgrades, pause and the menu, are in the bar under the map.)

const PaintTools := preload("res://scripts/ui/paint_tools.gd")

var _view: Node2D
var _view_button: Button
var _trails_button: Button
var _stats_title: Label
var _header: Label
var _stats: Label
var _selection_info: Label


## Builds the panel. Called by main.gd once everything exists.
func setup(view: Node2D, brush: Node2D) -> void:
	_view = view
	var outer := VBoxContainer.new()
	add_child(outer)
	outer.add_child(_title("Building tools"))
	var tools := PaintTools.new()
	outer.add_child(tools)
	tools.setup(view, brush)
	outer.add_child(_debug_buttons())
	outer.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	_header = _label()
	column.add_child(_header)

	column.add_child(HSeparator.new())
	column.add_child(_title("Selected (Inspect tool: click on anything)"))
	_selection_info = _label()
	column.add_child(_selection_info)

	column.add_child(HSeparator.new())
	_stats_title = _title("")
	column.add_child(_stats_title)
	_stats = _label()
	column.add_child(_stats)


## Fit map, isometric / debug view, show / hide trails.
func _debug_buttons() -> HBoxContainer:
	var row := HBoxContainer.new()
	_view_button = _button("", func() -> void: _view.set_iso_view(not _view.is_iso_view))
	_trails_button = _button("", func() -> void: _view.set_pheromones_visible(not _view.show_pheromones))
	for button in [_button("Fit map", _view.fit_map_to_area), _view_button, _trails_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


func _process(_delta: float) -> void:
	if _view == null:
		return
	var sim: ColonySimulation = _view.simulation
	var colony: Colony = _view.target_colony()
	_view_button.text = "%s view (%s)" % ["Debug" if _view.is_iso_view else "Iso", _keys("toggle_view")]
	_trails_button.text = "%s trails (%s)" % ["Hide" if _view.show_pheromones else "Show", _keys("toggle_pheromones")]
	_header.text = "Level: %s\nTime: %s%s" % [sim.level.name, _format_time(_view.play_time), "   (PAUSED)" if _view.is_paused else ""]
	_stats_title.text = colony.name
	_stats.text = _colony_stats(sim, colony)
	_selection_info.text = _describe_selection(sim)


func _colony_stats(sim: ColonySimulation, colony: Colony) -> String:
	var scouts := sim.count_scouts(colony)
	var lines := PackedStringArray([
		"Food stored in nest: %d   (a larva: %d food every %.1f s)" % [colony.food_stored, sim.food_per_larva, colony.larva_interval(sim.tech_tree)],
		"Larvae: %d stored, %d hatching%s   Maturity: %d" % [colony.larvae, colony.hatching.size(), "  (hatch all)" if colony.infinite_hatch else "", colony.maturity],
		"Upgrades owned: %d of %d   Nest health: %.0f / %.0f" % [colony.techs.size(), sim.tech_tree.nodes.size(), colony.hp, colony.max_hp],
		"Food collected: %d   (%.2f per second)" % [colony.total_food_collected, colony.food_per_second(sim.elapsed_time)],
		"Food left on map: %d" % sim.grid.total_food,
		"",
		"Ants: %d  (%d scouts, %d collectors)" % [colony.ant_count, scouts, colony.ant_count - scouts],
	])
	for mode in Ant.Mode.values():
		lines.append("    %s: %d" % [_mode_name(mode), sim.count_ants_in_mode(colony, mode)])
	lines.append("Born: %d   killed in fights: %d   died of old age: %d   larvae stolen by raiders: %d" % [colony.ants_born, colony.ants_killed, colony.ants_died_of_old_age, colony.larvae_stolen])
	lines.append("")
	lines.append("Spiders: %d here, %d killed, %d escaped (ate %d food)" % [sim.enemies.size(), sim.enemies_killed, sim.enemies_escaped, sim.food_eaten_by_enemies])
	return "\n".join(lines)


# --- Information about the selection -----------------------------------------

func _describe_selection(sim: ColonySimulation) -> String:
	var selected: Variant = _view.selection
	if selected is Ant:
		return _describe_ant(selected)
	if selected is Enemy:
		return _describe_enemy(selected)
	if selected is MapObject:
		return _describe_object(sim, selected)
	if selected is Colony:
		return _describe_nest(sim, selected)
	if selected is Vector2i:
		return _describe_cell(sim, selected)
	return "Nothing selected."


func _describe_ant(ant: Ant) -> String:
	if ant.is_dead():
		return "This ant died%s." % (" of old age" if ant.died_of_old_age else " in a fight")
	var lines := PackedStringArray([
		"%s (%s) of %s" % ["MAJOR ANT" if ant.is_major else "ANT", "scout" if ant.is_scout else "collector", ant.colony.name],
		"Doing: %s" % _mode_name(ant.mode),
		"Health: %.0f / %.0f" % [ant.hp, ant.max_hp],
		"Carrying: %d food" % ant.carried_food,
		"Age: %s of %s lifespan" % [_format_time(ant.age), _format_time(ant.lifespan)],
		"Will to fight: %.2f  (%s)" % [ant.fight_will, _will_description(ant)],
		"Explores up to %.0f s before going home" % ant.max_explore_time,
		"Position: %.0f, %.0f" % [ant.position.x, ant.position.y],
	])
	if ant.fight_target != null:
		var foe := "a rival ant" if ant.fight_target is Ant else "a spider"
		lines.append("Fighting %s with %.0f health left" % [foe, ant.fight_target.hp])
	return "\n".join(lines)


func _will_description(ant: Ant) -> String:
	var settings: AntSettings = ant.colony.ant_settings
	if ant.fight_will >= settings.join_fight_will:
		return "looks for fights"
	if ant.fight_will >= settings.contact_fight_will:
		return "fights enemies it bumps into"
	return "only fights back"


func _describe_enemy(enemy: Enemy) -> String:
	if enemy.is_dead():
		return "This spider was killed and turned into food."
	if enemy.has_left_the_map:
		return "This spider escaped with %d food." % enemy.food_eaten
	var state_name: String = Enemy.State.keys()[enemy.state].capitalize()
	return "\n".join(PackedStringArray([
		"SPIDER (enemy)",
		"Doing: %s%s" % [state_name, " (fighting %d ants)" % enemy.ants_in_contact.size() if not enemy.ants_in_contact.is_empty() else ""],
		"Health: %.0f / %.0f" % [enemy.hp, enemy.max_hp],
		"Food eaten: %d" % enemy.food_eaten,
		"Position: %.0f, %.0f" % [enemy.position.x, enemy.position.y],
	]))


func _describe_object(sim: ColonySimulation, object: MapObject) -> String:
	if not sim.objects.has(object):
		return "This %s is gone%s." % [sim.object_kinds.label(object.kind).to_lower(), " (eaten)" if object.is_food() else ""]
	var lines := PackedStringArray([
		"%s (%s)" % [sim.object_kinds.label(object.kind).to_upper(), "food" if object.is_food() else "obstacle"],
		"Covers %d cells" % object.cells.size(),
		"Position: %.0f, %.0f" % [object.position.x, object.position.y],
	])
	if object.is_food():
		lines.insert(1, "Food left: %d of %d" % [object.food_left, object.total_food])
	return "\n".join(lines)


func _describe_nest(sim: ColonySimulation, colony: Colony) -> String:
	return "\n".join(PackedStringArray([
		"NEST of %s%s" % [colony.name, "" if colony.is_player else "  (the buttons below the map now act on this colony)"],
		"Food stored: %d" % colony.food_stored,
		"Next larva in %.1f s (needs %d food); %d larvae stored, %d hatching" % [maxf(colony.time_until_larva, 0.0), sim.food_per_larva, colony.larvae, colony.hatching.size()],
		"Nest health: %.0f / %.0f%s" % [colony.hp, colony.max_hp, "  (DESTROYED)" if colony.destroyed else ""],
		"Ants: %d" % colony.ant_count,
		"Size: %.0f px radius, %d tiles (grows with the colony)" % [colony.nest_radius, sim.nest_tile_count(colony)],
		"Position: %.0f, %.0f" % [colony.nest_position.x, colony.nest_position.y],
	]))


func _describe_cell(sim: ColonySimulation, cell: Vector2i) -> String:
	var grid := sim.grid
	var index := cell.y * grid.width + cell.x
	var tile := Vector2i(cell.x / sim.ground.tile_cells, cell.y / sim.ground.tile_cells)
	var ground_name: String = GroundMap.TYPE_NAMES[sim.ground.type_at(tile.x, tile.y)]
	return "\n".join(PackedStringArray([
		"MAP CELL %d, %d  (tile %d, %d)" % [cell.x, cell.y, tile.x, tile.y],
		"Ground: %s%s" % [ground_name.capitalize(), "" if sim.ground.is_walkable(tile.x, tile.y) else " (can't be walked on)"],
		"Food: %d" % grid.food[index],
		"Our trails:  going out %.2f   going home %.2f   fight %.2f" % [grid.going_out[index], grid.going_home[index], grid.fight[index]],
		"Path wear: %.1f / %.1f%s" % [grid.path_wear[index], grid.unobstructed_wear, "  (unobstructed: ants walk faster)" if grid.path_wear[index] >= grid.unobstructed_wear else ""],
	]))


# --- Helpers ------------------------------------------------------------------

func _mode_name(mode: int) -> String:
	return Ant.Mode.keys()[mode].capitalize()


func _format_time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## A button that never takes keyboard focus (so Space still pauses instead of clicking it).
func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	UiTheme.add_click_animation(button)
	return button


## The key(s) of a [controls] action, for button texts.
func _keys(action: String) -> String:
	return ", ".join(GameSettings.get_list("controls", action))


func _title(text: String) -> Label:
	var label := _label()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	return label
