extends Node
## Plays the sound effects for what happens in the game: a spider arriving, a creature being
## killed, and a larva of our colony hatching. Watches the simulation's counters every frame (the
## simulation itself knows nothing about sound).

@export var view_path: NodePath
@onready var view: Node2D = get_node(view_path)  ## SimulationView

var _watched: ColonySimulation
var _creatures_killed := 0
var _spiders_arrived := 0
var _ants_born := 0


func _process(_delta: float) -> void:
	var simulation: ColonySimulation = view.simulation
	if simulation != _watched:  # a new level: start counting from there
		_watched = simulation
		_remember(simulation)
		return
	if simulation.creatures_killed_total > _creatures_killed:
		Sounds.play("spider_death")
	if simulation.spiders_arrived > _spiders_arrived:
		Sounds.play("spider_arrival")
	if simulation.player_colony.ants_born > _ants_born:
		Sounds.play("hatch")
	_remember(simulation)


func _remember(simulation: ColonySimulation) -> void:
	_creatures_killed = simulation.creatures_killed_total
	_spiders_arrived = simulation.spiders_arrived
	_ants_born = simulation.player_colony.ants_born
