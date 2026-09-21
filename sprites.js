(() => {
  "use strict";

  // Hand-tuned multi-frame pixel sprites for Spirit Lane.
  // Original designs — anime TROPE inspired, not character copies.

  const PAL = {
    0: null,
    1: "#1a120e",
    2: "#2a1c14",
    3: "#4a3424",
    4: "#e8c56a",
    5: "#e85d3c",
    6: "#3db8a0",
    7: "#e6dcc8",
    8: "#d64545",
    9: "#5a8fd4",
    a: "#7a5a3a",
    b: "#2a4a3a",
    c: "#c0c8d0",
    d: "#8b5a2b",
    e: "#ff8a60",
    f: "#1e2a38",
    // Gate Shade / cave extensions
    g: "#7ec8d8", // steel cyan
    h: "#0c1014", // void ash
    i: "#3a4850", // mid ash
    j: "#6a7880", // light ash
    k: "#ffb040", // knuckle glow
    l: "#243038", // charcoal
    m: "#2a3850", // navy jacket
    n: "#8a9098", // rock highlight
    o: "#5a6068", // rock mid
    p: "#142428", // dark teal (hexwisp)
    q: "#8a2030", // deep crimson
    r: "#c8e8f0", // bright cyan tip
    s: "#4a3020", // leather strap
    // My Hero pass
    t: "#1a5030", // dark green cowl
    u: "#3db868", // hero green
    v: "#f0b0c8", // gravity pink
    w: "#ffe08a", // blast yellow
    x: "#90c8e8", // ice blue
    y: "#ff6038", // fire orange
    z: "#3a2018", // boot brown
  };

  function bake(rows) {
    const h = rows.length;
    const w = rows[0].length;
    const cnv = document.createElement("canvas");
    cnv.width = w;
    cnv.height = h;
    const c = cnv.getContext("2d");
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const col = PAL[rows[y][x]];
        if (!col) continue;
        c.fillStyle = col;
        c.fillRect(x, y, 1, 1);
      }
    }
    return cnv;
  }

  function tintCanvas(src, tintHex, strength = 0.35) {
    const cnv = document.createElement("canvas");
    cnv.width = src.width;
    cnv.height = src.height;
    const c = cnv.getContext("2d");
    c.drawImage(src, 0, 0);
    c.globalCompositeOperation = "source-atop";
    c.globalAlpha = strength;
    c.fillStyle = tintHex;
    c.fillRect(0, 0, cnv.width, cnv.height);
    c.globalAlpha = 1;
    c.globalCompositeOperation = "source-over";
    return cnv;
  }

  function tintPack(pack, idleTint, atkTint, idleStr = 0.28, atkStr = 0.32) {
    return {
      idle: [
        tintCanvas(pack.idle[0], idleTint, idleStr),
        tintCanvas(pack.idle[1], idleTint, idleStr),
      ],
      attack: [
        tintCanvas(pack.attack[0], atkTint || idleTint, atkStr),
        tintCanvas(pack.attack[1], atkTint || idleTint, atkStr * 0.85),
      ],
    };
  }

  // --- Sparkfist / Dark Deku — green freckled smash hero ---
  const sparkIdle0 = bake([
    "000000tttt000000",
    "00000tuuut000000",
    "0000tu777ut00000",
    "0000t77777t00000",
    "0000zzzzzz000000",
    "000zzuuuuzz00000",
    "00zu7uuuu7uz0000",
    "0k0zuuuuuuz0k000",
    "0kk0zzzzzz0kk000",
    "0000333333000000",
    "00003zzzz3000000",
    "00003z00z3000000",
    "00003z00z3000000",
    "0000u0000u000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const sparkIdle1 = bake([
    "000000tttt000000",
    "00000tuuut000000",
    "0000tu777ut00000",
    "0000t77777t00000",
    "0000zzzzzz000000",
    "000zzuuuuzz00000",
    "00zu7uuuu7uz0000",
    "00kzuuuuuuzk0000",
    "0k00zzzzzz00k000",
    "0000333333000000",
    "00003zzzz3000000",
    "00003zzzz3000000",
    "000003zz30000000",
    "00000u00u0000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const sparkAtk0 = bake([
    "000000tttt000000",
    "0u000tuuut00u000",
    "0wu0tu777utuw000",
    "wu0t77777t0uw000",
    "u00zzzzzz00u0000",
    "00zzuuuuzz000000",
    "000zuuuuuz000000",
    "0000zzzzzz000000",
    "0000333333000000",
    "0003zzzzzz300000",
    "0003z0000z300000",
    "0003z0000z300000",
    "000u000000u00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const sparkAtk1 = bake([
    "u0w000tttt00w0u0",
    "uwu0tuuut0uwu000",
    "5wu0t7777t0uw500",
    "wu5zzzzzz5uw0000",
    "u5kuuuuuuk5u0000",
    "05kuuuuuuuk50000",
    "000kuuuuuk000000",
    "0000zzzzzz000000",
    "0000333333000000",
    "0003zzzzzz300000",
    "003z000000z30000",
    "003z000000z30000",
    "00u00000000u0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Blastcrown / Full Cowl — wider green detonation ---
  const blastIdle0 = bake([
    "00000uuuuu000000",
    "0000uwwwwu000000",
    "000uw7777wu00000",
    "000u777777u00000",
    "0000tttttt000000",
    "000ttuuuutt00000",
    "00tu7uuuu7ut0000",
    "0wu0tuuuut0uw000",
    "0ww0tttttt0ww000",
    "0000333333000000",
    "00003tttt3000000",
    "00003t00t3000000",
    "00003t00t3000000",
    "0000w0000w000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const blastIdle1 = bake([
    "00000uuuuu000000",
    "0000uwwwwu000000",
    "000uw7777wu00000",
    "000u777777u00000",
    "0000tttttt000000",
    "000ttuuuutt00000",
    "00tu7uuuu7ut0000",
    "00wutuuuutuw0000",
    "0w00tttttt00w000",
    "0000333333000000",
    "00003tttt3000000",
    "00003tttt3000000",
    "000003tt30000000",
    "00000w00w0000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const blastAtk0 = bake([
    "0w000uuuuu00w000",
    "0wu0uwwwwu0uw000",
    "wu5uw7777wu5uw00",
    "u50u777777u05u00",
    "50wttttttw05u000",
    "0wttuwwwwuttw000",
    "00tuwwwwwwut0000",
    "000tttttttt00000",
    "0000333333000000",
    "0003tttttt300000",
    "0003t0000t300000",
    "0003t0000t300000",
    "000w000000w00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const blastAtk1 = bake([
    "w5u00uuuuu00u5w0",
    "5wu5uwwwwu5uw5u0",
    "uw5uw7777wu5wu00",
    "w55u777777u55w00",
    "55wtttttttww5500",
    "5wttuwwwwuttw500",
    "0wtuwwwwwwutw000",
    "00wttttttttw0000",
    "0000333333000000",
    "0003tttttt300000",
    "003t000000t30000",
    "003t000000t30000",
    "00w00000000w0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Bakugo — blast gauntlets + palm pops ---
  const bakuIdle0 = bake([
    "0000055550000000",
    "0000557755000000",
    "0005577755000000",
    "0000zzzzzz000000",
    "000zzyyyyyzz0000",
    "00zy5yyyy5yz0000",
    "0e0zyyyyyyz0e000",
    "0ee0zzzzzz0ee000",
    "0000333333000000",
    "00003zzzz3000000",
    "00003z00z3000000",
    "00003z00z3000000",
    "0000y0000y000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const bakuIdle1 = bake([
    "0000055550000000",
    "0000557755000000",
    "0005577755000000",
    "0000zzzzzz000000",
    "000zzyyyyyzz0000",
    "00zy5yyyy5yz0000",
    "00ezyyyyyyze0000",
    "0e00zzzzzz00e000",
    "0000333333000000",
    "00003zzzz3000000",
    "00003zzzz3000000",
    "000003zz30000000",
    "00000y00y0000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const bakuAtk0 = bake([
    "0000055550000000",
    "0w0055775500w000",
    "0yw5577755wy0000",
    "yw0zzzzzz0wy0000",
    "w0zzyyyyyzz0w000",
    "00zywwwwwwyz0000",
    "000zyyyyyyz00000",
    "0000zzzzzz000000",
    "0000333333000000",
    "0003zzzzzz300000",
    "0003z0000z300000",
    "0003z0000z300000",
    "000y000000y00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const bakuAtk1 = bake([
    "w0y00555500y0w00",
    "wyw05577550wyw00",
    "5yw5577755wy5000",
    "yw5zzzzzz5wy0000",
    "w5zyyyyyyyz5w000",
    "05zywwwwwwyz5000",
    "000ywwwwwwy00000",
    "0000zzzzzz000000",
    "0000333333000000",
    "0003zzzzzz300000",
    "003z000000z30000",
    "003z000000z30000",
    "00y00000000y0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Hoverbind / Uravity — pink float suit + orbit orbs ---
  const hoverIdle0 = bake([
    "00000vvvv0000000",
    "0000v7777v000000",
    "0000v7777v000000",
    "0000vvvvvv000000",
    "0v00vccccv00v000",
    "09v0vccccv0v9000",
    "0000vvvvvv000000",
    "0000v0000v000000",
    "0000ffffff000000",
    "0000ff00ff000000",
    "0000f0000f000000",
    "0000v0000v000000",
    "0000900009000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const hoverIdle1 = bake([
    "000000vvvv000000",
    "00000v7777v00000",
    "00000v7777v00000",
    "00000vvvvvv00000",
    "00v00vccccv00v00",
    "009v0vccccv0v900",
    "00000vvvvvv00000",
    "00000v0000v00000",
    "00000ffffff00000",
    "00000ff00ff00000",
    "00000f0000f00000",
    "00000v0000v00000",
    "0000090000900000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const hoverAtk0 = bake([
    "00000vvvv0000000",
    "0c000v777v00c000",
    "09c0v7777v0c9000",
    "c900vvvvvv09c000",
    "9c00vccccv00c900",
    "0000vccccv000000",
    "0000vvvvvv000000",
    "0000v0000v000000",
    "0000ffffff000000",
    "000ff0000ff00000",
    "000f000000f00000",
    "000v000000v00000",
    "0009000000900000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const hoverAtk1 = bake([
    "c9000vvvv0009c00",
    "9cc0v7777v0cc900",
    "0c9v97779v9c0000",
    "09c0vvvvvv0c9000",
    "9c00vccccv00c900",
    "c000vccccv000c00",
    "0000vvvvvv000000",
    "0000v0000v000000",
    "0000ffffff000000",
    "00ff000000ff0000",
    "00f90000009f0000",
    "009v000000v90000",
    "00c00000000c0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Zerofield — heavier pink float lock ---
  const zeroIdle0 = bake([
    "0000vvvvvv000000",
    "000vccccccv00000",
    "000vc7777cv00000",
    "000vccccccv00000",
    "0000vvvvvv000000",
    "0c0vv7777vv0c000",
    "09cvv7777vvc9000",
    "0000vvvvvv000000",
    "0000ffffff000000",
    "0000ff00ff000000",
    "0000f0000f000000",
    "0000c0000c000000",
    "0000v0000v000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const zeroIdle1 = bake([
    "00000vvvvvv00000",
    "0000vccccccv0000",
    "0000vc7777cv0000",
    "0000vccccccv0000",
    "00000vvvvvv00000",
    "00c0vv7777vv0c00",
    "009cvv7777vvc900",
    "00000vvvvvv00000",
    "00000ffffff00000",
    "00000ff00ff00000",
    "00000f0000f00000",
    "00000c0000c00000",
    "00000v0000v00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const zeroAtk0 = bake([
    "0c000vvvvv00c000",
    "09c0vccccv0c9000",
    "c9cvc7777cvc9c00",
    "9c0vccccccv0c900",
    "c00vvvvvvvv00c00",
    "00cvv7777vvc0000",
    "000vv7777vv00000",
    "0000vvvvvv000000",
    "0000ffffff000000",
    "000ff0000ff00000",
    "000f000000f00000",
    "000c000000c00000",
    "000v000000v00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const zeroAtk1 = bake([
    "c9c00vvvvv00c9c0",
    "9cccvccccvccc900",
    "0c9vc7777cv9c000",
    "09cvccccccvc9000",
    "9c0vvvvvvvv0c900",
    "c0cvvccccvvc0c00",
    "00cvvccccvvc0000",
    "000vvvvvvvv00000",
    "0000ffffff000000",
    "00ff000000ff0000",
    "00fc000000cf0000",
    "009v000000v90000",
    "00c00000000c0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Todoroki — split ice / fire stance ---
  const todoIdle0 = bake([
    "00000x5550000000",
    "0000xx775y000000",
    "0000x7777y000000",
    "0000xxxxxx000000",
    "000xx7777yy00000",
    "00x7x7777y7y0000",
    "000xx7777yy00000",
    "0000x0000y000000",
    "0000ffffff000000",
    "0000ff00ff000000",
    "0000f0000f000000",
    "0000x0000y000000",
    "0000c0000e000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const todoIdle1 = bake([
    "000000x555000000",
    "00000xx775y00000",
    "00000x7777y00000",
    "00000xxxxxx00000",
    "0000xx7777yy0000",
    "000x7x7777y7y000",
    "0000xx7777yy0000",
    "00000x0000y00000",
    "00000ffffff00000",
    "00000ff00ff00000",
    "00000f0000f00000",
    "00000x0000y00000",
    "00000c0000e00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const todoAtk0 = bake([
    "00000x5550000000",
    "0c000x775y00e000",
    "09c0x7777y0ye000",
    "c900xxxxxx0ey000",
    "9c0xx7777yy0e000",
    "00x7xwwwwy7y0000",
    "000xx7777yy00000",
    "0000x0000y000000",
    "0000ffffff000000",
    "000ff0000ff00000",
    "000f000000f00000",
    "000x000000y00000",
    "000c000000e00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const todoAtk1 = bake([
    "c9x00x55500y0e00",
    "9cc0xx775y0eye00",
    "0c9x97779y9ye000",
    "09c0xxxxxx0ey000",
    "9c0xx7777yy0e900",
    "c0x7xwwwwy7y0e00",
    "00xxwwwwwyy00000",
    "000xxxxxxx000000",
    "0000ffffff000000",
    "00ff000000ff0000",
    "00fc000000ef0000",
    "009x000000y90000",
    "00c00000000e0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Tideblade (Breath Line) — water cloak + cleave arc ---
  const tideIdle0 = bake([
    "0000066600000000",
    "000066c660000000",
    "0006c77c60000000",
    "0000bbbbbb000000",
    "000bb6666bb00000",
    "00b6b7777b6b0c00",
    "000bb6666bb00c00",
    "0000bbbbbb000600",
    "0000aaaaaa000000",
    "0000aa00aa000000",
    "0000a0000a000000",
    "0000600006000000",
    "0000c0000c000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const tideIdle1 = bake([
    "0000006660000000",
    "0000066c66000000",
    "00006c77c6000000",
    "00000bbbbbb00000",
    "0000bb6666bb0000",
    "000b6b7777b6b0c0",
    "0000bb6666bb00c0",
    "00000bbbbbb00060",
    "00000aaaaaa00000",
    "00000aa00aa00000",
    "00000a0000a00000",
    "0000060000600000",
    "00000c0000c00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const tideAtk0 = bake([
    "0000066600000000",
    "000066c6600c0000",
    "0006c77c60c60000",
    "0000bbbbbbc60000",
    "000bb6666b6c0000",
    "00b6b7777bc60000",
    "000bb6666b6c0000",
    "0000bbbbbb6c0000",
    "0000aaaaaa0c0000",
    "000aa0000aa00000",
    "000a000000a00000",
    "0006000000600000",
    "000c000000c00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const tideAtk1 = bake([
    "00000666000r6000",
    "000066c660r6c000",
    "0006c77c6r6c6000",
    "0000bbbbbr6c6000",
    "000bb6666r6c0000",
    "00b6b7777r6c0000",
    "000bb6666r6c0000",
    "0000bbbbbr6c0000",
    "0000aaaaaa6c0000",
    "000aa0000aac0000",
    "000a000000a60000",
    "0006000000600000",
    "000c000000c00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Flashstep (Breath Line) — gold lightning scarf + blink ---
  const flashIdle0 = bake([
    "0000044400000000",
    "0000447744000000",
    "0004477744000000",
    "0000llllll000000",
    "0400l4444l004000",
    "04e0l7777l0e4000",
    "0000llllll000000",
    "0000l0000l000000",
    "0000222222000000",
    "0000220022000000",
    "00002e00e2000000",
    "0000400004000000",
    "0000e0000e000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const flashIdle1 = bake([
    "0000004440000000",
    "0000044774400000",
    "0000447774400000",
    "00000llllll00000",
    "00400l4444l00400",
    "004e0l7777l0e400",
    "00000llllll00000",
    "00000l0000l00000",
    "0000022222200000",
    "0000022002200000",
    "000002e00e200000",
    "0000040000400000",
    "00000e0000e00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const flashAtk0 = bake([
    "0000044400e40000",
    "0000447744e40000",
    "000447774e400000",
    "0000llllle400000",
    "0400l4444e400000",
    "04e0l7777e400000",
    "0000llllle400000",
    "0000l0000e400000",
    "000022222e400000",
    "00002200e2400000",
    "00002e0e42000000",
    "0000404e00000000",
    "0000e4e000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const flashAtk1 = bake([
    "4e00044400e4e000",
    "e4e0447744e4e000",
    "04e447774e4e0000",
    "0e40llllle4e0000",
    "4e00l4444e4e0000",
    "e4e0l7777e4e0000",
    "04e0llllle4e0000",
    "0e40l0000e4e0000",
    "4e0022222e4e0000",
    "e4002200e24e0000",
    "04002e0e42000000",
    "0e00404e00000000",
    "4e00e4e000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Shellbrute (Wall Corps) — bulky armor smash ---
  const shellIdle0 = bake([
    "0000oonnnoo00000",
    "000onnnnnnno0000",
    "00onn7777nno0000",
    "00onnnnnnnno0000",
    "0oonnnnnnnnoo000",
    "oonnnnnnnnnnoo00",
    "oonoonnnnoono000",
    "0oon0nnnn0noo000",
    "00oonnnnnnoo0000",
    "000onnnnnno00000",
    "000onnnnnoo00000",
    "000onn00nno00000",
    "000onn00nno00000",
    "000ooo00ooo00000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const shellIdle1 = bake([
    "00000oonnnoo0000",
    "0000onnnnnnno000",
    "000onn7777nno000",
    "000onnnnnnnno000",
    "00oonnnnnnnnoo00",
    "0oonnnnnnnnnnoo0",
    "0oonoonnnnoono00",
    "00oon0nnnn0noo00",
    "000oonnnnnnoo000",
    "0000onnnnnno0000",
    "0000onnnnnoo0000",
    "0000onn0nnno0000",
    "00000nn00nno0000",
    "00000oo00ooo0000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const shellAtk0 = bake([
    "0000oonnnoo00000",
    "000onnnnnnno0000",
    "00onn7777nno0000",
    "00onnnnnnnno0000",
    "0oonnnnnnnnoo000",
    "oonnnnnnnnnnoo00",
    "noonoonnnnoononn",
    "nooon0nnnn0noonn",
    "n0oonnnnnnoo0n00",
    "000onnnnnno00000",
    "000onnnnnoo00000",
    "000onn00nno00000",
    "000onn00nno00000",
    "000ooo00ooo00000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const shellAtk1 = bake([
    "0000oonnnoo00000",
    "n00onnnnnnno00n0",
    "noonn7777nnoon00",
    "noonnnnnnnnoon00",
    "nooonnnnnnnoonn0",
    "oonnnnnnnnnnoo00",
    "oonoonnnnoono000",
    "0oon0nnnn0noo000",
    "00oonnnnnnoo0000",
    "000onnnnnno00000",
    "000nnnnnnnn00000",
    "00nnn0000nnn0000",
    "00nn000000nn0000",
    "00oo000000oo0000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Wirehook (Wall Corps) — lean wire scout multi-stab ---
  const wireIdle0 = bake([
    "00000ccc00000000",
    "0000c77c70000000",
    "000c7777c0000000",
    "0000llllll000000",
    "0c00lcccccl0c000",
    "00c0l7777l0c0000",
    "0000llllll000000",
    "0000l0000l00c000",
    "0000ffffff000c00",
    "0000ff00ff000c00",
    "0000f0000f000000",
    "0000c0000c000000",
    "0000c0000c000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const wireIdle1 = bake([
    "000000ccc0000000",
    "00000c77c7000000",
    "0000c7777c000000",
    "00000llllll00000",
    "00c00lcccccl0c00",
    "000c0l7777l0c000",
    "00000llllll00000",
    "00000l0000l00c00",
    "00000ffffff000c0",
    "00000ff00ff000c0",
    "00000f0000f00000",
    "00000c0000c00000",
    "00000c0000c00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const wireAtk0 = bake([
    "00000ccc000c0000",
    "0000c77c70c00000",
    "000c7777cc000000",
    "0000lllllc000000",
    "0c00lccccc000000",
    "00c0l7777c000000",
    "0000lllllc000000",
    "0000l0000c000000",
    "0000ffffffc00000",
    "0000ff00ff0c0000",
    "0000f0000f00c000",
    "0000c0000c000c00",
    "0000c0000c000c00",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const wireAtk1 = bake([
    "00000ccc00c0c000",
    "0000c77c70c0c000",
    "000c7777cc0c0000",
    "0000lllllc0c0000",
    "0c00lccccc0c0000",
    "00c0l7777c0c0000",
    "0000lllllc0c0000",
    "0000l0000c0c0000",
    "0000ffffffc0c000",
    "0000ff00ff0c0c00",
    "0000f0000f00c0c0",
    "0000c0000c000c0c",
    "0000c0000c000c00",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Veinfist (Curse Ward) — crimson wraps punch ---
  const veinIdle0 = bake([
    "0000088800000000",
    "0000887788000000",
    "0008877788000000",
    "0000llllll000000",
    "0800l8888l008000",
    "08q0l7777l0q8000",
    "0000llllll000000",
    "0000l0000l000000",
    "0000222222000000",
    "0000288822000000",
    "00002q00q2000000",
    "0000800008000000",
    "0000q0000q000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const veinIdle1 = bake([
    "0000008880000000",
    "0000088778800000",
    "0000887778800000",
    "00000llllll00000",
    "00800l8888l00800",
    "008q0l7777l0q800",
    "00000llllll00000",
    "00000l0000l00000",
    "0000022222200000",
    "0000028882200000",
    "000002q00q200000",
    "0000080000800000",
    "00000q0000q00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const veinAtk0 = bake([
    "0000088800000000",
    "0800887788008000",
    "08q8877788q80000",
    "q800llllll08q000",
    "8q00l8888l00q800",
    "0000l7777l000000",
    "0000llllll000000",
    "0000l0000l000000",
    "0000222222000000",
    "0002288822000000",
    "0002q0000q200000",
    "0008000000800000",
    "000q000000q00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const veinAtk1 = bake([
    "8q000888000q8000",
    "q8q08877880q8q00",
    "08q8877788q8q000",
    "q8q0llllll0q8q00",
    "8q88l8888l88q800",
    "q800l7777l008q00",
    "0000llllll000000",
    "0000l0000l000000",
    "0000222222000000",
    "0002288822000000",
    "002q000000q20000",
    "0080000000080000",
    "00q00000000q0000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Markzone (Curse Ward) — pulse caster, ground mark expand ---
  const markIdle0 = bake([
    "0000060600000000",
    "00006ccc60000000",
    "0006c77c60000000",
    "0000pppppp000000",
    "000pp6666pp00000",
    "00p6p7777p6p0000",
    "000pp6666pp00000",
    "0000pppppp000000",
    "0000666666000000",
    "00006p00p6000000",
    "0000p0000p000000",
    "0000600006000000",
    "0000c0000c000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const markIdle1 = bake([
    "0000006060000000",
    "000006ccc6000000",
    "00006c77c6000000",
    "00000pppppp00000",
    "0000pp6666pp0000",
    "000p6p7777p6p000",
    "0000pp6666pp0000",
    "00000pppppp00000",
    "0000066666600000",
    "000006p00p600000",
    "00000p0000p00000",
    "0000060000600000",
    "00000c0000c00000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const markAtk0 = bake([
    "0000060600000000",
    "00006ccc60000000",
    "0006c77c60000000",
    "0000pppppp000000",
    "000pp6666pp00000",
    "00p6p7777p6p0000",
    "000pp6666pp00000",
    "0000pppppp000000",
    "0066666666660000",
    "06p00000000p6000",
    "0p0000000000p000",
    "0600000000006000",
    "0c0000000000c000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const markAtk1 = bake([
    "0000060600000000",
    "00006ccc60000000",
    "0006c77c60000000",
    "0000pppppp000000",
    "000pp6666pp00000",
    "00p6p7777p6p0000",
    "000pp6666pp00000",
    "0666pppppp666000",
    "6p6666666666p600",
    "p600000000006p00",
    "6000000000000600",
    "c0000000000000c0",
    "6000000000000060",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Shadeknife (Gate Shade hunter) 16x16 — hooded dual-knife idle/attack ---
  const shadeIdle0 = bake([
    "0000hhhhh0000000",
    "000hiiiiih000000",
    "00higgggih000000",
    "00higgggiih00000",
    "00hiiiiiiih00000",
    "000hsassah000000",
    "0c0hiaaaih0c0000",
    "0c00iaaai00c0000",
    "0000iiiiii000000",
    "0000llllll000000",
    "0000ll00ll000000",
    "0000l0000l000000",
    "0000j0000j000000",
    "0000c0000c000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  const shadeIdle1 = bake([
    "00000hhhhh000000",
    "0000hiiiiih00000",
    "000higgggih00000",
    "000higgggiih0000",
    "000hiiiiiiih0000",
    "0000hsassah00000",
    "00c0hiaaaih0c000",
    "00c00iaaai00c000",
    "00000iiiiii00000",
    "00000llllll00000",
    "00000ll00ll00000",
    "00000l0000l00000",
    "00000j0000j00000",
    "00000c0000c00000",
    "0000000000000000",
    "0000000000000000",
  ]);

  const shadeAtk0 = bake([
    "0000hhhhh0000000",
    "000hiiiiih000000",
    "00higgggih000000",
    "0chiggggiihc0000",
    "c0hiiiiiiih0c000",
    "g00hsassah00g000",
    "000hiaaaih000000",
    "0000iaaai0000000",
    "0000iiiiii000000",
    "0000llllll000000",
    "000ll0000ll00000",
    "000l000000l00000",
    "000j000000j00000",
    "000c000000c00000",
    "0000000000000000",
    "0000000000000000",
  ]);

  const shadeAtk1 = bake([
    "g000hhhhh000g000",
    "rg0hiiiiih0gr000",
    "0rhiggggihr00000",
    "0chiggggiihc0000",
    "c0hiiiiiiih0c000",
    "000hsassah000000",
    "000hiaaaih000000",
    "0000iaaai0000000",
    "0000iiiiii000000",
    "0000llllll000000",
    "000ll0000ll00000",
    "00l0000000l00000",
    "00j0000000j00000",
    "00c0000000c00000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Gravemark (Gate Shade) — ash raiser; attack = shadow tendrils ---
  const graveIdle0 = bake([
    "000g0hhh0g000000",
    "000hiiiiih000000",
    "00higgggih000000",
    "00hiiiiiiih00000",
    "000hiiiiih000000",
    "0000iiiiii000000",
    "0000llllll000000",
    "0000ll00ll000000",
    "0000l0000l000000",
    "0000iiiiii000000",
    "000ii0000ii00000",
    "000i000000i00000",
    "000h000000h00000",
    "000g000000g00000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const graveIdle1 = bake([
    "0000g0hhh0g00000",
    "0000hiiiiih00000",
    "000higgggih00000",
    "000hiiiiiiih0000",
    "0000hiiiiih00000",
    "00000iiiiii00000",
    "00000llllll00000",
    "00000ll00ll00000",
    "00000l0000l00000",
    "00000iiiiii00000",
    "0000ii0000ii0000",
    "0000i000000i0000",
    "0000h000000h0000",
    "0000g000000g0000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const graveAtk0 = bake([
    "000g0hhh0g000000",
    "0g0hiiiiih0g0000",
    "00higgggih000000",
    "00hiiiiiiih00000",
    "000hiiiiih000000",
    "0000iiiiii000000",
    "0000llllll000000",
    "0000ll00ll000000",
    "000hl0000lh00000",
    "000hiiiiiih00000",
    "00hii0000iih0000",
    "00hi000000ih0000",
    "00h00000000h0000",
    "00g00000000g0000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const graveAtk1 = bake([
    "g0rg0hhh0gr0g000",
    "rg0hiiiiih0gr000",
    "0rhiggggihr00000",
    "00hiiiiiiih00000",
    "000hiiiiih000000",
    "0000iiiiii000000",
    "0000llllll000000",
    "00h0ll00ll0h0000",
    "00hl00000lh00000",
    "0h0hiiiiiih0h000",
    "0hhii0000iihh000",
    "0hhi000000ihh000",
    "0hh00000000hh000",
    "0gg00000000gg000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // --- Mob walk frames ---

  // quirling — Hero Crest energy minion (green knuckle drone)
  const quirling0 = bake([
    "000000uuuu000000",
    "00000uwwwu000000",
    "0000uw777wu00000",
    "0000u77777u00000",
    "0000zzzzzz000000",
    "000zzuuuuzz00000",
    "00zu7kkkk7uz0000",
    "0k0zukkkuz0k0000",
    "0kk0zzzzzz0kk000",
    "0000333333000000",
    "00003uuuu3000000",
    "00003u00u3000000",
    "00003u00u3000000",
    "0000k0000k000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const quirling1 = bake([
    "000000uuuu000000",
    "00000uwwwu000000",
    "0000uw777wu00000",
    "0000u77777u00000",
    "0000zzzzzz000000",
    "000zzuuuuzz00000",
    "00zu7kkkk7uz0000",
    "00kzukkkuzk00000",
    "0k00zzzzzz00k000",
    "0000333333000000",
    "00003uuuu3000000",
    "00003uuuu3000000",
    "000003uu30000000",
    "00000k00k0000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // ashfiend — Breath Line demon foot soldier
  const ashfiend0 = bake([
    "000j00000j000000",
    "000l88888l000000",
    "000l81118l000000",
    "0000llllll000000",
    "0000iiiiii000000",
    "000iiiiiiii00000",
    "00ii8iiii8ii0000",
    "0lii0iiii0iilc00",
    "0000iiiiii000c00",
    "0000llllll000c00",
    "0000ll00ll000n00",
    "0000l0000l000000",
    "0000i0000i000000",
    "0000q0000q000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const ashfiend1 = bake([
    "000j00000j000000",
    "000l88888l000000",
    "000l81118l000000",
    "0000llllll000000",
    "0000iiiiii000000",
    "000iiiiiiii00000",
    "00ii8iiii8ii0000",
    "0lii0iiii0iil0c0",
    "0000iiiiii0000c0",
    "0000llllll0000c0",
    "000ll0000ll000n0",
    "000l000000l00000",
    "000i000000i00000",
    "000q000000q00000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // shardbrute — Wall Corps mini titan
  const shardbrute0 = bake([
    "0000oonnnoo00000",
    "000onnnnnnno0000",
    "00onn7777nno0000",
    "00onn8n8nnno0000",
    "0oonnnnnnnnoo000",
    "oonnnnnnnnnnoo00",
    "oonoonnnnoono000",
    "0oon0nnnn0noo000",
    "00oonnnnnnoo0000",
    "000onnnnnno00000",
    "000onnnnnoo00000",
    "000onn00nno00000",
    "000onn00nno00000",
    "000ooo00ooo00000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const shardbrute1 = bake([
    "00000oonnnoo0000",
    "0000onnnnnnno000",
    "000onn7777nno000",
    "000onn8n8nnno000",
    "00oonnnnnnnnoo00",
    "0oonnnnnnnnnnoo0",
    "0oonoonnnnoono00",
    "00oon0nnnn0noo00",
    "000oonnnnnnoo000",
    "0000onnnnnno0000",
    "0000onnnnnoo0000",
    "0000onn0nnno0000",
    "00000nn00nno0000",
    "00000oo00ooo0000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // hexwisp — Curse Ward cursed spirit (dark teal + crimson, not purple)
  const hexwisp0 = bake([
    "00000ppp00000000",
    "0000pqqqp0000000",
    "000pq777qp000000",
    "00pq7rrr7qp00000",
    "00pqq777qqp00000",
    "000pqqqqqp000000",
    "0000ppppp0000000",
    "000p0ppp0p000000",
    "00p0000000p00000",
    "0p000q00000p0000",
    "00000p0000000000",
    "000p0000p0000000",
    "00p0000000p00000",
    "0p000000000p0000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const hexwisp1 = bake([
    "000000ppp0000000",
    "00000pqqqp000000",
    "0000pq777qp00000",
    "000pq7rrr7qp0000",
    "000pqq777qqp0000",
    "0000pqqqqqp00000",
    "00000ppppp000000",
    "0000p0ppp0p00000",
    "000p0000000p0000",
    "00p000q00000p000",
    "0p0000p000000p00",
    "00000000p0000000",
    "0000p00000000000",
    "0000000000p00000",
    "0000000000000000",
    "0000000000000000",
  ]);

  // gatehound — Gate Shade dungeon beast
  const gatehound0 = bake([
    "0000000000000000",
    "000hhg0000000000",
    "00hghhh000000000",
    "0hhl7hhh00000000",
    "00hhhhhhhg000000",
    "000hhhhhhhh00000",
    "000hhghhhhhh0000",
    "000hhhhhhhhhhh00",
    "000hhhhhhh00hh00",
    "000hg0hg0h00h000",
    "000h00h00h00h000",
    "000r00r00r00r000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);
  const gatehound1 = bake([
    "0000000000000000",
    "0000hhg000000000",
    "000hghhh00000000",
    "00hhl7hhh0000000",
    "000hhhhhhhg00000",
    "0000hhhhhhhh0000",
    "0000hhghhhhhh000",
    "0000hhhhhhhhhhh0",
    "0000hhhhhhh00hh0",
    "0000h00hg0h00h00",
    "0000h00h00h00h00",
    "0000r00r00r00r00",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
  ]);

  const MOB_KINDS = ["quirling", "ashfiend", "shardbrute", "hexwisp", "gatehound"];

  const mobs = {
    quirling: {
      walk: [quirling0, quirling1],
      series: "Hero Crest",
      blurb: "Energy-minion knuckles",
    },
    ashfiend: {
      walk: [ashfiend0, ashfiend1],
      series: "Breath Line",
      blurb: "Demon foot soldier",
    },
    shardbrute: {
      walk: [shardbrute0, shardbrute1],
      series: "Wall Corps",
      blurb: "Rocky mini titan",
    },
    hexwisp: {
      walk: [hexwisp0, hexwisp1],
      series: "Curse Ward",
      blurb: "One-eyed cursed spirit",
    },
    gatehound: {
      walk: [gatehound0, gatehound1],
      series: "Gate Shade",
      blurb: "Rune-marked shadow hound",
    },
  };

  const sparkfist = {
    idle: [sparkIdle0, sparkIdle1],
    attack: [sparkAtk0, sparkAtk1],
  };
  const blastcrown = {
    idle: [blastIdle0, blastIdle1],
    attack: [blastAtk0, blastAtk1],
  };

  const hoverbind = {
    idle: [hoverIdle0, hoverIdle1],
    attack: [hoverAtk0, hoverAtk1],
  };
  const zerofield = {
    idle: [zeroIdle0, zeroIdle1],
    attack: [zeroAtk0, zeroAtk1],
  };

  const bakugo = {
    idle: [bakuIdle0, bakuIdle1],
    attack: [bakuAtk0, bakuAtk1],
  };
  const todoroki = {
    idle: [todoIdle0, todoIdle1],
    attack: [todoAtk0, todoAtk1],
  };

  const tideblade = {
    idle: [tideIdle0, tideIdle1],
    attack: [tideAtk0, tideAtk1],
  };
  const torrentfang = tintPack(tideblade, "#6ee0c8", "#c8fff0", 0.28, 0.34);

  const flashstep = {
    idle: [flashIdle0, flashIdle1],
    attack: [flashAtk0, flashAtk1],
  };
  const thunderpierce = tintPack(flashstep, "#ffe08a", "#fff4c0", 0.3, 0.36);

  const shellbrute = {
    idle: [shellIdle0, shellIdle1],
    attack: [shellAtk0, shellAtk1],
  };
  const colossus = tintPack(shellbrute, "#c0a888", "#e8d0b0", 0.28, 0.34);

  const wirehook = {
    idle: [wireIdle0, wireIdle1],
    attack: [wireAtk0, wireAtk1],
  };
  const skydancer = tintPack(wirehook, "#e6dcc8", "#ffffff", 0.26, 0.32);

  const veinfist = {
    idle: [veinIdle0, veinIdle1],
    attack: [veinAtk0, veinAtk1],
  };
  const blackspar = tintPack(veinfist, "#ff6060", "#ff9090", 0.3, 0.36);

  const markzone = {
    idle: [markIdle0, markIdle1],
    attack: [markAtk0, markAtk1],
  };
  const innerdomain = tintPack(markzone, "#6ee0c8", "#a0ffe8", 0.28, 0.34);

  const shadeknife = {
    idle: [shadeIdle0, shadeIdle1],
    attack: [shadeAtk0, shadeAtk1],
  };
  const monarchedge = tintPack(shadeknife, "#9ab8d0", "#c8e8f0", 0.28, 0.32);

  const gravemark = {
    idle: [graveIdle0, graveIdle1],
    attack: [graveAtk0, graveAtk1],
  };
  const shadowhost = tintPack(gravemark, "#7a90a8", "#c8d8e8", 0.28, 0.34);

  const nezuko = tintPack(veinfist, "#e07090", "#ffb0c8", 0.32, 0.36);
  const inosuke = tintPack(shellbrute, "#a09070", "#d0c0a0", 0.28, 0.34);
  const levi = tintPack(wirehook, "#9aa8b8", "#e8f0f8", 0.28, 0.34);
  const armin = tintPack(markzone, "#e8d090", "#fff0c0", 0.28, 0.34);
  const sukuna = tintPack(tideblade, "#c04040", "#ff8080", 0.34, 0.4);
  const megumi = tintPack(gravemark, "#405878", "#80a0c0", 0.3, 0.34);
  const cha = tintPack(wirehook, "#d0c090", "#fff0c0", 0.28, 0.34);
  const beru = tintPack(shellbrute, "#50a060", "#90e0a0", 0.32, 0.36);

  const units = {
    sparkfist,
    blastcrown,
    bakugo,
    hoverbind,
    zerofield,
    todoroki,
    tideblade,
    torrentfang,
    nezuko,
    inosuke,
    flashstep,
    thunderpierce,
    shellbrute,
    colossus,
    wirehook,
    skydancer,
    levi,
    armin,
    veinfist,
    blackspar,
    sukuna,
    markzone,
    innerdomain,
    megumi,
    shadeknife,
    monarchedge,
    gravemark,
    shadowhost,
    cha,
    beru,
  };

  function drawUnit(ctx, canvas, x, y, size) {
    if (!canvas) return;
    const s = size || canvas.width;
    ctx.drawImage(canvas, x, y, s, s);
  }

  function unitFrame(defId, unit, tick) {
    const pack = units[defId];
    if (!pack) return null;
    if (unit.attackAnim && unit.attackAnim > 0) {
      const fi = unit.attackAnim > 8 ? 0 : 1;
      return pack.attack[fi];
    }
    const fi = (tick >> 4) & 1;
    return pack.idle[fi];
  }

  function mobFrame(kind, pathIndex) {
    const pack = mobs[kind];
    if (!pack) return null;
    const fi = Math.floor(pathIndex / 8) & 1;
    return pack.walk[fi];
  }

  window.SpiritSprites = {
    PAL,
    bake,
    tintCanvas,
    units,
    sparkfist,
    blastcrown,
    bakugo,
    hoverbind,
    zerofield,
    todoroki,
    tideblade,
    torrentfang,
    nezuko,
    inosuke,
    flashstep,
    thunderpierce,
    shellbrute,
    colossus,
    wirehook,
    skydancer,
    levi,
    armin,
    veinfist,
    blackspar,
    sukuna,
    markzone,
    innerdomain,
    megumi,
    shadeknife,
    monarchedge,
    gravemark,
    shadowhost,
    cha,
    beru,
    mobs,
    MOB_KINDS,
    drawUnit,
    unitFrame,
    mobFrame,
  };
})();
