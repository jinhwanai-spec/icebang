extends Node
## 화면 점검용 스크린샷: 메인 메뉴 / 멀티 로비(8칸) / 게임 화면(생존자) / 게임 화면(술래로 변함)
## 인자: 술래 종류 (기본 butcher)
var out := "/tmp/claude-0/-home-claude/4bd266e9-da2d-58f5-b240-71ca2bdf22f6/scratchpad/ui/"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_name() == "Windows":
		out = ProjectSettings.globalize_path("res://").path_join("../pc_shots/ui/")
	DirAccess.make_dir_recursive_absolute(out)
	var args := OS.get_cmdline_user_args()
	var sk_type: String = args[0] if args.size() > 0 else "butcher"
	get_window().size = Vector2i(1600, 900)
	# --- 메뉴
	CrashLog.crashed_last_time = false
	var menu = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(2.0).timeout
	await _shot("menu_main")
	# --- 멀티 로비: 가짜로 방장 + 손님 4명
	Net.active = true
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Net.players = {1: {"name": "방장진환", "character": "chameleon", "ready": true, "in_game": false},
		201: {"name": "친구A", "character": "brute", "ready": true, "in_game": false},
		202: {"name": "친구B", "character": "", "ready": false, "in_game": false},
		203: {"name": "아주긴이름의친구", "character": "medic", "ready": true, "in_game": false},
		204: {"name": "친구D", "character": "hunter", "ready": false, "in_game": false}}
	Net.match_mode = "turncoat"
	Net.bot_fill = 6
	menu._show("multi")
	menu._refresh_multi()
	await get_tree().create_timer(0.6).timeout
	await _shot("menu_multi")
	Net.players = {}
	Net.active = false
	multiplayer.multiplayer_peer = null
	menu.queue_free()
	await get_tree().create_timer(0.3).timeout
	# --- 게임 화면
	var m = load("res://scenes/main.tscn").instantiate()
	m.forced_map = "school"
	m.forced_seeker_type = sk_type
	get_tree().root.add_child(m)
	while m.player == null or not m.ready_to_play:
		await get_tree().create_timer(0.3).timeout
	get_tree().paused = false
	await get_tree().create_timer(1.5).timeout
	await _shot("hud_survivor")
	var sk = m.seekers[0]
	m.player.become_seeker(sk)
	await get_tree().create_timer(1.0).timeout
	m.player._seeker_skill(0)
	await get_tree().create_timer(0.25).timeout
	await _shot("hud_seeker_skill")
	await get_tree().create_timer(1.5).timeout
	m.player._seeker_skill(1)
	await get_tree().create_timer(1.0).timeout
	await _shot("hud_seeker")
	# --- 결과 화면 (8명)
	var rows: Array = m._stats_rows()
	var names := ["친구A", "친구B", "아주긴이름의친구", "봇4 (악사)", "봇5 (정비공)", "봇6 (그림자)", "봇7 (의사)"]
	var k := 0
	while rows.size() < 8:
		var r: Dictionary = (rows[k % rows.size()] as Dictionary).duplicate()
		r["name"] = names[k % names.size()]
		r["me"] = false
		r["mvp"] = false
		r["rescues"] = k % 3
		r["result"] = ["탈출", "생존", "탈락"][k % 3]
		rows.append(r)
		k += 1
	m.hud.show_result(true, "봉인 성공!", "플레이 시간 4:05", rows, 120)
	await get_tree().create_timer(1.5).timeout
	await _shot("result8")
	print("UI SHOTS DONE ", out)
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
	print("SHOT ", name)
