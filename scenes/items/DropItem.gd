extends Area2D

var item_id: String = ""
var count: int = 1
var is_pickupable: bool = false

@onready var sprite: ColorRect = $SpritePlaceholder
@onready var label: Label = $Label

func setup(p_item_id: String, p_count: int):
	item_id = p_item_id
	count = p_count

func _ready():
	var item_data = ItemDatabase.get_item(item_id)
	var item_name = item_data.get("name", item_id)
	label.text = item_name if count == 1 else "%s x%d" % [item_name, count]

	var quality = item_data.get("quality", "")
	if quality != "":
		sprite.color = ItemDatabase.get_quality_color(quality)
	elif item_data.get("type", "") == "material":
		sprite.color = Color(0.8, 0.7, 0.3, 1)

func pop_toward(target_pos: Vector2):
	is_pickupable = false
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", target_pos, 0.4)
	tween.tween_property(self, "global_position", Vector2(target_pos.x, target_pos.y + 60), 0.3)
	tween.tween_callback(func(): is_pickupable = true)

func pickup(player):
	if not is_pickupable:
		return
	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.add_item(item_id, count)
	queue_free()

func _on_body_entered(body):
	if body.is_in_group("player") and is_pickupable:
		pickup(body)
