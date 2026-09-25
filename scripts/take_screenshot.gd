extends Node

func _ready():
	await get_tree().create_timer(1.0).timeout
	var img = get_viewport().get_texture().get_image()
	if img:
		img.save_png("user://screenshot.png")
	get_tree().quit(0)
