extends PanelContainer

var is_open: bool = false
var talent_sys: Node

@onready var points_label: Label = $VBoxContainer/PointsLabel
@onready var tab_container: TabContainer = $VBoxContainer/TabContainer
@onready var result_label: Label = $VBoxContainer/ResultLabel
@onready var respec_btn: Button = $VBoxContainer/Footer/RespecButton

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		talent_sys.talent_learned.connect(_on_talent_learned)
		talent_sys.talent_points_changed.connect(_on_points_changed)
	respec_btn.pressed.connect(_on_respec_pressed)

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	_refresh_points()
	_refresh_tabs()

func _refresh_points():
	if not talent_sys:
		return
	points_label.text = "天赋点: %d" % talent_sys.talent_points

func _refresh_tabs():
	if not talent_sys:
		return
	# Clear existing content in each tab
	for tab_idx in tab_container.get_tab_count():
		var tab = tab_container.get_child(tab_idx)
		for child in tab.get_children():
			child.queue_free()
	await get_tree().process_frame

	var categories = talent_sys.get_categories()
	for cat_idx in categories.size():
		var cat = categories[cat_idx]
		if cat_idx >= tab_container.get_tab_count():
			break
		var tab = tab_container.get_child(cat_idx)
		var scroll = ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.add_theme_constant_override("separation", 6)
		scroll.add_child(vbox)
		tab.add_child(scroll)

		var talents = talent_sys.get_category_talents(cat["id"])
		for talent in talents:
			_create_talent_entry(vbox, talent)

func _create_talent_entry(parent: VBoxContainer, talent: Dictionary):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	# Info column
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	var rank_text = "%d/%d" % [talent["current_rank"], talent["max_rank"]]
	name_label.text = "%s  [color=aaaaaa]%s[/color]" % [talent["name"], rank_text]
	name_label.bbcode_enabled = true
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = talent["description"]
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	info_vbox.add_child(desc_label)

	if talent["current_rank"] > 0:
		var bonus_label = Label.new()
		var bonus_val = talent["total_bonus"]
		if talent.get("bonus_type", "flat") == "percent":
			bonus_label.text = "当前加成: +%d%%" % int(bonus_val * 100)
		else:
			bonus_label.text = "当前加成: +%s" % str(bonus_val)
		bonus_label.modulate = Color(0.4, 0.9, 0.4)
		info_vbox.add_child(bonus_label)

	hbox.add_child(info_vbox)

	# Learn button
	var learn_btn = Button.new()
	learn_btn.text = "学习"
	learn_btn.custom_minimum_size = Vector2(60, 0)
	learn_btn.disabled = not talent["can_learn"]
	learn_btn.pressed.connect(_on_learn_pressed.bind(talent["id"]))
	hbox.add_child(learn_btn)

	parent.add_child(hbox)

	# Separator
	var sep = HSeparator.new()
	parent.add_child(sep)

func _on_learn_pressed(talent_id: String):
	if not talent_sys:
		return
	if talent_sys.learn_talent(talent_id):
		AudioManager.play_sfx("res://assets/audio/sfx_buy.ogg")
		_refresh()
	else:
		result_label.text = "无法学习!"
		result_label.modulate = Color.RED
		_clear_result()

func _on_respec_pressed():
	if not talent_sys:
		return
	if talent_sys.respec():
		AudioManager.play_sfx("res://assets/audio/sfx_sell.ogg")
		result_label.text = "天赋已重置!"
		result_label.modulate = Color.GREEN
		_refresh()
	else:
		result_label.text = "金币不足 (需要 500G)!"
		result_label.modulate = Color.RED
	_clear_result()

func _on_talent_learned(_talent_id: String, _new_rank: int):
	if is_open:
		_refresh()

func _on_points_changed(_new_total: int):
	if is_open:
		_refresh_points()

func _input(event):
	if event.is_action_pressed("talent_panel"):
		toggle()

func _clear_result():
	await get_tree().create_timer(2.0).timeout
	result_label.text = ""
	result_label.modulate = Color.WHITE
