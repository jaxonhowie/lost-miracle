extends PanelContainer

var is_open: bool = false
var honor_sys: Node

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var honor_label: Label = $VBoxContainer/HonorLabel
@onready var rank_label: Label = $VBoxContainer/RankLabel
@onready var effect_label: Label = $VBoxContainer/EffectLabel
@onready var history_list: VBoxContainer = $VBoxContainer/HistoryScroll/HistoryList

func _ready():
	visible = false
	honor_sys = get_node_or_null("/root/HonorSystem")
	if honor_sys:
		honor_sys.honor_changed.connect(_on_honor_changed)

func _input(event):
	if event.is_action_pressed("quest_panel"):
		# Alt+H for honor panel - use a different check
		pass

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _on_honor_changed(_new_value: int, _change: int):
	if is_open:
		_refresh()

func _refresh():
	if not honor_sys:
		return
	honor_label.text = "荣誉值: %d" % honor_sys.honor
	rank_label.text = "称号: " + honor_sys.get_honor_rank()

	# Effects
	var effects: Array[String] = []
	if honor_sys.get_shop_discount() > 0:
		effects.append("商店折扣: %d%%" % int(honor_sys.get_shop_discount() * 100))
	if not honor_sys.can_trade():
		effects.append("NPC拒绝交易")
	if honor_sys.is_bounty_target():
		effects.append("已被悬赏标记")
	if effects.is_empty():
		effect_label.text = "当前无特殊效果"
	else:
		effect_label.text = "\n".join(effects)

	# Honor bar color
	if honor_sys.honor >= 500:
		honor_label.modulate = Color(0.2, 0.8, 1.0)
	elif honor_sys.honor >= 0:
		honor_label.modulate = Color(0.5, 1.0, 0.5)
	else:
		honor_label.modulate = Color(1.0, 0.4, 0.4)

	# History
	for child in history_list.get_children():
		child.queue_free()
	for entry in honor_sys.history:
		var label = Label.new()
		var sign = "+" if entry["value"] > 0 else ""
		label.text = "%s%d %s" % [sign, entry["value"], entry.get("reason", "")]
		if entry["value"] > 0:
			label.modulate = Color(0.5, 1.0, 0.5)
		else:
			label.modulate = Color(1.0, 0.5, 0.5)
		label.add_theme_font_size_override("font_size", 13)
		history_list.add_child(label)
