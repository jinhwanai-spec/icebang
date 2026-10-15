extends Control
## 메인 메뉴 / 혼자 하기(캐릭터 선택) / 멀티플레이 로비 / 상점
## 화면은 모두 코드로 만들고, 색·모양은 아래 테마(_make_theme)에서 한 번에 정합니다.

const GAME_SCENE := "res://scenes/main.tscn"
const STAGES := 11

## 색 팔레트 (어두운 밤 + 얼음빛 포인트)
const C_BG := Color("0b0d12")
const C_PANEL := Color("12151c")
const C_PANEL_HI := Color("181c25")
const C_LINE := Color("262b36")
const C_TEXT := Color("e8ecf2")
const C_DIM := Color("8a93a3")
const C_ICE := Color("7fd6ff")
const C_BLOOD := Color("d9465a")

## 테스트용 선택지: 스테이지별 술래 이름 (main.gd SEEKER_ORDER 순서), 맵
const SEEKER_NAMES := ["거대 쥐", "유령", "도축자", "인형술사", "사냥개", "거미", "먹보 하마", "사이코", "처형인", "마네킹", "안개 마녀"]
const MAP_CHOICES := [["", "랜덤"], ["city", "버려진 도시"], ["forest", "숲속 폐캠핑장"], ["school", "밤의 폐교"], ["hospital", "폐병원"]]

## 상점에 파는 공통 능력: [능력 id, 이름, 설명]
const SHOP_ITEMS := [
	["noise", "소리 내기", "얼음 상태에서 F — 조준한 곳에 소리를 내서 술래를 유인 (쿨타임 100초)"],
	["emote", "이모티콘", "얼음 상태에서 G — 머리 위에 '메롱~'을 띄워 술래를 놀리기"],
]

var _pages := {}
var _selected := ""

# 메인
var _stage_label: Label
var _coin_label: Label
var _pips: HBoxContainer
# 혼자 하기
var _card_box: GridContainer
var _start_solo: Button
# 상점
var _shop_box: VBoxContainer
var _shop_coins: Label
# 멀티
var _mp_connect: Control
var _mp_lobby: Control
var _mp_name: LineEdit
var _mp_ip: LineEdit
var _mp_status: Label
var _mp_ip_box: Control
var _mp_ip_label: Label
var _mp_slots: HBoxContainer
var _mp_chars: GridContainer
var _mp_start: Button
var _mp_wait: Label
var _mp_ready: Button
var _mp_mode: Button


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_selected = SaveData.selected_character
	theme = _make_theme()
	_build_background()
	_pages["main"] = _build_main_page()
	_pages["solo"] = _build_solo_page()
	_pages["multi"] = _build_multi_page()
	_pages["shop"] = _build_shop_page()
	_pages["wardrobe"] = _build_wardrobe_page()
	Net.lobby_changed.connect(_refresh_multi)
	Net.status_changed.connect(_on_net_status)
	_show("multi" if Net.active else "main")
	if CrashLog.crashed_last_time:
		_crash_notice()


func _show(page: String) -> void:
	for k in _pages:
		(_pages[k] as Control).visible = k == page
	match page:
		"main":
			_refresh_main()
		"solo":
			_refresh_cards()
		"shop":
			_refresh_shop()
		"wardrobe":
			_refresh_wardrobe()
		"multi":
			_refresh_multi()


# ================================================================ 버그 신고

func _on_bug_report() -> void:
	var path := CrashLog.make_report("메뉴에서 버그 신고")
	_notice("버그 리포트를 저장했어요", "파일 위치를 클립보드에 복사했어요.\n%s\n\n이 파일(+같은 이름의 사진)을 개발자에게 보내 주세요." % ProjectSettings.globalize_path(path))


## 지난번에 게임이 갑자기 꺼졌을 때 한 번 안내
func _crash_notice() -> void:
	CrashLog.crashed_last_time = false
	_notice("지난번에 게임이 갑자기 꺼졌어요", "그때의 기록으로 버그 리포트를 만들 수 있어요.", "리포트 만들기", func() -> void:
		var path := CrashLog.make_report("지난 실행 비정상 종료")
		CrashLog.open_report_folder()
		DisplayServer.clipboard_set(ProjectSettings.globalize_path(path)))


func _notice(title: String, body: String, action := "", on_action := Callable()) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var card := _card()
	dim.add_child(card)
	card.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	v.add_child(_label(title, 22, C_TEXT))
	var b := _label(body, 15, C_DIM)
	b.custom_minimum_size.x = 460
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	if action != "":
		row.add_child(_button(action, func() -> void:
			on_action.call()
			dim.queue_free()))
	row.add_child(_button("폴더 열기", CrashLog.open_report_folder))
	row.add_child(_button("닫기", dim.queue_free))


# ================================================================ 메인

func _build_main_page() -> Control:
	var page := _page()
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 420
	col.add_theme_constant_override("separation", 0)
	_center(page).add_child(col)

	var title := _label("얼음땡", 84, C_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := _label("봉 인 의   밤", 26, C_ICE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_gap(14))
	var tag := _label("소리를 듣는 술래를 피해 봉인석을 켜고 탈출하세요", 15, C_DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	col.add_child(_gap(34))

	# 진행 상황: 스테이지 점 11개 + 코인
	var prog := _card()
	col.add_child(prog)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	prog.add_child(pv)
	var top := HBoxContainer.new()
	pv.add_child(top)
	_stage_label = _label("", 16, C_TEXT)
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_stage_label)
	_coin_label = _label("", 16, Color("ffd36b"))
	top.add_child(_coin_label)
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 6)
	pv.add_child(_pips)
	col.add_child(_gap(22))

	var solo := _button("혼자 하기", _show.bind("solo"), true)
	col.add_child(solo)
	col.add_child(_gap(10))
	col.add_child(_button("멀티플레이", _show.bind("multi"), true))
	col.add_child(_gap(10))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var shop := _button("능력 상점", _show.bind("shop"))
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(shop)
	var ward := _button("치장 상점", _show.bind("wardrobe"))
	ward.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(ward)
	var quit := _button("종료", func() -> void: get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(quit)

	# 아래 구석: 테스트용 버튼 (작게)
	var foot := HBoxContainer.new()
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_left = 14
	foot.offset_bottom = -12
	foot.add_theme_constant_override("separation", 6)
	page.add_child(foot)
	if GameConfig.flag("debug", "test_coins_button", true):
		foot.add_child(_text_button("+100 코인 (테스트)", _on_test_coins))
	foot.add_child(_text_button("기록 초기화", _on_reset))
	foot.add_child(_text_button("버그 신고 (F8)", _on_bug_report))
	# 그래픽 품질 (높음/낮음) 바꾸기
	var gfx := _text_button("", func() -> void: pass)
	var gfx_text := func() -> void: gfx.text = "그래픽: %s" % ("높음" if SaveData.high_graphics() else "낮음 (가벼움)")
	gfx_text.call()
	gfx.pressed.connect(func() -> void:
		SaveData.graphics = "low" if SaveData.high_graphics() else "high"
		SaveData.save_game()
		gfx_text.call())
	foot.add_child(gfx)
	return page


func _refresh_main() -> void:
	var st := clampi(SaveData.stage, 1, STAGES)
	_stage_label.text = "스테이지 %d / %d" % [st, STAGES] + ("   ·   클리어 %d회" % SaveData.clears if SaveData.clears > 0 else "")
	_coin_label.text = "● %d" % SaveData.coins
	for c in _pips.get_children():
		c.queue_free()
	for i in STAGES:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(0, 6)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(3)
		sb.bg_color = C_ICE if i < st - 1 else (C_TEXT if i == st - 1 else C_LINE)
		pip.add_theme_stylebox_override("panel", sb)
		_pips.add_child(pip)


# ================================================================ 혼자 하기 (캐릭터 선택)

func _build_solo_page() -> Control:
	var page := _page()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_center(page).add_child(col)
	col.add_child(_header("캐릭터 선택", "혼자 하기 · 빈 자리는 봇 동료 3명이 채워요"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1180, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_card_box = GridContainer.new()
	_card_box.columns = 5
	_card_box.add_theme_constant_override("h_separation", 12)
	_card_box.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_card_box)
	col.add_child(_test_pickers())
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var back := _button("뒤로", _show.bind("main"))
	back.custom_minimum_size.x = 180
	row.add_child(back)
	_start_solo = _button("이 캐릭터로 시작", _on_start, true)
	_start_solo.custom_minimum_size.x = 280
	row.add_child(_start_solo)
	return page


func _refresh_cards() -> void:
	for child in _card_box.get_children():
		child.queue_free()
	for id in CharacterDB.ORDER:
		var info := CharacterDB.get_info(id)
		var chosen: bool = id == _selected
		var card := Button.new()
		card.custom_minimum_size = Vector2(224, 300)
		card.toggle_mode = true
		card.button_pressed = chosen
		card.pressed.connect(_on_pick.bind(id))
		var sb := _box(C_PANEL_HI if chosen else C_PANEL, info["color"] if chosen else C_LINE, 2 if chosen else 1, 12)
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			card.add_theme_stylebox_override(s, sb if s != "hover" or chosen else _box(C_PANEL_HI, C_DIM, 1, 12))
		_card_box.add_child(card)

		var m := MarginContainer.new()
		m.set_anchors_preset(Control.PRESET_FULL_RECT)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 14)
		card.add_child(m)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 6)
		m.add_child(v)
		var head := HBoxContainer.new()
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(head)
		var dot := _dot(info["color"], 14)
		head.add_child(dot)
		head.add_child(_gap_h(8))
		var nm := _label(info["name"], 18, C_TEXT)
		head.add_child(nm)
		if CharacterDB.is_hidden(id):
			head.add_child(_label("  히든", 12, C_BLOOD))
		v.add_child(_gap(4))
		for slot in range(1, CharacterDB.slot_count(id) + 1):
			var cd := CharacterDB.cooldown(id, slot)
			var key: String = ["R", "T", "Y"][slot - 1]
			var h := _label("%s  %s%s" % [key, info["ability_%d" % slot], "" if cd < 2.0 else "  · %d초" % int(cd)], 13, (info["color"] as Color).lightened(0.35))
			v.add_child(h)
			var d := _label(info["ability_%d_desc" % slot], 12, C_DIM)
			d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			d.custom_minimum_size.x = 190
			v.add_child(d)
		for c in v.get_children():
			if c is Control:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## 테스트용: 스테이지(술래)와 맵을 직접 고르기
func _test_pickers() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label("스테이지", 14, C_DIM))
	var st := OptionButton.new()
	for i in SEEKER_NAMES.size():
		st.add_item("%d. %s" % [i + 1, SEEKER_NAMES[i]], i)
	st.select(clampi(SaveData.stage, 1, STAGES) - 1)
	st.item_selected.connect(func(i: int) -> void:
		SaveData.stage = i + 1
		SaveData.save_game()
		_refresh_main())
	row.add_child(st)
	row.add_child(_gap_h(16))
	row.add_child(_label("맵", 14, C_DIM))
	var mp := OptionButton.new()
	for i in MAP_CHOICES.size():
		mp.add_item(MAP_CHOICES[i][1], i)
		if MAP_CHOICES[i][0] == SaveData.test_map:
			mp.select(i)
	mp.item_selected.connect(func(i: int) -> void: SaveData.test_map = MAP_CHOICES[i][0])
	row.add_child(mp)
	return row


func _on_pick(id: String) -> void:
	_selected = id
	_refresh_cards()


func _on_start() -> void:
	SaveData.selected_character = _selected
	SaveData.save_game()
	get_tree().change_scene_to_file(GAME_SCENE)


# ================================================================ 멀티플레이

func _build_multi_page() -> Control:
	var page := _page()
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 820
	col.add_theme_constant_override("separation", 18)
	_center(page).add_child(col)
	col.add_child(_header("멀티플레이", "친구와 최대 4명 · 빈 자리는 봇이 채워요"))

	# --- 1) 접속 전: 이름 + 방 만들기 / 참가하기
	_mp_connect = VBoxContainer.new()
	(_mp_connect as VBoxContainer).add_theme_constant_override("separation", 14)
	col.add_child(_mp_connect)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	_mp_connect.add_child(name_row)
	name_row.add_child(_field_label("내 이름"))
	_mp_name = LineEdit.new()
	_mp_name.text = "플레이어%d" % (randi() % 90 + 10)
	_mp_name.max_length = 12
	_mp_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_mp_name)

	var two := HBoxContainer.new()
	two.add_theme_constant_override("separation", 14)
	_mp_connect.add_child(two)
	var host_card := _card()
	host_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	two.add_child(host_card)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	host_card.add_child(hv)
	hv.add_child(_label("방 만들기", 22, C_TEXT))
	var hd := _label("내가 방장이 돼요. 화면에 나오는 IP를 친구에게 알려 주세요.", 14, C_DIM)
	hd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hd.custom_minimum_size.y = 44
	hv.add_child(hd)
	hv.add_child(_button("방 만들기", func() -> void: Net.host(_mp_name.text), true))

	var join_card := _card()
	join_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	two.add_child(join_card)
	var jv := VBoxContainer.new()
	jv.add_theme_constant_override("separation", 10)
	join_card.add_child(jv)
	jv.add_child(_label("참가하기", 22, C_TEXT))
	_mp_ip = LineEdit.new()
	_mp_ip.text = "127.0.0.1"
	_mp_ip.placeholder_text = "방장 IP (예: 192.168.0.5)"
	_mp_ip.custom_minimum_size.y = 44
	jv.add_child(_mp_ip)
	jv.add_child(_button("참가하기", func() -> void: Net.join(_mp_ip.text, _mp_name.text)))

	var hint := _label("같은 컴퓨터에서 창 2개로 테스트할 때는 IP를 127.0.0.1 로 두세요.", 13, C_DIM)
	_mp_connect.add_child(hint)

	# --- 2) 접속 후: 로비
	_mp_lobby = VBoxContainer.new()
	(_mp_lobby as VBoxContainer).add_theme_constant_override("separation", 14)
	col.add_child(_mp_lobby)
	_mp_ip_box = _card()
	_mp_lobby.add_child(_mp_ip_box)
	var ipv := HBoxContainer.new()
	_mp_ip_box.add_child(ipv)
	ipv.add_child(_label("친구에게 알려 줄 IP   ", 14, C_DIM))
	_mp_ip_label = _label("", 18, C_ICE)
	_mp_ip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ipv.add_child(_mp_ip_label)
	var copy := _text_button("복사", func() -> void: DisplayServer.clipboard_set(_mp_ip_label.text.split("   ")[0]))
	ipv.add_child(copy)

	_mp_slots = HBoxContainer.new()
	_mp_slots.add_theme_constant_override("separation", 12)
	_mp_lobby.add_child(_mp_slots)
	_mp_lobby.add_child(_test_pickers())  # 방장이 고른 스테이지·맵으로 시작

	_mp_lobby.add_child(_label("내 캐릭터 고르기", 16, C_DIM))
	_mp_chars = GridContainer.new()
	_mp_chars.columns = 5
	_mp_chars.add_theme_constant_override("h_separation", 8)
	_mp_chars.add_theme_constant_override("v_separation", 8)
	_mp_lobby.add_child(_mp_chars)

	# --- 아래: 상태 + 버튼
	_mp_status = _label("", 14, C_DIM)
	_mp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mp_status)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var back := _button("방 나가기", _leave_multi)
	back.custom_minimum_size.x = 180
	row.add_child(back)
	_mp_mode = _button("", func() -> void: Net.toggle_mode())
	_mp_mode.custom_minimum_size.x = 330
	_mp_mode.tooltip_text = "술래 변신: AI 술래 없이 시작하고, 판 중간에 무작위 플레이어 한 명이 갑자기 술래로 변해요"
	row.add_child(_mp_mode)
	_mp_start = _button("게임 시작", func() -> void: Net.start_match(), true)
	_mp_start.custom_minimum_size.x = 280
	row.add_child(_mp_start)
	_mp_ready = _button("준비 완료", func() -> void: Net.set_ready(not Net.is_ready(Net.my_id())), true)
	_mp_ready.custom_minimum_size.x = 220
	row.add_child(_mp_ready)
	_mp_wait = _label("방장이 시작하길 기다리는 중...", 16, C_DIM)
	row.add_child(_mp_wait)
	return page


func _on_net_status(text: String) -> void:
	if _mp_status:
		_mp_status.text = text


func _leave_multi() -> void:
	Net.leave()
	_mp_status.text = ""
	_show("main")


func _refresh_multi() -> void:
	if _mp_slots == null:
		return
	var in_lobby := Net.active and not Net.players.is_empty()
	_mp_connect.visible = not Net.active
	_mp_lobby.visible = in_lobby
	_mp_start.visible = Net.is_host()
	_mp_mode.visible = in_lobby
	_mp_mode.disabled = not Net.is_host()
	_mp_mode.text = "방식: %s" % Net.MODE_NAMES.get(Net.match_mode, "")
	_mp_start.disabled = not (Net.all_picked() and Net.all_ready())
	if not Net.all_picked():
		_mp_start.text = "모두 캐릭터를 골라야 해요"
	elif not Net.all_ready():
		_mp_start.text = "모두 준비하길 기다리는 중"
	else:
		_mp_start.text = "게임 시작"
	var me_ready := Net.is_ready(Net.my_id())
	var picked := str(Net.players.get(Net.my_id(), {}).get("character", "")) != ""
	_mp_ready.visible = in_lobby and not Net.is_host()
	_mp_ready.disabled = not picked
	_mp_ready.text = "준비 취소" if me_ready else ("준비 완료" if picked else "캐릭터를 먼저 골라요")
	_mp_wait.visible = in_lobby and not Net.is_host()
	_mp_wait.text = "방장이 아직 게임 화면에 있어요..." if Net.host_in_game() else ("방장이 시작하길 기다리는 중..." if me_ready else "")
	_mp_ip_box.visible = Net.is_host()
	var ips := Net.local_ips()
	_mp_ip_label.text = "   ".join(ips) if not ips.is_empty() else "(IP를 찾지 못했어요)"

	# 참가자 칸 4개
	for c in _mp_slots.get_children():
		c.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	var taken := {}
	for i in Net.MAX_PLAYERS:
		var card := _card()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 92
		_mp_slots.add_child(card)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		card.add_child(v)
		if i < ids.size():
			var pid: int = ids[i]
			var p: Dictionary = Net.players[pid]
			var cid: String = p["character"]
			if cid != "":
				taken[cid] = pid
			var head := HBoxContainer.new()
			v.add_child(head)
			var nm := _label(str(p["name"]), 18, C_TEXT)
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nm.clip_text = true
			head.add_child(nm)
			if pid == 1:
				head.add_child(_label("방장", 12, C_ICE))
			elif Net.is_ready(pid):
				head.add_child(_label("준비 완료", 12, Color(0.45, 1.0, 0.6)))
			else:
				head.add_child(_label("준비 중", 12, C_DIM))
			var crow := HBoxContainer.new()
			v.add_child(crow)
			if cid != "":
				crow.add_child(_dot(CharacterDB.get_info(cid)["color"], 12))
				crow.add_child(_gap_h(6))
				crow.add_child(_label(CharacterDB.get_info(cid)["name"], 14, C_TEXT))
			else:
				crow.add_child(_label("캐릭터 고르는 중...", 14, C_DIM))
			if pid == Net.my_id():
				v.add_child(_label("나", 12, C_ICE))
				_box_override(card, _box(C_PANEL_HI, C_ICE, 2, 12))
		else:
			v.add_child(_label("빈 자리", 18, C_DIM))
			v.add_child(_label("봇이 채워요", 13, C_LINE.lightened(0.3)))

	# 캐릭터 고르기 칩 (다른 사람이 고른 건 못 고름)
	for c in _mp_chars.get_children():
		c.queue_free()
	for id in CharacterDB.ORDER:
		if CharacterDB.is_hidden(id):
			continue
		var info := CharacterDB.get_info(id)
		var mine: bool = taken.get(id, -1) == Net.my_id()
		var other: bool = taken.has(id) and not mine
		var b := Button.new()
		b.text = info["name"]
		b.custom_minimum_size = Vector2(156, 44)
		b.disabled = other
		b.add_theme_font_size_override("font_size", 15)
		b.icon = _dot_texture(info["color"])
		var border: Color = info["color"] if mine else C_LINE
		b.add_theme_stylebox_override("normal", _box(C_PANEL_HI if mine else C_PANEL, border, 2 if mine else 1, 10))
		b.add_theme_stylebox_override("hover", _box(C_PANEL_HI, info["color"], 1, 10))
		b.add_theme_stylebox_override("disabled", _box(C_BG, C_BG, 1, 10))
		b.pressed.connect(func() -> void: Net.pick_character(id))
		_mp_chars.add_child(b)


# ================================================================ 상점

func _build_shop_page() -> Control:
	var page := _page()
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 640
	col.add_theme_constant_override("separation", 14)
	_center(page).add_child(col)
	col.add_child(_header("상점", "얼음 상태에서 쓰는 공통 능력을 코인으로 해금해요"))
	_shop_coins = _label("", 18, Color("ffd36b"))
	col.add_child(_shop_coins)
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 10)
	col.add_child(_shop_box)
	var back := _button("뒤로", _show.bind("main"))
	col.add_child(back)
	return page


func _refresh_shop() -> void:
	_shop_coins.text = "보유 코인  ● %d" % SaveData.coins
	for child in _shop_box.get_children():
		child.queue_free()
	for item in SHOP_ITEMS:
		var id: String = item[0]
		var card := _card()
		_shop_box.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(_label(item[1], 20, C_TEXT))
		var d := _label(item[2], 13, C_DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(d)
		var btn: Button
		if SaveData.has_ability(id):
			btn = _button("보유 중", func() -> void: pass)
			btn.disabled = true
		else:
			btn = _button("● %d" % SaveData.price_of(id), _on_buy.bind(id), true)
			btn.disabled = SaveData.coins < SaveData.price_of(id)
		btn.custom_minimum_size = Vector2(140, 48)
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(btn)


# ================================================================ 치장 상점 (눈·머리·옷·장신구)

var _w_slot := "eyes"
var _w_try := {}            # 미리 입어 보는 중인 조합
var _w_pick := ""           # 지금 고른 아이템
var _w_grid: GridContainer
var _w_coins: Label
var _w_tabs: HBoxContainer
var _w_info: Label
var _w_action: Button
var _w_char: OptionButton
var _w_view: SubViewport
var _w_body: ClayBody
var _w_pivot: Node3D
var _w_drag := false
# 이모트 탭
var _w_ebox: VBoxContainer
var _w_ecats: HBoxContainer
var _w_eslots: GridContainer
var _w_ecat := ""           # "" = 전체
var _w_eslot := 0           # 장착할 칸 (0~9 = 숫자키 1~0)
var _w_epick := ""          # 미리 보는 이모트
var _w_etime := 0.0


func _build_wardrobe_page() -> Control:
	var page := _page()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	_center(page).add_child(col)
	col.add_child(_header("치장 상점", "코인으로 눈·머리·옷·장신구·이모트를 사요 · 이모트는 숫자키 1~0 칸에 장착"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)

	# 왼쪽: 3D 미리보기 (마우스로 끌어서 돌리기)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	var pv := _card()
	left.add_child(pv)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(380, 470)
	svc.stretch = true
	pv.add_child(svc)
	_w_view = SubViewport.new()
	_w_view.own_world_3d = true
	_w_view.transparent_bg = true
	_w_view.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_w_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.75)
	env.environment.ambient_light_energy = 0.7
	_w_view.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.2, 4.0)
	cam.fov = 38
	_w_view.add_child(cam)
	cam.look_at(Vector3(0, 1.05, 0))
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.2
	key.shadow_enabled = true
	_w_view.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, -1.5)
	rim.light_color = Color(0.5, 0.8, 1.0)
	rim.light_energy = 2.0
	rim.omni_range = 5.0
	_w_view.add_child(rim)
	var disc := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.8
	fm.bottom_radius = 0.85
	fm.height = 0.06
	disc.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.16, 0.19, 0.26)
	disc.material_override = fmat
	disc.position.y = -0.03
	_w_view.add_child(disc)
	_w_pivot = Node3D.new()
	_w_view.add_child(_w_pivot)
	svc.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_w_drag = (e as InputEventMouseButton).pressed
		elif e is InputEventMouseMotion and _w_drag:
			_w_pivot.rotate_y((e as InputEventMouseMotion).relative.x * 0.012))
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 8)
	left.add_child(crow)
	crow.add_child(_label("캐릭터", 14, C_DIM))
	_w_char = OptionButton.new()
	_w_char.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in CharacterDB.ORDER:
		_w_char.add_item(CharacterDB.get_info(id)["name"])
	_w_char.item_selected.connect(func(_i: int) -> void: _w_rebuild())
	crow.add_child(_w_char)
	_w_info = _label("", 15, C_TEXT)
	_w_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_w_info.custom_minimum_size = Vector2(380, 44)
	left.add_child(_w_info)
	_w_action = _button("", _on_wardrobe_action, true)
	left.add_child(_w_action)

	# 오른쪽: 칸 탭 + 아이템 목록
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var top := HBoxContainer.new()
	right.add_child(top)
	_w_tabs = HBoxContainer.new()
	_w_tabs.add_theme_constant_override("separation", 8)
	_w_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_w_tabs)
	_w_coins = _label("", 18, Color("ffd36b"))
	top.add_child(_w_coins)
	# 이모트 탭에서만 보이는 줄: 분류 버튼 + 숫자키 칸 10개
	_w_ebox = VBoxContainer.new()
	_w_ebox.add_theme_constant_override("separation", 8)
	right.add_child(_w_ebox)
	_w_ecats = HBoxContainer.new()
	_w_ecats.add_theme_constant_override("separation", 8)
	_w_ebox.add_child(_w_ecats)
	_w_eslots = GridContainer.new()
	_w_eslots.columns = 5
	_w_eslots.add_theme_constant_override("h_separation", 6)
	_w_eslots.add_theme_constant_override("v_separation", 6)
	_w_ebox.add_child(_w_eslots)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 480)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_w_grid = GridContainer.new()
	_w_grid.columns = 4
	_w_grid.add_theme_constant_override("h_separation", 8)
	_w_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_w_grid)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	col.add_child(bottom)
	bottom.add_child(_button("뒤로", func() -> void:
		_w_try = {}
		_show("main")))
	bottom.add_child(_text_button("입어 본 것 되돌리기", func() -> void:
		_w_try = SaveData.equipped.duplicate()
		_w_pick = ""
		_refresh_wardrobe()))
	return page


func _process(delta: float) -> void:
	if _w_body and is_instance_valid(_w_body) and _pages.has("wardrobe") and (_pages["wardrobe"] as Control).visible:
		if _w_slot == "emote" and _w_epick != "":
			# 이모트 미리보기: 얼굴(또는 엉덩이)이 카메라 쪽, 끝나면 반복
			var e := SaveData.emote_row(_w_epick)
			if not _w_drag:
				_w_pivot.rotation.y = lerp_angle(_w_pivot.rotation.y, PI if (not e.is_empty() and e[3] == "back") else 0.0, delta * 4.0)
			_w_etime += delta
			if not e.is_empty() and _w_etime > float(e[2]) + 0.6:
				_w_etime = 0.0
				_w_body.emote = ""
				_w_body.animate(delta, 0.0, false)
				_w_body.emote = _w_epick
		elif not _w_drag:
			_w_pivot.rotate_y(delta * 0.35)
		_w_body.animate(delta, 0.0, false)


func _refresh_wardrobe() -> void:
	if _w_try.is_empty():
		_w_try = SaveData.equipped.duplicate()
	var ci := CharacterDB.ORDER.find(SaveData.selected_character)
	if _w_char.selected < 0:
		_w_char.select(maxi(0, ci))
	_w_coins.text = "● %d" % SaveData.coins
	for c in _w_tabs.get_children():
		c.queue_free()
	for slot in Cosmetics.SLOTS:
		var on: bool = slot == _w_slot
		var owned := 0
		var all := Cosmetics.items_in(slot)
		for it in all:
			if SaveData.owns_cos(it[0]):
				owned += 1
		var b := _button("%s  %d/%d" % [Cosmetics.SLOT_NAMES[slot], owned, all.size()], func() -> void:
			_w_slot = slot
			_w_epick = ""
			_refresh_wardrobe(), on)
		b.custom_minimum_size = Vector2(118, 42)
		_w_tabs.add_child(b)
	var eown := 0
	for e in Survivor.EMOTES:
		if SaveData.owns_emote(e[0]):
			eown += 1
	var eb := _button("이모트  %d/%d" % [eown, Survivor.EMOTES.size()], func() -> void:
		_w_slot = "emote"
		_w_pick = ""
		_refresh_wardrobe(), _w_slot == "emote")
	eb.custom_minimum_size = Vector2(118, 42)
	_w_tabs.add_child(eb)
	for c in _w_grid.get_children():
		c.queue_free()
	_w_ebox.visible = _w_slot == "emote"
	if _w_slot == "emote":
		_refresh_emote_tab()
		return
	for it in Cosmetics.items_in(_w_slot):
		var id: String = it[0]
		var own := SaveData.owns_cos(id)
		var worn: bool = SaveData.equipped.get(_w_slot, "") == id
		var trying: bool = _w_try.get(_w_slot, "") == id
		var b := Button.new()
		b.custom_minimum_size = Vector2(166, 74)
		b.text = "%s\n%s" % [it[1], "착용 중" if worn else ("보유" if own else "● %d" % it[3])]
		b.add_theme_font_size_override("font_size", 14)
		b.icon = _dot_texture(it[5])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var border: Color = C_ICE if trying else (Color("ffd36b") if worn else C_LINE)
		var bg := C_PANEL_HI if trying else C_PANEL
		b.add_theme_stylebox_override("normal", _box(bg, border, 2 if (trying or worn) else 1, 10, 10))
		b.add_theme_stylebox_override("hover", _box(C_PANEL_HI, C_DIM, 1, 10, 10))
		b.add_theme_stylebox_override("pressed", _box(C_PANEL_HI, C_ICE, 2, 10, 10))
		if not own:
			b.add_theme_color_override("font_color", C_DIM)
		b.pressed.connect(func() -> void:
			_w_pick = id
			_w_try[_w_slot] = id
			_refresh_wardrobe())
		_w_grid.add_child(b)
	_w_update_action()
	_w_rebuild()


## 이모트 탭: 분류 버튼, 숫자키 칸 10개, 이모트 목록
func _refresh_emote_tab() -> void:
	for c in _w_ecats.get_children():
		c.queue_free()
	for cat in ["", "cute", "crude", "funny"]:
		var name: String = "전체" if cat == "" else Survivor.EMOTE_CATS[cat]
		var cb := _button(name, func() -> void:
			_w_ecat = cat
			_refresh_wardrobe(), _w_ecat == cat)
		cb.custom_minimum_size = Vector2(90, 34)
		_w_ecats.add_child(cb)
	var hint := _label("  칸을 고르고 → 이모트를 눌러 장착", 13, C_DIM)
	_w_ecats.add_child(hint)
	for c in _w_eslots.get_children():
		c.queue_free()
	for k in 10:
		var e := SaveData.emote_row(SaveData.emote_slots[k])
		var sb := Button.new()
		sb.custom_minimum_size = Vector2(134, 40)
		sb.text = "[%d] %s" % [(k + 1) % 10, e[1] if not e.is_empty() else "비어 있음"]
		sb.add_theme_font_size_override("font_size", 13)
		sb.clip_text = true
		var sel := k == _w_eslot
		sb.add_theme_stylebox_override("normal", _box(C_PANEL_HI if sel else C_PANEL, C_ICE if sel else C_LINE, 2 if sel else 1, 8, 6))
		sb.add_theme_stylebox_override("hover", _box(C_PANEL_HI, C_DIM, 1, 8, 6))
		sb.add_theme_stylebox_override("pressed", _box(C_PANEL_HI, C_ICE, 2, 8, 6))
		sb.pressed.connect(func() -> void:
			_w_eslot = k
			if not e.is_empty():
				_w_preview_emote(e[0])
			_refresh_wardrobe())
		_w_eslots.add_child(sb)
	var cat_cols := {"cute": Color("ff9ec4"), "crude": Color("b8d46a"), "funny": Color("ffd36b")}
	for e in Survivor.EMOTES:
		if _w_ecat != "" and e[4] != _w_ecat:
			continue
		var id: String = e[0]
		var own := SaveData.owns_emote(id)
		var slot := SaveData.emote_slots.find(id)
		var b := Button.new()
		b.custom_minimum_size = Vector2(166, 74)
		b.text = "%s\n%s · %s" % [e[1], Survivor.EMOTE_CATS[e[4]], ("[%d]번 칸" % ((slot + 1) % 10)) if slot >= 0 else ("보유" if own else "● %d" % e[5])]
		b.add_theme_font_size_override("font_size", 14)
		b.icon = _dot_texture(cat_cols[e[4]])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var picked := id == _w_epick
		var border: Color = C_ICE if picked else (Color("ffd36b") if slot >= 0 else C_LINE)
		b.add_theme_stylebox_override("normal", _box(C_PANEL_HI if picked else C_PANEL, border, 2 if (picked or slot >= 0) else 1, 10, 10))
		b.add_theme_stylebox_override("hover", _box(C_PANEL_HI, C_DIM, 1, 10, 10))
		b.add_theme_stylebox_override("pressed", _box(C_PANEL_HI, C_ICE, 2, 10, 10))
		if not own:
			b.add_theme_color_override("font_color", C_DIM)
		b.pressed.connect(func() -> void:
			_w_preview_emote(id)
			_refresh_wardrobe())
		_w_grid.add_child(b)
	# 왼쪽 정보·버튼
	if _w_epick == "":
		_w_info.text = "이모트를 누르면 미리 볼 수 있어요"
		_w_action.text = "이모트를 골라 주세요"
		_w_action.disabled = true
	else:
		var pe := SaveData.emote_row(_w_epick)
		_w_info.text = "이모트 · %s (%s)" % [pe[1], Survivor.EMOTE_CATS[pe[4]]]
		if SaveData.owns_emote(_w_epick):
			var in_slot: bool = SaveData.emote_slots[_w_eslot] == _w_epick
			_w_action.text = "[%d]번 칸에 장착됨" % ((_w_eslot + 1) % 10) if in_slot else "[%d]번 칸에 장착하기" % ((_w_eslot + 1) % 10)
			_w_action.disabled = in_slot
		else:
			_w_action.text = "구매하고 [%d]번 칸에 장착  ● %d" % [(_w_eslot + 1) % 10, pe[5]]
			_w_action.disabled = SaveData.coins < int(pe[5])
			if _w_action.disabled:
				_w_info.text += "   (코인이 부족해요)"
	if _w_body == null or not is_instance_valid(_w_body):
		_w_rebuild()


func _w_preview_emote(id: String) -> void:
	_w_epick = id
	_w_etime = 0.0
	if _w_body and is_instance_valid(_w_body):
		_w_body.emote = ""
		_w_body.animate(0.016, 0.0, false)
		_w_body.emote = id


func _w_update_action() -> void:
	if _w_pick == "":
		_w_info.text = "아이템을 누르면 미리 입어 볼 수 있어요"
		_w_action.text = "착용 저장"
		_w_action.disabled = _w_try == SaveData.equipped
		return
	var it := Cosmetics.info(_w_pick)
	var own := SaveData.owns_cos(_w_pick)
	_w_info.text = "%s · %s" % [Cosmetics.SLOT_NAMES[it[2]], it[1]]
	if own:
		_w_action.text = "착용 중" if SaveData.equipped.get(it[2], "") == _w_pick else "착용하기"
		_w_action.disabled = SaveData.equipped.get(it[2], "") == _w_pick
	else:
		_w_action.text = "구매하고 착용  ● %d" % it[3]
		_w_action.disabled = SaveData.coins < int(it[3])
		if _w_action.disabled:
			_w_info.text += "   (코인이 부족해요)"


func _on_wardrobe_action() -> void:
	if _w_slot == "emote":
		if _w_epick != "" and (SaveData.owns_emote(_w_epick) or SaveData.buy_emote(_w_epick)):
			SaveData.equip_emote(_w_eslot, _w_epick)
		_refresh_wardrobe()
		return
	if _w_pick == "":
		for slot in _w_try:
			if SaveData.owns_cos(_w_try[slot]):
				SaveData.equipped[slot] = _w_try[slot]
		SaveData.save_game()
	elif SaveData.owns_cos(_w_pick) or SaveData.buy_cos(_w_pick):
		SaveData.equip_cos(_w_pick)
	_refresh_wardrobe()


## 미리보기 인형 다시 만들기 (안 산 아이템도 입어 볼 수 있음)
func _w_rebuild() -> void:
	if _w_body and is_instance_valid(_w_body):
		_w_body.queue_free()
	_w_body = ClayBody.new()
	_w_pivot.add_child(_w_body)
	var cid: String = CharacterDB.ORDER[maxi(0, _w_char.selected)]
	_w_body.build(cid, _w_try)
	if _w_slot == "emote" and _w_epick != "":
		_w_body.emote = _w_epick
		_w_etime = 0.0


func _on_buy(id: String) -> void:
	SaveData.buy(id)
	_refresh_shop()


func _on_test_coins() -> void:
	SaveData.add_coins(100)
	SaveData.save_game()
	_refresh_main()


func _on_reset() -> void:
	SaveData.reset()
	_selected = SaveData.selected_character
	_refresh_main()


# ================================================================ 배경 · 테마 · 도우미

func _build_background() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV - vec2(0.5, 0.42);
	float d = length(uv * vec2(1.6, 1.0));
	vec3 top = vec3(0.07, 0.09, 0.13);
	vec3 bot = vec3(0.025, 0.028, 0.04);
	vec3 c = mix(top, bot, smoothstep(0.0, 0.9, d));
	c += vec3(0.02, 0.05, 0.07) * (1.0 - smoothstep(0.0, 0.5, d));
	COLOR = vec4(c, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	bg.material = m
	add_child(bg)
	# 천천히 내리는 눈 (얼음땡 분위기)
	var snow := CPUParticles2D.new()
	snow.amount = 90
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.position = Vector2(640, -20)
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(760, 4)
	snow.direction = Vector2(0.15, 1)
	snow.spread = 12.0
	snow.gravity = Vector2.ZERO
	snow.initial_velocity_min = 18.0
	snow.initial_velocity_max = 42.0
	snow.scale_amount_min = 1.0
	snow.scale_amount_max = 2.6
	snow.color = Color(0.8, 0.9, 1.0, 0.35)
	add_child(snow)


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", C_TEXT)
	# 버튼
	t.set_stylebox("normal", "Button", _box(C_PANEL, C_LINE, 1, 10))
	t.set_stylebox("hover", "Button", _box(C_PANEL_HI, C_DIM, 1, 10))
	t.set_stylebox("pressed", "Button", _box(C_PANEL_HI, C_ICE, 1, 10))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 10))
	t.set_stylebox("disabled", "Button", _box(Color("0f1117"), Color("1a1e27"), 1, 10))
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("4a5160"))
	t.set_font_size("font_size", "Button", 18)
	t.set_constant("h_separation", "Button", 8)
	# 입력 칸
	t.set_stylebox("normal", "LineEdit", _box(C_BG, C_LINE, 1, 8, 12))
	t.set_stylebox("focus", "LineEdit", _box(C_BG, C_ICE, 1, 8, 12))
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color("4f5768"))
	t.set_color("caret_color", "LineEdit", C_ICE)
	t.set_font_size("font_size", "LineEdit", 18)
	# 카드 (PanelContainer)
	t.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_LINE, 1, 12, 18))
	return t


func _box(bg: Color, border: Color, border_w: int, radius: int, pad := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad * 0.6
	sb.content_margin_bottom = pad * 0.6
	return sb


func _box_override(card: PanelContainer, sb: StyleBoxFlat) -> void:
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 11
	sb.content_margin_bottom = 11
	card.add_theme_stylebox_override("panel", sb)


func _page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)
	return page


func _center(page: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(c)
	return c


func _header(title: String, sub: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var t := _label(title, 40, C_TEXT)
	v.add_child(t)
	v.add_child(_label(sub, 15, C_DIM))
	return v


func _card() -> PanelContainer:
	return PanelContainer.new()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _field_label(text: String) -> Label:
	var l := _label(text, 16, C_DIM)
	l.custom_minimum_size.x = 80
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(text: String, on_pressed: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.pressed.connect(on_pressed)
	if primary:
		b.add_theme_stylebox_override("normal", _box(C_ICE.darkened(0.55), C_ICE.darkened(0.2), 1, 10))
		b.add_theme_stylebox_override("hover", _box(C_ICE.darkened(0.45), C_ICE, 1, 10))
		b.add_theme_stylebox_override("pressed", _box(C_ICE.darkened(0.6), C_ICE, 1, 10))
		b.add_theme_color_override("font_color", Color.WHITE)
	return b


func _text_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", C_DIM)
	b.add_theme_color_override("font_hover_color", C_TEXT)
	b.pressed.connect(on_pressed)
	return b


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _gap_h(w: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = w
	return c


func _dot(color: Color, size: float) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size))
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _dot_texture(color: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for x in 14:
		for y in 14:
			var d := Vector2(x - 6.5, y - 6.5).length()
			img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(7.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
