extends Seeker
## 술래: 도살자
## - 쇠사슬 그랩: 약 10m. 판정이 좁아서 피할 수 있음. 맞으면 도살자 2m 앞까지 끌려옴 (쿨 40초)
## - 도끼 던지기: 약 10m. 느리게 날아가지만 판정은 넉넉함. 맞으면 피 흘림 + 이동속도 50% 감소 (쿨 30초)
## 둘 다 생존자를 보고 쫓는 중에만 사용합니다.

const ProjectileScript := preload("res://scripts/projectile.gd")
const SFX_THROW := preload("res://audio/teleport.wav")

var _chain_cd := 0.0
var _axe_cd := 0.0
var _throw_audio: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	_chain_cd = GameConfig.num("butcher", "chain_cooldown", 40.0) * 0.4
	_axe_cd = GameConfig.num("butcher", "axe_cooldown", 30.0) * 0.4
	_throw_audio = AudioStreamPlayer3D.new()
	_throw_audio.stream = SFX_THROW
	_throw_audio.max_distance = 25.0
	_throw_audio.pitch_scale = 0.6
	add_child(_throw_audio)


func _ability_update(delta: float) -> void:
	_chain_cd = max(0.0, _chain_cd - delta)
	_axe_cd = max(0.0, _axe_cd - delta)
	if _lock_left > 0.0:
		return

	var chain_range := GameConfig.num("butcher", "chain_range", 10.0)
	var axe_range := GameConfig.num("butcher", "axe_range", 10.0)
	var target := _best_target_in_view(maxf(chain_range, axe_range))
	if target == null:
		return
	var dist := global_position.distance_to(target.global_position)
	if dist < 3.5:
		return  # 너무 가까우면 그냥 잡으러 감

	if _chain_cd <= 0.0 and dist <= chain_range:
		_throw("chain", target)
		_chain_cd = GameConfig.num("butcher", "chain_cooldown", 40.0)
	elif _axe_cd <= 0.0 and dist <= axe_range:
		_throw("axe", target)
		_axe_cd = GameConfig.num("butcher", "axe_cooldown", 30.0)


func _throw(kind: String, target: Survivor) -> void:
	var dir := target.global_position - global_position
	dir.y = 0.0
	rotation.y = atan2(-dir.x, -dir.z)  # 던지는 방향을 바라봄
	var p := Node3D.new()
	p.set_script(ProjectileScript)
	get_tree().current_scene.add_child(p)
	var from := global_position + Vector3.UP * 1.3 + dir.normalized() * 0.8
	if kind == "chain":
		p.call("setup", self, from, dir, GameConfig.num("butcher", "chain_speed", 24.0),
				GameConfig.num("butcher", "chain_range", 10.0), GameConfig.num("butcher", "chain_hit_radius", 0.45), "chain")
		_lock_left = GameConfig.num("butcher", "chain_range", 10.0) / GameConfig.num("butcher", "chain_speed", 24.0) + 0.1
	else:
		p.call("setup", self, from, dir, GameConfig.num("butcher", "axe_speed", 9.0),
				GameConfig.num("butcher", "axe_range", 10.0), GameConfig.num("butcher", "axe_hit_radius", 0.8), "axe")
		_lock_left = 0.4
		_hide_axe(GameConfig.num("butcher", "axe_range", 10.0) / GameConfig.num("butcher", "axe_speed", 9.0))
	_throw_audio.play()


func _hide_axe(seconds: float) -> void:
	if body.axe_in_hand == null:
		return
	body.axe_in_hand.visible = false
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(body) and body.axe_in_hand:
		body.axe_in_hand.visible = true


## projectile.gd 가 생존자를 맞히면 불러 줌
func _on_projectile_hit(kind: String, s: Survivor) -> void:
	if not is_active() or s.is_frozen:
		return
	if kind == "axe":
		s.hit_by_axe()
		return
	# 쇠사슬: 내 앞 2m 까지 끌어옴
	var dir := s.global_position - global_position
	dir.y = 0.0
	var spot := global_position + dir.normalized() * GameConfig.num("butcher", "pull_to_distance", 2.0)
	spot = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), spot)
	s.pull_to(spot, 0.35)
	_lock_left = 0.35 + GameConfig.num("butcher", "chain_recover_time", 0.8)  # 잠깐 멈춤 → 도망칠 기회
	if state != State.CHASE:
		_start_chase(s)
