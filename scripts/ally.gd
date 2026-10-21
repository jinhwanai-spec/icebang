extends Survivor
## 동료 봇 (싱글플레이 테스트용 AI 동료)
## 나중에 멀티플레이를 만들면 이 자리에 다른 유저가 들어옵니다.
##
## 0.25초마다 아래 순서로 할 일을 정합니다.
##   1. 술래가 나를 쫓으며 가까이 오면 → 얼음
##   2. 술래가 가까이 있으면 → 반대 방향으로 도망
##   3. 얼음 상태 동료가 있고 근처에 술래가 없으면 → 구하러 가서 해동될 때까지 옆에 있음
##   4. 그 외 → 가장 가까운 봉인석으로 가서 가동
## 그리고 캐릭터 고유 능력도 상황에 맞게 씁니다 (_use_abilities)

const REPAIR_REACH := 2.4

var mode := "idle"   # idle / flee / rescue / repair (디버그용)

var _think_timer := 0.0
var _goal_generator: Generator = null

@onready var agent: NavigationAgent3D = $NavigationAgent3D


var _rescue_target: Survivor = null
## 고유 능력 쿨타임 남은 시간 [능력1, 능력2]
var _ability_cd := [0.0, 0.0]


var _arrows := -1
var _wisps_alive := 0


func _ready() -> void:
	super._ready()
	_think_timer = randf() * 0.25  # 봇들이 동시에 생각하지 않도록 살짝 어긋나게


func _physics_process(delta: float) -> void:
	if net_puppet:  # 멀티: 다른 사람이 조종하거나 방장 컴퓨터의 봇 → 받은 위치만 따라감
		_net_puppet_update(delta)
		return
	_common_physics(delta)
	if is_dead:
		return
	_ability_cd[0] = max(0.0, _ability_cd[0] - delta)
	_ability_cd[1] = max(0.0, _ability_cd[1] - delta)
	# 그림자 속에 숨은 동안은 그림자 주인을 따라가거나 제자리
	if escaped or in_locker:
		return
	if _follow_chain(delta):
		return
	if rooted_left > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if is_shadowed():
		# 그림자 봇: 술래가 멀어지면 그림자에서 나옴 (쿨타임은 나온 뒤부터)
		var sk := _nearest_seeker()
		if sk == null or sk.global_position.distance_to(global_position) > 14.0:
			_leave_shadow()
			_spend(0)
	if _follow_shadow_host():
		move_and_slide()
		return
	if _update_roll(delta):
		return
	# 인형사에게 조종당하는 중: 억지로 인형사 쪽으로 걸어감
	var forced := _controlled_direction()
	if forced != Vector3.ZERO and not is_frozen:
		var fs := GameConfig.num("ally", "speed", 4.3) * 0.6
		velocity.x = forced.x * fs
		velocity.z = forced.z * fs
		_face_direction(forced, delta)
		move_and_slide()
		return
	if is_frozen or pulled_time_left > 0.0 or is_blended():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	# 옆에 쥐가 있으면 바로 잡음
	var rat := _nearest_rat(GameConfig.num("rat", "minion_kill_reach", 2.0))
	if rat and can_interact():
		rat.call("kill", self)
	# 옆에 거미줄 덫이 있으면 걷어냄
	var web := nearest_web(GameConfig.num("spider", "web_clear_reach", 2.2))
	if web and can_interact():
		web.call("clear_web")

	_flee_age += delta
	_think_timer -= delta
	if _think_timer <= 0.0:
		_think_timer = 0.25
		_decide()

	var moving := false
	velocity.x = 0.0
	velocity.z = 0.0

	var reach := GameConfig.num("player", "unfreeze_distance", 1.8)
	if mode == "rescue" and _rescue_target and global_position.distance_to(_rescue_target.global_position) < reach * 0.85:
		pass  # 얼음 동료 옆에 붙어서 해동될 때까지 기다림
	elif mode == "repair" and is_instance_valid(_goal_generator) and not _goal_generator.completed and can_interact() \
			and global_position.distance_to(_goal_generator.global_position) <= REPAIR_REACH:
		_goal_generator.repair(delta, self)  # 도착했으면 봉인석 가동
	elif not agent.is_navigation_finished() or (mode == "repair" and is_instance_valid(_goal_generator) and not _goal_generator.completed):
		# 길 끝까지 왔는데 봉인석에 손이 안 닿으면 봉인석 쪽으로 곧장 붙음 (멍하니 서 있지 않게)
		var next := Survivor.next_flat_point(agent, global_position) if not agent.is_navigation_finished() else _goal_generator.global_position
		var dir := next - global_position
		dir.y = 0.0
		if dir.length() > 0.05:
			dir = dir.normalized()
			# 도망칠 때는 유저처럼 달림 (술래 추격 속도가 달리기 기준이라)
			var run := mode == "flee" and can_run()
			var base := GameConfig.num("player", "run_speed", 7.5) if run else GameConfig.num("ally", "speed", 4.3)
			_update_stamina(delta, "run" if run else "walk")
			var speed := base * speed_multiplier()
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			_face_direction(dir, delta)
			moving = true

	if not moving:
		_update_stamina(delta, "idle")
	_check_bot_stuck(delta, moving)
	velocity += take_external_pull()
	_footsteps(delta, moving, GameConfig.num("player", "walk_noise", 9.0), 0.45, -6.0)
	move_and_slide()


## 가려고 하는데 1.5초 동안 거의 못 움직였거나, 길 끝에 왔는데 봉인석에 손이 안 닿으면 → 다른 곳으로
var _stuck_t := 0.0
var _stuck_at := Vector3.ZERO

func _check_bot_stuck(delta: float, moving: bool) -> void:
	var waiting := (mode == "rescue" and _rescue_target and global_position.distance_to(_rescue_target.global_position) < 2.0) \
			or (mode == "repair" and is_instance_valid(_goal_generator) and global_position.distance_to(_goal_generator.global_position) <= REPAIR_REACH)
	if waiting:
		_stuck_t = 0.0
		_stuck_at = global_position
		return
	_stuck_t += delta
	if _stuck_t < 1.5:
		return
	if global_position.distance_to(_stuck_at) < 0.4:
		if mode == "repair" and is_instance_valid(_goal_generator):
			# 봉인석 다른 쪽으로 다시 시도, 두 번째부터는 잠시 다른 봉인석으로
			if _goal_spot != Vector3.INF and global_position.distance_to(_goal_generator.global_position) < 6.0:
				_goal_spot = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), _goal_generator.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.2)
				agent.target_position = _goal_spot
			else:
				_avoid[_goal_generator] = Time.get_ticks_msec() / 1000.0 + 20.0
				_goal_generator = null
		var a := randf() * TAU
		agent.target_position = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), global_position + Vector3(cos(a), 0, sin(a)) * 4.0)
		_think_timer = 0.6
	_stuck_t = 0.0
	_stuck_at = global_position


func _decide() -> void:
	var seeker := _nearest_seeker()
	if _use_abilities(seeker):
		return

	# 하마 블랙홀 앞이면 무조건 달려서 도망
	for node in get_tree().get_nodes_in_group("seeker"):
		if node.has_method("is_sucking") and node.call("is_sucking") \
				and global_position.distance_to((node as Node3D).global_position) < 15.0:
			var away := global_position - (node as Node3D).global_position
			away.y = 0.0
			agent.target_position = global_position + away.normalized() * 10.0
			mode = "flee"
			return

	if seeker and seeker.is_active():
		var d := global_position.distance_to(seeker.global_position)
		# 1. 쫓기는 중 + 가까움 → 얼음
		if seeker.chase_target == self and d < GameConfig.num("ally", "freeze_distance", 3.5) and can_freeze():
			freeze()
			return
		# 2. 술래가 가까움 → 도망
		if d < GameConfig.num("ally", "fear_distance", 8.0):
			# 길 위의 실제로 갈 수 있는 곳 중 술래에게서 가장 멀어지는 곳으로 (벽에 막혀 제자리걸음하지 않게)
			if mode != "flee" or agent.is_navigation_finished() or _flee_age > 1.0:
				agent.target_position = _flee_point(seeker.global_position)
				_flee_age = 0.0
			mode = "flee"
			return

	# 탈출 단계: 가까운 얼음 동료만 구하고, 나머지는 가장 가까운 탈출구로
	var game := get_tree().get_first_node_in_group("game")
	if game and game.escape_phase and not game.exits.is_empty():
		var near_friend := _find_frozen_friend(seeker)
		if near_friend and near_friend.global_position.distance_to(global_position) < 15.0:
			_rescue_target = near_friend
			agent.target_position = near_friend.global_position
			mode = "rescue"
			return
		var best: Node3D = null
		for e in game.exits:
			if best == null or global_position.distance_to(e.global_position) < global_position.distance_to(best.global_position):
				best = e
		agent.target_position = best.global_position
		mode = "flee"  # 달려서 감
		return

	# 3. 얼음 동료 구하기
	var friend := _find_frozen_friend(seeker)
	_rescue_target = friend
	if friend:
		agent.target_position = friend.global_position
		mode = "rescue"
		return

	# 4. 봉인석 가동하러 가기: 다른 봇이 이미 가는 곳은 피해서 흩어짐 (줄지어 다니지 않게)
	var g := _pick_generator()
	if g != _goal_generator:
		_goal_generator = g
		_goal_spot = Vector3.INF
	if _goal_generator:
		if _goal_spot == Vector3.INF:
			# 봉인석 둘레의 내 자리 (봇마다 다른 방향)
			var a := float(get_index() % 7) * 1.7 + randf() * 0.4
			var want := _goal_generator.global_position + Vector3(cos(a), 0, sin(a)) * 1.6
			_goal_spot = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), want)
		agent.target_position = _goal_spot
		mode = "repair"
		return

	# 할 일이 없으면 제자리에 서 있지 않고 주변을 살피며 돌아다님
	if agent.is_navigation_finished() or mode != "idle" or agent.target_position.distance_to(global_position) < 2.0:
		var a := randf() * TAU
		agent.target_position = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), global_position + Vector3(cos(a), 0, sin(a)) * randf_range(6.0, 14.0))
	mode = "idle"


var _flee_age := 0.0

## 도망칠 곳: 사방 12곳을 길 위로 맞춘 뒤, 술래와 멀고 실제로 걸어갈 수 있는 곳
func _flee_point(from: Vector3) -> Vector3:
	var map := agent.get_navigation_map()
	var away := global_position - from
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	var best := global_position + away * 6.0
	var best_score := -INF
	for i in 12:
		var a := i * TAU / 12.0 + randf() * 0.3
		var dir := Vector3(cos(a), 0, sin(a))
		var cand := NavigationServer3D.map_get_closest_point(map, global_position + dir * randf_range(7.0, 11.0))
		var path := NavigationServer3D.map_get_path(map, global_position, cand, true)
		if path.size() < 2 or path[path.size() - 1].distance_to(cand) > 1.0:
			continue
		var plen := 0.0
		for k in path.size() - 1:
			plen += path[k].distance_to(path[k + 1])
		if plen < 3.0:
			continue
		# 첫 걸음이 술래 쪽이면 감점, 도착점이 술래와 멀수록 가점
		var first: Vector3 = path[1] - global_position
		first.y = 0.0
		var toward := first.normalized().dot((from - global_position).normalized()) if first.length() > 0.01 else 0.0
		var score := cand.distance_to(from) - toward * 6.0 - plen * 0.15
		if score > best_score:
			best_score = score
			best = cand
	return best


## 갈 봉인석 고르기: 가까울수록 좋고, 다른 봇이 이미 맡은 곳·못 가는 곳은 피함
var _goal_spot := Vector3.INF
var _avoid := {}  # 봉인석 → 피할 시각 (길이 막혀 못 갔던 곳)

func _pick_generator() -> Generator:
	var now := Time.get_ticks_msec() / 1000.0
	var best: Generator = null
	var best_score := INF
	for node in get_tree().get_nodes_in_group("generator"):
		var g := node as Generator
		if g == null or g.completed or float(_avoid.get(g, 0.0)) > now:
			continue
		var claims := 0
		for other in get_tree().get_nodes_in_group("survivor"):
			if other != self and other.get("_goal_generator") == g and not other.is_dead and not other.is_frozen:
				claims += 1
		var score := global_position.distance_to(g.global_position) + claims * 35.0
		if g == _goal_generator:
			score -= 8.0  # 하던 일은 웬만하면 계속
		if score < best_score:
			best = g
			best_score = score
	return best


## 구하러 가도 안전한 얼음 동료 중 가장 가까운 대상
func _find_frozen_friend(seeker: Seeker) -> Survivor:
	var safe_dist := GameConfig.num("ally", "rescue_safe_distance", 7.0)
	var best: Survivor = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s == self or not s.is_frozen or s.is_dead:
			continue
		if seeker and seeker.is_active() and seeker.global_position.distance_to(s.global_position) < safe_dist:
			continue  # 술래가 지키고 있으면 위험하니 패스
		var d := global_position.distance_to(s.global_position)
		# 더 가까운 다른 봇이 이미 구하러 가는 중이면 나는 다른 일
		var taken := false
		for other in get_tree().get_nodes_in_group("survivor"):
			if other != self and other.get("_rescue_target") == s and other.global_position.distance_to(s.global_position) < d:
				taken = true
				break
		if taken:
			continue
		if d < best_d:
			best = s
			best_d = d
	return best


# ---------------------------------------------------------------- 봇의 고유 능력 사용

## 상황에 맞으면 능력을 쓰고 true (이번 판단은 여기서 끝). 아니면 false
func _use_abilities(seeker: Seeker) -> bool:
	var d := INF
	var chased := false
	if seeker and seeker.is_active():
		d = global_position.distance_to(seeker.global_position)
		chased = seeker.chase_target == self
	var game := get_tree().get_first_node_in_group("game")
	match character_id:
		"chameleon":
			# 쫓기며 가까워지면 동화 (제자리에서 숨음)
			if chased and d < 5.0 and _ready_slot(0) and can_freeze():
				blend_time_left = GameConfig.num("chameleon", "blend_duration", 7.5)
				_spend(0)
				return true
			# 술래가 가까우면 맵 물들이기 후 도망
			if d < 9.0 and not chased and _ready_slot(1) and not is_blended():
				var t := GameConfig.num("chameleon", "paint_duration", 15.0)
				paint_time_left = t
				game.paint_map(CharacterDB.get_info(character_id)["color"], t)
				_spend(1)
		"space":
			# 쫓기며 가까워지면 순간이동
			if chased and d < 4.0 and _ready_slot(0):
				teleport_to(game.random_floor_point())
				_spend(0)
				return true
			# 위험한 곳에 있는 얼음 동료를 내 앞으로 소환해서 해동
			if _ready_slot(1) and d > 12.0:
				var target := _frozen_friend_in_danger()
				if target:
					target.teleport_to(game.closest_floor_point(global_position + body.global_basis.z * 1.5))
					_spend(1)
					_rescue_target = target
					mode = "rescue"
					return true
		"cameraman":
			# 쫓아오는 술래가 보이는 거리에 있으면 플래시
			if chased and d < GameConfig.num("cameraman", "photo_range", 14.0) and _ready_slot(0) \
					and seeker.visible_to_players() and _clear_line_to(seeker):
				seeker.stun(GameConfig.num("cameraman", "photo_stun_time", 1.5))
				play_sfx(preload("res://audio/shutter.wav"))
				_spend(0)
			# 봉인석 가동 중이면 근처에 카메라 설치 (봉인석 반대쪽을 감시)
			if mode == "repair" and is_instance_valid(_goal_generator) and _ready_slot(1) \
					and global_position.distance_to(_goal_generator.global_position) <= REPAIR_REACH:
				var cam := Node3D.new()
				cam.set_script(preload("res://scripts/placed_camera.gd"))
				get_tree().current_scene.add_child(cam)
				var away := global_position - _goal_generator.global_position
				away.y = 0.0
				cam.global_position = game.closest_floor_point(global_position + away.normalized())
				cam.look_at(cam.global_position + away.normalized(), Vector3.UP)
				cam.call("setup", self)
				_spend(1)
		"medic":
			# 치료: 얼음 동료가 있으면 해동, 없으면 쫓기는 동료에게 이속 증가
			if _ready_slot(0):
				for node in get_tree().get_nodes_in_group("survivor"):
					var s := node as Survivor
					if s and s != self and s.is_frozen and not s.is_dead and not _seeker_near(s.global_position):
						s.unfreeze(self)  # 술래가 바로 옆이면 녹여도 곧 다시 잡히니 기다림
						_spend(0)
						break
			# 붕대: 술래 근처에 있는 얼음 동료를 내 앞으로 당겨 와서 구함
			if _ready_slot(1) and d > 10.0:
				var target := _frozen_friend_in_danger()
				if target and target.global_position.distance_to(global_position) <= GameConfig.num("medic", "bandage_range", 15.0) \
						and _clear_line_to(target):
					target.bandage_pull(game.closest_floor_point(global_position + body.global_basis.z * 1.5), GameConfig.num("medic", "bandage_pull_time", 0.5))
					_spend(1)
					_rescue_target = target
					mode = "rescue"
					return true
		"shadow":
			# 쫓기며 술래가 가까우면 그림자 속으로 (근처 동료가 있으면 그 그림자에)
			if chased and d < 5.0 and _ready_slot(0) and not is_shadowed():
				var host: Node3D = null
				for node in get_tree().get_nodes_in_group("survivor"):
					if node != self and not node.is_dead and node.global_position.distance_to(global_position) < 3.0:
						host = node
						break
				enter_shadow(GameConfig.num("shadow", "shadow_time", 20.0), host)
				_spend(0)
				return true
		"hunter":
			# 쫓기면 발밑에 덫, 술래가 보이면 핏빛 화살 (화살 수 = 술래 수)
			if chased and d < 10.0 and _ready_slot(0):
				_effect("trap", global_position)
				_spend(0)
			if _arrows < 0:
				_arrows = get_tree().get_first_node_in_group("game").seekers.size()
			if _arrows > 0 and _ready_slot(1) and d < 30.0 and not seeker.is_bleeding \
					and seeker.visible_to_players() and _clear_line_to(seeker):
				var dir := seeker.global_position - global_position
				dir.y = 0.0
				_effect_raw("arrow", global_position + Vector3.UP * 1.3 + dir.normalized() * 0.6, dir.normalized())
				_arrows -= 1
				_spend(1)
		"bard":
			pass  # 봇은 노래하지 않음 (노래는 술래에게 위치가 드러나서 유저가 판단해서 쓰는 기술)
		"keeper":
			# 탐색광이 준비되면 술래를 찾으러 보냄 (빛이 모두 사라진 뒤 쿨타임)
			if _ready_slot(1) and _wisps_alive == 0 and d > 6.0:
				for node in get_tree().get_nodes_in_group("seeker"):
					_effect_raw("wisp", global_position + Vector3.UP * 2.0, body.global_basis.z, node)
					_wisps_alive += 1
				_ability_cd[1] = 9999.0
		"mechanic":
			# 보급품이 없으면 바로 착용
			if item == "" and _ready_slot(1):
				give_random_item()
				_spend(1)
		"gravity":
			# 쫓기며 술래가 보이면 무중력, 조금 떨어져 있으면 무중력 구슬
			if chased and d < 10.0 and _ready_slot(0) and seeker.visible_to_players() and _clear_line_to(seeker):
				seeker.float_up(GameConfig.num("gravity", "float_time", 3.0))
				play_sfx(preload("res://audio/ability.wav"))
				_spend(0)
				return true
			if d > 4.0 and d < 20.0 and _ready_slot(1) and seeker.visible_to_players() and _clear_line_to(seeker):
				var dir := seeker.global_position - global_position
				dir.y = 0.0
				_effect_raw("orb", global_position + Vector3.UP * 1.2 + dir.normalized() * 1.0, dir.normalized())
				_spend(1)
		"brute":
			# 술래가 주먹 닿는 거리면 강펀치 (얼음보다 먼저)
			if d < GameConfig.num("brute", "punch_range", 3.0) and _ready_slot(1) and seeker.visible_to_players():
				var pdir := seeker.global_position - global_position
				pdir.y = 0.0
				body.look_at(body.global_position - pdir.normalized(), Vector3.UP)
				body.punch(0.45)
				load("res://scripts/fist_fx.gd").spawn(self, pdir, true)
				seeker.knockback(pdir)
				seeker.set_meta("land_stun", GameConfig.num("brute", "punch_stun", 1.5))
				play_sfx(preload("res://audio/punch.wav"))
				_spend(1)
				return true
	return false


func _ready_slot(i: int) -> bool:
	return _ability_cd[i] <= 0.0 and not CharacterDB.is_passive(character_id, i + 1)


func _spend(i: int) -> void:
	_ability_cd[i] = CharacterDB.cooldown(character_id, i + 1)


func _clear_line_to(target: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, target.global_position + Vector3.UP * 1.3)
	q.exclude = [get_rid(), (target as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## 근처에 술래가 있어서 구하러 가기 위험한 얼음 동료
func _seeker_near(p: Vector3) -> bool:
	var safe := GameConfig.num("ally", "rescue_safe_distance", 7.0)
	for k in get_tree().get_nodes_in_group("seeker"):
		if k is Node3D and k.visible and (k as Node3D).global_position.distance_to(p) < safe:
			return true
	return false


func _frozen_friend_in_danger() -> Survivor:
	var safe := GameConfig.num("ally", "rescue_safe_distance", 7.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s == null or s == self or not s.is_frozen or s.is_dead:
			continue
		for sk_node in get_tree().get_nodes_in_group("seeker"):
			var sk := sk_node as Seeker
			if sk.is_active() and sk.global_position.distance_to(s.global_position) < safe:
				return s
	return null


## 술래가 공격하려 할 때: 확률적으로 옆으로 굴러서 피함
func on_attacked(by: Node3D) -> void:
	if randf() < GameConfig.num("ally", "roll_chance", 0.5):
		var away := global_position - by.global_position
		away.y = 0.0
		start_roll(away.normalized().rotated(Vector3.UP, randf_range(-0.8, 0.8)))


## 바닥에 붙이지 않고 그 위치 그대로 효과를 띄움 (화살, 탐색광)
func _effect_raw(kind: String, pos: Vector3, dir: Vector3, target: Node = null) -> Node3D:
	var e := Node3D.new()
	e.set_script(preload("res://scripts/ability_effect.gd"))
	get_tree().current_scene.add_child(e)
	if target:
		e.set_meta("target", target)
	e.call("setup", kind, pos, dir, self)
	return e


## 탐색광이 사라질 때 불림. 모두 사라지면 쿨타임 시작
func on_wisp_done() -> void:
	_wisps_alive = max(0, _wisps_alive - 1)
	if _wisps_alive == 0:
		_ability_cd[1] = CharacterDB.cooldown(character_id, 2)


func _effect(kind: String, pos: Vector3, dir := Vector3.FORWARD) -> void:
	var e := Node3D.new()
	e.set_script(preload("res://scripts/ability_effect.gd"))
	get_tree().current_scene.add_child(e)
	var game := get_tree().get_first_node_in_group("game")
	e.call("setup", kind, game.closest_floor_point(pos), dir, self)
