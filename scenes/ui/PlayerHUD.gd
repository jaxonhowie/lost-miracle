extends Control

@onready var name_label: Label = $HBoxContainer/InfoContainer/NameLevel/NameLabel
@onready var level_label: Label = $HBoxContainer/InfoContainer/NameLevel/LevelLabel
@onready var hp_bar: ProgressBar = $HBoxContainer/InfoContainer/HPBar
@onready var mp_bar: ProgressBar = $HBoxContainer/InfoContainer/MPBar
@onready var gold_label: Label = $HBoxContainer/InfoContainer/StatsRow/GoldLabel
@onready var stat_label: Label = $HBoxContainer/InfoContainer/StatsRow/StatLabel

var player: Node2D = null

func _ready():
	# Style HP bar
	hp_bar.add_theme_stylebox_override("fill", _create_bar_style(Color(0.8, 0.2, 0.2)))
	hp_bar.add_theme_stylebox_override("background", _create_bar_style(Color(0.2, 0.2, 0.2)))

	# Style MP bar
	mp_bar.add_theme_stylebox_override("fill", _create_bar_style(Color(0.2, 0.4, 0.8)))
	mp_bar.add_theme_stylebox_override("background", _create_bar_style(Color(0.15, 0.15, 0.2)))

	# Find player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		_update_display()

func _process(_delta):
	if player:
		_update_display()

func _update_display():
	if not player:
		return

	# HP
	hp_bar.max_value = player.get_total_max_hp()
	hp_bar.value = player.hp

	# MP (placeholder - no MP system yet)
	mp_bar.max_value = 100
	mp_bar.value = 100

	# Gold
	gold_label.text = str(player.gold)

	# Stats
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	var atk = player.get_total_attack()
	var def = player.get_total_defense()
	stat_label.text = "攻:%d 防:%d" % [atk, def]

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
