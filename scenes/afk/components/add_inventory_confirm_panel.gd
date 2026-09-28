extends Control
class_name AFK_AddInventoryConfirmPanel

signal inventory_extended(new_page_count: int)

@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton
@onready var title_label: Label = %TitleLabel
@onready var current_level_label: Label = %CurrentLevelLabel
@onready var next_level_label: Label = %NextLevelLabel
@onready var material_container: VBoxContainer = %MaterialList

var current_pages: int = 1
var max_pages: int = 4
var need_gold: int = 50000
var player_gold: int = 0
var confirm_callback: Callable = Callable()

func _ready() -> void:
	hide()
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.pressed.connect(hide_panel)

func show_panel(cur_pages: int, p_gold: int, arg3 = null, arg4 = 4, arg5 = null) -> void:
	current_pages = cur_pages
	player_gold = p_gold
	
	if arg3 is Callable:
		confirm_callback = arg3
		need_gold = 50000
		max_pages = 4
	else:
		if arg3 is int:
			need_gold = arg3
		else:
			need_gold = 50000
		if arg4 is int:
			max_pages = arg4
		else:
			max_pages = 4
		if arg5 is Callable:
			confirm_callback = arg5
		else:
			confirm_callback = Callable()
		
	if current_level_label:
		current_level_label.text = "当前背包数量: %d" % current_pages
	if next_level_label:
		if current_pages >= max_pages:
			next_level_label.text = "已达最大数量: %d" % max_pages
		else:
			next_level_label.text = "扩展后数量: %d" % (current_pages + 1)
		
	_render_materials()
	_update_confirm_button_state()
	show()

func hide_panel() -> void:
	hide()

func _render_materials() -> void:
	for c in material_container.get_children():
		c.queue_free()
		
	if current_pages >= max_pages:
		var limit_label = Label.new()
		limit_label.add_theme_font_size_override("font_size", 11)
		limit_label.text = "已达到最大扩展页数 (%d页)" % max_pages
		limit_label.modulate = Color(0.7, 0.7, 0.7)
		material_container.add_child(limit_label)
		return
		
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	
	var icon = TextureRect.new()
	icon.texture = load("res://assets/images/coin.png")
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 11)
	
	var gold_str = _format_number(need_gold)
	var player_str = _format_number(player_gold)
	label.text = "x %s (%s)" % [gold_str, player_str]
	
	if player_gold < need_gold:
		label.modulate = Color(1.0, 0.25, 0.25)
	else:
		label.modulate = Color(0.3, 1.0, 0.3)
		
	hbox.add_child(icon)
	hbox.add_child(label)
	material_container.add_child(hbox)

func _update_confirm_button_state() -> void:
	if confirm_button:
		var is_full = current_pages >= max_pages
		var gold_lack = player_gold < need_gold
		confirm_button.disabled = is_full or gold_lack

func _on_confirm_pressed() -> void:
	if current_pages >= max_pages or (need_gold > 0 and player_gold < need_gold):
		return
	var new_count = current_pages + 1
	if confirm_callback.is_valid():
		var arg_cnt = confirm_callback.get_argument_count()
		if arg_cnt == 2:
			confirm_callback.call(need_gold, new_count)
		elif arg_cnt == 1:
			confirm_callback.call(new_count)
		else:
			confirm_callback.call()
	hide_panel()

func _format_number(n: int) -> String:
	var s = str(n)
	var out = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_panel()
