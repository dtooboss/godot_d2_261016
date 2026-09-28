extends Control

@onready var hud = $AFK_MainHUD

func _ready() -> void:
	await get_tree().process_frame
	
	# 1. 先截取折叠缩进状态 (超干净全景纯净画面)
	hud.set_sidebar_expanded(false)
	await get_tree().create_timer(0.3).timeout
	var img_collapsed = get_viewport().get_texture().get_image()
	var shot_collapsed = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/sidebar_collapsed_preview.png"
	img_collapsed.save_png(shot_collapsed)
	print("SAVED_COLLAPSED_SHOT: " + shot_collapsed)
	
	# 2. 再截取展开状态 (背包和矩阵正常展示)
	hud.set_sidebar_expanded(true)
	await get_tree().create_timer(0.3).timeout
	var img_expanded = get_viewport().get_texture().get_image()
	var shot_expanded = "C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/sidebar_expanded_preview.png"
	img_expanded.save_png(shot_expanded)
	print("SAVED_EXPANDED_SHOT: " + shot_expanded)
	
	get_tree().quit(0)
