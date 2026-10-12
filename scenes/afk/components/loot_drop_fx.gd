extends Control
class_name AFK_LootDropFx

## 战利品掉落晃动与流光小箭头入包动效组件
## 遵循暗黑2沉浸视觉规范：
## 1. 掉落原位生成物品 Icon + 名称，上下浮动呼吸晃动 1.0 秒
## 2. 1.0 秒后 Icon 原位淡出，化作一道品质发光流线与锐利小箭头
## 3. 沿贝塞尔弧线加速直射背包，背包微震吸收并彻底销毁释放

# 内部子组件：自定义渲染的高亮小箭头与流光细线
class ArrowVisual extends Node2D:
	var color: Color = Color.GOLD
	var length: float = 26.0
	var head_size: float = 7.5

	func _draw() -> void:
		var start_p = Vector2(-length, 0.0)
		var end_p = Vector2(0.0, 0.0)
		
		# 1. 柔和外发光晕 (线宽 5.0, 半透明)
		var halo_color = Color(color.r, color.g, color.b, 0.3)
		draw_line(start_p, end_p, halo_color, 5.0, true)
		
		# 2. 品质核心流光细线 (线宽 2.4)
		var core_color = Color(color.r, color.g, color.b, 0.95)
		draw_line(start_p, end_p, core_color, 2.4, true)
		
		# 3. 头部锐利发光小箭头 (正对 (0,0))
		var p1 = end_p
		var p2 = end_p + Vector2(-head_size, -head_size * 0.55)
		var p3 = end_p + Vector2(-head_size * 0.5, 0.0)
		var p4 = end_p + Vector2(-head_size, head_size * 0.55)
		draw_colored_polygon(PackedVector2Array([p1, p2, p3, p4]), Color(1.0, 1.0, 1.0, 1.0)) # 箭头尖端为纯白高亮
		draw_polyline(PackedVector2Array([p2, p1, p4]), core_color, 1.5, true)

# 内部子组件：到达背包时的微型吸收冲击波
class BagBurstVisual extends Node2D:
	var color: Color = Color.GOLD
	var radius: float = 4.0
	var alpha: float = 1.0

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0, TAU, 24, Color(color.r, color.g, color.b, alpha * 0.8), 2.0, true)
		draw_circle(Vector2.ZERO, radius * 0.3, Color(1.0, 1.0, 1.0, alpha * 0.9))

var _start_pos: Vector2
var _target_pos: Vector2
var _control_pos: Vector2
var _quality_color: Color = Color.WHITE
var _on_reach_callback: Callable

var icon_container: Control = null
var arrow_visual: ArrowVisual = null
var _fly_progress: float = 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 28

## 启动掉落光效
## @param item_data 物品数据字典 (包含 icon, raw_name, quality 等)
## @param start_pos 掉落原点 (击杀怪物屏幕坐标)
## @param target_pos 背包落点目标坐标
## @param col_hex 品质颜色代码
## @param on_reach 到达背包时的触发回调
func setup(item_data: Dictionary, start_pos: Vector2, target_pos: Vector2, col_hex: String, on_reach: Callable = Callable()) -> void:
	_start_pos = start_pos
	_target_pos = target_pos
	_quality_color = Color.from_string(col_hex, Color.WHITE)
	_on_reach_callback = on_reach

	# 计算抛物线控制点：中点处向上拉高 45 像素，形成优美的弧线飞行
	var mid_x = (_start_pos.x + _target_pos.x) * 0.5
	var min_y = min(_start_pos.y, _target_pos.y)
	_control_pos = Vector2(mid_x, min_y - 45.0)

	_build_icon_visual(item_data)
	_start_hover_phase()

## 构建原位呼吸晃动的物品 Icon 与名称标签
func _build_icon_visual(item_data: Dictionary) -> void:
	icon_container = Control.new()
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_container.position = _start_pos
	add_child(icon_container)

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	vbox.custom_minimum_size = Vector2(76, 52)
	# 居中对齐于原点 (x: -38, y: -26)
	vbox.position = Vector2(-38, -26)
	icon_container.add_child(vbox)

	# 物品贴图居中容器 (纯净无外框与底色，原汁原味暗黑地表掉落)
	var center_c = CenterContainer.new()
	center_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(center_c)

	var icon_rect = TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.custom_minimum_size = Vector2(38, 38)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	center_c.add_child(icon_rect)

	# 加载贴图 (带有兜底保护)
	var raw_icon_path = str(item_data.get("icon", ""))
	var tex = AnsiHelper.load_item_texture(raw_icon_path) if not raw_icon_path.is_empty() else null
	if not tex:
		var fallback_path = "res://assets/items/misc/herb/herb.lowend.png"
		if ResourceLoader.exists(fallback_path):
			tex = load(fallback_path)
	if tex:
		icon_rect.texture = tex

	# 物品名称标签
	var iname = str(item_data.get("raw_name", item_data.get("name", "战利品")))
	var clean_name = AnsiHelper.to_plain_text(iname)
	var name_label = Label.new()
	name_label.text = clean_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", _quality_color)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(name_label)

## 第一阶段：原地上下浮动晃动与轻柔呼吸 2.2 秒
func _start_hover_phase() -> void:
	if not is_instance_valid(icon_container): return

	# 1. 前 0.12s 从击杀点向上微弹落位
	var bounce_tw = create_tween().bind_node(self)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y - 10.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# 2. 随后的 2.08s 原地正弦波上下浮动晃动 (两轮从容浮动，总耗时 2.2s)
	# 第一轮浮动 (1.04s)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y - 4.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y + 4.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 第二轮浮动 (1.04s)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y - 4.0, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y + 4.0, 0.52).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bounce_tw.tween_property(icon_container, "position:y", _start_pos.y, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 3. 伴随 2.2s 轻柔呼吸缩放 (两轮呼吸)
	var scale_tw = create_tween().bind_node(self)
	scale_tw.tween_property(icon_container, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scale_tw.tween_property(icon_container, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scale_tw.tween_property(icon_container, "scale", Vector2(1.06, 1.06), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	scale_tw.tween_property(icon_container, "scale", Vector2(1.0, 1.0), 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# 4. 2.2s 倒计时结束，转入流光小箭头飞向背包阶段
	bounce_tw.tween_callback(_start_fly_phase)

## 第二阶段：Icon 淡出消散，化作流光小箭头直射背包
func _start_fly_phase() -> void:
	if is_instance_valid(icon_container):
		var fade_tw = create_tween().bind_node(self)
		fade_tw.tween_property(icon_container, "modulate:a", 0.0, 0.1)
		fade_tw.tween_callback(func():
			if is_instance_valid(icon_container):
				icon_container.queue_free()
		)

	# 创建渲染小箭头节点
	arrow_visual = ArrowVisual.new()
	arrow_visual.color = _quality_color
	add_child(arrow_visual)
	_update_arrow_transform(0.0)

	# 贝塞尔弧线加速飞行 (0.42s，TRANS_QUAD 加速)
	var fly_tw = create_tween().bind_node(self)
	fly_tw.tween_method(_update_arrow_transform, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fly_tw.tween_callback(_on_fly_completed)

## 二次贝塞尔曲线插值与瞬时速度切线角度计算
func _update_arrow_transform(t: float) -> void:
	if not is_instance_valid(arrow_visual): return
	var inv = 1.0 - t
	var pos = inv * inv * _start_pos + 2.0 * inv * t * _control_pos + t * t * _target_pos
	arrow_visual.global_position = pos

	var derivative = 2.0 * inv * (_control_pos - _start_pos) + 2.0 * t * (_target_pos - _control_pos)
	if derivative.length_squared() > 0.001:
		arrow_visual.rotation = derivative.angle()

## 第三阶段：命中背包入口，微震吸收并彻底销毁
func _on_fly_completed() -> void:
	if _on_reach_callback.is_valid():
		_on_reach_callback.call()

	# 入包微爆波纹
	var burst = BagBurstVisual.new()
	burst.color = _quality_color
	burst.global_position = _target_pos
	add_child(burst)

	var burst_tw = create_tween().bind_node(burst)
	burst_tw.tween_property(burst, "radius", 18.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst_tw.parallel().tween_property(burst, "alpha", 0.0, 0.16)
	burst_tw.tween_callback(burst.queue_free)

	if is_instance_valid(arrow_visual):
		arrow_visual.queue_free()

	# 0.2 秒后自身完整销毁
	get_tree().create_timer(0.2).timeout.connect(queue_free)
