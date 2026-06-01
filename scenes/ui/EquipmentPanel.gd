extends PanelContainer

var is_open: bool = false
var equip_sys: Node

@onready var slot_btns: Dictionary = {
	"weapon": $VBoxContainer/SlotContainer/WeaponSlot/Btn,
	"armor": $VBoxContainer/SlotContainer/ArmorSlot/Btn,
	"boots": $VBoxContainer/SlotContainer/BootsSlot/Btn,
	"ring": $VBoxContainer/SlotContainer/RingSlot/Btn,
	"helmet": $VBoxContainer/SlotContainer/HelmetSlot/Btn,
	"accessory": $VBoxContainer/SlotContainer/AccessorySlot/Btn,
}
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var detail_label: Label = $VBoxContainer/DetailLabel

func _ready():
	visible = false
	equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		equip_sys.equipment_changed.connect(_refresh)

	for slot_name in slot_btns:
		slot_btns[slot_name].pressed.connect(_on_slot_pressed.bind(slot_name))

func _input(event):
	if event.is_action_pressed("equipment"):
		# Don't open equipment if near merchant (shop takes priority)
		var shop = get_node_or_null("../ShopPanel")
		if shop and (shop.near_merchant or shop.is_open):
			return
		toggle()

func toggle():
	is_open = !is_open
	visible = is_open
	if is_open:
		_refresh()

func _refresh():
	if not equip_sys:
		return

	for slot_name in slot_btns:
		var btn = slot_btns[slot_name]
		var equip_data = equip_sys.get_equipped(slot_name)
		if equip_data:
			var item_data = ItemDatabase.get_item(equip_data["item_id"])
			btn.text = item_data.get("name", "?")
			var quality = item_data.get("quality", "")
			if quality != "":
				btn.modulate = ItemDatabase.get_quality_color(quality)
			var enhance = equip_data.get("enhance_level", 0)
			if enhance > 0:
				btn.text += " +" + str(enhance)
		else:
			btn.text = "空"
			btn.modulate = Color.WHITE

	_update_stats_display()

func _update_stats_display():
	if not equip_sys:
		return

	var players = get_tree().get_nodes_in_group("player")
	var lines = []
	if not players.is_empty():
		var p = players[0]
		lines.append("STR:%d AGI:%d INT:%d" % [p.STR, p.AGI, p.INT])
		lines.append("攻击:%d 防御:%d HP:%d" % [p.get_total_attack(), p.get_total_defense(), p.get_total_max_hp()])
		lines.append("暴击率:%d%% 暴伤:%d%%" % [int(p.get_total_crit_rate() * 100), int(p.get_total_crit_damage() * 100)])

	var stats = equip_sys.get_total_stats()
	var equip_parts = []
	if stats["attack"] > 0:
		equip_parts.append("攻+" + str(stats["attack"]))
	if stats["defense"] > 0:
		equip_parts.append("防+" + str(stats["defense"]))
	if stats["hp"] > 0:
		equip_parts.append("HP+" + str(stats["hp"]))
	if not equip_parts.is_empty():
		lines.append("装备: " + " ".join(equip_parts))

	if lines.is_empty():
		stats_label.text = "无数据"
	else:
		stats_label.text = "\n".join(lines)

func _on_slot_pressed(slot_name: String):
	if not equip_sys:
		return

	var equip_data = equip_sys.get_equipped(slot_name)
	if equip_data:
		var item_data = ItemDatabase.get_item(equip_data["item_id"])
		var text = item_data.get("name", "?")
		var enhance = equip_data.get("enhance_level", 0)
		if enhance > 0:
			text += " +" + str(enhance)
		text += "\n品质: " + item_data.get("quality", "普通")
		if item_data.get("attack", 0) > 0:
			text += "\n攻击: +" + str(item_data["attack"])
		if item_data.get("defense", 0) > 0:
			text += "\n防御: +" + str(item_data["defense"])
		if item_data.get("hp", 0) > 0:
			text += "\n生命: +" + str(item_data["hp"])
		text += "\n\n点击卸下"
		detail_label.text = text

		# Unequip on second click
		equip_sys.unequip(slot_name)
	else:
		detail_label.text = slot_name + ": 空槽位"
