extends PanelContainer
## The panel on the right: level and timer, upgrade buttons, information about whatever
## the player clicked on with the Inspect tool, and colony statistics.

var _view: Node2D
var _header: Label
var _stats: Label
var _upgrade_buttons := {}    ## ColonyUpgrades.Kind -> Button
var _selection_info: Label


## Builds the panel. Called by main.gd once everything exists.
func setup(view: Node2D) -> void:
	_view = view
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	_header = _label()
	column.add_child(_header)

	column.add_child(HSeparator.new())
	column.add_child(_title("Upgrades (paid with food stored in the nest)"))
	for kind in ColonyUpgrades.Kind.values():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func() -> void: _view.simulation.buy_upgrade(kind))
		_upgrade_buttons[kind] = button
		column.add_child(button)

	column.add_child(HSeparator.new())
	column.add_child(_title("Selected (Inspect tool: click on anything)"))
	_selection_info = _label()
	column.add_child(_selection_info)

	column.add_child(HSeparator.new())
	column.add_child(_title("Colony"))
	_stats = _label()
	column.add_child(_stats)


func _process(_delta: float) -> void:
	if _view == null:
		return
	var sim: ColonySimulation = _view.simulation
	_header.text = "Level: %s\nTime: %s%s" % [sim.level.name, _format_time(_view.play_time), "   (PAUSED)" if _view.is_paused else ""]
	_stats.text = _colony_stats(sim)
	_update_upgrade_buttons(sim)
	_selection_info.text = _describe_selection(sim)


func _colony_stats(sim: ColonySimulation) -> String:
	var lines := PackedStringArray([
		"Food stored in nest: %d   (new ant: %d food every %.1f s)" % [sim.food_stored, sim.food_per_new_ant, sim.birth_interval()],
		"Food collected: %d   (%.2f per second)" % [sim.total_food_collected, sim.food_per_second()],
		"Food left on map: %d" % sim.grid.total_food,
		"",
		"Ants: %d  (%d scouts, %d collectors)" % [sim.ants.size(), sim.count_scouts(), sim.ants.size() - sim.count_scouts()],
	])
	for mode in Ant.Mode.values():
		lines.append("    %s: %d" % [_mode_name(mode), sim.count_ants_in_mode(mode)])
	lines.append("Born: %d   killed by enemies: %d   died of old age: %d" % [sim.ants_born, sim.ants_killed, sim.ants_died_of_old_age])
	lines.append("")
	lines.append("Spiders: %d here, %d killed, %d escaped (ate %d food)" % [sim.enemies.size(), sim.enemies_killed, sim.enemies_escaped, sim.food_eaten_by_enemies])
	return "\n".join(lines)


func _update_upgrade_buttons(sim: ColonySimulation) -> void:
	var upgrades := sim.upgrades
	for kind in _upgrade_buttons:
		var button: Button = _upgrade_buttons[kind]
		var level_text := "lv %d/%d" % [upgrades.level_of(kind), upgrades.max_level()]
		if upgrades.is_maxed(kind):
			button.text = "%s  (%s)  maxed" % [ColonyUpgrades.LABELS[kind], level_text]
			button.disabled = true
		else:
			button.text = "%s  (%s)  %s  -  %d food" % [ColonyUpgrades.LABELS[kind], level_text, upgrades.describe_bonus(kind), upgrades.cost(kind)]
			button.disabled = sim.food_stored < upgrades.cost(kind)


# --- Information about the selection -----------------------------------------

func _describe_selection(sim: ColonySimulation) -> String:
	var selected: Variant = _view.selection
	if selected is Ant:
		return _describe_ant(selected)
	if selected is Enemy:
		return _describe_enemy(selected)
	if selected is String and selected == _view.SELECTED_NEST:
		return _describe_nest(sim)
	if selected is Vector2i:
		return _describe_cell(sim, selected)
	return "Nothing selected."


func _describe_ant(ant: Ant) -> String:
	if ant.is_dead():
		return "This ant died%s." % (" of old age" if ant.died_of_old_age else " in a fight")
	var lines := PackedStringArray([
		"ANT (%s)" % ("scout" if ant.is_scout else "collector"),
		"Doing: %s" % _mode_name(ant.mode),
		"Health: %.0f / %.0f" % [ant.hp, ant.max_hp],
		"Carrying: %d food" % ant.carried_food,
		"Age: %s of %s lifespan" % [_format_time(ant.age), _format_time(ant.lifespan)],
		"Will to fight: %.2f  (%s)" % [ant.fight_will, _will_description(ant)],
		"Explores up to %.0f s before going home" % ant.max_explore_time,
		"Position: %.0f, %.0f" % [ant.position.x, ant.position.y],
	])
	if ant.fight_target != null:
		lines.append("Fighting an enemy with %.0f health left" % ant.fight_target.hp)
	return "\n".join(lines)


func _will_description(ant: Ant) -> String:
	var settings: AntSettings = _view.simulation.ant_settings
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


func _describe_nest(sim: ColonySimulation) -> String:
	return "\n".join(PackedStringArray([
		"NEST",
		"Food stored: %d" % sim.food_stored,
		"Next birth in %.1f s (needs %d food)" % [maxf(sim.time_until_birth, 0.0), sim.food_per_new_ant],
		"Ants: %d" % sim.ants.size(),
		"Size: %.0f px radius, %d tiles (grows with the colony)" % [sim.nest_radius, sim.nest_tile_count()],
		"Position: %.0f, %.0f" % [sim.nest_position.x, sim.nest_position.y],
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
		"Pheromones:  going out %.2f   going home %.2f   fight %.2f" % [grid.going_out[index], grid.going_home[index], grid.fight[index]],
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


func _title(text: String) -> Label:
	var label := _label()
	label.text = text
	label.add_theme_color_override("font_color", Color.WHITE)
	return label
