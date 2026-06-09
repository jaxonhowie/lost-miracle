class_name UIHelper
extends RefCounted

## UI 工具函数

## 创建带样式的按钮
static func create_button(text: String, min_size: Vector2 = Vector2(120, 40)) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	return btn

## 创建标签
static func create_label(text: String, font_size: int = 16) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

## 创建 HP 条
static func create_hp_bar(max_val: int, current_val: int, width: int = 200) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.max_value = max_val
	bar.value = current_val
	bar.custom_minimum_size = Vector2(width, 20)
	bar.show_percentage = false
	# 红色样式
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bar.add_theme_stylebox_override("background", bg)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.15, 0.15)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

## 品质颜色文字
static func quality_colored_text(text: String, quality: String) -> String:
	return "[color=#%s]%s[/color]" % [Equipment.QUALITY_COLORS.get(quality, Color.WHITE).to_html(false), text]
