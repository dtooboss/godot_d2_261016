# -*- coding: utf-8 -*-
"""test_fx_pool_smoke.gd — P1 池化改造冒烟测试 (headless)
extends SceneTree, 直接实例化 combat_fx_manager, 高频发射后验证池回收。
运行: godot --headless --path <proj> -s res://scripts/test_fx_pool_smoke.gd
"""
extends SceneTree

var _frames := 0
var _fx = null
var _done := false


func _initialize() -> void:
	print("=== FX POOL SMOKE TEST ===")
	var packed = load("res://scenes/afk/components/combat_fx_manager.gd")
	_fx = packed.new()
	root.add_child(_fx)
	# 高频发射 40 发 (超池上限, 验证复用+回收+超限兜底)
	for i in range(40):
		_fx.play_combat_fx(
			Vector2(100 + i * 5, 200), Vector2(600, 400),
			"fire_ball" if i % 2 == 0 else "strafe",
			"fire", Callable(), false, true, 1 if i % 3 else 3
		)
	# 命中冲击 + 地面残留
	_fx._spawn_hit_impact(Vector2(600, 400), Color(1, 0.4, 0.1), true)
	_fx._spawn_ground_fx("fire", Vector2(600, 400), 90.0, 5.0, Color(1, 0.45, 0.1))
	print("spawned: live=%d pool_keys=%s" % [_fx._live_count, str(_fx._proj_pool.keys())])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10 or _frames == 60:
		var pool_total := 0
		for k in _fx._proj_pool:
			pool_total += _fx._proj_pool[k].size()
		print("t=10f: live=%d pooled=%d impacts_cached=%d ground_pool=%d active_ground=%d" % [
			_fx._live_count, pool_total, _fx._impact_pool.size(),
			_fx._ground_pool.size(), _fx._active_ground])
	if _frames == 130 or _frames == 145:  # ~2s: 弹道全部到达, ground(2.5s) 仍在场
		var pool_total := 0
		for k in _fx._proj_pool:
			pool_total += _fx._proj_pool[k].size()
		var live_left := 0
		for n in _fx._live_proj_list:
			if is_instance_valid(n["proj"]) and n["proj"].visible:
				live_left += 1
		print("t=130f: live_counter=%d live_visible=%d pooled=%d" % [_fx._live_count, live_left, pool_total])
		if pool_total == 0:
			printerr("FAIL: 弹道未回收入池")
			quit(1)
			return true
	if Time.get_ticks_msec() >= 7000:  # ~3.3s: 地面残留结束
		if _fx._active_ground != 0:
			printerr("FAIL: 地面残留未回收 active=%d" % _fx._active_ground)
			quit(1)
			return true
		print("=== ALL FX POOL SMOKE CHECKS PASSED ===")
		quit(0)
		_done = true
	return false
