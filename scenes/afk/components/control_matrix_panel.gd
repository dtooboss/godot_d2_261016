extends Control
class_name AFK_ControlMatrixPanel

signal btn_character_clicked()
signal btn_hook_clicked()
signal btn_pickup_clicked()
signal btn_enhance_clicked()
signal btn_shop_clicked()
signal btn_reset_points_clicked()
signal btn_skills_clicked()
signal btn_craft_clicked()
signal btn_smelt_clicked()
signal btn_exit_clicked()

@onready var btn_character: Button = %BtnCharacter
@onready var btn_hook: Button = %BtnHook
@onready var btn_pickup: Button = %BtnPickup
@onready var btn_enhance: Button = %BtnEnhance
@onready var btn_shop: Button = %BtnShop
@onready var btn_reset_points: Button = %BtnResetPoints
@onready var btn_skills: Button = %BtnSkills
@onready var btn_craft: Button = %BtnCraft
@onready var btn_smelt: Button = %BtnSmelt
@onready var btn_exit: Button = %BtnExit

func _ready() -> void:
	if btn_character: btn_character.pressed.connect(func(): btn_character_clicked.emit())
	if btn_hook: btn_hook.pressed.connect(func(): btn_hook_clicked.emit())
	if btn_pickup: btn_pickup.pressed.connect(func(): btn_pickup_clicked.emit())
	if btn_enhance: btn_enhance.pressed.connect(func(): btn_enhance_clicked.emit())
	if btn_shop: btn_shop.pressed.connect(func(): btn_shop_clicked.emit())
	if btn_reset_points: btn_reset_points.pressed.connect(func(): btn_reset_points_clicked.emit())
	if btn_skills: btn_skills.pressed.connect(func(): btn_skills_clicked.emit())
	if btn_craft: btn_craft.pressed.connect(func(): btn_craft_clicked.emit())
	if btn_smelt: btn_smelt.pressed.connect(func(): btn_smelt_clicked.emit())
	if btn_exit: btn_exit.pressed.connect(func(): btn_exit_clicked.emit())
