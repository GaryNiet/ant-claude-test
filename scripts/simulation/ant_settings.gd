class_name AntSettings
extends RefCounted
## All ant behaviour values, read once from game_settings.cfg and shared by every ant.
## (Reading them once is much faster than looking them up each tick for 100 ants.)
## Each colony has its own copy: values that tech tree upgrades improve keep their starting
## value in a base_ variable and are recalculated by apply_techs().

# Movement and senses — [ant]
var base_speed: float = GameSettings.get_setting("ant", "speed")
var speed := base_speed
var turn_speed: float = GameSettings.get_setting("ant", "turn_speed")
var wander: float = GameSettings.get_setting("ant", "wander")
var sensor_distance: float = GameSettings.get_setting("ant", "sensor_distance")
var sensor_angle: float = GameSettings.get_setting("ant", "sensor_angle")
var sensor_radius_in_cells: int = GameSettings.get_setting("ant", "sensor_radius_in_cells")
var food_sight_radius: float = GameSettings.get_setting("ant", "food_sight_radius")
var base_carry_capacity: int = GameSettings.get_setting("ant", "carry_capacity")
var carry_capacity := base_carry_capacity
var food_reach: float = GameSettings.get_setting("ant", "food_reach")
var gatherers_lay_going_out: bool = GameSettings.get_setting("ant", "gatherers_lay_going_out")
var think_interval_ticks: int = GameSettings.get_setting("ant", "think_interval_ticks")

# Paths — [paths]
var path_wear_per_second: float = GameSettings.get_setting("paths", "wear_per_second")
var path_speed_bonus: float = GameSettings.get_setting("paths", "speed_bonus")

# Personality — [ant_personality]
var scout_fraction: float = GameSettings.get_setting("ant_personality", "scout_fraction")
var homebody_fraction: float = GameSettings.get_setting("ant_personality", "homebody_fraction")
var homebody_min_explore_time: float = GameSettings.get_setting("ant_personality", "homebody_min_explore_time")
var homebody_max_explore_time: float = GameSettings.get_setting("ant_personality", "homebody_max_explore_time")
var explorer_min_explore_time: float = GameSettings.get_setting("ant_personality", "explorer_min_explore_time")
var explorer_max_explore_time: float = GameSettings.get_setting("ant_personality", "explorer_max_explore_time")
var gather_give_up_time: float = GameSettings.get_setting("ant_personality", "gather_give_up_time")

# Going home — [ant_homing]
var push_growth: float = GameSettings.get_setting("ant_homing", "push_growth")
var push_max: float = GameSettings.get_setting("ant_homing", "push_max")
var nest_sight_radius: float = GameSettings.get_setting("ant_homing", "nest_sight_radius")
var stuck_time: float = GameSettings.get_setting("ant_homing", "stuck_time")
var stuck_min_progress: float = GameSettings.get_setting("ant_homing", "stuck_min_progress")
var detour_time: float = GameSettings.get_setting("ant_homing", "detour_time")
var detour_random_direction: bool = GameSettings.get_setting("ant_homing", "detour_random_direction")

# Life — [ant_life]
var lifespan_min: float = GameSettings.get_setting("ant_life", "lifespan_min")
var lifespan_max: float = GameSettings.get_setting("ant_life", "lifespan_max")
var starting_colony_max_age: float = GameSettings.get_setting("ant_life", "starting_colony_max_age")

# Combat — [ant_combat]
var base_hp: float = GameSettings.get_setting("ant_combat", "hp")
var hp := base_hp
var base_attack: float = GameSettings.get_setting("ant_combat", "attack")
var attack := base_attack
var damage_reduction := 0.0      ## taken off every hit (Chitinous armor)
var minimum_damage: float = GameSettings.get_setting("tech_tree", "minimum_damage")
var attack_interval: float = GameSettings.get_setting("ant_combat", "attack_interval")
var join_fight_will: float = GameSettings.get_setting("ant_combat", "join_fight_will")
var contact_fight_will: float = GameSettings.get_setting("ant_combat", "contact_fight_will")
var nest_defense_bonus: float = GameSettings.get_setting("ant_combat", "nest_defense_bonus")
var nest_defense_radius: float = GameSettings.get_setting("ant_combat", "nest_defense_radius")
var enemy_sight_radius: float = GameSettings.get_setting("ant_combat", "enemy_sight_radius")
var raid_sight_radius: float = GameSettings.get_setting("nest", "raid_sight_radius")
var join_fight_give_up_time: float = GameSettings.get_setting("ant_combat", "join_fight_give_up_time")
var fight_zone_radius: float = GameSettings.get_setting("ant_combat", "fight_zone_radius")
var fight_deposit: float = GameSettings.get_setting("ant_combat", "fight_deposit")
var attack_will: float = GameSettings.get_setting("focus", "attack_will")
var restraining_slow_time: float = GameSettings.get_setting("tech_restraining_bite", "slow_time")
## Two ants of rival colonies this close (center to center) are touching: they fight.
var rival_contact_distance: float = 2.0 * float(GameSettings.get_setting("collisions", "ant_radius")) \
	+ float(GameSettings.get_setting("creatures", "contact_margin"))

# Trails — [pheromones]
var going_out_deposit: float = GameSettings.get_setting("pheromones", "going_out_deposit")
var going_home_deposit: float = GameSettings.get_setting("pheromones", "going_home_deposit")
var trail_fade_time: float = GameSettings.get_setting("pheromones", "trail_fade_time")
var detection_threshold: float = GameSettings.get_setting("pheromones", "detection_threshold")


## Recalculates the improvable values from the base values and the colony's tech tree.
func apply_techs(colony: Colony, tree: TechTree) -> void:
	attack = base_attack
	if colony.has_tech("powerful_mandibles"):
		attack += float(tree.value("powerful_mandibles", "extra_attack"))
	damage_reduction = 0.0
	if colony.has_tech("chitinous_armor"):
		damage_reduction += float(tree.value("chitinous_armor", "damage_reduction"))
	carry_capacity = base_carry_capacity
	if colony.has_tech("carry_more"):
		carry_capacity += int(tree.value("carry_more", "extra_carry"))
