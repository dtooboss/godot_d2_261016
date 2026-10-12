extends Control

var _sent_commands: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print("   START TOWN EXIT QUIT COMMAND TEST              ")
	print("==================================================")
	NetworkClient.raw_sent.connect(func(cmd: String):
		_sent_commands.append(cmd)
	)
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n[Test 2] 验证 TownHubController 退出登录时发送 quit 并复位 GameState...")
	_sent_commands.clear()
	NetworkClient.is_connected = true
	GameState.selected_character = {"char_id": "char_town_test", "name": "主城测试角色", "level": 20}
	GameState.player_max_stage = 30
	GameState.is_in_team = true

	var town_scene = load("res://scenes/town/town_hub.tscn")
	var town = town_scene.instantiate()
	add_child(town)
	await get_tree().process_frame

	# 触发退出登录
	town._on_exit_to_login()
	await get_tree().create_timer(0.08).timeout

	assert(_sent_commands.has("quit"), "主城退出登录必须发送 quit 指令！当前已发: %s" % str(_sent_commands))
	assert(NetworkClient.is_connected == false, "主城退出登录后 NetworkClient 必须处于断开状态！")
	assert(GameState.selected_character.is_empty(), "主城退出登录后 selected_character 必须已被清空！")
	assert(GameState.player_max_stage == 0, "主城退出登录后 player_max_stage 必须复位为 0！")
	assert(GameState.is_in_team == false, "主城退出登录后 is_in_team 必须复位为 false！")
	print("✔ Test 2 通过: 主城退出登录 100% 发送 quit 并重置全部全局状态！")

	print("\n==================================================")
	print("  CONGRATULATIONS: TOWN EXIT QUIT TEST PASSED!    ")
	print("==================================================")
	Engine.get_main_loop().quit(0)
