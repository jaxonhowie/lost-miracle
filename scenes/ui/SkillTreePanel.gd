extends CanvasLayer

var is_open: bool = false
var _player: Node2D = null

func _ready():
	layer = 93
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Panel.visible = false
	$Panel/VBox/CloseBtn.pressed.connect(toggle)
	# Find player
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")
	_refresh_skills()

func toggle():
	is_open = !is_open
	$Panel.visible = is_open
	if is_open:
		_refresh_skills()
		get_tree().paused = true
	else:
		get_tree().paused = false

func _refresh_skills():
	if not _player:
		return
	var skill_tree = get_node_or_null("/root/SkillTreeSystem")
	if not skill_tree:
		return

	var class_id = _player.class_id
	var level_sys = get_node_or_null("/root/LevelSystem")
	var level = level_sys.level if level_sys else 1

	# Update points label
	$Panel/VBox/PointsLabel.text = "技能点: %d" % skill_tree.skill_points

	# Clear existing skill rows
	var container = $Panel/VBox/SkillList
	for child in container.get_children():
		child.queue_free()

	# Get class skills
	var skills = skill_tree.get_class_skills(class_id)
	for skill_id in skills:
		var data = skill_tree.get_skill_data(skill_id)
		var row = HBoxContainer.new()

		var name_label = Label.new()
		name_label.text = data.get("name", skill_id)
		name_label.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_label)

		var cost_label = Label.new()
		cost_label.text = "MP: %d" % data.get("mp_cost", 0)
		cost_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(cost_label)

		var unlock_btn = Button.new()
		if skill_tree.is_unlocked(skill_id):
			unlock_btn.text = "已解锁"
			unlock_btn.disabled = true
		elif data.get("unlock_level", 99) > level:
			unlock_btn.text = "Lv.%d 解锁" % data.get("unlock_level", 99)
			unlock_btn.disabled = true
		elif skill_tree.skill_points <= 0:
			unlock_btn.text = "无技能点"
			unlock_btn.disabled = true
		else:
			unlock_btn.text = "解锁"
			unlock_btn.pressed.connect(_on_unlock_pressed.bind(skill_id))
		row.add_child(unlock_btn)

		container.add_child(row)

func _on_unlock_pressed(skill_id: String):
	var skill_tree = get_node_or_null("/root/SkillTreeSystem")
	if not skill_tree or not _player:
		return
	var level_sys = get_node_or_null("/root/LevelSystem")
	var level = level_sys.level if level_sys else 1
	if skill_tree.unlock_skill(skill_id, _player.class_id, level):
		_refresh_skills()

func _input(event):
	if event.is_action_pressed("skill_tree_panel"):
		toggle()
	elif event.is_action_pressed("ui_cancel") and is_open:
		toggle()
		get_viewport().set_input_as_handled()
