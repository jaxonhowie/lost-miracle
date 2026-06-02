extends Node2D

func _ready():
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if spawn_sys:
		spawn_sys.switch_floor(3)
	await get_tree().process_frame
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.apply_save_data()
	AudioManager.play_bgm("res://assets/audio/bgm_floor3.ogg")
