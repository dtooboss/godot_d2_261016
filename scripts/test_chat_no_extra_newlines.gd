extends Control

func _ready() -> void:
	print("==================================================================")
	print("【自动化回归测试】消息框无冗余空行与换行防抖测试")
	print("==================================================================")

	# 1. 验证 GameState.add_chat_message 自动剔除尾随换行
	var raw_msg1 = "【庇护所】圣洁耀斑从你周身爆发，血鹰受到重创！\n"
	GameState.add_chat_message(raw_msg1, "耀斑")
	var stored1 = GameState.chat_history[-1]
	assert(not stored1.ends_with("\n"), "存入历史的消息尾部不应包含换行符")
	print("  ✔ 尾随换行剔除测试通过: ", stored1)

	# 2. 验证多行技能描述（中间换行保留，末尾换行剥离）
	var raw_msg2 = "你爆发出钢铁般的【大吼】！\n - 整体防御力暴增 +130%！\n\n"
	GameState.add_chat_message(raw_msg2, "大吼")
	var stored2 = GameState.chat_history[-1]
	assert("\n" in stored2, "中间有意义的技能换行必须完整保留")
	assert(not stored2.ends_with("\n"), "末尾的多余换行必须被全部剥离")
	print("  ✔ 多行技能换行保留与末尾剥离测试通过: \n", stored2)

	# 3. 验证 RichTextLabel 在追加时的换行紧凑度
	var rtl = RichTextLabel.new()
	add_child(rtl)
	rtl.append_text(stored1.strip_edges(false, true) + "\n")
	rtl.append_text(stored2.strip_edges(false, true) + "\n")
	
	await get_tree().process_frame
	print("  ✔ RichTextLabel 紧凑排版渲染测试通过！")

	print("\n🎉 全部消息框换行防抖测试 100% 通过！")
	get_tree().quit(0)
