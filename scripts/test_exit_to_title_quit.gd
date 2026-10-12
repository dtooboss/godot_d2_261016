extends Control

var _sent_commands: Array[String] = []

func _ready() -> void:
	print("==================================================")
	print("   START EXIT TO TITLE QUIT COMMAND TEST          ")
	print("==================================================")
	NetworkClient.raw_sent.connect(func(cmd: String):
		_sent_commands.append(cmd)
	)
	call_deferred("_run_tests")

func _run_tests() -> void:
	# ----------------------------------------------------
	# Test 1: 验证 AFK_MainHUD._on_exit_to_title 发送 quit
	# ----------------------------------------------------
	print("\n[Test 1] 验证 AFK_MainHUD 退出到标题时发送 quit 并复位 GameState...")
	_sent_commands.clear()
	NetworkClient.is_connected = true
	GameState.selected_character = {"char_id": "char_test", "name": "测试角色", "level": 50}
	GameState.player_max_stage = 25
	GameState.is_in_team = true
	GameState.chat_history.append("测试传音消息")

	var hud_scene = load("res://scenes/afk/afk_main_hud.tscn")
	var hud = hud_scene.instantiate()
	add_child(hud)
	await get_tree().process_frame

	# 触发退出到标题
	hud._on_exit_to_title()
	await get_tree().create_timer(0.08).timeout

	assert(_sent_commands.has("quit"), "点击退出到标题必须发送 quit 指令！当前已发: %s" % str(_sent_commands))
	assert(NetworkClient.is_connected == false, "退出到标题后 NetworkClient 必须处于断开状态！")
	assert(GameState.selected_character.is_empty(), "GameState.selected_character 必须已被清空！")
	assert(GameState.player_max_stage == 0, "GameState.player_max_stage 必须已复位为 0！")
	assert(GameState.is_in_team == false, "GameState.is_in_team 必须已复位为 false！")
	assert(GameState.chat_history.is_empty(), "GameState.chat_history 必须已被清空！")
	print("✔ Test 1 通过: 挂机主界面退出到标题 100% 发送 quit 并重置全部全局状态！")

	print("\n==================================================")
	print("  CONGRATULATIONS: EXIT QUIT TEST PASSED!         ")
	print("==================================================")
	Engine.get_main_loop().quit(0)
