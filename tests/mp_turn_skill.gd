extends Node
## 멀티 '술래 변신' 능력 확인: 방장 + 손님. 손님이 술래로 변해 [R] [T] 를 써 봄
## 인자: role stage(술래 종류 순서 1~11) mode(turncoat/classic) fill(인원)
var role := "host"
var stage := 1
var mode := "turncoat"
var fill := 8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := OS.get_cmdline_user_args()
	role = a[0]
	if a.size() > 1: stage = int(a[1])
	if a.size() > 2: mode = a[2]
	if a.size() > 3: fill = int(a[3])
	print("MT start ", role)
	if role == "host":
		SaveData.test_map = "school"
		SaveData.stage = stage
		Net.host("H")
		Net.pick_character("chameleon")
		while Net.players.size() < 2 or not Net.all_ready():
			await get_tree().create_timer(0.3).timeout
		if mode == "turncoat":
			Net.toggle_mode()
		while Net.bot_fill != fill:
			Net.cycle_fill()
			await get_tree().create_timer(0.2).timeout
		await get_tree().create_timer(0.5).timeout
		print("MT host starting fill=", Net.bot_fill, " mode=", Net.match_mode)
		Net.start_match()
	else:
		await get_tree().create_timer(1.0).timeout
		Net.join("127.0.0.1", "C")
		while Net.players.size() < 2:
			await get_tree().create_timer(0.3).timeout
		Net.pick_character("brute")
		await get_tree().create_timer(0.8).timeout
		Net.set_ready(true)
	print("MT ", role, " lobby ok players=", Net.players.size())
	var m = null
	var waited := 0.0
	while m == null or m.get("player") == null or not m.ready_to_play:
		await get_tree().create_timer(0.3).timeout
		waited += 0.3
		m = get_tree().get_first_node_in_group("game")
		if fmod(waited, 6.0) < 0.3:
			print("MT ", role, " wait m=", m != null, " player=", m.get("player") != null if m else false, " ready=", m.ready_to_play if m else false, " scene=", get_tree().current_scene.name if get_tree().current_scene else "-")
	var types := []
	for k in m.seekers:
		types.append(k.seeker_type)
	print("MT ", role, " survivors=", m.survivors.size(), " seekers=", types, " mode=", Net.match_config.get("mode"))
	var sp := {}
	for s in m.survivors:
		sp[str(s.global_position.snapped(Vector3.ONE * 0.1))] = true
	print("MT ", role, " distinct spawns=", sp.size())
	m.player.connect("notice", func(t: String) -> void: print("MT ", role, " NOTICE: ", t))
	if mode != "turncoat":
		await get_tree().create_timer(3.0).timeout
		print("MT ", role, " DONE")
		get_tree().quit()
		return
	var b2 = m.survivors[2]
	var b3 = m.survivors[3]
	if role == "host":
		m._turn_left = 0.0
		# 시험용 봇 2명: 2번은 가만히 서 있고, 3번은 얼음 (처형·사이코 묶기 확인)
		for b in [b2, b3]:
			b.set_physics_process(false)
			b.velocity = Vector3.ZERO
		b3.global_position = b2.global_position + Vector3(8.0, 0, 0)
		b3.freeze()
		Net.turn_seeker.rpc(1)
	await get_tree().create_timer(2.0).timeout
	var sk = m.seekers[0]
	var frozen_need := {"executioner": [0], "psycho": [1]}
	if role == "client":
		var me = m.player
		print("MT client turned=", me.turned_seeker != null, " type=", sk.seeker_type)
		for n in 2:
			var near_frozen: bool = (frozen_need.get(sk.seeker_type, []) as Array).has(n)
			var tgt = b3 if near_frozen else b2
			var off := Vector3(0, 0, 2.0 if near_frozen else 6.0)
			me.global_position = tgt.global_position + off
			var dir: Vector3 = tgt.global_position - me.global_position
			dir.y = 0
			me.pivot.global_rotation.y = atan2(-dir.x, -dir.z)
			await get_tree().create_timer(0.5).timeout
			me._seeker_skill(n)
			await get_tree().create_timer(2.5).timeout
			var proj := 0
			for c in get_tree().current_scene.get_children():
				if c.get_script() == preload("res://scripts/projectile.gd"):
					proj += 1
			print("MT client skill ", n, " [", sk.poss_skills()[n][0], "] cd=", snappedf(sk.poss_cd(n), 0.1), " note=", sk.poss_note_any(n), " extras=", m._extra_nodes.size(), " pos=", me.global_position.snapped(Vector3.ONE * 0.1), " fog=", snappedf(m.world_env.environment.fog_density, 0.01))
		me._seeker_skill(0)
		await get_tree().create_timer(1.0).timeout
	else:
		for k in 11:
			await get_tree().create_timer(1.0).timeout
			print("MT host t", k, " poss=", sk.poss_pack(), " extras=", m._net_extras_pack().size(),
				" | b2 slow=", snappedf(b2.slow_left, 0.1), " bleed=", snappedf(b2.bleed_time_left, 0.1), " root=", snappedf(b2.rooted_left, 0.1), " ctrl=", snappedf(b2.controlled_left, 0.1), " pull=", snappedf(b2.pulled_time_left, 0.1), " dead=", b2.is_dead,
				" | b3 frozen=", b3.is_frozen, " dead=", b3.is_dead, " chained=", b3.chained_by != null)
	await get_tree().create_timer(1.0).timeout
	print("MT ", role, " DONE")
	get_tree().quit()
