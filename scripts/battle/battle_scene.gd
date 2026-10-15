class_name BattleScene
extends Node3D
## Prototipe battle: arena 3D dengan sprite placeholder + HUD sederhana.
## Layout mengikuti battle-layout.md (musuh kiri, party kanan, resolusi dasar 640x360).
## Semua node dibuat dari kode supaya scene .tscn tetap minimal.

enum UiState { BUSY, COMMAND, SKILL, TARGET, SWAP, ENDED }

const MAIN_SCENE := "res://scenes/main.tscn"
const CHARACTER_DIR := "res://data/characters/"
const DEFAULT_ENCOUNTER := "res://data/encounters/02_lima_musuh.tres"
const PRESET_PATHS := [
	"res://data/time_of_day/pagi.tres",
	"res://data/time_of_day/siang.tres",
	"res://data/time_of_day/sore.tres",
	"res://data/time_of_day/malam.tres",
]
const STEP_DELAY := 0.35
const ENEMY_DELAY := 0.45
## Sprite 32x48 px dengan 1 px = 0.03 m.
const PARTY_SIZE := Vector2(0.96, 1.44)
const ENEMY_SIZE := Vector2(1.3, 1.3)
const BOSS_SIZE := Vector2(2.4, 2.6)

## Diisi sebelum change_scene ke battle; kosong = DEFAULT_ENCOUNTER.
static var pending_encounter: EncounterData
## Scene tujuan setelah battle selesai; kosong = MAIN_SCENE.
static var return_scene: String = ""

var system := BattleSystem.new()
var _views: Dictionary = {}  # Battler -> Node3D
var _state: UiState = UiState.BUSY
var _boost := 0
var _weapon := 0
var _pending: Dictionary = {}

var _order_now: Label
var _order_next: Label
var _log: Label
var _party_rows: Array[Label] = []
var _commands: VBoxContainer
var _submenu: VBoxContainer
var _sub_panel: PanelContainer
var _boost_label: Label
var _end_panel: PanelContainer
var _end_label: Label
var _end_button: Button


func _ready() -> void:
	_build_arena()
	_build_hud()
	_connect_system()
	_ensure_party()
	var encounter := pending_encounter
	pending_encounter = null
	if encounter == null:
		encounter = load(DEFAULT_ENCOUNTER)
	GameClock.begin_battle()
	system.setup(PartyManager.get_active(), PartyManager.get_reserves(), encounter)
	_spawn_views()
	_say("%s muncul!" % encounter.display_name)
	system.start()
	_advance()


func _exit_tree() -> void:
	GameClock.end_battle()


func _unhandled_input(event: InputEvent) -> void:
	if _state == UiState.BUSY or _state == UiState.ENDED:
		return
	if event.is_action_pressed("ui_cancel"):
		_show_commands()
		return
	if event.is_action_pressed("boost_up"):
		_set_boost(_boost + 1)
	elif event.is_action_pressed("boost_down"):
		_set_boost(_boost - 1)


# --- alur giliran -----------------------------------------------------------


func _advance() -> void:
	_state = UiState.BUSY
	_clear(_commands)
	_clear(_submenu)
	await get_tree().create_timer(STEP_DELAY).timeout
	var actor := system.next_turn()
	if actor == null:
		return
	_refresh()
	if actor.is_enemy:
		await get_tree().create_timer(ENEMY_DELAY).timeout
		system.perform(system.choose_enemy_action(actor))
		_after_action()
	else:
		_boost = 0
		_weapon = 0
		_show_commands()


func _after_action() -> void:
	_refresh()
	if system.result == BattleSystem.Result.NONE:
		_advance()


func _submit(action: Dictionary) -> void:
	action["boost"] = _boost
	action["weapon"] = _weapon
	_state = UiState.BUSY
	if not system.perform(action):
		_say("Aksi tidak bisa dipakai.")
		_show_commands()
		return
	_after_action()


# --- menu -------------------------------------------------------------------


func _show_commands() -> void:
	_state = UiState.COMMAND
	_clear(_submenu)
	_clear(_commands)
	var actor := system.current
	var weapons := actor.weapons()
	var attack_label := "Serang"
	if not weapons.is_empty():
		attack_label += " (%s)" % BattleTypes.type_name(weapons[_weapon])
	_add_button(_commands, attack_label, _on_attack)
	if weapons.size() > 1:
		_add_button(_commands, "Ganti senjata", _on_cycle_weapon)
	_add_button(_commands, "Skill", _on_skill_menu)
	_add_button(_commands, "Tukar", _on_swap_menu)
	_add_button(_commands, "Bertahan", _submit.bind({"type": BattleSystem.ActionType.DEFEND}))
	var flee := _add_button(
		_commands, "Kabur", _submit.bind({"type": BattleSystem.ActionType.FLEE})
	)
	flee.disabled = not system.can_flee
	_update_boost_label()
	_focus_first(_commands)
	_say("Giliran %s. Boost: Q/E atau L1/R1." % actor.display_name)


func _on_attack() -> void:
	_pick_target(null, {"type": BattleSystem.ActionType.ATTACK})


func _on_cycle_weapon() -> void:
	_weapon = (_weapon + 1) % system.current.weapons().size()
	_show_commands()


func _on_skill_menu() -> void:
	_open_submenu(UiState.SKILL)
	var actor := system.current
	for skill in actor.skills():
		var type_text := BattleTypes.type_name(skill.type)
		if skill.effect == SkillData.Effect.HEAL:
			type_text = "Heal"
		var text := "%s  %s  SP %d" % [skill.display_name, type_text, skill.sp_cost]
		var b := _add_button(_submenu, text, _on_skill_chosen.bind(skill))
		b.disabled = not system.can_use_skill(actor, skill)
	_add_button(_submenu, "Batal", _show_commands)
	_focus_first(_submenu)


func _on_skill_chosen(skill: SkillData) -> void:
	var action := {"type": BattleSystem.ActionType.SKILL, "skill": skill}
	if skill.is_single_target():
		_pick_target(skill, action)
	else:
		action["targets"] = []
		_submit(action)


func _pick_target(skill: SkillData, action: Dictionary) -> void:
	_open_submenu(UiState.TARGET)
	_pending = action
	for t in system.candidates(skill):
		var text := t.display_name
		if t.is_enemy and t.broken:
			text += " [BREAK]"
		_add_button(_submenu, text, _on_target_chosen.bind(t))
	_add_button(_submenu, "Batal", _show_commands)
	_focus_first(_submenu)


func _on_target_chosen(target: Battler) -> void:
	_pending["targets"] = [target]
	_submit(_pending)


func _on_swap_menu() -> void:
	_open_submenu(UiState.SWAP)
	for slot in BattleSystem.SLOTS:
		var a := system.active[slot]
		var r := system.reserve[slot]
		if r == null:
			continue
		var text := (
			"%s <-> %s (HP %d/%d, BP %d)"
			% [a.display_name if a != null else "-", r.display_name, r.hp, r.max_hp, r.bp]
		)
		var b := _add_button(_submenu, text, _on_swap_chosen.bind(slot))
		b.disabled = not system.can_swap(slot)
	_add_button(_submenu, "Batal", _show_commands)
	_focus_first(_submenu)


func _on_swap_chosen(slot: int) -> void:
	system.swap(slot)
	_refresh()
	# Switch tidak memakai giliran: pelaku sekarang bisa jadi cadangan yang baru masuk.
	_boost = 0
	_weapon = 0
	_show_commands()


func _set_boost(value: int) -> void:
	if system.current == null or system.current.is_enemy:
		return
	_boost = clampi(value, 0, mini(BattleSystem.MAX_BOOST, system.current.bp))
	_update_boost_label()


func _update_boost_label() -> void:
	_boost_label.text = "BOOST %d" % _boost if _boost > 0 else ""


# --- signal dari logika -----------------------------------------------------


func _connect_system() -> void:
	system.round_started.connect(func(n: int) -> void: _say("Ronde %d" % n))
	system.damaged.connect(_on_damaged)
	system.healed.connect(_on_healed)
	system.weakness_revealed.connect(
		func(t: Battler, type: int) -> void:
			_say("Kelemahan %s: %s" % [t.display_name, BattleTypes.type_name(type)])
	)
	system.broke.connect(_on_broke)
	system.recovered.connect(_on_recovered)
	system.knocked_out.connect(_on_knocked_out)
	system.swapped.connect(_on_swapped)
	system.action_performed.connect(_on_action_performed)
	system.battle_ended.connect(_on_battle_ended)


func _on_healed(target: Battler, amount: int) -> void:
	_popup(target, "+%d" % amount, Color(0.5, 1, 0.6))


func _on_action_performed(actor: Battler, action: Dictionary) -> void:
	var type: BattleSystem.ActionType = action.get("type")
	match type:
		BattleSystem.ActionType.SKILL:
			var skill: SkillData = action.get("skill")
			var boost := int(action.get("boost", 0))
			var suffix := " (Boost %d)" % boost if boost > 0 else ""
			_say("%s: %s%s" % [actor.display_name, skill.display_name, suffix])
		BattleSystem.ActionType.DEFEND:
			_say("%s bertahan." % actor.display_name)
		BattleSystem.ActionType.FLEE:
			if not system.can_flee:
				_say("Tidak bisa kabur!")


func _on_damaged(target: Battler, amount: int, weak: bool) -> void:
	_popup(target, str(amount), Color(1, 0.85, 0.3) if weak else Color.WHITE)
	var view: Node3D = _views.get(target)
	if view != null:
		# Terdorong menjauh dari lawan: musuh ke kiri, party ke kanan.
		var push := -0.15 if target.is_enemy else 0.15
		var tw := create_tween()
		tw.tween_property(view, "position:x", view.position.x + push, 0.05)
		tw.tween_property(view, "position:x", view.position.x, 0.08)


func _on_broke(target: Battler) -> void:
	_say("BREAK! %s" % target.display_name)
	_popup(target, "BREAK", Color(1, 0.25, 0.2))
	var view: Node3D = _views.get(target)
	if view != null:
		# "Terduduk": sprite memendek. Billboard mengabaikan rotasi, jadi pakai scale.
		var body: MeshInstance3D = view.get_node("Body")
		body.scale = Vector3(1.1, 0.75, 1.0)


func _on_recovered(target: Battler) -> void:
	var view: Node3D = _views.get(target)
	if view != null:
		var body: MeshInstance3D = view.get_node("Body")
		body.scale = Vector3.ONE
	_say("%s pulih dari Break." % target.display_name)


func _on_knocked_out(target: Battler) -> void:
	_say("%s tumbang." % target.display_name)
	var view: Node3D = _views.get(target)
	if view == null:
		return
	if target.is_enemy:
		var tw := create_tween()
		tw.tween_property(view, "scale", Vector3(1, 0.01, 1), 0.3)
		tw.tween_callback(view.hide)
	else:
		_set_view_alpha(view, 0.25)


func _on_swapped(slot: int, now_active: Battler, now_reserve: Battler, manual: bool) -> void:
	# Formasi pilihan pemain dibawa keluar battle; pergantian otomatis karena KO tidak.
	if manual:
		PartyManager.swap_slot(slot)
	var out_name := now_reserve.display_name if now_reserve != null else "-"
	_say("%s masuk menggantikan %s." % [now_active.display_name, out_name])
	_place_party_view(now_active, true)
	if now_reserve != null:
		_place_party_view(now_reserve, true)


func _on_battle_ended(result: BattleSystem.Result) -> void:
	_state = UiState.ENDED
	_clear(_commands)
	_clear(_submenu)
	match result:
		BattleSystem.Result.VICTORY:
			_end_label.text = "MENANG"
		BattleSystem.Result.DEFEAT:
			_end_label.text = "KALAH"
		BattleSystem.Result.FLED:
			_end_label.text = "KABUR"
	_end_panel.show()
	_end_button.grab_focus()


# --- arena 3D ---------------------------------------------------------------


func _build_arena() -> void:
	var preset: TimeOfDayPreset = load(PRESET_PATHS[GameClock.get_phase()])

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = preset.ambient_color.darkened(0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = preset.glow_intensity
	env.adjustment_enabled = true
	env.adjustment_saturation = preset.saturation
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.light_color = preset.sun_color
	sun.light_energy = preset.sun_energy
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-preset.sun_elevation_deg, -60.0, 0.0)
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(26, 14)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.32, 0.3, 0.28)
	ground.material_override = ground_mat
	add_child(ground)

	# battle-layout.md §3.2: FOV 35, pitch -18, sedikit dari kanan-depan.
	var cam := Camera3D.new()
	cam.fov = 35.0
	add_child(cam)
	cam.position = Vector3(1.0, 4.5, 12.0)
	cam.look_at(Vector3(0.5, 0.6, 0.0))
	cam.current = true


func _spawn_views() -> void:
	for slot in BattleSystem.SLOTS:
		for b in [system.active[slot], system.reserve[slot]]:
			if b == null:
				continue
			var view := _make_sprite(b, PARTY_SIZE)
			_views[b] = view
			_place_party_view(b, false)
	var has_boss := false
	for e in system.enemies:
		has_boss = has_boss or e.enemy.large
	var small: Array[Battler] = []
	for e in system.enemies:
		var big := e.enemy.large
		var view := _make_sprite(e, BOSS_SIZE if big else ENEMY_SIZE)
		_views[e] = view
		if big:
			view.position = Vector3(-4.5, 0, 0)
		else:
			small.append(e)
	_place_small_enemies(small, has_boss)


func _make_sprite(b: Battler, size: Vector2) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var body := MeshInstance3D.new()
	body.name = "Body"
	var quad := QuadMesh.new()
	quad.size = size
	body.mesh = quad
	body.position.y = size.y * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = b.placeholder_color()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	body.material_override = mat
	root.add_child(body)
	var label := Label3D.new()
	label.name = "Info"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.008
	label.font_size = 28
	label.outline_size = 8
	label.position.y = size.y + 0.3
	root.add_child(label)
	return root


func _party_position(slot: int, reserve: bool) -> Vector3:
	# battle-layout.md §3.1: diagonal, cadangan 1.2 m di belakang.
	var pos := Vector3(4.0 + 0.6 * slot, 0.0, -1.5 + slot)
	if reserve:
		pos.x += 1.2
	return pos


func _place_party_view(b: Battler, animate: bool) -> void:
	var view: Node3D = _views.get(b)
	if view == null:
		return
	var target := _party_position(b.slot, b.is_reserve)
	if animate:
		create_tween().tween_property(view, "position", target, 0.4).set_trans(Tween.TRANS_QUAD)
	else:
		view.position = target
	var alpha := 1.0
	if b.is_reserve:
		alpha = 0.5
	if not b.is_alive():
		alpha = 0.25
	_set_view_alpha(view, alpha)
	var body: MeshInstance3D = view.get_node("Body")
	body.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if b.is_reserve
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	)


func _place_small_enemies(list: Array[Battler], has_boss: bool) -> void:
	var n := list.size()
	if has_boss:
		for i in n:
			list[i].slot = i
			var z := -1.8 + 3.6 * i / maxf(1.0, n - 1.0)
			_views[list[i]].position = Vector3(-2.8, 0, z)
		return
	# Zigzag 2 kolom: x -5.0 dan -3.5, jarak z 1.0 (0.8 bila 5 musuh).
	var spacing := 0.8 if n >= 5 else 1.0
	for i in n:
		var x := -5.0 if i % 2 == 0 else -3.5
		var z := (i - (n - 1) * 0.5) * spacing
		_views[list[i]].position = Vector3(x, 0, z)


func _set_view_alpha(view: Node3D, alpha: float) -> void:
	var body: MeshInstance3D = view.get_node("Body")
	var mat: StandardMaterial3D = body.material_override
	mat.albedo_color.a = alpha


func _popup(target: Battler, text: String, color: Color) -> void:
	var view: Node3D = _views.get(target)
	if view == null:
		return
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.01
	label.font_size = 36
	label.outline_size = 10
	add_child(label)
	label.global_position = view.global_position + Vector3(0, 1.2, 0.3)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 0.8, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.chain().tween_callback(label.queue_free)


# --- HUD --------------------------------------------------------------------


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 8
	root.theme = theme
	layer.add_child(root)

	_order_now = _add_label(root, Vector2(6, 4))
	_order_next = _add_label(root, Vector2(6, 16))
	_log = _add_label(root, Vector2(6, 232))
	_boost_label = _add_label(root, Vector2(300, 232))
	_boost_label.modulate = Color(1, 0.75, 0.3)

	var cmd_panel := _add_panel(root, Rect2(4, 250, 150, 106))
	var cmd_box := HBoxContainer.new()
	cmd_panel.add_child(cmd_box)
	_commands = VBoxContainer.new()
	_commands.add_theme_constant_override("separation", 0)
	cmd_box.add_child(_commands)

	_sub_panel = _add_panel(root, Rect2(158, 150, 200, 206))
	var scroll := ScrollContainer.new()
	_sub_panel.add_child(scroll)
	_submenu = VBoxContainer.new()
	_submenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_submenu.add_theme_constant_override("separation", 0)
	scroll.add_child(_submenu)

	var party_panel := _add_panel(root, Rect2(362, 250, 274, 106))
	var party_box := VBoxContainer.new()
	party_panel.add_child(party_box)
	for i in BattleSystem.SLOTS:
		var row := Label.new()
		party_box.add_child(row)
		_party_rows.append(row)

	_end_panel = _add_panel(root, Rect2(220, 120, 200, 70))
	var end_box := VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_end_panel.add_child(end_box)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.add_theme_font_size_override("font_size", 16)
	end_box.add_child(_end_label)
	_end_button = _add_button(end_box, "Kembali", _on_back)
	_end_panel.hide()
	_sub_panel.hide()


func _on_back() -> void:
	var target := return_scene if not return_scene.is_empty() else MAIN_SCENE
	return_scene = ""
	get_tree().change_scene_to_file(target)


func _add_label(parent: Control, pos: Vector2) -> Label:
	var label := Label.new()
	label.position = pos
	parent.add_child(label)
	return label


func _add_panel(parent: Control, rect: Rect2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = rect.position
	panel.size = rect.size
	parent.add_child(panel)
	return panel


func _add_button(parent: Control, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


## Fokus ke tombol pertama yang aktif supaya menu bisa dipakai dengan gamepad.
func _focus_first(box: Control) -> void:
	for c in box.get_children():
		var b := c as Button
		if b != null and not b.disabled and not b.is_queued_for_deletion():
			b.grab_focus()
			return


func _clear(box: Control) -> void:
	for c in box.get_children():
		c.queue_free()
	if box == _submenu:
		_sub_panel.hide()


func _open_submenu(state: UiState) -> void:
	_state = state
	_clear(_submenu)
	_sub_panel.show()


func _refresh() -> void:
	_order_now.text = "GILIRAN INI  " + _order_text(system.get_current_order())
	_order_next.text = "BERIKUTNYA   " + _order_text(system.get_next_order())
	for i in BattleSystem.SLOTS:
		var a := system.active[i]
		var r := system.reserve[i]
		if a == null:
			_party_rows[i].text = "-"
			continue
		var marker := ">" if a == system.current else " "
		_party_rows[i].text = (
			"%s%-7s HP %4d/%-4d SP %3d  %s  %s"
			% [
				marker,
				a.display_name,
				a.hp,
				a.max_hp,
				a.sp,
				"#".repeat(a.bp) + "-".repeat(BattleSystem.MAX_BP - a.bp),
				("R:" + r.display_name) if r != null else "",
			]
		)
	for b in _views:
		_update_info(b)


func _order_text(list: Array[Battler]) -> String:
	var parts: PackedStringArray = []
	for b in list:
		parts.append(b.display_name.left(4))
	return " ".join(parts)


func _update_info(b: Battler) -> void:
	var view: Node3D = _views[b]
	var info: Label3D = view.get_node("Info")
	if not b.is_enemy:
		info.text = b.display_name if not b.is_reserve else ""
		return
	var weak: PackedStringArray = []
	for w in b.weaknesses:
		weak.append(BattleTypes.type_name(w) if b.revealed.has(w) else "?")
	var shield := "BREAK" if b.broken else "(%d)" % b.shield
	info.text = "%s %s\n%s" % [b.display_name, shield, " ".join(weak)]


func _say(text: String) -> void:
	_log.text = text


func _ensure_party() -> void:
	if PartyManager.member_count() > 0:
		return
	# Roster default untuk prototipe: urutan file = aktif 1-4 lalu cadangan.
	var files := Array(DirAccess.get_files_at(CHARACTER_DIR))
	files.sort()
	for f in files:
		var path: String = f.trim_suffix(".remap")
		if path.ends_with(".tres"):
			PartyManager.add_member(load(CHARACTER_DIR + path))
