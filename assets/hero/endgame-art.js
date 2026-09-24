(() => {
  "use strict";

  // Endgame rendered art for My Hero (UI + in-map). Pixel bake packs remain fallback.
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
    "sparkfist-64": "assets/hero/hero-sparkfist-64.png",
    "blastcrown-64": "assets/hero/hero-blastcrown-64.png",
    "bakugo-64": "assets/hero/hero-bakugo-64.png",
    "howitzer-64": "assets/hero/hero-howitzer-64.png",
    "hoverbind-64": "assets/hero/hero-hoverbind-64.png",
    "zerofield-64": "assets/hero/hero-zerofield-64.png",
    "todoroki-64": "assets/hero/hero-todoroki-64.png",
    "halfcold-64": "assets/hero/hero-halfcold-64.png",
    "quirling-endgame": "assets/hero/hero-quirling-endgame.png",
    "multifist-endgame": "assets/hero/hero-multifist-endgame.png",
    "floatdrone-endgame": "assets/hero/hero-floatdrone-endgame.png",
    "sparkgrub-endgame": "assets/hero/hero-sparkgrub-endgame.png",
    "quirling-64": "assets/hero/hero-quirling-64.png",
    "multifist-64": "assets/hero/hero-multifist-64.png",
    "floatdrone-64": "assets/hero/hero-floatdrone-64.png",
    "sparkgrub-64": "assets/hero/hero-sparkgrub-64.png",
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

  const portraits = Object.create(null);
  const mapSprites = Object.create(null);
  const mobPortraits = Object.create(null);
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

  async function boot() {
    const jobs = [];

    HERO_UNIT_IDS.forEach((id) => {
      jobs.push(
        loadImage(ASSET_URLS[`${id}-endgame`]).then((img) => {
          if (img) portraits[id] = img;
        })
      );
      jobs.push(
        loadImage(ASSET_URLS[`${id}-64`]).then((img) => {
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
        loadImage(ASSET_URLS[`${id}-64`]).then((img) => {
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
    ready = true;
    waiters.splice(0).forEach((cb) => {
      try {
        cb();
      } catch (_) {}
    });
  }

  window.SpiritEndgameArt = {
    HERO_UNIT_IDS,
    HERO_MOB_IDS,
    portraits,
    mapSprites,
    mobPortraits,
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
    unitMapSprite(id) {
      return mapSprites[id] || portraits[id] || null;
    },
    mobMapSprite(kind) {
      return mapSprites[`mob:${kind}`] || mobPortraits[kind] || null;
    },
  };

  boot();
})();
