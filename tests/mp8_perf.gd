extends Node
## 8인 멀티 부하 확인 (방장 혼자 방을 만들고 봇 7명으로 채움): 맵마다 FPS·스크린샷 → (PC) ../pc_shots/mp8/
## 인자: 맵 (없으면 school hospital city forest), "turn" 이면 술래 변신 모드로 나를 술래로
var OUT := "/tmp/claude-0/-home-claude/4bd266e9-da2d-58f5-b240-71ca2bdf22f6/scratchpad/mp8/"
var log := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Windows":
		OUT = ProjectSettings.globalize_path("res://").path_join("../pc_shots/mp8/")
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(1600, 900)
	var args := Array(OS.get_cmdline_user_args())
	var af := ProjectSettings.globalize_path("res://").path_join("../pc_shots/mp8_args.txt")
	if args.is_empty() and FileAccess.file_exists(af):
		args = Array(FileAccess.get_file_as_string(af).strip_edges().split(" ", false))
	var turn := args.has("turn")
	var maps: Array = args.filter(func(a): return a in ["city", "forest", "school", "hospital"])
	if maps.is_empty():
		maps = ["school", "hospital", "city", "forest"]
	for map in maps:
		SaveData.test_map = map
		Net.host("PC")
		Net.pick_character("chameleon")
		Net.bot_fill = 8
		Net.match_mode = "turncoat" if turn else "classic"
		await get_tree().create_timer(0.3).timeout
		Net.start_match()
		var m = null
		while m == null or m.get("player") == null or not m.ready_to_play:
			await get_tree().create_timer(0.3).timeout
			m = get_tree().get_first_node_in_group("game")
		await get_tree().create_timer(2.0).timeout
		if turn:
			m._turn_left = 0.0
			Net.turn_seeker.rpc(0)
			await get_tree().create_timer(1.0).timeout
			m.player._seeker_skill(0)
			await get_tree().create_timer(0.3).timeout
		await _snap(map + ("_turn" if turn else "_8p"))
		# FPS 15초 (봇 8명 + 술래 AI)
		var frames := 0
		var worst := 0.0
		var t := 0.0
		while t < 15.0:
			await get_tree().process_frame
			var d := get_process_delta_time()
			t += d
			frames += 1
			worst = maxf(worst, d)
		var types := []
		for k in m.seekers:
			types.append(k.seeker_type)
		var line := "%s survivors=%d seekers=%s fps=%.0f worst=%.0fms" % [map, m.survivors.size(), str(types), frames / t, worst * 1000.0]
		print("MP8 ", line)
		log += line + "\n"
		var f := FileAccess.open(OUT + "log.txt", FileAccess.WRITE)
		f.store_string(log)
		f.close()
		if turn:
			var cnt := {}
			for c in get_tree().current_scene.get_children():
				var k: String = c.get_class() + ("/" + str(c.get_script().resource_path.get_file()) if c.get_script() else "")
				cnt[k] = int(cnt.get(k, 0)) + 1
			log += "scene children: " + str(cnt) + "\n"
		await _snap(map + ("_turn2" if turn else "_8p2"))
		var f2 := FileAccess.open(OUT + "log.txt", FileAccess.WRITE)
		f2.store_string(log)
		f2.close()
		Net.leave()
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		await get_tree().create_timer(1.5).timeout
	print("MP8 DONE")
	get_tree().quit()


func _snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + n + ".png")
