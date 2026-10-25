class_name Hud
extends CanvasLayer
## 게임 화면 위 UI (글자, 능력 쿨타임, 해동 게이지, 화면 효과, 일시정지/결과 창)
## 노드를 코드로 만들기 때문에 에디터에서 따로 꾸밀 필요가 없습니다.

const MENU_SCENE := "res://scenes/menu.tscn"
const SFX_HEART := preload("res://audio/heartbeat.wav")

## 필름 노이즈 (지글지글한 오래된 영상 느낌)
const GRAIN_SHADER := """
shader_type canvas_item;
uniform float amount = 0.07;
float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float n = rand(UV * vec2(1280.0, 720.0) + vec2(TIME * 37.0, TIME * 91.0));
	float line = step(0.997, rand(vec2(floor(UV.y * 240.0), floor(TIME * 12.0))));
	COLOR = vec4(vec3(n), amount + line * 0.08);
}
"""

## 화면 가장자리 효과 (어두운 테두리 / 서리 / 동화 색)
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float strength = 0.6;
uniform float inner = 0.35;
void fragment() {
	vec2 uv = (UV - 0.5) * vec2(1.6, 1.0);
	float v = smoothstep(inner, 0.95, length(uv));
	COLOR = vec4(tint.rgb, v * strength);
}
"""

## [손맛] 얼음 서리: 화면 가장자리에서 안쪽으로 번져 들어오는 성에 + 해동될수록 금이 감
const FROST_SHADER := """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float crack = 0.0;
uniform vec4 tint : source_color = vec4(0.78, 0.93, 1.0, 1.0);
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * vnoise(p); p *= 2.07; a *= 0.5; } return v; }
void fragment() {
	vec2 c = (UV - 0.5) * vec2(1.7, 1.0);
	float edge = length(c);
	float n = fbm(UV * vec2(10.0, 6.0));
	float reach = mix(1.15, 0.5, progress);
	float f = smoothstep(reach, reach + 0.2, edge + (n - 0.5) * 0.4);
	float feather = fbm(vec2(atan(c.y, c.x) * 7.0, edge * 9.0));
	float a = f * (0.45 + 0.4 * feather);
	vec2 g = UV * vec2(9.0, 5.0);
	vec2 gi = floor(g);
	float d1 = 9.0; float d2 = 9.0; vec2 cell = vec2(0.0);
	for (int y = -1; y <= 1; y++) { for (int x = -1; x <= 1; x++) {
		vec2 o = vec2(float(x), float(y));
		vec2 pnt = o + hash2(gi + o);
		float d = length(g - gi - pnt);
		if (d < d1) { d2 = d1; d1 = d; cell = gi + o; } else if (d < d2) { d2 = d; }
	} }
	float line = 1.0 - smoothstep(0.0, 0.05, d2 - d1);
	float show = step(hash(cell), crack) * smoothstep(0.0, 0.3, crack);
	float cr = line * show * max(f, crack * 0.6);
	vec3 col = tint.rgb * (0.8 + 0.35 * n) + vec3(cr * 0.5);
	COLOR = vec4(col, clamp(a * 0.72 + cr * 0.5, 0.0, 1.0));
}
"""

var main: Node  # main.gd

var _top_label: Label
var _retro_mat: ShaderMaterial
var _stamina_bg: ColorRect
var _stamina_fill: ColorRect
var _status_label: Label
var _ability_label: Label
var _shared_label: Label
var _message_label: Label
var _summon_label: Label
var _thaw_bar: ProgressBar
var _thaw_label: Label
var _vignette: ColorRect
var _frost: ColorRect
var _camo: ColorRect
var _flash: ColorRect
var _pause_panel: PanelContainer
var _result_panel: PanelContainer
var _result_title: Label
var _result_body: Label
var _result_sub: Label
var _result_dim: ColorRect
var _result_box: VBoxContainer
var _mvp_card: PanelContainer
var _mvp_view: SubViewport
var _mvp_body: ClayBody
var _mvp_name: Label
var _mvp_why: Label
var _stats_grid: GridContainer
var _coin_label: Label
var _coin_target := 0
var _coin_shown := 0.0
var _result_retry: Button
var _result_menu: Button
var _message_time := 0.0
var _grain: ColorRect
var _danger: ColorRect
var _heart: AudioStreamPlayer
## 조작 도움말 (처음 30초 + F1/설정으로 항상 보기), 능력 준비 알림
var _help: Label
var _help_hint: Label
var _ready_sfx: AudioStreamPlayer
var _ready_prev := {}
var _ready_flash := 0.0
var _heart_timer := 0.0
# [손맛] 화면 피드백 상태
var _feel_bound: Node = null
var _hurt: ColorRect
var _red_flash: ColorRect
var _gold: ColorRect
var _hurt_level := 0.0
var _flash_level := 0.0
var _gold_level := 0.0
var _frost_prog := 0.0
var _frost_crack := 0.0
var _stamina_ghost: ColorRect
var _stamina_shown := 1.0
var _stamina_ghost_v := 1.0
var _stamina_ghost_wait := 0.0
var _stamina_idle := 0.0
var _status_was_empty := true
var _banner: Label
var _banner_sub: Label
var _banner_tw: Tween
var _missions_seen := -1
var _escape_seen := false
var _fx_t := 0.0


## 약한 레트로 필터: 해상도를 살짝 낮추고 색 단계를 줄여 점무늬(디더링)를 아주 옅게
const RETRO_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 pixel_res = vec2(711.0, 400.0);
uniform float color_depth = 32.0;
uniform float dither = 0.5;
float bayer(vec2 p) {
	int i = int(mod(p.x, 4.0)) + int(mod(p.y, 4.0)) * 4;
	float m[16] = float[16](0.,8.,2.,10.,12.,4.,14.,6.,3.,11.,1.,9.,15.,7.,13.,5.);
	return m[i] / 16.0 - 0.5;
}
void fragment() {
	vec2 cell = floor(SCREEN_UV * pixel_res);
	vec3 c = texture(screen_tex, (cell + 0.5) / pixel_res).rgb;
	c += bayer(cell) * dither / color_depth;
	c = floor(c * color_depth + 0.5) / color_depth;
	COLOR = vec4(c, 1.0);
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 일시정지 중에도 UI는 동작

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 레트로 필터 (약하게): 3D 화면만 살짝 거칠게. UI보다 먼저 그려서 글씨는 깨끗하게 유지
	if GameConfig.flag("retro", "enabled", false):
		var retro := ColorRect.new()
		retro.mouse_filter = Control.MOUSE_FILTER_IGNORE
		retro.set_anchors_preset(Control.PRESET_FULL_RECT)
		var rs := Shader.new()
		rs.code = RETRO_SHADER
		var rm := ShaderMaterial.new()
		rm.shader = rs
		_retro_mat = rm
		rm.set_shader_parameter("color_depth", GameConfig.num("retro", "color_depth", 32.0))
		rm.set_shader_parameter("dither", GameConfig.num("retro", "dither", 0.5))
		retro.material = rm
		root.add_child(retro)

	# 화면 효과 (가장 아래에 깔림)
	_vignette = _make_overlay(root, Color.BLACK, 0.75, 0.3)
	_camo = _make_overlay(root, Color(0.3, 0.9, 0.4), 0.0, 0.2)
	# [손맛] 서리: 가장자리부터 번져 들어오는 성에 (얼음일 때), 해동될수록 금
	_frost = ColorRect.new()
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frost.set_anchors_preset(Control.PRESET_FULL_RECT)
	var fs := Shader.new()
	fs.code = FROST_SHADER
	var fm := ShaderMaterial.new()
	fm.shader = fs
	_frost.material = fm
	_frost.visible = false
	root.add_child(_frost)
	# 공포 연출: 필름 노이즈 + 술래가 가까울수록 붉게 조여오는 화면
	_grain = ColorRect.new()
	_grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	var gs := Shader.new()
	gs.code = GRAIN_SHADER
	var gm := ShaderMaterial.new()
	gm.shader = gs
	gm.set_shader_parameter("amount", GameConfig.num("horror", "grain", 0.07))
	_grain.material = gm
	_grain.visible = GameConfig.num("horror", "grain", 0.0) > 0.0  # 0이면 노이즈 끔 (화면이 깨끗하게)
	root.add_child(_grain)
	_danger = _make_overlay(root, Color(0.5, 0.0, 0.0), 0.0, 0.25)
	# [손맛] 맞을 뻔/잡힘: 붉은 테두리 맥동 + 짧은 붉은 번쩍임, 봉인석 단계 성공: 은은한 금빛 테두리
	_hurt = _make_overlay(root, Color(0.65, 0.0, 0.02), 0.0, 0.18)
	_gold = _make_overlay(root, Color(1.0, 0.82, 0.45), 0.0, 0.3)
	_red_flash = ColorRect.new()
	_red_flash.color = Color(0.7, 0.0, 0.0, 0.0)
	_red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_red_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_red_flash)
	_heart = AudioStreamPlayer.new()
	_heart.stream = SFX_HEART
	add_child(_heart)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_flash)

	_top_label = _make_label(root, 20, Control.PRESET_TOP_LEFT)
	# 동료 목록 (위쪽 왼쪽, 진행 상황 아래): 색 점 · 이름 · 상태
	_roster = RichTextLabel.new()
	_roster.bbcode_enabled = true
	_roster.fit_content = true
	_roster.scroll_active = false
	_roster.autowrap_mode = TextServer.AUTOWRAP_OFF
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_roster.add_theme_font_size_override("normal_font_size", 14)
	_roster.add_theme_constant_override("outline_size", 4)
	_roster.add_theme_color_override("font_outline_color", Color.BLACK)
	_roster.add_theme_constant_override("line_separation", 2)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(0.03, 0.035, 0.05, 0.42)
	rsb.set_corner_radius_all(8)
	rsb.content_margin_left = 10
	rsb.content_margin_right = 12
	rsb.content_margin_top = 5
	rsb.content_margin_bottom = 6
	_roster.add_theme_stylebox_override("normal", rsb)
	root.add_child(_roster)
	_roster.position = Vector2(20, 110)
	_roster.custom_minimum_size = Vector2(200, 0)
	_status_label = _make_label(root, 21, Control.PRESET_CENTER_BOTTOM)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.position.y -= 90
	_status_base_bottom = _status_label.offset_bottom
	# 스태미나 막대 (화면 아래 가운데)
	_stamina_bg = ColorRect.new()
	_stamina_bg.color = Color(0, 0, 0, 0.55)
	_stamina_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina_bg.size = Vector2(260, 12)
	_stamina_bg.position = Vector2(-130, -42)
	root.add_child(_stamina_bg)
	_stamina_fill = ColorRect.new()
	_stamina_fill.color = Color(1.0, 0.85, 0.2)
	_stamina_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_fill.position = Vector2(2, 2)
	_stamina_fill.size = Vector2(256, 8)
	# [손맛] 줄어든 만큼 잠깐 남는 흰 잔상 막대 (채움 막대 뒤)
	_stamina_ghost = ColorRect.new()
	_stamina_ghost.color = Color(1.0, 0.95, 0.85, 0.55)
	_stamina_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina_ghost.position = Vector2(2, 2)
	_stamina_ghost.size = Vector2(256, 8)
	_stamina_bg.add_child(_stamina_ghost)
	_stamina_bg.add_child(_stamina_fill)
	_ability_label = _make_label(root, 18, Control.PRESET_BOTTOM_LEFT)
	_shared_label = _make_label(root, 16, Control.PRESET_BOTTOM_RIGHT)
	_shared_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 화면 구석 정보는 반투명 판 위에 (배경이 밝아도 잘 읽히고 덜 지저분하게)
	for l: Label in [_top_label, _ability_label, _shared_label]:
		_card(l)

	var help := _make_label(root, 14, Control.PRESET_TOP_RIGHT)
	_help = help
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.text = "WASD 이동 · Shift 달리기(소리 큼) · Ctrl 살금살금 · Space 구르기\nE 봉인석·문·판자·사물함·쥐·거미줄 · Q 얼음 · R/T 고유 능력\n얼음 동료 옆에 10초 붙어 있으면 땡 · Esc 일시정지\n헤드셋을 쓰면 발소리로 위치를 알 수 있어요"
	help.text = help.text.replace("10초", "%d초" % int(GameConfig.num("player", "thaw_time", 10.0))) + "\nF1 도움말 켜기/끄기"
	help.modulate = Color(1, 1, 1, 0.6)
	_help_survivor = help.text
	_help_hint = _make_label(root, 13, Control.PRESET_TOP_RIGHT)
	_help_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help_hint.text = "F1 도움말"
	_help_hint.modulate = Color(1, 1, 1, 0.4)
	_ready_sfx = AudioStreamPlayer.new()
	_ready_sfx.stream = load("res://audio/ui_ready.wav")
	_ready_sfx.volume_db = -8.0
	add_child(_ready_sfx)

	_message_label = _make_label(root, 28, Control.PRESET_CENTER_TOP)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.position.y += 110

	_summon_label = _make_label(root, 22, Control.PRESET_CENTER)
	_summon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summon_label.position.y += 80
	_summon_label.modulate = Color(0.85, 0.75, 1.0)

	var crosshair := _make_label(root, 24, Control.PRESET_CENTER)
	crosshair.text = "·"
	crosshair.modulate = Color(1, 1, 1, 0.7)

	# 해동 게이지 (화면 가운데 아래)
	var thaw_box := VBoxContainer.new()
	root.add_child(thaw_box)
	thaw_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 150)
	thaw_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	thaw_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_thaw_label = Label.new()
	_thaw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thaw_label.add_theme_font_size_override("font_size", 18)
	thaw_box.add_child(_thaw_label)
	_thaw_bar = ProgressBar.new()
	_thaw_bar.custom_minimum_size = Vector2(360, 18)
	_thaw_bar.show_percentage = false
	thaw_box.add_child(_thaw_bar)
	thaw_box.visible = false

	# [손맛] 봉인석 가동·탈출구 열림 배너 (가운데 위)
	_banner = _make_label(root, 40, Control.PRESET_CENTER_TOP)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position.y += 175
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	_banner_sub = _make_label(root, 18, Control.PRESET_CENTER_TOP)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.position.y += 232
	_banner_sub.modulate.a = 0.0

	_build_pause_panel(root)
	_build_result_panel(root)


## main.gd가 게임 준비를 끝내면 불러 줍니다.
func setup(main_node: Node) -> void:
	main = main_node


func show_message(text: String, seconds: float) -> void:
	_message_label.text = text
	_message_time = seconds


## 카메라맨 플래시 효과
func flash() -> void:
	_flash.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.5)


## 폭주 경고: 화면이 붉게 번쩍 + 울부짖음
func flash_red() -> void:
	_flash.color = Color(0.8, 0.0, 0.0, 0.6)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 1.2)
	tw.tween_callback(func() -> void: _flash.color = Color(1, 1, 1, 0))
	var a := AudioStreamPlayer.new()
	a.stream = preload("res://audio/howl.wav")
	a.pitch_scale = 0.7
	a.volume_db = -4.0
	add_child(a)
	a.play()
	a.finished.connect(a.queue_free)


func _process(delta: float) -> void:
	_message_time -= delta
	if _result_panel and _result_panel.visible:
		_tick_result(delta)
	_message_label.visible = _message_time > 0.0
	if main == null or not main.ready_to_play:
		return
	var p = main.player
	_bind_feel(p)
	_update_heartbeat(delta, p)
	_update_feel_fx(delta, p)

	# --- 위쪽: 진행 상황
	var alive := 0
	var frozen := 0
	for s in main.survivors:
		if not s.is_dead:
			alive += 1
			if s.is_frozen:
				frozen += 1
	_top_label.text = "스테이지 %d    봉인석 %d / %d\n생존 %d / %d  (얼음 %d)    코인 %d" % [
		SaveData.stage, main.missions_done, main.mission_total,
		alive, main.survivors.size(), frozen, SaveData.coins]
	if main.escape_phase:
		var t := ceili(main.escape_left)
		_top_label.text += "\n탈출구가 열렸어요! 남은 시간 %d:%02d   탈출 %d명" % [t / 60, t % 60, main.survivors.filter(func(x): return x.escaped).size()]
	if main.raged:
		_top_label.text += "\n술래 폭주 중!"
	if main.seal_broken:
		_top_label.text += "\n봉인석 파괴됨! 술래를 모두 쓰러뜨려야 해요 (남은 술래 %d)" % main.seekers.filter(func(x): return not x.is_killed).size()
	if main.paint_time_left > 0.0:
		_top_label.text += "\n맵 물들이기 %d초" % ceili(main.paint_time_left)
	if main._blackout_left > 0.0:
		_top_label.text += "\n정전! %d초" % ceili(main._blackout_left)
	if main.daily_rule != "":
		_top_label.text += "\n오늘의 규칙: %s" % DailyRule.find(main.daily_rule).get("name", "")
	if p.bleed_time_left > 0.0:
		_top_label.text += "\n피를 흘리는 중! 술래가 따라와요 (%d초)" % ceili(p.bleed_time_left)
	if p.speed_multiplier() < 0.99:
		_top_label.text += "\n느려짐 (%d%%)" % int(p.speed_multiplier() * 100.0)

	_update_roster(delta, p)

	# --- 레트로 필터: 창 크기에 맞춰 거칠기를 일정하게 (큰 화면·전체화면에서도 같은 느낌)
	if _retro_mat:
		var vs := get_viewport().get_visible_rect().size
		_retro_mat.set_shader_parameter("pixel_res", vs * GameConfig.num("retro", "pixel_scale", 0.75))

	# --- 스태미나
	_update_stamina_bar(delta, p)

	# --- 화면 효과
	_camo.material.set_shader_parameter("strength", 0.5 if p.is_hidden_from_seeker() else 0.0)

	# --- 해동 게이지: 내가 얼었을 때 / 내가 동료를 녹이고 있을 때
	var thaw_time := GameConfig.num("player", "thaw_time", 10.0)
	var thaw_target: Survivor = null
	if p.is_frozen:
		thaw_target = p
	elif not p.is_dead:
		var reach := GameConfig.num("player", "unfreeze_distance", 1.8)
		for s in main.survivors:
			if s != p and s.is_frozen and not s.is_dead and p.global_position.distance_to(s.global_position) <= reach:
				thaw_target = s
				break
	var thaw_box := _thaw_bar.get_parent() as Control
	thaw_box.visible = thaw_target != null
	if thaw_target:
		_thaw_bar.max_value = thaw_time
		_thaw_bar.value = thaw_target.thaw_progress
		if thaw_target == p:
			_thaw_label.text = "해동 중... %.1f / %d초" % [p.thaw_progress, thaw_time] if p.thaw_progress > 0.0 \
					else "얼음! 동료가 옆에 %d초 있어야 풀려요" % thaw_time
		else:
			_thaw_label.text = "%s 해동 중... %.1f / %d초 (떨어지면 처음부터)" % [thaw_target.display_name, thaw_target.thaw_progress, thaw_time]

	# --- 아래쪽 가운데: 내 상태
	if p.turned_seeker:
		_status_label.text = _seeker_status(p)
	elif p.is_dead or p.escaped:
		_status_label.text = ("탈락! " if p.is_dead else "탈출 성공! ") + _spectate_text(p)
	elif p.fall_slow_left > 0.0 and not p.is_frozen:
		_status_label.text = "착지 충격! %.1f초 동안 %d%% 느려요" % [p.fall_slow_left, roundi(p.fall_slow_amount * 100.0)]
	elif p.is_frozen:
		_status_label.text = "[ 얼음 %d회 ]  술래에게 잡히지 않아요" % p.freeze_count
		if p.ice_left > 0.0:
			_status_label.text += "  —  %d초 안에 땡을 못 받으면 얼음이 깨져요!" % ceili(p.ice_left)
	elif p.has_meta("bandaged"):
		_status_label.text = "의사의 붕대에 끌려가는 중!"
	elif p.pulled_time_left > 0.0 and not p.has_meta("vaulting") and not p.has_meta("executing"):
		_status_label.text = "쇠사슬에 끌려가는 중!"
	elif p.is_blended():
		_status_label.text = "동화 중 %.1f초 - 움직일 수 없어요 (R: 취소)" % p.blend_time_left
	elif p.paint_time_left > 0.0:
		_status_label.text = "물들이기 중 %.1f초 - 술래가 나를 감지 못해요 (상호작용 불가)" % p.paint_time_left
	elif p.has_meta("executing"):
		_status_label.text = "처형인에게 붙잡혔어요!! 동료가 처형인을 기절시켜야 해요!"
	elif p.chained_by:
		_status_label.text = "사이코의 쇠사슬에 묶여 끌려가는 중... 동료가 풀어 줘야 해요"
	elif p.rooted_left > 0.0 and p.has_meta("floating"):
		_status_label.text = "하마의 무중력에 떠올랐어요! (%.1f초)" % p.rooted_left
	elif p.rooted_left > 0.0:
		_status_label.text = "거미줄에 묶였어요! (%.1f초) 얼음(Q)만 쓸 수 있어요" % p.rooted_left
	elif p.is_shadowed():
		_status_label.text = "그림자 속 %.1f초 - 감지·잡기 불가 (R: 나오기 · T: 동료 그림자로 건너가기)" % p.shadow_left
	elif p.in_locker:
		_status_label.text = "사물함에 숨는 중... (E: 나가기)  %d초가 넘으면 고양이가 울어요" % int(GameConfig.num("structure", "locker_cat_time", 30.0))
	elif _last_mobile(p):
		_status_label.text = "마지막으로 움직이는 생존자예요! 지금 얼음(Q)하면 모두 얼어서 패배해요"
	elif p.nearby_prop:
		_status_label.text = p.nearby_prop.call("prompt", p)
	elif p.nearby_web:
		_status_label.text = "[E] 거미줄 걷어내기"
	elif p.has_method("nearest_window") and p.can_interact() and p.is_on_floor() and _window_hint(p):
		_status_label.text = "[E] 창문 넘기 (2층 이상에서 뛰어내리면 잠깐 느려져요)"
	elif p.nearby_rat:
		_status_label.text = p.nearby_rat.get_meta("prompt", "[E] 쥐 잡기 (잡으면 술래가 위치를 알게 돼요)")
	elif p.is_repairing:
		_status_label.text = "미니게임 중... 술래를 조심하세요! (Esc: 그만두기)"
	elif p.nearby_generator and p.nearby_generator.busy_for(p):
		_status_label.text = "다른 동료가 가동 중인 봉인석이에요 — 다른 봉인석으로 흩어져요"
	elif p.nearby_generator:
		_status_label.text = "[E] 봉인석 미니게임 (%d / %d 단계)" % [p.nearby_generator.stages_done(), p.nearby_generator.stage_count()]
	elif p.is_in_grass():
		_status_label.text = "풀숲에 숨어 있어요"
	elif p.freeze_cooldown_left > 0.0:
		_status_label.text = "얼음 다시 쓰기까지 %.1f초" % p.freeze_cooldown_left
	elif p.freeze_count == int(GameConfig.num("freeze_rule", "limit_from", 4)) - 1 and not main.escape_phase:
		_status_label.text = "다음 얼음부터는 %d초 안에 땡을 못 받으면 얼음이 깨져요" % int(GameConfig.num("freeze_rule", "shatter_time", 60.0))
	else:
		_status_label.text = ""
	# [손맛] 안내 문구가 새로 뜨면 살짝 튀어나오듯
	var empty := _status_label.text == ""
	if _status_was_empty and not empty:
		_status_label.pivot_offset = _status_label.size * 0.5
		_status_label.scale = Vector2(0.86, 0.86)
		_status_label.modulate.a = 0.0
		var ptw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		ptw.tween_property(_status_label, "scale", Vector2.ONE, 0.22)
		ptw.tween_property(_status_label, "modulate:a", 1.0, 0.12)
	_status_was_empty = empty

	# --- 소환 창 (공간을 지배하는 자)
	_summon_label.visible = p.summon_menu_open
	if p.summon_menu_open:
		var lines := ["치료할 동료를 고르세요  (R: 취소)" if p.heal_menu else "소환할 동료를 고르세요  (T: 취소)"]
		for i in p.summon_candidates.size():
			var c = p.summon_candidates[i]
			var tag := ""
			if p.heal_menu:
				tag = "  (얼음 → 해동)" if c.is_frozen else "  (이동속도 +%d%%)" % int(GameConfig.num("medic", "heal_speed", 0.2) * 100)
			elif c.is_frozen:
				tag = "  (얼음)"
			lines.append("[%d] %s%s" % [i + 1, c.display_name, tag])
		_summon_label.text = "\n".join(lines)

	# --- 아래쪽 왼쪽: 캐릭터 고유 능력
	var info := CharacterDB.get_info(p.character_id)
	var ability_lines := [info["name"]]
	for slot in range(1, CharacterDB.slot_count(p.character_id) + 1):
		var key: String = ["R", "T", "Y"][slot - 1]
		var state: String
		var max_c := CharacterDB.max_charges(p.character_id, slot)
		var pid: String = p.character_id
		var arrows := -1
		if pid == "hunter":
			arrows = int(p.get("arrows_left"))
			if arrows < 0:
				arrows = main.seekers.size()
		if CharacterDB.is_passive(pid, slot):
			state = "패시브"
		elif pid == "bard":
			state = "♪ 연주 중 (다시 누르면 끔)" if p.get("song") == slot else "꺼짐"
		elif pid == "hunter" and slot == 2 and arrows == 0:
			state = "화살 없음"
		elif pid == "mechanic" and slot == 2 and p.item != "":
			state = "착용 중: %s (깨지면 다시 사용)" % Survivor.ITEM_NAMES[p.item]
		elif pid == "keeper" and slot == 2 and p.ability_cooldown_left[1] >= 9000.0:
			state = "탐색 중"
		elif max_c > 0:
			state = "%d / %d개" % [p.ability_charges[slot - 1], max_c]
			if p.ability_charges[slot - 1] < max_c:
				state += " (충전 %d초)" % ceili(p.ability_cooldown_left[slot - 1])
		elif p.ability_cooldown_left[slot - 1] > 0.0:
			state = "%d초" % ceili(p.ability_cooldown_left[slot - 1])
		else:
			state = "준비됨"
		# 쿨타임이 끝나는 순간: 짧은 알림음 + 능력 줄이 반짝
		var rdy := state == "준비됨" or state.begins_with("준비됨")
		var was = _ready_prev.get(slot, true)
		if rdy and not was and not p.is_dead:
			_ready_sfx.play()
			_ready_flash = 0.6
		_ready_prev[slot] = rdy
		if pid == "hunter" and slot == 2 and arrows > 0:
			state += "  (화살 %d발)" % arrows
		ability_lines.append("[%s] %s: %s" % [key, info["ability_%d" % slot], state])
	_ability_label.text = "\n".join(ability_lines)
	var turned: bool = p.turned_seeker != null and is_instance_valid(p.turned_seeker)
	if turned:
		_ability_label.text = _seeker_skill_text(p.turned_seeker, SaveData.show_help or main.round_time < 30.0 or _turned_t < 12.0)
		_turned_t += get_process_delta_time()
	_shared_label.visible = not turned
	if bool(main.get("is_traitor")) and not turned and not p.is_dead:
		_ability_label.text += "\n[B] 배신자 제보 — 술래(사람)에게 가까운 동료 위치를 알려요"
	# 술래 능력 칸이 높아지면 가운데 아래 안내를 그 위로 올림 (겹치지 않게)
	var shift := maxf(0.0, _ability_label.size.y - 70.0) if turned else 0.0
	var ob := lerpf(_status_label.offset_bottom, _status_base_bottom - shift, 0.25)
	if absf(ob - _status_label.offset_bottom) > 0.1 or shift > 0.0:
		_status_label.offset_bottom = ob
		_status_label.offset_top = ob - _status_label.get_combined_minimum_size().y
	if _ready_flash > 0.0:
		_ready_flash = maxf(0.0, _ready_flash - get_process_delta_time())
		var k := _ready_flash / 0.6
		_ability_label.modulate = Color(1, 1, 1).lerp(Color(0.6, 1.0, 1.4), k)
	else:
		_ability_label.modulate = Color(1, 1, 1)
	var help_on: bool = SaveData.show_help or (main != null and main.round_time < 30.0)
	if turned:
		help_on = SaveData.show_help or _turned_t < 12.0
	_help.text = HELP_SEEKER if turned else _help_survivor
	_help.visible = help_on
	_help_hint.visible = not help_on

	# --- 아래쪽 오른쪽: 상점 공통 능력
	var noise_text: String
	if not SaveData.has_ability("noise"):
		noise_text = "잠김"
	elif p.noise_cooldown_left > 0.0:
		noise_text = "%d초" % ceili(p.noise_cooldown_left)
	else:
		noise_text = "준비됨"
	var emote_text := "준비됨" if SaveData.has_ability("emote") else "잠김"
	if help_on:
		_shared_label.text = "공통 능력 (얼음 상태에서)\n[F] 소리 내기: %s\n[G] 이모티콘: %s\n이모트 (숫자키, 다시 누르면 멈춤)\n%s" % [noise_text, emote_text, _emote_slots_text()]
	else:
		_shared_label.text = "[F] 소리 내기: %s   [G] 이모티콘: %s\n이모트: 숫자키 1~0" % [noise_text, emote_text]


var _win_check_t := 0.0
var _win_near := false

## 창문 안내는 0.2초마다만 검사 (창문이 많아서)
func _window_hint(p) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _win_check_t > 0.2:
		_win_check_t = now
		_win_near = p.nearest_window() >= 0
	return _win_near


var _emote_text_cache := ""
var _emote_text_key := ""

## 장착한 이모트 칸 안내 (5칸씩 두 줄)
func _emote_slots_text() -> String:
	var key := str(SaveData.emote_slots)
	if key == _emote_text_key:
		return _emote_text_cache
	var parts := []
	for k in 10:
		var id: String = SaveData.emote_slots[k]
		var e := SaveData.emote_row(id)
		parts.append("[%d]%s" % [(k + 1) % 10, e[1] if not e.is_empty() else "-"])
	_emote_text_key = key
	_emote_text_cache = " ".join(parts.slice(0, 5)) + "\n" + " ".join(parts.slice(5, 10))
	return _emote_text_cache


## 술래로 변한 사람: 아래쪽 가운데 안내 (기척·멈춤 이유)
func _seeker_status(p) -> String:
	var sk = p.turned_seeker
	if sk.state == Seeker.State.DISABLED:
		return "봉인석이 모두 가동되어 술래가 봉인됐어요..."
	if sk.state == Seeker.State.KNOCKBACK or sk._stun_left > 0.0:
		return "술래가 기절했어요... 잠시 못 움직여요"
	if sk.seeker_type == "mannequin" and sk.poss_note_any(0) != "":
		return "누가 쳐다보고 있어요! 굳어서 못 움직여요  —  [R] 기습으로 빠져나가요"
	if sk.possessed_frozen():
		return "능력을 쓰는 중..."
	var near := INF
	for s in main.survivors:
		if s != p and not s.is_dead and not s.escaped and s.turned_seeker == null and not s.is_frozen:
			near = minf(near, s.global_position.distance_to(p.global_position))
	var sense := ""
	if near < 7.0:
		sense = "  ·  기척: 바로 근처!"
	elif near < 16.0:
		sense = "  ·  기척: 가까움"
	return "당신은 술래 [%s]  닿으면 잡아요  ·  Shift 추격  ·  [R] [T] 능력%s" % [Seeker.TYPE_NAMES.get(sk.seeker_type, "술래"), sense]


var _sk_ready_prev := [true, true]
var _roster: RichTextLabel
var _roster_t := 0.0


## 동료 목록 갱신 (0.25초마다): ● 이름  상태
func _update_roster(delta: float, p) -> void:
	_roster.position.y = _top_label.position.y + _top_label.size.y + 8.0
	_roster_t -= delta
	if _roster_t > 0.0:
		return
	_roster_t = 0.25
	var lines: Array = []
	for s in main.survivors:
		if not is_instance_valid(s):
			continue
		var col: Color = CharacterDB.get_info(s.character_id)["color"]
		var nm: String = s.display_name
		if nm.length() > 12:
			nm = nm.left(11) + "…"
		var st := ""
		var name_col := "e8ecf2"
		if s.turned_seeker != null:
			st = "[color=#ff5a4a]술래[/color]"
			name_col = "ff9a8a"
		elif s.is_dead:
			st = "[color=#8a93a3]탈락[/color]"
			name_col = "6a7383"
		elif s.escaped:
			st = "[color=#7dffb0]탈출[/color]"
		elif s.has_meta("executing"):
			st = "[color=#ff5a4a]처형 중![/color]"
		elif s.chained_by:
			st = "[color=#ffb070]사슬[/color]"
		elif s.is_frozen:
			st = "[color=#7fd6ff]얼음%s[/color]" % (" %d초" % ceili(s.ice_left) if s.ice_left > 0.0 else "")
		var me := " [color=#7fd6ff](나)[/color]" if s == p and nm != "나" else ""
		if s == p and nm == "나" and not s.is_dead:
			name_col = "7fd6ff"
		lines.append("[color=#%s]●[/color] [color=#%s]%s[/color]%s  %s" % [col.to_html(false), name_col, nm, me, st])
	_roster.text = "\n".join(lines)
var _status_base_bottom := 0.0
## 술래로 변한 뒤 지난 시간 (처음 12초는 능력 설명을 자세히)
var _turned_t := 0.0
var _help_survivor := ""
const HELP_SEEKER := "술래 조작\nWASD 이동 · Shift 추격 속도 · 마우스 시점\n생존자에게 닿으면 공격 → 맞으면 잡힘 (얼음 상태는 무적)\n[R] [T] 술래 능력 · 붉은 화면이 짙어지면 생존자가 가까워요\nF1 도움말 켜기/끄기"

## 술래로 변한 사람: 아래쪽 왼쪽 능력 칸 (술래 종류별 [R] [T] + 패시브)
func _seeker_skill_text(sk, detail := true) -> String:
	var lines: Array = ["술래 · %s" % Seeker.TYPE_NAMES.get(sk.seeker_type, "")]
	var cm: float = sk.crowd_mult()
	if cm > 1.001:
		lines[0] += "   (인원 보정: 이동속도 +%d%%)" % roundi((cm - 1.0) * 100.0)
	var skills: Array = sk.poss_skills()
	for n in 2:
		var cd: float = sk.poss_cd(n)
		var st := "준비됨" if cd <= 0.0 else "%d초" % ceili(cd)
		var note: String = sk.poss_note_any(n)
		if note != "":
			st += "  (%s)" % note
		if cd <= 0.0 and not _sk_ready_prev[n]:
			_ready_sfx.play()
			_ready_flash = 0.6
		_sk_ready_prev[n] = cd <= 0.0
		lines.append("[%s] %s: %s" % [["R", "T"][n], skills[n][0], st])
		if detail:
			lines.append("     %s" % skills[n][1])
	var pas: String = Seeker.TYPE_PASSIVES.get(sk.seeker_type, "")
	if pas != "":
		lines.append("패시브: " + pas)
	return "\n".join(lines)


## 술래가 heartbeat_distance(6m) 안에 오면 두근두근. 가까울수록 빠르고 크게, 화면이 붉게 조여옴
func _update_heartbeat(delta: float, p) -> void:
	var near := INF
	if not p.is_dead and p.turned_seeker == null:
		for sk in main.seekers:
			if sk.is_active() and not sk.is_disguised():  # 변신한 마녀는 심장이 안 뜀 (속이기)
				near = minf(near, p.global_position.distance_to(sk.global_position))
	var hear := GameConfig.num("horror", "heartbeat_distance", 6.0)
	var hunter: bool = not p.is_dead and p.turned_seeker != null
	if hunter:
		# 술래로 변한 사람: 먹잇감(움직이는 생존자)이 가까우면 사냥감의 심장 소리가 들림
		for s in main.survivors:
			if s != p and not s.is_dead and not s.escaped and s.turned_seeker == null and not s.is_frozen:
				near = minf(near, p.global_position.distance_to(s.global_position))
		hear = 9.0
	var k := clampf(1.0 - near / hear, 0.0, 1.0) if near < hear else 0.0
	_heart_timer -= delta
	if near < hear and _heart_timer <= 0.0:
		_heart_timer = lerpf(0.85, 0.4, k)
		_heart.volume_db = lerpf(-4.0, 3.0, k)
		_heart.play()
	var pulse := maxf(0.0, 1.0 - (lerpf(0.85, 0.4, k) - _heart_timer) * 4.0) if near < hear else 0.0
	k = maxf(k, 0.25) if near < hear else 0.0
	# [손맛] 나를 쫓는 중이면 멀리 있어도 붉은 테두리가 은근히 남음 (추격 레이어와 같이)
	if _feel_bound and is_instance_valid(_feel_bound):
		k = maxf(k, float(_feel_bound.get("chase_vol")) * 0.3)
	var str_v := k * 0.55 + pulse * k * 0.35
	if hunter:
		str_v = minf(0.3, 0.08 + k * 0.16 + pulse * k * 0.1)  # 술래 시야: 늘 은은하게 붉음 (너무 빨갛지 않게)
	_danger.material.set_shader_parameter("strength", str_v)


# ---------------------------------------------------------------- [손맛] 화면 피드백

## 내 캐릭터의 feel_fx 신호를 한 번만 연결
func _bind_feel(p) -> void:
	var f: Node = p.get("feel")
	if f == _feel_bound or f == null:
		return
	_feel_bound = f
	f.connect("hud_event", _on_feel_event)


func _on_feel_event(kind: StringName, amount: float) -> void:
	var m := GameConfig.num("feel", "hud_flash", 1.0)
	match kind:
		&"caught":
			_flash_level = 1.0 * m
			_hurt_level = 1.0 * m
		&"near":
			_hurt_level = maxf(_hurt_level, (0.35 + 0.4 * amount) * m)
			_flash_level = maxf(_flash_level, 0.25 * amount * m)
		&"chase":
			_hurt_level = maxf(_hurt_level, 0.45 * m)
		&"punch":
			_gold_level = maxf(_gold_level, 0.25 * amount * m)
		&"stage":
			_gold_level = maxf(_gold_level, 0.55 * m)
		&"freeze":
			_frost_prog = minf(_frost_prog, 0.05)  # 가장자리부터 새로 번짐
			_frost_crack = 0.0
		&"thaw":
			_frost_crack = 1.0  # 금이 쫙 가면서 서리가 빠르게 물러남


## 붉은 맥동, 금빛 테두리, 서리, 배너
func _update_feel_fx(delta: float, p) -> void:
	_fx_t += delta
	_hurt_level = maxf(0.0, _hurt_level - delta * 0.75)
	_flash_level = maxf(0.0, _flash_level - delta * 2.4)
	_gold_level = maxf(0.0, _gold_level - delta * 1.1)
	var hp := _hurt_level * (0.8 + 0.2 * sin(_fx_t * 9.0))
	_hurt.visible = _hurt_level > 0.0
	_hurt.material.set_shader_parameter("strength", hp * 0.85)
	_red_flash.visible = _flash_level > 0.0
	_red_flash.color.a = _flash_level * 0.42
	_gold.visible = _gold_level > 0.0
	_gold.material.set_shader_parameter("strength", _gold_level * 0.5)
	# 서리: 얼면 1.2초에 걸쳐 가장자리에서 번져 들어오고, 땡 받으면 금이 가며 빠르게 물러남
	var amt := GameConfig.num("feel", "frost_overlay", 1.0)
	var frost_on: bool = p.is_frozen and not p.is_dead and amt > 0.0
	_frost_prog = move_toward(_frost_prog, 1.0 if frost_on else 0.0, delta * (0.85 if frost_on else 2.2))
	if frost_on:
		_frost_crack = clampf(p.thaw_progress / maxf(0.1, GameConfig.num("player", "thaw_time", 10.0)), 0.0, 1.0) * 0.85
	_frost.visible = _frost_prog > 0.001
	if _frost.visible:
		var ease_p := 1.0 - pow(1.0 - _frost_prog, 2.2)
		_frost.material.set_shader_parameter("progress", ease_p * amt)
		_frost.material.set_shader_parameter("crack", _frost_crack)
	# 배너: 봉인석 가동 / 탈출구 열림
	if _missions_seen < 0:
		_missions_seen = main.missions_done
		_escape_seen = main.escape_phase
	if main.missions_done > _missions_seen:
		_missions_seen = main.missions_done
		_show_banner("봉인석 가동", "%d / %d" % [main.missions_done, main.mission_total], Color(1.0, 0.86, 0.5))
	if main.escape_phase and not _escape_seen:
		_escape_seen = true
		_show_banner("탈출구가 열렸어요", "서둘러요!", Color(0.6, 1.0, 0.75))


func _show_banner(title: String, sub: String, col: Color) -> void:
	_banner.text = title
	_banner_sub.text = sub
	_banner.add_theme_color_override("font_color", col)
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.35, 1.35)
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_banner_tw = create_tween()
	_banner_tw.set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.45)
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	_banner_tw.tween_property(_banner_sub, "modulate:a", 0.85, 0.4).set_delay(0.2)
	_banner_tw.chain().tween_interval(1.8)
	_banner_tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.6)
	_banner_tw.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.6)
	_gold_level = maxf(_gold_level, 0.4)


## 스태미나 막대: 부드럽게 줄고, 줄어든 만큼 흰 잔상이 따라오고, 적으면 깜빡이며, 가득 차 있으면 흐려짐
func _update_stamina_bar(delta: float, p) -> void:
	var ratio := clampf(p.stamina / GameConfig.num("stamina", "max", 100.0), 0.0, 1.0)
	_stamina_shown = lerpf(_stamina_shown, ratio, 1.0 - exp(-14.0 * delta))
	if ratio >= _stamina_ghost_v:
		_stamina_ghost_v = _stamina_shown
		_stamina_ghost_wait = 0.4
	else:
		_stamina_ghost_wait -= delta
		if _stamina_ghost_wait <= 0.0:
			_stamina_ghost_v = move_toward(_stamina_ghost_v, ratio, delta * 0.5)
	_stamina_fill.size.x = 256.0 * _stamina_shown
	_stamina_ghost.size.x = 256.0 * maxf(_stamina_ghost_v, _stamina_shown)
	var low: bool = ratio < 0.25 or p.exhausted
	var base_col: Color = Color(1.0, 0.3, 0.2) if p.exhausted else Color(1.0, 0.85, 0.2).lerp(Color(1.0, 0.5, 0.15), clampf((0.4 - ratio) / 0.4, 0.0, 1.0))
	var pulse := 0.5 + 0.5 * sin(_fx_t * (9.0 if p.exhausted else 6.0))
	_stamina_fill.color = base_col.lerp(Color(1, 1, 1), pulse * 0.25) if low else base_col
	_stamina_bg.color = Color(0.25 * pulse, 0, 0, 0.6) if low else Color(0, 0, 0, 0.55)
	# 오래 가득 차 있으면 흐리게 (화면을 덜 가림)
	_stamina_idle = _stamina_idle + delta if ratio >= 0.999 else 0.0
	var want_a := 0.35 if _stamina_idle > 1.5 else 1.0
	_stamina_bg.modulate.a = move_toward(_stamina_bg.modulate.a, want_a, delta * 2.5)
	_stamina_bg.visible = not p.is_dead and not p.escaped and p.turned_seeker == null


var _settings: Node = null

func _unhandled_input(event: InputEvent) -> void:
	if _settings and is_instance_valid(_settings):
		return  # 설정 창이 열려 있으면 Esc 는 설정 창이 닫는 데 씀
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		SaveData.show_help = not SaveData.show_help
		SaveData.save_game()
		return
	if event.is_action_pressed("pause") and main and main.ready_to_play and not _result_panel.visible:
		_set_paused(not get_tree().paused)


## 맵 안에서 나만 움직일 수 있는지 (나까지 얼면 즉시 패배)
func _last_mobile(p) -> bool:
	if main == null or p.is_frozen or main.escape_phase:
		return false
	var others := 0
	var inside := 0
	for s in main.survivors:
		if s.is_dead or s.escaped or s.turned_seeker != null:
			continue
		inside += 1
		if s != p and not s.is_frozen:
			others += 1
	return inside > 1 and others == 0


func _set_paused(paused: bool) -> void:
	if not Net.in_match():  # 멀티에서는 게임을 멈추지 않고 메뉴만 띄움
		get_tree().paused = paused
	_pause_panel.visible = paused
	if main and main.player and "ui_block" in main.player:
		main.player.ui_block = paused and Net.in_match()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


## 관전 안내: 누구를 보는지 + 그 대상 상태 + 조작법
func _spectate_text(p) -> String:
	var keys := "\n[좌클릭] 다음  [우클릭] 이전  [V] 자유 시점 (WASD·Space·Ctrl·Shift)"
	if p.spectate_free:
		return "관전 · 자유 시점" + keys
	var t: Node3D = p.spectate_target
	if t == null or not is_instance_valid(t):
		return "관전할 대상이 없어요" + keys
	if t is Seeker:
		var st := "추격 중!" if (t as Seeker).chase_target else "순찰 중"
		return "관전 · 술래 시점 (%s)" % st + keys
	var s := t as Survivor
	var st2 := "얼음 (%.0f초 남음)" % s.ice_left if s.is_frozen and s.ice_left > 0.0 else ("얼음" if s.is_frozen else ("사물함 속" if s.in_locker else "이동 중"))
	return "관전 · %s · %s" % [s.display_name, st2] + keys


## main.gd가 판이 끝나면 불러 줍니다.
## rows = main._stats_rows() (생존자별 기록). 비어 있으면 글자만 보여 줌
func show_result(win: bool, title: String, details: String, rows: Array = [], coins := -1) -> void:
	_pause_panel.visible = false
	_result_title.text = ("승리 · " if win else "패배 · ") + title
	_result_title.modulate = Color(0.55, 1, 0.65) if win else Color(1, 0.5, 0.5)
	_result_sub.text = str(main.get("map_name")) if main else ""
	_result_body.text = details
	_fill_stats(rows)
	_message_time = 0.0
	_result_dim.visible = true
	_result_dim.modulate.a = 0.0
	create_tween().tween_property(_result_dim, "modulate:a", 1.0, 0.5)
	_coin_target = maxi(coins, 0)
	_coin_shown = 0.0
	_coin_label.visible = coins >= 0
	# 등장 연출: 살짝 커지며 나타나고, 표 줄이 하나씩 차례로
	_result_panel.pivot_offset = _result_panel.size * 0.5
	_result_panel.modulate.a = 0.0
	_result_panel.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_result_panel, "modulate:a", 1.0, 0.35)
	tw.tween_property(_result_panel, "scale", Vector2.ONE, 0.45)
	var i := 0
	for c in _stats_grid.get_children():
		var ctl := c as Control
		ctl.modulate.a = 0.0
		var row_i := i / _stats_grid.columns
		var step := 0.18 if _stats_grid.get_child_count() <= 6 * 6 else 0.1  # 8명이면 더 빠르게
		create_tween().tween_property(ctl, "modulate:a", 1.0, 0.25).set_delay(0.35 + row_i * step)
		i += 1
	_result_retry.text = "다음 스테이지" if win else "다시 하기"
	if Net.in_match():
		# 멀티: 방은 유지된 채 로비로. 방장은 바로 다음 판도 가능
		_result_retry.text = "다음 판 바로 시작"
		_result_retry.visible = Net.is_host()
		_result_menu.text = "로비로 (모두 함께)" if Net.is_host() else "로비로"
	_result_panel.visible = true


# ---------------------------------------------------------------- UI 만들기 도우미

func _make_overlay(parent: Control, tint: Color, strength: float, inner: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("strength", strength)
	mat.set_shader_parameter("inner", inner)
	rect.material = mat
	parent.add_child(rect)
	return rect


func _card(l: Label) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.035, 0.05, 0.55)
	sb.border_color = Color(0.5, 0.6, 0.75, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	l.add_theme_stylebox_override("normal", sb)
	l.add_theme_constant_override("outline_size", 4)


func _make_label(parent: Control, font_size: int, preset: Control.LayoutPreset) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, 20)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset in [
		Control.PRESET_CENTER, Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM] else (
		Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]
		else Control.GROW_DIRECTION_END)
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_CENTER_BOTTOM, Control.PRESET_BOTTOM_RIGHT] else (
		Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER else Control.GROW_DIRECTION_END)
	return label


func _make_panel(parent: Control) -> Array:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 32)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	panel.visible = false
	return [panel, box]


func _make_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 48)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(on_pressed)
	parent.add_child(b)
	return b


func _build_pause_panel(root: Control) -> void:
	var made := _make_panel(root)
	_pause_panel = made[0]
	var box: VBoxContainer = made[1]
	var title := Label.new()
	title.text = "일시정지"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_make_button(box, "계속하기", func() -> void: _set_paused(false))
	_make_button(box, "설정", func() -> void:
		var sp := SettingsPanel.new()
		_pause_panel.get_parent().add_child(sp)
		_settings = sp)
	_make_button(box, "버그 신고 (F8)", func() -> void:
		var path := CrashLog.make_report("일시정지 메뉴에서 신고")
		show_message("버그 리포트 저장 완료 (경로 복사됨)\n" + ProjectSettings.globalize_path(path), 5.0))
	_make_button(box, ("로비로 (모두 함께, 방 유지)" if Net.is_host() else "로비로 (방 유지, 내 자리는 봇이)") if Net.in_match() else "메뉴로 (이번 판 포기)", _go_menu)


func _build_result_panel(root: Control) -> void:
	var made := _make_panel(root)
	_result_panel = made[0]
	var box: VBoxContainer = made[1]
	_result_box = box
	_result_dim = ColorRect.new()
	_result_dim.color = Color(0.0, 0.0, 0.02, 0.72)
	_result_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_dim.visible = false
	root.add_child(_result_dim)
	root.move_child(_result_dim, _result_panel.get_index())
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.11, 0.94)
	sb.border_color = Color(0.45, 0.5, 0.9, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	_result_panel.add_theme_stylebox_override("panel", sb)
	_result_title = Label.new()
	_result_title.add_theme_font_size_override("font_size", 38)
	_result_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_result_title.add_theme_constant_override("outline_size", 8)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_title)
	_result_sub = Label.new()
	_result_sub.add_theme_font_size_override("font_size", 16)
	_result_sub.modulate = Color(0.75, 0.75, 0.85)
	_result_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_result_sub)
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 22)
	box.add_child(mid)
	_build_mvp_card(mid)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(right)
	_stats_grid = GridContainer.new()
	_stats_grid.columns = 6
	_stats_grid.add_theme_constant_override("h_separation", 18)
	_stats_grid.add_theme_constant_override("v_separation", 6)
	right.add_child(_stats_grid)
	right.add_child(HSeparator.new())
	_result_body = Label.new()
	_result_body.add_theme_font_size_override("font_size", 17)
	_result_body.custom_minimum_size = Vector2(520, 0)
	_result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_result_body)
	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 26)
	_coin_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	right.add_child(_coin_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_result_retry = _make_button(buttons, "다시 하기", _restart)
	_result_menu = _make_button(buttons, "메뉴로", _go_menu)


## MVP 카드: 3D 미리보기 속 캐릭터가 신나게 춤춤 + 이름 + 뽑힌 이유
func _build_mvp_card(parent: Control) -> void:
	_mvp_card = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.13, 0.05, 0.9)
	sb.border_color = Color(1.0, 0.8, 0.25)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_mvp_card.add_theme_stylebox_override("panel", sb)
	parent.add_child(_mvp_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_mvp_card.add_child(v)
	var star := Label.new()
	star.text = "★ MVP ★"
	star.add_theme_font_size_override("font_size", 24)
	star.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(star)
	var svc := SubViewportContainer.new()
	svc.custom_minimum_size = Vector2(220, 250)
	svc.stretch = true
	v.add_child(svc)
	_mvp_view = SubViewport.new()
	_mvp_view.own_world_3d = true
	_mvp_view.transparent_bg = true
	_mvp_view.msaa_3d = Viewport.MSAA_4X
	svc.add_child(_mvp_view)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.75)
	env.environment.ambient_light_energy = 0.7
	_mvp_view.add_child(env)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, 3.6)
	cam.fov = 38
	_mvp_view.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.2
	_mvp_view.add_child(key)
	var gold := OmniLight3D.new()
	gold.position = Vector3(-1.2, 2.0, -1.0)
	gold.light_color = Color(1.0, 0.8, 0.35)
	gold.light_energy = 2.0
	gold.omni_range = 5.0
	_mvp_view.add_child(gold)
	_mvp_name = Label.new()
	_mvp_name.add_theme_font_size_override("font_size", 20)
	_mvp_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_mvp_name)
	_mvp_why = Label.new()
	_mvp_why.add_theme_font_size_override("font_size", 14)
	_mvp_why.modulate = Color(0.9, 0.85, 0.7)
	_mvp_why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mvp_why.custom_minimum_size = Vector2(220, 0)
	_mvp_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_mvp_why)


## 기록 표 채우기: 이름 / 땡 / 봉인석 / 회피 / 생존 시간 / 결과. 항목마다 1등은 금색
func _fill_stats(rows: Array) -> void:
	for c in _stats_grid.get_children():
		c.queue_free()
	_mvp_card.visible = not rows.is_empty()
	_stats_grid.visible = not rows.is_empty()
	if rows.is_empty():
		return
	var heads := ["생존자", "땡", "봉인석", "회피", "생존", "결과"]
	for h in heads:
		var l := Label.new()
		l.text = h
		l.add_theme_font_size_override("font_size", 15)
		l.modulate = Color(0.65, 0.68, 0.85)
		_stats_grid.add_child(l)
	var best := {"rescues": 0.0, "stages": 0.0, "dodges": 0.0, "alive": 0.0}
	for r in rows:
		for k in best:
			best[k] = maxf(best[k], float(r[k]))
	var mvp: Dictionary = {}
	for r in rows:
		if r.get("mvp", false):
			mvp = r
	for r in rows:
		var me: bool = r.get("me", false)
		var name_l := Label.new()
		name_l.text = ("★ " if r.get("mvp", false) else "") + str(r["name"]) + (" (나)" if me and str(r["name"]) != "나" else "")
		name_l.add_theme_color_override("font_color", (r["color"] as Color).lightened(0.35))
		_stats_grid.add_child(name_l)
		for k in ["rescues", "stages", "dodges", "alive"]:
			var l := Label.new()
			var val := float(r[k])
			if k == "alive":
				l.text = "%d:%02d" % [int(val) / 60, int(val) % 60]
			elif k == "stages":
				l.text = "%.1f" % val
			else:
				l.text = str(int(val))
			if val > 0.0 and is_equal_approx(val, best[k]):
				l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_stats_grid.add_child(l)
		var res := Label.new()
		res.text = str(r["result"])
		res.add_theme_color_override("font_color", {"탈출": Color(0.5, 1, 0.7), "생존": Color(0.7, 0.9, 1), "탈락": Color(1, 0.5, 0.5)}.get(res.text, Color.WHITE))
		_stats_grid.add_child(res)
	# MVP 미리보기
	if _mvp_body:
		_mvp_body.queue_free()
		_mvp_body = null
	if mvp.is_empty():
		_mvp_card.visible = false
		return
	_mvp_body = ClayBody.new()
	_mvp_view.add_child(_mvp_body)
	_mvp_body.build(str(mvp["char"]), mvp.get("cos", {}))
	_mvp_body.emote = "disco"
	_mvp_name.text = str(mvp["name"])
	_mvp_why.text = _mvp_reason(mvp, best)


func _mvp_reason(r: Dictionary, best: Dictionary) -> String:
	var bits: Array[String] = []
	if float(r["rescues"]) > 0.0 and is_equal_approx(float(r["rescues"]), best["rescues"]):
		bits.append("땡 최다 %d번" % int(r["rescues"]))
	if float(r["stages"]) > 0.0 and is_equal_approx(float(r["stages"]), best["stages"]):
		bits.append("봉인석 최다")
	if float(r["dodges"]) > 0.0 and is_equal_approx(float(r["dodges"]), best["dodges"]):
		bits.append("회피 최다")
	if r["result"] == "탈출":
		bits.append("탈출 성공")
	if bits.is_empty():
		bits.append("가장 오래 버팀")
	return " · ".join(bits)


func _tick_result(delta: float) -> void:
	if _mvp_body and is_instance_valid(_mvp_body):
		_mvp_body.animate(delta, 0.0, false)
		_mvp_body.rotation.y = sin(Time.get_ticks_msec() * 0.0008) * 0.5
	if _coin_label.visible:
		_coin_shown = move_toward(_coin_shown, _coin_target, maxf(30.0, _coin_target * 0.8) * delta)
		_coin_label.text = "획득 코인 +%d" % int(_coin_shown)


func _restart() -> void:
	if Net.in_match():
		if Net.is_host():
			Net.start_match()  # 멀티: 방장이 다음 판 시작 → 모두 같이 이동
		return
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_menu() -> void:
	if Net.in_match():
		Net.return_to_lobby()  # 멀티: 방을 깨지 않고 로비로
		return
	if Net.active:
		Net.leave()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(MENU_SCENE)
