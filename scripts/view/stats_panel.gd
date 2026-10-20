extends Label
## Text in the top-left corner showing live numbers about the simulation.

var view: Node  ## the SimulationView, set by main.gd


func _ready() -> void:
	add_theme_font_size_override("font_size", GameSettings.get_setting("display", "hud_font_size"))
	add_theme_color_override("font_color", GameSettings.get_color("colors", "hud_text"))


func _process(_delta: float) -> void:
	if view == null or view.simulation == null:
		return
	var sim: ColonySimulation = view.simulation
	var lines := PackedStringArray([
		"Time: %d s%s" % [int(sim.elapsed_time), "   (PAUSED)" if view.is_paused else ""],
		"Food collected: %d" % sim.total_food_collected,
		"Food per second: %.2f" % sim.food_per_second(),
		"Food left on map: %d in %d piles" % [sim.food_left_on_map(), sim.food_sources.size()],
		"",
		"Ants: %d" % sim.ants.size(),
		"  exploring: %d" % sim.count_ants_in_mode(Ant.Mode.EXPLORING),
		"  gathering: %d" % sim.count_ants_in_mode(Ant.Mode.GATHERING),
		"  carrying food: %d" % sim.count_ants_in_mode(Ant.Mode.CARRYING_FOOD),
		"  returning home: %d" % sim.count_ants_in_mode(Ant.Mode.RETURNING_HOME),
		"",
		_controls_help(),
	])
	text = "\n".join(lines)


## e.g. "pause: Space, P   restart: R", built from the [controls] settings.
func _controls_help() -> String:
	var parts := PackedStringArray()
	for action in GameSettings.get_keys("controls"):
		parts.append("%s: %s" % [action, ", ".join(GameSettings.get_list("controls", action))])
	return "   ".join(parts)
