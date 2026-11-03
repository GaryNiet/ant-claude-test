class_name BeetleLarva
extends Creature
## A beetle larva (a fat white grub): a few live near every nest from the start of the map.
## It crawls slowly around the spot where it hatched and keeps eating roots, so it grows:
## the food it is worth rises from start_food by food_per_minute, up to max_food.
## It never fights. Ants leave it alone until the player sends them at it (Focus tool):
## kill it early for a quick boost, or let it grow for a bigger one later.
## Killed, its body becomes a larva food item (fast to cut, worth a lot).

var _home: Vector2
var _age := 0.0


func _init(start: Vector2, creature_settings: CreatureSettings) -> void:
	super(start, creature_settings)
	_home = start


func food_value() -> int:
	return roundi(minf(float(settings.value("start_food")) + float(settings.value("food_per_minute")) * _age / 60.0,
		settings.value("max_food")))


## 0 when it starts, 1 once it is fully grown.
func growth() -> float:
	var start: float = settings.value("start_food")
	return clampf((food_value() - start) / (float(settings.value("max_food")) - start), 0.0, 1.0)


func size_multiplier() -> float:
	return lerpf(settings.value("smallest_size"), 1.0, growth())


func activity() -> String:
	return "Crawling and growing (%d%% grown)" % roundi(growth() * 100.0)


func _behave(sim: ColonySimulation, delta: float) -> void:
	_age += delta
	if position.distance_to(_home) > float(settings.value("roam_radius")):
		_walk_towards(sim, _home, settings.speed, delta)
	else:
		_wander(sim, settings.speed, delta)
