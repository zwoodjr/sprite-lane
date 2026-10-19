extends StaticBody2D

## Destructible scrap / apothecary prop. Player shots and swings break it.

signal broken(global_pos: Vector2)

const PickupScene := preload("res://scenes/entities/powerup_pickup.tscn")

@export var max_hp: float = 24.0
## Power-up rate target ~2/10 crates. Rest: empty or scrap-only.
@export var powerup_chance: float = 0.20
@export var scrap_only_chance: float = 0.40 ## of the non-powerup rolls → lean scrap; else empty

var hp: float = 24.0
var kind: String = "crate"

@onready var sprite: Sprite2D = $Sprite


func setup(kind_id: String, tex: Texture2D, p_hp: float = 24.0) -> void:
	kind = kind_id
	max_hp = p_hp
	hp = p_hp
	if sprite == null:
		sprite = $Sprite
	sprite.texture = tex
	sprite.centered = true
	## Painted 2x prop art draws at half size (same world footprint).
	if tex and tex.resource_path.contains("/props_hd/"):
		sprite.scale = Vector2(0.5, 0.5)


func _ready() -> void:
	add_to_group("breakables")
	collision_layer = 1
	collision_mask = 0
	hp = max_hp
	set_process(false)


var _broken: bool = false
var _ping_left: float = 0.0


func ping() -> void:
	## Highlight from abilities (e.g. Rattle Rush) — glows for a few seconds.
	_ping_left = 6.0
	set_process(true)


func _process(delta: float) -> void:
	if _ping_left <= 0.0:
		set_process(false)
		if sprite:
			sprite.self_modulate = Color.WHITE
		return
	_ping_left -= delta
	var k := 0.5 + 0.5 * sin(_ping_left * 8.0)
	if sprite:
		sprite.self_modulate = Color(1.0 + k, 1.0 + k * 0.7, 0.6 + k * 0.2)


func take_damage(amount: float) -> void:
	if _broken:
		return
	hp -= amount
	Juice.flash(sprite, Color(2.2, 1.8, 1.4), 0.08)
	if sprite:
		sprite.position = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		var tw := sprite.create_tween()
		tw.tween_property(sprite, "position", Vector2.ZERO, 0.08)
	if hp <= 0.0:
		_break_open()


static func _spawn_pickup(parent: Node, pos: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var pickup: Area2D = PickupScene.instantiate()
	parent.add_child(pickup)
	pickup.global_position = pos
	## Some crate buffs are special-ammo cans instead (Phase 4).
	var aid := RunFx.random_bench_ammo_id()
	if aid != "" and randf() < UpgradeDefs.AMMO_CRATE_SHARE * GameState.ammo_odds_mult():
		pickup.call("setup", RunFx.ammo_def(aid))
	else:
		pickup.call("setup", PowerupDefs.random_powerup())


func _break_open() -> void:
	_broken = true
	var pos := global_position
	Juice.sfx("break")
	Juice.shake(0.1)
	Juice.burst(pos, Color(0.7, 0.5, 0.3), 16, 200.0, 0.5, 1.2)
	broken.emit(pos)
	## Outcomes: power-up (~20% + Hangar loot quality) · scrap-only · empty.
	## Soft-cap so empty crates stay common (player preference).
	var buff_chance := clampf(powerup_chance + GameState.loot_quality_bonus(), 0.05, 0.35)
	var roll := randf()
	if roll <= buff_chance:
		## Deferred: we're usually inside a physics callback (bullet hit).
		_spawn_pickup.call_deferred(get_tree().current_scene, pos)
		## Tiny scrap with buffs so opens aren't always dry.
		if randf() < 0.35:
			var scrap := GameState.add_scrap(1)
			Juice.float_text(pos + Vector2(0, -20), "+%d scrap" % scrap, UiTheme.AMBER, 14)
	elif roll <= buff_chance + (1.0 - buff_chance) * scrap_only_chance:
		var scrap2 := GameState.add_scrap(randi_range(1, 2))
		Juice.float_text(pos + Vector2(0, -20), "+%d scrap" % scrap2, UiTheme.AMBER, 15)
	else:
		Juice.float_text(pos + Vector2(0, -18), "empty", Color(0.7, 0.65, 0.55), 13)
	GearPickup.maybe_drop(get_tree().current_scene, pos, GearDefs.CRATE_DROP_CHANCE)
	queue_free()
