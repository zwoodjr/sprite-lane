extends CharacterBody2D

## Active companion — Noel / Bentley / Lillie kits (wasteland sheet style).

signal rampage_started(target: Node)
signal rampage_ended

## One 128 px pet frame spans this many world px (same px density as heroes,
## so the dogs read dog-sized next to their human).
## Style bible: pets are drawn at their size (52-64 px, chibi heads), so they
## draw at the shared texel density like everything else (no 0.7x scale).
const PET_VISUAL := 1.0
const PET_FRAME_WORLD := 128.0 * UnitAnim.TEXEL * PET_VISUAL
const FEET_Y := 20.0
## Standing still this long → sit down.
const SIT_AFTER := 2.0

var _def: Dictionary = {}
var _player: Node2D
var _target: Node2D
var _rampaging: bool = false
var _bite_cd: float = 0.0
var _aoe_cd: float = 0.0
var _bark_cd: float = 1.5
var _find_cd: float = 2.5
var _ram_cd: float = 2.0
var _ram_left: float = 0.0
var _ram_dir: Vector2 = Vector2.RIGHT
var _ram_wake_hit: Dictionary = {} ## instance_id -> true this charge
var _accent_left: float = 0.0
var _bob_t: float = 0.0
var _flash_left: float = 0.0
var _anim: UnitAnim = UnitAnim.new()
var _anim_prefix: String = ""
var _still_t: float = 0.0
## Kennel: rampage linger / chain state.
var _linger_left: float = 0.0
var _lingering: bool = false
var _chains_left: int = 0
## Depth E6 mech tricks.
var _strafe_cd: float = 2.0
var _mortar_cd: float = 3.0

@onready var body: Sprite2D = $Body
@onready var name_label: Label = $NameLabel

func setup(owner_player: Node2D, def: Dictionary) -> void:
	_player = owner_player
	_def = def.duplicate(true)
	if is_inside_tree():
		_apply_look()

func _ready() -> void:
	add_to_group("pets")
	collision_layer = 0
	collision_mask = 1
	if _def.is_empty() and GameState.pet:
		_def = GameState.pet.duplicate(true)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
	_apply_look()
	UnitAnim.add_contact_shadow(self, 50.0, FEET_Y, 0.4 if bool(_def.get("flying", false)) else 0.5)
	## Drone Bat flies over walls and rocks.
	if bool(_def.get("flying", false)):
		collision_mask = 0
	if _player and _player.has_signal("attacked"):
		if not _player.attacked.is_connected(_on_player_attacked):
			_player.attacked.connect(_on_player_attacked)
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)

func _ability_id() -> String:
	return str(_def.get("ability_id", ""))

func _accent_active() -> bool:
	return _rampaging or _ram_left > 0.0 or _accent_left > 0.0

func _apply_look() -> void:
	var prefix := str(_def.get("anim", "res://assets/sprites/pets/noel/noel"))
	if body and prefix != _anim_prefix:
		_anim_prefix = prefix
		## Native density for every pet (mech frame_world sizes predate the visual tier).
		## "hd": strips painted at 2x (256 px frames) keep the same world size.
		_anim.setup(body, prefix, PET_FRAME_WORLD, FEET_Y, float(_def.get("hd", 1.0)))
		## Y-sorted with the hero, mobs and standing props (World y-sort).
		z_index = 0
	if name_label:
		name_label.text = str(_def.get("name", "Pet"))
		name_label.add_theme_font_size_override("font_size", 10)
		var col := Color(0.92, 0.86, 0.72)
		if _rampaging or _ram_left > 0.0:
			col = Color(1.0, 0.45, 0.3)
		elif _accent_left > 0.0:
			col = Color(1.0, 0.85, 0.45)
		name_label.add_theme_color_override("font_color", col)
		## Slim HUD look: the name only shows while the pet is doing something.
		name_label.visible = col != Color(0.92, 0.86, 0.72)

func _physics_process(delta: float) -> void:
	_bite_cd = maxf(0.0, _bite_cd - delta)
	_aoe_cd = maxf(0.0, _aoe_cd - delta)
	_bark_cd = maxf(0.0, _bark_cd - delta)
	_find_cd = maxf(0.0, _find_cd - delta)
	_ram_cd = maxf(0.0, _ram_cd - delta)
	_strafe_cd = maxf(0.0, _strafe_cd - delta)
	_mortar_cd = maxf(0.0, _mortar_cd - delta)
	_flash_left = maxf(0.0, _flash_left - delta)
	var was_accent := _accent_left > 0.0
	_accent_left = maxf(0.0, _accent_left - delta)
	if was_accent and _accent_left <= 0.0 and not _rampaging and _ram_left <= 0.0:
		_apply_look()
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	_refresh_rampage_target()
	_update_move(delta)
	_update_combat(delta)
	_update_visuals(delta)

func _refresh_rampage_target() -> void:
	if not _rampaging:
		return
	var alive := _target != null and is_instance_valid(_target) and not _target.is_queued_for_deletion() \
		and _target.is_in_group("enemies")
	if alive:
		return
	## Kennel top rank: chain to the next attacker close by.
	if _chains_left > 0:
		var nxt := _nearest_enemy(float(_def.get("rampage_aoe_radius", 110.0)) * 2.5)
		if nxt != null:
			_chains_left -= 1
			_target = nxt
			Juice.float_text(global_position + Vector2(0, -28), "NEXT!", Color(1.0, 0.45, 0.25), 15)
			return
	## Kennel: the rampage lingers a moment after the attacker drops.
	if not _lingering and float(_def.get("rampage_linger", 0.0)) > 0.0:
		_lingering = true
		_linger_left = float(_def.get("rampage_linger", 0.0))
		_target = null
		return
	if _lingering:
		_linger_left -= get_physics_process_delta_time()
		if _linger_left > 0.0:
			return
	_end_rampage()

func _on_player_attacked(attacker: Node) -> void:
	if attacker == null or not is_instance_valid(attacker):
		return
	if not attacker.is_in_group("enemies"):
		return
	if _ability_id() != "territorial_rampage":
		_target = attacker as Node2D
		return
	_begin_rampage(attacker as Node2D)

func _begin_rampage(attacker: Node2D) -> void:
	_target = attacker
	_rampaging = true
	_linger_left = 0.0
	_lingering = false
	_chains_left = int(_def.get("rampage_chain", 0))
	_aoe_cd = 0.05
	_apply_look()
	Juice.sfx_at("noel_growl", global_position)
	Juice.sfx_at("noel_bark", global_position, -2.0)
	Juice.burst(global_position, Color(1.0, 0.35, 0.2), 20, 200.0, 0.55)
	Juice.float_text(global_position + Vector2(0, -28), "NOEL RAMPAGE!", Color(1.0, 0.45, 0.25), 18)
	Juice.shake(0.18)
	rampage_started.emit(_target)

func _end_rampage() -> void:
	if not _rampaging:
		_target = null
		return
	_rampaging = false
	_target = null
	_linger_left = 0.0
	_lingering = false
	_apply_look()
	Juice.float_text(global_position + Vector2(0, -24), "Settled", Color(0.85, 0.8, 0.7), 14)
	rampage_ended.emit()

func _update_move(delta: float) -> void:
	## Lillie ram charge overrides follow.
	if _ram_left > 0.0:
		_tick_ram(delta)
		return
	var speed := float(_def.get("follow_speed", 260.0))
	if _rampaging:
		speed *= float(_def.get("rampage_speed_mult", 1.5))
	var goal: Vector2
	if _rampaging and _target != null and is_instance_valid(_target):
		goal = _target.global_position
	elif _target != null and is_instance_valid(_target) and global_position.distance_to(_target.global_position) < 220.0:
		goal = _target.global_position
	else:
		var facing := Vector2.RIGHT
		if _player.get("velocity") is Vector2 and (_player.velocity as Vector2).length() > 20.0:
			facing = (_player.velocity as Vector2).normalized()
		var behind := -facing * 36.0 + facing.orthogonal() * 14.0
		goal = _player.global_position + behind
	var to := goal - global_position
	var dist := to.length()
	if dist > 8.0:
		var want := to.normalized() * speed
		if not _rampaging and dist < 40.0:
			want *= dist / 40.0
		velocity = velocity.move_toward(want, 1800.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 2200.0 * delta)
	move_and_slide()
	if to.length() > 4.0 and absf(to.x) > 2.0 and velocity.length() > 20.0:
		_anim.set_facing(to.x < 0.0)

func _update_combat(delta: float) -> void:
	match _ability_id():
		"territorial_rampage":
			if _rampaging:
				_tick_rampage_aoe()
				return
			_idle_bite()
		"talker_finder":
			_tick_bentley()
			_idle_bite()
		"ram_headbutt", "shock_pounce":
			if _ram_left <= 0.0:
				_try_start_ram()
			_idle_bite()
		"strafe_run":
			if _strafe_cd <= 0.0:
				_do_strafe()
			_idle_bite()
		"mortar_back":
			if _mortar_cd <= 0.0:
				_do_mortar()
			_idle_bite()
		_:
			_idle_bite()

func _idle_bite() -> void:
	if _bite_cd > 0.0 or _ram_left > 0.0:
		return
	var nearest := _nearest_enemy(float(_def.get("bite_range", 40.0)) + 8.0)
	if nearest == null:
		return
	_bite(nearest)

func _tick_rampage_aoe() -> void:
	if _aoe_cd > 0.0:
		return
	_aoe_cd = float(_def.get("rampage_tick", 0.28))
	var radius := float(_def.get("rampage_aoe_radius", 110.0))
	var dmg := float(_def.get("rampage_aoe_damage", 38.0)) * GameState.pet_power_mult() * GameState.aoe_damage_mult()
	Juice.burst(global_position, Color(1.0, 0.4, 0.2, 0.9), 14, radius * 1.4, 0.35, 1.2)
	Juice.dust_puff(global_position + Vector2(0, 10), 10)
	Juice.shake(0.1)
	_flash_left = 0.12
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, (e.global_position - global_position).normalized(), float(_def.get("bite_knock", 30.0)))
	if _target != null and is_instance_valid(_target) and _target.has_method("take_damage"):
		if global_position.distance_to(_target.global_position) <= radius:
			_target.call("take_damage", dmg * 0.35, (_target.global_position - global_position).normalized(), float(_def.get("bite_knock", 30.0)))

func _tick_bentley() -> void:
	if _bark_cd <= 0.0:
		_do_bark()
	if _find_cd <= 0.0:
		_do_find()

func _do_bark() -> void:
	_bark_cd = float(_def.get("bark_cooldown", 5.5))
	_accent_left = 0.55
	_apply_look()
	var radius := float(_def.get("bark_radius", 200.0))
	var dur := float(_def.get("bark_distract_sec", 1.4))
	var stun := float(_def.get("bark_stun", 0.0))
	var mark_mult := float(_def.get("bark_mark_mult", 1.0))
	var mark_t := float(_def.get("bark_mark_time", 0.0))
	Juice.sfx_at("bentley_yip", global_position)
	Juice.float_text(global_position + Vector2(0, -26), "BARK!", Color(1.0, 0.9, 0.5), 16)
	_anim.play("bark")
	Juice.burst(global_position, Color(1.0, 0.85, 0.4), 12, radius * 0.6, 0.35)
	var n := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		if not (node is Node2D) or not is_instance_valid(node):
			continue
		if global_position.distance_to((node as Node2D).global_position) > radius:
			continue
		if node.has_method("distract"):
			node.call("distract", dur)
			n += 1
		## Flag: marked enemies take extra damage; kennel ranks add a short stun.
		if node.has_method("apply_status"):
			if mark_t > 0.0 and mark_mult > 1.0:
				node.call("apply_status", "mark", mark_t, mark_mult)
			if stun > 0.0:
				node.call("apply_status", "stun", stun)
	if n > 0:
		Juice.shake(0.08)

func _do_find() -> void:
	_find_cd = float(_def.get("find_cooldown", 7.0))
	_accent_left = maxf(_accent_left, 0.4)
	_apply_look()
	var radius := float(_def.get("find_radius", 520.0))
	Juice.sfx_at("pet_gift", global_position)
	Juice.float_text(global_position + Vector2(0, -26), "FOUND!", Color(0.7, 0.95, 0.6), 15)
	_anim.play("drop")
	## Ping breakables in range.
	for crate in get_tree().get_nodes_in_group("breakables"):
		if not (crate is Node2D) or not is_instance_valid(crate):
			continue
		if global_position.distance_to((crate as Node2D).global_position) > radius:
			continue
		if crate.has_method("ping"):
			crate.call("ping")
	## Pull pickups toward the player.
	var pulled := 0
	for pu in get_tree().get_nodes_in_group("powerups"):
		if not (pu is Node2D) or not is_instance_valid(pu):
			continue
		var p := pu as Node2D
		if _player.global_position.distance_to(p.global_position) > radius:
			continue
		p.global_position = p.global_position.lerp(_player.global_position, 0.55)
		pulled += 1
	for lt in get_tree().get_nodes_in_group("loot"):
		if lt is Node2D and is_instance_valid(lt) and _player.global_position.distance_to((lt as Node2D).global_position) <= radius:
			lt.call("magnetize")
			pulled += 1
	_drop_gift()
	if pulled > 0:
		Juice.burst(_player.global_position, Color(0.6, 1.0, 0.7), 10, 120.0, 0.4)

## Bentley's "important" find at your feet: junk, a scrap pile, or something great.
func _drop_gift() -> void:
	var roll := randf()
	var great := float(_def.get("gift_great", 0.04))
	var good := float(_def.get("gift_good", 0.2))
	var feet := _player.global_position + Vector2(randf_range(-18, 18), 14)
	var parent := get_parent()
	if roll < great:
		var pick := randi() % 3
		if pick == 0:
			LootDrop.spawn_burst(parent, feet, "tonic", 1, 18.0)
			Juice.float_text(feet + Vector2(0, -40), "Bentley found a tonic!", Color(0.6, 1.0, 0.6), 15)
		elif pick == 1:
			RunFx.spawn_ammo_pickup(parent, feet)
			Juice.float_text(feet + Vector2(0, -40), "Bentley found ammo!", Color(1.0, 0.85, 0.4), 15)
		else:
			var r: Vector2i = _def.get("gift_great_scrap", Vector2i(18, 30))
			var big := GameState.add_scrap(randi_range(r.x, r.y))
			Juice.float_text(feet + Vector2(0, -40), "Jackpot! +%d scrap" % big, UiTheme.AMBER, 16)
		return
	var rng: Vector2i = _def.get("gift_good_scrap" if roll < great + good else "gift_junk_scrap", Vector2i(1, 3))
	var scrap := GameState.add_scrap(randi_range(rng.x, rng.y))
	Juice.float_text(feet + Vector2(0, -40), ("+%d scrap" if roll < great + good else "junk… +%d scrap") % scrap, UiTheme.AMBER, 14)


func _try_start_ram() -> void:
	if _ram_cd > 0.0:
		return
	var max_r := float(_def.get("ram_range", 280.0))
	var foe := _nearest_enemy(max_r)
	if foe == null:
		return
	_target = foe
	_ram_dir = (foe.global_position - global_position).normalized()
	## Long enough to close on a moving target when we home each frame.
	_ram_left = float(_def.get("ram_duration", 0.85))
	_ram_wake_hit.clear()
	_ram_cd = float(_def.get("ram_cooldown", 6.5))
	_apply_look()
	Juice.sfx_at("lillie_charge", global_position)
	_anim.set_facing(_ram_dir.x < 0.0)
	_anim.play("charge" if _anim.has_state("charge") else "windup")
	var lil := _ability_id() == "ram_headbutt"
	Juice.float_text(global_position + Vector2(0, -28), "LILLIE RAM!" if lil else "POUNCE!", Color(1.0, 0.55, 0.3) if lil else Color(0.5, 0.9, 1.0), 16)
	Juice.dust_puff(global_position + Vector2(0, 12), 8)

func _tick_ram(delta: float) -> void:
	_ram_left -= delta
	## Home on the live target so knockback / strafe can't make us hit empty air.
	if _target != null and is_instance_valid(_target):
		var to_tgt := (_target as Node2D).global_position - global_position
		if to_tgt.length() > 4.0:
			_ram_dir = _ram_dir.lerp(to_tgt.normalized(), clampf(delta * 10.0, 0.0, 1.0)).normalized()
	var spd := float(_def.get("ram_speed", 520.0))
	velocity = _ram_dir * spd
	move_and_slide()
	_anim.set_facing(_ram_dir.x < 0.0)
	## Wake (kennel rank 2): enemies we pass (not the primary — they get the impact hit).
	if int(_def.get("ram_trail", 0)) <= 0:
		_ram_contact_check()
		return
	if randf() < 0.5:
		Juice.dust_puff(global_position + Vector2(0, 10), 3)
	var wake_r := float(_def.get("ram_wake_radius", 42.0))
	var wake_dmg := float(_def.get("ram_wake_damage", 14.0)) * GameState.pet_power_mult() * GameState.aoe_damage_mult()
	var primary_id := _target.get_instance_id() if _target != null and is_instance_valid(_target) else -1
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		var id := e.get_instance_id()
		if id == primary_id or _ram_wake_hit.has(id):
			continue
		if global_position.distance_to(e.global_position) > wake_r:
			continue
		_ram_wake_hit[id] = true
		if e.has_method("take_damage"):
			## No knock on wake — normalized dirs would still full-yeet the pack.
			e.call("take_damage", wake_dmg, Vector2.ZERO)
		Juice.burst(e.global_position, Color(1.0, 0.7, 0.4), 6, 80.0, 0.2)
	_ram_contact_check()


func _ram_contact_check() -> void:
	## Real contact only — timer expire without contact = miss, no phantom AOE.
	var contact_r := float(_def.get("ram_contact_radius", 48.0))
	if _target != null and is_instance_valid(_target):
		if global_position.distance_to((_target as Node2D).global_position) <= contact_r:
			_ram_impact(true)
			return
	if _ram_left <= 0.0:
		_ram_impact(false)

func _ram_impact(connected: bool) -> void:
	_ram_left = 0.0
	if not connected:
		Juice.dust_puff(global_position + Vector2(0, 10), 6)
		Juice.float_text(global_position + Vector2(0, -24), "MISS", Color(0.75, 0.7, 0.6), 14)
		_target = null
		_anim.set_locomotion("idle")
		_anim.play("idle")
		_apply_look()
		return
	var radius := float(_def.get("ram_impact_radius", 95.0))
	var dmg := float(_def.get("ram_impact_damage", 42.0)) * GameState.pet_power_mult() * GameState.aoe_damage_mult()
	## Snap onto the target so the boom reads on their body, not empty dust.
	if _target != null and is_instance_valid(_target):
		global_position = global_position.lerp((_target as Node2D).global_position, 0.55)
	Juice.sfx_at("lillie_hit", global_position)
	_anim.play("impact" if _anim.has_state("impact") else "attack")
	if int(_def.get("shock_chain", 0)) > 0 and _target != null and is_instance_valid(_target):
		_shock_chain(_target)
	var stun := float(_def.get("ram_stun", 0.7))
	var knock := float(_def.get("ram_knock", 420.0))
	## Base headbutt: the target only — stun + knockback.
	if int(_def.get("ram_blast", 0)) <= 0:
		if _target != null and is_instance_valid(_target):
			var t := _target as Node2D
			if t.has_method("take_damage"):
				t.call("take_damage", dmg, (t.global_position - global_position).normalized(), knock)
			if t.has_method("apply_status") and is_instance_valid(t):
				t.call("apply_status", "stun", stun)
		Juice.burst(global_position, Color(1.0, 0.6, 0.3), 12, 140.0, 0.35)
		Juice.shake(0.12)
		Juice.float_text(global_position + Vector2(0, -30), "BONK!", Color(1.0, 0.6, 0.3), 16)
		_target = null
		_apply_look()
		return
	## Kennel rank 3: fierce AoE blast on contact.
	Juice.burst(global_position, Color(1.0, 0.5, 0.25), 22, radius * 1.5, 0.5)
	Juice.shake(0.22)
	Juice.float_text(global_position + Vector2(0, -30), "BOOM!", Color(1.0, 0.6, 0.3), 18)
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var e := n as Node2D
		if global_position.distance_to(e.global_position) > radius:
			continue
		if e.has_method("take_damage"):
			e.call("take_damage", dmg, (e.global_position - global_position).normalized(), knock)
		if is_instance_valid(e) and e.has_method("apply_status"):
			e.call("apply_status", "stun", stun)
	_target = null
	_apply_look()

func _bite(enemy: Node2D) -> void:
	_bite_cd = float(_def.get("bite_cooldown", 0.6))
	var dmg := float(_def.get("bite_damage", 8.0)) * GameState.pet_power_mult()
	_anim.set_facing(enemy.global_position.x < global_position.x)
	if not _anim.is_busy():
		_anim.play("attack")
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", dmg, (enemy.global_position - global_position).normalized(), float(_def.get("bite_knock", 30.0)))
	Juice.sfx_at("hit_flesh", enemy.global_position, -4.0)

func _nearest_enemy(max_d: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_d
	for n in get_tree().get_nodes_in_group("enemies"):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		var d := global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n as Node2D
	return best

func _update_visuals(delta: float) -> void:
	if body == null:
		return
	_anim.set_motion(velocity, float(_def.get("follow_speed", 260.0)))
	_anim.tick(delta)
	var v := velocity.length()
	if _ram_left > 0.0:
		## Lillie's charge loop runs for the whole ram.
		if _anim.has_state("charge") and not _anim.is_playing("charge"):
			_anim.play("charge")
	elif v > 24.0:
		_still_t = 0.0
		var mult := clampf(v / float(_def.get("follow_speed", 260.0)), 0.6, 1.6)
		_anim.set_locomotion("rampage" if _rampaging and _anim.has_state("rampage") else "walk", mult)
	else:
		_still_t += delta
		if _rampaging and _anim.has_state("rampage"):
			_anim.set_locomotion("rampage")
		else:
			_anim.set_locomotion("idle")
			if _still_t > SIT_AFTER and _anim.state == "idle" and _anim.has_state("sit"):
				_anim.play("sit")
	if _ram_left > 0.0:
		body.modulate = Color(1.4, 0.9, 0.7)
	elif _rampaging:
		_bob_t += delta * 18.0
		body.modulate = Color(1.35, 0.75, 0.65) if int(_bob_t * 8.0) % 2 == 0 else Color(1.15, 0.85, 0.8)
	elif _flash_left > 0.0 or _accent_left > 0.0:
		body.modulate = Color(1.35, 1.2, 0.95)
	else:
		body.modulate = Color.WHITE

func is_rampaging() -> bool:
	return _rampaging

func get_pet_name() -> String:
	return str(_def.get("name", "Pet"))


## --- Depth E6 mech tricks ------------------------------------------------------

## Mech Hound: the pounce's impact arcs to the nearest few enemies (machines take more).
func _shock_chain(from: Node2D) -> int:
	var n := int(_def.get("shock_chain", 0))
	var rng := float(_def.get("shock_range", 150.0))
	var dmg := float(_def.get("shock_damage", 16.0)) * GameState.pet_power_mult()
	var hit: Array = [from]
	var cur := from
	var count := 0
	for i in range(n):
		var nxt := RunFx.nearest_enemy(get_tree(), cur.global_position, rng, hit)
		if nxt == null:
			break
		RunFx.zap(get_parent(), cur.global_position + Vector2(0, -10), nxt.global_position + Vector2(0, -10), Color(0.5, 0.9, 1.0))
		var fac: Variant = nxt.get("faction")
		var mult := FactionDefs.weakness(str(fac), "shock") if fac != null else 1.0
		if nxt.has_method("take_damage"):
			nxt.call("take_damage", dmg * mult, (nxt.global_position - cur.global_position).normalized(), 60.0)
		if is_instance_valid(nxt) and nxt.has_method("apply_status"):
			nxt.call("apply_status", "stun", 0.25)
		hit.append(nxt)
		cur = nxt
		count += 1
	return count


## Drone Bat: a strafing burst at the nearest enemies, marking them.
func _do_strafe() -> int:
	var rng := float(_def.get("strafe_range", 320.0))
	var foes := RunFx.enemies_in(get_tree(), global_position, rng)
	if foes.is_empty():
		_strafe_cd = 0.6
		return 0
	_strafe_cd = float(_def.get("strafe_cooldown", 4.5))
	var me := global_position
	foes.sort_custom(func(a: Node, b: Node) -> bool:
		return me.distance_squared_to((a as Node2D).global_position) < me.distance_squared_to((b as Node2D).global_position))
	var shots := int(_def.get("strafe_shots", 4))
	var dmg := float(_def.get("strafe_damage", 7.0)) * GameState.pet_power_mult()
	_anim.play("attack")
	_accent_left = 0.4
	Juice.sfx_at("mech_servo", global_position)
	Juice.sfx_at("drone_fire", global_position, -2.0)
	var n := 0
	for i in range(shots):
		var e: Variant = foes[i % foes.size()]
		if not is_instance_valid(e):
			continue
		var en := e as Node2D
		RunFx.zap(get_parent(), global_position + Vector2(0, -24), en.global_position + Vector2(randf_range(-6, 6), -8), Color(1.0, 0.85, 0.45), 0.14, 2.0)
		if en.has_method("take_damage"):
			en.call("take_damage", dmg, (en.global_position - global_position).normalized(), 20.0)
		if is_instance_valid(en) and en.has_method("apply_status"):
			en.call("apply_status", "mark", float(_def.get("strafe_mark_time", 3.0)), float(_def.get("strafe_mark_mult", 1.15)))
		n += 1
	return n


## Rust Mule: lob a shell at the thickest crowd in range (telegraphed, then a blast).
func _do_mortar() -> Vector2:
	var rng := float(_def.get("mortar_range", 380.0))
	var radius := float(_def.get("mortar_radius", 90.0))
	var foes := RunFx.enemies_in(get_tree(), global_position, rng)
	if foes.is_empty():
		_mortar_cd = 0.8
		return Vector2.INF
	_mortar_cd = float(_def.get("mortar_cooldown", 7.0))
	var best: Node2D = foes[0]
	var best_n := -1
	for a in foes:
		var c := 0
		for b in foes:
			if (a as Node2D).global_position.distance_to((b as Node2D).global_position) <= radius:
				c += 1
		if c > best_n:
			best_n = c
			best = a
	var at := best.global_position
	_anim.set_facing(at.x < global_position.x)
	_anim.play("attack")
	Juice.sfx_at("mech_servo", global_position, 2.0)
	Juice.burst(global_position + Vector2(0, -30), Color(0.6, 0.9, 1.0), 8, 90.0, 0.3)
	RunFx.ring(get_parent(), at, radius, Color(1.0, 0.6, 0.3, 0.8), float(_def.get("mortar_delay", 0.7)), 3.0)
	var dmg := float(_def.get("mortar_damage", 34.0)) * GameState.pet_power_mult() * GameState.aoe_damage_mult()
	## Weak ref: the match may end (and free the hero) while the shell is in the air.
	var plref: WeakRef = weakref(_player)
	get_tree().create_timer(float(_def.get("mortar_delay", 0.7)), false).timeout.connect(func() -> void:
		var pl: Variant = plref.get_ref()
		if pl != null and is_instance_valid(pl):
			RunFx.explosion(pl as Node2D, at, radius, dmg, Color(1.0, 0.65, 0.3), "pet", 240.0)
			Juice.shake(0.12))
	return at
