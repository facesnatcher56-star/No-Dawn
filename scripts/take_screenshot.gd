extends Node

func _ready():
	await get_tree().create_timer(1.0).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("/home/deck/tanks/screenshot.png")
	print("Saved screenshot to /home/deck/tanks/screenshot.png, size: ", img.get_size())
	get_tree().quit(0)
