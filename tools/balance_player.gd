extends RefCounted
## The scripted player of tools/balance_test.gd (see there for how to run it).

const MIXED_UPGRADES := ["carry_more", "chitinous_armor", "restraining_bite", "mushroom_harvest", "motherbase", "faster_larvae", "guarded_paths", "major_ants"]
const ECONOMY_UPGRADES := ["carry_more", "mushroom_harvest", "motherbase", "faster_larvae"]
const FIGHTING_UPGRADES := ["chitinous_armor", "restraining_bite"]
const DECIDE_EVERY_TICKS := 15        ## the player acts twice per game second
const REPORT_EVERY_MINUTES := 2.0
const LARVAE_NEAR_NEST := 200.0       ## beetle larvae this close to the nest are "ours" to hunt
const CRICKET_HUNT_INTERVAL := 20.0   ## game seconds between two Focus clicks on a cricket
const CRICKET_HUNT_ANTS := 40         ## without Restraining bite, hunts crickets from this many ants
const RAID_INTERVAL := 30.0           ## game seconds between two Focus clicks on the rival nest
const RAID_ANTS := 10                 ## raids once it has this many ants

var sim: ColonySimulation
var colony: Colony
var upgrades: Array = []
var bought := 0
var strategy: String
var report: Array[String] = []
var _last_cricket_focus := -INF
var _game_speed: float = GameSettings.get_setting("simulation", "game_speed")


func run(args: PackedStringArray) -> void:
	strategy = args[1]
	var larvae_at := float(args[2])
	var minutes := float(args[3])
	sim = ColonySimulation.new(Level.load_file(args[0]))
	sim.rng.seed = int(args[4])
	colony = sim.player_colony
	_choose_upgrades()
	var tick_length := 1.0 / float(GameSettings.get_setting("simulation", "ticks_per_second"))
	var maturity_2_at := -1.0
	var next_report := REPORT_EVERY_MINUTES
	for tick in int(minutes * 60.0 * _game_speed / tick_length):
		sim.step(tick_length)
		if tick % DECIDE_EVERY_TICKS != 0:
			continue
		_decide(larvae_at)
		var real_minutes := _real_minutes()
		if maturity_2_at < 0.0 and colony.maturity >= 2:
			maturity_2_at = real_minutes
		if real_minutes >= next_report:
			report.append(_status(real_minutes))
			next_report += REPORT_EVERY_MINUTES
	print("== %s %s, larvae at %s, seed %s: maturity 2 at %s min, %d ants, %d food collected%s" % [
		args[0].get_file(), strategy, args[2], args[4], ("%.1f" % maturity_2_at) if maturity_2_at >= 0.0 else "never",
		colony.ant_count, colony.total_food_collected, _rival_summary()])
	for line in report:
		print("   ", line)


func _choose_upgrades() -> void:
	if strategy.begins_with("econ"):
		upgrades = ECONOMY_UPGRADES.slice(0, int(strategy.substr(4)))
	elif strategy.begins_with("up"):
		upgrades = MIXED_UPGRADES.slice(0, int(strategy.substr(2)))
	elif strategy == "cricket" or strategy == "raid":
		upgrades = FIGHTING_UPGRADES


## What the player does: buy the next upgrade, lay larvae with the food it doesn't save,
## and click Focus on beetle larvae, crickets or the rival nest.
func _decide(larvae_at: float) -> void:
	var saving_for := 0
	if bought < upgrades.size():
		var node: String = upgrades[bought]
		if sim.buy_tech(colony, node):
			bought += 1
			report.append("%4.1f min: bought %s (%d ants)" % [_real_minutes(), node, colony.ant_count])
		elif colony.maturity >= sim.tech_tree.maturity(node):
			saving_for = sim.tech_tree.cost(node)
	if colony.laying < 2 and colony.food_stored - sim.food_per_larva >= saving_for:
		sim.lay_larvae(colony, 1)
	var larva := _nearest("beetle_larva", LARVAE_NEAR_NEST)
	if larvae_at >= 0.0 and sim.elapsed_time >= larvae_at and larva != null:
		if colony.focus_target == Vector2.INF or colony.focus_target.distance_to(larva.position) > larva.settings.radius * 3.0:
			sim.focus(colony, larva.position)
	elif (colony.has_tech("restraining_bite") or colony.ant_count >= CRICKET_HUNT_ANTS) and sim.elapsed_time - _last_cricket_focus > CRICKET_HUNT_INTERVAL:
		var cricket := _nearest("cricket", INF)
		if cricket != null:
			sim.focus(colony, cricket.position)
			_last_cricket_focus = sim.elapsed_time
	if strategy == "raid" and bought >= upgrades.size() and colony.ant_count >= RAID_ANTS:
		var rival := _rival()
		if rival != null and int(sim.elapsed_time) % int(RAID_INTERVAL) == 0:
			sim.focus(colony, rival.nest_position)


## Minutes the player has played (real time: the game runs at game_speed).
func _real_minutes() -> float:
	return sim.elapsed_time / _game_speed / 60.0


func _nearest(kind: String, radius: float) -> Creature:
	var closest: Creature = null
	var closest_distance := radius
	for creature in sim.creatures:
		var distance := creature.position.distance_to(colony.nest_position)
		if creature.kind == kind and distance < closest_distance:
			closest = creature
			closest_distance = distance
	return closest


## The first rival colony still standing, or null.
func _rival() -> Colony:
	for other in sim.colonies:
		if other.team != colony.team and not other.destroyed:
			return other
	return null


func _status(real_minutes: float) -> String:
	var killed: Dictionary = sim.creatures_killed
	var line := "%4.1f min: %3d ants, %4d food, %d upgrades | killed: %d beetle larvae, %d crickets, %d spiders | ants lost %d | collected %d" % [
		real_minutes, colony.ant_count, colony.food_stored, bought, killed.beetle_larva, killed.cricket, killed.spider,
		colony.ants_killed, colony.total_food_collected]
	return line + _rival_summary()


func _rival_summary() -> String:
	for other in sim.colonies:
		if other.team != colony.team:
			return " | rival: %d ants, nest %.0f hp%s" % [other.ant_count, other.hp, " (DESTROYED)" if other.destroyed else ""]
	return ""
