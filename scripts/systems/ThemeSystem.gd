extends Node

var theme: Theme

func _ready():
	theme = Theme.new()
	_setup_panel_style()
	_setup_button_style()
	_setup_label_style()
	_setup_tab_style()
	_apply_to_viewport()

func _setup_panel_style():
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.95)
	panel_style.border_color = Color(0.3, 0.25, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(12)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	var panel_normal = StyleBoxFlat.new()
	panel_normal.bg_color = Color(0.1, 0.09, 0.12, 0.9)
	panel_normal.border_color = Color(0.25, 0.2, 0.18)
	panel_normal.set_border_width_all(1)
	panel_normal.set_corner_radius_all(4)
	theme.set_stylebox("panel", "Panel", panel_normal)

func _setup_button_style():
	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.18, 0.15, 0.12)
	btn_normal.border_color = Color(0.4, 0.35, 0.3)
	btn_normal.set_border_width_all(1)
	btn_normal.set_corner_radius_all(4)
	btn_normal.set_content_margin_all(8)
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.2, 0.15)
	btn_hover.border_color = Color(0.6, 0.5, 0.35)
	btn_hover.set_border_width_all(1)
	btn_hover.set_corner_radius_all(4)
	btn_hover.set_content_margin_all(8)
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.12, 0.1, 0.08)
	btn_pressed.border_color = Color(0.5, 0.4, 0.3)
	btn_pressed.set_border_width_all(1)
	btn_pressed.set_corner_radius_all(4)
	btn_pressed.set_content_margin_all(8)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled = StyleBoxFlat.new()
	btn_disabled.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	btn_disabled.border_color = Color(0.2, 0.2, 0.2, 0.5)
	btn_disabled.set_border_width_all(1)
	btn_disabled.set_corner_radius_all(4)
	btn_disabled.set_content_margin_all(8)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	theme.set_color("font_color", "Button", Color(0.85, 0.8, 0.7))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.95, 0.8))
	theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.4))

func _setup_label_style():
	theme.set_color("font_color", "Label", Color(0.85, 0.8, 0.7))
	theme.set_font_size("font_size", "Label", 14)

func _setup_tab_style():
	var tab_bg = StyleBoxFlat.new()
	tab_bg.bg_color = Color(0.12, 0.1, 0.08)
	tab_bg.set_content_margin_all(8)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_bg)

	var tab_selected = StyleBoxFlat.new()
	tab_selected.bg_color = Color(0.2, 0.17, 0.13)
	tab_selected.border_color = Color(0.5, 0.4, 0.3)
	tab_selected.set_border_width_all(1)
	tab_selected.set_content_margin_all(8)
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)

	var tab_panel = StyleBoxFlat.new()
	tab_panel.bg_color = Color(0.1, 0.09, 0.12, 0.95)
	tab_panel.border_color = Color(0.3, 0.25, 0.2)
	tab_panel.set_border_width_all(1)
	tab_panel.set_content_margin_all(8)
	theme.set_stylebox("panel", "TabContainer", tab_panel)

func _apply_to_viewport():
	get_viewport().theme = theme
