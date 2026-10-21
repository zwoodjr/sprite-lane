"""Wanderer master palette (48 colours) + zone sub-palettes. Single source of truth
for style_sheet.png and STYLE_BIBLE.md. Every ramp is dark -> light; tone 0 is the
outline/AO tone for that material (L* <= 20)."""

def h(x):
    x = x.lstrip('#')
    return (int(x[0:2], 16), int(x[2:4], 16), int(x[4:6], 16))

RAMPS = {
    # name: (list of hex, usage)
    "ink":    (["#140c0e"], "universal outline / deepest AO; never #000"),
    "ash":    (["#1f1a1d", "#3a3436", "#5d5654", "#8f877e", "#e9dfc9"], "neutral warm grey: concrete, asphalt, smoke, grey fur; top = BONE (text, VFX core, hit flash)"),
    "earth":  (["#3a2d27", "#5a4636", "#7c6550", "#a08669", "#c8b08a"], "dirt, sand, wood, leather"),
    "rust":   (["#3e1a12", "#763420", "#ad5a2a", "#d98a45"], "rusted metal, raider gear, old paint"),
    "brass":  (["#3e2a10", "#7a5520", "#b88a33", "#e8c972"], "brass fittings, scrap, hazard paint, gauges"),
    "steel":  (["#1b222c", "#36424f", "#5e6d7a", "#9aa8ad"], "machines, weapons, tanks, UI plates"),
    "cloth":  (["#2a2a1c", "#59563a", "#8f8a5e"], "canvas, fatigues, tents, sandbags"),
    "skin":   (["#4a2420", "#8e4c3b", "#c98060", "#eeb48c"], "raiders / humans (heroes keep their own painted skin)"),
    "plague": (["#142a18", "#2b5a2c", "#57932f", "#9ccf3e", "#dcf58a"], "plague growth, toxic liquid, poison; tones 3-4 are EMISSIVE"),
    "flesh":  (["#2e1830", "#5a3254", "#8a5474", "#c08aa0"], "plague flesh, chitin, tumours, Epic rarity"),
    "dust":   (["#5e260c", "#a8520f", "#e88a1c", "#ffc040", "#fff2c0"], "Dust amber: loot, XP, fire, muzzle, hero UI; tones 2-4 EMISSIVE"),
    "blood":  (["#9a1e26"], "blood, wounds, medic cross (shadow = rust 0)"),
    "teal":   (["#1f5a58", "#5cd2c0"], "friendly / extract / shield / shock"),
    "signal": (["#ff4836"], "ENEMY telegraphs, damage, danger only"),
}
ORDER = ["ink", "ash", "earth", "rust", "brass", "steel", "cloth", "skin", "plague", "flesh", "dust", "blood", "teal", "signal"]

def R(name):
    return [h(c) for c in RAMPS[name][0]]

INK = h("#140c0e")
BONE = h("#e9dfc9")
ALL = [h(c) for n in ORDER for c in RAMPS[n][0]]
assert len(ALL) == 48, len(ALL)

# Zone sub-palettes: ground ramp (crack, base, mid, speck), light-pool colour, accent ramp, prop key
ZONES = [
    ("T1 HAZE", "The Haze", ["#433428", "#5b4a3b", "#685645", "#7e6953"], "#ffc040", "dust", "wreck cars, sandbags, poles"),
    ("T2 DRIFT", "The Drift", ["#433424", "#5d4a36", "#6a5640", "#7e6a50"], "#ffc040", "dust", "dunes, bones, half-buried scrap"),
    ("T3 SMOG", "Old Refinery", ["#3a3633", "#524d46", "#5f5951", "#746c60"], "#e88a1c", "steel", "oil tanks, pipe racks, oil slicks"),
    ("T4 PALL", "Dead City", ["#34363f", "#494e5a", "#54596a", "#676d7b"], "#ffc040", "brass", "street lamps, shop ruins, cars"),
    ("T5 BLIGHT", "Quarantine Zone", ["#36382f", "#4d4f43", "#585b4d", "#6b6f5f"], "#9ccf3e", "plague", "quarantine tents, hazard barriers"),
    ("T6 SHROUD", "Raider Territory", ["#4a3028", "#67453a", "#755244", "#896555"], "#d98a45", "rust", "spike barricades, totems, red rags"),
    ("T7 CHOKE", "Chemical Plant", ["#37372d", "#4e4e3c", "#5a5a46", "#6d6e56"], "#9ccf3e", "plague", "chem vats, pipe racks, drums"),
    ("T8 BLACKOUT", "Military Base", ["#323834", "#474f4b", "#535b56", "#676f69"], "#ff4836", "steel", "tank wrecks, guard posts, wire"),
    ("T9 DEADFALL", "Crater City", ["#3a3634", "#534c49", "#5f5854", "#726c67"], "#ffc040", "ash", "slab ruins, sinkholes, rebar"),
    ("T10 DUSTFALL", "Where the Dust Began", ["#502f1b", "#6b452e", "#775038", "#8a6549"], "#fff2c0", "dust", "dust spires, everything, amber haze"),
]

def lab_L(rgb):
    def f(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (f(x) for x in rgb)
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116 * (y ** (1 / 3)) - 16 if y > 0.008856 else 903.3 * y

TONE0 = {}
for n in ORDER:
    rr = R(n)
    for c in rr:
        TONE0[c] = rr[0] if lab_L(rr[0]) <= 22 else INK

def nearest(rgb, pool=None):
    pool = pool or ALL
    return min(pool, key=lambda c: (c[0]-rgb[0])**2*0.3 + (c[1]-rgb[1])**2*0.59 + (c[2]-rgb[2])**2*0.11)

if __name__ == "__main__":
    for n in ORDER:
        print(n, [(c, round(lab_L(h(c)))) for c in RAMPS[n][0]])
    for z in ZONES:
        print(z[0], [round(lab_L(h(c))) for c in z[2]])
