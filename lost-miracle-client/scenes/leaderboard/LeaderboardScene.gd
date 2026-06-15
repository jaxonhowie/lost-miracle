extends Control

func _ready() -> void:
	$Background.color = Color(0.06, 0.04, 0.08)
	$VBox/Title.add_theme_font_size_override("font_size", 32)
	$VBox/BackBtn.pressed.connect(_on_back)
	await _load_leaderboard()

func _load_leaderboard() -> void:
	var list: VBoxContainer = $VBox/List
	for child in list.get_children():
		child.queue_free()

	var char_id := NetworkManager.get_character_id()
	var result = await NetworkManager.get_leaderboard(char_id)
	if not result.get("ok", false):
		var err := Label.new()
		err.text = "加载失败: %s" % result.get("message", "")
		list.add_child(err)
		return

	var data: Dictionary = result.get("data", {})
	var items: Array = data.get("items", [])
	if items.is_empty():
		var empty := Label.new()
		empty.text = "暂无排行数据"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
		return

	var my_rank = data.get("myRank", null)
	var my_score = data.get("myScore", null)
	if my_rank != null:
		var mine := Label.new()
		mine.text = "我的排名: #%s  战力: %s" % [my_rank, my_score]
		mine.modulate = Color(0.8, 0.9, 1.0)
		list.add_child(mine)

	for entry in items:
		var row := Label.new()
		row.text = "#%d  %s  Lv.%d  战力 %d" % [
			entry.get("rank", 0),
			entry.get("name", "?"),
			entry.get("level", 1),
			entry.get("score", 0),
		]
		list.add_child(row)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/Main.tscn")
