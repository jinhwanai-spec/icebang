extends Node
## 오늘의 규칙 · 정전 확인: 인자 = 맵 규칙id (예: school tiny_seeker). 평소 / 정전 / 복구 화면을 찍음
## → (PC) ../pc_shots/rules/ , (샌드박스) 스크래치/rules/
var OUT := "/tmp/claude-0/-home-claude/4bd266e9-da2d-58f5-b240-71ca2bdf22f6/scratchpad/rules/"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Windows":
		OUT = ProjectSettings.globalize_path("res://").path_join("../pc_shots/rules/")
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1600, 900)
	var args := Array(OS.get_cmdline_user_args())
	var af := ProjectSettings.globalize_path("res://").path_join("../pc_shots/rule_args.txt")
	if args.is_empty() and FileAccess.file_exists(af):
		args = Array(FileAccess.get_file_as_string(af).strip_edges().split(" ", false))
	var map: String = args[0] if args.size() > 0 else "school"
	var rule: String = args[1] if args.size() > 1 else "tiny_seeker"
	var keep := SaveData.daily_rule
	SaveData.daily_rule = rule
	var m = load("res://scenes/main.tscn").instantiate()
	m.forced_map = map
	get_tree().root.add_child.call_deferred(m)
	while m.player == null or not m.ready_to_play:
		await get_tree().create_timer(0.3).timeout
	SaveData.daily_rule = keep
	get_tree().paused = false
	for k in m.seekers:
		k.set_physics_process(false)
	var log := "rule=%s stamina_max=%.0f thaw=%.1f rage=%.0f fog=%.3f mission=%d sight=%.1f scale=%.2f maxfreeze=%d coins=%.0f\n" % [
		m.daily_rule, GameConfig.num("stamina", "max", 0), GameConfig.num("player", "thaw_time", 0), GameConfig.num("seeker", "rage_time", 0),
		m.world_env.environment.fog_density, m.mission_total, GameConfig.num("seeker", "far_sight_range", 0),
		m.seekers[0].body.scale.x, int(GameConfig.num("freeze_rule", "max_freezes", 0)), GameConfig.num("reward", "clear", 0)]
	# 술래를 플레이어 앞 5m 에 세워 둠 (크기·정전 중 눈 보이기 확인)
	var p = m.player
	var fwd: Vector3 = -p.spring_arm.global_basis.z
	fwd.y = 0
	m.seekers[0].global_position = p.global_position + fwd.normalized() * 6.0
	await get_tree().create_timer(6.0).timeout
	await _snap(map + "_" + rule + "_1normal")
	m.start_blackout(6.0)
	await get_tree().create_timer(1.6).timeout
	await _snap(map + "_" + rule + "_2blackout")
	log += "blackout lights_off=%d sight=%.2f\n" % [m._bo_lights.size(), Seeker.dark_sight]
	await get_tree().create_timer(6.5).timeout
	await _snap(map + "_" + rule + "_3restored")
	log += "restored sight=%.2f lights_saved=%d\n" % [Seeker.dark_sight, m._bo_lights.size()]
	var f := FileAccess.open(OUT + "log.txt", FileAccess.WRITE)
	f.store_string(log)
	f.close()
	print("RULE ", log)
	get_tree().quit()


func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
