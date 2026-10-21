class_name AntSettings
extends RefCounted
## All ant behaviour values, read once from game_settings.cfg and shared by every ant.
## (Reading them once is much faster than looking them up each tick for 100 ants.)
## Values that upgrades improve keep their starting value in a base_ variable.

# Movement and senses — [ant]
var base_speed: float = GameSettings.get_setting("ant", "speed")
var speed := base_speed
var turn_speed: float = GameSettings.get_setting("ant", "turn_speed")
var wander: float = GameSettings.get_setting("ant", "wander")
var sensor_distance: float = GameSettings.get_setting("ant", "sensor_distance")
var sensor_angle: float = GameSettings.get_setting("ant", "sensor_angle")
var sensor_radius_in_cells: int = GameSettings.get_setting("ant", "sensor_radius_in_cells")
var food_sight_radius: float = GameSettings.get_setting("ant", "food_sight_radius")
var base_cut_time: float = GameSettings.get_setting("ant", "cut_time")
var cut_time := base_cut_time
var base_carry_capacity: int = GameSettings.get_setting("ant", "carry_capacity")
var carry_capacity := base_carry_capacity
var food_reach: float = GameSettings.get_setting("ant", "food_reach")
var gatherers_lay_going_out: bool = GameSettings.get_setting("ant", "gatherers_lay_going_out")

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
var attack_interval: float = GameSettings.get_setting("ant_combat", "attack_interval")
var join_fight_will: float = GameSettings.get_setting("ant_combat", "join_fight_will")
var contact_fight_will: float = GameSettings.get_setting("ant_combat", "contact_fight_will")
var nest_defense_bonus: float = GameSettings.get_setting("ant_combat", "nest_defense_bonus")
var nest_defense_radius: float = GameSettings.get_setting("ant_combat", "nest_defense_radius")
var enemy_sight_radius: float = GameSettings.get_setting("ant_combat", "enemy_sight_radius")
var join_fight_give_up_time: float = GameSettings.get_setting("ant_combat", "join_fight_give_up_time")
var fight_zone_radius: float = GameSettings.get_setting("ant_combat", "fight_zone_radius")
var fight_deposit: float = GameSettings.get_setting("ant_combat", "fight_deposit")

# Trails — [pheromones]
var going_out_deposit: float = GameSettings.get_setting("pheromones", "going_out_deposit")
var going_home_deposit: float = GameSettings.get_setting("pheromones", "going_home_deposit")
var trail_fade_time: float = GameSettings.get_setting("pheromones", "trail_fade_time")
var detection_threshold: float = GameSettings.get_setting("pheromones", "detection_threshold")


## Recalculates the upgradable values from the base values and the upgrades bought.
func apply_upgrades(upgrades: ColonyUpgrades) -> void:
	speed = base_speed * (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.SPEED))
	hp = base_hp * (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.HP))
	attack = base_attack * (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.ATTACK))
	carry_capacity = base_carry_capacity + int(upgrades.total_bonus(ColonyUpgrades.Kind.CARRY))
	cut_time = base_cut_time / (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.CUT_SPEED))
