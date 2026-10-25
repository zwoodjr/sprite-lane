extends RefCounted

## Settings > Colour-blind loot: a shape per rarity alongside its colour
## (circle common, triangle rare, diamond epic, star legendary / evolution).
## glyph() for text (the bundled symbol font has these), points() for world
## badges drawn as polygons.

const GLYPH := {"common": "●", "rare": "▲", "epic": "◆", "legendary": "★", "evolution": "★"}


static func on() -> bool:
	return SettingsDefs.cb_loot()


static func glyph(rarity: String) -> String:
	return str(GLYPH.get(rarity, GLYPH["common"]))


## Text with the rarity shape in front when the setting is on.
static func tag(text: String, rarity: String) -> String:
	return (glyph(rarity) + " " + text) if on() else text


## Outline polygon of the shape, radius r around the origin.
static func points(rarity: String, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match rarity:
		"rare":
			for i in range(3):
				var a := -PI * 0.5 + TAU * float(i) / 3.0
				pts.append(Vector2(cos(a), sin(a)) * r * 1.15)
		"epic":
			pts = PackedVector2Array([Vector2(0, -r * 1.15), Vector2(r * 0.9, 0), Vector2(0, r * 1.15), Vector2(-r * 0.9, 0)])
		"legendary", "evolution":
			for i in range(10):
				var a := -PI * 0.5 + TAU * float(i) / 10.0
				var rr := r * 1.2 if i % 2 == 0 else r * 0.5
				pts.append(Vector2(cos(a), sin(a)) * rr)
		_:
			for i in range(8):
				var a := TAU * float(i) / 8.0
				pts.append(Vector2(cos(a), sin(a)) * r * 0.8)
	return pts


## World badge: INK-backed shape in the rarity colour (a Node2D to add).
static func badge(rarity: String, col: Color, r: float = 6.0) -> Node2D:
	var n := Node2D.new()
	n.name = "RarityMark"
	var back := Polygon2D.new()
	var outline := PackedVector2Array()
	for p in points(rarity, r):
		outline.append(p * ((r + 2.0) / r))
	back.polygon = outline
	back.color = Color("140c0e")
	n.add_child(back)
	var fg := Polygon2D.new()
	fg.polygon = points(rarity, r)
	fg.color = Color(col, 1.0)
	n.add_child(fg)
	return n
