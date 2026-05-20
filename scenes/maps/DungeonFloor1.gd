extends Node2D

func _ready():
	await get_tree().process_frame
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.apply_save_data()
