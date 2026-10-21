extends PopupPanel
## A small Settings window, opened from the main menu or the tool bar.
## For now: the window resolution.

var _resolution_choice: OptionButton
var _note: Label


## Builds the menu. Called by the screen that owns it once everything exists.
func setup() -> void:
	var column := VBoxContainer.new()
	add_child(column)

	var title := Label.new()
	title.text = "Settings"
	column.add_child(title)
	column.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = "Resolution (16:9):"
	row.add_child(label)
	_resolution_choice = OptionButton.new()
	for choice in GameSettings.get_list("window", "resolutions"):
		_resolution_choice.add_item(choice)
	_resolution_choice.item_selected.connect(_on_resolution_selected)
	row.add_child(_resolution_choice)

	_note = Label.new()
	column.add_child(_note)

	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	column.add_child(close)


func open() -> void:
	var current := PlayerSettings.resolution()
	for index in _resolution_choice.item_count:
		if _resolution_choice.get_item_text(index) == current:
			_resolution_choice.select(index)
	_update_note()
	popup_centered()


func _on_resolution_selected(index: int) -> void:
	var choice := _resolution_choice.get_item_text(index)
	PlayerSettings.save_resolution(choice)
	Startup.apply_resolution()
	_update_note()


## Tells the player when the window had to be shrunk to fit their screen.
func _update_note() -> void:
	var wanted := PlayerSettings.parse_resolution(PlayerSettings.resolution())
	var actual := get_tree().root.size
	_note.text = "" if actual == wanted else "Shrunk to %dx%d to fit your screen." % [actual.x, actual.y]
