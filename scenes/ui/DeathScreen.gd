extends CanvasLayer

var _countdown: float = 5.0
var _respawn_ready: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	$Panel.visible = false
	$Panel/VBox/RespawnBtn.disabled = true
	$Panel/VBox/RespawnBtn.pressed.connect(_on_respawn)
	$Panel/VBox/MenuBtn.pressed.connect(_on_menu)

func show_death():
	_countdown = 5.0
	_respawn_ready = false
	$Panel.visible = true
	$Panel/VBox/RespawnBtn.disabled = true
	$Panel/VBox/RespawnBtn.text = "立即复活 (5)"
	set_process(true)

func _process(delta):
	if not $Panel.visible:
		return
	if _respawn_ready:
		return
	_countdown -= delta
	var sec = int(ceil(_countdown))
	$Panel/VBox/RespawnBtn.text = "立即复活 (%d)" % maxi(0, sec)
	if _countdown <= 0:
		_respawn_ready = true
		$Panel/VBox/RespawnBtn.disabled = false
		$Panel/VBox/RespawnBtn.text = "立即复活"

func _on_respawn():
	$Panel.visible = false
	set_process(false)
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.respawn_player()
	else:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var p = players[0]
			p.hp = p.get_total_max_hp()
			p.is_dead = false
			p.get_node("CollisionShape2D").disabled = false
			p.get_node("HurtBox").monitoring = true

func _on_menu():
	$Panel.visible = false
	set_process(false)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
