(() => {
  "use strict";

  // Hi-res character models. Any unit id or mob kind listed here is drawn
  // from its own full-resolution frames (tall, crisp, feet on the tile)
  // instead of the old 32px packs. Add art with tools/import-model.py —
  // it writes the PNGs and updates the block below.
  // h = height on the map in tiles.
  /* MANIFEST:BEGIN */
  const MANIFEST = {
    units: {},
    mobs: {},
  };
  /* MANIFEST:END */

  const units = Object.create(null);
  const mobs = Object.create(null);

  function load(src) {
    return new Promise((resolve) => {
      const img = new Image();
      img.decoding = "async";
      img.onload = () => resolve(img);
      img.onerror = () => resolve(null);
      img.src = src;
    });
  }

  async function loadPack(entry) {
    const pack = { h: entry.h || 1.5 };
    for (const key of ["idle", "atk", "walk"]) {
      const list = entry[key] || [];
      pack[key] = (await Promise.all(list.map(load))).filter(Boolean);
    }
    return pack.idle.length || pack.walk.length ? pack : null;
  }

  const waiters = [];
  let ready = false;
  (async () => {
    for (const [id, e] of Object.entries(MANIFEST.units)) {
      const p = await loadPack(e);
      if (p) units[id] = p;
    }
    for (const [id, e] of Object.entries(MANIFEST.mobs)) {
      const p = await loadPack(e);
      if (p) mobs[id] = p;
    }
    ready = true;
    waiters.splice(0).forEach((cb) => cb());
  })();

  // Returns { img, h, bob } or null.
  function unitFrame(id, unit, tick) {
    const p = units[id];
    if (!p) return null;
    if (unit && unit.attackAnim > 0 && p.atk.length) {
      const i = unit.attackAnim > 8 ? 0 : p.atk.length - 1;
      return { img: p.atk[i], h: p.h, bob: 0 };
    }
    const idle = p.idle.length ? p.idle : p.walk;
    const phase = ((tick + (unit ? unit.tx * 7 + unit.ty * 13 : 0)) >> 4) & 1;
    if (idle.length > 1) return { img: idle[phase], h: p.h, bob: 0 };
    // One idle frame: gentle breathing bob instead.
    return { img: idle[0], h: p.h, bob: phase ? -0.5 : 0 };
  }

  function mobFrame(kind, pathIndex) {
    const p = mobs[kind];
    if (!p) return null;
    const list = p.walk.length ? p.walk : p.idle;
    const i = Math.floor((pathIndex || 0) / 6) % list.length;
    return { img: list[i], h: p.h, bob: list.length > 1 ? 0 : (i & 1 ? -0.5 : 0) };
  }

  function shopFrame(id, tick) {
    const f = unitFrame(id, null, tick);
    return f ? f.img : null;
  }

  window.SpiritHiRes = {
    MANIFEST,
    has: (id) => !!units[id],
    hasMob: (kind) => !!mobs[kind],
    unitFrame,
    mobFrame,
    shopFrame,
    whenReady(cb) {
      if (ready) cb();
      else waiters.push(cb);
    },
  };
})();
