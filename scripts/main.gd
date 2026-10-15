extends Node3D
## 게임 한 판(스테이지)을 관리합니다.
## 1. LevelBuilder 로 도시 맵과 봉인석을 만든다
## 2. 술래가 다닐 길(내비게이션 메시)을 굽는다(bake)
## 3. 플레이어(고른 캐릭터), 동료 봇, 술래를 배치한다
## 4. 승리/패배를 판정하고 코인을 지급한다
## 5. 캐릭터 능력이 쓰는 기능(맵 물들이기, 랜덤 위치 등)을 제공한다
## 술래는 유령/도살자/역병의 쥐 중 랜덤 (SEEKER_TYPES)

const PlayerScene := preload("res://scenes/player.tscn")
const AllyScene := preload("res://scenes/ally.tscn")
const SeekerScene := preload("res://scenes/seeker.tscn")
const GeneratorScene := preload("res://scenes/generator.tscn")
const StructureBuilderScript := preload("res://scripts/structure_builder.gd")
## 술래 11종. 매 판 이 중 몇 종류가 랜덤으로 나오고, 유저에게는 알려주지 않음
const SEEKER_TYPES := {
	"ghost": preload("res://scripts/seeker_ghost.gd"),
	"butcher": preload("res://scripts/seeker_butcher.gd"),
	"rat": preload("res://scripts/seeker_rat.gd"),
	"spider": preload("res://scripts/seeker_spider.gd"),
	"mannequin": preload("res://scripts/seeker_mannequin.gd"),
	"hound": preload("res://scripts/seeker_hound.gd"),
	"puppeteer": preload("res://scripts/seeker_puppeteer.gd"),
	"witch": preload("res://scripts/seeker_witch.gd"),
	"psycho": preload("res://scripts/seeker_psycho.gd"),
	"executioner": preload("res://scripts/seeker_executioner.gd"),
	"diet": preload("res://scripts/seeker_diet.gd"),
}

## 스테이지별 술래 (1마리씩). 마지막 스테이지(안개 마녀)를 깨면 게임 클리어
const SEEKER_ORDER := ["rat", "ghost", "butcher", "puppeteer", "hound", "spider", "diet", "psycho", "executioner", "mannequin", "witch"]

## 맵 모양을 정하는 숫자. 바꾸면 다른 도시가 만들어져요.
const MAP_SEED := 2026

var player: Survivor
## 첫 번째 술래 (예전 코드 호환용). 전체 목록은 seekers
var seeker: Seeker
var seekers: Array[Seeker] = []
var survivors: Array[Survivor] = []
var generators: Array[Generator] = []

var mission_total := 3
var missions_done := 0
var player_rescues := 0
## 게임이 시작돼서 판정을 해도 되는지
var ready_to_play := false
## 카멜레온 맵 물들이기 남은 시간
var paint_time_left := 0.0
## 맵 목록. 새 맵을 만들면 여기에 한 줄 추가
const MAPS := {
	"city": {"name": "버려진 도시", "builder": preload("res://scripts/level_builder.gd")},
	"forest": {"name": "숲속 폐캠핑장", "builder": preload("res://scripts/forest_builder.gd")},
	"school": {"name": "밤의 폐교", "builder": preload("res://scripts/school_builder.gd")},
	"hospital": {"name": "폐병원", "builder": preload("res://scripts/hospital_builder.gd")},
}
## 이번 판 맵 이름 (HUD 표시용)
var map_name := ""
var map_id := ""
const AtmosphereScript := preload("res://scripts/atmosphere.gd")
## 테스트용: 특정 맵만 나오게 하고 싶으면 "city" / "forest"
var forced_map := ""
## 테스트용: 특정 술래만 나오게 하고 싶으면 "ghost" / "butcher" / "rat"
var forced_seeker_type := ""

var _round_over := false
var _ended := false
var _nav_region: NavigationRegion3D
var _builder: LevelBuilder
var _paint_original: Dictionary = {}
## 붕괴로 부술 수 있는 물체 → 위치 상자 (destroy_sphere 용)
var _aabb_cache: Dictionary = {}
## 가동 안 된 봉인석이 부서졌는지 (true 면 술래를 모두 쓰러뜨려야 클리어)
var seal_broken := false

## 탈출 단계 (봉인석을 모두 켜면 시작)
var escape_phase := false
var escape_left := 0.0
var exits: Array[Node3D] = []
var _reveal_timer := 0.0
## 판이 시작된 뒤 지난 시간, 술래 폭주 여부
var round_time := 0.0
var raged := false

@onready var hud: Hud = $HUD
@onready var world_env: WorldEnvironment = $WorldEnvironment


## 맵 모양을 정하는 난수 (멀티에서는 모두가 같은 씨앗을 써서 같은 맵이 만들어짐)
var level_rng := RandomNumberGenerator.new()
var _net_timer := 0.0


func _ready() -> void:
	# 화질: 계단 현상 줄이기 (MSAA 4배) + 살짝 선명하게
	get_viewport().msaa_3d = Viewport.MSAA_4X
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	add_to_group("game")
	randomize()
	if Net.in_match():
		level_rng.seed = int(Net.match_config["seed"])
		forced_map = str(Net.match_config["map"])
	else:
		level_rng.randomize()
		if forced_map == "" and SaveData.test_map != "":
			forced_map = SaveData.test_map
	world_env.environment.fog_density = GameConfig.num("view", "fog_density", 0.06)
	_build_level()
	AtmosphereScript.apply(self, map_id)  # 조명·안개·빛 번짐 (그래픽 품질에 따라)
	await _bake_navigation()
	_spawn_characters()
	if player:
		AtmosphereScript.add_motes(player, map_id)
	_setup_horror()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.setup(self)
	ready_to_play = true
	hud.show_message("[%s] 봉인석 %d개를 찾아 가동하세요! 발소리에 귀를 기울이세요" % [map_name, mission_total], 5.0)


func _unhandled_input(event: InputEvent) -> void:
	# 창 밖으로 나갔다 돌아오면 클릭해서 다시 마우스 잠금
	if event is InputEventMouseButton and event.pressed and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_update_horror(delta)
	if paint_time_left > 0.0:
		paint_time_left -= delta
		if paint_time_left <= 0.0:
			_restore_map_colors()
			hud.show_message("맵 색이 원래대로 돌아왔어요", 2.0)

	if not ready_to_play or _round_over:
		return
	round_time += delta
	if Net.is_client():
		return  # 판정·폭주·탈출은 방장 컴퓨터가 계산해서 알려 줌
	if not raged and round_time >= GameConfig.num("seeker", "rage_time", 600.0):
		_enrage_all("10분이 지났어요... 술래들이 폭주합니다!")
	_update_turncoat(delta)
	if escape_phase:
		_update_escape(delta)
		if _round_over:
			return
	# 판정: 맵 안에 남은 사람 기준 (탈출한 사람·술래로 변한 사람은 빠짐)
	var inside := survivors.filter(func(s: Survivor) -> bool: return not s.is_dead and not s.escaped and s.turned_seeker == null)
	var escaped_n := survivors.filter(func(s: Survivor) -> bool: return s.escaped).size()
	if escape_phase and escaped_n > 0 and inside.all(func(s: Survivor) -> bool: return s.is_frozen or s.chained_by != null):
		_finish_escape()  # 움직일 수 있는 사람이 모두 나감 → 남은 얼음 동료는 탈락
	elif inside.is_empty():
		_end_round(false, "모두 술래에게 잡혔어요...")
	elif inside.all(func(s: Survivor) -> bool: return s.is_frozen):
		_end_round(false, "모두 얼어버렸어요... 땡해줄 사람이 없어요!")
	elif inside.all(func(s: Survivor) -> bool: return s.is_frozen or s.chained_by != null):
		_end_round(false, "모두 사이코의 쇠사슬에 묶였어요...")


# ---------------------------------------------------------------- 맵 만들기

func _build_level() -> void:
	# NavigationRegion3D 아래에 있는 바닥/건물을 보고 "걸을 수 있는 길"을 계산합니다.
	_nav_region = NavigationRegion3D.new()
	_nav_region.name = "Level"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_max_climb = 0.25
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	_nav_region.navigation_mesh = nav_mesh
	add_child(_nav_region)

	# 맵: 매 판 랜덤 (도시 / 숲속 캠핑장)
	map_id = MAPS.keys()[randi() % MAPS.size()] if forced_map == "" else forced_map
	map_name = MAPS[map_id]["name"]
	_builder = (MAPS[map_id]["builder"] as GDScript).new()
	_builder.build(_nav_region, MAP_SEED)

	# 봉인석 (길 계산 전에 놓아야 술래가 봉인석을 피해 다님)
	mission_total = int(GameConfig.num("mission", "count", 3))
	var spots := _builder.generator_spots.duplicate()
	for i in range(spots.size() - 1, 0, -1):  # 섞기 (멀티에서도 똑같이)
		var j := level_rng.randi_range(0, i)
		var tmp = spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	for i in min(mission_total, spots.size()):
		var g := GeneratorScene.instantiate() as Generator
		_nav_region.add_child(g)
		g.position = spots[i]
		g.mission_completed.connect(_on_mission_completed)
		generators.append(g)
	mission_total = generators.size()


func _bake_navigation() -> void:
	await get_tree().physics_frame
	_clear_around_generators()
	# 추격전 구조물: 벽은 길 계산 전에, 문·판자·사물함은 길 계산 뒤에
	var structures := StructureBuilderScript.new()
	structures._builder = _builder
	if _builder.use_shacks:
		structures.build_shells(self, _builder, level_rng)
	# 지붕 위 등은 길 계산에서 뺌 (nav_ignore). 나머지 맵 물체만 길 계산에 씀
	var nm := _nav_region.navigation_mesh
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"navsrc"
	for child in _nav_region.get_children():
		if not child.has_meta("nav_ignore"):
			child.add_to_group(&"navsrc")
	await get_tree().physics_frame
	_nav_region.bake_navigation_mesh(false)
	await get_tree().physics_frame
	_push_navmesh()
	# 내비게이션 서버에 길 정보가 반영될 때까지 기다림
	var map := get_world_3d().navigation_map
	while NavigationServer3D.map_get_iteration_id(map) == 0:
		await get_tree().physics_frame
	# 길 정보가 실제로 쓸 수 있게 될 때까지 (최대 약 3초)
	var probe: Vector3 = _builder.survivor_spawns[0]
	for i in 180:
		if NavigationServer3D.map_get_closest_point(map, probe) != Vector3.ZERO:
			break
		await get_tree().physics_frame
	await get_tree().physics_frame
	structures._props.append_array(_builder.props)
	structures.spawn_props(self)


func _spawn_characters() -> void:
	var spawns := _builder.survivor_spawns
	if Net.in_match():
		_net_spawn_characters()
		return

	# 플레이어: 메뉴에서 고른 캐릭터
	player = PlayerScene.instantiate() as Survivor
	player.character_id = SaveData.selected_character
	player.cosmetics = SaveData.equipped.duplicate()
	player.display_name = "나"
	add_child(player)
	player.global_position = spawns[0]
	survivors.append(player)
	player.connect("notice", func(t: String) -> void: hud.show_message(t, 2.5))
	player.connect("flashed", hud.flash)

	# 동료 봇: 내가 고르지 않은 캐릭터들 (히든 캐릭터는 봇으로 나오지 않음)
	var others: Array = CharacterDB.ORDER.filter(func(id: String) -> bool:
		return id != SaveData.selected_character and not CharacterDB.is_hidden(id))
	others.shuffle()  # 매 판 다른 동료가 나오게
	var ally_count := int(GameConfig.num("ally", "count", 2))
	for i in min(ally_count, others.size(), spawns.size() - 1):
		var ally := AllyScene.instantiate() as Survivor
		ally.character_id = others[i]
		ally.display_name = "동료%d (%s)" % [i + 1, CharacterDB.get_info(others[i])["name"]]
		ally.name = "Ally%d" % (i + 1)
		add_child(ally)
		ally.global_position = spawns[i + 1]
		survivors.append(ally)

	for s in survivors:
		s.rescued.connect(_on_rescued)
		s.died.connect(_on_survivor_died.bind(s))

	# 술래: 스테이지 1~8은 쉬운 술래부터 1마리씩, 그다음부터는 서로 다른 종류로 seeker_count 마리 (랜덤)
	var types: Array = SEEKER_TYPES.keys()
	types.shuffle()
	var count := mini(int(GameConfig.num("seeker", "count", 2)), types.size())
	if SaveData.stage <= SEEKER_ORDER.size():
		types.erase(SEEKER_ORDER[SaveData.stage - 1])
		types.push_front(SEEKER_ORDER[SaveData.stage - 1])
		count = 1
	if forced_seeker_type != "":
		types.erase(forced_seeker_type)
		types.push_front(forced_seeker_type)
	for i in count:
		var seeker_type: String = types[i]
		var node := SeekerScene.instantiate()
		node.set_script(SEEKER_TYPES[seeker_type])
		var sk := node as Seeker
		sk.seeker_type = seeker_type
		sk.map_half_size = _builder.half - 3.0
		add_child(sk)
		sk.global_position = _builder.seeker_spawns[i]
		sk.killed.connect(_on_seeker_killed)
		seekers.append(sk)
	seeker = seekers[0]


# ---------------------------------------------------------------- 공포 연출

const SFX_DRONE := preload("res://audio/ambient_drone.wav")
const CREEPY_SOUNDS := [preload("res://audio/creak.wav"), preload("res://audio/whisper.wav")]

## 깜빡이는 조명들: [조명, 원래 밝기]
var _flicker_lights: Array = []
var _creepy_timer := 10.0


func _setup_horror() -> void:
	# 가로등·간판·모닥불 중 일부가 불규칙하게 깜빡임
	for l in _nav_region.find_children("*", "OmniLight3D", true, false):
		if randf() < GameConfig.num("horror", "flicker_ratio", 0.4):
			_flicker_lights.append([l, (l as OmniLight3D).light_energy])
	# 계속 낮게 깔리는 불길한 소리
	var drone := AudioStreamPlayer.new()
	drone.stream = SFX_DRONE
	drone.volume_db = GameConfig.num("horror", "drone_volume_db", -14.0)
	add_child(drone)
	drone.finished.connect(drone.play)
	drone.play()


func _update_horror(delta: float) -> void:
	for pair in _flicker_lights:
		var l: OmniLight3D = pair[0]
		if not is_instance_valid(l):
			continue
		if randf() < 0.08:  # 가끔 확 꺼졌다 켜짐
			l.light_energy = 0.0 if l.light_energy > 0.0 and randf() < 0.6 else pair[1] * randf_range(0.6, 1.2)
	# 가끔 근처 어딘가에서 쇠 긁는 소리나 속삭임
	_creepy_timer -= delta
	if _creepy_timer <= 0.0 and player and not player.is_dead:
		_creepy_timer = randf_range(GameConfig.num("horror", "creepy_min", 12.0), GameConfig.num("horror", "creepy_max", 25.0))
		var p := AudioStreamPlayer3D.new()
		p.stream = CREEPY_SOUNDS[randi() % CREEPY_SOUNDS.size()]
		p.max_distance = 40.0
		p.volume_db = -4.0
		add_child(p)
		var a := randf() * TAU
		p.global_position = player.global_position + Vector3(cos(a), 0.5, sin(a)) * randf_range(8.0, 18.0)
		p.play()
		p.finished.connect(p.queue_free)


# ---------------------------------------------------------------- 능력이 쓰는 기능

## 걸을 수 있는 바닥 중 랜덤 위치 (공간을 지배하는 자 순간이동)
func random_floor_point() -> Vector3:
	var map := get_world_3d().navigation_map
	var half: float = _builder.half - 3.0
	for i in 30:
		var lv: float = _builder.floor_levels[randi() % _builder.floor_levels.size()]
		var p := Vector3(randf_range(-half, half), lv + 0.3, randf_range(-half, half))
		var c := NavigationServer3D.map_get_closest_point(map, p)
		if absf(c.y - lv) < 1.0 and Vector2(c.x, c.z).distance_to(Vector2(p.x, p.z)) < 2.0 and reachable(c):
			return c
	return player.global_position


## 시작 지점에서 걸어서 갈 수 있는 곳인지 (지붕 위·막힌 방 제외)
func reachable(p: Vector3) -> bool:
	var map := get_world_3d().navigation_map
	var from: Vector3 = NavigationServer3D.map_get_closest_point(map, _builder.survivor_spawns[0])
	var path := NavigationServer3D.map_get_path(map, from, p, true)
	return path.size() > 0 and path[path.size() - 1].distance_to(p) < 1.0


## p 에서 가장 가까운 걸을 수 있는 바닥
func closest_floor_point(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, Vector3(p.x, 0.0, p.z))


## 카멜레온 맵 물들이기: duration 초 동안 맵 전체를 color 하나로
## (감지 불가 효과는 카멜레온 본인의 paint_time_left 로 따로 처리)
func paint_map(color: Color, duration: float) -> void:
	if paint_time_left <= 0.0:
		_paint_original.clear()
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(0.35)
		mat.roughness = 0.9
		for g in _builder.paintable:
			if is_instance_valid(g):
				_paint_original[g] = g.material_override
				g.material_override = mat
	paint_time_left = duration
	hud.show_message("카멜레온이 맵을 물들였어요! (%d초)" % int(duration), 3.0)


func _restore_map_colors() -> void:
	for g in _paint_original.keys():
		if is_instance_valid(g):
			g.material_override = _paint_original[g]
	_paint_original.clear()



# ---------------------------------------------------------------- 이벤트

func _on_mission_completed(g: Generator) -> void:
	missions_done += 1
	# 봉인석이 켜지면 술래들이 어느 봉인석인지 알고 그곳으로 몰려옴
	for node in get_tree().get_nodes_in_group("seeker"):
		(node as Seeker).alert_to(g.global_position)
	if missions_done < mission_total:
		say("봉인석 가동! (%d/%d) 술래가 그 위치를 알아챘어요!" % [missions_done, mission_total], 3.0)
		return
	# 모든 봉인석 완료 → 탈출 단계
	_start_escape()


# ---------------------------------------------------------------- 탈출 단계 / 폭주

func _enrage_all(text: String) -> void:
	raged = true
	for node in get_tree().get_nodes_in_group("seeker"):
		(node as Seeker).enrage()
	say(text, 4.0)
	hud.flash_red()


func _start_escape() -> void:
	escape_phase = true
	escape_left = GameConfig.num("escape", "time_limit", 180.0)
	for s in survivors:
		s.clear_ice_timer()  # 탈출 단계에서는 얼음 무제한
	_spawn_exits()
	if not raged:
		_enrage_all("모든 봉인석 가동! 탈출구가 열렸어요! 술래들이 폭주합니다!")
	say("모든 봉인석 가동! 탈출구 %d곳이 열렸어요. %d분 안에 탈출하세요!" % [exits.size(), int(escape_left / 60.0)], 5.0)
	if Net.is_host():
		Net.escape_started.rpc(exits.map(func(e): return e.global_position))
	_reveal_survivors()
	_reveal_timer = GameConfig.num("escape", "reveal_interval", 10.0)


## 폭주한 술래들이 생존자 위치를 알게 됨 (각자 가장 가까운 생존자)
func _reveal_survivors() -> void:
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		var best: Survivor = null
		var best_d := INF
		for s in survivors:
			if s.is_dead or s.escaped or s.is_frozen:
				continue
			var d := sk.global_position.distance_to(s.global_position)
			if d < best_d:
				best = s
				best_d = d
		if best:
			sk.alert_to(best.global_position)


func _update_escape(delta: float) -> void:
	escape_left -= delta
	_reveal_timer -= delta
	if _reveal_timer <= 0.0:
		_reveal_timer = GameConfig.num("escape", "reveal_interval", 10.0)
		_reveal_survivors()
	var r := GameConfig.num("escape", "exit_radius", 2.5)
	for s in survivors:
		if s.is_dead or s.escaped or s.is_frozen or s.chained_by:
			continue
		for e in exits:
			if Vector2(s.global_position.x, s.global_position.z).distance_to(Vector2(e.global_position.x, e.global_position.z)) < r:
				s.escape()
				if s == player:
					hud.show_message("탈출 성공! 동료들을 기다리는 중...", 3.0)
				if Net.is_host() or s != player:
					say("%s 탈출!" % _net_name(s), 3.0)
				break
	if escape_left <= 0.0:
		_finish_escape()


## 탈출 단계 끝: 못 나간 사람은 탈락. 한 명이라도 나갔으면 클리어
func _finish_escape() -> void:
	var escaped_n := 0
	for s in survivors:
		if s.escaped:
			escaped_n += 1
		elif not s.is_dead:
			s._kill()
	if escaped_n > 0:
		_end_round(true, "탈출 성공! (%d명 탈출)" % escaped_n)
	else:
		_end_round(false, "시간 안에 아무도 탈출하지 못했어요...")


## 맵 가장자리 서로 다른 변에 탈출구
func _spawn_exits() -> void:
	var half := _builder.half - 3.0
	var edges := [0, 1, 2, 3]
	edges.shuffle()
	for i in mini(int(GameConfig.num("escape", "exit_count", 2)), 4):
		var spot := Vector3.INF
		for tries in 30:
			var t := randf_range(-half + 8.0, half - 8.0)
			var p: Vector3 = [Vector3(t, 0, -half), Vector3(t, 0, half), Vector3(-half, 0, t), Vector3(half, 0, t)][edges[i]]
			var c := closest_floor_point(p)
			if c.y < 1.0 and Vector2(c.x, c.z).distance_to(Vector2(p.x, p.z)) < 4.0:
				spot = c
				break
		if spot == Vector3.INF:
			spot = random_floor_point()
		exits.append(_make_exit(spot))


func _make_exit(pos: Vector3) -> Node3D:
	# 멀리서는 안 보임: 작은 철문 + 약한 초록 불빛. 가까이(약 8m) 가야 글씨가 보이고,
	# 20m 안에서는 바람 새는 소리가 들려서 헤드셋으로 방향을 찾을 수 있음
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	# 바깥(맵 가장자리) 쪽을 등지게
	var out := Vector3(pos.x, 0, pos.z).normalized()
	root.rotation.y = atan2(out.x, out.z)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.24, 0.23)
	metal.metallic = 0.6
	metal.roughness = 0.5
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.2, 0.6, 0.3)
	glow.emission_enabled = true
	glow.emission = Color(0.2, 0.9, 0.4)
	glow.emission_energy_multiplier = 0.8
	for x in [-1.1, 1.1]:
		_exit_box(root, Vector3(x, 1.2, 0.6), Vector3(0.2, 2.4, 0.2), metal)
	_exit_box(root, Vector3(0, 2.45, 0.6), Vector3(2.4, 0.2, 0.2), metal)
	_exit_box(root, Vector3(0, 1.1, 0.7), Vector3(2.0, 2.2, 0.05), glow)  # 틈새로 새어 나오는 빛
	var light := OmniLight3D.new()
	light.light_color = Color(0.4, 1.0, 0.6)
	light.omni_range = 4.0
	light.light_energy = 1.2
	light.position = Vector3(0, 1.5, 0.2)
	root.add_child(light)
	var label := Label3D.new()
	label.text = "탈출구"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.pixel_size = 0.002
	label.font_size = 40
	label.outline_size = 10
	label.modulate = Color(0.5, 1.0, 0.6)
	label.position.y = 3.0
	label.visibility_range_end = GameConfig.num("escape", "label_distance", 8.0)
	root.add_child(label)
	if ResourceLoader.exists("res://audio/exit_wind.wav"):
		var hum := AudioStreamPlayer3D.new()
		hum.stream = load("res://audio/exit_wind.wav")
		hum.max_distance = GameConfig.num("escape", "sound_distance", 20.0)
		hum.unit_size = 4.0
		hum.position.y = 1.5
		root.add_child(hum)
		hum.finished.connect(hum.play)
		hum.play()
	return root


func _exit_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat
	m.position = pos
	parent.add_child(m)


## 히든 캐릭터의 붕괴로 술래가 죽었을 때. 모든 술래가 죽으면 클리어
func _on_seeker_killed(_sk: Seeker) -> void:
	if _round_over:
		return
	var alive := seekers.filter(func(x: Seeker) -> bool: return not x.is_killed)
	if not alive.is_empty():
		hud.show_message("술래 하나를 쓰러뜨렸어요! (남은 술래 %d)" % alive.size(), 3.0)
		return
	_round_over = true
	hud.show_message("모든 술래를 쓰러뜨렸어요!", 3.0)
	await get_tree().create_timer(2.5).timeout
	_end_round(true, "스테이지 클리어!")


## 봉인석 자리 주변(반경 4m)에 놓인 차·상자·나무 등을 치움 (봉인석과 겹치지 않게)
func _clear_around_generators() -> void:
	var radius := GameConfig.num("mission", "clear_radius", 4.0)
	for g in generators:
		var gp := g.global_position
		for child in _nav_region.get_children():
			if child == g or child.has_meta("indestructible") or not (child is Node3D) or not (child as Node3D).is_inside_tree():
				continue
			var aabb := _node_aabb(child)
			if aabb.size == Vector3.ZERO or aabb.end.y < 0.3:
				continue  # 바닥 장식(보도, 공원 바닥)은 그대로
			var nearest := Vector2(clampf(gp.x, aabb.position.x, aabb.end.x), clampf(gp.z, aabb.position.z, aabb.end.z))
			if nearest.distance_to(Vector2(gp.x, gp.z)) < radius:
				_nav_region.remove_child(child)
				child.queue_free()


## 노드와 자식 메시들을 모두 감싸는 월드 기준 상자 (붕괴·봉인석 정리에 사용)
func _node_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var meshes: Array = [node] + node.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		if m is MeshInstance3D and (m as Node).is_inside_tree():
			var box: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			result = box if first else result.merge(box)
			first = false
	return result


## 지형이 부서진 뒤 길 정보를 다시 계산 (붕괴 스킬)
func rebake_navigation() -> void:
	_nav_region.bake_navigation_mesh(false)
	_push_navmesh()


## Godot 4.5 에서는 다 만든 길 정보를 다시 넣어 줘야 내비게이션 서버에 반영됨
## (안 하면 술래·봇이 길을 못 찾고 제자리에 서 있음)
func _push_navmesh() -> void:
	var nm := _nav_region.navigation_mesh
	_nav_region.navigation_mesh = null
	_nav_region.navigation_mesh = nm


## 붕괴 구체: center 에서 반경 radius 안에 닿은 건물·나무·차·봉인석을 파괴
## (바닥과 바깥 울타리는 제외). 반환값: 부서진 물체들의 위치 목록 (파편 효과용)
func destroy_sphere(center: Vector3, radius: float) -> Array[Vector3]:
	if _aabb_cache.is_empty():
		_build_aabb_cache()
	var broken: Array[Vector3] = []
	var c2 := Vector2(center.x, center.z)
	for child in _aabb_cache.keys():
		if not is_instance_valid(child):
			_aabb_cache.erase(child)
			continue
		var hit := false
		if child is Light3D:
			var lp: Vector3 = (child as Node3D).global_position
			hit = Vector2(lp.x, lp.z).distance_to(c2) <= radius
		else:
			var aabb: AABB = _aabb_cache[child]
			var nearest := Vector2(clampf(c2.x, aabb.position.x, aabb.end.x), clampf(c2.y, aabb.position.z, aabb.end.z))
			hit = nearest.distance_to(c2) <= radius
		if not hit:
			continue
		_aabb_cache.erase(child)
		if child is Generator:
			_on_generator_destroyed(child)
		if not (child is Light3D):
			broken.append((child as Node3D).global_position)
		_nav_region.remove_child(child)
		child.queue_free()
	return broken


## 부술 수 있는 물체들의 위치 상자를 한 번만 계산해 둠 (매 프레임 계산하면 느림)
func _build_aabb_cache() -> void:
	for child in _nav_region.get_children():
		if child.has_meta("indestructible") or not (child is Node3D):
			continue
		if child is Light3D:
			_aabb_cache[child] = AABB()
			continue
		var aabb := _node_aabb(child)
		if aabb.size == Vector3.ZERO or aabb.end.y < 0.3:
			continue  # 바닥 장식(보도, 공원 바닥, 차선)은 그대로
		_aabb_cache[child] = aabb


## 붕괴로 봉인석이 부서짐: 아직 가동 안 된 봉인석이면 더 이상 봉인으로 클리어 불가 → 술래를 모두 쓰러뜨려야 함
func _on_generator_destroyed(g: Generator) -> void:
	generators.erase(g)
	if g.completed or seal_broken:
		return
	seal_broken = true
	hud.show_message("봉인석이 부서졌어요! 이제 술래를 모두 쓰러뜨려야 클리어할 수 있어요", 5.0)


func _in_corridor(p: Vector3, start: Vector3, dir: Vector3, length: float, half_w: float) -> bool:
	var rel := Vector3(p.x - start.x, 0, p.z - start.z)
	var along := rel.dot(dir)
	var side := absf(rel.cross(dir).y)
	return along >= 0.0 and along <= length and side <= half_w


## start 에서 dir 방향으로 맵 경계까지 거리
func _distance_to_edge(start: Vector3, dir: Vector3) -> float:
	var half := _builder.half
	var t := INF
	if absf(dir.x) > 0.001:
		t = minf(t, ((half if dir.x > 0.0 else -half) - start.x) / dir.x)
	if absf(dir.z) > 0.001:
		t = minf(t, ((half if dir.z > 0.0 else -half) - start.z) / dir.z)
	return maxf(t, 0.0)


## 멀티에서 모두에게 보일 이름 ("나" 대신 실제 이름)
func _net_name(s: Survivor) -> String:
	if Net.in_match() and s.net_slot >= 0:
		return str(Net.match_config["slots"][s.net_slot]["name"])
	return s.display_name


func _on_rescued(rescuer: Survivor, target: Survivor) -> void:
	if Net.in_match():
		if Net.is_host():
			say("땡! %s → %s 해동" % [_net_name(rescuer), _net_name(target)], 2.0)
		return
	if rescuer == player:
		player_rescues += 1
		hud.show_message("땡! %s 해동 성공" % target.display_name, 2.0)
	elif target == player and rescuer:
		hud.show_message("땡! %s(이)가 풀어줬어요" % rescuer.display_name, 2.0)


func _on_survivor_died(s: Survivor) -> void:
	s.stat_out_time = round_time
	if Net.in_match():
		if Net.is_host():
			say("%s(이)가 잡혔어요!" % _net_name(s), 2.5)
		return
	if s == player:
		hud.show_message("술래에게 잡혔어요! 동료들이 봉인석을 다 가동하면 함께 클리어돼요", 4.0)
	else:
		hud.show_message("%s(이)가 잡혔어요!" % s.display_name, 2.5)


# ---------------------------------------------------------------- 판 끝내기

## 결과 화면: 생존자별 기록 + MVP
func _mvp_score(s: Survivor) -> float:
	var alive_time := round_time if s.stat_out_time < 0.0 else s.stat_out_time
	return s.stat_rescues * 3.0 + s.stat_stages * 2.0 + s.stat_dodges * 2.0 + (4.0 if s.escaped else 0.0) + alive_time / 60.0


func _stats_text() -> String:
	var mvp: Survivor = null
	for s in survivors:
		if mvp == null or _mvp_score(s) > _mvp_score(mvp):
			mvp = s
	var lines: Array[String] = []
	var t := int(round_time)
	lines.append("플레이 시간 %d:%02d" % [t / 60, t % 60])
	for s in survivors:
		var alive_time := int(round_time if s.stat_out_time < 0.0 else s.stat_out_time)
		var result := "탈출" if s.escaped else ("탈락" if s.is_dead else "생존")
		var who := s.display_name if "(" in s.display_name else "%s(%s)" % [s.display_name, CharacterDB.get_info(s.character_id)["name"]]
		lines.append("%s%s  땡 %d · 봉인석 %.1f단계 · 회피 %d · 생존 %d:%02d · %s" % [
			"★ MVP  " if s == mvp else "", who,
			s.stat_rescues, s.stat_stages, s.stat_dodges, alive_time / 60, alive_time % 60, result])
	return "\n".join(lines)


## 결과 화면 표에 쓰는 생존자별 기록 (멀티에서는 방장이 만들어 모두에게 보냄)
func _stats_rows() -> Array:
	var mvp: Survivor = null
	for s in survivors:
		if mvp == null or _mvp_score(s) > _mvp_score(mvp):
			mvp = s
	var rows := []
	for i in survivors.size():
		var s: Survivor = survivors[i]
		var info: Dictionary = CharacterDB.get_info(s.character_id) if CharacterDB.ORDER.has(s.character_id) else {"name": "?", "color": Color.WHITE}
		rows.append({
			"idx": i, "name": s.display_name, "char": s.character_id, "color": info["color"], "cos": s.cosmetics,
			"rescues": s.stat_rescues, "stages": s.stat_stages, "dodges": s.stat_dodges,
			"alive": round_time if s.stat_out_time < 0.0 else s.stat_out_time,
			"result": "탈출" if s.escaped else ("탈락" if s.is_dead else "생존"),
			"mvp": s == mvp, "me": s == player,
		})
	return rows


func _end_round(win: bool, reason: String) -> void:
	if _ended:
		return
	_ended = true
	_round_over = true

	# 코인 계산: 이겨도 져도 한 만큼은 받음 → 여러 판 할수록 성장
	var mission_coins := missions_done * int(GameConfig.num("reward", "per_mission", 10))
	var rescue_coins := player_rescues * int(GameConfig.num("reward", "per_rescue", 5))
	var clear_coins := int(GameConfig.num("reward", "clear", 50)) if win else 0
	var total := mission_coins + rescue_coins + clear_coins
	SaveData.add_coins(total)
	var game_clear := win and SaveData.stage >= SEEKER_ORDER.size()
	if game_clear:
		# 마지막 술래까지 물리침 → 게임 클리어! 다음 판은 처음부터
		SaveData.clears += 1
		SaveData.best_stage = maxi(SaveData.best_stage, SEEKER_ORDER.size())
		SaveData.stage = 1
		reason = "모든 술래를 물리쳤어요! 게임 클리어!"
	elif win:
		SaveData.advance_stage()
	else:
		SaveData.stage = 1  # 지면 처음(스테이지 1, 첫 술래)부터 다시
	SaveData.save_game()

	var t := int(round_time)
	var details := "플레이 시간 %d:%02d\n봉인석 %d개 +%d · 땡 %d번 +%d · 클리어 보너스 +%d   (보유 코인 %d)" % [
		t / 60, t % 60, missions_done, mission_coins, player_rescues, rescue_coins, clear_coins, SaveData.coins]
	if game_clear:
		details += "\n\n축하해요! 11마리의 술래를 모두 물리쳤어요. (클리어 %d회)\n다음 판은 스테이지 1부터 다시 시작해요." % SaveData.clears
	elif win:
		details += "\n다음은 스테이지 %d / %d!" % [SaveData.stage, SEEKER_ORDER.size()]
	else:
		details += "\n스테이지 1부터 다시 시작해요."

	var rows := _stats_rows()
	if Net.is_host():
		Net.round_ended.rpc(win, reason, "플레이 시간 %d:%02d" % [t / 60, t % 60], rows)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_result(win, reason, details, rows, total)


# ================================================================ 멀티플레이 (scripts/autoload/net.gd 와 함께)

## 멀티: 자리(slot)대로 생존자 만들기. 내 자리 = 내가 조종, 나머지는 받은 위치를 따라가는 꼭두각시
## 방장 컴퓨터의 봇만 진짜 AI로 움직임
func _net_spawn_characters() -> void:
	var spawns := _builder.survivor_spawns
	var slots: Array = Net.match_config["slots"]
	var me := Net.my_slot()
	var host := Net.is_host()
	for i in slots.size():
		var sl: Dictionary = slots[i]
		var s: Survivor
		if i == me:
			s = PlayerScene.instantiate() as Survivor
			player = s
		else:
			s = AllyScene.instantiate() as Survivor
			s.net_owner = int(sl["peer"])
			s.net_puppet = (not host) or s.net_owner != 0
		s.character_id = str(sl["character"])
		s.cosmetics = sl.get("cos", {})
		s.display_name = "나" if i == me else str(sl["name"])
		s.net_slot = i
		s.name = "S%d" % i
		add_child(s)
		s.global_position = spawns[i % spawns.size()]
		survivors.append(s)
		s.rescued.connect(_on_rescued)
		s.died.connect(_on_survivor_died.bind(s))
	player.connect("notice", func(t: String) -> void: hud.show_message(t, 2.5))
	player.connect("flashed", hud.flash)

	var stage := int(Net.match_config.get("stage", 1))
	var types: Array = [SEEKER_ORDER[clampi(stage, 1, SEEKER_ORDER.size()) - 1]]
	for i in types.size():
		var seeker_type: String = types[i]
		var node := SeekerScene.instantiate()
		node.set_script(SEEKER_TYPES[seeker_type])
		var sk := node as Seeker
		sk.seeker_type = seeker_type
		sk.map_half_size = _builder.half - 3.0
		sk.net_puppet = not host
		sk.name = "K%d" % i
		add_child(sk)
		sk.global_position = _builder.seeker_spawns[i]
		sk.killed.connect(_on_seeker_killed)
		seekers.append(sk)
	seeker = seekers[0]
	# 술래 변신 모드: 처음엔 술래가 없고, 방장이 무작위 시간에 무작위 플레이어를 술래로 바꿈
	if str(Net.match_config.get("mode", "classic")) == "turncoat":
		for sk in seekers:
			sk.make_dormant()
		if host:
			_turn_left = 25.0 + _true_random(0, 45000) / 1000.0


## 술래 변신까지 남은 시간 (방장만 셈. 0 이하 = 이미 변했거나 기본 모드)
var _turn_left := 0.0


## 규칙성 없는 진짜 무작위 정수 [lo, hi] (운영체제의 암호용 난수 사용: 자리 순서·시간과 무관)
func _true_random(lo: int, hi: int) -> int:
	var bytes := Crypto.new().generate_random_bytes(8)
	var v := 0
	for b in bytes:
		v = ((v << 8) | b) & 0x3FFFFFFFFFFFFFFF
	return lo + v % (hi - lo + 1)


func _update_turncoat(delta: float) -> void:
	if _turn_left <= 0.0:
		return
	_turn_left -= delta
	if _turn_left > 0.0:
		return
	var slots: Array = Net.match_config["slots"]
	var cands: Array = []
	for i in survivors.size():
		var s := survivors[i]
		if int(slots[i]["peer"]) != 0 and not s.is_dead and not s.escaped:
			cands.append(i)
	if cands.is_empty():
		return
	# 후보 순서도 섞은 뒤 고름 (누가 먼저 들어왔는지·자리 번호와 관계없음)
	for k in range(cands.size() - 1, 0, -1):
		var j := _true_random(0, k)
		var t: int = cands[k]
		cands[k] = cands[j]
		cands[j] = t
	Net.turn_seeker.rpc(cands[_true_random(0, cands.size() - 1)])


## (모든 컴퓨터) slot 자리 플레이어가 술래로 변함
func net_turn_seeker(slot: int) -> void:
	if slot < 0 or slot >= survivors.size() or seekers.is_empty():
		return
	var s := survivors[slot]
	s.become_seeker(seekers[0])
	if s == player:
		hud.show_message("당신이 술래로 변했어요!  생존자에게 닿으면 잡아요  (Shift 달리기)", 5.0)
	else:
		hud.show_message("누군가 술래로 변했어요...!  도망쳐요!", 4.0)


# ---------------------------------------------------------------- 창문 파쿠르

const SFX_GLASS := preload("res://audio/glass_break.wav")

func level_windows() -> Array:
	return _builder.windows if _builder else []


## 창문 유리를 깸 (충돌 없애고, 그림 숨기고, 파편·소리). 멀티에서는 Net.window_broken 으로 모두에게
func break_window(index: int) -> void:
	var ws := level_windows()
	if index < 0 or index >= ws.size():
		return
	var w: Dictionary = ws[index]
	if w.get("broken", false):
		return
	w["broken"] = true
	(w["cs"] as CollisionShape3D).set_deferred("disabled", true)
	var c: Vector3 = w["c"]
	if w.has("mmi") and is_instance_valid(w["mmi"]):
		var mm := (w["mmi"] as MultiMeshInstance3D).multimesh
		mm.set_instance_transform(int(w["idx"]), Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), c))
	var pt := CPUParticles3D.new()
	pt.one_shot = true
	pt.emitting = true
	pt.amount = 40
	pt.lifetime = 1.2
	pt.explosiveness = 0.95
	pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	var sz: Vector3 = w["size"]
	pt.emission_box_extents = Vector3(sz.x * 0.45, sz.y * 0.45, 0.02)
	pt.direction = Vector3(0, 0, 1)
	pt.spread = 70.0
	pt.initial_velocity_min = 1.0
	pt.initial_velocity_max = 3.5
	pt.gravity = Vector3(0, -12, 0)
	pt.angle_max = 180.0
	pt.scale_amount_min = 0.4
	pt.scale_amount_max = 1.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.06, 0.005)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.7, 0.85, 0.95, 0.7)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.metallic = 0.6
	gm.roughness = 0.1
	bm.material = gm
	pt.mesh = bm
	add_child(pt)
	pt.global_transform = Transform3D(w["basis"], c)
	get_tree().create_timer(2.0).timeout.connect(pt.queue_free)
	var au := AudioStreamPlayer3D.new()
	au.stream = SFX_GLASS
	au.max_distance = 30.0
	au.unit_size = 5.0
	add_child(au)
	au.global_position = c
	au.play()
	au.finished.connect(au.queue_free)


## 화면 알림: 방장이면 모두에게도 보냄
func say(text: String, seconds: float) -> void:
	hud.show_message(text, seconds)
	if Net.is_host():
		Net.message.rpc(text, seconds)


func _physics_process(delta: float) -> void:
	if not Net.in_match() or not ready_to_play:
		return
	_net_timer -= delta
	if _net_timer > 0.0:
		return
	_net_timer = 0.05  # 초당 20번
	if Net.is_host():
		_net_send_snapshot()
	elif player:
		Net.player_state.rpc_id(1, player.net_slot, [player.global_position, player.body.rotation.y,
				Vector2(player.velocity.x, player.velocity.z).length(), player.net_flags()])


func _net_send_snapshot() -> void:
	var surv: Array = []
	for s in survivors:
		surv.append([s.global_position, s.body.rotation.y, Vector2(s.velocity.x, s.velocity.z).length(), s.net_flags(), s.thaw_progress])
	var sks: Array = []
	for sk in seekers:
		sks.append([sk.global_position, sk.rotation.y, sk.velocity, int(sk.state), sk.body.visible, sk.enraged, sk.attack_seq])
	var gens: Array = []
	for g in generators:
		gens.append(g.progress)
	Net.world_snapshot.rpc([surv, sks, gens, missions_done, escape_phase, escape_left, raged])


## (다른 사람 컴퓨터) 방장이 보낸 세계 상태 적용
func net_apply_snapshot(data: Array) -> void:
	if not ready_to_play:
		return
	var surv: Array = data[0]
	for i in mini(surv.size(), survivors.size()):
		var s := survivors[i]
		if s == player:
			continue
		var d: Array = surv[i]
		s.net_target(d[0], d[1], d[2], d[3], d[4])
	var sks: Array = data[1]
	for i in mini(sks.size(), seekers.size()):
		var d: Array = sks[i]
		seekers[i].net_target(d[0], d[1], d[2], d[3], d[4], d[5], d[6])
	var gens: Array = data[2]
	for i in mini(gens.size(), generators.size()):
		var g := generators[i]
		var p: float = gens[i]
		if absf(g.progress - p) > 0.0001:
			g.progress = p
			if p >= 0.999 and not g.completed:
				g.completed = true
				g._play_complete_sound()
			g._update_visual()
	missions_done = int(data[3])
	escape_phase = bool(data[4])
	escape_left = float(data[5])
	raged = bool(data[6])


## (방장 컴퓨터) 다른 사람이 보낸 자기 캐릭터 상태
func net_apply_player_state(sender: int, slot: int, data: Array) -> void:
	if slot < 0 or slot >= survivors.size():
		return
	var s := survivors[slot]
	if s.net_owner != sender:
		return
	s.net_target(data[0], data[1], data[2], data[3], s.thaw_progress)


## (내 컴퓨터) 방장이 알려 준 "내 캐릭터에 일어난 일"
func net_apply_to_me(method: String, args: Array) -> void:
	if player == null:
		return
	var real: Array = []
	for a in args:
		if a is Dictionary and a.has("seeker"):
			real.append(get_node_or_null(NodePath(str(a["seeker"]))))
		else:
			real.append(a)
	if method == "unfreeze":
		real = [player]
	player.callv(method, real)


## (방장 컴퓨터) 다른 사람의 미니게임 결과
func net_minigame_result(gen_index: int, slot: int, cleared: bool) -> void:
	if gen_index < 0 or gen_index >= generators.size() or slot < 0 or slot >= survivors.size():
		return
	var g := generators[gen_index]
	if cleared:
		g.clear_stage(survivors[slot])
	else:
		g.fail_stage(survivors[slot])


func net_seeker_knockback(index: int, dir: Vector3, stun: float) -> void:
	if index >= 0 and index < seekers.size() and is_instance_valid(seekers[index]):
		seekers[index].knockback(dir)
		seekers[index].set_meta("land_stun", stun)


func net_minigame_cancel(gen_index: int) -> void:
	if gen_index >= 0 and gen_index < generators.size():
		generators[gen_index].cancel_stage()


## (다른 사람 컴퓨터) 탈출 단계 시작
func net_client_escape(positions: Array) -> void:
	escape_phase = true
	for p in positions:
		exits.append(_make_exit(p))
	for s in survivors:
		s.clear_ice_timer()


## (다른 사람 컴퓨터) 판 끝
func net_client_round_end(win: bool, reason: String, details: String, rows: Array = []) -> void:
	if _ended:
		return
	_ended = true
	_round_over = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for r in rows:
		var i: int = r.get("idx", -1)
		r["me"] = i >= 0 and i < survivors.size() and survivors[i] == player
	hud.show_result(win, reason, details + "\n로비로 가서 준비하거나, 방장이 다음 판을 바로 시작할 수 있어요.", rows)


## (방장 컴퓨터) 누군가 나감 → 그 자리는 봇이 이어서 함
func net_peer_left(peer: int, who: String, to_lobby := false) -> void:
	for s in survivors:
		if s.net_owner == peer:
			s.net_owner = 0
			s.net_puppet = false
			if s.turned_seeker:  # 술래로 변한 사람이 나감 → 술래는 AI가 이어서 함
				s.turned_seeker.possessed_by = null
				s.turned_seeker._enter_patrol()
				s.set_physics_process(false)
				s.visible = false
	if not _ended:
		say("%s 님이 %s. 봇이 대신해요" % [who, "로비로 갔어요" if to_lobby else "나갔어요"], 3.0)
