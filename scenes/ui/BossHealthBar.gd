extends Control

var _boss_ref: Node2D = null
var _visible: bool = false

@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar

func _ready():
	visible = false
	modulate.a = 0.0
	hp_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.7, 0.1, 0.1)))
	hp_bar.add_theme_stylebox_override("background", _bar_style(Color(0.15, 0.15, 0.15)))

func _process(_delta):
	if not is_instance_valid(_boss_ref):
		if _visible:
			_hide_bar()
		# Scan for nearby boss monsters
		_find_boss()
		return

	# Update HP
	hp_bar.max_value = _boss_ref.max_hp
	hp_bar.value = _boss_ref.hp

	# Hide if boss is dead
	if _boss_ref.current_state == _boss_ref.State.DEAD:
		_hide_bar()
		_boss_ref = null

func _find_boss():
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	var monsters = get_tree().get_nodes_in_group("monsters")
	for m in monsters:
		if not is_instance_valid(m) or m.current_state == m.State.DEAD:
			continue
		if m.monster_id.ends_with("_boss"):
			var dist = player.global_position.distance_to(m.global_position)
			if dist < 400:
				_show_bar(m)
				return

func _show_bar(boss: Node2D):
	_boss_ref = boss
	_visible = true
	var item_data = MonsterDatabase.get_monster(boss.monster_id)
	name_label.text = item_data.get("name", boss.monster_id) if not item_data.is_empty() else boss.monster_id
	hp_bar.max_value = boss.max_hp
	hp_bar.value = boss.hp
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

func _hide_bar():
	_visible = false
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)

func _bar_style(color: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s
