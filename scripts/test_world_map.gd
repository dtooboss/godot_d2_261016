extends Control

@onready var world_map = get_node("WorldMap")

func _ready() -> void:
	await get_tree().process_frame
	world_map.change_world_panel.show()
	await get_tree().create_timer(0.6).timeout
	var img = get_viewport().get_texture().get_image()
	var shot = 'C:/Users/Administrator/.gemini/antigravity/brain/61532b8d-b072-439f-a11e-b9a4a44489f9/scratch/change_world_preview.png'
	img.save_png(shot)
	print('SAVED_CHANGE_WORLD: ' + shot)
	get_tree().quit(0)
