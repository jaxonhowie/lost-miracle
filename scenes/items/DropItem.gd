extends Area2D

var item_id: String = ""
var count: int = 1
var is_pickupable: bool = false
var _magnet_target: Node2D = null
var _magnet_speed: float = 0.0

const MAGNET_RANGE: float = 120.0
const MAGNET_ACCEL: float = 600.0
const MAGNET_MAX_SPEED: float = 400.0

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

func _process(delta):
	if not is_pickupable:
		return

	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return
	var player = players[0]
	var dist = global_position.distance_to(player.global_position)

	if dist < MAGNET_RANGE:
		# Fly toward player with acceleration
		_magnet_speed = minf(_magnet_speed + MAGNET_ACCEL * delta, MAGNET_MAX_SPEED)
		var dir = (player.global_position - global_position).normalized()
		global_position += dir * _magnet_speed * delta

		# Pick up when very close
		if dist < 15:
			pickup(player)

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
	is_pickupable = false
	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.add_item(item_id, count)
	# Brief scale-up effect before disappearing
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)

func _on_body_entered(body):
	if body.is_in_group("player") and is_pickupable:
		pickup(body)
