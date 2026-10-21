class_name UiTheme
extends RefCounted
## The look shared by every panel and menu: font size, panel color, text color.


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = GameSettings.get_setting("ui", "font_size")
	var background := StyleBoxFlat.new()
	background.bg_color = GameSettings.get_color("ui", "panel_color")
	background.set_content_margin_all(6)
	theme.set_stylebox("panel", "PanelContainer", background)
	theme.set_color("font_color", "Label", GameSettings.get_color("colors", "hud_text"))
	return theme
