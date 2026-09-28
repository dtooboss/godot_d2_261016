extends Control
class_name SalvageUniqueConfirmDialog

signal salvage_confirmed(file_id: String)

@onready var title_label: Label = %TitleLabel
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name_label: Label = %ItemNameLabel
@onready var warn_desc_label: Label = %WarnDescLabel
@onready var btn_confirm: Button = %BtnConfirm
@onready var btn_cancel: Button = %BtnCancel
@onready var btn_close: Button = %BtnClose

var current_file_id: String = ""
var on_confirm_callback: Callable

func _ready() -> void:
	hide()
	if btn_confirm:
		btn_confirm.pressed.connect(_on_confirm_pressed)
	if btn_cancel:
		btn_cancel.pressed.connect(hide_dialog)
	if btn_close:
		btn_close.pressed.connect(hide_dialog)

func prompt_confirm(item_data: Dictionary, callback: Callable = Callable()) -> void:
	current_file_id = item_data.get("file_id", "")
	on_confirm_callback = callback
	
	var iname = item_data.get("name", "暗金装备")
	item_name_label.text = AnsiHelper.to_plain_text(iname)
	
	var itex = item_data.get("icon_texture", null)
	if itex:
		item_icon.texture = itex
	elif item_data.has("icon"):
		item_icon.texture = AnsiHelper.load_item_texture(item_data["icon"])
		
	show()

func _on_confirm_pressed() -> void:
	hide()
	if on_confirm_callback.is_valid():
		on_confirm_callback.call(current_file_id)
	salvage_confirmed.emit(current_file_id)

func hide_dialog() -> void:
	hide()
	current_file_id = ""

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide_dialog()
