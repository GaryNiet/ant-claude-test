class_name Enemy
extends RefCounted
## A big creature that walks in from the edge of the map towards the nest.
## While ants touch it, it stops and fights: every attack_interval seconds it hits one of
## the touching ants. When its HP reaches 0 it dies and turns into a pile of food.

var position: Vector2
var heading: float
var hp: float
var max_hp: float
var ants_in_contact: Array[Ant] = []  ## filled by the simulation every tick

var _settings: EnemySettings
var _time_until_attack: float


func _init(start: Vector2, settings: EnemySettings) -> void:
	position = start
	_settings = settings
	max_hp = settings.hp
	hp = settings.hp
	_time_until_attack = settings.attack_interval


func is_dead() -> bool:
	return hp <= 0.0


func take_damage(amount: float) -> void:
	hp -= amount


## Advances the enemy by one tick of `delta` seconds.
func update(sim: ColonySimulation, delta: float) -> void:
	if ants_in_contact.is_empty():
		_time_until_attack = _settings.attack_interval
		_walk_towards_nest(sim, delta)
	else:
		_fight(sim, delta)


## Hits one random touching ant every attack_interval seconds.
func _fight(sim: ColonySimulation, delta: float) -> void:
	_time_until_attack -= delta
	if _time_until_attack > 0.0:
		return
	_time_until_attack = _settings.attack_interval
	var victim: Ant = ants_in_contact[sim.rng.randi_range(0, ants_in_contact.size() - 1)]
	victim.take_damage(_settings.attack, self)


## Heads for the nest with some random wobble, bouncing off obstacles and map edges.
func _walk_towards_nest(sim: ColonySimulation, delta: float) -> void:
	var angle_to_nest := angle_difference(heading, (sim.nest_position - position).angle())
	heading += clampf(angle_to_nest, -1.0, 1.0) * _settings.turn_speed * delta
	heading += sim.rng.randf_range(-1.0, 1.0) * _settings.wander * delta
	var step := Vector2.from_angle(heading) * _settings.speed * delta
	# Check the spot at the front edge of the body, not the center, so it doesn't sink into walls.
	var front := Vector2.from_angle(heading) * _settings.radius
	if sim.grid.is_obstacle(position + front * Vector2(1, 0) + Vector2(step.x, 0.0)):
		heading = PI - heading
		step.x = 0.0
	if sim.grid.is_obstacle(position + front * Vector2(0, 1) + Vector2(step.x, step.y)):
		heading = -heading
		step.y = 0.0
	position += step
