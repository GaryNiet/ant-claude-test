class_name Ant
extends RefCounted
## One ant. Every tick it senses its surroundings, decides which way to turn,
## walks forward and (depending on its mode) lays pheromone behind it.
##
## The four modes:
##   EXPLORING      Wanders towards places other ants haven't been (where the
##                  "going out" smell is weakest). Lays a "going out" trail.
##   GATHERING      Knows food exists: walks straight to food it can see, otherwise
##                  follows the "going home" trail (left by food carriers) towards
##                  stronger smell, which leads back to the food. Gives up and goes
##                  home if it doesn't reach food in time (e.g. the pile ran out).
##   CARRYING_FOOD  Walks home by following "going out" trails backwards (towards
##                  stronger smell, which is near the nest), with a growing push
##                  towards the nest if it's struggling. Lays a "going home" trail.
##   RETURNING_HOME Gave up exploring without finding food. Walks home the same way
##                  as a food carrier, but lays no trail.
##
## Personality (picked at random when the ant is born):
##   Collector  Focused on collecting: as soon as it smells a food trail it follows it,
##              and after delivering food it goes straight back for more.
##              Some collectors are "homebodies" that only explore briefly near the nest.
##   Scout      Focused on exploring: ignores food trails and keeps looking for new places.
##              It only collects food it finds itself (which starts a new trail for the
##              collectors), then goes back to exploring.
##
## Why trails can be followed "backwards": an ant lays less pheromone the longer it
## has been walking, so every trail is strongest near where it started.

enum Mode { EXPLORING, GATHERING, CARRYING_FOOD, RETURNING_HOME }

var position: Vector2
var heading: float              ## direction of travel in radians (0 = right, PI/2 = down)
var mode := Mode.EXPLORING
var is_scout: bool              ## personality: true = scout, false = collector
var max_explore_time: float     ## personality: seconds of exploring before giving up
var time_in_mode := 0.0
var time_since_trail_start := 0.0  ## seconds since leaving the nest or picking up food

var _settings: AntSettings


func _init(start: Vector2, settings: AntSettings, rng: RandomNumberGenerator) -> void:
	position = start
	_settings = settings
	heading = rng.randf() * TAU
	is_scout = rng.randf() < settings.scout_fraction
	if not is_scout and rng.randf() < settings.homebody_fraction:
		max_explore_time = rng.randf_range(settings.homebody_min_explore_time, settings.homebody_max_explore_time)
	else:
		max_explore_time = rng.randf_range(settings.explorer_min_explore_time, settings.explorer_max_explore_time)


func is_carrying_food() -> bool:
	return mode == Mode.CARRYING_FOOD


## Advances the ant by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	time_in_mode += delta
	time_since_trail_start += delta

	# Each mode returns how much to turn: -1 = full left, 0 = straight, +1 = full right.
	var turn := 0.0
	match mode:
		Mode.EXPLORING:
			turn = _explore(sim)
		Mode.GATHERING:
			turn = _gather(sim)
		Mode.CARRYING_FOOD, Mode.RETURNING_HOME:
			turn = _go_home(sim)

	heading += clampf(turn, -1.0, 1.0) * _settings.turn_speed * delta
	heading += sim.rng.randf_range(-1.0, 1.0) * _settings.wander * delta
	_move_forward(sim, delta)
	_lay_trail(sim, delta)
	_check_arrival_at_nest(sim)


# --- The four modes ---------------------------------------------------------

func _explore(sim: ColonySimulation) -> float:
	var food := sim.nearest_food(position, _settings.food_sight_radius)
	if food != null:
		_set_mode(Mode.GATHERING)
		return _turn_towards(food.position)
	if not is_scout and _can_smell(sim, PheromoneGrid.Kind.GOING_HOME):
		_set_mode(Mode.GATHERING)  # collector found a trail that leads to food
	elif time_in_mode > max_explore_time:
		_set_mode(Mode.RETURNING_HOME)
	# Negative weight = prefer the weakest "going out" smell = unexplored places.
	return _steer_by_smell(sim, -1.0, 0.0)


func _gather(sim: ColonySimulation) -> float:
	var food := sim.nearest_food(position, _settings.food_sight_radius)
	if food != null:
		if position.distance_to(food.position) <= _settings.pickup_distance and sim.take_food(food):
			_set_mode(Mode.CARRYING_FOOD)
			heading += PI  # turn around and head home
			return 0.0
		return _turn_towards(food.position)

	if time_in_mode > _settings.gather_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 1.0)


func _go_home(sim: ColonySimulation) -> float:
	if position.distance_to(sim.nest_position) < _settings.nest_sight_radius:
		return _turn_towards(sim.nest_position)
	var smell_turn := _steer_by_smell(sim, 1.0, 0.0)
	var push := minf(time_in_mode * _settings.push_growth, _settings.push_max)
	return lerpf(smell_turn, _turn_towards(sim.nest_position), push)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	time_in_mode = 0.0
	if new_mode == Mode.CARRYING_FOOD:
		time_since_trail_start = 0.0  # the "going home" trail starts at the food


func _check_arrival_at_nest(sim: ColonySimulation) -> void:
	if position.distance_to(sim.nest_position) > sim.nest_radius:
		return
	if mode == Mode.CARRYING_FOOD:
		sim.deliver_food()
		time_since_trail_start = 0.0
		if is_scout:
			_set_mode(Mode.EXPLORING)  # scouts go look for new food
			heading = sim.rng.randf() * TAU
		else:
			_set_mode(Mode.GATHERING)  # collectors go back for more, following the food trail
			heading += PI
	elif mode == Mode.RETURNING_HOME:
		_set_mode(Mode.EXPLORING)  # rested, try a new random direction
		heading = sim.rng.randf() * TAU
		time_since_trail_start = 0.0


# --- Senses and steering ----------------------------------------------------

## Compares the smell at 3 sensors (left, front, right) and returns which way to turn.
## Each sensor's score = going_out * going_out_weight + going_home * going_home_weight.
## The ant turns towards the highest score (a negative weight means "avoid this smell").
func _steer_by_smell(sim: ColonySimulation, going_out_weight: float, going_home_weight: float) -> float:
	var left := _sensor_score(sim, -_settings.sensor_angle, going_out_weight, going_home_weight)
	var front := _sensor_score(sim, 0.0, going_out_weight, going_home_weight)
	var right := _sensor_score(sim, _settings.sensor_angle, going_out_weight, going_home_weight)
	if front >= left and front >= right:
		return 0.0
	return -1.0 if left > right else 1.0


func _sensor_score(sim: ColonySimulation, angle_offset: float, going_out_weight: float, going_home_weight: float) -> float:
	var spot := _sensor_position(angle_offset)
	return (_smell(sim, PheromoneGrid.Kind.GOING_OUT, spot) * going_out_weight
		+ _smell(sim, PheromoneGrid.Kind.GOING_HOME, spot) * going_home_weight)


## True if any of the 3 sensors smells pheromone `kind` above the detection threshold.
func _can_smell(sim: ColonySimulation, kind: PheromoneGrid.Kind) -> bool:
	for angle_offset in [-_settings.sensor_angle, 0.0, _settings.sensor_angle]:
		if _smell(sim, kind, _sensor_position(angle_offset)) > _settings.detection_threshold:
			return true
	return false


## How strong pheromone `kind` smells to a sensor at `spot`.
func _smell(sim: ColonySimulation, kind: PheromoneGrid.Kind, spot: Vector2) -> float:
	return sim.pheromones.sample_area(kind, spot, _settings.sensor_radius_in_cells)


func _sensor_position(angle_offset: float) -> Vector2:
	return position + Vector2.from_angle(heading + angle_offset) * _settings.sensor_distance


## Returns a turn value (-1..+1) that points the ant at `target`.
func _turn_towards(target: Vector2) -> float:
	var angle_to_target := angle_difference(heading, (target - position).angle())
	return clampf(angle_to_target * 2.0, -1.0, 1.0)


# --- Movement and trails ----------------------------------------------------

## Walks forward and bounces off the map edges.
func _move_forward(sim: ColonySimulation, delta: float) -> void:
	position += Vector2.from_angle(heading) * _settings.speed * delta
	var map_size := sim.pheromones.world_size()
	if position.x < 0.0 or position.x > map_size.x:
		heading = PI - heading
		position.x = clampf(position.x, 0.0, map_size.x)
	if position.y < 0.0 or position.y > map_size.y:
		heading = -heading
		position.y = clampf(position.y, 0.0, map_size.y)


func _lay_trail(sim: ColonySimulation, delta: float) -> void:
	# The longer the ant has walked, the less it lays (see the note at the top).
	var fade := exp(-time_since_trail_start / _settings.trail_fade_time)
	var lays_going_out := mode == Mode.EXPLORING or (mode == Mode.GATHERING and _settings.gatherers_lay_going_out)
	if lays_going_out:
		sim.pheromones.deposit(PheromoneGrid.Kind.GOING_OUT, position, _settings.going_out_deposit * fade * delta)
	elif mode == Mode.CARRYING_FOOD:
		sim.pheromones.deposit(PheromoneGrid.Kind.GOING_HOME, position, _settings.going_home_deposit * fade * delta)
