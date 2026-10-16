extends CanvasLayer

## 全局天神跑马灯广播组件 (NoticeMarquee)
## 负责全界面（主城安全区、野外挂机战斗区等）置顶大字跑马灯广播展示

@onready var container: Control = $Container
@onready var banner_bar: PanelContainer = $Container/BannerBar
@onready var badge_label: Label = %BadgeLabel
@onready var clip_viewport: Control = %ClipViewport
@onready var notice_text: RichTextLabel = %NoticeText

const NOTICE_FONT_SIZE: int = 28

var current_anim_tween: Tween = null
var current_scroll_tween: Tween = null
var is_showing: bool = false
var default_banner_y: float = 16.0
var hidden_banner_y: float = -90.0

func _ready() -> void:
	layer = 120
	# 初始状态隐藏并移出屏幕上方
	banner_bar.position.y = hidden_banner_y
	banner_bar.modulate.a = 0.0
	container.visible = false
	
	# 双向监听网络 JSON 广播
	if NetworkClient:
		NetworkClient.json_frame_received.connect(_on_json_frame_received)

func _on_json_frame_received(type: String, data: Variant) -> void:
	if type == "shout":
		if data is Dictionary:
			show_marquee(data)
		elif data is String:
			show_marquee({"text": data})

## 触发大字跑马灯展示
## [notice_data] 结构体: { "text": String, "duration": int/float, "color": String, "sender": String }
func show_marquee(notice_data: Dictionary) -> void:
	var raw_text = str(notice_data.get("text", "")).strip_edges()
	if raw_text.is_empty():
		return
		
	var duration = float(notice_data.get("duration", 10.0))
	if duration <= 0.0:
		duration = 10.0
	# 保障最小展示时长
	duration = clampf(duration, 3.0, 60.0)
	
	var base_color = str(notice_data.get("color", "#ffd700"))
	if base_color.is_empty():
		base_color = "#ffd700"
		
	var sender = str(notice_data.get("sender", "天神")).strip_edges()
	if sender.is_empty():
		sender = "天神"
	badge_label.text = "【%s敕令】" % sender
	badge_label.add_theme_color_override("font_color", Color(base_color))
	
	# 确保字号全局统一生效，防止 [b] 粗体退回 16px 默认值
	notice_text.add_theme_font_size_override("normal_font_size", NOTICE_FONT_SIZE)
	notice_text.add_theme_font_size_override("bold_font_size", NOTICE_FONT_SIZE)
	notice_text.add_theme_font_size_override("italics_font_size", NOTICE_FONT_SIZE)
	notice_text.add_theme_font_size_override("bold_italics_font_size", NOTICE_FONT_SIZE)

	# 解析色彩并构造富文本
	var bbcode = AnsiHelper.to_bbcode(raw_text)
	# 如果文本内未指定颜色，则用基准色包裹
	if not "[color" in bbcode.to_lower():
		bbcode = "[color=%s][b]%s[/b][/color]" % [base_color, bbcode]
	else:
		bbcode = "[b]%s[/b]" % bbcode
		
	notice_text.text = bbcode
	
	# 同步追加至全局聊天历史
	if GameState and GameState.has_method("add_chat_message"):
		var chat_msg = "[color=%s]【系统公告】%s：%s[/color]" % [base_color, sender, bbcode]
		GameState.add_chat_message(chat_msg, "【公告】%s" % raw_text)
	
	# 启动动效展示
	_play_marquee_animation(duration, bbcode)

func _play_marquee_animation(duration: float, bbcode: String) -> void:
	if current_anim_tween and current_anim_tween.is_valid():
		current_anim_tween.kill()
	if current_scroll_tween and current_scroll_tween.is_valid():
		current_scroll_tween.kill()
		
	container.visible = true
	is_showing = true
	
	# 等待两帧以便 RichTextLabel 与容器完成排版与尺寸收敛
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(self) or not is_showing:
		return
		
	var viewport_width = clip_viewport.size.x
	if viewport_width <= 0:
		viewport_width = 800.0
	var viewport_height = clip_viewport.size.y
	if viewport_height <= 0:
		viewport_height = 54.0
		
	# 计算文本真实渲染宽度与行高
	var font = notice_text.get_theme_font("bold_font")
	if not font:
		font = notice_text.get_theme_font("normal_font")
	var font_size = NOTICE_FONT_SIZE
	var plain_text = notice_text.get_parsed_text()
	var text_width = 0.0
	var font_height = 36.0
	if font:
		text_width = font.get_string_size(plain_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 30.0
		font_height = font.get_height(font_size)
	else:
		text_width = plain_text.length() * (font_size + 2.0) + 30.0
		
	var content_h = notice_text.get_content_height()
	if content_h > 0 and content_h < viewport_height:
		font_height = content_h

	# 计算上下绝对垂直居中 Y 坐标，+3px 补偿 RichTextLabel 内部字体基线与 Label 的视觉中线偏差
	var center_y = maxf(0.0, roundf((viewport_height - font_height) / 2.0) + 3.0)
	notice_text.position.y = center_y
	print("[DEBUG Marquee] viewport_w=", viewport_width, " viewport_h=", viewport_height, " font_h=", font_height, " content_h=", content_h, " text_w=", text_width, " center_y=", center_y, " actual_pos_y=", notice_text.position.y)

	# 1. 横幅顶部平滑滑入与淡入 (0.35s)
	current_anim_tween = create_tween()
	current_anim_tween.set_parallel(true)
	banner_bar.position.y = hidden_banner_y
	banner_bar.modulate.a = 0.0
	current_anim_tween.tween_property(banner_bar, "position:y", default_banner_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	current_anim_tween.tween_property(banner_bar, "modulate:a", 1.0, 0.35)
	
	# 2. 跑马灯滚动与居中展示
	current_scroll_tween = create_tween()
	var is_long = text_width > viewport_width
	if is_long:
		# 长文本：
		# 步骤 A：从左侧 position.x = 0 开始展示，先静止停顿 1.5 秒让玩家看清前半段
		notice_text.custom_minimum_size.x = text_width
		notice_text.size.x = text_width
		notice_text.position.x = 0.0
		notice_text.position.y = center_y
		current_scroll_tween.tween_interval(1.5)
		
		# 步骤 B：匀速向左滚动直到末尾完全露出
		var scroll_distance = text_width - viewport_width + 40.0
		var scroll_time = maxf(1.0, duration - 3.0)
		current_scroll_tween.tween_property(notice_text, "position:x", -scroll_distance, scroll_time).set_trans(Tween.TRANS_LINEAR)
		
		# 步骤 C：滚至末尾静止停留 1.5 秒
		current_scroll_tween.tween_interval(1.5)
	else:
		# 短文本：水平+上下完美双居中展示
		notice_text.custom_minimum_size.x = viewport_width
		notice_text.size.x = viewport_width
		notice_text.position.x = 0.0
		notice_text.position.y = center_y
		notice_text.text = "[center]%s[/center]" % bbcode
		current_scroll_tween.tween_interval(duration)
		
	await current_scroll_tween.finished
	if not is_instance_valid(self):
		return
		
	# 3. 滑出与淡出动画
	var exit_tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(banner_bar, "position:y", hidden_banner_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit_tween.tween_property(banner_bar, "modulate:a", 0.0, 0.35)
	await exit_tween.finished
	
	if is_instance_valid(self):
		is_showing = false
		container.visible = false
