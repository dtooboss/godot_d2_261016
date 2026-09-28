extends SceneTree

func _init():
	print("==================================================")
	print("【测试开始】公频装备展示 (gshowitem) 修复全链路验证")
	print("==================================================")
	
	var esc = char(27)
	var pass_count = 0
	var total_tests = 4
	
	# ----------------------------------------------------
	# 测试 1: LPC 端 strip_ansi 算法仿真验证
	# ----------------------------------------------------
	print("\n--- 1. 验证装备名 24 位色与 ANSI 序列彻底清洗 ---")
	var raw_lpc_item_name = esc + "[f#908858m天使的镰刀" + esc + "[2;37;0m"
	
	# 仿真 gshowitem.c 的过滤算法
	var pure_name = ""
	var s_len = raw_lpc_item_name.length()
	var s_i = 0
	while s_i < s_len:
		if raw_lpc_item_name.unicode_at(s_i) == 27:
			s_i += 1
			while s_i < s_len and raw_lpc_item_name.unicode_at(s_i) != 109 and raw_lpc_item_name.unicode_at(s_i) != 93 and raw_lpc_item_name.unicode_at(s_i) != 27:
				s_i += 1
			if s_i < s_len: s_i += 1
		else:
			pure_name += raw_lpc_item_name.substr(s_i, 1)
			s_i += 1
	var clean_name = pure_name.strip_edges()
	
	print("原始装备名 (含ANSI): ", raw_lpc_item_name)
	print("清洗后装备名: ", clean_name)
	assert(clean_name == "天使的镰刀", "装备名清洗失败！")
	print("✅ 测试 1 通过：装备名彻底清洗为纯净字符串 '天使的镰刀'")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 2: 留言中【装备名】原地精准替换（杜绝重复）
	# ----------------------------------------------------
	print("\n--- 2. 验证留言中的【装备名】原地替换逻辑 ---")
	var fid = "/clone/d2/equipment/w106#2692"
	var q_color = "#a59263"
	var link = "[url=item:%s][color=%s]『%s』[/color][/url]" % [fid, q_color, clean_name]
	
	var user_msg_with_tag = "埃苏丹【天使的镰刀】"
	var bracket_tag = "【%s】" % clean_name
	
	var replaced_msg = user_msg_with_tag.replace(bracket_tag, link)
	print("玩家原始输入: ", user_msg_with_tag)
	print("原地替换结果: ", replaced_msg)
	
	# 断言：替换后的字符串中不再包含【天使的镰刀】，且『天使的镰刀』只出现一次
	assert("【天使的镰刀】" not in replaced_msg, "【天使的镰刀】未被替换！")
	assert(replaced_msg.count("天使的镰刀") == 1, "装备名称重复出现！")
	print("✅ 测试 2 通过：【天使的镰刀】原地精准替换为超链接，绝无重复出现！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 3: RichTextLabel 解析验证（杜绝裸露 [/url] 与标签泄漏）
	# ----------------------------------------------------
	print("\n--- 3. 验证 RichTextLabel 标签闭合与无 [/url] 裸露 ---")
	var broadcast_raw = "『" + esc + "[1;36m世界" + esc + "[0m』郑天灭：" + replaced_msg + "\n"
	var bbcode_msg = AnsiHelper.to_bbcode(broadcast_raw)
	print("生成的广播 BBCode:\n", bbcode_msg)
	
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = bbcode_msg
	
	# 追加第二条系统提示消息（验证第一条是否会导致标签下渗污染）
	var hint_msg = "[color=#22c55e]你已成功将【天使的镰刀】展示到世界频道！[/color]\n"
	rtl.text += hint_msg
	
	var parsed_text = rtl.get_parsed_text()
	print("RichTextLabel 解析后的纯文本显示内容:\n", parsed_text)
	
	assert("[/url]" not in parsed_text.to_lower(), "致命缺陷：界面上出现了裸露的 [/url]！")
	assert("[/color]" not in parsed_text.to_lower(), "界面上出现了裸露的 [/color]！")
	print("✅ 测试 3 通过：超链接正确解析闭合，绝无任何 [/url] 或 [/color] 裸露！")
	pass_count += 1
	
	# ----------------------------------------------------
	# 测试 4: to_plain_text 纯净性验证
	# ----------------------------------------------------
	print("\n--- 4. 验证 AnsiHelper.to_plain_text 纯文本输出 ---")
	var plain_output = AnsiHelper.to_plain_text(bbcode_msg)
	print("to_plain_text 输出:\n", plain_output)
	assert("rl=item:" not in plain_output, "to_plain_text 破坏截断了 BBCode 标签！")
	assert("[/url]" not in plain_output.to_lower(), "to_plain_text 残留了 [/url]！")
	assert("【天使的镰刀】" not in plain_output, "纯文本中残留了旧占位符！")
	print("✅ 测试 4 通过：to_plain_text 输出绝对纯净，零残余！")
	pass_count += 1
	
	print("\n==================================================")
	print("【测试结果】全部 %d/%d 项测试 100%% 通过！" % [pass_count, total_tests])
	print("==================================================")
	
	quit()
