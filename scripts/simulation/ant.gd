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
##   CUTTING_FOOD   Standing on food, cutting pieces off: one piece (piece_food units of
##                  food: a lot for a larva or a hard shell, less for fruit or aphids)
##                  every cut_time seconds of that food item (fruit is quick, a hard
##                  shell is slow), until it carries as many pieces as it can
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
##   ATTACKING      Attack ants only (fighting spirit, and majors), sent by the player with
##                  the Focus tool: follows the colony's "attack" trail (from the nest to
##                  the focused spot) towards stronger smell, and attacks anything it
##                  sees on the way or there: spiders, beetle larvae, crickets, rival ants
##                  and nests. With nothing left to attack, it collects the food in sight
##                  (the kill); goes home when the trail is gone and nothing is left.
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
##     (>= [focus] attack_will: an "attack ant", follows the attack trail of the Focus tool)
##     medium (>= contact_fight_will) fights an enemy it bumps into
##     low                            only fights back when an enemy hits it
##
## Other creatures: spiders are always enemies; beetle larvae and crickets are left alone
## until the player sends attack ants at them (then the whole colony treats them as enemies).
##
## Colonies: every ant belongs to a colony (its nest, its trails, its upgrades). It only
## follows its own colony's trails. When it meets an ant of another colony, both fight.
## Dead ants of other colonies are food: an ant carries one home in a single chunk.
##
## Behaviour and upgrades: the colony's Behaviour sliders (aggressivity, exploring distance)
## and tech tree are read when the ant hatches (aggressivity and exploring only then: changes
## only affect ants hatched later). Some ants hatch as majors (Major ants upgrade).
##
## Raids: an ant that walks into a rival nest steals a larva (carried home as food), or, if
## the nest has none left and the ant is willing to fight, attacks the nest itself.
##
## Thinking less often: deciding where to go (smelling with 3 sensors, looking for food and
## enemies) is the expensive part, so an ant only does it every think_interval_ticks ticks
## (each ant at its own moment) and keeps turning the same way in between. Walking, laying
## trails and arriving at the nest still happen every tick.
##
## Why trails can be followed "backwards": an ant lays less pheromone the longer it
## has been walking, so every trail is strongest near where it started.
##
## Paths: every walking ant wears the ground under it a little. Where many ants pass, the
## ground becomes an unobstructed path (see MapGrid), and ants walk faster there.

enum Mode { EXPLORING, GATHERING, CUTTING_FOOD, CARRYING_FOOD, RETURNING_HOME, JOINING_FIGHT, ATTACKING, FIGHTING }

var colony: Colony
var position: Vector2
var previous_position: Vector2  ## where it was one tick ago (to draw it smoothly between ticks)
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
var carried_food := 0           ## food the ant is holding (units)
var pieces_carried := 0         ## pieces cut off on this trip (carry_capacity counts pieces)
var fight_will: float           ## personality: 0 = never starts a fight, 1 = loves fighting
var fight_target: Object        ## the Creature, rival Ant or rival nest (Colony) this ant is fighting
var cutting_spot := Vector2.INF ## the food cell it is cutting from (CUTTING_FOOD)
var is_major := false           ## a big fighter (Major ants upgrade)
var size_multiplier := 1.0      ## how much bigger it is drawn (majors)
var attack_multiplier := 1.0
var poison_time_left := 0.0     ## Corrosive sting: seconds of poison left
var poison_damage_per_second := 0.0
var poison_team := -1           ## team of the ant that poisoned it
var damage_to_show := 0.0       ## damage taken since the simulation last reported it (damage numbers)
var damage_attacker_team := -1  ## team of whoever hurt it last (-1 = a spider)
var _mode_before_fight := Mode.EXPLORING
var _last_fight_target: Object  ## touching the same target again keeps the bite timer going
var _time_until_attack := 0.0
var _cut_time := 0.0            ## seconds per piece of the food being cut

# Going home: push and getting unstuck
var _push_time := 0.0              ## seconds the push has been growing
var _closest_to_nest := INF        ## closest distance to the nest reached on this trip home
var _time_without_progress := 0.0  ## seconds since the ant last got noticeably closer
var _detour_time_left := 0.0       ## > 0 while taking a detour (no push)

var _settings: AntSettings
var _tree: TechTree
var _on_path := false           ## standing on a worn path (for Guarded paths)
var _time_until_acid := 0.0     ## Acid spray cooldown
var _turn := 0.0                ## how it turns between two thinking ticks (-1 left .. +1 right)
var _ticks_until_thinking: int


func _init(ant_colony: Colony, rng: RandomNumberGenerator, starting_age: float, tree: TechTree) -> void:
	colony = ant_colony
	_tree = tree
	position = colony.nest_position
	previous_position = position
	var settings := colony.ant_settings
	_settings = settings
	_ticks_until_thinking = rng.randi_range(1, settings.think_interval_ticks)  # spread the thinking
	heading = rng.randf() * TAU
	age = starting_age
	lifespan = rng.randf_range(settings.lifespan_min, settings.lifespan_max)
	hp = settings.hp
	max_hp = settings.hp
	fight_will = clampf(rng.randf() + colony.aggressivity - 0.5, 0.0, 1.0)  # aggressivity 0.5 = unchanged
	is_scout = rng.randf() < settings.scout_fraction
	if not is_scout and rng.randf() < settings.homebody_fraction:
		max_explore_time = rng.randf_range(settings.homebody_min_explore_time, settings.homebody_max_explore_time)
	else:
		max_explore_time = rng.randf_range(settings.explorer_min_explore_time, settings.explorer_max_explore_time)
	max_explore_time *= colony.exploring
	if colony.has_tech("major_ants") and rng.randf() < float(tree.value("major_ants", "chance")):
		_become_major()


## Majors: bigger, much stronger, always eager to fight (even more with Super majors).
func _become_major() -> void:
	is_major = true
	fight_will = 1.0
	for node in ["major_ants", "super_majors"]:
		if colony.has_tech(node):
			hp *= float(_tree.value(node, "hp_multiplier"))
			attack_multiplier *= float(_tree.value(node, "attack_multiplier"))
			size_multiplier *= float(_tree.value(node, "size_multiplier"))
	max_hp = hp


func is_carrying_food() -> bool:
	return carried_food > 0


func is_dead() -> bool:
	return hp <= 0.0


## Called when an enemy or a rival ant hits this ant (armor upgrades take some off).
## An ant that survives always fights back.
func take_damage(amount: float, attacker: Object) -> void:
	var reduction := _settings.damage_reduction
	if _near_own_nest_with("motherbase"):
		reduction += float(_tree.value("motherbase", "damage_reduction"))
	var damage := maxf(amount - reduction, _settings.minimum_damage) if reduction > 0.0 else amount
	hp -= damage
	damage_to_show += damage
	damage_attacker_team = attacker.colony.team if attacker is Ant else -1
	if not is_dead() and mode != Mode.FIGHTING:
		_start_fight(attacker)


## Corrosive sting: loses `damage_per_second` health for `duration` seconds.
func poison(damage_per_second: float, duration: float, team: int) -> void:
	poison_damage_per_second = damage_per_second
	poison_time_left = duration
	poison_team = team


## How hard this ant hits: its colony's attack, more for majors and near the nest (Motherbase).
func attack_power() -> float:
	var power := _settings.attack * attack_multiplier
	if _near_own_nest_with("motherbase"):
		power += float(_tree.value("motherbase", "extra_attack"))
	return power


## True if the colony has the upgrade `node` and the ant is within its radius of the nest.
func _near_own_nest_with(node: String) -> bool:
	return colony.has_tech(node) and position.distance_to(colony.nest_position) <= float(_tree.value(node, "radius"))


## Hits `target` (a spider, a rival ant or a rival nest), poisoning it with Corrosive sting.
func _hit(target: Object) -> void:
	target.take_damage(attack_power(), self)
	if colony.has_tech("corrosive_sting") and not target is Colony:
		target.poison(_tree.value("corrosive_sting", "damage_per_second"), _tree.value("corrosive_sting", "duration"), colony.team)


## Called by the simulation every tick this ant touches `creature`. Attacking ants fight
## anything; otherwise only creatures that are enemies of the colony are fought.
func touch_creature(sim: ColonySimulation, creature: Creature) -> void:
	if mode == Mode.FIGHTING:
		return
	if mode == Mode.ATTACKING:
		_start_fight(creature)
		return
	if not creature.is_hostile_to(colony.team):
		return
	if mode == Mode.JOINING_FIGHT or _will_to_fight_at(sim, creature.position) >= _settings.contact_fight_will:
		_start_fight(creature)


## Called by the simulation every tick this ant touches an ant of another colony:
## rival ants always fight when they meet.
func touch_rival(rival: Ant) -> void:
	if mode != Mode.FIGHTING and not is_dead() and not rival.is_dead():
		_start_fight(rival)


## The ant's will to fight for a fight at `spot`: its own will, plus a bonus that grows
## from 0 (at nest_defense_radius or further from the nest) to nest_defense_bonus (at the nest).
func _will_to_fight_at(sim: ColonySimulation, spot: Vector2) -> float:
	var closeness := 1.0 - clampf(spot.distance_to(colony.nest_position) / _settings.nest_defense_radius, 0.0, 1.0)
	return fight_will + _settings.nest_defense_bonus * closeness


## Advances the ant by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	previous_position = position
	if poison_time_left > 0.0:
		poison_time_left -= delta
		hp -= poison_damage_per_second * delta
		damage_to_show += poison_damage_per_second * delta
		damage_attacker_team = poison_team
		if is_dead():
			return
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
	_ticks_until_thinking -= 1
	if _ticks_until_thinking <= 0:
		_ticks_until_thinking = _settings.think_interval_ticks
		_turn = _think(sim, delta * _settings.think_interval_ticks)

	heading += clampf(_turn, -1.0, 1.0) * _settings.turn_speed * delta
	heading += sim.rng.randf_range(-1.0, 1.0) * _settings.wander * delta
	_move_forward(sim, delta)
	_lay_trail(sim, delta)
	_check_arrival_at_nest(sim)


## Decides what to do and which way to turn: -1 = full left, 0 = straight, +1 = full right.
## `delta` = the time since the ant last thought.
func _think(sim: ColonySimulation, delta: float) -> float:
	_spray_acid(sim, delta)
	if not is_carrying_food() and _raid_rival_nest(sim):
		return 0.0
	if _wants_to_attack(sim):
		_set_mode(Mode.ATTACKING)
	elif (mode == Mode.EXPLORING or mode == Mode.GATHERING) and _wants_to_join_fight(sim):
		_set_mode(Mode.JOINING_FIGHT)
	match mode:
		Mode.EXPLORING:
			return _explore(sim)
		Mode.GATHERING:
			return _gather(sim)
		Mode.CARRYING_FOOD, Mode.RETURNING_HOME:
			return _go_home(sim, delta)
		Mode.JOINING_FIGHT:
			return _join_fight(sim)
		Mode.ATTACKING:
			return _attack(sim)
	return 0.0


## Inside a rival nest: steals a larva or some stored food and heads home with it, or, if
## there is nothing to take, attacks the nest itself (if willing to fight). Returns true if
## the ant did something.
func _raid_rival_nest(sim: ColonySimulation) -> bool:
	var rival := sim.rival_colony_at(position, colony.team)
	if rival == null:
		return false
	var loot := sim.raid_nest(rival)
	if loot > 0:
		carried_food = loot
		_set_mode(Mode.CARRYING_FOOD)
		heading += PI
		return true
	if _will_to_fight_at(sim, position) >= _settings.contact_fight_will:
		_start_fight(rival)
		return true
	return false


## Acid spray: every `interval` seconds, hits the closest spider or rival ant within `range`
## without touching it.
func _spray_acid(sim: ColonySimulation, delta: float) -> void:
	if not colony.has_tech("acid_spray"):
		return
	_time_until_acid -= delta
	if _time_until_acid > 0.0:
		return
	var reach: float = _tree.value("acid_spray", "range")
	var target: Object = sim.nearest_hostile_creature(position, reach, colony.team)
	if target == null:
		target = sim.collisions.nearest_rival(position, reach, colony.team)
	if target == null:
		return
	_time_until_acid = _tree.value("acid_spray", "interval")
	var damage: float = _tree.value("acid_spray", "damage")
	target.take_damage(damage, self)
	if colony.has_tech("corrosive_sting"):
		target.poison(_tree.value("corrosive_sting", "damage_per_second"), _tree.value("corrosive_sting", "duration"), colony.team)


# --- The modes --------------------------------------------------------------

func _explore(sim: ColonySimulation) -> float:
	var food := _food_in_sight(sim)
	if food != MapGrid.NO_FOOD:
		_set_mode(Mode.GATHERING)
		return _turn_towards(food)
	if fight_will >= _settings.join_fight_will:  # eager fighters head for rival nests they see
		var rival_nest := sim.rival_nest_near(position, _settings.raid_sight_radius, colony.team)
		if rival_nest != null:
			return _turn_towards(rival_nest.nest_position)
	if not is_scout and _can_smell(sim, MapGrid.Kind.GOING_HOME):
		_set_mode(Mode.GATHERING)  # collector found a trail that leads to food
	elif time_in_mode > max_explore_time:
		_set_mode(Mode.RETURNING_HOME)
	# Negative weight = prefer the weakest "going out" smell = unexplored places.
	return _steer_by_smell(sim, -1.0, 0.0)


func _gather(sim: ColonySimulation) -> float:
	var corpse_food := sim.take_rival_corpse(position, _settings.food_reach, colony)
	if corpse_food > 0:  # a dead rival ant: carried home in one chunk
		carried_food = corpse_food
		_set_mode(Mode.CARRYING_FOOD)
		heading += PI
		return 0.0
	var reachable := _food_within_reach(sim)
	if reachable != MapGrid.NO_FOOD:
		_start_cutting(sim, reachable)  # reached food: start cutting a piece off
		return 0.0
	var food := _food_in_sight(sim)
	if food != MapGrid.NO_FOOD:
		return _turn_towards(food)

	if time_in_mode > _settings.gather_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 1.0)


## The closest food the ant sees: food on the map or a dead rival ant (NO_FOOD if none).
func _food_in_sight(sim: ColonySimulation) -> Vector2:
	var corpse := sim.rival_corpse_near(position, _settings.food_sight_radius, colony)
	if corpse != MapGrid.NO_FOOD:
		return corpse
	return sim.grid.find_food_near(position, _settings.food_sight_radius)


func _go_home(sim: ColonySimulation, delta: float) -> float:
	var distance_to_nest := position.distance_to(colony.nest_position)
	if distance_to_nest < _settings.nest_sight_radius:
		return _turn_towards(colony.nest_position)
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
	return lerpf(smell_turn, _turn_towards(colony.nest_position), push)


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


## Starts cutting the food at `spot`, at the speed of its food item.
func _start_cutting(sim: ColonySimulation, spot: Vector2) -> void:
	_set_mode(Mode.CUTTING_FOOD)
	cutting_spot = spot
	_cut_time = sim.cut_time_at(spot)


## Waits until the piece is cut, then takes it home. If the food is gone meanwhile
## (other ants or a spider took it), goes back to gathering.
func _cut_food(sim: ColonySimulation) -> void:
	if time_in_mode < _cut_time:
		return
	time_in_mode = 0.0  # start cutting the next piece
	var food := _food_within_reach(sim)
	var taken := sim.take_food_piece(food) if food != MapGrid.NO_FOOD else 0
	if taken > 0:
		carried_food += taken
		pieces_carried += 1
		if pieces_carried < _settings.carry_capacity:
			return  # room for more: keep cutting
	cutting_spot = Vector2.INF
	if carried_food > 0:
		_set_mode(Mode.CARRYING_FOOD)
		heading += PI  # turn around and head home
	else:
		_set_mode(Mode.GATHERING)


## Closest food the ant can touch (its own cell or right next to it), or NO_FOOD.
func _food_within_reach(sim: ColonySimulation) -> Vector2:
	return sim.grid.find_food_near(position, _settings.food_reach)


func _join_fight(sim: ColonySimulation) -> float:
	var enemy := sim.nearest_hostile_creature(position, _settings.enemy_sight_radius, colony.team)
	if enemy != null:
		return _turn_towards(enemy.position)
	if time_in_mode > _settings.join_fight_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 0.0, 1.0)


## Follows the attack trail towards the focused spot, turning towards anything to attack
## that it sees. With nothing left to attack but food in sight (usually what it just killed),
## it collects the food. Goes home once the trail has faded and nothing is in sight.
func _attack(sim: ColonySimulation) -> float:
	var target := _attack_target_in_sight(sim)
	if target != null:
		return _turn_towards(target.position)
	var food := _food_in_sight(sim)
	if food != MapGrid.NO_FOOD:
		_set_mode(Mode.GATHERING)
		return _turn_towards(food)
	if not _can_smell(sim, MapGrid.Kind.ATTACK) and time_in_mode > _settings.join_fight_give_up_time:
		_set_mode(Mode.RETURNING_HOME)
	return _steer_by_smell(sim, 0.0, 0.0, 0.0, 1.0)


## What an attacking ant goes for: the closest creature, else rival ant, else rival nest
## it sees (null if none).
func _attack_target_in_sight(sim: ColonySimulation) -> Object:
	var creature := sim.nearest_creature(position, _settings.enemy_sight_radius)
	if creature != null:
		return creature
	var rival := sim.collisions.nearest_rival(position, _settings.enemy_sight_radius, colony.team)
	if rival != null:
		return rival
	return sim.rival_nest_near(position, _settings.raid_sight_radius, colony.team)


## Attack ants (will to fight at least [focus] attack_will, and majors) that aren't busy
## with food follow the attack trail when they smell it.
func _wants_to_attack(sim: ColonySimulation) -> bool:
	if mode != Mode.EXPLORING and mode != Mode.GATHERING and mode != Mode.RETURNING_HOME:
		return false
	if is_carrying_food() or not (is_major or fight_will >= _settings.attack_will):
		return false
	return _can_smell(sim, MapGrid.Kind.ATTACK)


func _fight(sim: ColonySimulation, delta: float) -> void:
	if not _still_touching(fight_target):
		_end_fight()
		return
	heading = (fight_target.position - position).angle()
	sim.grid.deposit_zone(MapGrid.Kind.FIGHT, position, _settings.fight_zone_radius, _settings.fight_deposit * delta)
	if fight_target is Ant and fight_target.colony.has_tech("restraining_bite"):
		delta *= float(_tree.value("restraining_bite", "opponent_speed"))  # held down: attacks slower
	_time_until_attack -= delta
	if _time_until_attack <= 0.0:
		_time_until_attack = _settings.attack_interval
		_hit(fight_target)


## True while the spider, rival ant or rival nest being fought is still there and touching.
func _still_touching(target: Object) -> bool:
	if target.is_dead():
		return false
	if target is Ant:
		return position.distance_to(target.position) <= _settings.rival_contact_distance
	if target is Colony:
		return position.distance_to(target.nest_position) <= target.nest_radius + _settings.rival_contact_distance
	return target.ants_in_contact.has(self)


func _start_fight(target: Object) -> void:
	# Ants that came looking for a fight go exploring afterwards (and will find the enemy's food);
	# attacking ants keep attacking.
	_mode_before_fight = Mode.EXPLORING if mode == Mode.JOINING_FIGHT else mode
	fight_target = target
	cutting_spot = Vector2.INF
	if target != _last_fight_target:  # a new opponent (not one it lost touch with for a moment)
		_time_until_attack = _settings.attack_interval
		if _on_path and colony.has_tech("guarded_paths"):
			_time_until_attack = 0.0  # strikes first
	if target is Creature and target.settings.hold_per_ant > 0.0 and target.settings.hold_per_ant < 1.0:
		_time_until_attack = 0.0  # an animal that tries to get away: bite as soon as it's caught
	_last_fight_target = target
	mode = Mode.FIGHTING
	time_in_mode = 0.0


func _end_fight() -> void:
	fight_target = null
	mode = _mode_before_fight
	time_in_mode = 0.0


## Eager fighters drop what they're doing when they see an enemy or smell a fight.
## (A fight that is only smelled is assumed to be about where the ant is.)
func _wants_to_join_fight(sim: ColonySimulation) -> bool:
	var enemy := sim.nearest_hostile_creature(position, _settings.enemy_sight_radius, colony.team)
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
	if position.distance_to(colony.nest_position) > colony.nest_radius:
		return
	if mode == Mode.CARRYING_FOOD:
		colony.deliver_food(carried_food, sim.elapsed_time)
		carried_food = 0
		pieces_carried = 0
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
##                       + fight * fight_weight + attack * attack_weight.
## The ant turns towards the highest score (a negative weight means "avoid this smell").
## A sensor that touches an obstacle gets the worst possible score, so ants steer around them.
func _steer_by_smell(sim: ColonySimulation, going_out_weight: float, going_home_weight: float, fight_weight := 0.0, attack_weight := 0.0) -> float:
	var weights := [going_out_weight, going_home_weight, fight_weight, attack_weight]
	var left := _sensor_score(sim, -_settings.sensor_angle, weights)
	var front := _sensor_score(sim, 0.0, weights)
	var right := _sensor_score(sim, _settings.sensor_angle, weights)
	if front >= left and front >= right:
		return 0.0
	return -1.0 if left > right else 1.0


## `weights` = [going_out, going_home, fight, attack] weights (see _steer_by_smell).
func _sensor_score(sim: ColonySimulation, angle_offset: float, weights: Array) -> float:
	var spot := _sensor_position(angle_offset)
	if sim.grid.is_obstacle(spot):
		return -INF
	var score := 0.0  # smells with weight 0 are skipped, to save time
	for kind in [MapGrid.Kind.GOING_OUT, MapGrid.Kind.GOING_HOME, MapGrid.Kind.FIGHT, MapGrid.Kind.ATTACK]:
		if weights[kind] != 0.0:
			score += _smell(sim, kind, spot) * weights[kind]
	return score


## True if any of the 3 sensors smells pheromone `kind` above the detection threshold.
func _can_smell(sim: ColonySimulation, kind: MapGrid.Kind) -> bool:
	for angle_offset in [-_settings.sensor_angle, 0.0, _settings.sensor_angle]:
		if _smell(sim, kind, _sensor_position(angle_offset)) > _settings.detection_threshold:
			return true
	return false


## How strong pheromone `kind` smells to a sensor at `spot`.
func _smell(sim: ColonySimulation, kind: MapGrid.Kind, spot: Vector2) -> float:
	return sim.grid.sample_area(kind, spot, _settings.sensor_radius_in_cells, colony.index)


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
	_on_path = sim.grid.is_unobstructed(position)
	if _on_path:
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
		sim.grid.deposit(MapGrid.Kind.GOING_OUT, position, _settings.going_out_deposit * fade * delta, colony.index)
	elif mode == Mode.CARRYING_FOOD:
		sim.grid.deposit(MapGrid.Kind.GOING_HOME, position, _settings.going_home_deposit * fade * delta, colony.index)
