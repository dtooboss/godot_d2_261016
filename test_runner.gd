extends Node

func _ready() -> void:
	print("[TestRunner] Starting afk_main_hud test...")
	var scene = load("res://scenes/afk/afk_main_hud.tscn").instantiate()
	add_child(scene)
	
	# 等待渲染几帧后截图
	await get_tree().create_timer(1.0).timeout
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_afk_main_hud.png")
	print("[TestRunner] Saved test_afk_main_hud.png successfully")
	get_tree().quit(0)
