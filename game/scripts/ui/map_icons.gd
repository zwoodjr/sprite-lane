class_name MapIcons
extends RefCounted

## Tiny pixel glyphs shared by the minimap, its rim markers, its legend and the
## on-screen edge arrows, so every "where is it" cue speaks one icon language.
## Glyphs are baked once into white textures with a 1 px dark outline; draw
## them tinted (the outline and dark holes stay dark). Draw on a CanvasItem with
## TEXTURE_FILTER_NEAREST to keep them crisp.

enum { SKULL, SKULL_BIG, GEM, CROSS, AMMO, PAGE, PAD, BANG, TENT, BUNKER, VAULT, MARKET, TOWER, PLANE, CRATE, TARGET, KEY, GARAGE, WRECK, COUNT }

## '#' = tinted fill, 'o' = dark hole, '.' = empty (outlined where it touches fill).
const GLYPHS := {
	SKULL: [".###.", "#o#o#", "#####", ".###.", ".#.#."],
	SKULL_BIG: [".#####.", "#######", "#oo#oo#", "#oo#oo#", "#######", ".##o##.", ".#.#.#."],
	GEM: ["..#..", ".###.", "#####", ".###.", "..#.."],
	CROSS: ["..##..", "..##..", "######", "######", "..##..", "..##.."],
	AMMO: [".#.", "###", "###", "###", "###"],
	PAGE: ["###..", "#o##.", "#####", "#ooo#", "#####", "#oo##", "#####"],
	PAD: ["..###..", ".#ooo#.", "#oo#oo#", "#o###o#", "#oo#oo#", ".#ooo#.", "..###.."],
	BANG: [".#####.", "###o###", "###o###", "###o###", "#######", "###o###", ".#####."],
	TENT: ["...#...", "..###..", ".##o##.", ".#ooo#.", "##ooo##", "#######"],
	BUNKER: ["..###..", ".#####.", "#######", "##ooo##", "##ooo##"],
	VAULT: ["#######", "#ooooo#", "#o###o#", "#o#o#o#", "#o###o#", "#ooooo#", "#######"],
	MARKET: ["#######", "#o#o#o#", ".#...#.", ".#...#.", ".#####."],
	TOWER: ["..#..", ".#.#.", ".###.", ".#.#.", "#.#.#", "#...#", "#...#"],
	PLANE: ["...#...", "..###..", "#######", "...#...", "..###.."],
	CRATE: ["######", "#o##o#", "##oo##", "##oo##", "#o##o#", "######"],
	TARGET: ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
	KEY: [".###.", "#####", "#####", "#####", ".###."],
	GARAGE: ["...#...", "..###..", ".#####.", "#######", ".#ooo#.", ".#ooo#."],
	WRECK: ["..##...", ".####..", "#######", "#######", ".#...#."],
}

const DARK := Color(0.05, 0.035, 0.025, 0.92)

## Icon language (also the legend).
const C_MOB := Color(1.0, 0.92, 0.3)
const C_ELITE := Color(0.95, 0.6, 0.12)
const C_BOSS := Color(1.0, 0.25, 0.22)
const C_PAD_OPEN := Color(0.4, 1.0, 0.45)
const C_PAD_SEALED := Color(0.6, 0.55, 0.45)
const C_PAD_LAST := Color(1.0, 0.3, 0.26)
const C_EVENT := Color(0.4, 0.9, 1.0)
const C_JOB := Color(0.55, 1.0, 0.6) ## RadioDefs.MAP_COLOR
const C_HUNT := Color(1.0, 0.42, 0.25)
const C_MED := Color(1.0, 0.42, 0.4)
const C_PAGE := Color(0.95, 0.88, 0.65)
const C_POI := Color(0.85, 0.55, 0.36)
const C_BUNKER := Color(1.0, 0.85, 0.45)
const C_CRATE := Color(1.0, 0.7, 0.3)
const C_PLAYER := Color(0.35, 0.95, 0.85)
const RARITY := {
	"common": Color(0.95, 0.95, 0.92), "uncommon": Color(0.4, 0.9, 0.45), "rare": Color(0.35, 0.65, 1.0),
	"epic": Color(0.75, 0.4, 1.0), "legendary": Color(1.0, 0.58, 0.15),
}

static var _tex: Array = []


static func tex(id: int) -> Texture2D:
	if _tex.is_empty():
		_bake()
	return _tex[id] if id >= 0 and id < _tex.size() else null


static func rarity_color(r: String) -> Color:
	return RARITY.get(r, RARITY["common"])


static func _bake() -> void:
	_tex.resize(COUNT)
	for id in GLYPHS.keys():
		var rows: Array = GLYPHS[id]
		var gw := str(rows[0]).length()
		var gh := rows.size()
		var img := Image.create(gw + 2, gh + 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for y in range(gh):
			var row := str(rows[y])
			for x in range(gw):
				var ch := row[x]
				if ch == "#":
					img.set_pixel(x + 1, y + 1, Color.WHITE)
				elif ch == "o":
					img.set_pixel(x + 1, y + 1, DARK)
		## 1 px outline (8-neighbour) around the fill.
		for y in range(gh + 2):
			for x in range(gw + 2):
				if img.get_pixel(x, y).a > 0.0:
					continue
				var near := false
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						var nx := x + ox
						var ny := y + oy
						if nx >= 0 and ny >= 0 and nx < gw + 2 and ny < gh + 2 and img.get_pixel(nx, ny) == Color.WHITE:
							near = true
				if near:
					img.set_pixel(x, y, DARK)
		_tex[id] = ImageTexture.create_from_image(img)


## Draws glyph `id` centred on `pos` at an integer-ish pixel scale.
static func draw(ci: CanvasItem, id: int, pos: Vector2, col: Color, k: float = 1.0) -> void:
	var t := tex(id)
	if t == null:
		return
	var sz := t.get_size() * k
	ci.draw_texture_rect(t, Rect2((pos - sz * 0.5).round(), sz), false, col)


## Chevron pointing along `dir` (unit), tip at `tip`.
static func draw_chevron(ci: CanvasItem, tip: Vector2, dir: Vector2, col: Color, length: float = 9.0, half_w: float = 6.0) -> void:
	var base := tip - dir * length
	var o := dir.orthogonal() * half_w
	var pts := PackedVector2Array([tip, base + o, base - o])
	var grow := PackedVector2Array([tip + dir * 1.6, base + o * 1.3 - dir * 1.0, base - o * 1.3 - dir * 1.0])
	ci.draw_colored_polygon(grow, DARK)
	ci.draw_colored_polygon(pts, col)
