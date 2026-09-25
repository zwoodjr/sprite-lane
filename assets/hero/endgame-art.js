(() => {
  "use strict";

  // Endgame rendered art for My Hero (UI + in-map).
  // Board sprites are turned into short idle / attack / walk packs so shop +
  // maze show moving models instead of static face cards.
  // Paths listed explicitly so the offline builder can rewrite them to data URLs.
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

  const UNIT_FX = {
    sparkfist: "#5ee08a",
    blastcrown: "#ffe08a",
    bakugo: "#ff8a40",
    howitzer: "#ffb060",
    hoverbind: "#f0b0c8",
    zerofield: "#d0e8ff",
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
  const mapSprites = Object.create(null);
  const mobPortraits = Object.create(null);
  const unitPacks = Object.create(null);
  const mobPacks = Object.create(null);
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

  /** Bake a posed frame from a static board/portrait sprite. */
  function poseFrame(src, opts = {}) {
    const { w, h } = sourceSize(src);
    const { canvas, ctx } = makeCanvas(w, h);
    const dx = opts.dx || 0;
    const dy = opts.dy || 0;
    const scaleX = opts.scaleX == null ? 1 : opts.scaleX;
    const scaleY = opts.scaleY == null ? 1 : opts.scaleY;
    const nw = Math.max(1, Math.round(w * scaleX));
    const nh = Math.max(1, Math.round(h * scaleY));
    const ox = Math.round((w - nw) / 2) + dx;
    const oy = Math.round((h - nh) / 2) + dy;

    ctx.clearRect(0, 0, w, h);
    if (opts.mirror) {
      ctx.save();
      ctx.translate(w, 0);
      ctx.scale(-1, 1);
      ctx.drawImage(src, w - ox - nw, oy, nw, nh);
      ctx.restore();
    } else {
      ctx.drawImage(src, ox, oy, nw, nh);
    }

    if (opts.tint) {
      ctx.globalCompositeOperation = "source-atop";
      ctx.globalAlpha = opts.tintStrength == null ? 0.22 : opts.tintStrength;
      ctx.fillStyle = opts.tint;
      ctx.fillRect(0, 0, w, h);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
    }

    if (opts.flash) {
      ctx.globalCompositeOperation = "lighter";
      ctx.globalAlpha = opts.flashStrength == null ? 0.35 : opts.flashStrength;
      ctx.fillStyle = opts.flash;
      // Accent burst near fists / lower body so it reads as motion, not a flat wash.
      ctx.fillRect(2, Math.floor(h * 0.45), 4, 5);
      ctx.fillRect(w - 6, Math.floor(h * 0.45), 4, 5);
      ctx.fillRect(Math.floor(w / 2) - 2, Math.floor(h * 0.2), 4, 3);
      ctx.globalAlpha = 1;
      ctx.globalCompositeOperation = "source-over";
    }

    if (opts.liftShadow) {
      ctx.globalCompositeOperation = "destination-over";
      ctx.fillStyle = "rgba(0,0,0,0.35)";
      ctx.fillRect(Math.floor(w * 0.2), h - 2, Math.floor(w * 0.6), 2);
      ctx.globalCompositeOperation = "source-over";
    }

    return canvas;
  }

  function buildUnitPack(src, fx) {
    return {
      idle: [
        poseFrame(src, { liftShadow: true }),
        poseFrame(src, {
          dy: -2,
          scaleY: 1.04,
          tint: fx,
          tintStrength: 0.16,
          liftShadow: true,
        }),
      ],
      attack: [
        poseFrame(src, {
          dy: 2,
          scaleY: 0.82,
          scaleX: 1.06,
          tint: fx,
          tintStrength: 0.28,
          flash: fx,
          flashStrength: 0.5,
        }),
        poseFrame(src, {
          dy: -2,
          scaleX: 1.12,
          scaleY: 0.92,
          tint: "#fff6d0",
          tintStrength: 0.22,
          flash: fx,
          flashStrength: 0.7,
        }),
      ],
    };
  }

  function buildMobPack(src, fx) {
    return {
      walk: [
        poseFrame(src, { dy: 0, liftShadow: true }),
        poseFrame(src, {
          dy: -2,
          dx: 1,
          scaleY: 1.05,
          tint: fx,
          tintStrength: 0.14,
          liftShadow: true,
        }),
        poseFrame(src, { dy: 0, mirror: true, liftShadow: true }),
        poseFrame(src, {
          dy: -2,
          dx: -1,
          mirror: true,
          scaleY: 1.05,
          tint: fx,
          tintStrength: 0.14,
          liftShadow: true,
        }),
      ],
    };
  }

  /** Prefer board sprite; fall back to portrait so packs always exist when art loads. */
  function modelSource(id, board, portrait) {
    return board || portrait || null;
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
      const src = modelSource(id, mapSprites[id], portraits[id]);
      if (src) unitPacks[id] = buildUnitPack(src, UNIT_FX[id] || "#e8c56a");
    });
    HERO_MOB_IDS.forEach((id) => {
      const src = modelSource(id, mapSprites[`mob:${id}`], mobPortraits[id]);
      if (src) mobPacks[id] = buildMobPack(src, MOB_FX[id] || "#e8c56a");
    });

    ready = true;
    waiters.splice(0).forEach((cb) => {
      try {
        cb();
      } catch (_) {}
    });
  }

  function unitFrame(defId, unit, tick) {
    const pack = unitPacks[defId];
    if (!pack) return null;
    if (unit && unit.attackAnim && unit.attackAnim > 0) {
      const fi = unit.attackAnim > 8 ? 0 : 1;
      return pack.attack[fi];
    }
    const fi = (tick >> 3) & 1;
    return pack.idle[fi];
  }

  function mobFrame(kind, pathIndex) {
    const pack = mobPacks[kind];
    if (!pack || !pack.walk) return null;
    const fi = Math.floor(pathIndex / 5) % pack.walk.length;
    return pack.walk[fi];
  }

  function shopFrame(defId, tick) {
    const pack = unitPacks[defId];
    if (!pack) return null;
    const fi = (tick >> 3) & 1;
    return pack.idle[fi];
  }

  window.SpiritEndgameArt = {
    HERO_UNIT_IDS,
    HERO_MOB_IDS,
    portraits,
    mapSprites,
    mobPortraits,
    unitPacks,
    mobPacks,
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
        (unitPacks[id] && unitPacks[id].idle[0]) ||
        mapSprites[id] ||
        portraits[id] ||
        null
      );
    },
    unitMapSprite(id) {
      // Kept for callers; gameplay should prefer unitFrame().
      return mapSprites[id] || portraits[id] || null;
    },
    mobMapSprite(kind) {
      return mapSprites[`mob:${kind}`] || mobPortraits[kind] || null;
    },
    unitFrame,
    mobFrame,
    shopFrame,
  };

  boot();
})();
