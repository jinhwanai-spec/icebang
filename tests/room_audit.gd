extends Node
## 맵 점검: (1) 모든 방을 방 구석 높은 곳에서 반대편 구석을 보며 사진 (12장씩 한 장으로 묶음)
## (2) 이상한 부품 자동 검출: 떠 있는 부품, 아무것에도 안 붙은 얇은 막대
## 결과 → (PC) ../pc_shots/audit/ , (샌드박스) 스크래치/audit/
var OUT := "/tmp/claude-0/-home-claude/4bd266e9-da2d-58f5-b240-71ca2bdf22f6/scratchpad/audit/"
const W := 480
const H := 270

var corr_mode := false
var out_mode := false
var maps_stairs := false
var no_rooms := false


func _ready() -> void:
	if OS.get_name() == "Windows":
		OUT = ProjectSettings.globalize_path("res://").path_join("../pc_shots/audit/")
	DirAccess.make_dir_recursive_absolute(OUT)
	BuildingKit.debug_record = true
	get_window().size = Vector2i(W, H)
	var args := OS.get_cmdline_user_args()
	var af := ProjectSettings.globalize_path("res://").path_join("../pc_shots/audit_args.txt")
	if args.is_empty() and FileAccess.file_exists(af):  # PC에서: 인자 파일 (예: "hospital forest corr out")
		var txt := FileAccess.get_file_as_string(af).strip_edges()
		if txt != "":
			args = PackedStringArray(txt.split(" "))
	var maps: Array = ["city", "school", "hospital", "forest"] if args.is_empty() else Array(args)
	var shots := not maps.has("noshots")
	maps.erase("noshots")
	corr_mode = maps.has("corr") or args.is_empty()
	maps.erase("corr")
	maps.erase("tall")
	out_mode = maps.has("out") or args.is_empty()
	maps.erase("out")
	maps_stairs = maps.has("stairs")
	no_rooms = maps.has("norooms")
	maps.erase("norooms")
	maps.erase("stairs")
	if maps.is_empty():
		maps = ["city", "school", "hospital", "forest"]
	var rep := ""
	for map in maps:
		var m = load("res://scenes/main.tscn").instantiate()
		m.forced_map = map
		get_tree().root.add_child.call_deferred(m)
		while m.player == null:
			await get_tree().process_frame
		await get_tree().create_timer(0.8).timeout
		get_tree().paused = false
		for k in m.seekers:
			k.set_physics_process(false)
			k.global_position = Vector3(0, -80, 0)
		for s in m.survivors:
			s.set_physics_process(false)
			s.global_position = Vector3(0, -90, 0)
			s.visible = false
		var hud = m.get_node_or_null("HUD")
		if hud: hud.visible = false
		var b = m._builder
		rep += _scan(map, b)
		var cam := Camera3D.new()
		cam.fov = 78
		m.add_child(cam)
		cam.current = true
		var fill := OmniLight3D.new()
		fill.light_energy = 2.5
		fill.omni_range = 14.0
		fill.shadow_enabled = false
		cam.add_child(fill)
		var mid := OmniLight3D.new()
		mid.light_energy = 3.0
		mid.omni_range = 12.0
		mid.omni_attenuation = 0.6
		m.add_child(mid)
		cam.near = 0.03
		var rooms: Array = b.debug_rooms if shots and not no_rooms else []
		var sheet: Image = null
		var n := 0
		var sheet_i := 0
		var idx_log := ""
		for ri in rooms.size():
			var rr = rooms[ri]
			var rect: Rect2 = rr[0]["rect"]
			var fy: float = rr[1]
			var p0 := Vector3(rect.position.x + 0.9, fy + 1.9, rect.position.y + 0.9)
			var p1 := Vector3(rect.end.x - 0.55, fy + 0.5, rect.end.y - 0.55)
			mid.global_position = Vector3(rect.get_center().x, fy + 2.3, rect.get_center().y)
			for v in 2:  # 두 방향 (대각선 양쪽 구석에서)
				var a := p0 if v == 0 else Vector3(rect.end.x - 0.9, fy + 1.9, rect.end.y - 0.9)
				var t := p1 if v == 0 else Vector3(rect.position.x + 0.55, fy + 0.5, rect.position.y + 0.55)
				cam.global_position = a
				cam.look_at(t, Vector3.UP)
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				if sheet == null:
					sheet = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
				var cell := n % 12
				sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((cell % 4) * W, (cell / 4) * H))
				idx_log += "%s sheet%d cell%d room%d v%d kind=%s rect=%s y=%.1f\n" % [map, sheet_i, cell, ri, v, rr[0].get("kind", ""), rect, fy]
				n += 1
				if n % 12 == 0:
					sheet.save_png(OUT + "%s_%02d.png" % [map, sheet_i])
					sheet = null
					sheet_i += 1
		if sheet:
			sheet.save_png(OUT + "%s_%02d.png" % [map, sheet_i])
		# 복도: 몇 개 방 문 앞(복도 쪽)에서 복도를 따라 양쪽으로
		if shots and corr_mode:
			var cs: Image = null
			var cn := 0
			var ci := 0
			for ri in range(0, rooms.size(), 3):
				var rm: Dictionary = rooms[ri][0]
				var da: Vector3 = rm.get("door_at", Vector3.INF)
				if da == Vector3.INF:
					continue
				var rc: Vector2 = (rm["rect"] as Rect2).get_center()
				var out_dir := Vector3(da.x - rc.x, 0, da.z - rc.y)
				if rm.get("door_along_x", true):
					out_dir = Vector3(0, 0, signf(out_dir.z))
				else:
					out_dir = Vector3(signf(out_dir.x), 0, 0)
				var side := Vector3(out_dir.z, 0, -out_dir.x)
				var fy2: float = rooms[ri][1]
				var cp := Vector3(da.x, fy2 + 1.7, da.z) + out_dir * 1.6
				mid.global_position = cp + Vector3.UP * 0.5
				for v in 2:
					cam.global_position = cp
					cam.look_at(cp + side * (1.0 if v == 0 else -1.0) * 6.0 + Vector3.DOWN * 0.6, Vector3.UP)
					await get_tree().process_frame
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					var img2 := get_viewport().get_texture().get_image()
					img2.convert(Image.FORMAT_RGB8)
					if cs == null:
						cs = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
					var cell2 := cn % 12
					cs.blit_rect(img2, Rect2i(0, 0, W, H), Vector2i((cell2 % 4) * W, (cell2 / 4) * H))
					idx_log += "%s corr%d cell%d room%d v%d pos=%s\n" % [map, ci, cell2, ri, v, cp]
					cn += 1
					if cn % 12 == 0:
						cs.save_png(OUT + "%s_corr%02d.png" % [map, ci])
						cs = null
						ci += 1
			if cs:
				cs.save_png(OUT + "%s_corr%02d.png" % [map, ci])
		# 계단: 아래쪽 끝에서 위를 보고 한 장씩 (최대 12)
		print("AUDIT stairs ", map, " ", b.kit.stair_list.size() if b.get("kit") else -1)
		if shots and maps_stairs:
			var st_img: Image = null
			var st_top: Image = null
			var sn := 0
			for st in b.kit.stair_list:
				if sn >= 12:
					break
				var strip: Rect2 = st[0]
				var ax: bool = st[1]
				var fw: bool = st[2]
				var yb: float = st[3]
				var rise: float = st[4]
				var d := Vector3(1, 0, 0) if ax else Vector3(0, 0, 1)
				if not fw:
					d = -d
				var run := strip.size.x if ax else strip.size.y
				var c3 := Vector3(strip.get_center().x, yb, strip.get_center().y)
				var cp3 := c3 - d * (run * 0.5 + 1.8) + Vector3.UP * 1.6
				cam.global_position = cp3
				cam.look_at(c3 + d * run * 0.3 + Vector3.UP * rise * 0.6, Vector3.UP)
				mid.global_position = c3 + Vector3.UP * (rise * 0.5 + 1.0)
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img4 := get_viewport().get_texture().get_image()
				img4.convert(Image.FORMAT_RGB8)
				if st_img == null:
					st_img = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
				st_img.blit_rect(img4, Rect2i(0, 0, W, H), Vector2i((sn % 4) * W, (sn / 4) * H))
				# 위층 도착점에서 복도·방 쪽을 봄
				cam.global_position = c3 + d * (run * 0.5 + 1.2) + Vector3.UP * (rise + 1.6)
				cam.look_at(c3 + d * (run * 0.5 + 6.0) + Vector3.UP * (rise + 1.0) + (Vector3(0, 0, 1) if ax else Vector3(1, 0, 0)) * 1.5, Vector3.UP)
				mid.global_position = cam.global_position + Vector3.UP * 0.5
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img5 := get_viewport().get_texture().get_image()
				img5.convert(Image.FORMAT_RGB8)
				if st_top == null:
					st_top = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
				st_top.blit_rect(img5, Rect2i(0, 0, W, H), Vector2i((sn % 4) * W, (sn / 4) * H))
				sn += 1
			if st_img:
				st_img.save_png(OUT + "%s_stairs.png" % map)
			if st_top:
				st_top.save_png(OUT + "%s_stairs_top.png" % map)
		# 바깥: 맵 위에서 아래로 쏴서 땅(0.6m 아래)이 맞는 곳에서 사람 눈높이로 한 장씩
		if shots and out_mode:
			var os_img: Image = null
			var on := 0
			var space := (m as Node3D).get_world_3d().direct_space_state
			var orng := RandomNumberGenerator.new()
			orng.seed = 4242
			var tries := 0
			while on < 12 and tries < 600:
				tries += 1
				var gx := orng.randf_range(-70, 70)
				var gz := orng.randf_range(-70, 70)
				var q := PhysicsRayQueryParameters3D.create(Vector3(gx, 60, gz), Vector3(gx, -5, gz))
				var hit := space.intersect_ray(q)
				if hit.is_empty() or (hit["position"] as Vector3).y > 0.6:
					continue
				var cp2: Vector3 = hit["position"] + Vector3.UP * 1.7
				var ang := orng.randf() * TAU
				cam.global_position = cp2
				cam.look_at(cp2 + Vector3(cos(ang), -0.08, sin(ang)), Vector3.UP)
				mid.global_position = cp2 + Vector3(cos(ang), 0.5, sin(ang)) * 4.0
				await get_tree().process_frame
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img3 := get_viewport().get_texture().get_image()
				img3.convert(Image.FORMAT_RGB8)
				if os_img == null:
					os_img = Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
				os_img.blit_rect(img3, Rect2i(0, 0, W, H), Vector2i((on % 4) * W, (on / 4) * H))
				idx_log += "%s out cell%d pos=%s ang=%.2f\n" % [map, on, cp2, ang]
				on += 1
			if os_img:
				os_img.save_png(OUT + "%s_out.png" % map)
		var f := FileAccess.open(OUT + map + "_index.txt", FileAccess.WRITE)
		f.store_string(idx_log)
		m.queue_free()
		await get_tree().create_timer(0.4).timeout
	var rf := FileAccess.open(OUT + "report.txt", FileAccess.WRITE)
	rf.store_string(rep)
	print(rep)
	get_tree().quit()


## 이상한 부품 찾기
func _scan(map: String, b) -> String:
	var furn: Array = b.get_meta("dbg_furn", [])
	var out := "== %s parts=%d\n" % [map, furn.size()]
	var tall := {}
	for f in furn:
		var tsz: Vector3 = f[1]
		if tsz.y > 1.6 and minf(tsz.x, tsz.z) < 0.3:
			var tk := "%s/%s %.2fx%.2fx%.2f" % [f[4], f[5], tsz.x, tsz.y, tsz.z]
			tall[tk] = int(tall.get(tk, 0)) + 1
	if OS.get_cmdline_user_args().has("tall"):
		out += "tall: %s\n" % str(tall)
	var boxes: Array = []
	for f in furn:
		var c: Vector3 = f[0]
		var sz: Vector3 = f[1]
		var yaw: float = f[3]
		var ext := Vector3(absf(cos(yaw)) * sz.x + absf(sin(yaw)) * sz.z, sz.y, absf(sin(yaw)) * sz.x + absf(cos(yaw)) * sz.z) * 0.5
		boxes.append(AABB(c - ext, ext * 2.0))
	var floors: Array = [0.0, 0.06]
	for rr in b.debug_rooms:
		var fy: float = rr[1]
		for d in [0.0, -0.06, 0.06, -0.03, 0.03]:
			floors.append(fy + d)
	var floating := {}
	var sticks := {}
	var poles := {}
	for i in furn.size():
		var f = furn[i]
		var bb: AABB = boxes[i]
		var sz: Vector3 = f[1]
		var who: String = "%s/%s" % [f[4], f[5]]
		# 떠 있는지: 아래 바닥(층 높이 배수 근처)이나 다른 부품과 닿아 있지 않으면
		var bottom := bb.position.y
		var on_floor := false
		for fh in floors:
			if absf(bottom - fh) < 0.1:
				on_floor = true
		var touching := false
		var grown := bb.grow(0.04)
		for j in furn.size():
			if j != i and grown.intersects(boxes[j]):
				touching = true
				break
		if not on_floor and not touching and sz.y < 2.5:
			floating[who] = int(floating.get(who, 0)) + 1
			if int(floating[who]) <= 2:
				out += "  FLOAT %s c=%s size=%s bottom=%.2f\n" % [who, f[0], sz, bottom]
		# 얇은 막대: 두 변이 7cm 이하이고 한 변이 50cm 이상, 다른 부품에 안 닿음
		var dims := [sz.x, sz.y, sz.z]
		dims.sort()
		if dims[0] <= 0.07 and dims[1] <= 0.07 and dims[2] >= 0.5 and not touching:
			sticks[who] = int(sticks.get(who, 0)) + 1
		if dims[0] <= 0.07 and dims[1] <= 0.07 and sz.y >= 0.8:
			poles[who] = int(poles.get(who, 0)) + 1
	out += "floating: %s\n" % str(floating)
	out += "lonely sticks: %s\n" % str(sticks)
	out += "tall poles (all): %s\n" % str(poles)
	return out
