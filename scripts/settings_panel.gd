class_name SettingsPanel
extends Control
## 설정 창 (메인 메뉴·일시정지 메뉴 둘 다에서 씀). 바꾸면 바로 적용되고 저장됨
## 마우스 감도 · 전체 음량 · 화면 흔들림 · 전체화면 · 그래픽 · 도움말 표시

signal closed

const C_PANEL := Color("12151c")
const C_LINE := Color("262b36")
const C_TEXT := Color("e8ecf2")
const C_DIM := Color("8a93a3")
const C_ICE := Color("7fd6ff")


func _ready() -> void:
	# 부모 크기와 상관없이 화면 전체를 덮음
	top_level = true
	position = Vector2.ZERO
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_PANEL
	sb.border_color = C_LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = 520
	panel.add_child(box)
	var title := Label.new()
	title.text = "설정"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", C_TEXT)
	box.add_child(title)
	_slider(box, "마우스 감도", 0.3, 2.5, 0.05, SaveData.sensitivity, func(v: float) -> void: SaveData.sensitivity = v, func(v: float) -> String: return "%.2f배" % v)
	_slider(box, "전체 음량", 0.0, 1.0, 0.01, SaveData.volume, func(v: float) -> void:
		SaveData.volume = v
		SaveData.apply_audio(), func(v: float) -> String: return "%d%%" % roundi(v * 100))
	_slider(box, "화면 흔들림", 0.0, 1.0, 0.05, SaveData.shake, func(v: float) -> void: SaveData.shake = v, func(v: float) -> String: return "끔" if v <= 0.0 else "%d%%" % roundi(v * 100))
	_toggle(box, "전체화면", SaveData.fullscreen, func(on: bool) -> void:
		SaveData.fullscreen = on
		SaveData.apply_window())
	_toggle(box, "그래픽 높음 (끄면 가벼움)", SaveData.high_graphics(), func(on: bool) -> void: SaveData.graphics = "high" if on else "low")
	_toggle(box, "조작 도움말 항상 보기 (F1로도 켜고 끔)", SaveData.show_help, func(on: bool) -> void: SaveData.show_help = on)
	var note := Label.new()
	note.text = "그래픽 변경은 다음 판부터 적용돼요"
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", C_DIM)
	box.add_child(note)
	var close := Button.new()
	close.text = "닫기"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_close)
	box.add_child(close)
	close.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	SaveData.save_game()
	closed.emit()
	queue_free()


func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 190
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", C_TEXT)
	row.add_child(l)
	box.add_child(row)
	return row


func _slider(box: VBoxContainer, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable, fmt: Callable) -> void:
	var row := _row(box, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var v := Label.new()
	v.custom_minimum_size.x = 64
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_color_override("font_color", C_ICE)
	v.text = fmt.call(value)
	row.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		on_change.call(x)
		v.text = fmt.call(x))


func _toggle(box: VBoxContainer, text: String, on: bool, on_change: Callable) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = on
	c.add_theme_font_size_override("font_size", 17)
	c.toggled.connect(func(x: bool) -> void: on_change.call(x))
	box.add_child(c)
