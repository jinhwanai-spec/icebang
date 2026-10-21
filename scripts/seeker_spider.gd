extends Seeker
## 술래: 거미 여왕
## - 거미줄 발사: 빠른 거미줄(속도 28). 맞으면 1.5초 묶임 (못 움직이고 능력도 못 씀, 얼음만 가능) (쿨 25초)
## - 알 낳기: 30초마다 그 자리에 알을 낳음 (최대 3개). 30초 뒤 새끼 거미가 나옴 (최대 4마리)
##   새끼도 거미줄을 쏘고, 새끼에게 묶이면 여왕이 그 위치를 알게 됨. 알·새끼는 E로 제거 (대가 없음)

const ProjectileScript := preload("res://scripts/projectile.gd")
const EggScript := preload("res://scripts/spider_egg.gd")

var _web_cd := 0.0
var _egg_cd := 0.0
var eggs: Array = []
var babies: Array = []


func _ready() -> void:
	super._ready()
	_web_cd = GameConfig.num("spider", "web_cooldown", 25.0) * 0.4
	_egg_cd = GameConfig.num("spider", "egg_interval", 30.0) * 0.5


func _ability_update(delta: float) -> void:
	_web_cd = max(0.0, _web_cd - delta)
	_egg_cd = max(0.0, _egg_cd - delta)
	eggs = eggs.filter(func(e): return is_instance_valid(e))
	babies = babies.filter(func(b): return is_instance_valid(b))
	if _lock_left > 0.0 or possessed_by:
		return

	# 거미줄 발사
	var target := _best_target_in_view(GameConfig.num("spider", "web_range", 14.0))
	if target and _web_cd <= 0.0 and global_position.distance_to(target.global_position) >= 2.5:
		_shoot_web(target)
		return

	# 알 낳기 (추격 중이 아닐 때)
	if _egg_cd <= 0.0 and state != State.CHASE and eggs.size() < int(GameConfig.num("spider", "egg_max", 3)):
		var egg := Node3D.new()
		egg.set_script(EggScript)
		get_tree().current_scene.add_child(egg)
		egg.global_position = _floor_point(global_position + global_basis.z * 1.0)
		egg.call("setup", self)
		eggs.append(egg)
		_egg_cd = GameConfig.num("spider", "egg_interval", 30.0)
		_lock_left = 0.8


func can_hatch() -> bool:
	babies = babies.filter(func(b): return is_instance_valid(b))
	return babies.size() < int(GameConfig.num("spider", "baby_max", 4))


func _shoot_web(target: Survivor) -> void:
	var dir := target.global_position - global_position
	dir.y = 0.0
	rotation.y = atan2(-dir.x, -dir.z)
	shoot_web_from(self, global_position + Vector3.UP * 1.1 + dir.normalized() * 0.9, dir,
			GameConfig.num("spider", "web_range", 14.0))
	_web_cd = GameConfig.num("spider", "web_cooldown", 25.0)
	_lock_left = 0.4


## 여왕과 새끼가 같이 쓰는 거미줄 발사
func shoot_web_from(thrower: Node3D, from: Vector3, dir: Vector3, max_range: float) -> void:
	_launch("web", thrower, from, dir, GameConfig.num("spider", "web_speed", 28.0), max_range, 0.6)


## 거미줄에 맞음 (새끼가 묶으면 by_baby = true → 여왕이 위치를 알게 됨)
func web_hit(s: Survivor, by_baby: bool) -> void:
	if not is_active() or s.is_frozen:
		return
	s.root(GameConfig.num("spider", "web_root", 1.5))
	_notify(s, "거미줄에 묶였어요! (얼음만 쓸 수 있어요)")
	if by_baby:
		if possessed_by:
			_poss_call("poss_sense_at", [s.global_position, 3.0])
		else:
			alert_to(s.global_position)
	elif state != State.CHASE and not possessed_by:
		_start_chase(s)


func _on_projectile_hit(kind: String, s: Survivor) -> void:
	if kind == "web":
		web_hit(s, false)


func disable() -> void:
	super.disable()
	for n in eggs + babies:
		if is_instance_valid(n):
			n.queue_free()


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 거미줄 / [T] 알 낳기)

func poss_skills() -> Array:
	return [["거미줄 발사", "빠른 거미줄(14m). 맞으면 1.5초 동안 묶여요"],
			["알 낳기", "발밑에 알 (최대 %d개). 새끼가 생존자를 묶으면 위치가 보여요" % int(GameConfig.num("spider", "egg_max", 3))]]


func poss_note(n: int) -> String:
	if n == 1:
		eggs = eggs.filter(func(e): return is_instance_valid(e))
		babies = babies.filter(func(b): return is_instance_valid(b))
		return "알 %d · 새끼 %d" % [eggs.size(), babies.size()]
	return ""


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		var t := _aim_target(aim, 14.5, 10.0)
		var dir := (t.global_position - global_position) if t else aim
		dir.y = 0.0
		_face_aim(dir.normalized())
		shoot_web_from(self, global_position + Vector3.UP * 1.1 + dir.normalized() * 0.9, dir, GameConfig.num("spider", "web_range", 14.0))
		_lock_left = 0.4
		return GameConfig.num("spider", "web_cooldown", 25.0) * 0.6
	eggs = eggs.filter(func(e): return is_instance_valid(e))
	if eggs.size() >= int(GameConfig.num("spider", "egg_max", 3)):
		return "알은 최대 %d개까지 낳을 수 있어요" % int(GameConfig.num("spider", "egg_max", 3))
	var egg := Node3D.new()
	egg.set_script(EggScript)
	get_tree().current_scene.add_child(egg)
	egg.global_position = _floor_point(global_position + global_basis.z * 1.0)
	egg.call("setup", self)
	eggs.append(egg)
	_lock_left = 0.8
	return 10.0
