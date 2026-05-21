extends Control

var map_width: float = 5000.0
var map_height: float = 700.0
var minimap_size: Vector2 = Vector2(180, 100)
var margin: float = 10.0

var player: Node2D = null
var _monsters: Array = []
var _refresh_timer: float = 0.0
const REFRESH_INTERVAL: float = 0.5

func _ready():
	# Position in top-right corner
	position = Vector2(1280 - minimap_size.x - margin, margin)
	size = minimap_size
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")

func _process(delta):
	_refresh_timer -= delta
	if _refresh_timer <= 0:
		_refresh_timer = REFRESH_INTERVAL
		_monsters = get_tree().get_nodes_in_group("monsters")
	queue_redraw()

func _draw():
	# Background
	draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0.05, 0.04, 0.08, 0.85))
	draw_rect(Rect2(Vector2.ZERO, minimap_size), Color(0.3, 0.25, 0.2), false, 1.0)

	# Draw static elements (ground, walls)
	var scale_x = minimap_size.x / map_width
	var scale_y = minimap_size.y / map_height

	# Ground line
	var ground_y = 620.0 * scale_y
	draw_line(Vector2(0, ground_y), Vector2(minimap_size.x, ground_y), Color(0.25, 0.2, 0.18), 2.0)

	# Walls
	draw_line(Vector2(0, 0), Vector2(0, minimap_size.y), Color(0.25, 0.2, 0.18), 1.0)
	draw_line(Vector2(minimap_size.x, 0), Vector2(minimap_size.x, minimap_size.y), Color(0.25, 0.2, 0.18), 1.0)

	# Draw monsters as dots
	for m in _monsters:
		if not is_instance_valid(m) or m.current_state == m.State.DEAD:
			continue
		var mx = m.global_position.x * scale_x
		var my = m.global_position.y * scale_y
		var color = Color(0.8, 0.2, 0.2)
		if m.monster_id.begins_with("elite"):
			color = Color(1.0, 0.5, 0.0)
		elif m.monster_id.ends_with("_boss"):
			color = Color(1.0, 0.0, 0.0)
		draw_circle(Vector2(mx, my), 2.0, color)

	# Draw player
	if is_instance_valid(player):
		var px = player.global_position.x * scale_x
		var py = player.global_position.y * scale_y
		draw_circle(Vector2(px, py), 3.0, Color(0.2, 0.8, 0.2))
		draw_circle(Vector2(px, py), 4.0, Color(0.2, 0.8, 0.2), false, 1.0)

	# Border labels
	draw_string(ThemeDB.fallback_font, Vector2(2, 10), "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.5, 0.4))
