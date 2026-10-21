class_name AntCollisions
extends RefCounted
## Stops ants from overlapping: each ant is a small circle, and any two circles that
## overlap are pushed apart (each moves half the overlap). No bouncing, no physics engine.
##
## Finding which ants are close uses a "uniform grid": every tick the ants are sorted into
## map squares, and each ant only checks ants in its own square and the 8 around it.
## That keeps the cost proportional to the number of ants (checking every pair of ants
## would be ~100x slower at 1,000 ants). See docs/collision_study.md for measurements.

var enabled: bool = GameSettings.get_setting("collisions", "enabled")
var ant_radius: float = GameSettings.get_setting("collisions", "ant_radius")
var square_size: float = GameSettings.get_setting("collisions", "grid_square_size")
var contacts_last_tick := 0  ## number of overlapping pairs found in the last tick (for stats)
## Pairs [ant, ant] of different colonies touching in the last tick (they will fight).
var rival_contacts: Array[Array] = []
var _rival_contact_distance_squared: float
var _grid: MapGrid           ## the map, to avoid pushing ants into obstacles

var _columns: int
var _rows: int
# The grid, stored in flat arrays that are reused every tick (nothing is created per tick):
var _square_of_ant := PackedInt32Array()     ## which square each ant is in
var _ants_in_square := PackedInt32Array()    ## how many ants each square holds
var _first_in_square := PackedInt32Array()   ## where each square's ants start in _ants_by_square
var _ants_by_square := PackedInt32Array()    ## ant indexes, grouped square by square


func _init(map_size: Vector2) -> void:
	if square_size < ant_radius * 2.0:
		push_error("[collisions] grid_square_size must be at least 2x ant_radius, or collisions are missed")
	_columns = int(ceil(map_size.x / square_size)) + 1
	_rows = int(ceil(map_size.y / square_size)) + 1
	_ants_in_square.resize(_columns * _rows)
	_first_in_square.resize(_columns * _rows)
	var contact_distance := ant_radius * 2.0 + float(GameSettings.get_setting("enemies", "contact_margin"))
	_rival_contact_distance_squared = contact_distance * contact_distance


## Pushes apart every pair of overlapping ants (never into an obstacle or off the map), and
## lists the touching ants of different colonies in rival_contacts.
func resolve(ants: Array[Ant], grid: MapGrid) -> void:
	contacts_last_tick = 0
	rival_contacts.clear()
	if not enabled:
		return
	_grid = grid
	_sort_ants_into_squares(ants)
	for ant_index in ants.size():
		_push_away_neighbours(ants, ant_index)


## Fills the grid arrays (a "counting sort": count ants per square, then place them).
func _sort_ants_into_squares(ants: Array[Ant]) -> void:
	_square_of_ant.resize(ants.size())
	_ants_by_square.resize(ants.size())
	_ants_in_square.fill(0)
	for ant_index in ants.size():
		var square := _square_at(ants[ant_index].position)
		_square_of_ant[ant_index] = square
		_ants_in_square[square] += 1

	var running_total := 0
	for square in _ants_in_square.size():
		_first_in_square[square] = running_total
		running_total += _ants_in_square[square]

	_ants_in_square.fill(0)
	for ant_index in ants.size():
		var square := _square_of_ant[ant_index]
		_ants_by_square[_first_in_square[square] + _ants_in_square[square]] = ant_index
		_ants_in_square[square] += 1


## Checks ant `ant_index` against the ants in the 3x3 squares around it.
func _push_away_neighbours(ants: Array[Ant], ant_index: int) -> void:
	var square := _square_of_ant[ant_index]
	var column := square % _columns
	var row := square / _columns
	var ant := ants[ant_index]
	for neighbour_row in range(maxi(row - 1, 0), mini(row + 2, _rows)):
		for neighbour_column in range(maxi(column - 1, 0), mini(column + 2, _columns)):
			var neighbour_square := neighbour_row * _columns + neighbour_column
			var first := _first_in_square[neighbour_square]
			for slot in range(first, first + _ants_in_square[neighbour_square]):
				var other_index := _ants_by_square[slot]
				if other_index > ant_index:  # each pair only once
					_push_apart(ant, ants[other_index])


func _push_apart(a: Ant, b: Ant) -> void:
	var offset := b.position - a.position
	var touching_distance := ant_radius * 2.0
	var distance_squared := offset.length_squared()
	if a.colony != b.colony and distance_squared <= _rival_contact_distance_squared:
		rival_contacts.append([a, b])
	if distance_squared >= touching_distance * touching_distance:
		return
	contacts_last_tick += 1
	var distance := sqrt(distance_squared)
	# Two ants exactly on top of each other: push them apart sideways.
	var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
	var half_overlap := direction * (touching_distance - distance) * 0.5
	_move_if_free(a, a.position - half_overlap)
	_move_if_free(b, b.position + half_overlap)


func _move_if_free(ant: Ant, target: Vector2) -> void:
	if not _grid.is_obstacle(target):
		ant.position = target


func _square_at(world_position: Vector2) -> int:
	var column := clampi(int(world_position.x / square_size), 0, _columns - 1)
	var row := clampi(int(world_position.y / square_size), 0, _rows - 1)
	return row * _columns + column
