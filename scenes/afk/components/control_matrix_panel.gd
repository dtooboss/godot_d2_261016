extends Control
class_name AFK_ControlMatrixPanel

signal btn_character_clicked()
signal btn_hook_clicked()
signal btn_pickup_clicked()
signal btn_enhance_clicked()
signal btn_shop_clicked()
signal btn_skills_clicked()
signal btn_craft_clicked()
signal btn_smelt_clicked()
signal btn_exit_clicked()

@onready var btn_character: Button = %BtnCharacter
@onready var btn_hook: Button = %BtnHook
@onready var btn_pickup: Button = %BtnPickup
@onready var btn_enhance: Button = %BtnEnhance
@onready var btn_shop: Button = %BtnShop
@onready var btn_skills: Button = %BtnSkills
@onready var btn_craft: Button = %BtnCraft
@onready var btn_smelt: Button = %BtnSmelt
@onready var btn_exit: Button = %BtnExit

func _ready() -> void:
	if btn_character == null: btn_character = get_node_or_null("Margin/VBox/Grid/BtnCharacter")
	if btn_hook == null: btn_hook = get_node_or_null("Margin/VBox/Grid/BtnHook")
	if btn_pickup == null: btn_pickup = get_node_or_null("Margin/VBox/Grid/BtnPickup")
	if btn_enhance == null: btn_enhance = get_node_or_null("Margin/VBox/Grid/BtnEnhance")
	if btn_shop == null: btn_shop = get_node_or_null("Margin/VBox/Grid/BtnShop")
	if btn_skills == null: btn_skills = get_node_or_null("Margin/VBox/Grid/BtnSkills")
	if btn_craft == null: btn_craft = get_node_or_null("Margin/VBox/Grid/BtnCraft")
	if btn_smelt == null: btn_smelt = get_node_or_null("Margin/VBox/Grid/BtnSmelt")
	if btn_exit == null: btn_exit = get_node_or_null("Margin/VBox/BottomHBox/BtnExit")

	if btn_character: btn_character.pressed.connect(_on_btn_character)
	if btn_hook: btn_hook.pressed.connect(_on_btn_hook)
	if btn_pickup: btn_pickup.pressed.connect(_on_btn_pickup)
	if btn_enhance: btn_enhance.pressed.connect(_on_btn_enhance)
	if btn_shop: btn_shop.pressed.connect(_on_btn_shop)
	if btn_skills: btn_skills.pressed.connect(_on_btn_skills)
	if btn_craft: btn_craft.pressed.connect(_on_btn_craft)
	if btn_smelt: btn_smelt.pressed.connect(_on_btn_smelt)
	if btn_exit: btn_exit.pressed.connect(_on_btn_exit)

func _on_btn_character() -> void: btn_character_clicked.emit()
func _on_btn_hook() -> void: btn_hook_clicked.emit()
func _on_btn_pickup() -> void: btn_pickup_clicked.emit()
func _on_btn_enhance() -> void: btn_enhance_clicked.emit()
func _on_btn_shop() -> void: btn_shop_clicked.emit()
func _on_btn_skills() -> void: btn_skills_clicked.emit()
func _on_btn_craft() -> void: btn_craft_clicked.emit()
func _on_btn_smelt() -> void: btn_smelt_clicked.emit()
func _on_btn_exit() -> void:
	print("[ControlMatrixPanel] _on_btn_exit CALLED!")
	btn_exit_clicked.emit()
