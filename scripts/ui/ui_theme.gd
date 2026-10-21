class_name UiTheme
extends RefCounted
## The look shared by every panel and menu: font size, panel color, text color, and buttons
## that look like in-game buttons (raised, rounded, with a border; darker when pressed or
## selected). Colors and sizes are in [ui] in game_settings.cfg.


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = GameSettings.get_setting("ui", "font_size")
	var background := StyleBoxFlat.new()
	background.bg_color = GameSettings.get_color("ui", "panel_color")
	background.set_content_margin_all(6)
	theme.set_stylebox("panel", "PanelContainer", background)
	theme.set_color("font_color", "Label", GameSettings.get_color("colors", "hud_text"))
	_add_button_styles(theme)
	_add_progress_bar_styles(theme)
	return theme


## Progress bars: a dark groove that fills with ochre.
static func _add_progress_bar_styles(theme: Theme) -> void:
	var groove := StyleBoxFlat.new()
	groove.bg_color = GameSettings.get_color("ui", "button_pressed_color")
	groove.border_color = GameSettings.get_color("ui", "button_border_color")
	groove.set_border_width_all(1)
	groove.set_corner_radius_all(GameSettings.get_setting("ui", "button_corner_radius"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameSettings.get_color("ui", "progress_color")
	fill.set_corner_radius_all(GameSettings.get_setting("ui", "button_corner_radius"))
	theme.set_stylebox("background", "ProgressBar", groove)
	theme.set_stylebox("fill", "ProgressBar", fill)


static func _add_button_styles(theme: Theme) -> void:
	var border: Color = GameSettings.get_color("ui", "button_border_color")
	var styles := {
		"normal": _button_box(GameSettings.get_color("ui", "button_color"), border, false),
		"hover": _button_box(GameSettings.get_color("ui", "button_hover_color"), border, false),
		"pressed": _button_box(GameSettings.get_color("ui", "button_pressed_color"), GameSettings.get_color("ui", "button_selected_border_color"), true),
		"hover_pressed": _button_box(GameSettings.get_color("ui", "button_pressed_color"), GameSettings.get_color("ui", "button_selected_border_color"), true),
		"disabled": _button_box(GameSettings.get_color("ui", "button_disabled_color"), border, false),
		"focus": StyleBoxEmpty.new(),
	}
	for state in styles:
		theme.set_stylebox(state, "Button", styles[state])
	var text: Color = GameSettings.get_color("colors", "hud_text")
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		theme.set_color(state, "Button", text)
	theme.set_color("font_disabled_color", "Button", GameSettings.get_color("ui", "button_disabled_text_color"))


## A rounded box with a border and a darker bottom edge (so it looks raised), or, when
## `pushed_in`, a thick top edge instead (so it looks pressed into the panel).
static func _button_box(color: Color, border: Color, pushed_in: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	if pushed_in:
		box.border_width_top = 4
	else:
		box.border_width_bottom = 4
	box.set_corner_radius_all(GameSettings.get_setting("ui", "button_corner_radius"))
	box.set_content_margin_all(6)
	return box


## Makes `button` shrink a little while it is held down and spring back when released.
static func add_click_animation(button: Button) -> void:
	var click_scale: float = GameSettings.get_setting("ui", "click_scale")
	var click_time: float = GameSettings.get_setting("ui", "click_time")
	button.resized.connect(func() -> void: button.pivot_offset = button.size / 2.0)
	button.button_down.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE * click_scale, click_time))
	button.button_up.connect(func() -> void:
		button.create_tween().tween_property(button, "scale", Vector2.ONE, click_time))
