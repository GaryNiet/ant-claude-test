class_name Colony
extends RefCounted
## One ant colony: its nest, the food and larvae stored in it, its tech tree upgrades, the
## behaviour the player set, its maturity and its statistics.
##
## A level can have several colonies: one is the player's ("our" colony), the others are
## rivals; nuptial flights add allied colonies. Colonies of the same team are allies; ants
## fight ants of other teams. Ants only follow their own colony's trails.
##
## Larvae: the queen lays a larva for food_per_larva stored food when asked (the player's Lay
## buttons; rival and allied colonies lay whenever they can afford it). Laying takes lay_time
## per larva, one after the other. Laid larvae are stored in the nest until they are hatched
## (by the player, or automatically with auto hatch). Hatching larvae also wait in a queue
## and hatch one after the other, each taking hatch_time.

var index: int            ## position in the simulation's list of colonies (also its trails)
var name: String
var is_player: bool
var team: int             ## colonies with the same team are allies
var nest_position: Vector2
var position: Vector2:    ## where it is, for ants fighting the nest (= nest_position)
	get:
		return nest_position
var nest_radius: float    ## ants count as "home" inside this distance; grows with the colony
var hp: float             ## nest health (rival ants attack a nest with no larvae left)
var max_hp: float
var destroyed := false
var damage_to_show := 0.0       ## damage taken since the simulation last reported it (damage numbers)
var damage_attacker_team := -1  ## team of whoever hurt it last
var ant_settings := AntSettings.new()
var techs := {}           ## tech tree node -> true when owned (shared with allied colonies)
var maturity := 1         ## grows with the number of ants, never goes back

var starting_ants: int
var founded_time := 0.0   ## when the colony started (its first ants emerge from then on)
var ant_count := 0        ## living ants of this colony
var food_stored: int      ## food in the nest, for larvae and upgrades
var laying := 0           ## larvae in the laying queue (paid for; the first one is being laid)
var lay_time_left := 0.0  ## seconds until the first larva in the queue is laid
var larvae := 0           ## larvae stored, waiting to hatch
var hatching := 0                 ## larvae in the hatching queue (the first one is hatching now)
var hatch_time_left := 0.0        ## seconds until the first larva in the queue hatches
var infinite_hatch := false       ## hatch every larva as soon as it's laid
var nests_to_found := 0           ## Nuptial flights bought but not placed yet
var focus_target := Vector2.INF   ## where the Focus tool last sent the attack ants (INF = nowhere)
var first_ants_spawned := 0       ## the starting colony emerges over time; this counts them
var _mushroom_food := 0.0         ## mushroom food growing, added to the store by whole units

# Behaviour, set by the player; only ants hatched after a change use the new values.
var aggressivity: float = GameSettings.get_setting("behaviour", "aggressivity")
var exploring: float = GameSettings.get_setting("behaviour", "exploring")

# Statistics
var total_food_collected := 0
var ants_born := 0
var ants_killed := 0         ## in fights (by spiders or rival ants)
var ants_died_of_old_age := 0
var larvae_stolen := 0       ## by rival ants raiding this nest
var food_stolen := 0         ## stored food taken by rival ants raiding this nest
var _delivery_times: Array[float] = []  ## when each recent food arrived, for food per second

var _lay_time: float = GameSettings.get_setting("nest", "lay_time")
var _hatch_time: float = GameSettings.get_setting("nest", "hatch_time")
var _food_rate_window: float = GameSettings.get_setting("display", "food_rate_window")


func _init(colony_index: int, colony_name: String, player: bool, colony_team: int, nest: Vector2, ants_at_start: int) -> void:
	index = colony_index
	name = colony_name
	is_player = player
	team = colony_team
	nest_position = nest
	starting_ants = ants_at_start
	max_hp = GameSettings.get_setting("nest", "hp")
	hp = max_hp
	food_stored = GameSettings.get_setting("nest", "starting_food")
	infinite_hatch = not player or GameSettings.get_setting("nest", "player_starts_with_infinite_hatch")


func has_tech(node: String) -> bool:
	return techs.has(node)


func is_dead() -> bool:
	return destroyed


## Rival ants attacking the nest (when it has no larvae left to steal).
func take_damage(amount: float, attacker: Ant) -> void:
	hp -= amount
	damage_to_show += amount
	damage_attacker_team = attacker.colony.team


## Seconds to lay one larva (shorter with the Faster larvae upgrades).
func lay_time(tree: TechTree) -> float:
	var bonus := 0.0
	for node in ["faster_larvae", "faster_larvae_2"]:
		if has_tech(node):
			bonus += tree.value(node, "speed_bonus")
	return _lay_time / (1.0 + bonus)


## Pays for up to `count` larvae (`cost` food each, as many as the food allows) and puts
## them in the laying queue. Returns how many were added.
func lay(count: int, cost: int, tree: TechTree) -> int:
	var added := 0
	while added < count and food_stored >= cost:
		food_stored -= cost
		added += 1
	if laying == 0 and added > 0:
		lay_time_left = lay_time(tree)  # the queue was empty: the first one starts now
	laying += added
	return added


## Advances the larva being laid; returns 1 when it is laid (then the next one in the
## queue starts), otherwise 0.
func update_laying(delta: float, tree: TechTree) -> int:
	if laying == 0:
		return 0
	lay_time_left -= delta
	if lay_time_left > 0.0:
		return 0
	laying -= 1
	lay_time_left = lay_time(tree) if laying > 0 else 0.0
	return 1


## How far the larva being laid now is (0 = just started, 1 = laid).
func lay_progress(tree: TechTree) -> float:
	if laying == 0:
		return 0.0
	return 1.0 - lay_time_left / lay_time(tree)


## Puts up to `count` stored larvae in the hatching queue. Returns how many were added.
func hatch(count: int) -> int:
	var added := mini(count, larvae)
	if hatching == 0 and added > 0:
		hatch_time_left = _hatch_time  # the queue was empty: the first one starts now
	hatching += added
	larvae -= added
	return added


## Advances the larva that is hatching; returns 1 when it is ready to become an ant (then
## the next one in the queue starts), otherwise 0.
func update_hatching(delta: float) -> int:
	if hatching == 0:
		return 0
	hatch_time_left -= delta
	if hatch_time_left > 0.0:
		return 0
	hatching -= 1
	hatch_time_left = _hatch_time if hatching > 0 else 0.0
	return 1


## How far the larva that is hatching now is (0 = just started, 1 = hatching).
func hatch_progress() -> float:
	if hatching == 0:
		return 0.0
	return 1.0 - hatch_time_left / _hatch_time


## Mushroom harvest: free food trickles in (`food_per_minute`); whole units go to the store.
func grow_mushrooms(food_per_minute: float, delta: float) -> void:
	_mushroom_food += food_per_minute / 60.0 * delta
	var whole := int(_mushroom_food)
	food_stored += whole
	_mushroom_food -= whole


## Food arriving at the nest is stored (for larvae and upgrades).
func deliver_food(amount: int, time: float) -> void:
	total_food_collected += amount
	food_stored += amount
	for piece in amount:
		_delivery_times.append(time)


## Average food delivered per second over the last few seconds (`time` = now).
func food_per_second(time: float) -> float:
	while not _delivery_times.is_empty() and _delivery_times[0] < time - _food_rate_window:
		_delivery_times.pop_front()
	var window := minf(time - founded_time, _food_rate_window)
	if window <= 0.0:
		return 0.0
	return _delivery_times.size() / window
