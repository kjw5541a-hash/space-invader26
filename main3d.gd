# Space Invader 2.5D - Godot 4 / Neon / Stage + Boss patterns
# 조작: 키보드 좌우(방향키/AD) + 하단 터치 버튼. 발사 자동.
# 로직 좌표는 2D와 동일 수치, 화면은 틸트 카메라 + 3D 메시로 렌더.
extends Node3D

const HW := 240.0
const HH := 360.0
const FIRE_INTERVAL := 0.22
const PLAYER_SPEED := 360.0
const PLAYER_X_LIM := 220.0
const PLAYER_Z := 270.0
const EDGE := 216.0
const INVADE_Z := 240.0
const CAM_POS := Vector3(0, 470, 470)
const CAM_LOOK := Vector3(0, 0, -20)
const TOUCH_SPEED_FACTOR := 0.55

var score := 0
var wave := 0
var max_hp := 4
var hp := 4
var game_over := false
var invincible_t := 0.0
var blink_t := 0.0
var next_wave_cd := -1.0
var elapsed := 0.0
var shake := 0.0
var move_dir := 0.0

var cam: Camera3D = null
var player: Node3D = null
var player_alive := true
var enemies: Array = []
var p_bullets: Array = []
var e_bullets: Array = []
var shards: Array = []

var enemy_dir := 1.0
var enemy_speed := 42.0
var drop_cd := 0.0
var fire_cd := 1.0
var fire_interval := 0.9
var bullet_speed := 260.0

var boss: Node3D = null
var boss_pattern := -1
var boss_ptime := 0.0
var boss_pinterval := 3.6
var boss_bspeed := 220.0
var boss_tx := 0.0
var boss_tt := 0.0
var spiral_on := false
var spiral_t := 0.0
var spiral_emit := 0.0
var spiral_ang := 0.0
var wall_on := false
var wall_t := 0.0
var wall_emit := 0.0
var wall_gap := 0.0

var touch_left := false
var touch_right := false
var _fire_accum := 0.0
var _msg_t := -1.0

var score_label: Label = null
var wave_label: Label = null
var hp_bar: ProgressBar = null
var hp_label: Label = null
var msg_label: Label = null
var boss_bar: ProgressBar = null
var ui_font: Font = null

var sfx_streams := {}
var sfx_pool: Array = []
var sfx_vol := {
	"shoot": -16.0, "enemy_shoot": -26.0, "explosion": -14.0,
	"hit": -10.0, "wave": -12.0, "boss": -11.0, "gameover": -9.0, "tick": -15.0,
	"bossdown": -13.0, "boss_shoot": -16.0, "boss_hit": -14.0,
}
var bgm_stage: AudioStreamPlayer = null
var bgm_boss: AudioStreamPlayer = null
var bgm_want := "stage"
var _bgm_unlocked := false

# 공용 머티리얼
var m_player: StandardMaterial3D
var m_player_glow: StandardMaterial3D
var m_white: StandardMaterial3D
var m_e1: StandardMaterial3D
var m_e1_glow: StandardMaterial3D
var m_dark: StandardMaterial3D
var m_e2: StandardMaterial3D
var m_e2_glow: StandardMaterial3D
var m_core_red: StandardMaterial3D
var m_boss: StandardMaterial3D
var m_boss_glow: StandardMaterial3D
var m_core_yellow: StandardMaterial3D
var m_bullet_p: StandardMaterial3D
var m_bullet_e: StandardMaterial3D
var m_bullet_p_glow: StandardMaterial3D
var m_bullet_core: StandardMaterial3D
var m_bullet_e_glow: StandardMaterial3D
var m_bullet_hot: StandardMaterial3D
var m_orb: StandardMaterial3D
var m_needle: StandardMaterial3D
var m_star: StandardMaterial3D
var m_weaver: StandardMaterial3D
var m_weaver_glow: StandardMaterial3D
var m_tank: StandardMaterial3D
var m_tank_glow: StandardMaterial3D
var m_core_orange: StandardMaterial3D
var m_canopy: StandardMaterial3D
var m_engine: StandardMaterial3D
var m_tip: StandardMaterial3D
var m_boss_hull: StandardMaterial3D
var m_boss_armor: StandardMaterial3D
var m_spike: StandardMaterial3D
var boss_core_mat: StandardMaterial3D = null
var snipe_on := false
var snipe_t := 0.0
var snipe_emit := 0.0
var snipe_n := 0
var _boss_hit_cd := 0.0
var sweep_on := false
var sweep_t := 0.0
var sweep_emit := 0.0

# ---------- 로그라이크 스킬 (단일 풀, wave 클리어마다 3택1) ----------
var player_fire_interval := 0.22
var p_bullet_speed := 560.0
var player_speed := 360.0
var player_hit_r := 15.0
var invincible_dur := 2.0
var e_bullet_mult := 1.0
var p_damage := 1.0
var proj_count := 1
var pierce := 0
var shield := 0
var aoe_level := 0
var aoe_cd := 0.0
const AOE_BASE_CD := 2.0
const AOE_RADIUS := 110.0
const SHIELD_R := 34.0
var shield_dome: MeshInstance3D = null
var skill_open := false
var skill_layer: CanvasLayer = null
var skill_title: Label = null
var skill_btns: Array = []
var started := false
var title_layer: CanvasLayer = null
var title_hint: Label = null
var ui_layer: CanvasLayer = null
var popups: Array = []
var muzzles: Array = []
var hit_flash: ColorRect = null
var flash_a := 0.0
var flash_col := Color(1, 0.2, 0.3)
var lowhp_rect: ColorRect = null

var star_mm: MultiMesh = null
var star_data: Array = []
const STAR_N := 130


func _ready() -> void:
	_build_world()
	_build_materials()
	_build_starfield()
	_build_deep_space()
	_build_audio()
	_build_ui()
	_build_skill_ui()
	_build_player()
	_build_title()


# ---------- 월드/카메라 ----------

func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.6)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.15
	add_child(sun)
	cam = Camera3D.new()
	cam.position = CAM_POS
	cam.fov = 60.0
	cam.current = true
	add_child(cam)
	cam.look_at(CAM_LOOK)


func _neon(color: Color, energy: float = 1.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = energy
	return m


func _neon_trans(color: Color, alpha: float = 0.22) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 1.2
	return m


func _build_materials() -> void:
	m_player = _neon(Color(0, 1, 1))
	m_player_glow = _neon_trans(Color(0, 1, 1))
	m_white = _neon(Color(1, 1, 1), 1.5)
	m_e1 = _neon(Color(1, 0.3, 1))
	m_e1_glow = _neon_trans(Color(1, 0.3, 1))
	m_dark = _neon(Color(0.03, 0.03, 0.08), 0.4)
	m_e2 = _neon(Color(1, 0.62, 0.05))
	m_e2_glow = _neon_trans(Color(1, 0.45, 0.1))
	m_core_red = _neon(Color(1, 0.15, 0.15))
	m_boss = _neon(Color(1, 0.13, 0.33))
	m_boss_glow = _neon_trans(Color(1, 0.13, 0.33), 0.28)
	m_core_yellow = _neon(Color(1, 0.9, 0.2))
	m_bullet_p = _neon(Color(0, 1, 1), 2.2)
	m_bullet_e = _neon(Color(1, 0.27, 0.53), 2.2)
	m_bullet_p_glow = _neon_trans(Color(0.1, 0.6, 1), 0.35)
	m_bullet_core = _neon(Color(0.85, 1, 1), 2.6)
	m_bullet_e_glow = _neon_trans(Color(1, 0.15, 0.35), 0.35)
	m_bullet_hot = _neon(Color(1, 0.85, 0.9), 2.6)
	m_orb = _neon(Color(1, 0.12, 0.25), 2.0)
	m_needle = _neon(Color(0.65, 0.05, 0.15), 2.2)
	m_star = _neon(Color(0.4, 0.42, 0.62), 0.45)
	m_weaver = _neon(Color(0.2, 1, 0.55))
	m_weaver_glow = _neon_trans(Color(0.2, 1, 0.55))
	m_tank = _neon(Color(0.62, 0.25, 1))
	m_tank_glow = _neon_trans(Color(0.62, 0.25, 1))
	m_core_orange = _neon(Color(1, 0.55, 0.1))
	m_canopy = _neon(Color(0.1, 0.25, 0.9), 1.2)
	m_engine = _neon(Color(1, 0.35, 0.9), 2.4)
	m_tip = _neon(Color(1, 0.95, 0.3), 2.0)
	m_boss_hull = _neon(Color(0.45, 0.03, 0.1), 1.4)
	m_boss_armor = _neon(Color(0.25, 0.02, 0.08), 1.0)
	m_spike = _neon(Color(0.7, 0.08, 0.15), 1.6)


func _box(sx: float, sy: float, sz: float, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sx, sy, sz)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _build_starfield() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.2, 1.2, 6.0)
	star_mm = MultiMesh.new()
	star_mm.transform_format = MultiMesh.TRANSFORM_3D
	star_mm.mesh = mesh
	star_mm.instance_count = STAR_N
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = star_mm
	mmi.material_override = m_star
	add_child(mmi)
	for i in range(STAR_N):
		star_data.append({
			"x": randf_range(-260, 260),
			"y": randf_range(-40, 220),
			"z": randf_range(-380, 380),
			"sp": randf_range(100, 260),
		})
		_update_star(i)


func _update_star(i: int) -> void:
	var s: Dictionary = star_data[i]
	star_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(s["x"], s["y"], s["z"])))


func _ship(path: String, s: float, face_player: bool = false) -> Node3D:
	var n := Node3D.new()
	var res = load(path)
	if res is PackedScene:
		n.add_child((res as PackedScene).instantiate())
	elif res is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = res
		n.add_child(mi)
	n.scale = Vector3.ONE * s
	if face_player:
		n.rotation.y = PI
	return n


func _sprite3d(path: String, pos: Vector3, world_size: float, alpha: float) -> Sprite3D:
	var sp := Sprite3D.new()
	var tex := load(path) as Texture2D
	sp.texture = tex
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sp.pixel_size = world_size / float(tex.get_width())
	sp.position = pos
	sp.modulate = Color(1, 1, 1, alpha)
	add_child(sp)
	return sp


func _build_deep_space() -> void:
	_sprite3d("res://assets/kenney/nebula.png", Vector3(0, 80, -880), 1500.0, 0.32)
	_sprite3d("res://assets/kenney/planets/planet00.png", Vector3(-200, 100, -720), 220.0, 0.5)
	_sprite3d("res://assets/kenney/planets/planet03.png", Vector3(205, 20, -830), 150.0, 0.45)
	_sprite3d("res://assets/kenney/planets/planet07.png", Vector3(-120, 220, -950), 260.0, 0.4)


# ---------- 오디오 ----------

func _build_audio() -> void:
	var sfx_file := {"shoot": "shoot.ogg", "enemy_shoot": "eshoot.wav",
		"explosion": "boom.ogg", "hit": "hit.ogg", "wave": "wave.ogg",
		"boss": "boss.ogg", "gameover": "over.ogg", "tick": "tick.ogg",
		"bossdown": "big.ogg", "boss_shoot": "boss_shoot.wav", "boss_hit": "boss_hit.wav"}
	for n in sfx_vol.keys():
		var p := AudioStreamPlayer.new()
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		sfx_pool.append(p)
		var st = load("res://assets/audio/%s" % sfx_file.get(n, "tick.ogg"))
		if st != null:
			sfx_streams[n] = st
	bgm_stage = _mk_bgm("apex.mp3")
	bgm_boss = _mk_bgm("vanguard.mp3")


func _mk_bgm(fname: String) -> AudioStreamPlayer:
	var pl := AudioStreamPlayer.new()
	pl.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pl)
	var st := load("res://assets/audio/" + fname) as AudioStreamMP3
	if st != null:
		st.loop = true
		pl.stream = st
		pl.volume_db = -4.0
	return pl


func _play_want_bgm(force: bool = false) -> void:
	var want := bgm_boss if bgm_want == "boss" else bgm_stage
	for p in [bgm_stage, bgm_boss]:
		if p == null:
			continue
		if p == want:
			if force and (p as AudioStreamPlayer).playing:
				(p as AudioStreamPlayer).stop()
			if (p as AudioStreamPlayer).stream and not (p as AudioStreamPlayer).playing:
				(p as AudioStreamPlayer).play()
		elif (p as AudioStreamPlayer).playing:
			(p as AudioStreamPlayer).stop()


func _sfx(n: String) -> void:
	if not sfx_streams.has(n):
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = sfx_streams[n]
			p.volume_db = sfx_vol.get(n, -10.0)
			p.play()
			return


# ---------- UI (2D 오버레이 + 한글 폰트) ----------

func _build_ui() -> void:
	ui_font = load("res://fonts/NanumGothic-Bold.ttf") as Font
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer

	score_label = _mk_label(layer, Vector2(12, 10), 20, Color(0, 1, 1))
	hp_bar = ProgressBar.new()
	hp_bar.position = Vector2(12, 38)
	hp_bar.size = Vector2(150, 14)
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	layer.add_child(hp_bar)
	hp_label = _mk_label(layer, Vector2(168, 32), 18, Color(1, 0.33, 0.47))
	wave_label = _mk_label(layer, Vector2(340, 10), 20, Color(1, 0.3, 1))
	wave_label.size = Vector2(128, 30)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(90, 56)
	boss_bar.size = Vector2(300, 12)
	boss_bar.min_value = 0
	boss_bar.max_value = 100
	boss_bar.value = 100
	boss_bar.show_percentage = false
	boss_bar.visible = false
	layer.add_child(boss_bar)

	msg_label = Label.new()
	if ui_font:
		msg_label.add_theme_font_override("font", ui_font)
	msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 34)
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.add_theme_color_override("font_outline_color", Color(0, 0.8, 0.8))
	msg_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(msg_label)

	var left_btn := _mk_button(layer, "◀", Vector2(8, 590), Color(0, 1, 1), Vector2(228, 104))
	left_btn.button_down.connect(func() -> void: touch_left = true)
	left_btn.button_up.connect(func() -> void: touch_left = false)
	var right_btn := _mk_button(layer, "▶", Vector2(244, 590), Color(1, 0.3, 1), Vector2(228, 104))
	right_btn.button_down.connect(func() -> void: touch_right = true)
	right_btn.button_up.connect(func() -> void: touch_right = false)

	hit_flash = ColorRect.new()
	hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash.color = Color(1, 0.2, 0.3, 0.0)
	layer.add_child(hit_flash)
	lowhp_rect = ColorRect.new()
	lowhp_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	lowhp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lowhp_rect.color = Color(0.6, 0.0, 0.05, 0.0)
	lowhp_rect.visible = false
	layer.add_child(lowhp_rect)

	_refresh_hud()


func _mk_label(layer: CanvasLayer, pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	if ui_font:
		l.add_theme_font_override("font", ui_font)
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	layer.add_child(l)
	return l


func _mk_button(layer: CanvasLayer, txt: String, pos: Vector2, col: Color, sz: Vector2 = Vector2(104, 104)) -> Button:
	var b := Button.new()
	if ui_font:
		b.add_theme_font_override("font", ui_font)
	b.text = txt
	b.position = pos
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 42)
	b.add_theme_color_override("font_color", col)
	b.modulate = Color(1, 1, 1, 0.9)
	layer.add_child(b)
	return b


func _refresh_hud() -> void:
	if score_label:
		score_label.text = "SCORE %d" % score
	if wave_label:
		wave_label.text = "WAVE %d" % maxi(1, wave)
	if hp_bar:
		hp_bar.value = 100.0 * float(maxi(0, hp)) / float(maxi(1, max_hp))
	if hp_label:
		var t := "%d/%d" % [maxi(0, hp), max_hp]
		if shield > 0:
			t += " [◈%d]" % shield
		hp_label.text = t


# ---------- 스킬 선택 (wave 클리어마다 3택1) ----------

func _build_skill_ui() -> void:
	skill_layer = CanvasLayer.new()
	skill_layer.layer = 10
	skill_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	skill_layer.visible = false
	add_child(skill_layer)
	skill_title = Label.new()
	if ui_font:
		skill_title.add_theme_font_override("font", ui_font)
	skill_title.position = Vector2(40, 180)
	skill_title.size = Vector2(400, 40)
	skill_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skill_title.add_theme_font_size_override("font_size", 26)
	skill_title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	skill_layer.add_child(skill_title)
	skill_btns.clear()
	for i in range(3):
		var b := Button.new()
		if ui_font:
			b.add_theme_font_override("font", ui_font)
		b.position = Vector2(60, 240 + i * 84)
		b.size = Vector2(360, 72)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 19)
		b.pressed.connect(_on_skill_pick.bind(i))
		skill_layer.add_child(b)
		skill_btns.append(b)


func _skill_pool() -> Array:
	var pool := []
	if proj_count < 6:
		pool.append({"id": "count", "name": "연장 포 Lv%d" % (proj_count + 1), "desc": "미사일 +1 (현재 %d발)" % proj_count})
	if player_fire_interval > 0.081:
		pool.append({"id": "rate", "name": "속사", "desc": "발사속도 +15%"})
	pool.append({"id": "dmg", "name": "화력", "desc": "데미지 +15%%"})
	if shield < 9:
		pool.append({"id": "shield", "name": "방어막", "desc": "탄 차단 +3 (현재 %d)" % shield})
	if player_speed < 640.0:
		pool.append({"id": "speed", "name": "기동", "desc": "이동속도 +10%"})
	if pierce < 3:
		pool.append({"id": "pierce", "name": "관통탄", "desc": "탄 관통 +1 (전체 적용)"})
	if aoe_level < 3:
		pool.append({"id": "aoe", "name": "폭렬탄 Lv%d" % (aoe_level + 1), "desc": "2초마다 범위 폭발"})
	if hp < max_hp:
		pool.append({"id": "heal", "name": "긴급 수리", "desc": "체력 +1 (현재 %d/%d)" % [hp, max_hp]})
	if max_hp < 6:
		pool.append({"id": "maxhp", "name": "중장갑", "desc": "최대 체력 +1 (현재 %d)" % max_hp})
	return pool


var skill_opts: Array = []


func _open_skill_select() -> void:
	var pool := _skill_pool()
	if pool.is_empty():
		next_wave_cd = 0.9
		return
	pool.shuffle()
	skill_opts = pool.slice(0, mini(3, pool.size()))
	if wave % 3 == 0:
		skill_title.text = "BOSS 격파! 스킬 선택"
	else:
		skill_title.text = "WAVE %d 클리어! 스킬 선택" % wave
	for i in range(skill_btns.size()):
		var b: Button = skill_btns[i]
		if i < skill_opts.size():
			var o: Dictionary = skill_opts[i]
			b.visible = true
			b.text = "%s\n%s" % [String(o["name"]), String(o["desc"])]
		else:
			b.visible = false
	skill_open = true
	skill_layer.visible = true
	get_tree().paused = true


func _on_skill_pick(idx: int) -> void:
	if idx < 0 or idx >= skill_opts.size():
		return
	_apply_skill(String((skill_opts[idx] as Dictionary)["id"]))
	skill_layer.visible = false
	skill_open = false
	get_tree().paused = false
	next_wave_cd = 0.9


func _apply_skill(sid: String) -> void:
	match sid:
		"count":
			proj_count = mini(6, proj_count + 1)
		"rate":
			player_fire_interval = maxf(0.08, player_fire_interval / 1.15)
		"dmg":
			p_damage *= 1.15
		"shield":
			shield = mini(9, shield + 3)
		"speed":
			player_speed = minf(640.0, player_speed * 1.10)
		"pierce":
			pierce = mini(3, pierce + 1)
		"aoe":
			aoe_level = mini(3, aoe_level + 1)
			if aoe_level == 1:
				aoe_cd = AOE_BASE_CD
		"heal":
			hp = mini(max_hp, hp + 1)
		"maxhp":
			max_hp = mini(6, max_hp + 1)
			hp = mini(max_hp, hp + 1)
	_refresh_hud()
	_update_shield()


# ---------- 엔티티 ----------

func _cone(r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = r
	mesh.height = h
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.rotation_degrees.x = -90.0
	return mi


func _build_player() -> void:
	player = Node3D.new()
	player.position = Vector3(0, 0, PLAYER_Z)
	var halo := _ball(14.0, m_player_glow)
	halo.scale = Vector3(1.4, 0.22, 1.4)
	halo.position = Vector3(0, -6, 4)
	player.add_child(halo)
	player.add_child(_ship("res://assets/kenney/ships/craft_racer.obj", 20.0, true))
	var flames := []
	for sx in [-1.0, 1.0]:
		var flame := _box(6, 6, 4, m_engine)
		flame.position = Vector3(sx * 5.0, 5, 22.5)
		player.add_child(flame)
		flames.append(flame)
	player.set_meta("flames", flames)
	add_child(player)
	player_alive = true
	_build_shield()


func _build_shield() -> void:
	# 비행기 앞 반투명 반구 방어막: 적 탄을 대신 맞고 차지 소모
	var mesh := SphereMesh.new()
	mesh.radius = SHIELD_R
	mesh.height = SHIELD_R * 2.0
	mesh.is_hemisphere = true
	mesh.radial_segments = 16
	mesh.rings = 8
	shield_dome = MeshInstance3D.new()
	shield_dome.mesh = mesh
	shield_dome.material_override = _neon_trans(Color(0.3, 0.9, 1), 0.25)
	shield_dome.position = Vector3(0, 0, -20)
	shield_dome.visible = false
	player.add_child(shield_dome)


func _update_shield() -> void:
	if shield_dome and is_instance_valid(shield_dome):
		shield_dome.visible = shield > 0
	_refresh_hud()


func _shield_center() -> Vector3:
	return player.position + Vector3(0, 0, -20)


# ---------- 타이틀 (시작 전 표지 + 터치 시작) ----------

func _build_title() -> void:
	title_layer = CanvasLayer.new()
	title_layer.layer = 20
	add_child(title_layer)
	var tex := load("res://assets/front.jpg") as Texture2D
	var rect := TextureRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex:
		rect.texture = tex
	title_layer.add_child(rect)
	title_hint = Label.new()
	if ui_font:
		title_hint.add_theme_font_override("font", ui_font)
	title_hint.text = "터치하여 시작"
	title_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	title_hint.position = Vector2(40, 560)
	title_hint.size = Vector2(400, 60)
	title_hint.add_theme_font_size_override("font_size", 30)
	title_hint.add_theme_color_override("font_color", Color(0, 1, 1))
	title_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	title_hint.add_theme_constant_override("outline_size", 8)
	title_layer.add_child(title_hint)


func _start_game() -> void:
	if started:
		return
	started = true
	if title_layer and is_instance_valid(title_layer):
		title_layer.queue_free()
	title_layer = null
	title_hint = null
	next_wave()


func next_wave() -> void:
	wave += 1
	_refresh_hud()
	enemy_dir = 1.0
	drop_cd = 0.0
	spiral_on = false
	wall_on = false
	snipe_on = false
	sweep_on = false
	var is_boss := wave % 3 == 0
	bgm_want = "boss" if is_boss else "stage"
	_play_want_bgm()
	if is_boss:
		_spawn_boss()
		_show_msg("WAVE %d\nBOSS!" % wave, 1.4)
		_sfx("boss")
	else:
		_spawn_formation()
		_show_msg("WAVE %d" % wave, 1.2)


func _mk_enemy_root(lx: float, lz: float) -> Node3D:
	var e := Node3D.new()
	e.position = Vector3(lx, 0, lz)
	e.set_meta("flash", 0.0)
	e.set_meta("spawn", 0.25)
	e.set_meta("spawn_total", 0.25)
	add_child(e)
	enemies.append(e)
	return e


func _spawn_formation() -> void:
	var cols := 6 + (1 if wave >= 4 else 0) + (1 if wave >= 7 else 0)
	var rows := 3 + mini(3, wave / 2)
	var hp_small := 1 + wave / 4
	var hp_mid := 2 + wave / 3
	enemy_speed = minf(150.0, 30.0 + wave * 9.0)
	fire_interval = maxf(0.35, 0.95 - wave * 0.06)
	fire_cd = fire_interval
	bullet_speed = 235.0 + wave * 26.0
	boss = null
	if boss_bar:
		boss_bar.visible = false
	var dx := 360.0 / maxf(1.0, float(cols - 1)) if cols > 1 else 0.0
	var tank_slots := mini(3, wave / 2) if wave >= 2 else 0
	var tank_placed := 0
	for r in range(rows):
		for c in range(cols):
			var lx := -180.0 + c * dx
			var is_bottom := r >= rows - 1
			var want_tank := is_bottom and tank_placed < tank_slots and absf(lx) < 40.0 + tank_slots * 30.0
			var kind := "scout"
			if want_tank:
				kind = "tank"
				tank_placed += 1
			elif is_bottom:
				kind = "gunner"
			elif wave >= 2 and (r + c) % 2 == 0:
				kind = "weaver"
			# 상단부터 빽빽하게: 6행이어도 맨 아랫줄이 z=-60 위로 유지
			var e := _mk_enemy_root(lx, -280.0 + r * 44.0)
			if kind == "gunner":
				e.add_child(_ship("res://assets/kenney/ships/craft_miner.obj", 15.0))
				_beacon(e, m_e2, m_e2_glow, 13.0, 16.0)
				e.set_meta("hp", hp_mid)
				e.set_meta("score_v", 40)
				e.set_meta("radius", 19.0)
			elif kind == "weaver":
				e.add_child(_ship("res://assets/kenney/ships/craft_speederB.obj", 13.0))
				_beacon(e, m_weaver, m_weaver_glow, 10.0, 12.0)
				e.set_meta("hp", 1 + wave / 4)
				e.set_meta("score_v", 30)
				e.set_meta("radius", 13.0)
				e.set_meta("weave", randf() * TAU)
			elif kind == "tank":
				e.add_child(_ship("res://assets/kenney/ships/craft_cargoA.obj", 24.0))
				_beacon(e, m_tank, m_tank_glow, 22.0, 24.0)
				e.set_meta("hp", 5 + wave / 2)
				e.set_meta("score_v", 80)
				e.set_meta("radius", 24.0)
			else:
				e.add_child(_ship("res://assets/kenney/ships/craft_speederA.obj", 14.0))
				_beacon(e, m_e1, m_e1_glow, 13.0, 12.0)
				e.set_meta("hp", hp_small)
				e.set_meta("score_v", 20)
				e.set_meta("radius", 14.0)
			e.set_meta("kind", kind)


func _beacon(e: Node3D, dot_mat: Material, halo_mat: Material, top_y: float, halo_r: float) -> void:
	var dot := _ball(2.5, dot_mat)
	dot.position = Vector3(0, top_y, 0)
	e.add_child(dot)
	var halo := _ball(halo_r, halo_mat)
	halo.scale = Vector3(1.2, 0.18, 1.2)
	halo.position = Vector3(0, -3, 2)
	e.add_child(halo)


func _spawn_boss() -> void:
	enemy_speed = 60.0
	fire_interval = 9.0
	var hp := 45 + wave * 14
	boss_core_mat = _neon(Color(1, 0.85, 0.15), 2.2)
	var b := Node3D.new()
	b.position = Vector3(0, 0, -250)
	b.add_child(_ship("res://assets/kenney/ships/craft_cargoB.obj", 60.0))
	for i in range(5):
		var cx := -40.0 + i * 20.0
		var core := _ball(9.0, m_dark)
		core.position = Vector3(cx, 15, -62)
		b.add_child(core)
		var hot := _ball(4.5, boss_core_mat)
		hot.position = Vector3(cx, 15, -70)
		b.add_child(hot)
	b.set_meta("hp", hp)
	b.set_meta("max_hp", hp)
	b.set_meta("score_v", 500)
	b.set_meta("kind", "boss")
	b.set_meta("flash", 0.0)
	b.set_meta("spawn", 0.4)
	b.set_meta("spawn_total", 0.4)
	add_child(b)
	enemies.append(b)
	boss = b
	boss_pattern = -1
	boss_ptime = 2.0
	boss_tx = 0.0
	boss_tt = 0.0
	boss_pinterval = maxf(2.0, 3.8 - wave * 0.15)
	boss_bspeed = 200.0 + wave * 12.0
	if boss_bar:
		boss_bar.visible = true
		boss_bar.value = 100


# ---------- 발사 ----------

func _spawn_p_bullet(x: float, z: float, vel: Vector2) -> void:
	# 플레이어 푸른 볼트: 글로우 외피 + 백색 코어
	var b := Node3D.new()
	b.position = Vector3(x, 0, z)
	b.add_child(_box(9, 11, 28, m_bullet_p_glow))
	b.add_child(_box(4, 6, 22, m_bullet_core))
	b.set_meta("vel", vel)
	b.set_meta("pierce", pierce)
	b.set_meta("hits", [])
	b.set_meta("aoe", false)
	add_child(b)
	p_bullets.append(b)


func _spawn_aoe_bullet(x: float, z: float) -> void:
	# 폭렬탄: 명중 지점에서 범위 폭발 (적 2~3기 영역)
	var b := Node3D.new()
	b.position = Vector3(x, 0, z)
	b.add_child(_ball(11.0, m_bullet_p_glow))
	b.add_child(_ball(7.0, m_core_orange))
	b.set_meta("vel", Vector2(0, -p_bullet_speed * 0.8))
	b.set_meta("pierce", 0)
	b.set_meta("hits", [])
	b.set_meta("aoe", true)
	add_child(b)
	p_bullets.append(b)


func _explode_aoe(p: Vector2) -> void:
	var dmg := p_damage * (2.0 + 0.5 * float(maxi(0, aoe_level - 1)))
	_explode(p, Color(1, 0.55, 0.1), 22)
	_add_shake(5.0)
	_sfx("explosion")
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var d := p.distance_to(_epos(e))
		var rr := AOE_RADIUS + (80.0 if String(e.get_meta("kind")) == "boss" else 0.0)
		if d < rr:
			_damage_enemy(e, dmg)


func _spawn_e_bullet(x: float, z: float, vel: Vector2, mtype: String = "dart") -> void:
	vel = vel * e_bullet_mult
	# 적 붉은 계열 3종: dart(표준) / orb(느리고 큼) / needle(가늘고 빠름)
	var b := Node3D.new()
	b.position = Vector3(x, 0, z)
	if mtype == "orb":
		b.add_child(_ball(11.0, m_bullet_e_glow))
		b.add_child(_ball(7.5, m_orb))
		var core := _ball(3.0, m_bullet_hot)
		core.position = Vector3(0, 1, 0)
		b.add_child(core)
		b.set_meta("br", 13.0)
	elif mtype == "needle":
		b.add_child(_box(4, 7, 32, m_needle))
		b.add_child(_box(5, 8, 8, m_bullet_hot))
		b.set_meta("br", 6.0)
	else:
		b.add_child(_box(10, 11, 22, m_bullet_e_glow))
		b.add_child(_box(4, 6, 16, m_bullet_e))
		b.set_meta("br", 8.0)
	b.set_meta("vel", vel)
	add_child(b)
	e_bullets.append(b)


func _enemy_fire_tick() -> void:
	if boss != null and is_instance_valid(boss):
		return
	var alive := []
	for e in enemies:
		if is_instance_valid(e):
			alive.append(e)
	if alive.is_empty():
		return
	var shooters := mini(alive.size(), 1 + wave / 3)
	for i in range(shooters):
		var s: Node3D = alive[randi() % alive.size()]
		var sk := String(s.get_meta("kind"))
		if sk == "tank":
			# 탱크: 중앙 오브 + 양옆 다트 혼합 발리
			_spawn_e_bullet(s.position.x, s.position.z + 16, Vector2(0, bullet_speed * 0.7), "orb")
			_spawn_e_bullet(s.position.x, s.position.z + 16, Vector2(-90, bullet_speed), "dart")
			_spawn_e_bullet(s.position.x, s.position.z + 16, Vector2(90, bullet_speed), "dart")
		elif sk == "gunner" and wave >= 2 and randi() % 3 == 0:
			_spawn_e_bullet(s.position.x, s.position.z + 16, Vector2(0, bullet_speed * 0.75), "orb")
		elif wave >= 4 and (sk == "weaver" or (sk == "scout" and randi() % 4 == 0)):
			_spawn_e_bullet(s.position.x, s.position.z + 16,
				Vector2(randf_range(-30, 30), bullet_speed * 1.25), "needle")
		else:
			_spawn_e_bullet(s.position.x, s.position.z + 16,
				Vector2(randf_range(-40, 40), bullet_speed), "dart")
	_sfx("enemy_shoot")


# ---------- 보스 탄막 패턴 (x/z 평면, 2D와 동일 각도계) ----------

func _run_boss_pattern() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var n_aim := 5 + (2 if wave >= 6 else 0)
	var bp := boss.position
	var pp := player.position if player else Vector3(0, 0, PLAYER_Z)
	if boss_pattern == 0:
		var to_p := Vector2(pp.x - bp.x, pp.z - bp.z).normalized()
		var base := to_p.angle()
		for i in range(n_aim):
			var off := (float(i) - float(n_aim - 1) / 2.0) * 0.16
			var a := base + off
			_spawn_e_bullet(bp.x, bp.z + 30, Vector2(cos(a), sin(a)) * boss_bspeed, "needle")
		_sfx("boss_shoot")
	elif boss_pattern == 1:
		var count := 16 + mini(8, wave)
		for ring in range(2):
			var rot := (TAU / count) * (0.5 if ring == 1 else 0.0) + randf() * 0.2
			var sp := boss_bspeed * (0.8 if ring == 0 else 1.1)
			for i in range(count):
				var a2 := rot + TAU * float(i) / float(count)
				_spawn_e_bullet(bp.x, bp.z + 10, Vector2(cos(a2), sin(a2)) * sp, "orb")
		_sfx("boss_shoot")
	elif boss_pattern == 2:
		spiral_on = true
		spiral_t = 2.2
		spiral_emit = 0.0
		_sfx("boss_shoot")
	elif boss_pattern == 3:
		wall_on = true
		wall_t = 2.0
		wall_emit = 0.0
		wall_gap = pp.x
		_sfx("boss_shoot")
	elif boss_pattern == 4:
		# 저격 연발: 플레이어 현위치로 빠른 단발 6연발
		snipe_on = true
		snipe_t = 1.2
		snipe_emit = 0.0
		snipe_n = 6
	elif boss_pattern == 5:
		# 추적 부채꼴: 발사 순간마다 플레이어를 조준하며 1.5초간 연사
		sweep_on = true
		sweep_t = 1.5
		sweep_emit = 0.0
		_sfx("boss_shoot")


func _boss_continuous(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		spiral_on = false
		wall_on = false
		snipe_on = false
		sweep_on = false
		return
	var bp := boss.position
	var pp2 := player.position if player else Vector3(0, 0, PLAYER_Z)
	if spiral_on:
		spiral_t -= delta
		spiral_emit -= delta
		spiral_ang += delta * (2.4 + wave * 0.12)
		var arms := 2 + (1 if wave >= 6 else 0)
		if spiral_emit <= 0.0:
			spiral_emit = 0.055
			for k in range(arms):
				var a := spiral_ang + TAU * float(k) / float(arms)
				_spawn_e_bullet(bp.x, bp.z + 20,
					Vector2(cos(a), sin(a)) * (boss_bspeed * 0.75))
		if spiral_t <= 0.0:
			spiral_on = false
	if wall_on:
		wall_t -= delta
		wall_emit -= delta
		if player:
			wall_gap = lerpf(wall_gap, player.position.x, delta * 1.6)
		var gap_half := maxf(38.0, 58.0 - wave * 2.0)
		if wall_emit <= 0.0:
			wall_emit = 0.15
			# 보스 전면(±78)에서만 발사 → 몸통에서 나가는 탄벽
			for k in range(-3, 4):
				var wx := bp.x + float(k) * 26.0
				if absf(wx - wall_gap) > gap_half:
					_spawn_e_bullet(wx, bp.z + 34, Vector2(float(k) * 15.0, boss_bspeed), "dart")
		if wall_t <= 0.0:
			wall_on = false
	if snipe_on:
		snipe_t -= delta
		snipe_emit -= delta
		if snipe_emit <= 0.0 and snipe_n > 0:
			snipe_emit = 0.13
			snipe_n -= 1
			var aim := Vector2(pp2.x - bp.x, pp2.z - bp.z).normalized()
			_spawn_e_bullet(bp.x, bp.z + 30, aim * (boss_bspeed * 1.6), "needle")
			_sfx("tick")
		if snipe_n <= 0 or snipe_t <= 0.0:
			snipe_on = false
	if sweep_on:
		sweep_t -= delta
		sweep_emit -= delta
		if sweep_emit <= 0.0:
			sweep_emit = 0.10
			var aim2 := Vector2(pp2.x - bp.x, pp2.z - bp.z).normalized()
			var base2 := aim2.angle()
			for k in [-1, 0, 1]:
				var a3: float = base2 + float(k) * 0.12
				_spawn_e_bullet(bp.x, bp.z + 30, Vector2(cos(a3), sin(a3)) * boss_bspeed, "dart")
		if sweep_t <= 0.0:
			sweep_on = false


# ---------- 타격 ----------

func _add_shake(m: float) -> void:
	shake = minf(shake + m, 10.0)


func _damage_enemy(e: Node3D, dmg: float = 1.0) -> void:
	if not is_instance_valid(e):
		return
	var ehp := float(e.get_meta("hp")) - dmg
	e.set_meta("hp", ehp)
	e.set_meta("flash", 0.08)
	var ep := Vector2(e.position.x, e.position.z)
	var k := String(e.get_meta("kind"))
	var boom_n := 14 if (k == "boss" or k == "tank") else (10 if k == "gunner" else 7)
	_explode(ep, Color(1, 0.13, 0.33) if k == "boss" else Color(1, 0.93, 0.2), boom_n)
	if ehp <= 0:
		var sv := int(e.get_meta("score_v"))
		score += sv
		_refresh_hud()
		_popup(ep, "+%d" % sv)
		if e.get_meta("kind") == "boss":
			_do_flash(Color(1, 1, 1), 0.25)
		_explode(ep, Color(1, 0.5, 0.1), 10)
		if e.get_meta("kind") == "boss":
			_sfx("bossdown")
		else:
			_sfx("explosion")
		_add_shake(4.0 if e.get_meta("kind") != "boss" else 8.0)
		enemies.erase(e)
		if e == boss:
			boss = null
			spiral_on = false
			wall_on = false
			snipe_on = false
			sweep_on = false
			boss_core_mat = null
			if boss_bar:
				boss_bar.visible = false
		e.queue_free()
		if enemies.is_empty() and not game_over and next_wave_cd < 0.0 and not skill_open:
			_open_skill_select()
	else:
		if e.get_meta("kind") == "boss":
			# 연타 금속음을 둔탁한 쿵으로 교체 + 0.12초 쿨다운
			if _boss_hit_cd <= 0.0:
				_boss_hit_cd = 0.12
				_sfx("boss_hit")
		else:
			_sfx("tick")
		if e.get_meta("kind") == "boss" and boss_bar:
			var r := ehp / float(maxf(1.0, float(e.get_meta("max_hp"))))
			boss_bar.value = r * 100.0


func _hit_player() -> void:
	if game_over or invincible_t > 0.0 or not player_alive:
		return
	hp -= 1
	_refresh_hud()
	_explode(Vector2(player.position.x, player.position.z), Color(0, 1, 1), 14)
	_sfx("hit")
	_add_shake(8.0)
	_do_flash(Color(1, 0.2, 0.3), 0.35)
	if hp <= 0:
		_do_game_over()
	else:
		invincible_t = invincible_dur


func _do_game_over() -> void:
	game_over = true
	player_alive = false
	if player:
		player.visible = false
	_show_msg("GAME OVER\nSCORE %d\n탭하여 재시작" % score, 100000.0)
	_sfx("gameover")
	for p in [bgm_stage, bgm_boss]:
		if p:
			(p as AudioStreamPlayer).volume_db = -20.0


func _show_msg(txt: String, dur: float) -> void:
	if msg_label:
		msg_label.text = txt
		msg_label.modulate = Color(1, 1, 1, 1)
	_msg_t = dur


func _explode(p: Vector2, color: Color, n: int) -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 2.0
	for i in range(n):
		var s := _box(randf_range(2.5, 5.5), randf_range(2.5, 5.5), randf_range(2.5, 5.5), m)
		s.position = Vector3(p.x, 0, p.y)
		add_child(s)
		shards.append({
			"n": s,
			"vel": Vector3(randf_range(-170, 170), randf_range(30, 220), randf_range(-170, 170)),
			"life": randf_range(0.3, 0.55),
		})


# ---------- 연출 (팝업/머즐/플래시) ----------

func _popup(world_p: Vector2, txt: String, col: Color = Color(1, 0.93, 0.2)) -> void:
	if ui_layer == null or cam == null:
		return
	var sp := cam.unproject_position(Vector3(world_p.x, 0, world_p.y))
	var l := Label.new()
	if ui_font:
		l.add_theme_font_override("font", ui_font)
	l.text = txt
	l.position = sp + Vector2(-30, -30)
	l.size = Vector2(120, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(l)
	popups.append({"l": l, "life": 0.7})


func _muzzle(x: float, z: float) -> void:
	var f := _ball(3.5, m_bullet_hot)
	f.position = Vector3(x, 1, z)
	add_child(f)
	muzzles.append({"n": f, "life": 0.06})


func _do_flash(col: Color, a: float) -> void:
	flash_col = col
	flash_a = a


func _input(event: InputEvent) -> void:
	# _unhandled_input은 UI 버튼에 먹히므로, 모든 입력에서 BGM 강제 시작
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		pressed = true
	if not pressed:
		return
	if not _bgm_unlocked:
		_bgm_unlocked = true
		_play_want_bgm(true)
	if not started:
		_start_game()


func _unhandled_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	elif event is InputEventKey and event.pressed:
		pressed = true
	if pressed:
		# 브라우저 오디오 자동재생 차단을 첫 입력 시점에 해제 (BGM 재시작)
		_play_want_bgm()
	if not game_over:
		return
	if pressed and (not (event is InputEventKey) or event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		get_tree().reload_current_scene()


# ---------- 메인 루프 ----------

func _physics_process(delta: float) -> void:
	elapsed += delta
	if _boss_hit_cd > 0.0:
		_boss_hit_cd -= delta

	# 별 이동
	for i in range(STAR_N):
		var s: Dictionary = star_data[i]
		s["z"] = float(s["z"]) + float(s["sp"]) * delta
		if float(s["z"]) > 380.0:
			s["z"] = -380.0
			s["x"] = randf_range(-260, 260)
		_update_star(i)

	# 파편
	for i in range(shards.size() - 1, -1, -1):
		var sh: Dictionary = shards[i]
		if not is_instance_valid(sh["n"]):
			shards.remove_at(i)
			continue
		sh["life"] = float(sh["life"]) - delta
		if float(sh["life"]) <= 0.0:
			(sh["n"] as Node3D).queue_free()
			shards.remove_at(i)
			continue
		var sn: Node3D = sh["n"]
		sn.position += (sh["vel"] as Vector3) * delta
		var k := clampf(float(sh["life"]) * 2.2, 0.05, 1.0)
		sn.scale = Vector3(k, k, k)

	# 카메라 흔들림
	if cam:
		if shake > 0.05:
			cam.position = CAM_POS + Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake
			shake = lerpf(shake, 0.0, delta * 7.0)
		elif cam.position != CAM_POS:
			cam.position = CAM_POS

	if not started:
		if title_hint and is_instance_valid(title_hint):
			title_hint.modulate.a = 0.55 + 0.45 * sin(elapsed * 4.0)
		return

	if game_over:
		return

	if invincible_t > 0.0:
		invincible_t -= delta
		blink_t += delta
		if player:
			player.visible = fmod(blink_t, 0.2) < 0.12
		if invincible_t <= 0.0 and player:
			player.visible = true

	if _msg_t > 0.0 and not game_over and msg_label:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg_t = -1.0
			msg_label.text = ""
		elif _msg_t < 0.4:
			msg_label.modulate.a = clampf(_msg_t / 0.4, 0.0, 1.0)

	# 플레이어 이동 + 뱅킹
	move_dir = 0.0
	if player_alive and player:
		var dir := 0.0
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or touch_left:
			dir -= 1.0
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or touch_right:
			dir += 1.0
		move_dir = dir
		# 터치 버튼은 미세 컨트롤용으로 감속 (키보드는 전속)
		var spd := player_speed
		if touch_left or touch_right:
			spd *= TOUCH_SPEED_FACTOR
		player.position.x = clampf(player.position.x + dir * spd * delta, -PLAYER_X_LIM, PLAYER_X_LIM)
		player.rotation.z = lerpf(player.rotation.z, -dir * 0.3, delta * 8.0)
		if player.has_meta("flames"):
			var fl: Array = player.get_meta("flames")
			for fi in range(fl.size()):
				if is_instance_valid(fl[fi]):
					var fs := 0.8 + 0.35 * sin(elapsed * 26.0 + fi * 2.1)
					(fl[fi] as MeshInstance3D).scale = Vector3(1, 1, fs)

	# 자동 발사
	if player_alive and player and not skill_open:
		fire_cd -= delta
		var interval := player_fire_interval
		if boss != null and is_instance_valid(boss):
			interval = player_fire_interval * 0.86
		if fire_cd <= 0.0:
			fire_cd = interval
			# 발사체 수 스킬: 1발 기본, 같은 스킬 취득마다 +1
			var px := player.position.x
			var pz := player.position.z - 24
			for i in range(proj_count):
				var t := float(i) - float(proj_count - 1) / 2.0
				_spawn_p_bullet(px + t * 12.0, pz, Vector2(t * 55.0, -p_bullet_speed))
				_muzzle(px + t * 12.0, pz - 20.0)
			_sfx("shoot")
		# 폭렬탄: 스택당 쿨다운 감소, 범위 폭발 미사일 발사
		if aoe_level > 0:
			aoe_cd -= delta
			if aoe_cd <= 0.0:
				aoe_cd = maxf(1.0, AOE_BASE_CD * pow(0.85, aoe_level - 1))
				_spawn_aoe_bullet(player.position.x, player.position.z - 24)
				_sfx("boss_shoot")

	# 적 발사 / 보스 스케줄
	if boss == null or not is_instance_valid(boss):
		_fire_tick_accum(delta)
	else:
		# 랜덤 기동: 1.6~3.2초마다 새 목표 x를 잡고 웨이브 비례 속도로 접근 + 상하 bob
		boss_tt -= delta
		if boss_tt <= 0.0:
			boss_tt = randf_range(1.6, 3.2)
			boss_tx = randf_range(-150.0, 150.0)
		var bx0 := boss.position.x
		boss.position.x = move_toward(boss.position.x, boss_tx, (90.0 + wave * 10.0) * delta)
		boss.position.x += sin(elapsed * 2.3 + float(wave)) * 20.0 * delta
		boss.position.z = -250.0 + sin(elapsed * 0.9) * 30.0
		# 물리 뱅킹: 실제 횡속도에 비례해 롤+요를 줘서 기동과 자세가 일치
		var bv := (boss.position.x - bx0) / maxf(delta, 0.0001)
		boss.rotation.z = lerpf(boss.rotation.z, clampf(-bv / 900.0, -0.25, 0.25), delta * 4.0)
		boss.rotation.y = lerpf(boss.rotation.y, clampf(bv / 2100.0, -0.1, 0.1), delta * 4.0)
		if boss_core_mat:
			boss_core_mat.emission_energy_multiplier = 1.7 + sin(elapsed * 6.0) * 0.9
		boss_ptime += delta
		if boss_ptime >= boss_pinterval:
			boss_ptime = 0.0
			# 탄막 순서 랜덤 (직전 패턴 제외)
			var np := randi() % 6
			while np == boss_pattern:
				np = randi() % 6
			boss_pattern = np
			_run_boss_pattern()
		_boss_continuous(delta)
		if boss_bar and is_instance_valid(boss):
			var r2 := float(boss.get_meta("hp")) / float(maxf(1.0, float(boss.get_meta("max_hp"))))
			boss_bar.value = r2 * 100.0

	# 일반 적 이동 (벽 반전 + 낙하 쿨다운)
	if (boss == null or not is_instance_valid(boss)) and not enemies.is_empty():
		drop_cd -= delta
		var min_x := 1e9
		var max_x := -1e9
		for e in enemies:
			if is_instance_valid(e):
				min_x = minf(min_x, (e as Node3D).position.x)
				max_x = maxf(max_x, (e as Node3D).position.x)
		if (enemy_dir > 0 and max_x > EDGE) or (enemy_dir < 0 and min_x < -EDGE):
			enemy_dir *= -1.0
			if drop_cd <= 0.0:
				drop_cd = 0.7
				for e in enemies:
					if is_instance_valid(e):
						(e as Node3D).position.z += 12.0
		for e in enemies:
			if is_instance_valid(e):
				var en: Node3D = e
				var vx := enemy_dir * enemy_speed
				if en.has_meta("weave"):
					vx += cos(elapsed * 3.0 + float(en.get_meta("weave"))) * 60.0
				en.position.x += vx * delta
				en.rotation.y = sin(elapsed * 2.5 + en.position.x * 0.03) * 0.18
		if player_alive:
			for e in enemies:
				if is_instance_valid(e) and (e as Node3D).position.z > INVADE_Z:
					enemies.erase(e)
					(e as Node3D).queue_free()
					_hit_player()
					break

	# 등장 스케일-인 + 피격 플래시
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var en2: Node3D = e
		var sc := 1.0
		if en2.has_meta("spawn") and float(en2.get_meta("spawn")) > 0.0:
			en2.set_meta("spawn", float(en2.get_meta("spawn")) - delta)
			var total := 0.25
			if en2.has_meta("spawn_total"):
				total = float(en2.get_meta("spawn_total"))
			var k := clampf(1.0 - float(en2.get_meta("spawn")) / total, 0.0, 1.0)
			sc = lerpf(0.2, 1.0, k * k)
		if float(en2.get_meta("flash")) > 0.0:
			en2.set_meta("flash", float(en2.get_meta("flash")) - delta)
			if float(en2.get_meta("flash")) > 0.0:
				sc *= 1.18
		en2.scale = Vector3(sc, sc, sc)

	# 팝업/머즐/플래시 업데이트
	for i in range(popups.size() - 1, -1, -1):
		var pu: Dictionary = popups[i]
		if not is_instance_valid(pu["l"]):
			popups.remove_at(i)
			continue
		pu["life"] = float(pu["life"]) - delta
		if float(pu["life"]) <= 0.0:
			(pu["l"] as Label).queue_free()
			popups.remove_at(i)
			continue
		var pl: Label = pu["l"]
		pl.position.y -= 44.0 * delta
		pl.modulate.a = clampf(float(pu["life"]) / 0.7, 0.0, 1.0)
	for i in range(muzzles.size() - 1, -1, -1):
		var mz: Dictionary = muzzles[i]
		if not is_instance_valid(mz["n"]):
			muzzles.remove_at(i)
			continue
		mz["life"] = float(mz["life"]) - delta
		if float(mz["life"]) <= 0.0:
			(mz["n"] as MeshInstance3D).queue_free()
			muzzles.remove_at(i)
			continue
		var mzn: MeshInstance3D = mz["n"]
		var mk := clampf(float(mz["life"]) / 0.06, 0.05, 1.0)
		mzn.scale = Vector3(mk, mk, mk)
	if flash_a > 0.0 and hit_flash:
		flash_a = maxf(0.0, flash_a - delta * 1.8)
		hit_flash.color = Color(flash_col.r, flash_col.g, flash_col.b, flash_a)
	if lowhp_rect:
		if started and not game_over and hp == 1:
			lowhp_rect.visible = true
			lowhp_rect.color = Color(0.6, 0.0, 0.05, 0.10 + 0.06 * sin(elapsed * 5.0))
		else:
			lowhp_rect.visible = false

	_move_bullets(delta)
	_check_collisions()

	if next_wave_cd > 0.0:
		next_wave_cd -= delta
		if next_wave_cd <= 0.0:
			next_wave_cd = -1.0
			next_wave()


func _fire_tick_accum(delta: float) -> void:
	_fire_accum += delta
	if _fire_accum >= fire_interval:
		_fire_accum = 0.0
		_enemy_fire_tick()


func _move_bullets(delta: float) -> void:
	for i in range(p_bullets.size() - 1, -1, -1):
		var b = p_bullets[i]
		if not is_instance_valid(b):
			p_bullets.remove_at(i)
			continue
		var bn: Node3D = b
		var v: Vector2 = bn.get_meta("vel")
		bn.position.x += v.x * delta
		bn.position.z += v.y * delta
		if bn.position.z < -390 or bn.position.z > 390 or bn.position.x < -270 or bn.position.x > 270:
			bn.queue_free()
			p_bullets.remove_at(i)
	for i in range(e_bullets.size() - 1, -1, -1):
		var b2 = e_bullets[i]
		if not is_instance_valid(b2):
			e_bullets.remove_at(i)
			continue
		var bn2: Node3D = b2
		var v2: Vector2 = bn2.get_meta("vel")
		bn2.position.x += v2.x * delta
		bn2.position.z += v2.y * delta
		if bn2.position.z < -390 or bn2.position.z > 390 or bn2.position.x < -270 or bn2.position.x > 270:
			bn2.queue_free()
			e_bullets.remove_at(i)


func _epos(e: Node3D) -> Vector2:
	return Vector2(e.position.x, e.position.z)


func _check_collisions() -> void:
	for bi in range(p_bullets.size() - 1, -1, -1):
		if bi >= p_bullets.size():
			continue
		var b = p_bullets[bi]
		if not is_instance_valid(b):
			continue
		var bn: Node3D = b
		var bp := Vector2(bn.position.x, bn.position.z)
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if (bn.get_meta("hits") as Array).has((e as Node3D).get_instance_id()):
				continue
			if _hit_test(bp, 8.0, e):
				if bool(bn.get_meta("aoe")):
					bn.queue_free()
					p_bullets.remove_at(bi)
					_explode_aoe(bp)
					break
				(bn.get_meta("hits") as Array).append((e as Node3D).get_instance_id())
				_damage_enemy(e, p_damage)
				if int(bn.get_meta("pierce")) > 0 and is_instance_valid(e):
					bn.set_meta("pierce", int(bn.get_meta("pierce")) - 1)
				else:
					bn.queue_free()
					p_bullets.remove_at(bi)
					break
				if not is_instance_valid(e):
					continue
	# 방어막: 비행기 앞 반구가 적 탄을 대신 맞고 차지 소모
	if shield > 0 and player_alive and player:
		var sc := Vector2(_shield_center().x, _shield_center().z)
		for bi3 in range(e_bullets.size() - 1, -1, -1):
			if bi3 >= e_bullets.size():
				continue
			var b3 = e_bullets[bi3]
			if not is_instance_valid(b3):
				continue
			var q3 := Vector2((b3 as Node3D).position.x, (b3 as Node3D).position.z)
			var br3: float = float((b3 as Node3D).get_meta("br"))
			if q3.distance_to(sc) < SHIELD_R + br3:
				(b3 as Node3D).queue_free()
				e_bullets.remove_at(bi3)
				_explode(sc, Color(0.3, 0.9, 1), 4)
				_sfx("tick")
				shield -= 1
				_update_shield()
				if shield <= 0:
					break
	if player_alive and player and invincible_t <= 0.0:
		var pp := Vector2(player.position.x, player.position.z)
		for bi2 in range(e_bullets.size() - 1, -1, -1):
			var b2 = e_bullets[bi2]
			if not is_instance_valid(b2):
				continue
			var q := Vector2((b2 as Node3D).position.x, (b2 as Node3D).position.z)
			var br: float = float((b2 as Node3D).get_meta("br"))
			if q.distance_to(pp) < player_hit_r + br:
				(b2 as Node3D).queue_free()
				e_bullets.remove_at(bi2)
				_hit_player()
				break
	if player_alive and player and invincible_t <= 0.0:
		var pp2 := Vector2(player.position.x, player.position.z)
		for e in enemies:
			if is_instance_valid(e) and _hit_test(pp2, player_hit_r, e):
				enemies.erase(e)
				(e as Node3D).queue_free()
				_hit_player()
				break


func _hit_test(p: Vector2, r: float, e: Node3D) -> bool:
	if String(e.get_meta("kind")) == "boss":
		return absf(p.x - e.position.x) < 55.0 + r and absf(p.y - e.position.z) < 80.0 + r
	return p.distance_to(_epos(e)) < float(e.get_meta("radius")) + r
