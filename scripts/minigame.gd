class_name Minigame
extends CanvasLayer
## 봉인석 미니게임 창 (게임 속 게임)
## 봉인석 앞에서 E를 누르면 9종 중 하나가 랜덤으로 뜹니다. 클리어하면 봉인석 진행도 +1단계.
## 미니게임 중에도 게임은 계속 진행돼서 술래가 다가올 수 있어요. Esc로 언제든 그만둘 수 있습니다.
##   1. 숨은 글자 찾기: 아주 비슷한 글자 35개 중 하나만 다른 글자 클릭
##   2. 순서 기억: 빠르게 빛나는 버튼 5~6개 순서를 기억해서 똑같이 누르기
##   3. 타이밍 맞추기: 좁은 초록 구간에 2번 연속 Space (2번째는 더 빠름)
##   4. 부적 맞추기: 가짜 조각 6개를 피해 6조각을 순서대로 클릭 (누를 때마다 자리가 섞임)
##   5. 회전 바늘: 원을 도는 바늘이 초록 구간에 올 때 Space, 3번 연속 (갈수록 좁고 빠르게)
##   6. 숫자 순서: 흩어진 1~12를 순서대로 클릭
##   7. 화살표 입력: 화면의 화살표를 제한 시간 안에 WASD(방향키)로 따라 입력
##   8. 카드 짝 맞추기: 1초 보여 준 뒤 덮인 카드 12장의 짝 찾기
##   9. 눈 감고 스톱워치: 숫자가 사라진 뒤 감으로 목표 시간에 Space
## 중간에 그만두면(Esc, 얼음, 끌려감 등) 술래가 그 봉인석 위치를 알아챕니다.
## stage(0, 1, 2…)가 높을수록 조금씩 어려워집니다. (봉인석의 몇 번째 단계인지)

signal cleared
signal failed
signal closed
## 끝나기 전에 중간에 그만둠 (술래가 위치를 알게 됨)
signal cancelled

const TYPES := ["find", "memory", "timing", "talisman", "dial", "order", "arrows", "cards", "stopwatch"]
const ARROWS := ["↑", "→", "↓", "←"]
const CARD_FACES := ["얼", "음", "땡", "술", "래", "봉"]
const CARD_COLORS := [Color(1, 0.45, 0.45), Color(0.45, 0.7, 1), Color(0.5, 1, 0.5), Color(1, 0.85, 0.35), Color(0.85, 0.5, 1), Color(0.4, 1, 0.95)]
const FIND_PAIRS := [["밝", "밟"], ["갈", "걀"], ["뭉", "몽"], ["얼", "열"], ["땡", "떙"], ["숲", "슾"], ["괘", "궤"], ["봬", "뵈"], ["쌈", "썸"], ["흙", "흝"]]
const MEMORY_COLORS := [Color(0.9, 0.25, 0.25), Color(0.25, 0.6, 1.0), Color(0.3, 0.85, 0.35), Color(1.0, 0.8, 0.2)]
const TALISMAN := ["술", "래", "를", "봉", "인", "해"]
const TALISMAN_DECOYS := ["솔", "레", "릍", "봄", "안", "헤"]

var game_type := ""
## 봉인석의 몇 번째 단계인지 (0부터). player.gd 가 정해 줌
var stage := 0
var _time_left := 10.0
var _done := false
var _content: Control
var _info: Label
var _timer_bar: ProgressBar

# 순서 기억
var _sequence: Array[int] = []
var _input_index := 0
var _showing := false
var _memory_buttons: Array[Button] = []
# 타이밍
var _needle := 0.0
var _needle_dir := 1.0
var _zone_start := 0.0
var _zone_size := 0.13
var _timing_hits := 0
var _speed_boost := 1.0
var _zone_rect: ColorRect
var _needle_rect: ColorRect
var _track_width := 380.0
# 부적
var _talisman_next := 0
var _talisman_grid: GridContainer
# 회전 바늘
var _dial: Control
var _dial_angle := 0.0
var _dial_zone_start := 0.0
var _dial_zone := 50.0
var _dial_hits := 0
var _dial_speed := 1.0
# 숫자 순서
var _order_next := 1
# 화살표
var _arrow_seq: Array[int] = []
var _arrow_labels: Array[Label] = []
var _arrow_index := 0
# 카드
var _cards: Array[Button] = []
var _card_values: Array[int] = []
var _card_open: Array[int] = []
var _card_matched := 0
var _card_busy := false
# 스톱워치
var _sw_target := 3.0
var _sw_time := 0.0
var _sw_label: Label


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_type = TYPES[randi() % TYPES.size()]
	_time_left = GameConfig.num("minigame", "time_limit", 10.0)
	_build_window()
	match game_type:
		"find":
			_build_find()
		"memory":
			_build_memory()
		"timing":
			_build_timing()
		"talisman":
			_build_talisman()
		"dial":
			_build_dial()
		"order":
			_build_order()
		"arrows":
			_build_arrows()
		"cards":
			_build_cards()
		"stopwatch":
			_build_stopwatch()


## 이 미니게임만의 제한 시간
func _set_time(t: float) -> void:
	_time_left = t
	_timer_bar.max_value = t
	_timer_bar.value = t


func _process(delta: float) -> void:
	if _done:
		return
	if not _showing:
		_time_left -= delta
	_timer_bar.value = _time_left
	if _time_left <= 0.0:
		_fail("시간 초과!")
		return
	if game_type == "timing":
		_needle += _needle_dir * delta * GameConfig.num("minigame", "timing_speed", 1.1) * _speed_boost * (1.0 + 0.12 * stage)
		if _needle >= 1.0 or _needle <= 0.0:
			_needle = clampf(_needle, 0.0, 1.0)
			_needle_dir = -_needle_dir
		_needle_rect.position.x = _needle * _track_width - 3.0
	elif game_type == "dial":
		_dial_angle = fmod(_dial_angle + 360.0 / GameConfig.num("minigame", "dial_lap_time", 1.4) * _dial_speed * (1.0 + 0.08 * stage) * delta, 360.0)
		_dial.queue_redraw()
	elif game_type == "stopwatch":
		_sw_time += delta
		if _sw_time < GameConfig.num("minigame", "stopwatch_visible", 1.0):
			_sw_label.text = "%.2f" % _sw_time
		else:
			_sw_label.text = "?.??"


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
	elif _showing:
		return
	elif game_type == "timing" and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		_timing_press()
	elif (game_type == "dial" or game_type == "stopwatch") and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if game_type == "dial":
			_dial_press()
		else:
			_stopwatch_press()
	elif game_type == "arrows" and event is InputEventKey and event.pressed and not event.echo:
		var dir := -1
		match (event as InputEventKey).physical_keycode:
			KEY_W, KEY_UP: dir = 0
			KEY_D, KEY_RIGHT: dir = 1
			KEY_S, KEY_DOWN: dir = 2
			KEY_A, KEY_LEFT: dir = 3
		if dir >= 0:
			get_viewport().set_input_as_handled()
			_arrow_press(dir)
	elif game_type == "memory" and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			get_viewport().set_input_as_handled()
			_memory_press(k - KEY_1)


## 창 닫기 (그만두기). 진행도는 그대로 남음
## silent: 봉인석이 완료돼서 자동으로 닫힐 때 (술래에게 안 알림)
func close(silent := false) -> void:
	if not _done and not silent:
		cancelled.emit()
	_done = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()
	queue_free()


func _clear() -> void:
	if _done:
		return
	_info.text = "성공!"
	_info.modulate = Color(0.5, 1, 0.6)
	_done = true
	cleared.emit()
	_finish_later()


func _fail(reason: String) -> void:
	if _done:
		return
	_info.text = "%s 실패... 큰 소리가 났어요!" % reason
	_info.modulate = Color(1, 0.45, 0.45)
	_done = true
	failed.emit()
	_finish_later()


func _finish_later() -> void:
	await get_tree().create_timer(0.6).timeout
	if is_instance_valid(self):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		closed.emit()
		queue_free()


# ---------------------------------------------------------------- 창

func _build_window() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP  # 뒤쪽 게임 화면으로 클릭이 새지 않게
	add_child(root)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.12, 0.92)
	style.set_corner_radius_all(12)
	style.set_border_width_all(2)
	style.border_color = Color(0.55, 0.45, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := Label.new()
	title.text = "봉인석 해제"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 17)
	box.add_child(_info)
	_content = CenterContainer.new()
	_content.custom_minimum_size = Vector2(400, 190)
	box.add_child(_content)
	_timer_bar = ProgressBar.new()
	_timer_bar.max_value = _time_left
	_timer_bar.value = _time_left
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(400, 10)
	box.add_child(_timer_bar)
	var hint := Label.new()
	hint.text = "Esc: 그만두기 (진행도 유지) · 실패하면 큰 소리가 나요"
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _button(text: String, size: Vector2, font := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.focus_mode = Control.FOCUS_NONE  # Space/Enter가 버튼을 누르지 않게
	b.add_theme_font_size_override("font_size", font)
	return b


# ---------------------------------------------------------------- 1. 숨은 글자 찾기

func _build_find() -> void:
	_info.text = "하나만 다른 글자를 찾아 클릭하세요"
	var pair: Array = FIND_PAIRS[randi() % FIND_PAIRS.size()]
	if randf() < 0.5:
		pair = [pair[1], pair[0]]
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	var count := int(GameConfig.num("minigame", "find_count", 35))
	var odd := randi() % count
	for i in count:
		var b := _button(pair[1] if i == odd else pair[0], Vector2(52, 36), 22)
		b.pressed.connect(_clear if i == odd else _fail.bind("다른 글자를 눌렀어요."))
		grid.add_child(b)


# ---------------------------------------------------------------- 2. 순서 기억

func _build_memory() -> void:
	_info.text = "빛나는 순서를 기억하세요..."
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	for i in 4:
		var b := _button(str(i + 1), Vector2(80, 80), 28)
		b.modulate = MEMORY_COLORS[i].darkened(0.5)
		b.pressed.connect(_memory_press.bind(i))
		row.add_child(b)
		_memory_buttons.append(b)
	var length := int(GameConfig.num("minigame", "memory_length", 5)) + (1 if stage >= 2 else 0)
	for i in length:
		_sequence.append(randi() % 4)
	_show_sequence()


func _show_sequence() -> void:
	_showing = true
	await get_tree().create_timer(0.5).timeout
	for idx in _sequence:
		if not is_instance_valid(self) or _done:
			return
		_memory_buttons[idx].modulate = MEMORY_COLORS[idx].lightened(0.3)
		await get_tree().create_timer(maxf(0.22, 0.34 - 0.04 * stage)).timeout
		if not is_instance_valid(self):
			return
		_memory_buttons[idx].modulate = MEMORY_COLORS[idx].darkened(0.5)
		await get_tree().create_timer(0.12).timeout
	if is_instance_valid(self):
		_showing = false
		_info.text = "같은 순서로 누르세요 (클릭 또는 1~4)"


func _memory_press(idx: int) -> void:
	if _showing or _done:
		return
	var b := _memory_buttons[idx]
	b.modulate = MEMORY_COLORS[idx].lightened(0.3)
	create_tween().tween_property(b, "modulate", MEMORY_COLORS[idx].darkened(0.5), 0.25)
	if idx != _sequence[_input_index]:
		_fail("순서가 틀렸어요.")
		return
	_input_index += 1
	if _input_index >= _sequence.size():
		_clear()


# ---------------------------------------------------------------- 3. 타이밍 맞추기

func _build_timing() -> void:
	var need := int(GameConfig.num("minigame", "timing_hits", 2))
	_info.text = "바늘이 초록 구간에 들어오면 Space! (%d번 연속)" % need
	_zone_size = maxf(0.07, GameConfig.num("minigame", "timing_zone", 0.13) - 0.015 * stage)
	_zone_start = randf_range(0.15, 0.85 - _zone_size)
	_needle = 0.0
	var track := ColorRect.new()
	track.color = Color(0.2, 0.2, 0.25)
	track.custom_minimum_size = Vector2(_track_width, 40)
	_content.add_child(track)
	var zone := ColorRect.new()
	_zone_rect = zone
	zone.color = Color(0.3, 0.85, 0.35)
	zone.position = Vector2(_zone_start * _track_width, 0)
	zone.size = Vector2(_zone_size * _track_width, 40)
	track.add_child(zone)
	_needle_rect = ColorRect.new()
	_needle_rect.color = Color(1, 1, 1)
	_needle_rect.size = Vector2(6, 52)
	_needle_rect.position = Vector2(-3, -6)
	track.add_child(_needle_rect)


func _timing_press() -> void:
	if _needle < _zone_start or _needle > _zone_start + _zone_size:
		_fail("타이밍이 어긋났어요.")
		return
	_timing_hits += 1
	var need := int(GameConfig.num("minigame", "timing_hits", 2))
	if _timing_hits >= need:
		_clear()
		return
	# 다음 번: 구간 위치가 바뀌고 바늘이 더 빨라짐
	_info.text = "좋아요! 한 번 더! (%d / %d)" % [_timing_hits, need]
	_speed_boost *= 1.35
	_zone_start = randf_range(0.1, 0.9 - _zone_size)
	_zone_rect.position.x = _zone_start * _track_width


# ---------------------------------------------------------------- 4. 부적 맞추기

func _build_talisman() -> void:
	_info.text = "\"%s\" 순서대로 클릭! (가짜 조각 주의, 누를 때마다 섞여요)" % " ".join(TALISMAN)
	_set_time(GameConfig.num("minigame", "talisman_time", 7.0))
	var grid := GridContainer.new()
	_talisman_grid = grid
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	_content.add_child(grid)
	# 진짜 조각 6개 + 가짜 조각 6개 (가짜는 진짜와 비슷한 글자)
	var pieces: Array = []
	for i in TALISMAN.size():
		pieces.append(i)
	var decoys := range(TALISMAN_DECOYS.size())
	decoys.shuffle()
	for k in decoys.size():
		pieces.append(-1 - decoys[k])
	pieces.shuffle()
	for i in pieces:
		var text: String = TALISMAN[i] if i >= 0 else TALISMAN_DECOYS[-1 - i]
		var b := _button(text, Vector2(64, 80), 30)
		b.rotation_degrees = randf_range(-15, 15)
		b.pivot_offset = Vector2(32, 40)
		b.modulate = Color(1.0, 0.9, 0.6)
		b.pressed.connect(_talisman_press.bind(i, b))
		grid.add_child(b)


func _talisman_press(i: int, b: Button) -> void:
	if i != _talisman_next:
		_fail("순서가 틀렸어요.")
		return
	_talisman_next += 1
	b.disabled = true
	b.rotation_degrees = 0.0
	b.modulate = Color(0.6, 1.0, 0.6)
	if _talisman_next >= TALISMAN.size():
		_clear()
		return
	# 조각 자리를 섞음
	var kids := _talisman_grid.get_children()
	kids.shuffle()
	for k in kids.size():
		_talisman_grid.move_child(kids[k], k)
		(kids[k] as Control).rotation_degrees = 0.0 if (kids[k] as Button).disabled else randf_range(-15, 15)


# ---------------------------------------------------------------- 5. 회전 바늘

func _build_dial() -> void:
	var need := int(GameConfig.num("minigame", "dial_hits", 3))
	_info.text = "도는 바늘이 초록 구간에 오면 Space! (%d번 연속)" % need
	_dial_zone = maxf(25.0, GameConfig.num("minigame", "dial_zone_deg", 50.0) - 5.0 * stage)
	_dial_zone_start = randf_range(90.0, 270.0)
	_dial = Control.new()
	_dial.custom_minimum_size = Vector2(190, 190)
	_dial.draw.connect(_draw_dial)
	_content.add_child(_dial)


func _draw_dial() -> void:
	var c := _dial.size / 2.0
	var r := 78.0
	_dial.draw_arc(c, r, 0.0, TAU, 64, Color(0.22, 0.22, 0.3), 16.0)
	var a0 := deg_to_rad(_dial_zone_start - 90.0)
	_dial.draw_arc(c, r, a0, a0 + deg_to_rad(_dial_zone), 24, Color(0.3, 0.85, 0.35), 16.0)
	var a := deg_to_rad(_dial_angle - 90.0)
	_dial.draw_line(c, c + Vector2(cos(a), sin(a)) * (r + 12.0), Color.WHITE, 5.0)
	_dial.draw_circle(c, 8.0, Color.WHITE)


func _dial_press() -> void:
	if fposmod(_dial_angle - _dial_zone_start, 360.0) > _dial_zone:
		_fail("타이밍이 어긋났어요.")
		return
	_dial_hits += 1
	var need := int(GameConfig.num("minigame", "dial_hits", 3))
	if _dial_hits >= need:
		_clear()
		return
	# 다음 번: 구간이 좁아지고, 바늘에서 먼 곳으로 옮겨지고, 더 빨라짐
	_info.text = "좋아요! (%d / %d)" % [_dial_hits, need]
	_dial_zone = maxf(20.0, _dial_zone * 0.8)
	_dial_zone_start = fmod(_dial_angle + randf_range(100.0, 260.0), 360.0)
	_dial_speed *= 1.2


# ---------------------------------------------------------------- 6. 숫자 순서

func _build_order() -> void:
	var count := int(GameConfig.num("minigame", "order_count", 12)) + stage
	_info.text = "1부터 %d까지 순서대로 클릭!" % count
	var area := Control.new()
	area.custom_minimum_size = Vector2(420, 200)
	_content.add_child(area)
	var spots: Array[Vector2] = []
	for i in range(1, count + 1):
		var pos := Vector2.ZERO
		for tries in 80:
			pos = Vector2(randf_range(0, 420 - 48), randf_range(0, 200 - 38))
			var ok := true
			for q in spots:
				if absf(q.x - pos.x) < 52.0 and absf(q.y - pos.y) < 42.0:
					ok = false
					break
			if ok:
				break
		spots.append(pos)
		var b := _button(str(i), Vector2(48, 38), 20)
		b.position = pos
		b.pressed.connect(_order_press.bind(i, b))
		area.add_child(b)


func _order_press(i: int, b: Button) -> void:
	if i != _order_next:
		_fail("순서가 틀렸어요.")
		return
	_order_next += 1
	b.disabled = true
	b.modulate = Color(0.5, 1.0, 0.5, 0.5)
	if _order_next > int(GameConfig.num("minigame", "order_count", 12)) + stage:
		_clear()


# ---------------------------------------------------------------- 7. 화살표 입력

func _build_arrows() -> void:
	_info.text = "화살표를 순서대로 입력! (WASD 또는 방향키)"
	_set_time(GameConfig.num("minigame", "arrow_time", 3.5))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	for i in int(GameConfig.num("minigame", "arrow_count", 6)) + stage:
		_arrow_seq.append(randi() % 4)
		var l := Label.new()
		l.text = ARROWS[_arrow_seq[i]]
		l.add_theme_font_size_override("font_size", 44)
		l.modulate = Color(1, 1, 1, 0.9)
		row.add_child(l)
		_arrow_labels.append(l)
	_arrow_labels[0].modulate = Color(1.0, 0.85, 0.3)


func _arrow_press(dir: int) -> void:
	if dir != _arrow_seq[_arrow_index]:
		_arrow_labels[_arrow_index].modulate = Color(1, 0.3, 0.3)
		_fail("방향이 틀렸어요.")
		return
	_arrow_labels[_arrow_index].modulate = Color(0.4, 1.0, 0.5, 0.6)
	_arrow_index += 1
	if _arrow_index >= _arrow_seq.size():
		_clear()
		return
	_arrow_labels[_arrow_index].modulate = Color(1.0, 0.85, 0.3)


# ---------------------------------------------------------------- 8. 카드 짝 맞추기

func _build_cards() -> void:
	_info.text = "카드를 잘 보세요..."
	_set_time(GameConfig.num("minigame", "card_time", 15.0))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for k in CARD_FACES.size():
		_card_values.append(k)
		_card_values.append(k)
	_card_values.shuffle()
	for i in _card_values.size():
		var b := _button("", Vector2(58, 76), 30)
		b.pressed.connect(_card_press.bind(i))
		grid.add_child(b)
		_cards.append(b)
		_card_face(i, true)
	_showing = true  # 보여 주는 동안은 시간이 안 감
	await get_tree().create_timer(maxf(0.5, GameConfig.num("minigame", "card_peek", 1.0) - 0.15 * stage)).timeout
	if not is_instance_valid(self) or _done:
		return
	for i in _cards.size():
		_card_face(i, false)
	_showing = false
	_info.text = "같은 글자 짝을 모두 찾으세요!"


func _card_face(i: int, up: bool) -> void:
	var b := _cards[i]
	if up:
		b.text = CARD_FACES[_card_values[i]]
		b.modulate = CARD_COLORS[_card_values[i]]
	else:
		b.text = "?"
		b.modulate = Color(0.6, 0.55, 0.8)


func _card_press(i: int) -> void:
	if _showing or _done or _card_busy or _cards[i].disabled or _card_open.has(i):
		return
	_card_face(i, true)
	_card_open.append(i)
	if _card_open.size() < 2:
		return
	var a := _card_open[0]
	var b := _card_open[1]
	_card_open.clear()
	if _card_values[a] == _card_values[b]:
		_cards[a].disabled = true
		_cards[b].disabled = true
		_card_matched += 1
		if _card_matched >= CARD_FACES.size():
			_clear()
		return
	_card_busy = true
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(self) or _done:
		return
	_card_face(a, false)
	_card_face(b, false)
	_card_busy = false


# ---------------------------------------------------------------- 9. 눈 감고 스톱워치

func _build_stopwatch() -> void:
	_sw_target = [2.0, 2.5, 3.0, 3.5][randi() % 4]
	_info.text = "%.2f초에 Space! (숫자는 곧 사라져요)" % _sw_target
	_set_time(_sw_target + 3.0)
	_sw_label = Label.new()
	_sw_label.text = "0.00"
	_sw_label.add_theme_font_size_override("font_size", 64)
	_sw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(_sw_label)


func _stopwatch_press() -> void:
	_sw_label.text = "%.2f" % _sw_time
	var tol := maxf(0.08, GameConfig.num("minigame", "stopwatch_tolerance", 0.15) - 0.02 * stage)
	if absf(_sw_time - _sw_target) <= tol:
		_clear()
	else:
		_fail("%.2f초였어요." % _sw_time)
