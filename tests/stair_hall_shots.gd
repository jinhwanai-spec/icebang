extends Node
## 계단실 점검: 맵의 계단마다 (1) 아래층 계단 앞에서 계단·복도 쪽, (2) 위층 도착점에서 복도·방 쪽을 사람 눈높이로 찍음
## 12칸씩 한 장 → (PC) ../pc_shots/stairs/ , (샌드박스) 스크래치/stairs/
var OUT := "/tmp/claude-0/-home-claude/4bd266e9-da2d-58f5-b240-71ca2bdf22f6/scratchpad/stairs/"
const W := 480
const H := 270


func _ready() -> void:
	if OS.get_name() == "Windows":
		OUT = ProjectSettings.globalize_path("res://").path_join("../pc_shots/stairs/")
	DirAccess.make_dir_recursive_absolute(OUT)
	get_window().size = Vector2i(W, H)
	var args := Array(OS.get_cmdline_user_args())
	var map: String = args[0] if args.size() > 0 else "city"
	var m = load("res://scenes/main.tscn").instantiate()
	m.forced_map = map
	get_tree().root.add_child.call_deferred(m)
	while m.player == null:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	get_tree().paused = false
	for k in m.seekers:
		k.set_physics_process(false)
		k.visible = false
	m.player.set_physics_process(false)
	m.hud.visible = false
	var cam := Camera3D.new()
	cam.fov = 75
	get_tree().root.add_child(cam)
	cam.make_current()
	var lamp := OmniLight3D.new()
	lamp.omni_range = 9.0
	lamp.light_energy = 1.4
	get_tree().root.add_child(lamp)
	var b = m._builder
	var sheets := [null, null]
	var n := 0
	var log := ""
	for st in b.kit.stair_list:
		if n >= 12:
			break
		var strip: Rect2 = st[0]
		var ax: bool = st[1]
		var d := Vector3(1, 0, 0) if ax else Vector3(0, 0, 1)
		if not st[2]:
			d = -d
		var yb: float = st[3]
		var rise: float = st[4]
		var run := strip.size.x if ax else strip.size.y
		var c := Vector3(strip.get_center().x, yb, strip.get_center().y)
		var side := Vector3(0, 0, 1) if ax else Vector3(1, 0, 0)
		var bottom := c - d * run * 0.5
		var top := c + d * run * 0.5
		var views := [
			[bottom - d * 0.55 + side * 1.4 + Vector3.UP * 1.6, top + d * 2.0 + side * 0.6 + Vector3.UP * 1.6],
			[top + d * 0.7 + side * 1.0 + Vector3.UP * (rise + 1.6), bottom + side * 2.2 + Vector3.UP * (rise + 0.8)],
		]
		for vi in 2:
			cam.global_position = views[vi][0]
			cam.look_at(views[vi][1], Vector3.UP)
			lamp.global_position = cam.global_position
			await get_tree().process_frame
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			if sheets[vi] == null:
				sheets[vi] = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
			(sheets[vi] as Image).blit_rect(img, Rect2i(0, 0, W, H), Vector2i((n % 4) * W, (n / 4) * H))
		log += "%d strip=%s run=%.1f\n" % [n, str(strip), run]
		n += 1
	for vi in 2:
		if sheets[vi]:
			(sheets[vi] as Image).save_png(OUT + "%s_%s.png" % [map, ["low", "top"][vi]])
	var f := FileAccess.open(OUT + map + "_log.txt", FileAccess.WRITE)
	f.store_string("stairs=%d\n" % b.kit.stair_list.size() + log)
	f.close()
	print("STAIR SHOTS ", b.kit.stair_list.size())
	get_tree().quit()
