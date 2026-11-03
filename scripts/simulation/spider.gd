class_name Spider
extends Creature
## A spider: comes in from the edge of the map, now and then, to feed. It never goes for
## the nest: it heads for a food source, and hunts the ants it sees on the way.
##
##   SEARCHING  Walks to a food item on the map (picked when it arrives). Starts hunting when
##              it sees an ant, eats when it reaches food. Gives up after search_give_up_time.
##   HUNTING    Chases the closest ant it sees; goes back to searching when it loses sight.
##   EATING     Standing on food, eating 1 unit every eat_interval seconds.
##   LEAVING    Full (appetite food eaten or ants_to_eat ants killed), or gave up: walks to
##              the nearest map edge and disappears there.
##
## While ants touch it, it stops and fights back (it is always an enemy). Killed, its body
## becomes a dead spider food item (food_when_killed plus what it ate).

enum State { SEARCHING, HUNTING, EATING, LEAVING }

var state := State.SEARCHING
var food_eaten := 0
var ants_eaten := 0
var _target_food := Vector2.INF   ## the food item it is heading for (INF = none left)


func _init(start: Vector2, creature_settings: CreatureSettings) -> void:
	super(start, creature_settings)


## Picks the food item it will head for (a random one), facing it.
func choose_target(sim: ColonySimulation) -> void:
	var food := sim.random_food_object()
	_target_food = food.position if food != null else Vector2.INF
	var aim := _target_food if food != null else sim.grid.world_size() / 2.0
	heading = (aim - position).angle()


func food_value() -> int:
	return int(settings.value("food_when_killed")) + food_eaten


func activity() -> String:
	return State.keys()[state].capitalize()


func is_walking() -> bool:
	return ants_in_contact.is_empty() and state != State.EATING


func _fight(sim: ColonySimulation, delta: float) -> Ant:
	var killed := super(sim, delta)
	if killed != null:
		ants_eaten += 1
		if ants_eaten >= int(settings.value("ants_to_eat")):
			_set_state(State.LEAVING)
	return killed


func _behave(sim: ColonySimulation, delta: float) -> void:
	match state:
		State.SEARCHING:
			_search(sim, delta)
		State.HUNTING:
			_hunt(sim, delta)
		State.EATING:
			_eat(sim)
		State.LEAVING:
			_leave_map(sim, settings.speed, delta)


func _search(sim: ColonySimulation, delta: float) -> void:
	if _time_in_state > float(settings.value("search_give_up_time")):
		_set_state(State.LEAVING)
		return
	if _food_under_body(sim) != MapGrid.NO_FOOD:
		_set_state(State.EATING)
		return
	if _ant_in_sight(sim) != null:
		_set_state(State.HUNTING)
		return
	var food := sim.grid.find_food_near(position, settings.value("food_sight_radius"))
	if food == MapGrid.NO_FOOD:
		if _target_food == Vector2.INF or sim.grid.find_food_near(_target_food, settings.radius) == MapGrid.NO_FOOD:
			choose_target(sim)  # its food item is gone: pick another one
		food = _target_food
	if food == Vector2.INF:
		_wander(sim, settings.speed, delta)
	else:
		_walk_towards(sim, food, settings.speed, delta)


func _hunt(sim: ColonySimulation, delta: float) -> void:
	var prey := _ant_in_sight(sim)
	if prey == null:
		_set_state(State.SEARCHING)
		return
	_walk_towards(sim, prey.position, settings.speed, delta)


func _eat(sim: ColonySimulation) -> void:
	if _time_in_state < float(settings.value("eat_interval")):
		return
	_time_in_state = 0.0
	var food := _food_under_body(sim)
	if food == MapGrid.NO_FOOD or not sim.take_food(food):
		_set_state(State.SEARCHING)  # this spot is empty, look for more
		return
	food_eaten += 1
	sim.food_eaten_by_spiders += 1
	if food_eaten >= int(settings.value("appetite")):
		_set_state(State.LEAVING)


func _ant_in_sight(sim: ColonySimulation) -> Ant:
	return sim.collisions.nearest_rival(position, settings.value("hunt_sight_radius"), -1)


func _set_state(new_state: State) -> void:
	state = new_state
	_time_in_state = 0.0


## Closest food the body is touching, or NO_FOOD.
func _food_under_body(sim: ColonySimulation) -> Vector2:
	return sim.grid.find_food_near(position, settings.radius)
