class_name Ant
extends RefCounted
## One ant. Every tick it senses its surroundings, decides which way to turn,
## walks forward and (depending on its mode) lays pheromone behind it.
##
## The modes:
##   EXPLORING      Wanders towards places other ants haven't been (where the
##                  "going out" smell is weakest). Lays a "going out" trail.
##   GATHERING      Knows food exists: walks straight to food it can see, otherwise
##                  follows the "going home" trail (left by food carriers) towards
##                  stronger smell, which leads back to the food. Gives up and goes
##                  home if it doesn't reach food in time (e.g. the pile ran out).
##   CUTTING_FOOD   Standing on food, cutting pieces off: one piece (1 unit of food)
##                  every cut_time seconds, until it carries as much as it can
##                  (carry_capacity) or the food runs out. Then it carries them home.
##   CARRYING_FOOD  Walks home by following "going out" trails backwards (towards
##                  stronger smell, which is near the nest), with a growing push
##                  towards the nest if it's struggling. Lays a "going home" trail.
##                  If the push keeps it stuck (e.g. behind an obstacle), it takes a
##                  detour: push off for a while, following trails only.
##   RETURNING_HOME Gave up exploring without finding food. Walks home the same way
##                  as a food carrier, but lays no trail.
##   JOINING_FIGHT  Eager fighters only: walks to an enemy it sees, or follows the
##                  "fight" smell towards stronger smell (where a fight is going on).
##   FIGHTING       Stands next to an enemy and hits it every attack_interval seconds,
##                  laying "fight" pheromone in a zone around itself. When the enemy dies
##                  or moves away, the ant goes back to what it was doing.
##
## Personality (picked at random when the ant is born):
##   Collector  Focused on collecting: as soon as it smells a food trail it follows it,
##              and after delivering food it goes straight back for more.
##              Some collectors are "homebodies" that only explore briefly near the nest.
##   Scout      Focused on exploring: ignores food trails and keeps looking for new places.
##              It only collects food it finds itself (which starts a new trail for the
##              collectors), then goes back to exploring.
##   Will to fight (0..1, random for every ant), plus a bonus when the fight is close
##   to the nest (the colony defends its home harder):
##     high   (>= join_fight_will)    goes looking for fights when it smells or sees one
##     medium (>= contact_fight_will) fights an enemy it bumps into
##     low                            only fights back when an enemy hits it
##
## Why trails can be followed "backwards": an ant lays less pheromone the longer it
## has been walking, so every trail is strongest near where it started.
##
## Paths: every walking ant wears the ground under it a little. Where many ants pass, the
## ground becomes an unobstructed path (see MapGrid), and ants walk faster there.

enum Mode { EXPLORING, GATHERING, CUTTING_FOOD, CARRYING_FOOD, RETURNING_HOME, JOINING_FIGHT, FIGHTING }

var position: Vector2
var heading: float              ## direction of travel in radians (0 = right, PI/2 = down)
var mode := Mode.EXPLORING
var is_scout: bool              ## personality: true = scout, false = collector
var max_explore_time: float     ## personality: seconds of exploring before giving up
var time_in_mode := 0.0
var time_since_trail_start := 0.0  ## seconds since leaving the nest or picking up food

# Life and combat
var age := 0.0                  ## seconds since birth
var lifespan: float             ## dies of old age after this many seconds (0 = never)
var died_of_old_age := false
var hp: float
var max_hp: float
var carried_food := 0           ## pieces of food the ant is holding
var fight_will: float           ## personality: 0 = never starts a fight, 1 = loves fighting
var fight_target: Enemy         ## the enemy this ant is fighting (FIGHTING mode only)
var _mode_before_fight := Mode.EXPLORING
var _time_until_attack := 0.0

# Going home: push and getting unstuck
var _push_time := 0.0              ## seconds the push has been growing
var _closest_to_nest := INF        ## closest distance to the nest reached on this trip home
var _time_without_progress := 0.0  ## seconds since the ant last got noticeably closer
var _detour_time_left := 0.0       ## > 0 while taking a detour (no push)

var _settings: AntSettings


func _init(start: Vector2, settings: AntSettings, rng: RandomNumberGenerator, starting_age := 0.0) -> void:
	position = start
	_settings = settings
	heading = rng.randf() * TAU
	age = starting_age
	lifespan = rng.randf_range(settings.lifespan_min, settings.lifespan_max)
	hp = settings.hp
	max_hp = settings.hp
	fight_will = rng.randf()
	is_scout = rng.randf() < settings.scout_fraction
	if not is_scout and rng.randf() < settings.homebody_fraction:
		max_explore_time = rng.randf_range(settings.homebody_min_explore_time, settings.homebody_max_explore_time)
	else:
		max_explore_time = rng.randf_range(settings.explorer_min_explore_time, settings.explorer_max_explore_time)


func is_carrying_food() -> bool:
	return carried_food > 0


func is_dead() -> bool:
	return hp <= 0.0


## Called when an enemy hits this ant. An ant that survives always fights back.
func take_damage(amount: float, attacker: Enemy) -> void:
	hp -= amount
	if not is_dead() and mode != Mode.FIGHTING:
		_start_fight(attacker)


## Called by the simulation every tick this ant touches `enemy`.
func touch_enemy(sim: ColonySimulation, enemy: Enemy) -> void:
	if mode == Mode.FIGHTING:
		return
	if mode == Mode.JOINING_FIGHT or _will_to_fight_at(sim, enemy.position) >= _settings.contact_fight_will:
		_start_fight(enemy)


## The ant's will to fight for a fight at `spot`: its own will, plus a bonus that grows
## from 0 (at nest_defense_radius or further from the nest) to nest_defense_bonus (at the nest).
func _will_to_fight_at(sim: ColonySimulation, spot: Vector2) -> float:
	var closeness := 1.0 - clampf(spot.distance_to(sim.nest_position) / _settings.nest_defense_radius, 0.0, 1.0)
	return fight_will + _settings.nest_defense_bonus * closeness


## Advances the ant by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	time_in_mode += delta
	time_since_trail_start += delta
	age += delta
	if lifespan > 0.0 and age > lifespan:
		hp = 0.0
		died_of_old_age = true
		return
	if mode == Mode.FIGHTING:
		_fight(sim, delta)
		return  # fighting ants stand still
	if mode == Mode.CUTTING_FOOD:
		_cut_food(sim)
		return  # cutting ants stand still
	if (mode == Mode.EXPLORING or mode == Mode.GATHERING) and _wants_to_join_fight(sim):
		_set_mode(Mode.JOINING_FIGHT)

	# Each mode returns how much to turn: -1 = full left, 0 = straight, +1 = full right.
	var turn := 0.0
	match mode:
		Mode.EXPLORING:
			turn = _explore(sim)
		Mode.GATHERING:
			turn = _gather(sim)
		Mode.CARRYING_FOOD, Mode.RETURNING_HOME:
			turn = _go_home(sim, delta)
		Mode.JOINING_FIGHT:
			turn = _join_fight(sim)

	heading += clampf(turn, -1.0, 1.0) * _settings.turn_speed * delta
	heading += sim.rng.randf_range(-1.0, 1.0) * _settings.wander * delta
	_move_forward(sim, delta)
	_lay_trail(sim, delta)
	_check_arrival_at_nest(sim)


# --- The modes --------------------------------------------------------------

func _explore(sim: ColonySimulation) -> float:
	var food := sim.grid.find_food_near(position, _settings.food_sight_radius)
	if food != MapGrid.NO_FOOD:
		_set_mode(Mode.GATHERING)
		return _turn_towards(food)
	if not is_scout and _can_smell(sim, MapGrid.Kind.GOING_HOME):
		_set_mode(Mode.GATHERING)  # collector found a trail that leads to food
	elif time_in_mode > max_explore_time:
		_set_mode(Mode.RETURNING_HOME)
	# Negative weight = prefer the weakest "going out" smell = unexplored places.
	return _steer_by_smell(sim, -1.0, 0.0)


func _gather(sim: ColonySimulation) -> float:
	if _food_within_reach(sim) != MapGrid.NO_FOOD:
		_set_mode(Mode.CUTTING_FOOD)  # reached food: start cutting a piece off
		return 0.0
	var food := sim.grid.find_food_near(position, _settings.food_sight_radius)
	if food != MapGrid.NO_FOOD:
		return _turn_towards(food)

	if time_in_mode > _settings.gather_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 1.0)


func _go_home(sim: ColonySimulation, delta: float) -> float:
	var distance_to_nest := position.distance_to(sim.nest_position)
	if distance_to_nest < _settings.nest_sight_radius:
		return _turn_towards(sim.nest_position)
	var smell_turn := _steer_by_smell(sim, 1.0, 0.0)

	if _detour_time_left > 0.0:
		_detour_time_left -= delta
		return smell_turn  # detour: follow trails only, no push

	_track_progress_home(distance_to_nest, delta)
	if _time_without_progress > _settings.stuck_time:
		_start_detour(sim)
		return smell_turn

	_push_time += delta
	var push := minf(_push_time * _settings.push_growth, _settings.push_max)
	return lerpf(smell_turn, _turn_towards(sim.nest_position), push)


## Remembers the closest the ant got to the nest; counts how long since it improved.
func _track_progress_home(distance_to_nest: float, delta: float) -> void:
	if distance_to_nest < _closest_to_nest - _settings.stuck_min_progress:
		_closest_to_nest = distance_to_nest
		_time_without_progress = 0.0
	else:
		_time_without_progress += delta


## Stuck (usually the push pinning the ant against an obstacle): stop pushing for a while.
func _start_detour(sim: ColonySimulation) -> void:
	_detour_time_left = _settings.detour_time
	_push_time = 0.0  # when the detour ends, the push starts again from zero
	_closest_to_nest = INF
	_time_without_progress = 0.0
	if _settings.detour_random_direction:
		heading = sim.rng.randf() * TAU


## Waits until the piece is cut, then takes it home. If the food is gone meanwhile
## (other ants or an enemy took it), goes back to gathering.
func _cut_food(sim: ColonySimulation) -> void:
	if time_in_mode < _settings.cut_time:
		return
	time_in_mode = 0.0  # start cutting the next piece
	var food := _food_within_reach(sim)
	if food != MapGrid.NO_FOOD and sim.grid.take_food(food):
		carried_food += 1
		if carried_food < _settings.carry_capacity:
			return  # room for more: keep cutting
	if carried_food > 0:
		_set_mode(Mode.CARRYING_FOOD)
		heading += PI  # turn around and head home
	else:
		_set_mode(Mode.GATHERING)


## Closest food the ant can touch (its own cell or right next to it), or NO_FOOD.
func _food_within_reach(sim: ColonySimulation) -> Vector2:
	return sim.grid.find_food_near(position, _settings.food_reach)


func _join_fight(sim: ColonySimulation) -> float:
	var enemy := sim.nearest_enemy(position, _settings.enemy_sight_radius)
	if enemy != null:
		return _turn_towards(enemy.position)
	if time_in_mode > _settings.join_fight_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 0.0, 1.0)


func _fight(sim: ColonySimulation, delta: float) -> void:
	if fight_target.is_dead() or not fight_target.ants_in_contact.has(self):
		_end_fight()
		return
	heading = (fight_target.position - position).angle()
	sim.grid.deposit_zone(MapGrid.Kind.FIGHT, position, _settings.fight_zone_radius, _settings.fight_deposit * delta)
	_time_until_attack -= delta
	if _time_until_attack <= 0.0:
		_time_until_attack = _settings.attack_interval
		fight_target.take_damage(_settings.attack)


func _start_fight(enemy: Enemy) -> void:
	# Ants that came looking for a fight go exploring afterwards (and will find the enemy's food).
	_mode_before_fight = Mode.EXPLORING if mode == Mode.JOINING_FIGHT else mode
	fight_target = enemy
	_time_until_attack = _settings.attack_interval
	mode = Mode.FIGHTING
	time_in_mode = 0.0


func _end_fight() -> void:
	fight_target = null
	mode = _mode_before_fight
	time_in_mode = 0.0


## Eager fighters drop what they're doing when they see an enemy or smell a fight.
## (A fight that is only smelled is assumed to be about where the ant is.)
func _wants_to_join_fight(sim: ColonySimulation) -> bool:
	var enemy := sim.nearest_enemy(position, _settings.enemy_sight_radius)
	if enemy != null:
		return _will_to_fight_at(sim, enemy.position) >= _settings.join_fight_will
	return (_will_to_fight_at(sim, position) >= _settings.join_fight_will
		and _can_smell(sim, MapGrid.Kind.FIGHT))


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	time_in_mode = 0.0
	_push_time = 0.0
	_closest_to_nest = INF
	_time_without_progress = 0.0
	_detour_time_left = 0.0
	if new_mode == Mode.CARRYING_FOOD:
		time_since_trail_start = 0.0  # the "going home" trail starts at the food


func _check_arrival_at_nest(sim: ColonySimulation) -> void:
	if position.distance_to(sim.nest_position) > sim.nest_radius:
		return
	if mode == Mode.CARRYING_FOOD:
		sim.deliver_food(carried_food)
		carried_food = 0
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
## Each sensor's score = going_out * going_out_weight + going_home * going_home_weight
##                       + fight * fight_weight.
## The ant turns towards the highest score (a negative weight means "avoid this smell").
## A sensor that touches an obstacle gets the worst possible score, so ants steer around them.
func _steer_by_smell(sim: ColonySimulation, going_out_weight: float, going_home_weight: float, fight_weight := 0.0) -> float:
	var left := _sensor_score(sim, -_settings.sensor_angle, going_out_weight, going_home_weight, fight_weight)
	var front := _sensor_score(sim, 0.0, going_out_weight, going_home_weight, fight_weight)
	var right := _sensor_score(sim, _settings.sensor_angle, going_out_weight, going_home_weight, fight_weight)
	if front >= left and front >= right:
		return 0.0
	return -1.0 if left > right else 1.0


func _sensor_score(sim: ColonySimulation, angle_offset: float, going_out_weight: float, going_home_weight: float, fight_weight: float) -> float:
	var spot := _sensor_position(angle_offset)
	if sim.grid.is_obstacle(spot):
		return -INF
	var score := 0.0  # smells with weight 0 are skipped, to save time
	if going_out_weight != 0.0:
		score += _smell(sim, MapGrid.Kind.GOING_OUT, spot) * going_out_weight
	if going_home_weight != 0.0:
		score += _smell(sim, MapGrid.Kind.GOING_HOME, spot) * going_home_weight
	if fight_weight != 0.0:
		score += _smell(sim, MapGrid.Kind.FIGHT, spot) * fight_weight
	return score


## True if any of the 3 sensors smells pheromone `kind` above the detection threshold.
func _can_smell(sim: ColonySimulation, kind: MapGrid.Kind) -> bool:
	for angle_offset in [-_settings.sensor_angle, 0.0, _settings.sensor_angle]:
		if _smell(sim, kind, _sensor_position(angle_offset)) > _settings.detection_threshold:
			return true
	return false


## How strong pheromone `kind` smells to a sensor at `spot`.
func _smell(sim: ColonySimulation, kind: MapGrid.Kind, spot: Vector2) -> float:
	return sim.grid.sample_area(kind, spot, _settings.sensor_radius_in_cells)


func _sensor_position(angle_offset: float) -> Vector2:
	return position + Vector2.from_angle(heading + angle_offset) * _settings.sensor_distance


## Returns a turn value (-1..+1) that points the ant at `target`.
func _turn_towards(target: Vector2) -> float:
	var angle_to_target := angle_difference(heading, (target - position).angle())
	return clampf(angle_to_target * 2.0, -1.0, 1.0)


# --- Movement and trails ----------------------------------------------------

## Walks forward (faster on unobstructed paths) and bounces off obstacles and the map
## edges (like a ball off a wall: hitting a vertical wall flips the left/right direction,
## a horizontal one flips up/down). Wears the ground it walks on.
func _move_forward(sim: ColonySimulation, delta: float) -> void:
	sim.grid.wear_path(position, _settings.path_wear_per_second * delta)
	var speed := _settings.speed
	if sim.grid.is_unobstructed(position):
		speed *= 1.0 + _settings.path_speed_bonus
	var step := Vector2.from_angle(heading) * speed * delta
	if _is_blocked(sim, position + Vector2(step.x, 0.0)):
		heading = PI - heading
		step.x = 0.0
	if _is_blocked(sim, position + Vector2(step.x, step.y)):
		heading = -heading
		step.y = 0.0
	position += step


## True if the ant can't step onto `target`. An ant that is already inside an obstacle
## (because the player painted one on top of it) is allowed to walk out.
func _is_blocked(sim: ColonySimulation, target: Vector2) -> bool:
	return sim.grid.is_obstacle(target) and not sim.grid.is_obstacle(position)


func _lay_trail(sim: ColonySimulation, delta: float) -> void:
	# The longer the ant has walked, the less it lays (see the note at the top).
	var fade := exp(-time_since_trail_start / _settings.trail_fade_time)
	var lays_going_out := mode == Mode.EXPLORING or (mode == Mode.GATHERING and _settings.gatherers_lay_going_out)
	if lays_going_out:
		sim.grid.deposit(MapGrid.Kind.GOING_OUT, position, _settings.going_out_deposit * fade * delta)
	elif mode == Mode.CARRYING_FOOD:
		sim.grid.deposit(MapGrid.Kind.GOING_HOME, position, _settings.going_home_deposit * fade * delta)
