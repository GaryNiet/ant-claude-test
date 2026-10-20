class_name AntSettings
extends RefCounted
## All ant behaviour values, read once from game_settings.cfg and shared by every ant.
## (Reading them once is much faster than looking them up each tick for 100 ants.)

# Movement and senses — [ant]
var speed: float = GameSettings.get_setting("ant", "speed")
var turn_speed: float = GameSettings.get_setting("ant", "turn_speed")
var wander: float = GameSettings.get_setting("ant", "wander")
var sensor_distance: float = GameSettings.get_setting("ant", "sensor_distance")
var sensor_angle: float = GameSettings.get_setting("ant", "sensor_angle")
var sensor_radius_in_cells: int = GameSettings.get_setting("ant", "sensor_radius_in_cells")
var food_sight_radius: float = GameSettings.get_setting("ant", "food_sight_radius")
var pickup_distance: float = GameSettings.get_setting("ant", "pickup_distance")
var gatherers_lay_going_out: bool = GameSettings.get_setting("ant", "gatherers_lay_going_out")

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

# Trails — [pheromones]
var going_out_deposit: float = GameSettings.get_setting("pheromones", "going_out_deposit")
var going_home_deposit: float = GameSettings.get_setting("pheromones", "going_home_deposit")
var trail_fade_time: float = GameSettings.get_setting("pheromones", "trail_fade_time")
var detection_threshold: float = GameSettings.get_setting("pheromones", "detection_threshold")
