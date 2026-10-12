extends Node2D

func _ready() -> void:
	var dialog_scene = preload("res://scenes/common/team_invite_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	add_child(dialog)
	dialog.show_trade_invite("赵狂 想要与你进行以物换物交易。", "gtrade accept xdao_sor", "gtrade decline xdao_sor")
	
	# 等待一帧后截图
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("C:/Users/Administrator/.gemini/antigravity/brain/b5309461-d440-459a-8a46-12eef9df4706/test_trade_invite_dialog.png")
	print("Trade dialog screenshot saved successfully!")
	get_tree().quit()
