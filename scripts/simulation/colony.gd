class_name Colony
extends RefCounted
## One ant colony: its nest, the food stored in it, its upgrades and its statistics.
## A level can have several colonies; one of them is the player's ("our" colony), the others
## are rivals. Ants only follow their own colony's trails and fight ants of other colonies.

var index: int            ## position in the simulation's list of colonies (also its trails)
var name: String
var is_player: bool
var nest_position: Vector2
var nest_radius: float    ## ants count as "home" inside this distance; grows with the colony
var ant_settings := AntSettings.new()   ## each colony's ants get its own upgrades
var upgrades := ColonyUpgrades.new()

var starting_ants: int
var ant_count := 0        ## living ants of this colony
var food_stored := 0      ## food in the nest, for new ants and upgrades
var time_until_birth := 0.0
var first_ants_spawned := 0  ## the starting colony emerges over time; this counts them

# Statistics
var total_food_collected := 0
var ants_born := 0
var ants_killed := 0         ## in fights (by spiders or rival ants)
var ants_died_of_old_age := 0
var _delivery_times: Array[float] = []  ## when each recent food arrived, for food per second

var _base_birth_interval: float = GameSettings.get_setting("nest", "birth_interval")
var _food_rate_window: float = GameSettings.get_setting("display", "food_rate_window")


func _init(colony_index: int, colony_name: String, player: bool, nest: Vector2, ants_at_start: int) -> void:
	index = colony_index
	name = colony_name
	is_player = player
	nest_position = nest
	starting_ants = ants_at_start
	time_until_birth = birth_interval()


## Seconds between two births (shorter with the "Faster spawn" upgrade).
func birth_interval() -> float:
	return _base_birth_interval / (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.SPAWN))


## Food arriving at the nest is stored (for new ants and upgrades).
func deliver_food(amount: int, time: float) -> void:
	total_food_collected += amount
	food_stored += amount
	for piece in amount:
		_delivery_times.append(time)


## Average food delivered per second over the last few seconds (`time` = now).
func food_per_second(time: float) -> float:
	while not _delivery_times.is_empty() and _delivery_times[0] < time - _food_rate_window:
		_delivery_times.pop_front()
	var window := minf(time, _food_rate_window)
	if window <= 0.0:
		return 0.0
	return _delivery_times.size() / window
