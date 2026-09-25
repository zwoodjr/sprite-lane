(() => {
  "use strict";

  // My Hero endgame art:
  //  - Shop: portrait stages from *-endgame.png cards
  //  - Map: 24×24 full-body model packs (idle/attack/walk) under assets/hero/models/
  const ASSET_URLS = {
    "sparkfist-endgame": "assets/hero/hero-sparkfist-endgame.png",
    "blastcrown-endgame": "assets/hero/hero-blastcrown-endgame.png",
    "bakugo-endgame": "assets/hero/hero-bakugo-endgame.png",
    "howitzer-endgame": "assets/hero/hero-howitzer-endgame.png",
    "hoverbind-endgame": "assets/hero/hero-hoverbind-endgame.png",
    "zerofield-endgame": "assets/hero/hero-zerofield-endgame.png",
    "todoroki-endgame": "assets/hero/hero-todoroki-endgame.png",
    "halfcold-endgame": "assets/hero/hero-halfcold-endgame.png",
    "quirling-endgame": "assets/hero/hero-quirling-endgame.png",
    "multifist-endgame": "assets/hero/hero-multifist-endgame.png",
    "floatdrone-endgame": "assets/hero/hero-floatdrone-endgame.png",
    "sparkgrub-endgame": "assets/hero/hero-sparkgrub-endgame.png",
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

  // Explicit paths so the offline builder can rewrite them to data URLs.
  const MODEL_URLS = {
    "sparkfist-idle0": "assets/hero/models/sparkfist-idle0.png",
    "sparkfist-idle1": "assets/hero/models/sparkfist-idle1.png",
    "sparkfist-atk0": "assets/hero/models/sparkfist-atk0.png",
    "sparkfist-atk1": "assets/hero/models/sparkfist-atk1.png",
    "blastcrown-idle0": "assets/hero/models/blastcrown-idle0.png",
    "blastcrown-idle1": "assets/hero/models/blastcrown-idle1.png",
    "blastcrown-atk0": "assets/hero/models/blastcrown-atk0.png",
    "blastcrown-atk1": "assets/hero/models/blastcrown-atk1.png",
    "bakugo-idle0": "assets/hero/models/bakugo-idle0.png",
    "bakugo-idle1": "assets/hero/models/bakugo-idle1.png",
    "bakugo-atk0": "assets/hero/models/bakugo-atk0.png",
    "bakugo-atk1": "assets/hero/models/bakugo-atk1.png",
    "howitzer-idle0": "assets/hero/models/howitzer-idle0.png",
    "howitzer-idle1": "assets/hero/models/howitzer-idle1.png",
    "howitzer-atk0": "assets/hero/models/howitzer-atk0.png",
    "howitzer-atk1": "assets/hero/models/howitzer-atk1.png",
    "hoverbind-idle0": "assets/hero/models/hoverbind-idle0.png",
    "hoverbind-idle1": "assets/hero/models/hoverbind-idle1.png",
    "hoverbind-atk0": "assets/hero/models/hoverbind-atk0.png",
    "hoverbind-atk1": "assets/hero/models/hoverbind-atk1.png",
    "zerofield-idle0": "assets/hero/models/zerofield-idle0.png",
    "zerofield-idle1": "assets/hero/models/zerofield-idle1.png",
    "zerofield-atk0": "assets/hero/models/zerofield-atk0.png",
    "zerofield-atk1": "assets/hero/models/zerofield-atk1.png",
    "todoroki-idle0": "assets/hero/models/todoroki-idle0.png",
    "todoroki-idle1": "assets/hero/models/todoroki-idle1.png",
    "todoroki-atk0": "assets/hero/models/todoroki-atk0.png",
    "todoroki-atk1": "assets/hero/models/todoroki-atk1.png",
    "halfcold-idle0": "assets/hero/models/halfcold-idle0.png",
    "halfcold-idle1": "assets/hero/models/halfcold-idle1.png",
    "halfcold-atk0": "assets/hero/models/halfcold-atk0.png",
    "halfcold-atk1": "assets/hero/models/halfcold-atk1.png",
    "quirling-walk0": "assets/hero/models/quirling-walk0.png",
    "quirling-walk1": "assets/hero/models/quirling-walk1.png",
    "quirling-walk2": "assets/hero/models/quirling-walk2.png",
    "quirling-walk3": "assets/hero/models/quirling-walk3.png",
    "multifist-walk0": "assets/hero/models/multifist-walk0.png",
    "multifist-walk1": "assets/hero/models/multifist-walk1.png",
    "multifist-walk2": "assets/hero/models/multifist-walk2.png",
    "multifist-walk3": "assets/hero/models/multifist-walk3.png",
    "floatdrone-walk0": "assets/hero/models/floatdrone-walk0.png",
    "floatdrone-walk1": "assets/hero/models/floatdrone-walk1.png",
    "floatdrone-walk2": "assets/hero/models/floatdrone-walk2.png",
    "floatdrone-walk3": "assets/hero/models/floatdrone-walk3.png",
    "sparkgrub-walk0": "assets/hero/models/sparkgrub-walk0.png",
    "sparkgrub-walk1": "assets/hero/models/sparkgrub-walk1.png",
    "sparkgrub-walk2": "assets/hero/models/sparkgrub-walk2.png",
    "sparkgrub-walk3": "assets/hero/models/sparkgrub-walk3.png",
  };

  const UNIT_FX = {
    sparkfist: "#5ee08a",
    blastcrown: "#ffe08a",
    bakugo: "#ff8a40",
    howitzer: "#ffb060",
    hoverbind: "#f0b0c8",
    zerofield: "#e8a0c8",
    todoroki: "#90c8e8",
    halfcold: "#ff7040",
  };
  const MOB_FX = {
    quirling: "#6ee0a0",
    multifist: "#ffe080",
    floatdrone: "#a8d0ff",
    sparkgrub: "#ff9060",
  };

  const portraits = Object.create(null);
  const unitPacks = Object.create(null); // shop stages
  const mapUnitPacks = Object.create(null); // 24px full-body map models
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
        if (d[(y * w + x) * 4 + 3] < 16) continue;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < minX) return { x: 0, y: 0, w, h };
    return { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 };
  }

  function cropCanvas(src, box) {
    const { canvas, ctx } = makeCanvas(box.w, box.h);
    ctx.drawImage(src, box.x, box.y, box.w, box.h, 0, 0, box.w, box.h);
    return canvas;
  }

  function toCanvas(img) {
    const { w, h } = sourceSize(img);
    const { canvas, ctx } = makeCanvas(w, h);
    ctx.drawImage(img, 0, 0);
    return canvas;
  }

  /** Shop portrait bob from endgame cards. */
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

  /** Drop residual black mats and keep the model filling its square. */
  function normalizeModelFrame(src, size = 32) {
    const cut = knockOutInk(src, 28);
    const box = contentBounds(cut);
    const cropped = cropCanvas(cut, box);
    const { canvas, ctx } = makeCanvas(size, size);
    const pad = 1;
    const max = size - pad * 2;
    const scale = Math.min(max / cropped.width, max / cropped.height);
    const dw = Math.max(1, Math.round(cropped.width * scale));
    const dh = Math.max(1, Math.round(cropped.height * scale));
    const dx = Math.floor((size - dw) / 2);
    const dy = Math.min(size - dh - pad, Math.max(pad, Math.floor((size - dh) / 2) + 1));
    ctx.imageSmoothingEnabled = false;
    ctx.drawImage(cropped, dx, dy, dw, dh);
    return knockOutInk(canvas, 30);
  }

  function modelUrl(id, frame) {
    return MODEL_URLS[`${id}-${frame}`] || `assets/hero/models/${id}-${frame}.png`;
  }

  async function loadUnitModelPack(id) {
    const [idle0, idle1, atk0, atk1] = await Promise.all([
      loadImage(modelUrl(id, "idle0")),
      loadImage(modelUrl(id, "idle1")),
      loadImage(modelUrl(id, "atk0")),
      loadImage(modelUrl(id, "atk1")),
    ]);
    if (!idle0 || !idle1 || !atk0 || !atk1) return null;
    return {
      idle: [normalizeModelFrame(idle0), normalizeModelFrame(idle1)],
      attack: [normalizeModelFrame(atk0), normalizeModelFrame(atk1)],
    };
  }

  async function loadMobModelPack(id) {
    const [w0, w1, w2, w3] = await Promise.all([
      loadImage(modelUrl(id, "walk0")),
      loadImage(modelUrl(id, "walk1")),
      loadImage(modelUrl(id, "walk2")),
      loadImage(modelUrl(id, "walk3")),
    ]);
    if (!w0 || !w1 || !w2 || !w3) return null;
    return {
      walk: [
        normalizeModelFrame(w0),
        normalizeModelFrame(w1),
        normalizeModelFrame(w2),
        normalizeModelFrame(w3),
      ],
    };
  }

  function installIntoSpiritSprites() {
    const SS = window.SpiritSprites;
    if (!SS) return;
    if (SS.units) {
      HERO_UNIT_IDS.forEach((id) => {
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
        loadUnitModelPack(id).then((pack) => {
          if (pack) mapUnitPacks[id] = pack;
        })
      );
    });

    HERO_MOB_IDS.forEach((id) => {
      jobs.push(
        loadImage(ASSET_URLS[`${id}-endgame`]).then((img) => {
          if (img) portraits[`mob:${id}`] = img;
        })
      );
      jobs.push(
        loadMobModelPack(id).then((pack) => {
          if (pack) mapMobPacks[id] = pack;
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
      const card = portraits[id];
      if (!card) return;
      unitPacks[id] = buildShopPack(card, UNIT_FX[id] || "#e8c56a");
    });

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
    unitPacks,
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
      return (mapUnitPacks[id] && mapUnitPacks[id].idle[0]) || null;
    },
    unitMapSprite(id) {
      return (mapUnitPacks[id] && mapUnitPacks[id].idle[0]) || null;
    },
    mobMapSprite(kind) {
      return (mapMobPacks[kind] && mapMobPacks[kind].walk[0]) || null;
    },
    unitFrame: mapUnitFrame,
    mapUnitFrame,
    mobFrame: mapMobFrame,
    mapMobFrame,
    shopFrame,
  };

  boot();
})();
