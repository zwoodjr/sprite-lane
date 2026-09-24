(() => {
  "use strict";

  // Spirit Lane — original cast. Kits echo popular battle tropes only.
  // 24px tiles (50% over the old 16px). Fewer cols/rows keep the board clean.
  const TILE = 24;
  const COLS = 20;
  const ROWS = 11;
  const W = COLS * TILE; // 480
  const H = ROWS * TILE; // 264
  const PX = TILE / 16; // scale combat/draw sizes with the tile
  const SPAWN = { x: 0, y: 5 };
  const EXIT = { x: COLS - 1, y: 5 };

  const canvas = document.getElementById("game");
  const frameEl = document.getElementById("frame");
  const stageEl = document.getElementById("stage");
  if (!canvas) {
    throw new Error("Missing #game canvas — page markup failed to load.");
  }
  const ctx = canvas.getContext("2d", { alpha: false });
  if (!ctx) {
    throw new Error("Canvas 2D unavailable in this browser.");
  }
  ctx.imageSmoothingEnabled = false;

  // Size the 480×264 buffer to fill the stage (map-first layout).
  function fitDisplay() {
    if (!frameEl || !stageEl) return;
    const stageCss = stageEl.getBoundingClientRect();
    const hudDock = document.getElementById("hud-dock");
    const hudH = hudDock ? hudDock.getBoundingClientRect().height + 6 : 0;
    let maxW = Math.max(
      64,
      stageCss.width || stageEl.clientWidth || window.innerWidth * 0.95
    );
    let maxH = Math.max(
      64,
      (stageCss.height || stageEl.clientHeight || window.innerHeight * 0.9) - hudH
    );

    if (maxH < 80) {
      const vv = window.visualViewport;
      const viewH = (vv && vv.height) || window.innerHeight || 480;
      const pad =
        parseFloat(getComputedStyle(document.documentElement).fontSize) || 16;
      maxH = Math.max(120, viewH - pad * 1.5 - hudH);
    }
    if (maxW < 80) {
      maxW = Math.max(160, (window.innerWidth || 320) - 16);
    }

    const raw = Math.min(maxW / W, maxH / H);
    if (!(raw > 0) || !isFinite(raw)) return;

    let scale = raw;
    const floor = Math.floor(raw);
    if (floor >= 1) {
      scale = raw - floor < 0.08 ? floor : raw;
    }

    const cssW = Math.max(120, Math.floor(W * scale));
    const cssH = Math.max(66, Math.floor(H * scale));
    frameEl.style.width = cssW + "px";
    frameEl.style.height = cssH + "px";
    frameEl.style.aspectRatio = "auto";
    canvas.style.width = "100%";
    canvas.style.height = "100%";

    if (canvas.width !== W || canvas.height !== H) {
      canvas.width = W;
      canvas.height = H;
    }
    ctx.imageSmoothingEnabled = false;
  }

  function preferLandscape() {
    const orient = screen.orientation;
    if (orient && typeof orient.lock === "function") {
      orient.lock("landscape").catch(() => {});
    }
  }

  function isStandaloneApp() {
    return (
      window.matchMedia("(display-mode: standalone)").matches ||
      window.navigator.standalone === true
    );
  }

  function isBrowserFullscreen() {
    return !!(
      document.fullscreenElement ||
      document.webkitFullscreenElement ||
      document.msFullscreenElement
    );
  }

  function syncFullscreenUi() {
    const on = isBrowserFullscreen() || document.documentElement.classList.contains("is-fullscreen");
    document.documentElement.classList.toggle("is-fullscreen", on || isBrowserFullscreen());
    document.documentElement.classList.toggle("is-standalone", isStandaloneApp());
    const label = on ? "Exit" : "Full";
    const pressed = on ? "true" : "false";
    [el.btnFullscreen, el.btnFullscreenMenu].forEach((btn) => {
      if (!btn) return;
      btn.textContent = btn === el.btnFullscreenMenu
        ? on
          ? "Exit Full Screen"
          : "Full Screen"
        : label;
      btn.setAttribute("aria-pressed", pressed);
      btn.classList.toggle("is-active", on);
    });
  }

  async function enterFullscreen() {
    preferLandscape();
    const root = document.documentElement;
    try {
      if (root.requestFullscreen) await root.requestFullscreen();
      else if (root.webkitRequestFullscreen) root.webkitRequestFullscreen();
      else if (root.webkitRequestFullScreen) root.webkitRequestFullScreen();
      else throw new Error("no-fs-api");
      root.classList.add("is-fullscreen");
    } catch (err) {
      // iPhone Safari: no Fullscreen API — guide user to Home Screen.
      root.classList.add("is-fullscreen");
      if (isStandaloneApp()) {
        setHint("Already running as Home Screen app.");
      } else {
        setHint("iPhone: Share → Add to Home Screen for true fullscreen (no Safari bar).");
        openDrawer("menu");
      }
    }
    syncFullscreenUi();
    setTimeout(fitDisplay, 50);
    setTimeout(fitDisplay, 250);
  }

  async function exitFullscreen() {
    try {
      if (document.exitFullscreen) await document.exitFullscreen();
      else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
      else if (document.webkitCancelFullScreen) document.webkitCancelFullScreen();
    } catch (_) {
      /* ignore */
    }
    document.documentElement.classList.remove("is-fullscreen");
    syncFullscreenUi();
    setTimeout(fitDisplay, 50);
    setTimeout(fitDisplay, 250);
  }

  async function toggleFullscreen() {
    ensureAudio();
    if (isBrowserFullscreen() || document.documentElement.classList.contains("is-fullscreen")) {
      // If only CSS class (iOS fallback), toggle off; else exit browser FS.
      if (!isBrowserFullscreen() && document.documentElement.classList.contains("is-fullscreen")) {
        document.documentElement.classList.remove("is-fullscreen");
        syncFullscreenUi();
        setTimeout(fitDisplay, 50);
        return;
      }
      await exitFullscreen();
    } else {
      await enterFullscreen();
    }
  }

  const el = {
    gold: document.getElementById("gold"),
    lives: document.getElementById("lives"),
    wave: document.getElementById("wave"),
    income: document.getElementById("income"),
    shop: document.getElementById("shop"),
    preview: document.getElementById("sprite-preview"),
    hint: document.getElementById("hint"),
    ready: document.getElementById("btn-ready"),
    sell: document.getElementById("btn-sell"),
    upgrade: document.getElementById("btn-upgrade"),
    mapSelect: document.getElementById("map-select"),
    mapRandom: document.getElementById("btn-map-random"),
    mapLabel: document.getElementById("map-label"),
    saveOffline: document.getElementById("btn-save-offline"),
    offlineTip: document.getElementById("offline-tip"),
    spiritPoints: document.getElementById("spirit-points"),
    shopSpirit: document.getElementById("shop-spirit"),
    metaBest: document.getElementById("meta-best"),
    metaStore: document.getElementById("meta-store"),
    newRun: document.getElementById("btn-new-run"),
    unitSelected: document.getElementById("unit-selected"),
    drawerShop: document.getElementById("drawer-shop"),
    drawerUnit: document.getElementById("drawer-unit"),
    drawerMenu: document.getElementById("drawer-menu"),
    drawerBackdrop: document.getElementById("drawer-backdrop"),
    btnDrawerShop: document.getElementById("btn-drawer-shop"),
    btnDrawerUnit: document.getElementById("btn-drawer-unit"),
    btnDrawerMenu: document.getElementById("btn-drawer-menu"),
    btnCloseShop: document.getElementById("btn-close-shop"),
    btnCloseUnit: document.getElementById("btn-close-unit"),
    btnCloseMenu: document.getElementById("btn-close-menu"),
    btnFullscreen: document.getElementById("btn-fullscreen"),
    btnFullscreenMenu: document.getElementById("btn-fullscreen-menu"),
  };

  // --- Meta progression (local Spirit Points store) ---
  const META_KEY = "spirit-lane-meta-v1";
  const META_UPGRADES = [
    {
      id: "startingGold",
      name: "Starting Gold",
      desc: "+25 gold at run start",
      max: 5,
      costs: [12, 20, 32, 48, 70],
      perLevel: 25,
    },
    {
      id: "attackSpeed",
      name: "Attack Speed",
      desc: "Towers fire 6% faster / lvl",
      max: 5,
      costs: [15, 24, 36, 54, 80],
      perLevel: 0.06,
    },
    {
      id: "unitDiscount",
      name: "Unit Discount",
      desc: "Units & tower upgrades 4% cheaper / lvl",
      max: 5,
      costs: [15, 24, 36, 54, 80],
      perLevel: 0.04,
    },
    {
      id: "critChance",
      name: "Crit Chance",
      desc: "+5% crit (2× damage) / lvl",
      max: 5,
      costs: [18, 28, 42, 60, 90],
      perLevel: 0.05,
    },
    {
      id: "startingLives",
      name: "Extra Lives",
      desc: "+1 life at run start / lvl",
      max: 5,
      costs: [14, 22, 34, 50, 72],
      perLevel: 1,
    },
    {
      id: "incomeBoost",
      name: "Income Boost",
      desc: "+2 starting income / lvl",
      max: 5,
      costs: [12, 20, 32, 48, 70],
      perLevel: 2,
    },
  ];
  const META_BY_ID = Object.fromEntries(META_UPGRADES.map((u) => [u.id, u]));

  function defaultMeta() {
    return {
      points: 0,
      lifetime: 0,
      bestWave: 0,
      runs: 0,
      levels: {
        startingGold: 0,
        attackSpeed: 0,
        unitDiscount: 0,
        critChance: 0,
        startingLives: 0,
        incomeBoost: 0,
      },
    };
  }

  function loadMeta() {
    try {
      const raw = localStorage.getItem(META_KEY);
      if (!raw) return defaultMeta();
      const parsed = JSON.parse(raw);
      const base = defaultMeta();
      const levels = { ...base.levels, ...(parsed.levels || {}) };
      META_UPGRADES.forEach((u) => {
        levels[u.id] = Math.max(0, Math.min(u.max, levels[u.id] | 0));
      });
      return {
        points: Math.max(0, parsed.points | 0),
        lifetime: Math.max(0, parsed.lifetime | 0),
        bestWave: Math.max(0, parsed.bestWave | 0),
        runs: Math.max(0, parsed.runs | 0),
        levels,
      };
    } catch (_) {
      return defaultMeta();
    }
  }

  function saveMeta() {
    try {
      localStorage.setItem(META_KEY, JSON.stringify(meta));
    } catch (_) {
      /* private mode / quota */
    }
  }

  const meta = loadMeta();

  function metaLevel(id) {
    return meta.levels[id] | 0;
  }

  function metaBonus(id) {
    const def = META_BY_ID[id];
    if (!def) return 0;
    return metaLevel(id) * def.perLevel;
  }

  function nextMetaCost(id) {
    const def = META_BY_ID[id];
    const lvl = metaLevel(id);
    if (!def || lvl >= def.max) return null;
    return def.costs[lvl];
  }

  function baseStartingGold() {
    return 150 + metaBonus("startingGold");
  }

  function baseStartingLives() {
    return 20 + metaBonus("startingLives");
  }

  function baseStartingIncome() {
    return 12 + metaBonus("incomeBoost");
  }

  function unitCost(def) {
    if (!def) return 9999;
    const disc = Math.min(0.35, metaBonus("unitDiscount"));
    return Math.max(1, Math.floor(def.cost * (1 - disc)));
  }

  function fireCooldown(def) {
    const speed = Math.min(0.4, metaBonus("attackSpeed"));
    return Math.max(4, Math.floor((def.rate || 30) * (1 - speed)));
  }

  function rollCrit() {
    return Math.random() < Math.min(0.5, metaBonus("critChance"));
  }

  function spiritForWave(wave, leaks) {
    const base = 10 + Math.max(1, wave | 0) * 2;
    const mult = Math.max(0, 1 - 0.1 * Math.max(0, leaks | 0));
    return Math.max(0, Math.floor(base * mult));
  }

  function awardWaveSpirit(wave, leaks) {
    const gained = spiritForWave(wave, leaks);
    if (gained > 0) {
      meta.points += gained;
      meta.lifetime += gained;
      saveMeta();
      updateMetaHud();
      renderMetaStore();
    }
    return gained;
  }

  function updateMetaHud() {
    const label = `SP ${meta.points}`;
    if (el.spiritPoints) el.spiritPoints.textContent = label;
    if (el.shopSpirit) el.shopSpirit.textContent = `Spirit ${meta.points}`;
    if (el.metaBest) el.metaBest.textContent = `Best W${meta.bestWave}`;
  }

  function renderMetaStore() {
    if (!el.metaStore) return;
    el.metaStore.innerHTML = "";
    META_UPGRADES.forEach((def) => {
      const lvl = metaLevel(def.id);
      const cost = nextMetaCost(def.id);
      const maxed = cost == null;
      const canBuy = !maxed && meta.points >= cost;
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "meta-card";
      btn.disabled = maxed || !canBuy;
      btn.innerHTML =
        `<span class="name">${def.name}</span>` +
        `<span class="desc">${def.desc}</span>` +
        `<span class="lvl">Lv ${lvl}/${def.max}</span>` +
        `<span class="buy">${maxed ? "MAX" : cost + " SP"}</span>`;
      btn.addEventListener("click", () => buyMetaUpgrade(def.id));
      el.metaStore.appendChild(btn);
    });
    updateMetaHud();
  }

  function buyMetaUpgrade(id) {
    const cost = nextMetaCost(id);
    if (cost == null) return;
    if (meta.points < cost) {
      setHint("Need more Spirit — clear waves cleanly to earn SP.");
      beep(120, 0.08, "sawtooth");
      return;
    }
    meta.points -= cost;
    meta.levels[id] = metaLevel(id) + 1;
    saveMeta();
    renderMetaStore();
    renderShop();
    updateHud();
    beep(740, 0.05);
    const def = META_BY_ID[id];
    setHint(`Shop boosted: ${def.name} Lv ${metaLevel(id)}.`);
    // Apply soft bonuses that don't require a new run when still in early build.
    if (state.mode === "build" && state.wave === 0 && state.units.length === 0) {
      state.gold = baseStartingGold();
      state.lives = baseStartingLives();
      state.income = baseStartingIncome();
      updateHud();
    }
  }

  function setDrawerOpen(drawer, open) {
    if (!drawer) return;
    if (open) {
      drawer.hidden = false;
      drawer.setAttribute("aria-hidden", "false");
      // Force reflow so the slide-in transition plays.
      void drawer.offsetWidth;
      drawer.classList.add("is-open");
    } else {
      drawer.classList.remove("is-open");
      drawer.setAttribute("aria-hidden", "true");
      const finish = () => {
        if (!drawer.classList.contains("is-open")) drawer.hidden = true;
      };
      drawer.addEventListener("transitionend", finish, { once: true });
      setTimeout(finish, 280);
    }
  }

  function setBackdropOpen(open) {
    if (!el.drawerBackdrop) return;
    if (open) {
      el.drawerBackdrop.hidden = false;
      void el.drawerBackdrop.offsetWidth;
      el.drawerBackdrop.classList.add("is-open");
    } else {
      el.drawerBackdrop.classList.remove("is-open");
      const finish = () => {
        if (!el.drawerBackdrop.classList.contains("is-open")) {
          el.drawerBackdrop.hidden = true;
        }
      };
      el.drawerBackdrop.addEventListener("transitionend", finish, { once: true });
      setTimeout(finish, 240);
    }
  }

  function syncEdgeTabs(which) {
    const tabs = [
      [el.btnDrawerShop, "shop"],
      [el.btnDrawerUnit, "unit"],
      [el.btnDrawerMenu, "menu"],
    ];
    tabs.forEach(([btn, key]) => {
      if (!btn) return;
      const on = which === key;
      btn.classList.toggle("is-open", on);
      btn.setAttribute("aria-expanded", on ? "true" : "false");
      const arrow = btn.querySelector(".edge-arrow");
      if (arrow) arrow.textContent = on ? "▸" : "◂";
    });
  }

  function closeDrawers() {
    setDrawerOpen(el.drawerShop, false);
    setDrawerOpen(el.drawerUnit, false);
    setDrawerOpen(el.drawerMenu, false);
    setBackdropOpen(false);
    syncEdgeTabs(null);
  }

  function openDrawer(which) {
    const shop = which === "shop";
    const unit = which === "unit";
    const menu = which === "menu";
    const shopOpen = el.drawerShop && !el.drawerShop.hidden && el.drawerShop.classList.contains("is-open");
    const unitOpen = el.drawerUnit && !el.drawerUnit.hidden && el.drawerUnit.classList.contains("is-open");
    const menuOpen = el.drawerMenu && !el.drawerMenu.hidden && el.drawerMenu.classList.contains("is-open");
    if ((shop && shopOpen) || (unit && unitOpen) || (menu && menuOpen)) {
      closeDrawers();
      return;
    }
    setDrawerOpen(el.drawerShop, shop);
    setDrawerOpen(el.drawerUnit, unit);
    setDrawerOpen(el.drawerMenu, menu);
    setBackdropOpen(shop || unit || menu);
    syncEdgeTabs(shop ? "shop" : unit ? "unit" : menu ? "menu" : null);
    if (unit) {
      renderShop();
      updateUnitDrawerLabel();
    }
    if (shop) {
      renderMetaStore();
      updateMetaHud();
    }
  }

  function updateUnitDrawerLabel() {
    if (!el.unitSelected) return;
    const u = state.selectedUnit;
    if (!u) {
      el.unitSelected.textContent =
        "Pick a unit below (gold), then tap grass — or tap a placed unit to upgrade.";
      return;
    }
    const def = UNIT_MAP[u.type];
    if (!def) {
      el.unitSelected.textContent = "Unit selected.";
      return;
    }
    const star = unitStar(u);
    if (def.next) {
      const next = UNIT_MAP[def.next];
      const cost = next ? unitCost(next) : 0;
      el.unitSelected.textContent = `${def.name} ★${star}. Evolve → ${next.name} for ${cost}g, then keep leveling with gold.`;
    } else if (star < MAX_UNIT_STAR) {
      el.unitSelected.textContent = `${def.name} ★${star}/${MAX_UNIT_STAR}. Next level ${starUpgradeCost(u)}g.`;
    } else {
      el.unitSelected.textContent = `${def.name} ★${star} (max). Sell for gold refund.`;
    }
  }

  // Back-compat alias used by older boot paths / exports.
  function showRailPanel(which) {
    if (which === "store") openDrawer("shop");
    else if (which === "unit" || which === "towers") openDrawer("unit");
    else if (which === "shop") openDrawer("shop");
    else if (which === "menu") openDrawer("menu");
    else closeDrawers();
  }

  function settleRun(won) {
    if (state.runSettled) return;
    state.runSettled = true;
    meta.runs += 1;
    meta.bestWave = Math.max(meta.bestWave, state.wave);
    saveMeta();
    updateMetaHud();
    renderMetaStore();
    if (el.newRun) el.newRun.hidden = false;
    el.ready.disabled = true;
    setHint(
      won
        ? `Victory! Spirit already banked each wave. Open Shop for Spirit boosts, or Reset.`
        : `Lane broke after wave ${state.wave}. Open Shop to spend Spirit, or Reset.`
    );
    openDrawer("shop");
  }

  const SS = window.SpiritSprites || null;
  const EA = window.SpiritEndgameArt || null;
  const MOB_KINDS = (SS && SS.MOB_KINDS) || [
    "quirling",
    "multifist",
    "floatdrone",
    "sparkgrub",
    "ashfiend",
    "shardbrute",
    "hexwisp",
    "gatehound",
  ];
  const HERO_MOB_KINDS = (SS && SS.HERO_MOB_KINDS) || [
    "quirling",
    "multifist",
    "floatdrone",
    "sparkgrub",
  ];
  const SERIES_MOBS = {
    "Lane Works": ["quirling", "ashfiend", "shardbrute", "hexwisp", "gatehound"],
    "My Hero": HERO_MOB_KINDS,
    "Demon Slayer": ["ashfiend", "shardbrute", "gatehound"],
    "Attack on Titan": ["shardbrute", "ashfiend", "gatehound"],
    "Jujutsu Kaisen": ["hexwisp", "ashfiend", "gatehound"],
    "Solo Leveling": ["gatehound", "hexwisp", "shardbrute"],
  };

  // --- Audio ---
  let audioCtx = null;
  function ensureAudio() {
    if (!audioCtx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (AC) audioCtx = new AC();
    }
    if (audioCtx?.state === "suspended") audioCtx.resume();
  }
  function beep(freq, dur = 0.06, type = "square", vol = 0.04) {
    if (!audioCtx) return;
    const t = audioCtx.currentTime;
    const o = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    o.type = type;
    o.frequency.value = freq;
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g);
    g.connect(audioCtx.destination);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  // --- Pixel helpers ---
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

  function packSprite(id, fallbackRows) {
    if (SS && SS.units && SS.units[id] && SS.units[id].idle && SS.units[id].idle[0]) {
      return SS.units[id].idle[0];
    }
    return bake(fallbackRows);
  }

  // --- Unit definitions (fan cast keyed to series maps) ---
  const UNITS = [
    {
      id: "palewall",
      name: "Palewall",
      next: null,
      series: "Lane Works",
      blurb: "Cheap maze block",
      cost: 12,
      range: 0,
      rate: 9999,
      damage: 0,
      animated: false,
      color: "#5a4a3a",
      sprite: bake([
        "000aaaaaa0000000",
        "00a777777a000000",
        "0a7aa7a7a7a00000",
        "0a77777777a00000",
        "0a7a7aa7a7a00000",
        "0a77777777a00000",
        "0a7aa7a7a7a00000",
        "0a77777777a00000",
        "00a7aaaa7a000000",
        "000aaaaaa0000000",
        "000a3333a0000000",
        "000a3003a0000000",
        "000a3333a0000000",
        "000aaaaaa0000000",
        "00aa0000aa000000",
        "0000000000000000",
      ]),
    },
    // —— My Hero ——
    {
      id: "sparkfist",
      name: "Dark Deku",
      next: "blastcrown",
      series: "My Hero",
      blurb: "Close smash bursts",
      cost: 40,
      range: 48,
      rate: 42,
      damage: 18,
      aoe: 22,
      animated: true,
      color: "#2a8a48",
      sprite: packSprite("sparkfist", [
        "000uu000","00uwwu00","0u7777u0","0tuuuut0","0kzuuzk0","00zzzz00","003zz300","00u00u00",
      ]),
    },
    {
      id: "blastcrown",
      name: "Full Cowl",
      next: null,
      series: "My Hero",
      blurb: "Wider smash detonation",
      cost: 90,
      range: 56,
      rate: 36,
      damage: 34,
      aoe: 34,
      animated: true,
      color: "#3db868",
      sprite: packSprite("blastcrown", [
        "00uuuu00","0uwwwwu0","uw7777wu","utuuuutu","wu0uu0uw","03333330","03t00t30","0w0000w0",
      ]),
    },
    {
      id: "bakugo",
      name: "Bakugo",
      next: "howitzer",
      series: "My Hero",
      blurb: "Explosion pops",
      cost: 48,
      range: 44,
      rate: 34,
      damage: 22,
      aoe: 30,
      animated: true,
      color: "#e85d3c",
      sprite: packSprite("bakugo", [
        "00555500","05577550","0zyyyyz0","eyyyyyye","0ezzze0","03333330","03z00z30","0y0000y0",
      ]),
    },
    {
      id: "howitzer",
      name: "Howitzer",
      next: null,
      series: "My Hero",
      blurb: "Gauntlet howitzer blasts",
      cost: 100,
      range: 52,
      rate: 28,
      damage: 40,
      aoe: 42,
      animated: true,
      color: "#ff7040",
      sprite: packSprite("howitzer", [
        "055w5500","55777550","zyyyyyyz","weyyyyew","wezzzzewe","03333330","03z00z30","0y0w0y00",
      ]),
    },
    {
      id: "hoverbind",
      name: "Uravity",
      next: "zerofield",
      series: "My Hero",
      blurb: "Gravity slow field",
      cost: 35,
      range: 54,
      rate: 50,
      damage: 6,
      slow: 0.45,
      animated: true,
      color: "#f0a0c0",
      sprite: packSprite("hoverbind", [
        "00vvvv00","0v7777v0","0vccccv0","0vvvvvv0","0v0000v0","0ffffff0","0v0000v0","09000090",
      ]),
    },
    {
      id: "zerofield",
      name: "Zero Gravity",
      next: null,
      series: "My Hero",
      blurb: "Heavy float lock",
      cost: 80,
      range: 64,
      rate: 40,
      damage: 10,
      slow: 0.65,
      animated: true,
      color: "#d070a0",
      sprite: packSprite("zerofield", [
        "0vvvvvv0","vccccccv","vc7777cv","vvvvvvvv","cv7777vc","0ffffff0","0c0000c0","0v0000v0",
      ]),
    },
    {
      id: "todoroki",
      name: "Todoroki",
      next: "halfcold",
      series: "My Hero",
      blurb: "Ice slow + fire hit",
      cost: 55,
      range: 58,
      rate: 36,
      damage: 16,
      slow: 0.35,
      aoe: 20,
      animated: true,
      color: "#70b0e0",
      sprite: packSprite("todoroki", [
        "00x55500","0xx775y0","0x7777y0","xx7777yy","0x0000y0","0ffffff0","0x0000y0","0c0000e0",
      ]),
    },
    {
      id: "halfcold",
      name: "Half-Cold",
      next: null,
      series: "My Hero",
      blurb: "Full dual ice / fire field",
      cost: 110,
      range: 68,
      rate: 30,
      damage: 28,
      slow: 0.5,
      aoe: 32,
      animated: true,
      color: "#90c8e8",
      sprite: packSprite("halfcold", [
        "0xxx55y0","xx7775yy","x777777y","xxx777yyy","cx0000ye","0ffffff0","0x0000y0","0cxxxxe0",
      ]),
    },
    // —— Demon Slayer ——
    {
      id: "tideblade",
      name: "Tanjiro",
      next: "torrentfang",
      series: "Demon Slayer",
      blurb: "Water cleave along path",
      cost: 45,
      range: 52,
      rate: 38,
      damage: 16,
      cleave: true,
      animated: true,
      color: "#3db8a0",
      sprite: packSprite("tideblade", [
        "00006000","00066000","0066c600","06677760","006aa600","00a77a00","0a0000a0","a000000a",
      ]),
    },
    {
      id: "torrentfang",
      name: "Hinokami",
      next: null,
      series: "Demon Slayer",
      blurb: "Wide water cleave",
      cost: 95,
      range: 60,
      rate: 32,
      damage: 28,
      cleave: true,
      animated: true,
      color: "#6ee0c8",
      sprite: packSprite("torrentfang", [
        "0006c600","006ccc60","06c77c60","6c7777c6","06cccc60","00aaaa00","0a0aa0a0","a000000a",
      ]),
    },
    {
      id: "nezuko",
      name: "Nezuko",
      next: null,
      series: "Demon Slayer",
      blurb: "Blood burst AOE",
      cost: 42,
      range: 40,
      rate: 44,
      damage: 20,
      aoe: 32,
      animated: true,
      color: "#e07090",
      sprite: packSprite("nezuko", [
        "00088000","00877800","08777780","87777778","087aa780","00a00a00","0a0000a0","80000008",
      ]),
    },
    {
      id: "inosuke",
      name: "Inosuke",
      next: null,
      series: "Demon Slayer",
      blurb: "Beast smash aura",
      cost: 50,
      range: 36,
      rate: 30,
      damage: 18,
      aoe: 26,
      animated: true,
      color: "#a09070",
      sprite: packSprite("inosuke", [
        "00333300","03aaaa30","3a7777a3","a777777a","3a3333a3","03dddd30","0d0000d0","d000000d",
      ]),
    },
    {
      id: "flashstep",
      name: "Zenitsu",
      next: "thunderpierce",
      series: "Demon Slayer",
      blurb: "Lightning snipe",
      cost: 50,
      range: 72,
      rate: 55,
      damage: 40,
      animated: true,
      color: "#e8c56a",
      sprite: packSprite("flashstep", [
        "00044000","004ee400","04e77e40","4e7777e4","04e44e40","004aa400","00a00a00","0a0000a0",
      ]),
    },
    {
      id: "thunderpierce",
      name: "God Speed",
      next: null,
      series: "Demon Slayer",
      blurb: "Brutal bolt strike",
      cost: 110,
      range: 80,
      rate: 48,
      damage: 70,
      animated: true,
      color: "#ffe08a",
      sprite: packSprite("thunderpierce", [
        "004ee400","04eeee40","4e7777e4","e777777e","4e4444e4","04aaaa40","0a0aa0a0","a000000a",
      ]),
    },
    // —— Attack on Titan ——
    {
      id: "shellbrute",
      name: "Eren",
      next: "colossus",
      series: "Attack on Titan",
      blurb: "Titan smash aura",
      cost: 55,
      range: 36,
      rate: 48,
      damage: 14,
      aoe: 28,
      animated: true,
      color: "#9a8770",
      sprite: packSprite("shellbrute", [
        "00333300","03aaaa30","3a7777a3","a777777a","3a3333a3","03dddd30","0d0000d0","d000000d",
      ]),
    },
    {
      id: "colossus",
      name: "Attack Titan",
      next: null,
      series: "Attack on Titan",
      blurb: "Crushing presence",
      cost: 120,
      range: 42,
      rate: 40,
      damage: 26,
      aoe: 36,
      animated: true,
      color: "#c0a888",
      sprite: packSprite("colossus", [
        "03333330","3aaaaaa3","a777777a","a777777a","3a3333a3","03dddd30","0dd00dd0","d000000d",
      ]),
    },
    {
      id: "wirehook",
      name: "Mikasa",
      next: "skydancer",
      series: "Attack on Titan",
      blurb: "ODM priority cuts",
      cost: 48,
      range: 64,
      rate: 22,
      damage: 10,
      prioritize: "strongest",
      animated: true,
      color: "#c0c8d0",
      sprite: packSprite("wirehook", [
        "000c0c00","00c77c00","0c7777c0","c777777c","0c7aa7c0","00a00a00","0a0000a0","c000000c",
      ]),
    },
    {
      id: "skydancer",
      name: "Ackerman",
      next: null,
      series: "Attack on Titan",
      blurb: "Blinding blade work",
      cost: 105,
      range: 70,
      rate: 14,
      damage: 14,
      prioritize: "strongest",
      animated: true,
      color: "#e6dcc8",
      sprite: packSprite("skydancer", [
        "0c0c0c0c","0c7777c0","c777777c","c777777c","0c7aa7c0","00aaaa00","0a0aa0a0","c000000c",
      ]),
    },
    {
      id: "levi",
      name: "Levi",
      next: null,
      series: "Attack on Titan",
      blurb: "Fastest blade flurry",
      cost: 62,
      range: 58,
      rate: 12,
      damage: 14,
      prioritize: "strongest",
      animated: true,
      color: "#9aa8b8",
      sprite: packSprite("levi", [
        "000c0c00","00c77c00","0c7777c0","c777777c","0c7aa7c0","00a00a00","0a0000a0","c000000c",
      ]),
    },
    {
      id: "armin",
      name: "Armin",
      next: null,
      series: "Attack on Titan",
      blurb: "Tactical pulse zone",
      cost: 52,
      range: 60,
      rate: 55,
      damage: 11,
      aoe: 48,
      pulse: true,
      animated: true,
      color: "#e8d090",
      sprite: packSprite("armin", [
        "00060600","006cc600","06c77c60","6c7777c6","06c66c60","00677600","06000060","60000006",
      ]),
    },
    // —— Jujutsu Kaisen ——
    {
      id: "veinfist",
      name: "Yuji",
      next: "blackspar",
      series: "Jujutsu Kaisen",
      blurb: "Divergent fist DPS",
      cost: 42,
      range: 40,
      rate: 28,
      damage: 22,
      animated: true,
      color: "#d64545",
      sprite: packSprite("veinfist", [
        "00088000","00877800","08777780","87777778","087aa780","00a00a00","0a0000a0","80000008",
      ]),
    },
    {
      id: "blackspar",
      name: "Black Flash",
      next: null,
      series: "Jujutsu Kaisen",
      blurb: "Devastating punches",
      cost: 100,
      range: 44,
      rate: 20,
      damage: 38,
      animated: true,
      color: "#ff6060",
      sprite: packSprite("blackspar", [
        "00877800","08777780","87777778","87777778","087aa780","00aaaa00","0a0aa0a0","80000008",
      ]),
    },
    {
      id: "sukuna",
      name: "Sukuna",
      next: null,
      series: "Jujutsu Kaisen",
      blurb: "Dismantle cleave",
      cost: 70,
      range: 56,
      rate: 32,
      damage: 24,
      cleave: true,
      animated: true,
      color: "#c04040",
      sprite: packSprite("sukuna", [
        "00006000","00066000","0066c600","06677760","006aa600","00a77a00","0a0000a0","a000000a",
      ]),
    },
    {
      id: "markzone",
      name: "Gojo",
      next: "innerdomain",
      series: "Jujutsu Kaisen",
      blurb: "Infinity pulse zone",
      cost: 60,
      range: 58,
      rate: 60,
      damage: 12,
      aoe: 50,
      pulse: true,
      animated: true,
      color: "#90d0e8",
      sprite: packSprite("markzone", [
        "00060600","006cc600","06c77c60","6c7777c6","06c66c60","00677600","06000060","60000006",
      ]),
    },
    {
      id: "innerdomain",
      name: "Unlimited Void",
      next: null,
      series: "Jujutsu Kaisen",
      blurb: "Huge domain pulse",
      cost: 140,
      range: 70,
      rate: 50,
      damage: 22,
      aoe: 64,
      pulse: true,
      animated: true,
      color: "#b8f0ff",
      sprite: packSprite("innerdomain", [
        "006cc600","06cccc60","6c7777c6","6c7777c6","06c66c60","00cccc00","060cc060","60000006",
      ]),
    },
    {
      id: "megumi",
      name: "Megumi",
      next: null,
      series: "Jujutsu Kaisen",
      blurb: "Shikigami on kills",
      cost: 58,
      range: 52,
      rate: 40,
      damage: 12,
      raiseOnKill: true,
      maxShadows: 2,
      shadowLife: 90,
      shadowDamage: 8,
      animated: true,
      color: "#405878",
      sprite: packSprite("megumi", [
        "000f0f00","00f99f00","0f9779f0","f977779f","0f9ff9f0","00f77f00","0f0000f0","90000009",
      ]),
    },
    // —— Solo Leveling ——
    {
      id: "shadeknife",
      name: "Jin-Woo",
      next: "monarchedge",
      series: "Solo Leveling",
      blurb: "Dagger finisher",
      cost: 52,
      range: 50,
      rate: 16,
      damage: 12,
      prioritize: "weakest",
      execute: 0.2,
      color: "#6a8aaa",
      animated: true,
      sprite: packSprite("shadeknife", [
        "0000f000","000fcf00","00fc7cf0","0fc777cf","00fcaff0","000aa000","00a00a00","0f0000f0",
      ]),
    },
    {
      id: "monarchedge",
      name: "Monarch",
      next: null,
      series: "Solo Leveling",
      blurb: "Executes wounded prey",
      cost: 115,
      range: 56,
      rate: 11,
      damage: 18,
      prioritize: "weakest",
      execute: 0.35,
      color: "#9ab8d0",
      animated: true,
      sprite: packSprite("monarchedge", [
        "000fcf00","00fcccf0","0fc777cf","fc77777c","0fcffcf0","00aaaa00","0a0aa0a0","f000000f",
      ]),
    },
    {
      id: "gravemark",
      name: "Shadow Army",
      next: "shadowhost",
      series: "Solo Leveling",
      blurb: "Kills raise shadows",
      cost: 58,
      range: 54,
      rate: 44,
      damage: 10,
      raiseOnKill: true,
      maxShadows: 2,
      shadowLife: 100,
      shadowDamage: 7,
      animated: true,
      color: "#4a5a6a",
      sprite: packSprite("gravemark", [
        "000f0f00","00f99f00","0f9779f0","f977779f","0f9ff9f0","00f77f00","0f0000f0","90000009",
      ]),
    },
    {
      id: "shadowhost",
      name: "Shadow Host",
      next: null,
      series: "Solo Leveling",
      blurb: "Larger shadow army",
      cost: 130,
      range: 62,
      rate: 36,
      damage: 16,
      raiseOnKill: true,
      maxShadows: 4,
      shadowLife: 140,
      shadowDamage: 12,
      animated: true,
      color: "#7a90a8",
      sprite: packSprite("shadowhost", [
        "00f99f00","0f9999f0","f977779f","f977779f","0f9ff9f0","00ffff00","0f0ff0f0","90000009",
      ]),
    },
    {
      id: "cha",
      name: "Cha Hae-In",
      next: null,
      series: "Solo Leveling",
      blurb: "Sword flurry DPS",
      cost: 54,
      range: 56,
      rate: 18,
      damage: 15,
      prioritize: "strongest",
      animated: true,
      color: "#d0c090",
      sprite: packSprite("cha", [
        "000c0c00","00c77c00","0c7777c0","c777777c","0c7aa7c0","00a00a00","0a0000a0","c000000c",
      ]),
    },
    {
      id: "beru",
      name: "Beru",
      next: null,
      series: "Solo Leveling",
      blurb: "Ant king smash",
      cost: 65,
      range: 40,
      rate: 26,
      damage: 26,
      aoe: 30,
      animated: true,
      color: "#50a060",
      sprite: packSprite("beru", [
        "00333300","03aaaa30","3a7777a3","a777777a","3a3333a3","03dddd30","0d0000d0","d000000d",
      ]),
    },
  ];

  const UNIT_MAP = Object.fromEntries(UNITS.map((u) => [u.id, u]));
  const SHOP_IDS = [
    "palewall",
    "sparkfist", "bakugo", "hoverbind", "todoroki",
    "tideblade", "nezuko", "inosuke", "flashstep",
    "shellbrute", "wirehook", "levi", "armin",
    "veinfist", "sukuna", "markzone", "megumi",
    "shadeknife", "gravemark", "cha", "beru",
  ];
  const MAX_UNIT_STAR = 5;

  function unitStar(u) {
    if (!u) return 1;
    return Math.max(1, Math.min(MAX_UNIT_STAR, u.star | 1));
  }

  function starUpgradeCost(u) {
    const def = UNIT_MAP[u.type];
    if (!def) return Infinity;
    const star = unitStar(u);
    return Math.floor(unitCost(def) * (0.7 + star * 0.55));
  }

  function canGoldUpgrade(u) {
    if (!u) return false;
    const def = UNIT_MAP[u.type];
    if (!def) return false;
    if (def.next) return true;
    return unitStar(u) < MAX_UNIT_STAR;
  }

  function goldUpgradeCost(u) {
    if (!u) return Infinity;
    const def = UNIT_MAP[u.type];
    if (!def) return Infinity;
    if (def.next) return unitCost(UNIT_MAP[def.next]);
    return starUpgradeCost(u);
  }

  function scaledDamage(def, u) {
    const base = def.damage || 0;
    if (!base) return 0;
    const star = unitStar(u);
    return Math.max(1, Math.floor(base * (1 + (star - 1) * 0.3)));
  }

  function scaledRange(def, u) {
    const base = def.range || 0;
    if (!base) return 0;
    const star = unitStar(u);
    return base * (1 + (star - 1) * 0.08);
  }

  // Tile types: 0 grass (buildable), 3 rock, 4 spawn, 5 exit
  // One layout per cast series (+ lane works). Mid row stays a clear corridor.
  const MAPS = [
    {
      id: "lane-works",
      name: "Lane Works",
      series: "Lane Works",
      blurb: "Crate yard — stacked boxes to learn the maze",
      grassA: "#2c4030",
      grassB: "#243628",
      rock: "#7a5a3a",
      rockDeep: "#2a2018",
      rockHi: "#c0a070",
      accent: "#e8c56a",
      style: "crates",
      rocks: [
        [4, 2], [5, 2], [10, 2], [14, 2],
        [3, 3], [8, 3], [12, 3], [16, 3],
        [6, 4], [13, 4],
        [4, 6], [9, 6], [14, 6],
        [6, 7], [11, 7], [15, 7],
        [3, 8], [8, 8], [13, 8], [16, 8],
      ],
    },
    {
      id: "hero-crest",
      name: "My Hero",
      series: "My Hero",
      blurb: "UA training yard — orange pillars, chalk lanes",
      grassA: "#2a241c",
      grassB: "#221e18",
      rock: "#e07040",
      rockDeep: "#4a2818",
      rockHi: "#ffb080",
      accent: "#3db868",
      chalk: "#e8dcc0",
      style: "hero",
      rocks: [
        [3, 2], [7, 2], [11, 2], [15, 2],
        [5, 3], [9, 3], [13, 3],
        [3, 4], [16, 4],
        [5, 6], [9, 6], [14, 6],
        [3, 7], [7, 7], [12, 7], [16, 7],
        [5, 8], [10, 8], [15, 8],
      ],
    },
    {
      id: "breath-line",
      name: "Demon Slayer",
      series: "Demon Slayer",
      blurb: "River cuts — long walls with breath gaps",
      grassA: "#142428",
      grassB: "#101e24",
      rock: "#4a88a8",
      rockDeep: "#183040",
      rockHi: "#8ec8e0",
      accent: "#3db8a0",
      chalk: "#a0d0e0",
      style: "river",
      rocks: [
        [3, 2], [4, 2], [5, 2], [6, 2], [12, 2], [13, 2], [14, 2], [15, 2],
        [8, 3], [9, 3], [10, 3],
        [3, 4], [16, 4],
        [3, 6], [16, 6],
        [8, 7], [9, 7], [10, 7],
        [3, 8], [4, 8], [5, 8], [6, 8], [12, 8], [13, 8], [14, 8], [15, 8],
      ],
    },
    {
      id: "wall-corps",
      name: "Attack on Titan",
      series: "Attack on Titan",
      blurb: "Fortress ribs — thick flanks, narrow gates",
      grassA: "#1c1c18",
      grassB: "#181610",
      rock: "#8a8070",
      rockDeep: "#3a3830",
      rockHi: "#c8c0b0",
      accent: "#d64545",
      chalk: "#b0a890",
      style: "fort",
      rocks: [
        [3, 2], [4, 2], [5, 2], [14, 2], [15, 2], [16, 2],
        [3, 3], [4, 3], [15, 3], [16, 3],
        [3, 4], [16, 4],
        [8, 4], [9, 4], [10, 4],
        [8, 6], [9, 6], [10, 6],
        [3, 6], [16, 6],
        [3, 7], [4, 7], [15, 7], [16, 7],
        [3, 8], [4, 8], [5, 8], [14, 8], [15, 8], [16, 8],
      ],
    },
    {
      id: "curse-ward",
      name: "Jujutsu Kaisen",
      series: "Jujutsu Kaisen",
      blurb: "Domain marks — clustered seals around the spine",
      grassA: "#241018",
      grassB: "#1c0e14",
      rock: "#a05070",
      rockDeep: "#3a1828",
      rockHi: "#e090b0",
      accent: "#e85d3c",
      chalk: "#d080a0",
      style: "curse",
      rocks: [
        [5, 2], [6, 2], [13, 2], [14, 2],
        [4, 3], [7, 3], [12, 3], [15, 3],
        [6, 4], [9, 4], [10, 4], [13, 4],
        [4, 6], [7, 6], [12, 6], [15, 6],
        [5, 7], [9, 7], [10, 7], [14, 7],
        [6, 8], [7, 8], [12, 8], [13, 8],
      ],
    },
    {
      id: "gate-shade",
      name: "Solo Leveling",
      series: "Solo Leveling",
      blurb: "Shadow alleys — offset teeth along the lane",
      grassA: "#141820",
      grassB: "#10141c",
      rock: "#607090",
      rockDeep: "#182030",
      rockHi: "#9ab8d0",
      accent: "#7ec8d8",
      chalk: "#6a7880",
      style: "gate",
      rocks: [
        [4, 2], [8, 2], [12, 2], [16, 2],
        [3, 3], [6, 3], [10, 3], [14, 3],
        [5, 4], [9, 4], [13, 4], [17, 4],
        [3, 6], [7, 6], [11, 6], [15, 6],
        [5, 7], [9, 7], [13, 7], [16, 7],
        [4, 8], [8, 8], [12, 8], [15, 8],
      ],
    },
  ];

  const MAP_BY_ID = Object.fromEntries(MAPS.map((m) => [m.id, m]));

  function buildMap(mapId) {
    const theme = MAP_BY_ID[mapId] || MAPS[0];
    const tiles = Array.from({ length: ROWS }, () => Array(COLS).fill(0));
    for (let x = 0; x < COLS; x++) {
      tiles[0][x] = 3;
      tiles[ROWS - 1][x] = 3;
    }
    for (let y = 0; y < ROWS; y++) {
      tiles[y][0] = 3;
      tiles[y][COLS - 1] = 3;
    }
    (theme.rocks || []).forEach(([x, y]) => {
      if (tiles[y]?.[x] === 0) tiles[y][x] = 3;
    });
    tiles[SPAWN.y][SPAWN.x] = 4;
    tiles[EXIT.y][EXIT.x] = 5;
    return {
      tiles,
      path: [],
      tilePath: [],
      themeId: theme.id,
      theme,
    };
  }

  function pickRandomMapId(exceptId) {
    const pool = MAPS.map((m) => m.id).filter((id) => id !== exceptId);
    return pool[Math.floor(Math.random() * pool.length)] || MAPS[0].id;
  }

  function applyMap(mapId, opts = {}) {
    const randomPick = mapId === "random";
    const id = randomPick ? pickRandomMapId(state.map?.themeId) : mapId;
    const theme = MAP_BY_ID[id] || MAPS[0];
    state.map = buildMap(theme.id);
    state.units = [];
    state.enemies = [];
    state.projectiles = [];
    state.shadows = [];
    state.fx = [];
    state.selectedUnit = null;
    if (!opts.keepShop) state.selectedShop = "sparkfist";
    recomputePath();
    renderShop();
    updateHud();
    syncMapSelect(randomPick ? "random" : theme.id, theme);
    setHint(
      randomPick
        ? `Random map → ${theme.name}. ${theme.blurb}`
        : `${theme.name}: ${theme.blurb}`
    );
    return theme;
  }

  function syncMapSelect(selectValue, theme) {
    if (el.mapSelect) el.mapSelect.value = selectValue;
    if (el.mapLabel) {
      el.mapLabel.textContent = theme
        ? `Map · ${theme.name}`
        : "Map";
    }
    if (el.mapSelect) {
      el.mapSelect.disabled = state.mode !== "build";
    }
    if (el.mapRandom) {
      el.mapRandom.disabled = state.mode !== "build";
    }
  }

  function unitAt(tx, ty) {
    return state.units.find((u) => u.tx === tx && u.ty === ty);
  }

  function isBlocked(tx, ty, extraBlock) {
    if (tx < 0 || ty < 0 || tx >= COLS || ty >= ROWS) return true;
    if (extraBlock && tx === extraBlock.x && ty === extraBlock.y) return true;
    const t = state.map.tiles[ty][tx];
    if (t === 3) return true;
    if (unitAt(tx, ty)) return true;
    return false;
  }

  function findPath(from, to, extraBlock) {
    const key = (x, y) => `${x},${y}`;
    const open = [{ x: from.x, y: from.y, g: 0, f: 0, parent: null }];
    const openMap = new Map([[key(from.x, from.y), open[0]]]);
    const closed = new Set();
    const heuristic = (x, y) => Math.abs(x - to.x) + Math.abs(y - to.y);
    const dirs = [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ];

    while (open.length) {
      open.sort((a, b) => a.f - b.f);
      const cur = open.shift();
      openMap.delete(key(cur.x, cur.y));
      const ck = key(cur.x, cur.y);
      if (closed.has(ck)) continue;
      closed.add(ck);
      if (cur.x === to.x && cur.y === to.y) {
        const out = [];
        let n = cur;
        while (n) {
          out.push({ x: n.x, y: n.y });
          n = n.parent;
        }
        out.reverse();
        return out;
      }
      for (const [dx, dy] of dirs) {
        const nx = cur.x + dx;
        const ny = cur.y + dy;
        if (isBlocked(nx, ny, extraBlock)) continue;
        const nk = key(nx, ny);
        if (closed.has(nk)) continue;
        const g = cur.g + 1;
        const existing = openMap.get(nk);
        if (existing && existing.g <= g) continue;
        const node = { x: nx, y: ny, g, f: g + heuristic(nx, ny), parent: cur };
        if (existing) {
          existing.g = g;
          existing.f = node.f;
          existing.parent = cur;
        } else {
          open.push(node);
          openMap.set(nk, node);
        }
      }
    }
    return null;
  }

  function pathToPixels(tilePath) {
    if (!tilePath || !tilePath.length) return [];
    const path = [];
    for (let i = 0; i < tilePath.length - 1; i++) {
      const ax = tilePath[i].x * TILE + TILE / 2;
      const ay = tilePath[i].y * TILE + TILE / 2;
      const bx = tilePath[i + 1].x * TILE + TILE / 2;
      const by = tilePath[i + 1].y * TILE + TILE / 2;
      const steps = Math.max(1, Math.round(Math.hypot(bx - ax, by - ay)));
      for (let s = 0; s < steps; s++) {
        path.push({
          x: ax + ((bx - ax) * s) / steps,
          y: ay + ((by - ay) * s) / steps,
        });
      }
    }
    const last = tilePath[tilePath.length - 1];
    path.push({
      x: last.x * TILE + TILE / 2,
      y: last.y * TILE + TILE / 2,
    });
    return path;
  }

  function recomputePath(extraBlock) {
    const tilePath = findPath(SPAWN, EXIT, extraBlock);
    if (!tilePath) {
      if (!extraBlock) {
        state.map.tilePath = [];
        state.map.path = [];
      }
      return false;
    }
    if (!extraBlock) {
      state.map.tilePath = tilePath;
      state.map.path = pathToPixels(tilePath);
    }
    return true;
  }

  // --- State ---
  const state = {
    mode: "build", // build | wave | win | lose
    gold: baseStartingGold(),
    lives: baseStartingLives(),
    wave: 0,
    income: baseStartingIncome(),
    selectedShop: "sparkfist",
    selectedUnit: null,
    units: [],
    enemies: [],
    projectiles: [],
    shadows: [],
    fx: [],
    map: buildMap("lane-works"),
    tick: 0,
    spawnQueue: [],
    spawnTimer: 0,
    waveLeaks: 0,
    runSettled: false,
  };

  function dist(a, b) {
    return Math.hypot(a.x - b.x, a.y - b.y);
  }

  function readyButtonLabel() {
    if (state.mode === "wave") return "Fighting...";
    if (state.mode === "win") return "Victory!";
    if (state.mode === "lose") return "Defeat";
    const n = (state.wave | 0) + 1;
    return `Ready Wave ${n}`;
  }

  function updateHud() {
    el.gold.textContent = `${state.gold}g`;
    el.lives.textContent = `HP${state.lives}`;
    el.wave.textContent = `W${state.wave}`;
    el.income.textContent = `+${state.income}`;
    updateMetaHud();
    const u = state.selectedUnit;
    el.sell.disabled = !u || state.mode !== "build";
    const upCost = goldUpgradeCost(u);
    el.upgrade.disabled =
      !u ||
      state.mode !== "build" ||
      !canGoldUpgrade(u) ||
      state.gold < upCost;
    if (el.upgrade) {
      if (!u) el.upgrade.textContent = "Upgrade";
      else if (!canGoldUpgrade(u)) el.upgrade.textContent = "Maxed";
      else {
        const def = UNIT_MAP[u.type];
        el.upgrade.textContent = def && def.next
          ? `Evolve ${upCost}g`
          : `Lv ${unitStar(u) + 1} · ${upCost}g`;
      }
    }
    el.ready.disabled = state.mode !== "build";
    el.ready.textContent = readyButtonLabel();
    // Reset stays visible so players never need a browser refresh.
    if (el.newRun) el.newRun.hidden = false;
    if (el.mapSelect) el.mapSelect.disabled = state.mode !== "build";
    if (el.mapRandom) el.mapRandom.disabled = state.mode !== "build";
    updateUnitDrawerLabel();
  }

  function setHint(text) {
    el.hint.textContent = text == null ? "" : String(text);
  }

  function renderSpritePreview(shopId) {
    if (!el.preview) return;
    el.preview.innerHTML = "";
    if (!SS || !shopId) return;
    const pack = SS.units && SS.units[shopId];
    if (pack && pack.idle && pack.attack) {
      const def = UNIT_MAP[shopId];
      const label = document.createElement("span");
      label.className = "label";
      label.textContent = `${def ? def.name : shopId} frames`;
      el.preview.appendChild(label);
      [...pack.idle, ...pack.attack].forEach((frame) => {
        const c = document.createElement("canvas");
        c.width = 16;
        c.height = 16;
        const cctx = c.getContext("2d");
        cctx.imageSmoothingEnabled = false;
        cctx.drawImage(frame, 0, 0);
        el.preview.appendChild(c);
      });
      return;
    }
    // Fallback: mob roster strip when no fighter pack
    const label = document.createElement("span");
    label.className = "label";
    label.textContent = "Lane mobs";
    el.preview.appendChild(label);
    MOB_KINDS.forEach((kind) => {
      const frame = SS.mobs[kind]?.walk[0];
      if (!frame) return;
      const c = document.createElement("canvas");
      c.width = 16;
      c.height = 16;
      const cctx = c.getContext("2d");
      cctx.imageSmoothingEnabled = false;
      cctx.drawImage(frame, 0, 0);
      c.title = kind;
      el.preview.appendChild(c);
    });
  }

  const SERIES_FLAVOR = {
    "My Hero": "Smash, explosions, gravity, and dual elements",
    "Demon Slayer": "Water breath, blood burst, beast blades, lightning",
    "Attack on Titan": "Titan smash, ODM blades, captain speed, tactics",
    "Jujutsu Kaisen": "Fists, dismantle, infinity, and shikigami",
    "Solo Leveling": "Daggers, shadow army, sword flurry, ant king",
    "Lane Works": "Cheap crates to snake the lane",
  };

  function shopHint(id) {
    const u = UNIT_MAP[id];
    if (!u) return "";
    if (u.id === "palewall") {
      return `${u.name}: place on grass to block. Keep a path from red to teal.`;
    }
    const flavor = SERIES_FLAVOR[u.series];
    if (flavor) return `${u.name}: ${flavor}`;
    return `Place ${u.name} on grass to maze mobs. ${u.blurb}.`;
  }

  function renderShop() {
    el.shop.innerHTML = "";
    SHOP_IDS.forEach((id) => {
      const u = UNIT_MAP[id];
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "card" + (state.selectedShop === id ? " selected" : "");
      btn.dataset.series = u.series || "";
      const endgame = EA && EA.unitPortrait && EA.unitPortrait(id);
      let art;
      if (endgame) {
        art = document.createElement("img");
        art.className = "art art-endgame";
        art.src = endgame.src;
        art.alt = "";
        art.width = 48;
        art.height = 48;
        art.setAttribute("aria-hidden", "true");
      } else {
        art = document.createElement("canvas");
        art.className = "art";
        art.width = 32;
        art.height = 32;
        art.setAttribute("aria-hidden", "true");
        const actx = art.getContext("2d");
        actx.imageSmoothingEnabled = false;
        actx.fillStyle = "#0c0a08";
        actx.fillRect(0, 0, 32, 32);
        const frame =
          (SS && SS.units && SS.units[id] && SS.units[id].idle && SS.units[id].idle[0]) ||
          u.sprite;
        if (frame) {
          const pad = 4;
          actx.drawImage(frame, pad, pad, 32 - pad * 2, 32 - pad * 2);
        }
      }
      btn.appendChild(art);
      const name = document.createElement("span");
      name.className = "name";
      name.textContent = u.name;
      btn.appendChild(name);
      const series = document.createElement("span");
      series.className = "meta";
      series.textContent = u.series;
      btn.appendChild(series);
      const blurb = document.createElement("span");
      blurb.className = "meta";
      blurb.textContent = u.blurb;
      btn.appendChild(blurb);
      const cost = document.createElement("span");
      cost.className = "cost";
      cost.textContent = `${unitCost(u)}g`;
      btn.appendChild(cost);
      btn.addEventListener("click", () => {
        ensureAudio();
        preferLandscape();
        state.selectedShop = id;
        state.selectedUnit = null;
        setHint(shopHint(id) + " Tap grass to place.");
        renderShop();
        renderSpritePreview(id);
        updateHud();
        beep(520, 0.04);
      });
      el.shop.appendChild(btn);
    });
    renderSpritePreview(state.selectedShop);
  }

  function placeUnit(tx, ty) {
    if (state.mode !== "build" && state.mode !== "wave") return;
    const occ = unitAt(tx, ty);
    if (occ) {
      state.selectedUnit = occ;
      state.selectedShop = null;
      renderShop();
      const def = UNIT_MAP[state.selectedUnit.type];
      setHint(
        state.mode === "wave"
          ? `Selected ${def.name} ★${unitStar(state.selectedUnit)}.`
          : `Selected ${def.name} ★${unitStar(state.selectedUnit)}. Sell or upgrade with gold.`
      );
      updateHud();
      openDrawer("unit");
      return;
    }
    if (state.map.tiles[ty]?.[tx] !== 0) {
      setHint("Build on grass only — not rocks, spawn, or exit.");
      return;
    }
    const id = state.selectedShop;
    if (!id) {
      setHint("Open Units ▸, pick a unit, then tap grass.");
      openDrawer("unit");
      return;
    }
    const def = UNIT_MAP[id];
    if (state.gold < unitCost(def)) {
      setHint("Not enough gold.");
      beep(120, 0.08, "sawtooth");
      return;
    }
    if (!recomputePath({ x: tx, y: ty })) {
      setHint("That seals the lane — leave a path.");
      beep(120, 0.08, "sawtooth");
      return;
    }
    const paid = unitCost(def);
    state.gold -= paid;
    const inset = Math.floor((TILE - 8) / 2);
    const unit = {
      type: id,
      tx,
      ty,
      x: tx * TILE + inset,
      y: ty * TILE + inset,
      cd: 0,
      attackAnim: 0,
      spent: paid,
      star: 1,
    };
    state.units.push(unit);
    state.selectedUnit = unit;
    recomputePath();
    if (state.mode === "wave") repathEnemies();
    beep(660, 0.05);
    setHint(
      state.mode === "wave"
        ? `${def.name} deployed mid-fight!`
        : `${def.name} deployed. Maze the mobs, keep red→teal open.`
    );
    updateHud();
  }

  function repathEnemies() {
    const path = state.map.path;
    if (!path || path.length < 2) return;
    state.enemies.forEach((en) => {
      let bestI = 0;
      let bestD = Infinity;
      for (let i = 0; i < path.length; i++) {
        const d = Math.hypot(en.x - path[i].x, en.y - path[i].y);
        if (d < bestD) {
          bestD = d;
          bestI = i;
        }
      }
      en.pathIndex = Math.min(bestI, path.length - 1);
    });
  }

  function sellSelected() {
    const u = state.selectedUnit;
    if (!u || state.mode !== "build") return;
    const refund = Math.floor(u.spent * 0.7);
    state.gold += refund;
    state.units = state.units.filter((x) => x !== u);
    state.selectedUnit = null;
    recomputePath();
    setHint(`Sold for ${refund}g. Path updated.`);
    beep(300, 0.05);
    updateHud();
  }

  function upgradeSelected() {
    const u = state.selectedUnit;
    if (!u || state.mode !== "build") return;
    const cur = UNIT_MAP[u.type];
    if (!cur) return;

    // Prefer form evolve when available, then star levels with gold.
    if (cur.next) {
      const next = UNIT_MAP[cur.next];
      if (!next) return;
      const paid = unitCost(next);
      if (state.gold < paid) {
        setHint("Need more gold to evolve.");
        return;
      }
      state.gold -= paid;
      u.type = next.id;
      u.spent += paid;
      u.star = unitStar(u);
      recomputePath();
      beep(880, 0.06);
      setHint(`Evolved to ${next.name} ★${unitStar(u)}. Keep upgrading with gold.`);
      updateHud();
      return;
    }

    if (unitStar(u) >= MAX_UNIT_STAR) {
      setHint(`${cur.name} is maxed.`);
      return;
    }
    const paid = starUpgradeCost(u);
    if (state.gold < paid) {
      setHint("Need more gold to level up.");
      return;
    }
    state.gold -= paid;
    u.star = unitStar(u) + 1;
    u.spent += paid;
    beep(920, 0.05);
    setHint(`${cur.name} → ★${unitStar(u)}. Damage up.`);
    updateHud();
  }

  function mapMobKinds() {
    const theme = state.map && state.map.theme;
    const series = theme && theme.series;
    const list = (series && SERIES_MOBS[series]) || MOB_KINDS;
    return list.length ? list : MOB_KINDS;
  }

  function waveEnemyPlan(n) {
    const count = 6 + n * 2;
    const hp = 40 + n * 18;
    const speed = (0.55 + Math.min(0.45, n * 0.03)) * 1.1 * PX;
    const reward = 4 + Math.floor(n * 0.6);
    const kinds = mapMobKinds();
    const list = [];
    for (let i = 0; i < count; i++) {
      const elite = n > 3 && i % 7 === 0;
      list.push({
        hp: elite ? hp * 2.4 : hp,
        maxHp: elite ? hp * 2.4 : hp,
        speed: elite ? speed * 0.85 : speed,
        reward: elite ? reward * 3 : reward,
        elite,
        kind: kinds[i % kinds.length],
        delay: i * 22,
      });
    }
    if (n % 5 === 0) {
      const bossKind =
        kinds.includes("multifist")
          ? "multifist"
          : kinds.includes("shardbrute")
            ? "shardbrute"
            : kinds.includes("gatehound")
              ? "gatehound"
              : kinds[kinds.length - 1];
      list.push({
        hp: hp * 6,
        maxHp: hp * 6,
        speed: speed * 0.55,
        reward: reward * 8,
        elite: true,
        boss: true,
        kind: n % 10 === 0 && kinds.includes("gatehound") ? "gatehound" : bossKind,
        delay: count * 22 + 30,
      });
    }
    return list;
  }

  function startWave() {
    if (state.mode !== "build") return;
    ensureAudio();
    preferLandscape();
    if (!recomputePath()) {
      setHint("That seals the lane — leave a path.");
      beep(120, 0.1, "sawtooth");
      return;
    }
    state.wave += 1;
    state.mode = "wave";
    state.selectedUnit = null;
    state.waveLeaks = 0;
    state.spawnQueue = waveEnemyPlan(state.wave);
    state.spawnTimer = 0;
    state.enemies = [];
    state.projectiles = [];
    state.shadows = [];
    beep(400, 0.08);
    beep(500, 0.08);
    setHint("Hold the maze! Gold places/upgrades units. Spirit banks after the wave.");
    updateHud();
  }

  function spawnEnemy(plan) {
    const start = state.map.path[0];
    state.enemies.push({
      x: start.x,
      y: start.y,
      hp: plan.hp,
      maxHp: plan.maxHp,
      speed: plan.speed,
      reward: plan.reward,
      elite: !!plan.elite,
      boss: !!plan.boss,
      kind: plan.kind || MOB_KINDS[0],
      pathIndex: 0,
      slow: 0,
      slowT: 0,
    });
  }

  function endWaveIfDone() {
    if (state.mode !== "wave") return;
    if (state.spawnQueue.length || state.enemies.length) return;
    state.mode = "build";
    state.shadows = [];
    state.gold += state.income;
    state.income += 3;
    const leaks = state.waveLeaks | 0;
    const gained = awardWaveSpirit(state.wave, leaks);
    const pct = Math.max(0, 100 - leaks * 10);
    beep(523, 0.07);
    beep(659, 0.08);
    if (leaks === 0) {
      setHint(`Clean clear! +${gained} Spirit (100%). +${state.income - 3} income.`);
    } else {
      setHint(
        `Wave cleared · ${leaks} leak${leaks === 1 ? "" : "s"} → ${pct}% · +${gained} Spirit. +${state.income - 3} income.`
      );
    }
    if (state.wave >= 15) {
      state.mode = "win";
      settleRun(true);
    }
    updateHud();
  }

  function unitCenter(unit) {
    return { x: unit.tx * TILE + TILE / 2, y: unit.ty * TILE + TILE / 2 };
  }

  function unitRange(def, u) {
    return scaledRange(def, u) * PX;
  }

  function unitAoe(def, u) {
    const base = def.aoe || 0;
    if (!base) return 0;
    const star = unitStar(u);
    return base * PX * (1 + (star - 1) * 0.06);
  }

  function pushMuzzleAndRange(unit, def) {
    const { x: cx, y: cy } = unitCenter(unit);
    state.fx.push({
      x: cx,
      y: cy,
      life: 10,
      maxLife: 10,
      muzzle: true,
      color: def.color,
    });
    // Brief faint range ring only when firing (wave clutter control)
    state.fx.push({
      x: cx,
      y: cy,
      life: 18,
      maxLife: 18,
      rangePing: unitRange(def, unit),
      color: def.color,
    });
  }

  function damageEnemy(en, amount, slow) {
    if (!en || en.hp <= 0) return;
    en.hp -= amount;
    if (slow) {
      en.slow = Math.max(en.slow || 0, slow);
      en.slowT = 45;
    }
    if (en.hp <= 0) {
      const corpse = { x: en.x, y: en.y };
      state.gold += en.reward;
      state.fx.push({ x: en.x, y: en.y, life: 12, text: `+${en.reward}`, color: "#e8c56a" });
      state.enemies = state.enemies.filter((e) => e !== en);
      tryRaiseShadows(corpse);
      beep(700, 0.03, "triangle", 0.03);
      updateHud();
    }
  }

  function tryRaiseShadows(corpse) {
    state.units.forEach((u) => {
      const def = UNIT_MAP[u.type];
      if (!def.raiseOnKill) return;
      const c = unitCenter(u);
      if (dist(c, corpse) > unitRange(def, u)) return;
      const owned = state.shadows.filter((s) => s.owner === u).length;
      if (owned >= (def.maxShadows || 2)) return;
      state.shadows.push({
        owner: u,
        x: corpse.x,
        y: corpse.y,
        life: def.shadowLife || 100,
        cd: 8,
        damage: def.shadowDamage || 7,
        range: 40 * PX,
        rate: 18,
      });
      state.fx.push({
        x: corpse.x,
        y: corpse.y,
        life: 14,
        maxLife: 14,
        ring: 16 * PX,
        color: "#6a8aaa",
      });
      beep(240, 0.05, "triangle", 0.035);
    });
  }

  function findTarget(unit, def) {
    const c = unitCenter(unit);
    let best = null;
    let bestScore = -Infinity;
    const range = unitRange(def, unit);
    for (const en of state.enemies) {
      const d = dist(c, en);
      if (d > range) continue;
      let score = en.pathIndex;
      if (def.prioritize === "strongest") score = en.hp + en.pathIndex * 0.01;
      if (def.prioritize === "weakest") score = -en.hp + en.pathIndex * 0.01;
      if (score > bestScore) {
        bestScore = score;
        best = en;
      }
    }
    return best;
  }

  function fireUnit(unit) {
    const def = UNIT_MAP[unit.type];
    if (!def.range || def.damage <= 0) return;
    const target = findTarget(unit, def);
    if (!target) return;
    unit.cd = fireCooldown(def);
    if (def.animated) unit.attackAnim = 16;
    const { x: cx, y: cy } = unitCenter(unit);
    pushMuzzleAndRange(unit, def);

    let dmg = scaledDamage(def, unit);
    let crit = false;
    if (def.execute && target.hp / target.maxHp <= def.execute) {
      dmg = Math.floor(dmg * 1.75);
      state.fx.push({
        x: target.x,
        y: target.y - 6,
        life: 10,
        text: "EXE",
        color: "#9ab8d0",
      });
    } else if (rollCrit()) {
      dmg = Math.floor(dmg * 2);
      crit = true;
      state.fx.push({
        x: target.x,
        y: target.y - 6,
        life: 10,
        text: "CRIT",
        color: "#e85d3c",
      });
    }

    if (def.pulse || def.aoe) {
      const radius = unitAoe(def, unit) || unitRange(def, unit) * 0.7;
      state.fx.push({
        x: cx,
        y: cy,
        life: 18,
        maxLife: 18,
        ring: radius,
        color: def.color,
      });
      const splash = crit ? Math.floor(scaledDamage(def, unit) * 2) : scaledDamage(def, unit);
      state.enemies.forEach((en) => {
        if (dist({ x: cx, y: cy }, en) <= radius) {
          damageEnemy(en, splash, def.slow);
        }
      });
      beep(def.pulse ? 280 : 200, 0.04, "square", 0.03);
      return;
    }

    if (def.cleave) {
      damageEnemy(target, dmg, def.slow);
      state.enemies.forEach((en) => {
        if (en === target) return;
        if (
          Math.abs(en.pathIndex - target.pathIndex) < 18 * PX &&
          dist(en, target) < 28 * PX
        ) {
          damageEnemy(en, Math.floor(dmg * 0.7), def.slow);
        }
      });
      state.fx.push({
        x: target.x,
        y: target.y,
        life: 12,
        maxLife: 12,
        slash: true,
        color: def.color,
      });
      beep(480, 0.04);
      return;
    }

    state.projectiles.push({
      x: cx,
      y: cy,
      px: cx,
      py: cy,
      tx: target.x,
      ty: target.y,
      target,
      speed: (def.prioritize === "weakest" ? 4.2 : 3.2) * PX,
      damage: dmg,
      slow: def.slow || 0,
      color: def.color,
    });
    beep(620, 0.025, "square", 0.025);
  }

  function updateWave() {
    state.tick++;

    // Spawns (delays are absolute ticks from wave start)
    while (
      state.spawnQueue.length &&
      state.spawnQueue[0].delay <= state.spawnTimer
    ) {
      spawnEnemy(state.spawnQueue.shift());
    }
    state.spawnTimer++;

    // Enemies move
    for (let i = state.enemies.length - 1; i >= 0; i--) {
      const en = state.enemies[i];
      if (en.slowT > 0) {
        en.slowT--;
        if (en.slowT <= 0) en.slow = 0;
      }
      const spd = en.speed * (1 - (en.slow || 0));
      en.pathIndex += spd;
      const idx = Math.min(state.map.path.length - 1, Math.floor(en.pathIndex));
      const p = state.map.path[idx];
      const p2 = state.map.path[Math.min(state.map.path.length - 1, idx + 1)];
      const frac = en.pathIndex - idx;
      en.x = p.x + (p2.x - p.x) * frac;
      en.y = p.y + (p2.y - p.y) * frac;

      if (en.pathIndex >= state.map.path.length - 1) {
        const loss = en.boss ? 5 : en.elite ? 2 : 1;
        state.lives -= loss;
        state.waveLeaks = (state.waveLeaks | 0) + 1;
        state.enemies.splice(i, 1);
        state.fx.push({ x: en.x, y: en.y, life: 16, text: `-${loss}`, color: "#d64545" });
        beep(90, 0.12, "sawtooth", 0.05);
        updateHud();
        if (state.lives <= 0) {
          state.lives = 0;
          state.mode = "lose";
          settleRun(false);
        }
      }
    }

    // Units attack
    state.units.forEach((u) => {
      if (u.attackAnim > 0) u.attackAnim--;
      if (u.cd > 0) u.cd--;
      else fireUnit(u);
    });

    // Projectiles
    for (let i = state.projectiles.length - 1; i >= 0; i--) {
      const p = state.projectiles[i];
      const targetAlive = state.enemies.includes(p.target);
      const aimX = targetAlive ? p.target.x : p.tx;
      const aimY = targetAlive ? p.target.y : p.ty;
      const d = Math.hypot(aimX - p.x, aimY - p.y);
      if (d < 4 || !targetAlive) {
        if (targetAlive) damageEnemy(p.target, p.damage, p.slow);
        state.projectiles.splice(i, 1);
        continue;
      }
      p.px = p.x;
      p.py = p.y;
      p.x += ((aimX - p.x) / d) * p.speed;
      p.y += ((aimY - p.y) / d) * p.speed;
    }

    // Shadow soldiers (Gate Shade raise-on-kill)
    for (let i = state.shadows.length - 1; i >= 0; i--) {
      const sh = state.shadows[i];
      sh.life--;
      if (sh.life <= 0 || !state.units.includes(sh.owner)) {
        state.shadows.splice(i, 1);
        continue;
      }
      if (sh.cd > 0) {
        sh.cd--;
        continue;
      }
      let best = null;
      let bestD = Infinity;
      for (const en of state.enemies) {
        const d = dist(sh, en);
        if (d < bestD && d <= sh.range) {
          bestD = d;
          best = en;
        }
      }
      if (best) {
        sh.cd = sh.rate;
        // Lunge toward prey visually
        sh.x += (best.x - sh.x) * 0.25;
        sh.y += (best.y - sh.y) * 0.25;
        damageEnemy(best, sh.damage);
        state.fx.push({
          x: best.x,
          y: best.y,
          life: 6,
          maxLife: 6,
          slash: true,
          color: "#6a8aaa",
        });
      }
    }

    // FX
    state.fx.forEach((f) => f.life--);
    state.fx = state.fx.filter((f) => f.life > 0);

    endWaveIfDone();
  }

  // --- Draw ---
  function drawMap() {
    const pathTiles = new Set(
      (state.map.tilePath || []).map((p) => `${p.x},${p.y}`)
    );
    const theme = state.map.theme || MAPS[0];
    const style = theme.style || "default";
    // Endgame Hero Crest backdrop under the yard
    if (style === "hero" && EA && EA.mapBackdrop) {
      ctx.globalAlpha = 0.55;
      ctx.drawImage(EA.mapBackdrop, 0, 0, COLS * TILE, ROWS * TILE);
      ctx.globalAlpha = 1;
    }
    for (let y = 0; y < ROWS; y++) {
      for (let x = 0; x < COLS; x++) {
        const t = state.map.tiles[y][x];
        const px = x * TILE;
        const py = y * TILE;
        if (t === 3) {
          ctx.fillStyle = theme.rockDeep;
          ctx.fillRect(px, py, TILE, TILE);
          if (style === "hero") {
            // UA training pillar — chevron plate + green crest band
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 4 * PX, py + 2 * PX, 16 * PX, 20 * PX);
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 5 * PX, py + 3 * PX, 14 * PX, 18 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 7 * PX, py + 5 * PX, 10 * PX, 3 * PX);
            // chevron
            ctx.fillStyle = theme.chalk || "#e8dcc0";
            ctx.fillRect(px + 8 * PX, py + 9 * PX, 8 * PX, 2 * PX);
            ctx.fillRect(px + 9 * PX, py + 11 * PX, 6 * PX, 2 * PX);
            ctx.fillRect(px + 10 * PX, py + 13 * PX, 4 * PX, 2 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 8 * PX, py + 16 * PX, 8 * PX, 2 * PX);
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 6 * PX, py + 19 * PX, 12 * PX, 2 * PX);
          } else if (style === "river") {
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 3 * PX, py + 4 * PX, 18 * PX, 14 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 5 * PX, py + 6 * PX, 14 * PX, 3 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 4 * PX, py + 14 * PX, 16 * PX, 2 * PX);
          } else if (style === "fort") {
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 2 * PX, py + 2 * PX, 20 * PX, 20 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 4 * PX, py + 4 * PX, 6 * PX, 6 * PX);
            ctx.fillRect(px + 14 * PX, py + 4 * PX, 6 * PX, 6 * PX);
            ctx.fillRect(px + 4 * PX, py + 14 * PX, 6 * PX, 6 * PX);
            ctx.fillRect(px + 14 * PX, py + 14 * PX, 6 * PX, 6 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 10 * PX, py + 10 * PX, 4 * PX, 4 * PX);
          } else if (style === "curse") {
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 4 * PX, py + 4 * PX, 16 * PX, 16 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 7 * PX, py + 7 * PX, 10 * PX, 2 * PX);
            ctx.fillRect(px + 7 * PX, py + 15 * PX, 10 * PX, 2 * PX);
            ctx.fillRect(px + 7 * PX, py + 7 * PX, 2 * PX, 10 * PX);
            ctx.fillRect(px + 15 * PX, py + 7 * PX, 2 * PX, 10 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 10 * PX, py + 10 * PX, 4 * PX, 4 * PX);
          } else if (style === "gate") {
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 6 * PX, py + 2 * PX, 12 * PX, 20 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 8 * PX, py + 4 * PX, 8 * PX, 3 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 9 * PX, py + 10 * PX, 6 * PX, 6 * PX);
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 7 * PX, py + 18 * PX, 10 * PX, 3 * PX);
          } else if (style === "crates") {
            // Stacked crate with plank lines + strap
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 3 * PX, py + 5 * PX, 18 * PX, 16 * PX);
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 4 * PX, py + 6 * PX, 16 * PX, 14 * PX);
            ctx.fillStyle = theme.rockHi;
            ctx.fillRect(px + 5 * PX, py + 7 * PX, 14 * PX, 3 * PX);
            ctx.fillRect(px + 5 * PX, py + 12 * PX, 14 * PX, 2 * PX);
            ctx.fillStyle = theme.accent;
            ctx.fillRect(px + 11 * PX, py + 8 * PX, 2 * PX, 10 * PX);
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 4 * PX, py + 18 * PX, 16 * PX, 2 * PX);
            ctx.fillRect(px + 7 * PX, py + 4 * PX, 10 * PX, 2 * PX);
          } else {
            ctx.fillStyle = theme.rock;
            ctx.fillRect(px + 4 * PX, py + 5 * PX, 12 * PX, 10 * PX);
            ctx.fillStyle = theme.rockDeep;
            ctx.fillRect(px + 5 * PX, py + 6 * PX, 10 * PX, 3 * PX);
          }
        } else if (t === 4) {
          drawPortalTile(px, py, "spawn");
        } else if (t === 5) {
          drawPortalTile(px, py, "exit");
        } else {
          const parity = (x + y) & 1;
          if (style === "hero" && EA && EA.mapBackdrop) {
            // Let the endgame UA yard show through; keep a light checker wash
            ctx.fillStyle = parity ? "rgba(42,36,28,0.35)" : "rgba(34,30,24,0.28)";
            ctx.fillRect(px, py, TILE, TILE);
          } else {
            ctx.fillStyle = parity ? theme.grassA : theme.grassB;
            ctx.fillRect(px, py, TILE, TILE);
          }
          if (theme.chalk && ((x * 5 + y * 3) % 7) === 0) {
            ctx.fillStyle = theme.chalk;
            ctx.globalAlpha = 0.28;
            ctx.fillRect(px + 4 * PX, py + 11 * PX, 16 * PX, 2 * PX);
            ctx.globalAlpha = 1;
          } else if (style === "hero" && ((x + y) % 5) === 0) {
            // training-lane hash marks
            ctx.fillStyle = theme.chalk || "#e8dcc0";
            ctx.globalAlpha = 0.2;
            ctx.fillRect(px + 2 * PX, py + 10 * PX, 4 * PX, 2 * PX);
            ctx.fillRect(px + 18 * PX, py + 12 * PX, 4 * PX, 2 * PX);
            ctx.globalAlpha = 1;
          } else if (((x * 13 + y * 7) % 11) === 0) {
            ctx.fillStyle = theme.grassA;
            ctx.fillRect(px + 8 * PX, py + 12 * PX, 4 * PX, 3 * PX);
          }
          if (style === "hero" && theme.accent && ((x * 3 + y) % 8) === 0) {
            ctx.fillStyle = theme.accent;
            ctx.globalAlpha = 0.22;
            ctx.fillRect(px + 10 * PX, py + 6 * PX, 4 * PX, 4 * PX);
            ctx.fillRect(px + 11 * PX, py + 5 * PX, 2 * PX, 6 * PX);
            ctx.globalAlpha = 1;
          } else if (theme.accent && ((x + y * 2) % 9) === 0) {
            ctx.fillStyle = theme.accent;
            ctx.globalAlpha = 0.18;
            ctx.fillRect(px + 10 * PX, py + 6 * PX, 4 * PX, 4 * PX);
            ctx.globalAlpha = 1;
          }
          if (pathTiles.has(`${x},${y}`)) {
            // Always show a soft lane trail so the maze reads at a glance.
            ctx.fillStyle = "rgba(200, 170, 110, 0.16)";
            ctx.fillRect(px + 2, py + 2, TILE - 4, TILE - 4);
            ctx.fillStyle = "rgba(232, 197, 106, 0.22)";
            ctx.fillRect(px + 10 * PX, py + 10 * PX, 4 * PX, 4 * PX);
            if (
              state.mode === "build" ||
              (state.mode === "wave" && state.selectedShop)
            ) {
              ctx.fillStyle = "rgba(232,197,106,0.22)";
              ctx.fillRect(px + 1, py + 1, TILE - 2, TILE - 2);
              ctx.fillStyle = "rgba(232,197,106,0.5)";
              ctx.fillRect(px + 9 * PX, py + 9 * PX, 6 * PX, 6 * PX);
            }
          }
        }
      }
    }
  }

  function drawPortalTile(px, py, kind) {
    const pulse = 0.55 + 0.45 * Math.sin(state.tick * 0.12);
    const isSpawn = kind === "spawn";
    const deep = isSpawn ? "#2a100c" : "#0c221c";
    const mid = isSpawn ? "#e85d3c" : "#3db8a0";
    const hi = isSpawn ? "#ffb080" : "#9af0d8";
    const rim = isSpawn ? "#7a2818" : "#184838";
    ctx.fillStyle = deep;
    ctx.fillRect(px, py, TILE, TILE);
    ctx.fillStyle = rim;
    ctx.fillRect(px + 2 * PX, py + 2 * PX, 20 * PX, 20 * PX);
    ctx.fillStyle = mid;
    ctx.globalAlpha = 0.55 + pulse * 0.35;
    ctx.fillRect(px + 5 * PX, py + 5 * PX, 14 * PX, 14 * PX);
    ctx.globalAlpha = 1;
    ctx.fillStyle = hi;
    ctx.fillRect(px + 9 * PX, py + 9 * PX, 6 * PX, 6 * PX);
    // Arch posts
    ctx.fillStyle = rim;
    ctx.fillRect(px + 3 * PX, py + 3 * PX, 3 * PX, 18 * PX);
    ctx.fillRect(px + 18 * PX, py + 3 * PX, 3 * PX, 18 * PX);
    ctx.fillRect(px + 3 * PX, py + 3 * PX, 18 * PX, 3 * PX);
    ctx.fillStyle = hi;
    ctx.globalAlpha = 0.35 + pulse * 0.4;
    ctx.fillRect(px + 6 * PX, py + 1 * PX, 12 * PX, 2 * PX);
    ctx.globalAlpha = 1;
  }

  // Board-native draw sizes: sprites are baked to TILE×TILE and must fill one cell.
  const UNIT_DRAW = Math.round(14 * PX);
  const UNIT_DRAW_ANIM = Math.round(18 * PX);
  const UNIT_DRAW_BOARD = TILE; // endgame pixel art matches one maze cell
  const MOB_DRAW_BOARD = TILE - 2;

  function drawUnits() {
    state.units.forEach((u) => {
      const def = UNIT_MAP[u.type];
      const c = unitCenter(u);
      if (state.selectedUnit === u) {
        ctx.beginPath();
        ctx.lineWidth = 2;
        ctx.strokeStyle = "#e8c56a";
        ctx.strokeRect(u.tx * TILE + 1, u.ty * TILE + 1, TILE - 2, TILE - 2);
        ctx.strokeStyle = "rgba(61,184,160,0.55)";
        ctx.lineWidth = 1;
        ctx.strokeRect(u.tx * TILE + 3, u.ty * TILE + 3, TILE - 6, TILE - 6);
        if (def.range > 0) {
          const pulse = 0.35 + 0.15 * Math.sin(state.tick * 0.15);
          ctx.beginPath();
          ctx.arc(c.x, c.y, unitRange(def, u), 0, Math.PI * 2);
          ctx.strokeStyle = `rgba(61,184,160,${pulse})`;
          ctx.lineWidth = 1;
          ctx.stroke();
        }
        ctx.lineWidth = 1;
        ctx.globalAlpha = 1;
      }
      const endgame =
        EA && EA.unitMapSprite ? EA.unitMapSprite(u.type) : null;
      const anim =
        !endgame && def.animated && SS ? SS.unitFrame(u.type, u, state.tick) : null;
      const drawSize = endgame
        ? UNIT_DRAW_BOARD
        : anim
          ? UNIT_DRAW_ANIM
          : UNIT_DRAW;
      // Snap endgame art to the tile so it scales with the board, not free-float.
      const ox = endgame ? u.tx * TILE : c.x - drawSize / 2;
      const oy = endgame ? u.ty * TILE : c.y - drawSize / 2;
      if (!endgame) {
        ctx.fillStyle = "#0a0806";
        ctx.fillRect(ox - 1, oy - 1, drawSize + 2, drawSize + 2);
        ctx.fillStyle = def.color;
        ctx.fillRect(ox - 1, oy + drawSize - 1, drawSize + 2, 2);
      } else {
        // Thin underplate so the cell still reads on busy backdrops
        ctx.fillStyle = "rgba(10,8,6,0.55)";
        ctx.fillRect(ox, oy, TILE, TILE);
      }
      ctx.imageSmoothingEnabled = false;
      ctx.drawImage(endgame || anim || def.sprite, ox, oy, drawSize, drawSize);
      ctx.imageSmoothingEnabled = false;
    });
  }

  function drawShadows() {
    state.shadows.forEach((sh) => {
      ctx.globalAlpha = 0.85;
      ctx.fillStyle = "#0a1018";
      ctx.fillRect(sh.x - 5 * PX, sh.y - 5 * PX, 10 * PX, 10 * PX);
      ctx.fillStyle = "#6a8aaa";
      ctx.fillRect(sh.x - 3 * PX, sh.y - 3 * PX, 6 * PX, 6 * PX);
      ctx.fillStyle = "#c8d8e8";
      ctx.fillRect(sh.x - 1 * PX, sh.y - 2 * PX, 2 * PX, 2 * PX);
      ctx.globalAlpha = 1;
    });
  }

  function drawEnemies() {
    state.enemies.forEach((en) => {
      const endgame =
        EA && EA.mobMapSprite ? EA.mobMapSprite(en.kind) : null;
      const base = endgame
        ? en.boss
          ? TILE + 4
          : en.elite
            ? TILE
            : MOB_DRAW_BOARD
        : (en.boss ? 22 : en.elite ? 16 : 14) * PX;
      const frame =
        !endgame && SS && SS.mobFrame ? SS.mobFrame(en.kind, en.pathIndex) : null;
      if (endgame || frame) {
        const ox = en.x - base / 2;
        const oy = en.y - base / 2;
        if (!endgame) {
          ctx.fillStyle = "#0a0806";
          ctx.fillRect(ox - 1, oy - 1, base + 2, base + 2);
        }
        ctx.imageSmoothingEnabled = false;
        ctx.drawImage(endgame || frame, ox, oy, base, base);
        ctx.imageSmoothingEnabled = false;
      } else {
        const s = (en.boss ? 16 : en.elite ? 11 : 9) * PX;
        const body = en.boss ? "#ff7048" : en.elite ? "#ffe080" : "#f0a050";
        const outline = en.boss ? "#fff8e0" : en.elite ? "#ffffff" : "#ffe8c0";
        ctx.fillStyle = outline;
        ctx.fillRect(en.x - s / 2 - 1, en.y - s / 2 - 1, s + 2, s + 2);
        ctx.fillStyle = body;
        ctx.fillRect(en.x - s / 2, en.y - s / 2, s, s);
        ctx.fillStyle = "#fff8e8";
        ctx.fillRect(en.x - s / 2 + 1, en.y - s / 2 + 1, Math.max(2, s - 4), 2);
        ctx.fillStyle = "#2a1410";
        ctx.fillRect(en.x - 1, en.y, 2, 2);
      }
      // HP bar
      const w = base + 4;
      ctx.fillStyle = "#1a120e";
      ctx.fillRect(en.x - w / 2, en.y - base / 2 - 4, w, 2);
      ctx.fillStyle = "#ff5555";
      ctx.fillRect(en.x - w / 2, en.y - base / 2 - 4, w * (en.hp / en.maxHp), 2);
    });
  }

  function drawProjectiles() {
    state.projectiles.forEach((p) => {
      // Trail pixel
      if (p.px != null) {
        ctx.globalAlpha = 0.5;
        ctx.fillStyle = p.color;
        ctx.fillRect(p.px - 2, p.py - 2, 3, 3);
        ctx.globalAlpha = 1;
      }
      ctx.fillStyle = "#1a1008";
      ctx.fillRect(p.x - 3, p.y - 3, 6, 6);
      ctx.fillStyle = p.color;
      ctx.fillRect(p.x - 2, p.y - 2, 4, 4);
      ctx.fillStyle = "#fff8e0";
      ctx.fillRect(p.x - 1, p.y - 1, 2, 2);
    });
  }

  function drawFx() {
    state.fx.forEach((f) => {
      const maxL = f.maxLife || 12;
      const t = Math.max(0, f.life / maxL);
      const expand = 1 - t; // 0 at spawn → 1 at end
      if (f.ring) {
        const r = Math.max(2, f.ring * (0.25 + expand * 0.75));
        ctx.beginPath();
        ctx.arc(f.x, f.y, r, 0, Math.PI * 2);
        ctx.strokeStyle = f.color;
        ctx.lineWidth = 2;
        ctx.globalAlpha = Math.min(1, 0.35 + t * 0.75);
        ctx.stroke();
        ctx.beginPath();
        ctx.arc(f.x, f.y, Math.max(1, r - 2), 0, Math.PI * 2);
        ctx.strokeStyle = "#fff8e0";
        ctx.lineWidth = 1;
        ctx.globalAlpha = t * 0.65;
        ctx.stroke();
        ctx.globalAlpha = 1;
        ctx.lineWidth = 1;
      } else if (f.slash) {
        ctx.beginPath();
        ctx.strokeStyle = f.color;
        ctx.lineWidth = 3;
        ctx.globalAlpha = Math.min(1, t + 0.15);
        ctx.moveTo(f.x - 8, f.y - 5);
        ctx.lineTo(f.x + 8, f.y + 5);
        ctx.stroke();
        ctx.beginPath();
        ctx.strokeStyle = "#fff8e0";
        ctx.lineWidth = 1;
        ctx.moveTo(f.x - 6, f.y - 3);
        ctx.lineTo(f.x + 6, f.y + 3);
        ctx.stroke();
        ctx.globalAlpha = 1;
        ctx.lineWidth = 1;
      } else if (f.muzzle) {
        ctx.globalAlpha = Math.min(1, t + 0.2);
        ctx.fillStyle = "#fff8e0";
        ctx.fillRect(f.x - 4, f.y - 4, 8, 8);
        ctx.fillStyle = f.color;
        ctx.fillRect(f.x - 3, f.y - 3, 6, 6);
        ctx.fillStyle = "#fff8e0";
        ctx.fillRect(f.x - 1, f.y - 1, 2, 2);
        ctx.globalAlpha = 1;
      } else if (f.rangePing) {
        ctx.beginPath();
        ctx.arc(f.x, f.y, f.rangePing, 0, Math.PI * 2);
        ctx.strokeStyle = f.color;
        ctx.lineWidth = 1;
        ctx.globalAlpha = 0.18 * t;
        ctx.stroke();
        ctx.globalAlpha = 1;
        ctx.lineWidth = 1;
      } else if (f.text) {
        ctx.globalAlpha = 1;
        ctx.fillStyle = f.color;
        ctx.font = "6px monospace";
        ctx.fillText(f.text, f.x - 6, f.y - 8);
      }
    });
  }

  function startNewRun(opts = {}) {
    const keepMap = !!opts.keepMap;
    state.mode = "build";
    state.gold = baseStartingGold();
    state.lives = baseStartingLives();
    state.wave = 0;
    state.income = baseStartingIncome();
    state.selectedShop = "sparkfist";
    state.selectedUnit = null;
    state.units = [];
    state.enemies = [];
    state.projectiles = [];
    state.shadows = [];
    state.fx = [];
    state.spawnQueue = [];
    state.spawnTimer = 0;
    state.waveLeaks = 0;
    state.runSettled = false;
    state.tick = 0;
    if (!keepMap) {
      applyMap(state.map?.themeId || "lane-works", { keepShop: true });
    } else {
      recomputePath();
    }
    if (el.newRun) el.newRun.hidden = false;
    closeDrawers();
    renderShop();
    updateHud();
    setHint(
      `Reset — ${state.gold}g / ${state.lives} lives. Tap Shop ▸ to buy units.`
    );
    beep(520, 0.05);
  }

  function drawAtmosphere() {
    // Soft vignette so the lane reads as a stage, not a flat grid.
    const g = ctx.createRadialGradient(W * 0.5, H * 0.48, H * 0.35, W * 0.5, H * 0.5, H * 0.9);
    g.addColorStop(0, "rgba(0,0,0,0)");
    g.addColorStop(0.75, "rgba(0,0,0,0)");
    g.addColorStop(1, "rgba(0,0,0,0.22)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // Theme dust motes
    const theme = state.map.theme || MAPS[0];
    const mote = theme.accent || "#e8c56a";
    for (let i = 0; i < 8; i++) {
      const seed = i * 97 + (state.tick >> 1);
      const x = (seed * 13) % W;
      const y = ((seed * 29) + Math.floor(state.tick * (0.15 + (i % 3) * 0.05))) % H;
      ctx.globalAlpha = 0.1 + (i % 3) * 0.05;
      ctx.fillStyle = mote;
      ctx.fillRect(x, y, 1 + (i % 2), 1 + (i % 2));
    }
    ctx.globalAlpha = 1;
  }

  function drawOverlay() {
    if (state.mode === "win" || state.mode === "lose") {
      ctx.fillStyle = "rgba(10,8,6,0.72)";
      ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = state.mode === "win" ? "#e8c56a" : "#d64545";
      ctx.font = "12px Press Start 2P, monospace";
      const msg = state.mode === "win" ? "LANE HELD" : "LANE BROKEN";
      const m = ctx.measureText(msg);
      ctx.fillText(msg, (W - m.width) / 2, H / 2);
      ctx.fillStyle = "#e6dcc8";
      ctx.font = "6px Press Start 2P, monospace";
      const sub = "Reset · Unit panel for Spirit";
      const m2 = ctx.measureText(sub);
      ctx.fillText(sub, (W - m2.width) / 2, H / 2 + 16);
    }
  }

  function frame() {
    state.tick++;
    if (state.mode === "wave") updateWave();
    ctx.fillStyle = "#14100c";
    ctx.fillRect(0, 0, W, H);
    drawMap();
    drawUnits();
    drawShadows();
    drawEnemies();
    drawProjectiles();
    drawFx();
    drawAtmosphere();
    drawOverlay();
    requestAnimationFrame(frame);
  }

  // --- Input ---
  // Overlay chrome owns its taps; map only receives clicks in the open middle.
  document.querySelectorAll(".overlay-chrome").forEach((node) => {
    node.addEventListener(
      "pointerdown",
      (e) => {
        e.stopPropagation();
      },
      { passive: true }
    );
  });

  canvas.addEventListener("pointerdown", (e) => {
    ensureAudio();
    preferLandscape();
    const rect = canvas.getBoundingClientRect();
    const x = ((e.clientX - rect.left) / rect.width) * W;
    const y = ((e.clientY - rect.top) / rect.height) * H;
    const tx = Math.floor(x / TILE);
    const ty = Math.floor(y / TILE);
    if (state.mode === "build" || state.mode === "wave") placeUnit(tx, ty);
  });

  el.ready.addEventListener("click", () => {
    ensureAudio();
    preferLandscape();
    startWave();
  });
  el.sell.addEventListener("click", sellSelected);
  el.upgrade.addEventListener("click", upgradeSelected);

  if (el.btnFullscreen) {
    el.btnFullscreen.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      toggleFullscreen();
      beep(480, 0.03);
    });
  }
  if (el.btnFullscreenMenu) {
    el.btnFullscreenMenu.addEventListener("click", (e) => {
      e.preventDefault();
      toggleFullscreen();
      beep(480, 0.03);
    });
  }
  document.addEventListener("fullscreenchange", () => {
    syncFullscreenUi();
    setTimeout(fitDisplay, 40);
  });
  document.addEventListener("webkitfullscreenchange", () => {
    syncFullscreenUi();
    setTimeout(fitDisplay, 40);
  });
  // Offer fullscreen on first meaningful tap (desktop / Android / some iPads).
  let offeredFs = false;
  document.addEventListener(
    "pointerdown",
    () => {
      if (offeredFs || isStandaloneApp() || isBrowserFullscreen()) return;
      offeredFs = true;
      // Don't force — just mark that user interacted; button remains primary control.
    },
    { passive: true }
  );
  syncFullscreenUi();

  function bindDrawerButton(btn, which) {
    if (!btn) return;
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      ensureAudio();
      openDrawer(which);
      beep(which === "shop" ? 400 : 440, 0.03);
    });
  }
  bindDrawerButton(el.btnDrawerShop, "shop");
  bindDrawerButton(el.btnDrawerUnit, "unit");
  bindDrawerButton(el.btnDrawerMenu, "menu");
  if (el.btnCloseShop) {
    el.btnCloseShop.addEventListener("click", () => {
      ensureAudio();
      closeDrawers();
      beep(360, 0.03);
    });
  }
  if (el.btnCloseUnit) {
    el.btnCloseUnit.addEventListener("click", () => {
      ensureAudio();
      closeDrawers();
      beep(360, 0.03);
    });
  }
  if (el.btnCloseMenu) {
    el.btnCloseMenu.addEventListener("click", () => {
      ensureAudio();
      closeDrawers();
      beep(360, 0.03);
    });
  }
  if (el.drawerBackdrop) {
    el.drawerBackdrop.addEventListener("click", () => {
      closeDrawers();
    });
  }
  if (el.newRun) {
    el.newRun.addEventListener("click", () => {
      ensureAudio();
      preferLandscape();
      startNewRun({ keepMap: true });
    });
  }

  const offlineSheet = document.getElementById("offline-sheet");
  const btnOfflineInstall = document.getElementById("btn-offline-install");
  const btnOfflineShare = document.getElementById("btn-offline-share");
  const btnOfflineDismiss = document.getElementById("btn-offline-dismiss");

  function isAppleTouchDevice() {
    try {
      if (/[?&]ios=1(?:&|$)/.test(location.search)) return true;
    } catch (_) {
      /* ignore */
    }
    const ua = navigator.userAgent || "";
    if (/iPad|iPhone|iPod/.test(ua)) return true;
    // iPadOS desktop UA
    return navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1;
  }

  function stripSourceEmbed(html) {
    return String(html).replace(
      /<script>window\.__SPIRIT_LANE_SOURCE__\s*=[\s\S]*?<\/script>\s*/i,
      ""
    );
  }

  function injectIosInstallBanner(html) {
    if (/id="spirit-ios-hint"/.test(html)) return html;
    const banner = `
<div id="spirit-ios-hint" style="position:fixed;left:0;right:0;top:0;z-index:10001;background:#1a120e;color:#e6dcc8;border-bottom:2px solid #5ec8c8;padding:10px 12px 12px;font:12px/1.45 monospace;">
  <strong style="color:#e8c56a;">iPhone offline install</strong><br/>
  Tap Share → <em>Add to Home Screen</em> (or Add Bookmark). Open that icon with Wi‑Fi off.
  Files → Safari often fails — Home Screen is the reliable path.
  <div style="margin-top:8px;">
    <button type="button" id="spirit-ios-hint-x" style="font:inherit;padding:8px 10px;border:2px solid #5ec8c8;background:#120e0b;color:#5ec8c8;">Got it</button>
  </div>
</div>
<script>
(function(){
  var b=document.getElementById("spirit-ios-hint");
  var x=document.getElementById("spirit-ios-hint-x");
  function hide(){ if(b&&b.parentNode) b.parentNode.removeChild(b); try{ localStorage.setItem("spiritLaneIosHint","1"); }catch(e){} }
  if(x) x.addEventListener("click", hide);
  try{ if(localStorage.getItem("spiritLaneIosHint")==="1") hide(); }catch(e){}
})();
<\/script>`;
    return html.replace(/<\/body>/i, banner + "</" + "body>");
  }

  async function getOfflineHtml({ forIosInstall = false } = {}) {
    // Prefer the pristine bundled source when present (single-file build).
    let html = window.__SPIRIT_LANE_SOURCE__ || null;
    if (!html) {
      try {
        if (location.protocol !== "file:" && location.protocol !== "data:") {
          const res = await fetch(location.href, { cache: "no-store" });
          if (res.ok) html = await res.text();
        }
      } catch (_) {
        /* fall through */
      }
    }
    if (!html) {
      // Last resort: serialize the live DOM (already self-contained for the bundle).
      html = "<!DOCTYPE html>\n" + document.documentElement.outerHTML;
    }
    // Drop the duplicated source payload so the phone copy stays smaller / bookmarkable.
    html = stripSourceEmbed(html);
    if (forIosInstall) html = injectIosInstallBanner(html);
    return html;
  }

  function triggerDesktopDownload(html) {
    const blob = new Blob([html], { type: "text/html;charset=utf-8" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "spirit-lane.html";
    a.rel = "noopener";
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 2500);
  }

  async function shareOfflineFile(html) {
    const file = new File([html], "spirit-lane.html", {
      type: "text/html",
      lastModified: Date.now(),
    });
    if (!navigator.share) {
      throw new Error("share-unavailable");
    }
    const payload = { files: [file], title: "Spirit Lane", text: "Spirit Lane offline" };
    if (navigator.canShare && !navigator.canShare(payload)) {
      throw new Error("share-files-unavailable");
    }
    await navigator.share(payload);
  }

  function openIosInstallTab(html) {
    // Prefer a data: URL so Share → Add to Home Screen / Bookmark can reopen
    // offline. Chrome blocks top-frame data: navigations; iOS Safari allows them
    // when user-initiated. Always fall back to document.write so the tab is playable.
    const dataUrl = "data:text/html;charset=utf-8," + encodeURIComponent(html);
    const win = window.open("about:blank", "_blank");
    if (!win) {
      try {
        location.href = dataUrl;
        return "navigated";
      } catch (_) {
        return "blocked";
      }
    }
    try {
      win.document.open();
      win.document.write(html);
      win.document.close();
    } catch (_) {
      /* ignore */
    }
    try {
      // Upgrade to data: when allowed (iOS Safari) so the Home Screen icon persists offline.
      win.location.replace(dataUrl);
      return "opened-data";
    } catch (_) {
      return "opened-blank";
    }
  }

  function showOfflineSheet(show) {
    if (!offlineSheet) return;
    offlineSheet.hidden = !show;
  }

  async function downloadOfflineCopy() {
    const apple = isAppleTouchDevice();
    if (apple) {
      showOfflineSheet(true);
      if (el.offlineTip) {
        el.offlineTip.textContent =
          "iPhone: use Open Install Tab → Share → Add to Home Screen. Files often will not open in Safari.";
        el.offlineTip.classList.add("is-local");
      }
      setHint("iPhone offline setup — pick an option in the sheet.");
      beep(660, 0.04);
      return;
    }

    const html = await getOfflineHtml();
    triggerDesktopDownload(html);
    if (el.offlineTip) {
      el.offlineTip.textContent =
        "Saved spirit-lane.html — open that file with Wi‑Fi off.";
      el.offlineTip.classList.add("is-local");
    }
    setHint("Offline copy downloading — open the saved HTML in airplane mode.");
    beep(660, 0.04);
  }

  function refreshOfflineTip() {
    if (!el.offlineTip) return;
    const isFile = location.protocol === "file:" || location.protocol === "data:";
    const isBundle = document.documentElement.hasAttribute("data-offline-bundle");
    if (isFile || (isBundle && !navigator.onLine)) {
      el.offlineTip.textContent =
        "This copy is offline-ready — no Wi‑Fi needed.";
      el.offlineTip.classList.add("is-local");
      if (el.saveOffline) el.saveOffline.hidden = location.protocol === "file:";
    } else if (!navigator.onLine) {
      el.offlineTip.textContent = isAppleTouchDevice()
        ? "You're offline. Open your Home Screen / Bookmark copy — the web link needs Wi‑Fi."
        : "You're offline. Open a saved spirit-lane.html — the web link needs Wi‑Fi.";
      el.offlineTip.classList.add("is-local");
    } else {
      el.offlineTip.textContent = isAppleTouchDevice()
        ? "Airplane mode: tap Save Offline → Open Install Tab → Share → Add to Home Screen."
        : "Airplane mode needs a saved file — tap Save Offline while online, then open that file.";
      el.offlineTip.classList.remove("is-local");
    }
  }

  if (el.saveOffline) {
    el.saveOffline.addEventListener("click", () => {
      ensureAudio();
      downloadOfflineCopy().catch((err) => {
        setHint("Save failed — on iPhone use Share → Add to Home Screen from this page.");
        console.warn(err);
      });
    });
  }
  if (btnOfflineDismiss && offlineSheet) {
    btnOfflineDismiss.addEventListener("click", () => showOfflineSheet(false));
    offlineSheet.addEventListener("click", (e) => {
      if (e.target === offlineSheet) showOfflineSheet(false);
    });
  }
  if (btnOfflineInstall) {
    btnOfflineInstall.addEventListener("click", () => {
      ensureAudio();
      getOfflineHtml({ forIosInstall: true })
        .then((html) => {
          const mode = openIosInstallTab(html);
          showOfflineSheet(false);
          setHint(
            mode === "navigated"
              ? "Share → Add to Home Screen, then open that icon offline."
              : mode === "blocked"
                ? "Popup blocked — allow popups, or use Share File…"
                : "New tab: Share → Add to Home Screen (or Bookmark). Use that offline."
          );
          if (el.offlineTip) {
            el.offlineTip.textContent =
              "Install tab opened — Share → Add to Home Screen, then airplane mode.";
            el.offlineTip.classList.add("is-local");
          }
          beep(720, 0.04);
        })
        .catch((err) => {
          setHint("Could not open install tab — try Share File instead.");
          console.warn(err);
        });
    });
  }
  if (btnOfflineShare) {
    btnOfflineShare.addEventListener("click", () => {
      ensureAudio();
      getOfflineHtml()
        .then((html) => shareOfflineFile(html))
        .then(() => {
          showOfflineSheet(false);
          setHint("Shared. If Safari will not open it, use Open Install Tab instead.");
          if (el.offlineTip) {
            el.offlineTip.textContent =
              "File shared. Prefer Home Screen install if Safari will not open the file.";
            el.offlineTip.classList.add("is-local");
          }
          beep(660, 0.04);
        })
        .catch((err) => {
          // User cancel vs hard failure
          const name = err && err.name;
          if (name === "AbortError") return;
          setHint("Share unavailable — use Open Install Tab → Add to Home Screen.");
          console.warn(err);
        });
    });
  }
  refreshOfflineTip();
  window.addEventListener("online", refreshOfflineTip);
  window.addEventListener("offline", refreshOfflineTip);

  function populateMapSelect() {
    if (!el.mapSelect) return;
    el.mapSelect.innerHTML = "";
    const randomOpt = document.createElement("option");
    randomOpt.value = "random";
    randomOpt.textContent = "Random";
    el.mapSelect.appendChild(randomOpt);
    MAPS.forEach((m) => {
      const opt = document.createElement("option");
      opt.value = m.id;
      opt.textContent = m.name;
      el.mapSelect.appendChild(opt);
    });
  }

  if (el.mapSelect) {
    el.mapSelect.addEventListener("change", () => {
      if (state.mode !== "build") return;
      ensureAudio();
      preferLandscape();
      applyMap(el.mapSelect.value);
      beep(440, 0.03);
    });
  }
  if (el.mapRandom) {
    el.mapRandom.addEventListener("click", () => {
      if (state.mode !== "build") return;
      ensureAudio();
      preferLandscape();
      applyMap("random");
      beep(500, 0.03);
    });
  }

  // Boot
  populateMapSelect();
  recomputePath();
  renderShop();
  renderMetaStore();
  updateHud();
  closeDrawers();
  syncMapSelect("lane-works", MAP_BY_ID["lane-works"]);
  setHint("Open Shop to buy a unit, then tap grass to place it.");
  preferLandscape();
  fitDisplay();
  // Safari often lays out after the first paint — refit so the map isn't 0×0.
  setTimeout(fitDisplay, 0);
  setTimeout(fitDisplay, 100);
  setTimeout(fitDisplay, 400);
  window.addEventListener("resize", fitDisplay);
  window.addEventListener("orientationchange", () => {
    setTimeout(fitDisplay, 50);
    setTimeout(fitDisplay, 250);
  });
  if (window.visualViewport) {
    window.visualViewport.addEventListener("resize", fitDisplay);
  }
  document.addEventListener(
    "pointerdown",
    () => {
      preferLandscape();
    },
    { once: true, passive: true }
  );
  window.SpiritLane = {
    fitDisplay,
    preferLandscape,
    applyMap,
    listMaps: () => MAPS.map((m) => ({ id: m.id, name: m.name, series: m.series })),
    getMap: () => ({
      id: state.map.themeId,
      name: state.map.theme && state.map.theme.name,
    }),
    setGold(n) {
      state.gold = Math.max(0, n | 0);
      updateHud();
    },
    getUnits: () => state.units.map((u) => ({ type: u.type, tx: u.tx, ty: u.ty, star: unitStar(u) })),
    getPath: () => (state.map.tilePath || []).map((p) => ({ x: p.x, y: p.y })),
    getPathPixels: () => (state.map.path || []).length,
    getMode: () => state.mode,
    getHint: () => el.hint.textContent,
    getEnemies: () =>
      state.enemies.map((e) => ({
        x: e.x,
        y: e.y,
        pathIndex: e.pathIndex,
        kind: e.kind,
      })),
    getTiles: () => state.map.tiles.map((row) => row.slice()),
    getMeta: () => JSON.parse(JSON.stringify(meta)),
    addSpirit(n) {
      meta.points += Math.max(0, n | 0);
      saveMeta();
      updateMetaHud();
      renderMetaStore();
    },
    buyMeta: buyMetaUpgrade,
    newRun: startNewRun,
    showStore: () => openDrawer("shop"),
    showShop: () => openDrawer("shop"),
    closeDrawers,
    mapMobKinds,
  };

  // Drop any boot splash immediately so Safari never sticks on "Loading…"
  document.querySelectorAll("#boot-splash").forEach((node) => {
    node.classList.add("hide");
    setTimeout(() => node.remove(), 350);
  });
  if (EA && EA.whenReady) {
    EA.whenReady(() => {
      renderShop();
      updateHud();
    });
  }
  requestAnimationFrame(frame);
})();
