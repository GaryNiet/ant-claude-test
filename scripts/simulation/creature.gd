class_name Creature
extends RefCounted
## An animal living on the map besides the ants: a spider, a beetle larva or a cricket
## (see Spider, BeetleLarva, Cricket for what each does). This base holds what they share:
## a round body that ants can't walk into, health, taking hits, poison, fighting back,
## being held down by ants, and walking around obstacles.
##
## Hostility: spiders are always enemies. The others live their own lives: ants leave them
## alone until the player sends ants at them (Focus tool); once a colony hurts one, that
## colony's ants treat it as an enemy (it is "provoked").
## When it dies, its body becomes a food item (food_value()).

var kind: String
var settings: CreatureSettings
var position: Vector2
var previous_position: Vector2  ## where it was one tick ago (to draw it smoothly between ticks)
var heading: float
var hp: float
var max_hp: float
var has_left_the_map := false
var poison_time_left := 0.0     ## Corrosive sting (ants' upgrade): seconds of poison left
var poison_damage_per_second := 0.0
var poison_team := -1           ## team of the ant that poisoned it
var damage_to_show := 0.0       ## damage taken since the simulation last reported it (damage numbers)
var damage_attacker_team := -1  ## team of whoever hurt it last
var ants_in_contact: Array[Ant] = []  ## filled by the simulation every tick
var provoked_teams := {}        ## team -> true: teams whose ants attacked it
var slowed_time_left := 0.0     ## Restraining bite: seconds it still moves at reduced speed

var _time_until_attack: float
var _time_in_state := 0.0


func _init(start: Vector2, creature_settings: CreatureSettings) -> void:
	settings = creature_settings
	kind = settings.kind
	position = start
	previous_position = start
	max_hp = settings.hp
	hp = settings.hp
	_time_until_attack = settings.attack_interval


func is_dead() -> bool:
	return hp <= 0.0


## True if ants of `team` treat it as an enemy (always for spiders, otherwise once provoked).
func is_hostile_to(team: int) -> bool:
	return settings.always_hostile or provoked_teams.has(team)


## Called when an ant hits it: it now counts as an enemy for that ant's colony. An ant with
## Restraining bite slows it down for a while.
func take_damage(amount: float, attacker: Ant) -> void:
	hp -= amount
	damage_to_show += amount
	damage_attacker_team = attacker.colony.team
	provoked_teams[attacker.colony.team] = true
	if attacker.colony.has_tech("restraining_bite"):
		slowed_time_left = attacker.colony.ant_settings.restraining_slow_time
	_on_attacked()


## Corrosive sting: loses `damage_per_second` health for `duration` seconds.
func poison(damage_per_second: float, duration: float, team: int) -> void:
	poison_damage_per_second = damage_per_second
	poison_time_left = duration
	poison_team = team


## Advances the creature by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	previous_position = position
	if poison_time_left > 0.0:
		poison_time_left -= delta
		hp -= poison_damage_per_second * delta
		damage_to_show += poison_damage_per_second * delta
		damage_attacker_team = poison_team
	_time_in_state += delta
	slowed_time_left = maxf(slowed_time_left - delta, 0.0)
	if settings.attack > 0.0 and not ants_in_contact.is_empty():
		_fight(sim, delta)
		return
	_time_until_attack = settings.attack_interval
	_behave(sim, delta)


# --- What each kind overrides -------------------------------------------------------------

## What it does this tick when it isn't fighting.
func _behave(_sim: ColonySimulation, _delta: float) -> void:
	pass


## Called when an ant hits it.
func _on_attacked() -> void:
	pass


## Food its body is worth when killed.
func food_value() -> int:
	return 0


## What it is doing, for the side panel.
func activity() -> String:
	return ""


## True while it walks (for the walking animation).
func is_walking() -> bool:
	return true


## How big its sprite is drawn, relative to [creature_<kind>] sprite_size.
func size_multiplier() -> float:
	return 1.0


# --- Shared behaviour ---------------------------------------------------------------------

## Hits one random touching ant every attack_interval seconds. Ants with Restraining bite
## hold it down: it attacks slower. Returns the ant it killed, or null.
func _fight(sim: ColonySimulation, delta: float) -> Ant:
	if _restrained(sim):
		delta *= float(sim.tech_tree.value("restraining_bite", "opponent_speed"))
	_time_until_attack -= delta
	if _time_until_attack > 0.0:
		return null
	_time_until_attack = settings.attack_interval
	var victim: Ant = ants_in_contact[sim.rng.randi_range(0, ants_in_contact.size() - 1)]
	victim.take_damage(settings.attack, self)
	return victim if victim.is_dead() else null


## True if one of the touching ants has Restraining bite.
func _restrained(_sim: ColonySimulation) -> bool:
	for ant in ants_in_contact:
		if ant.colony.has_tech("restraining_bite"):
			return true
	return false


## How much of its speed it keeps (0..1): each touching ant holds on to it and takes
## hold_per_ant away (Restraining bite: hold_strength times more); a bite with Restraining
## bite slows it down (opponent_speed) for a while.
func _held_speed_factor(sim: ColonySimulation) -> float:
	var factor := 1.0
	if slowed_time_left > 0.0:
		factor *= float(sim.tech_tree.value("restraining_bite", "opponent_speed"))
	if ants_in_contact.is_empty() or settings.hold_per_ant <= 0.0:
		return factor
	var hold := 0.0
	for ant in ants_in_contact:
		var strength := 1.0
		if ant.colony.has_tech("restraining_bite"):
			strength = sim.tech_tree.value("restraining_bite", "hold_strength")
		hold += settings.hold_per_ant * strength
	return factor * maxf(0.0, 1.0 - hold)


## The point on the map border closest to the creature.
func _nearest_edge_point(map_size: Vector2) -> Vector2:
	var distances := [position.x, map_size.x - position.x, position.y, map_size.y - position.y]
	match distances.find(distances.min()):
		0: return Vector2(0.0, position.y)
		1: return Vector2(map_size.x, position.y)
		2: return Vector2(position.x, 0.0)
		_: return Vector2(position.x, map_size.y)


## Walks to the nearest map edge at `speed`; once there it has left the map.
func _leave_map(sim: ColonySimulation, speed: float, delta: float) -> void:
	var exit := _nearest_edge_point(sim.grid.world_size())
	if position.distance_to(exit) <= settings.radius:
		has_left_the_map = true
		return
	_walk_towards(sim, exit, speed, delta, true)


## Turns towards `target` with some random wobble, then steps forward at `speed`, bouncing
## off obstacles. `leaving` = it may step right up to the map border.
func _walk_towards(sim: ColonySimulation, target: Vector2, speed: float, delta: float, leaving := false) -> void:
	var angle_to_target := angle_difference(heading, (target - position).angle())
	heading += clampf(angle_to_target, -1.0, 1.0) * settings.turn_speed * delta
	_step(sim, speed, delta, leaving)


## Wanders at random (no target) at `speed`.
func _wander(sim: ColonySimulation, speed: float, delta: float) -> void:
	_step(sim, speed, delta, false)


func _step(sim: ColonySimulation, speed: float, delta: float, leaving: bool) -> void:
	heading += sim.rng.randf_range(-1.0, 1.0) * settings.wander * delta
	var step := Vector2.from_angle(heading) * speed * _held_speed_factor(sim) * delta
	# Check the spot at the front edge of the body, not the center, so it doesn't sink into walls.
	var front := Vector2.from_angle(heading) * settings.radius
	if _hits_obstacle(sim, position + front * Vector2(1, 0) + Vector2(step.x, 0.0), leaving):
		heading = PI - heading
		step.x = 0.0
	if _hits_obstacle(sim, position + front * Vector2(0, 1) + Vector2(step.x, step.y), leaving):
		heading = -heading
		step.y = 0.0
	position += step


## Painted obstacles block it; the map edge only does while it isn't leaving.
func _hits_obstacle(sim: ColonySimulation, spot: Vector2, leaving: bool) -> bool:
	var index := sim.grid.cell_index(spot)
	if index == -1:
		return not leaving
	return sim.grid.obstacle[index] == 1
