class_name Enemy
extends RefCounted
## A big creature that comes in from the edge of the map to steal food.
##
##   SEARCHING  Walks towards the nearest nest (where food is likely to be) until it sees food,
##              then walks to it. Gives up after search_give_up_time and leaves.
##   EATING     Standing on food, eating 1 unit every eat_interval seconds until it's full.
##   LEAVING    Walks to the nearest map edge and disappears there (with the food it ate).
##
## Whatever it's doing, while ants touch it, it stops and fights: every attack_interval
## seconds it hits one of the touching ants. When its HP reaches 0 it dies and its body
## becomes a food item (its own food value plus everything it ate).

enum State { SEARCHING, EATING, LEAVING }

var position: Vector2
var previous_position: Vector2  ## where it was one tick ago (to draw it smoothly between ticks)
var heading: float
var state := State.SEARCHING
var hp: float
var max_hp: float
var food_eaten := 0
var has_left_the_map := false
var poison_time_left := 0.0     ## Corrosive sting (ants' upgrade): seconds of poison left
var poison_damage_per_second := 0.0
var poison_team := -1           ## team of the ant that poisoned it
var damage_to_show := 0.0       ## damage taken since the simulation last reported it (damage numbers)
var damage_attacker_team := -1  ## team of whoever hurt it last (-1 = a spider)
var ants_in_contact: Array[Ant] = []  ## filled by the simulation every tick

var _settings: EnemySettings
var _time_until_attack: float
var _time_in_state := 0.0


func _init(start: Vector2, settings: EnemySettings) -> void:
	position = start
	previous_position = start
	_settings = settings
	max_hp = settings.hp
	hp = settings.hp
	_time_until_attack = settings.attack_interval


func is_dead() -> bool:
	return hp <= 0.0


## Called when an ant hits the spider.
func take_damage(amount: float, attacker: Ant) -> void:
	hp -= amount
	damage_to_show += amount
	damage_attacker_team = attacker.colony.team


## Corrosive sting: loses `damage_per_second` health for `duration` seconds.
func poison(damage_per_second: float, duration: float, team: int) -> void:
	poison_damage_per_second = damage_per_second
	poison_time_left = duration
	poison_team = team


## Advances the enemy by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	previous_position = position
	if poison_time_left > 0.0:
		poison_time_left -= delta
		hp -= poison_damage_per_second * delta
		damage_to_show += poison_damage_per_second * delta
		damage_attacker_team = poison_team
	_time_in_state += delta
	if not ants_in_contact.is_empty():
		_fight(sim, delta)
		return
	_time_until_attack = _settings.attack_interval
	match state:
		State.SEARCHING:
			_search(sim, delta)
		State.EATING:
			_eat(sim)
		State.LEAVING:
			_leave(sim, delta)


func _search(sim: ColonySimulation, delta: float) -> void:
	if _time_in_state > _settings.search_give_up_time:
		_set_state(State.LEAVING)
		return
	if _food_under_body(sim) != MapGrid.NO_FOOD:
		_set_state(State.EATING)
		return
	var food := sim.grid.find_food_near(position, _settings.food_sight_radius)
	var target := food if food != MapGrid.NO_FOOD else sim.nearest_colony(position).nest_position
	_walk_towards(sim, target, delta)


func _eat(sim: ColonySimulation) -> void:
	if _time_in_state < _settings.eat_interval:
		return
	_time_in_state = 0.0
	var food := _food_under_body(sim)
	if food == MapGrid.NO_FOOD or not sim.take_food(food):
		_set_state(State.SEARCHING)  # this spot is empty, look for more
		return
	food_eaten += 1
	sim.food_eaten_by_enemies += 1
	if food_eaten >= _settings.appetite:
		_set_state(State.LEAVING)


func _leave(sim: ColonySimulation, delta: float) -> void:
	var exit := _nearest_edge_point(sim.grid.world_size())
	if position.distance_to(exit) <= _settings.radius:
		has_left_the_map = true
		return
	_walk_towards(sim, exit, delta)


## Hits one random touching ant every attack_interval seconds.
## Ants with Restraining bite hold it down: it attacks slower.
func _fight(sim: ColonySimulation, delta: float) -> void:
	for ant in ants_in_contact:
		if ant.colony.has_tech("restraining_bite"):
			delta *= float(sim.tech_tree.value("restraining_bite", "opponent_speed"))
			break
	_time_until_attack -= delta
	if _time_until_attack > 0.0:
		return
	_time_until_attack = _settings.attack_interval
	var victim: Ant = ants_in_contact[sim.rng.randi_range(0, ants_in_contact.size() - 1)]
	victim.take_damage(_settings.attack, self)


func _set_state(new_state: State) -> void:
	state = new_state
	_time_in_state = 0.0


## Closest food the body is touching, or NO_FOOD.
func _food_under_body(sim: ColonySimulation) -> Vector2:
	return sim.grid.find_food_near(position, _settings.radius)


## The point on the map border closest to the enemy.
func _nearest_edge_point(map_size: Vector2) -> Vector2:
	var distances := [position.x, map_size.x - position.x, position.y, map_size.y - position.y]
	match distances.find(distances.min()):
		0: return Vector2(0.0, position.y)
		1: return Vector2(map_size.x, position.y)
		2: return Vector2(position.x, 0.0)
		_: return Vector2(position.x, map_size.y)


## Turns towards `target` with some random wobble, then steps forward, bouncing off
## obstacles. (At the map edge it can step right up to the border, to leave.)
func _walk_towards(sim: ColonySimulation, target: Vector2, delta: float) -> void:
	var angle_to_target := angle_difference(heading, (target - position).angle())
	heading += clampf(angle_to_target, -1.0, 1.0) * _settings.turn_speed * delta
	heading += sim.rng.randf_range(-1.0, 1.0) * _settings.wander * delta
	var step := Vector2.from_angle(heading) * _settings.speed * delta
	# Check the spot at the front edge of the body, not the center, so it doesn't sink into walls.
	var front := Vector2.from_angle(heading) * _settings.radius
	if _hits_obstacle(sim, position + front * Vector2(1, 0) + Vector2(step.x, 0.0)):
		heading = PI - heading
		step.x = 0.0
	if _hits_obstacle(sim, position + front * Vector2(0, 1) + Vector2(step.x, step.y)):
		heading = -heading
		step.y = 0.0
	position += step


## Painted obstacles block the enemy; the map edge only does while it isn't leaving.
func _hits_obstacle(sim: ColonySimulation, spot: Vector2) -> bool:
	var index := sim.grid.cell_index(spot)
	if index == -1:
		return state != State.LEAVING
	return sim.grid.obstacle[index] == 1
