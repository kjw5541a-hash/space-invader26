# Space Invader - Godot 4 / Neon / Stage + Boss patterns
# 조작: 키보드 좌우(방향키/AD) + 하단 터치 버튼. 발사 자동.
extends Node2D

const W := 480.0
const H := 720.0
const FIRE_INTERVAL := 0.22
const PLAYER_SPEED := 360.0
const PLAYER_Y := 630.0

var score := 0
var wave := 0
var lives := 3
var game_over := false
var invincible_t := 0.0
var blink_t := 0.0
var next_wave_cd := -1.0

var player: Node2D = null
var player_alive := true
var enemies: Array = []
var p_bullets: Array = []
var e_bullets: Array = []
var shards: Array = []
var stars: Array = []

var enemy_dir := 1.0
var enemy_speed := 42.0
var drop_cd := 0.0
var fire_cd := 1.0
var fire_interval := 0.9
var bullet_speed := 260.0

var boss: Node2D = null
var boss_pattern := -1
var boss_ptime := 0.0
var boss_pinterval := 3.6
var boss_bspeed := 220.0
var spiral_on := false
var spiral_t := 0.0
var spiral_emit := 0.0
var spiral_ang := 0.0
var wall_on := false
var wall_t := 0.0
var wall_emit := 0.0
var wall_gap := 240.0

var touch_left := false
var touch_right := false
var _fire_accum := 0.0
var _msg_t := -1.0

var score_label: Label = null
var wave_label: Label = null
var lives_label: Label = null
var msg_label: Label = null
var boss_bar: ProgressBar = null

var sfx_streams := {}
var sfx_pool: Array = []
var sfx_vol := {
	"shoot": -14.0, "enemy_shoot": -16.0, "explosion": -8.0,
	"hit": -6.0, "wave": -8.0, "boss": -8.0, "gameover": -8.0, "tick": -16.0,
}
var bgm_player: AudioStreamPlayer = null


func _ready() -> void:
	_build_background()
	_build_audio()
	_build_ui()
	_build_player()
	next_wave()
	_bgm_start()


# ---------- 생성 헬퍼 ----------

func _poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p


func _oct(r: float, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


func _rect_pts(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-w / 2, -h / 2), Vector2(w / 2, -h / 2),
		Vector2(w / 2, h / 2), Vector2(-w / 2, h / 2),
	])


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.size = Vector2(W, H)
	add_child(bg)
	for i in range(90):
		var s := ColorRect.new()
		var sz := randf_range(1.0, 3.0)
		s.size = Vector2(sz, sz)
		s.position = Vector2(randf_range(0, W), randf_range(0, H))
		s.color = Color(0.55, 0.55, 1.0, randf_range(0.3, 1.0))
		add_child(s)
		stars.append({"n": s, "speed": randf_range(20.0, 90.0)})


func _build_audio() -> void:
	for n in sfx_vol.keys():
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_pool.append(p)
		var st = load("res://sounds/%s.wav" % n)
		if st != null:
			sfx_streams[n] = st
	bgm_player = AudioStreamPlayer.new()
	add_child(bgm_player)
	var bgm_wav := load("res://sounds/bgm.wav") as AudioStreamWAV
	if bgm_wav != null:
		bgm_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		bgm_player.stream = bgm_wav
		bgm_player.volume_db = -11.0


func _bgm_start() -> void:
	if bgm_player and bgm_player.stream and not bgm_player.playing:
		bgm_player.play()


func _sfx(n: String) -> void:
	if not sfx_streams.has(n):
		return
	for p in sfx_pool:
		if not p.playing:
			p.stream = sfx_streams[n]
			p.volume_db = sfx_vol.get(n, -10.0)
			p.play()
			return


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	score_label = Label.new()
	score_label.position = Vector2(12, 10)
	score_label.add_theme_font_size_override("font_size", 20)
	score_label.add_theme_color_override("font_color", Color(0, 1, 1))
	layer.add_child(score_label)

	lives_label = Label.new()
	lives_label.position = Vector2(12, 36)
	lives_label.add_theme_font_size_override("font_size", 20)
	lives_label.add_theme_color_override("font_color", Color(1, 0.33, 0.47))
	layer.add_child(lives_label)

	wave_label = Label.new()
	wave_label.position = Vector2(W - 140, 10)
	wave_label.size = Vector2(128, 30)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.add_theme_color_override("font_color", Color(1, 0.3, 1))
	layer.add_child(wave_label)

	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(W / 2 - 150, 56)
	boss_bar.size = Vector2(300, 12)
	boss_bar.min_value = 0
	boss_bar.max_value = 100
	boss_bar.value = 100
	boss_bar.show_percentage = false
	boss_bar.visible = false
	layer.add_child(boss_bar)

	msg_label = Label.new()
	msg_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 34)
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.add_theme_color_override("font_outline_color", Color(0, 0.8, 0.8))
	msg_label.add_theme_constant_override("outline_size", 8)
	layer.add_child(msg_label)

	var left_btn := Button.new()
	left_btn.text = "◀"
	left_btn.position = Vector2(16, H - 130)
	left_btn.size = Vector2(104, 104)
	left_btn.focus_mode = Control.FOCUS_NONE
	left_btn.add_theme_font_size_override("font_size", 42)
	left_btn.add_theme_color_override("font_color", Color(0, 1, 1))
	left_btn.modulate = Color(1, 1, 1, 0.9)
	left_btn.button_down.connect(func() -> void: touch_left = true)
	left_btn.button_up.connect(func() -> void: touch_left = false)
	layer.add_child(left_btn)

	var right_btn := Button.new()
	right_btn.text = "▶"
	right_btn.position = Vector2(W - 120, H - 130)
	right_btn.size = Vector2(104, 104)
	right_btn.focus_mode = Control.FOCUS_NONE
	right_btn.add_theme_font_size_override("font_size", 42)
	right_btn.add_theme_color_override("font_color", Color(1, 0.3, 1))
	right_btn.modulate = Color(1, 1, 1, 0.9)
	right_btn.button_down.connect(func() -> void: touch_right = true)
	right_btn.button_up.connect(func() -> void: touch_right = false)
	layer.add_child(right_btn)

	_refresh_hud()


func _refresh_hud() -> void:
	if score_label:
		score_label.text = "SCORE %d" % score
	if wave_label:
		wave_label.text = "WAVE %d" % maxi(1, wave)
	if lives_label:
		lives_label.text = "♥".repeat(maxi(0, lives)) if lives > 0 else "—"


func _build_player() -> void:
	player = Node2D.new()
	player.position = Vector2(W / 2, PLAYER_Y)
	var glow := _poly(PackedVector2Array([
		Vector2(0, -20), Vector2(25, 19), Vector2(0, 10), Vector2(-25, 19),
	]), Color(0, 1, 1, 0.22))
	player.add_child(glow)
	player.add_child(_poly(PackedVector2Array([
		Vector2(0, -14), Vector2(18, 14), Vector2(0, 7), Vector2(-18, 14),
	]), Color(0, 1, 1)))
	player.add_child(_poly(_oct(3.5), Color.WHITE))
	player.get_child(2).position = Vector2(0, 2)
	add_child(player)
	player_alive = true


# ---------- 웨이브 / 난이도 ----------

func next_wave() -> void:
	wave += 1
	_refresh_hud()
	enemy_dir = 1.0
	drop_cd = 0.0
	spiral_on = false
	wall_on = false
	var is_boss := wave % 3 == 0
	if is_boss:
		_spawn_boss()
		_show_msg("WAVE %d\nBOSS!" % wave, 1.4)
		_sfx("boss")
	else:
		_spawn_formation()
		_show_msg("WAVE %d" % wave, 1.2)
		_sfx("wave")


func _spawn_formation() -> void:
	var cols := 6 + (1 if wave >= 4 else 0) + (1 if wave >= 7 else 0)
	var rows := 3 + mini(3, wave / 2)
	var hp_small := 1 + wave / 4
	var hp_mid := 2 + wave / 3
	enemy_speed = minf(150.0, 30.0 + wave * 9.0)
	fire_interval = maxf(0.26, 0.95 - wave * 0.09)
	fire_cd = fire_interval
	bullet_speed = 235.0 + wave * 26.0
	boss = null
	if boss_bar:
		boss_bar.visible = false
	var dx := 360.0 / maxf(1.0, float(cols - 1)) if cols > 1 else 0.0
	for r in range(rows):
		for c in range(cols):
			var mid := r >= rows - 1
			var e := Node2D.new()
			e.position = Vector2(60 + c * dx, 110 + r * 52)
			if mid:
				e.add_child(_poly(_rect_pts(40, 24), Color(1, 0.45, 0.1, 0.25)))
				e.add_child(_poly(_rect_pts(34, 19), Color(1, 0.62, 0.05)))
				var core := _poly(_oct(4.5), Color(1, 0.15, 0.15))
				core.position = Vector2(-8, 0)
				e.add_child(core)
				var core2 := core.duplicate()
				core2.position = Vector2(8, 0)
				e.add_child(core2)
				e.set_meta("hp", hp_mid)
				e.set_meta("score_v", 30)
				e.set_meta("radius", 19.0)
			else:
				e.add_child(_poly(_oct(15, 8), Color(1, 0.3, 1, 0.25)))
				e.add_child(_poly(_oct(11, 8), Color(1, 0.3, 1)))
				var eye := _poly(_oct(3.0, 6), Color(0.02, 0.02, 0.06))
				eye.position = Vector2(-4, -1)
				e.add_child(eye)
				var eye2 := eye.duplicate()
				eye2.position = Vector2(4, -1)
				e.add_child(eye2)
				e.set_meta("hp", hp_small)
				e.set_meta("score_v", 20)
				e.set_meta("radius", 14.0)
			e.set_meta("kind", "mid" if mid else "small")
			e.set_meta("flash", 0.0)
			add_child(e)
			enemies.append(e)


func _spawn_boss() -> void:
	enemy_speed = 60.0
	fire_interval = 9.0
	var hp := 45 + wave * 14
	var b := Node2D.new()
	b.position = Vector2(W / 2, 150)
	b.add_child(_poly(_rect_pts(142, 66), Color(1, 1, 1, 0.28)))
	b.add_child(_poly(_rect_pts(130, 56), Color(1, 0.13, 0.33)))
	for i in range(3):
		var core := _poly(_oct(11, 8), Color(0.25, 0.02, 0.08))
		core.position = Vector2(-30 + i * 30, 0)
		b.add_child(core)
		var ring := _poly(_oct(6, 8), Color(1, 0.9, 0.2))
		ring.position = core.position
		b.add_child(ring)
	b.set_meta("hp", hp)
	b.set_meta("max_hp", hp)
	b.set_meta("score_v", 500)
	b.set_meta("kind", "boss")
	b.set_meta("flash", 0.0)
	add_child(b)
	enemies.append(b)
	boss = b
	boss_pattern = -1
	boss_ptime = 2.0
	boss_pinterval = maxf(2.0, 3.8 - wave * 0.15)
	boss_bspeed = 200.0 + wave * 12.0
	if boss_bar:
		boss_bar.visible = true
		boss_bar.value = 100


# ---------- 발사 ----------

func _spawn_p_bullet(pos: Vector2) -> void:
	var b := Node2D.new()
	b.position = pos
	b.add_child(_poly(_rect_pts(5, 16), Color(0, 1, 1)))
	b.set_meta("vel", Vector2(0, -560))
	b.set_meta("radius", 8.0)
	add_child(b)
	p_bullets.append(b)


func _spawn_e_bullet(pos: Vector2, vel: Vector2) -> void:
	var b := Node2D.new()
	b.position = pos
	b.add_child(_poly(_rect_pts(7, 14), Color(1, 0.27, 0.53)))
	b.set_meta("vel", vel)
	b.set_meta("radius", 8.0)
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
	var shooters := mini(alive.size(), 1 + wave / 2)
	for i in range(shooters):
		var s = alive[randi() % alive.size()]
		_spawn_e_bullet(s.position + Vector2(0, 16),
			Vector2(randf_range(-40, 40), bullet_speed))
	_sfx("enemy_shoot")


# ---------- 보스 탄막 패턴 ----------

func _run_boss_pattern() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	var n_aim := 5 + (2 if wave >= 6 else 0)
	if boss_pattern == 0:
		var to_p: Vector2 = (player.position - boss.position).normalized()
		var base := to_p.angle()
		for i in range(n_aim):
			var off := (float(i) - float(n_aim - 1) / 2.0) * 0.16
			var v := Vector2(cos(base + off), sin(base + off)) * boss_bspeed
			_spawn_e_bullet(boss.position + Vector2(0, 30), v)
		_sfx("enemy_shoot")
	elif boss_pattern == 1:
		var count := 16 + mini(8, wave)
		for ring in range(2):
			var rot := (TAU / count) * (0.5 if ring == 1 else 0.0) + randf() * 0.2
			var sp := boss_bspeed * (0.8 if ring == 0 else 1.1)
			for i in range(count):
				var a := rot + TAU * float(i) / float(count)
				_spawn_e_bullet(boss.position + Vector2(0, 10), Vector2(cos(a), sin(a)) * sp)
		_sfx("enemy_shoot")
	elif boss_pattern == 2:
		spiral_on = true
		spiral_t = 2.2
		spiral_emit = 0.0
	elif boss_pattern == 3:
		wall_on = true
		wall_t = 2.0
		wall_emit = 0.0
		wall_gap = player.position.x if player else W / 2


func _boss_continuous(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		spiral_on = false
		wall_on = false
		return
	if spiral_on:
		spiral_t -= delta
		spiral_emit -= delta
		spiral_ang += delta * (2.4 + wave * 0.12)
		var arms := 2 + (1 if wave >= 6 else 0)
		if spiral_emit <= 0.0:
			spiral_emit = 0.055
			for k in range(arms):
				var a := spiral_ang + TAU * float(k) / float(arms)
				_spawn_e_bullet(boss.position + Vector2(0, 20),
					Vector2(cos(a), sin(a)) * (boss_bspeed * 0.75))
		if spiral_t <= 0.0:
			spiral_on = false
	if wall_on:
		wall_t -= delta
		wall_emit -= delta
		if player:
			wall_gap = lerpf(wall_gap, player.position.x, delta * 1.6)
		var gap_half := maxf(42.0, 66.0 - wave * 2.0)
		if wall_emit <= 0.0:
			wall_emit = 0.16
			var x := 20.0
			while x < W - 10.0:
				if absf(x - wall_gap) > gap_half:
					_spawn_e_bullet(Vector2(x, boss.position.y + 34), Vector2(0, boss_bspeed * 0.9))
				x += 34.0
		if wall_t <= 0.0:
			wall_on = false


# ---------- 타격 ----------

func _damage_enemy(e: Node2D, dmg: int = 1) -> void:
	if not is_instance_valid(e):
		return
	var hp := int(e.get_meta("hp")) - dmg
	e.set_meta("hp", hp)
	e.set_meta("flash", 0.08)
	_explode(e.position, Color(1, 0.93, 0.2) if e.get_meta("kind") != "boss" else Color(1, 0.13, 0.33), 7 if e.get_meta("kind") != "boss" else 14)
	if hp <= 0:
		score += int(e.get_meta("score_v"))
		_refresh_hud()
		_explode(e.position, Color(1, 0.5, 0.1), 10)
		_sfx("explosion")
		enemies.erase(e)
		if e == boss:
			boss = null
			spiral_on = false
			wall_on = false
			if boss_bar:
				boss_bar.visible = false
		e.queue_free()
		if enemies.is_empty() and not game_over:
			next_wave_cd = 0.9
	else:
		_sfx("tick")
		if e.get_meta("kind") == "boss" and boss_bar:
			var r := float(hp) / float(maxi(1, int(e.get_meta("max_hp"))))
			boss_bar.value = r * 100.0


func _hit_player() -> void:
	if game_over or invincible_t > 0.0 or not player_alive:
		return
	lives -= 1
	_refresh_hud()
	_explode(player.position, Color(0, 1, 1), 14)
	_sfx("hit")
	if lives <= 0:
		_do_game_over()
	else:
		invincible_t = 2.0


func _do_game_over() -> void:
	game_over = true
	player_alive = false
	if player:
		player.visible = false
	_show_msg("GAME OVER\nSCORE %d\n탭하여 재시작" % score, 100000.0)
	_sfx("gameover")
	if bgm_player:
		bgm_player.volume_db = -20.0


func _show_msg(txt: String, dur: float) -> void:
	if msg_label:
		msg_label.text = txt
		msg_label.modulate = Color(1, 1, 1, 1)
	_msg_t = dur

func _explode(pos: Vector2, color: Color, n: int) -> void:
	for i in range(n):
		var s := ColorRect.new()
		var sz := randf_range(2.0, 5.0)
		s.size = Vector2(sz, sz)
		s.position = pos
		s.color = color
		add_child(s)
		shards.append({
			"n": s,
			"vel": Vector2(randf_range(-160, 160), randf_range(-160, 160)),
			"life": randf_range(0.25, 0.5),
		})


func _unhandled_input(event: InputEvent) -> void:
	if not game_over:
		return
	var tap := false
	if event is InputEventMouseButton and event.pressed:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		tap = true
	if tap:
		get_tree().reload_current_scene()


# ---------- 메인 루프 ----------

func _physics_process(delta: float) -> void:
	for st in stars:
		var r: ColorRect = st["n"]
		r.position.y += float(st["speed"]) * delta
		if r.position.y > H:
			r.position.y = 0
			r.position.x = randf_range(0, W)

	for i in range(shards.size() - 1, -1, -1):
		var sh: Dictionary = shards[i]
		if not is_instance_valid(sh["n"]):
			shards.remove_at(i)
			continue
		sh["life"] = float(sh["life"]) - delta
		if float(sh["life"]) <= 0.0:
			sh["n"].queue_free()
			shards.remove_at(i)
			continue
		sh["n"].position += (sh["vel"] as Vector2) * delta
		sh["n"].modulate.a = clampf(float(sh["life"]) * 2.5, 0.0, 1.0)

	if game_over:
		return

	if invincible_t > 0.0:
		invincible_t -= delta
		blink_t += delta
		if player:
			player.visible = fmod(blink_t, 0.2) < 0.12
		if invincible_t <= 0.0 and player:
			player.visible = true

	# 중앙 메시지 페이드 (게임오버 메시지는 유지)
	if _msg_t > 0.0 and not game_over and msg_label:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg_t = -1.0
			msg_label.text = ""
		elif _msg_t < 0.4:
			msg_label.modulate.a = clampf(_msg_t / 0.4, 0.0, 1.0)

	# 플레이어 이동
	if player_alive and player:
		var dir := 0.0
		if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or touch_left:
			dir -= 1.0
		if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or touch_right:
			dir += 1.0
		player.position.x = clampf(player.position.x + dir * PLAYER_SPEED * delta, 20.0, W - 20.0)

	# 자동 발사
	if player_alive:
		fire_cd -= delta
		# 보스전에서는 발사 간격 약간 단축 (DPS 보정)
		var interval := FIRE_INTERVAL
		if boss != null and is_instance_valid(boss):
			interval = 0.19
		if fire_cd <= 0.0:
			fire_cd = interval
			_spawn_p_bullet(player.position + Vector2(0, -24))
			_sfx("shoot")

	# 적 발사 (일반 웨이브)
	if boss == null or not is_instance_valid(boss):
		_fire_tick_accum(delta)
	else:
		# 보스 이동 + 패턴 스케줄
		var t := float(Time.get_ticks_msec()) / 1000.0
		boss.position.x = W / 2 + sin(t * 1.4) * (W / 2 - 90.0)
		boss_ptime += delta
		if boss_ptime >= boss_pinterval:
			boss_ptime = 0.0
			boss_pattern = (boss_pattern + 1) % 4
			_run_boss_pattern()
		_boss_continuous(delta)
		if boss_bar and is_instance_valid(boss):
			var r2 := float(int(boss.get_meta("hp"))) / float(maxi(1, int(boss.get_meta("max_hp"))))
			boss_bar.value = r2 * 100.0

	# 일반 적 이동 (벽에 닿으면 반전 + 낙하, 낙하는 쿨다운으로 제한)
	if (boss == null or not is_instance_valid(boss)) and not enemies.is_empty():
		drop_cd -= delta
		var min_x := 1e9
		var max_x := -1e9
		for e in enemies:
			if is_instance_valid(e):
				min_x = minf(min_x, e.position.x)
				max_x = maxf(max_x, e.position.x)
		if (enemy_dir > 0 and max_x > W - 24) or (enemy_dir < 0 and min_x < 24):
			enemy_dir *= -1.0
			if drop_cd <= 0.0:
				drop_cd = 0.7
				for e in enemies:
					if is_instance_valid(e):
						e.position.y += 12.0
		for e in enemies:
			if is_instance_valid(e):
				e.position.x += enemy_dir * enemy_speed * delta
		# 침투 체크
		if player_alive:
			for e in enemies:
				if is_instance_valid(e) and e.position.y > PLAYER_Y - 30.0:
					enemies.erase(e)
					e.queue_free()
					_hit_player()
					break

	# 플래시 복원
	for e in enemies:
		if is_instance_valid(e) and float(e.get_meta("flash")) > 0.0:
			e.set_meta("flash", float(e.get_meta("flash")) - delta)
			e.modulate = Color(3, 3, 3) if float(e.get_meta("flash")) > 0.0 else Color.WHITE

	# 총알 이동 + 충돌
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
		b.position += (b.get_meta("vel") as Vector2) * delta
		if b.position.y < -30 or b.position.y > H + 30 or b.position.x < -30 or b.position.x > W + 30:
			b.queue_free()
			p_bullets.remove_at(i)
	for i in range(e_bullets.size() - 1, -1, -1):
		var b2 = e_bullets[i]
		if not is_instance_valid(b2):
			e_bullets.remove_at(i)
			continue
		b2.position += (b2.get_meta("vel") as Vector2) * delta
		if b2.position.y < -30 or b2.position.y > H + 30 or b2.position.x < -30 or b2.position.x > W + 30:
			b2.queue_free()
			e_bullets.remove_at(i)


func _check_collisions() -> void:
	# 플레이어 총알 vs 적
	for bi in range(p_bullets.size() - 1, -1, -1):
		if bi >= p_bullets.size():
			continue
		var b = p_bullets[bi]
		if not is_instance_valid(b):
			continue
		var hit := false
		for e in enemies:
			if not is_instance_valid(e):
				continue
			if _hit_test(b.position, 8.0, e):
				b.queue_free()
				p_bullets.remove_at(bi)
				_damage_enemy(e)
				hit = true
				break
		if hit:
			continue
	# 적 총알 vs 플레이어
	if player_alive and invincible_t <= 0.0:
		for bi2 in range(e_bullets.size() - 1, -1, -1):
			var b2 = e_bullets[bi2]
			if not is_instance_valid(b2):
				continue
			if b2.position.distance_to(player.position) < 22.0:
				b2.queue_free()
				e_bullets.remove_at(bi2)
				_hit_player()
				break
	# 적 vs 플레이어 직접 충돌
	if player_alive and invincible_t <= 0.0:
		for e in enemies:
			if is_instance_valid(e) and _hit_test(player.position, 14.0, e):
				enemies.erase(e)
				e.queue_free()
				_hit_player()
				break


func _hit_test(p: Vector2, r: float, e: Node2D) -> bool:
	if String(e.get_meta("kind")) == "boss":
		return absf(p.x - e.position.x) < 68.0 + r and absf(p.y - e.position.y) < 32.0 + r
	return p.distance_to(e.position) < float(e.get_meta("radius")) + r
