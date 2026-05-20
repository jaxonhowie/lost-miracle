extends Control

@onready var name_label: Label = $HBoxContainer/InfoContainer/NameLevel/NameLabel
@onready var level_label: Label = $HBoxContainer/InfoContainer/NameLevel/LevelLabel
@onready var hp_bar: ProgressBar = $HBoxContainer/InfoContainer/HPBar
@onready var xp_bar: ProgressBar = $HBoxContainer/InfoContainer/XPBar
@onready var gold_label: Label = $HBoxContainer/InfoContainer/StatsRow/GoldLabel
@onready var stat_label: Label = $HBoxContainer/InfoContainer/StatsRow/StatLabel

var player: Node2D = null
var _loot_container: VBoxContainer = null
const MAX_LOOT_LINES: int = 5

func _ready():
	# Style HP bar
	hp_bar.add_theme_stylebox_override("fill", _create_bar_style(Color(0.8, 0.2, 0.2)))
	hp_bar.add_theme_stylebox_override("background", _create_bar_style(Color(0.2, 0.2, 0.2)))

	# Style XP bar
	xp_bar.add_theme_stylebox_override("fill", _create_bar_style(Color(0.2, 0.6, 0.9)))
	xp_bar.add_theme_stylebox_override("background", _create_bar_style(Color(0.15, 0.15, 0.2)))

	# Create loot notification container
	_loot_container = VBoxContainer.new()
	_loot_container.position = Vector2(10, 125)
	_loot_container.custom_minimum_size = Vector2(300, 0)
	add_child(_loot_container)

	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		_update_display()

	# Connect to drop system
	var drop_sys = get_node_or_null("/root/DropSystem")
	if drop_sys:
		drop_sys.item_dropped.connect(_on_item_dropped)

func _process(_delta):
	if player:
		_update_display()

func _update_display():
	if not player:
		return

	# HP
	hp_bar.max_value = player.get_total_max_hp()
	hp_bar.value = player.hp

	# Gold
	gold_label.text = str(player.gold)

	# Stats
	var atk = player.get_total_attack()
	var def = player.get_total_defense()
	stat_label.text = "攻:%d 防:%d" % [atk, def]

	# Level & XP
	var level_sys = get_node_or_null("/root/LevelSystem")
	if level_sys:
		level_label.text = "Lv.%d" % level_sys.level
		xp_bar.max_value = level_sys.xp_to_next_level()
		xp_bar.value = level_sys.xp

func _on_item_dropped(item_id: String, count: int, _position: Vector2):
	if item_id == "gold":
		return
	var item_data = ItemDatabase.get_item(item_id)
	var item_name = item_data.get("name", item_id)
	var quality = item_data.get("quality", "normal")
	var color = ItemDatabase.get_quality_color(quality)

	var label = Label.new()
	label.text = "获得: %s x%d" % [item_name, count]
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = color
	_loot_container.add_child(label)

	# Limit lines
	while _loot_container.get_child_count() > MAX_LOOT_LINES:
		_loot_container.get_child(0).queue_free()

	# Fade out after 3 seconds
	var tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _create_bar_style(fill_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style
