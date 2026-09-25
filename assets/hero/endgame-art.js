(() => {
  "use strict";

  // Endgame art for My Hero:
  //  - Shop cards: portrait stages (endgame PNGs)
  //  - Map models: NEW full-body idle/attack packs built from those same
  //    shop cards so board units match the hero card look while moving
  //    like the other anime series.
  const ASSET_URLS = {
    "sparkfist-endgame": "assets/hero/hero-sparkfist-endgame.png",
    "blastcrown-endgame": "assets/hero/hero-blastcrown-endgame.png",
    "bakugo-endgame": "assets/hero/hero-bakugo-endgame.png",
    "howitzer-endgame": "assets/hero/hero-howitzer-endgame.png",
    "hoverbind-endgame": "assets/hero/hero-hoverbind-endgame.png",
    "zerofield-endgame": "assets/hero/hero-zerofield-endgame.png",
    "todoroki-endgame": "assets/hero/hero-todoroki-endgame.png",
    "halfcold-endgame": "assets/hero/hero-halfcold-endgame.png",
    "sparkfist-board": "assets/hero/hero-sparkfist-board.png",
    "blastcrown-board": "assets/hero/hero-blastcrown-board.png",
    "bakugo-board": "assets/hero/hero-bakugo-board.png",
    "howitzer-board": "assets/hero/hero-howitzer-board.png",
    "hoverbind-board": "assets/hero/hero-hoverbind-board.png",
    "zerofield-board": "assets/hero/hero-zerofield-board.png",
    "todoroki-board": "assets/hero/hero-todoroki-board.png",
    "halfcold-board": "assets/hero/hero-halfcold-board.png",
    "quirling-endgame": "assets/hero/hero-quirling-endgame.png",
    "multifist-endgame": "assets/hero/hero-multifist-endgame.png",
    "floatdrone-endgame": "assets/hero/hero-floatdrone-endgame.png",
    "sparkgrub-endgame": "assets/hero/hero-sparkgrub-endgame.png",
    "quirling-board": "assets/hero/hero-quirling-board.png",
    "multifist-board": "assets/hero/hero-multifist-board.png",
    "floatdrone-board": "assets/hero/hero-floatdrone-board.png",
    "sparkgrub-board": "assets/hero/hero-sparkgrub-board.png",
    "crest-map": "assets/hero/hero-crest-map-endgame.png",
  };

  const HERO_UNIT_IDS = [
    "sparkfist",
    "blastcrown",
    "bakugo",
    "howitzer",
    "hoverbind",
    "zerofield",
    "todoroki",
    "halfcold",
  ];
  const HERO_MOB_IDS = ["quirling", "multifist", "floatdrone", "sparkgrub"];

  // Costume / FX hints per unit (used when sampling is thin).
  const UNIT_STYLE = {
    sparkfist: { suit: "#1a5030", accent: "#5ee08a", boot: "#2a2018", fx: "#7dff9a" },
    blastcrown: { suit: "#1a5030", accent: "#ffe08a", boot: "#2a2018", fx: "#fff0a0" },
    bakugo: { suit: "#1a1410", accent: "#ff8a40", boot: "#3a2010", fx: "#ffb060" },
    howitzer: { suit: "#1a1410", accent: "#ff7040", boot: "#3a2010", fx: "#ffe080" },
    hoverbind: { suit: "#2a1828", accent: "#f0b0c8", boot: "#3a2030", fx: "#ffd0e8" },
    zerofield: { suit: "#201828", accent: "#e8a0c8", boot: "#3a2038", fx: "#f0d0ff" },
    todoroki: { suit: "#141828", accent: "#90c8e8", boot: "#1a2030", fx: "#ff7040" },
    halfcold: { suit: "#141828", accent: "#90c8e8", boot: "#1a2030", fx: "#ff6030" },
  };
  const MOB_STYLE = {
    quirling: { suit: "#1a5030", accent: "#6ee0a0", boot: "#2a2018", fx: "#9dffb0" },
    multifist: { suit: "#2a1810", accent: "#ffe080", boot: "#3a2010", fx: "#ffd060" },
    floatdrone: { suit: "#182030", accent: "#a8d0ff", boot: "#203040", fx: "#d0e8ff" },
    sparkgrub: { suit: "#301810", accent: "#ff9060", boot: "#3a2010", fx: "#ffc080" },
  };

  const portraits = Object.create(null);
  const mapSprites = Object.create(null);
  const mobPortraits = Object.create(null);
  const unitPacks = Object.create(null); // shop portrait stages
  const mobPacks = Object.create(null);
  const mapUnitPacks = Object.create(null); // new full-body map models
  const mapMobPacks = Object.create(null);
  let mapBackdrop = null;
  let ready = false;
  const waiters = [];

  function whenReady(cb) {
    if (ready) cb();
    else waiters.push(cb);
  }

  function loadImage(src) {
    return new Promise((resolve) => {
      const img = new Image();
      img.decoding = "async";
      img.onload = () => resolve(img);
      img.onerror = () => resolve(null);
      img.src = src;
    });
  }

  function makeCanvas(w, h) {
    const c = document.createElement("canvas");
    c.width = w;
    c.height = h;
    const ctx = c.getContext("2d");
    ctx.imageSmoothingEnabled = false;
    return { canvas: c, ctx };
  }

  function sourceSize(src) {
    return {
      w: src.naturalWidth || src.width,
      h: src.naturalHeight || src.height,
    };
  }

  function knockOutInk(src, threshold = 24) {
    const { w, h } = sourceSize(src);
    const { canvas, ctx } = makeCanvas(w, h);
    ctx.drawImage(src, 0, 0);
    const img = ctx.getImageData(0, 0, w, h);
    const d = img.data;
    for (let i = 0; i < d.length; i += 4) {
      if (d[i] <= threshold && d[i + 1] <= threshold && d[i + 2] <= threshold) {
        d[i + 3] = 0;
      }
    }
    ctx.putImageData(img, 0, 0);
    return canvas;
  }

  function contentBounds(src) {
    const { w, h } = sourceSize(src);
    const { ctx } = (() => {
      const m = makeCanvas(w, h);
      m.ctx.drawImage(src, 0, 0);
      return m;
    })();
    const d = ctx.getImageData(0, 0, w, h).data;
    let minX = w,
      minY = h,
      maxX = 0,
      maxY = 0;
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const a = d[(y * w + x) * 4 + 3];
        if (a < 16) continue;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX) return { x: 0, y: 0, w, h };
    return {
      x: minX,
      y: minY,
      w: maxX - minX + 1,
      h: maxY - minY + 1,
    };
  }

  function cropCanvas(src, box) {
    const { canvas, ctx } = makeCanvas(box.w, box.h);
    ctx.drawImage(src, box.x, box.y, box.w, box.h, 0, 0, box.w, box.h);
    return canvas;
  }

  function sampleAccent(src, fallback) {
    const { w, h } = sourceSize(src);
    const { ctx } = (() => {
      const m = makeCanvas(w, h);
      m.ctx.drawImage(src, 0, 0);
      return m;
    })();
    const d = ctx.getImageData(0, 0, w, h).data;
    let best = null;
    let bestScore = -1;
    for (let i = 0; i < d.length; i += 4) {
      const a = d[i + 3];
      if (a < 200) continue;
      const r = d[i],
        g = d[i + 1],
        b = d[i + 2];
      // Prefer saturated mid/bright pixels for accents (gauntlets, FX, hair tips).
      const max = Math.max(r, g, b);
      const min = Math.min(r, g, b);
      const sat = max - min;
      const score = sat * 2 + max;
      if (score > bestScore && max > 80) {
        bestScore = score;
        best = `rgb(${r},${g},${b})`;
      }
    }
    return best || fallback;
  }

  /** Shop portrait stage: card art with a light idle bob (stage drawn by UI). */
  function buildShopPack(src, fx) {
    const cut = knockOutInk(src);
    const box = contentBounds(cut);
    const head = cropCanvas(cut, box);
    function portrait(dy, tintStr) {
      const size = 48;
      const { canvas, ctx } = makeCanvas(size, size);
      const pad = 4;
      ctx.drawImage(head, pad, pad + dy, size - pad * 2, size - pad * 2 - 4);
      if (tintStr) {
        ctx.globalCompositeOperation = "source-atop";
        ctx.globalAlpha = tintStr;
        ctx.fillStyle = fx;
        ctx.fillRect(0, 0, size, size);
        ctx.globalAlpha = 1;
        ctx.globalCompositeOperation = "source-over";
      }
      return canvas;
    }
    return {
      idle: [portrait(0, 0), portrait(-1, 0.08)],
      attack: [portrait(1, 0.16), portrait(-1, 0.24)],
    };
  }

  /**
   * New map model: full-body 16×16 figure whose head/bust comes from the
   * shop hero card, with anime-series-style idle bob + attack poses.
   */
  function buildMapModelPack(cardImg, style) {
    const cut = knockOutInk(cardImg);
    const box = contentBounds(cut);
    // Face/hair only from the shop card (not the whole bust), so the map
    // model can grow a matching full body underneath like other series.
    const headBox = {
      x: box.x + Math.floor(box.w * 0.08),
      y: box.y,
      w: Math.max(8, Math.floor(box.w * 0.84)),
      h: Math.max(8, Math.floor(box.h * 0.48)),
    };
    const head = cropCanvas(cut, headBox);
    const accent = sampleAccent(cut, style.accent);

    function drawModel(pose) {
      const SIZE = 16;
      const { canvas, ctx } = makeCanvas(SIZE, SIZE);
      const bob = pose.bob || 0;
      const squat = pose.squat || 0;
      const armsOut = !!pose.armsOut;
      const flash = !!pose.flash;
      const step = pose.step || 0;

      // Boots / legs (same silhouette language as other anime packs)
      ctx.fillStyle = style.boot;
      const legY = 13 + squat;
      if (step === 0) {
        ctx.fillRect(5, legY, 2, 2);
        ctx.fillRect(9, legY, 2, 2);
      } else {
        ctx.fillRect(4, legY, 2, 2);
        ctx.fillRect(10, legY - 1, 2, 2);
      }
      // Lower suit
      ctx.fillStyle = style.suit;
      ctx.fillRect(5, 11 + squat, 6, 3);

      // Torso
      ctx.fillRect(4, 7 + bob + squat, 8, 5);
      // Belt / chest accent from card palette
      ctx.fillStyle = accent;
      ctx.fillRect(5, 9 + bob + squat, 6, 1);
      ctx.fillRect(4, 8 + bob + squat, 1, 2);
      ctx.fillRect(11, 8 + bob + squat, 1, 2);

      // Arms
      ctx.fillStyle = style.suit;
      if (armsOut) {
        ctx.fillRect(1, 8 + bob, 3, 2);
        ctx.fillRect(12, 8 + bob, 3, 2);
        ctx.fillStyle = accent;
        ctx.fillRect(0, 7 + bob, 2, 3);
        ctx.fillRect(14, 7 + bob, 2, 3);
      } else {
        ctx.fillRect(3, 8 + bob, 2, 3);
        ctx.fillRect(11, 8 + bob, 2, 3);
        ctx.fillStyle = accent;
        ctx.fillRect(2, 9 + bob, 2, 2);
        ctx.fillRect(12, 9 + bob, 2, 2);
      }

      // Shop-card face/hair on top
      const headW = 10;
      const headH = 7;
      const hx = 3;
      const hy = Math.max(0, bob);
      ctx.drawImage(head, hx, hy, headW, headH);

      if (flash) {
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = style.fx;
        ctx.globalAlpha = 0.9;
        ctx.fillRect(0, 6 + bob, 3, 3);
        ctx.fillRect(13, 6 + bob, 3, 3);
        ctx.fillRect(7, 1 + bob, 2, 2);
        ctx.globalAlpha = 1;
        ctx.globalCompositeOperation = "source-over";
      }

      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.fillRect(4, 15, 8, 1);

      return canvas;
    }

    return {
      idle: [
        drawModel({ bob: 0, step: 0 }),
        drawModel({ bob: -1, step: 1 }),
      ],
      attack: [
        drawModel({ bob: 1, squat: 1, armsOut: true }),
        drawModel({ bob: -1, armsOut: true, flash: true }),
      ],
    };
  }

  function buildMapMobPack(cardImg, style) {
    const cut = knockOutInk(cardImg);
    const box = contentBounds(cut);
    const body = cropCanvas(cut, box);
    const accent = sampleAccent(cut, style.accent);

    function drawMob(pose) {
      const SIZE = 16;
      const { canvas, ctx } = makeCanvas(SIZE, SIZE);
      const bob = pose.bob || 0;
      const mirror = !!pose.mirror;

      ctx.save();
      if (mirror) {
        ctx.translate(SIZE, 0);
        ctx.scale(-1, 1);
      }

      // Legs / float base
      ctx.fillStyle = style.boot;
      ctx.fillRect(5, 12 + bob, 2, 3);
      ctx.fillRect(9, 12 + (pose.step ? bob - 1 : bob), 2, 3);
      ctx.fillStyle = style.suit;
      ctx.fillRect(4, 10 + bob, 8, 3);

      // Body from card
      ctx.drawImage(body, 2, 1 + bob, 12, 10);

      if (pose.flash) {
        ctx.globalCompositeOperation = "lighter";
        ctx.fillStyle = accent;
        ctx.globalAlpha = 0.7;
        ctx.fillRect(1, 4 + bob, 2, 2);
        ctx.fillRect(13, 4 + bob, 2, 2);
        ctx.globalAlpha = 1;
        ctx.globalCompositeOperation = "source-over";
      }

      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.fillRect(4, 15, 8, 1);
      ctx.restore();
      return canvas;
    }

    const a = drawMob({ bob: 0, step: 0 });
    const b = drawMob({ bob: -1, step: 1 });
    return {
      walk: [
        a,
        b,
        drawMob({ bob: 0, step: 0, mirror: true }),
        drawMob({ bob: -1, step: 1, mirror: true }),
      ],
    };
  }

  function installIntoSpiritSprites() {
    const SS = window.SpiritSprites;
    if (!SS) return;
    // Dark Deku uses the hand-tuned full-body pack in sprites.js (card-matched).
    // Other My Hero units keep generated card-matched packs until authored.
    const SKIP = { sparkfist: true };
    if (SS.units) {
      HERO_UNIT_IDS.forEach((id) => {
        if (SKIP[id]) return;
        const pack = mapUnitPacks[id];
        if (!pack) return;
        SS.units[id] = pack;
        SS[id] = pack;
      });
    }
    if (SS.mobs) {
      HERO_MOB_IDS.forEach((id) => {
        const pack = mapMobPacks[id];
        if (!pack) return;
        SS.mobs[id] = pack;
      });
    }
  }

  async function boot() {
    const jobs = [];

    HERO_UNIT_IDS.forEach((id) => {
      jobs.push(
        loadImage(ASSET_URLS[`${id}-endgame`]).then((img) => {
          if (img) portraits[id] = img;
        })
      );
      jobs.push(
        loadImage(ASSET_URLS[`${id}-board`]).then((img) => {
          if (img) mapSprites[id] = img;
        })
      );
    });

    HERO_MOB_IDS.forEach((id) => {
      jobs.push(
        loadImage(ASSET_URLS[`${id}-endgame`]).then((img) => {
          if (img) mobPortraits[id] = img;
        })
      );
      jobs.push(
        loadImage(ASSET_URLS[`${id}-board`]).then((img) => {
          if (img) mapSprites[`mob:${id}`] = img;
        })
      );
    });

    jobs.push(
      loadImage(ASSET_URLS["crest-map"]).then((img) => {
        if (img) mapBackdrop = img;
      })
    );

    await Promise.all(jobs);

    HERO_UNIT_IDS.forEach((id) => {
      const card = portraits[id] || mapSprites[id];
      if (!card) return;
      const style = UNIT_STYLE[id] || UNIT_STYLE.sparkfist;
      unitPacks[id] = buildShopPack(card, style.fx);
      mapUnitPacks[id] = buildMapModelPack(card, style);
    });

    HERO_MOB_IDS.forEach((id) => {
      const card = mobPortraits[id] || mapSprites[`mob:${id}`];
      if (!card) return;
      const style = MOB_STYLE[id] || MOB_STYLE.quirling;
      mobPacks[id] = buildShopPack(card, style.fx);
      mapMobPacks[id] = buildMapMobPack(card, style);
    });

    // Replace old My Hero test packs so map drawing (SS.unitFrame) uses the
    // new card-matched models automatically.
    installIntoSpiritSprites();

    ready = true;
    waiters.splice(0).forEach((cb) => {
      try {
        cb();
      } catch (_) {}
    });
  }

  function shopFrame(defId, tick) {
    const pack = unitPacks[defId];
    if (!pack) return null;
    return pack.idle[(tick >> 3) & 1];
  }

  function mapUnitFrame(defId, unit, tick) {
    // Prefer hand-tuned SpiritSprites packs when present (Dark Deku).
    const SS = window.SpiritSprites;
    if (SS && SS.unitFrame && SS.units && SS.units[defId] && defId === "sparkfist") {
      return SS.unitFrame(defId, unit || { attackAnim: 0 }, tick);
    }
    const pack = mapUnitPacks[defId];
    if (!pack) return null;
    if (unit && unit.attackAnim && unit.attackAnim > 0) {
      return pack.attack[unit.attackAnim > 8 ? 0 : 1];
    }
    return pack.idle[(tick >> 3) & 1];
  }

  function mapMobFrame(kind, pathIndex) {
    const pack = mapMobPacks[kind];
    if (!pack || !pack.walk) return null;
    return pack.walk[Math.floor(pathIndex / 5) % pack.walk.length];
  }

  window.SpiritEndgameArt = {
    HERO_UNIT_IDS,
    HERO_MOB_IDS,
    portraits,
    mapSprites,
    mobPortraits,
    unitPacks,
    mobPacks,
    mapUnitPacks,
    mapMobPacks,
    get mapBackdrop() {
      return mapBackdrop;
    },
    get ready() {
      return ready;
    },
    whenReady,
    unitPortrait(id) {
      return portraits[id] || null;
    },
    unitModel(id) {
      return (
        (mapUnitPacks[id] && mapUnitPacks[id].idle[0]) ||
        mapSprites[id] ||
        portraits[id] ||
        null
      );
    },
    unitMapSprite(id) {
      return (mapUnitPacks[id] && mapUnitPacks[id].idle[0]) || mapSprites[id] || null;
    },
    mobMapSprite(kind) {
      return (
        (mapMobPacks[kind] && mapMobPacks[kind].walk[0]) ||
        mapSprites[`mob:${kind}`] ||
        null
      );
    },
    unitFrame: mapUnitFrame,
    mapUnitFrame,
    mobFrame: mapMobFrame,
    mapMobFrame,
    shopFrame,
  };

  boot();
})();
