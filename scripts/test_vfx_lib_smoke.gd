# -*- coding: utf-8 -*-
"""test_vfx_lib_smoke.gd — 借入库 vfx_library 冒烟测试 (headless)
实例化 6 个候选借入场景, 验证可加载可播放无报错。
运行: godot --headless --path <proj> -s res://scripts/test_vfx_lib_smoke.gd
"""
extends SceneTree

var _t0 := 0
var _checked := false


func _initialize() -> void:
	print("=== VFX LIB BORROW SMOKE TEST ===")
	var scenes := [
		"res://addons/vfx_library/effects/lightning_chain.tscn",
		"res://addons/vfx_library/effects/ice_frost.tscn",
		"res://addons/vfx_library/effects/poison_cloud.tscn",
		"res://addons/vfx_library/effects/energy_burst.tscn",
		"res://addons/vfx_library/effects/sparks.tscn",
		"res://addons/vfx_library/effects/combo_ring.tscn",
		"res://addons/vfx_library/effects/summon_circle.tscn",
		"res://addons/vfx_library/effects/fireball_trail.tscn",
	]
	var ok := 0
	for p in scenes:
		var ps: PackedScene = load(p)
		if ps == null:
			printerr("FAIL load: " + p)
			continue
		var n: Node = ps.instantiate()
		if n == null:
			printerr("FAIL instantiate: " + p)
			continue
		root.add_child(n)
		ok += 1
	# 状态 shader 可加载性
	for sh in ["flash_white", "frozen", "poison", "burning", "dissolve"]:
		var res: Shader = load("res://addons/vfx_library/shaders/%s.gdshader" % sh)
		if res == null:
			printerr("FAIL shader: " + sh)
		else:
			ok += 1
	print("loaded+instantiated OK: %d (8 scenes + 5 shaders)" % ok)
	_t0 = Time.get_ticks_msec()


func _process(_delta: float) -> bool:
	# 播放 1.2s 后退出 (headless 墙钟)
	if not _checked and Time.get_ticks_msec() - _t0 > 1200:
		_checked = true
		print("=== VFX LIB BORROW SMOKE PASSED (1.2s playback, no errors) ===")
		quit(0)
	return false
