class_name Cricket
extends Creature
## A cricket: lives in a small area away from the nests, hopping about (a hop, then a rest).
## When attacked it freezes for startle_time (ants close by can grab it), then flees towards
## the nearest map edge in long, fast hops (flee_speed, much
## faster than an ant) with short pauses, and is gone if it gets there. Ants hanging on to it
## slow it down (hold_per_ant each, much more with Restraining bite), and a Restraining bite
## slows it for a while: it takes Restraining bite or many ants around it to catch one.
## It never fights back. Killed, its body becomes a dead cricket food item (a hard shell:
## slow to cut, worth a lot).

enum State { HOPPING, RESTING, FLEEING }

var state := State.RESTING
var _home: Vector2


func _init(start: Vector2, creature_settings: CreatureSettings) -> void:
	super(start, creature_settings)
	_home = start


func food_value() -> int:
	return settings.value("food_when_killed")


func activity() -> String:
	return State.keys()[state].capitalize()


func is_walking() -> bool:
	return state != State.RESTING


func _on_attacked() -> void:
	if state != State.FLEEING:
		state = State.FLEEING
		_time_in_state = 0.0


func _behave(sim: ColonySimulation, delta: float) -> void:
	match state:
		State.FLEEING:
			_flee(sim, delta)
		State.RESTING:
			if _time_in_state > float(settings.value("rest_time")):
				state = State.HOPPING
				_time_in_state = 0.0
		State.HOPPING:
			_hop(sim, delta)


## Hops towards the map edge: flee_hop_time at flee_speed, then a flee_rest_time pause.
## (After freezing for startle_time when first attacked.)
func _flee(sim: ColonySimulation, delta: float) -> void:
	var fleeing_time := _time_in_state - float(settings.value("startle_time"))
	var cycle: float = float(settings.value("flee_hop_time")) + float(settings.value("flee_rest_time"))
	if fleeing_time >= 0.0 and fmod(fleeing_time, cycle) < float(settings.value("flee_hop_time")):
		_leave_map(sim, settings.value("flee_speed"), delta)


## A short hop, back towards home if it strayed too far.
func _hop(sim: ColonySimulation, delta: float) -> void:
	if _time_in_state > float(settings.value("hop_time")):
		state = State.RESTING
		_time_in_state = 0.0
		return
	if position.distance_to(_home) > float(settings.value("roam_radius")):
		_walk_towards(sim, _home, settings.speed, delta)
	else:
		_wander(sim, settings.speed, delta)
