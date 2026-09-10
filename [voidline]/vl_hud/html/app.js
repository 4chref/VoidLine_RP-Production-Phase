/* =============================================================================
   vl_hud - presentation layer.

   The Lua side sends raw percentages and nothing else; every decision about
   colour and visibility is made here, so the look can be retuned without
   touching game code.
   ============================================================================= */

let cfg = {
    icons: { health: true, hunger: true, thirst: true, stamina: true, armour: true, temperature: true, mic: true, noise: true, power: true, threat: true, sleep: true, poop: true, pee: true },
    thresholds: { fine: 70, warning: 55, danger: 35, critical: 18, flash: 5 },
    iconFill: true,
    fillHiddenAt: 101,
    alwaysShow: true,
    stamina: { alwaysShow: true, hideAbovePercent: 98 },
    breath: { enabled: true, showWhileSwimming: false, lowPercent: 35, criticalPercent: 15 },
    weapon: { enabled: true, hideInVehicle: true, showReserve: true, lowAmmo: 5, lowDurability: 25 },
};

const els = {
    energy: document.getElementById("stat-energy"),
    hunger: document.getElementById("stat-hunger"),
    temperature: document.getElementById("stat-temperature"),
    thirst: document.getElementById("stat-thirst"),
    health: document.getElementById("stat-health"),
    armour: document.getElementById("stat-armour"),
    sleep: document.getElementById("stat-sleep"),
    poop: document.getElementById("stat-poop"),
    pee: document.getElementById("stat-pee"),
};

// Clip rects that produce the bottom-up fill, one per icon.
const rects = {
    energy: document.getElementById("rect-energy"),
    hunger: document.getElementById("rect-hunger"),
    temperature: document.getElementById("rect-temperature"),
    thirst: document.getElementById("rect-thirst"),
    health: document.getElementById("rect-health"),
    armour: document.getElementById("rect-armour"),
    sleep: document.getElementById("rect-sleep"),
    poop: document.getElementById("rect-poop"),
    pee: document.getElementById("rect-pee"),
};

const ICON_SIZE = 24; // matches every icon's viewBox

/**
 * Raises the clip rect from the bottom of the icon to `value` percent, so the
 * filled height IS the level. The fill is always shown by default; setting
 * cfg.fillHiddenAt to 100 or less makes a full stat collapse to bare outline.
 */
function applyFill(key, value) {
    const rect = rects[key];
    if (!rect) return;

    // Outline-only unless the fill is explicitly enabled.
    const pct = Math.max(0, Math.min(100, value || 0));
    const filled = cfg.iconFill && pct < (cfg.fillHiddenAt ?? 101);
    const height = filled ? (ICON_SIZE * pct) / 100 : 0;

    rect.setAttribute("height", height);
    rect.setAttribute("y", ICON_SIZE - height);
}

const sleepFaintTimerEl = document.getElementById("sleep-faint-timer");
const blackoutTimerEl = document.getElementById("power-blackout-timer");

/**
 * Countdown floated above a stat icon (fainted sleep, blackout power, etc).
 * Seconds arrive from the Lua side already rounded up to a whole second;
 * formatted here as m:ss.
 */
function applyIconTimer(el, seconds) {
    if (!el) return;

    const s = Math.max(0, Math.floor(seconds || 0));
    if (s <= 0) {
        el.classList.add("hidden");
        return;
    }

    const mm = Math.floor(s / 60);
    const ss = String(s % 60).padStart(2, "0");
    el.textContent = `${mm}:${ss}`;
    el.classList.remove("hidden");
}

const micEl = document.getElementById("stat-mic");
const powerEl = document.getElementById("stat-power");
const threatEl = document.getElementById("stat-threat");
const noiseEl = document.getElementById("noise");
const noiseBars = noiseEl ? Array.from(noiseEl.querySelectorAll(".narc")) : [];

/**
 * Voice + noise arrive on their own faster channel than survival status,
 * because both change far too quickly to look right at the status tick rate.
 */
function applyLive(d) {
    if (micEl) {
        micEl.classList.toggle("hidden", !cfg.icons.mic);
        micEl.classList.toggle("talking", !!d.talking);
        micEl.classList.toggle("radio", !!d.radio);
    }

    if (noiseEl) {
        noiseEl.classList.toggle("hidden", !cfg.icons.noise);
        const level = Math.max(0, Math.min(4, d.noise || 0));
        noiseBars.forEach((bar) => {
            bar.classList.toggle("on", Number(bar.dataset.level) <= level);
        });
        noiseEl.classList.toggle("loud", level === 3);
        noiseEl.classList.toggle("veryloud", level >= 4);
    }

    applyBreath(d);
    applyWeapon(d);
}

const staminaWrap = document.getElementById("stamina");
const staminaFill = document.getElementById("stamina-fill");

let isDead = false;

const breathWrap = document.getElementById("breath");
const breathFill = document.getElementById("breath-fill");
const breathSpacer = document.getElementById("breath-spacer");

const weaponWrap = document.getElementById("weapon");
const weaponSpacer = document.getElementById("weapon-spacer");
const durabilityFill = document.getElementById("durability-fill");
const ammoLoaded = document.getElementById("ammo-loaded");
const ammoReserve = document.getElementById("ammo-reserve");

/**
 * Equipped weapon. The Lua side sends the whole widget or nothing at all --
 * ox_inventory's own equip/holster event is the show/hide condition, so there
 * is no "is a weapon out" test to duplicate here.
 *
 * Counts of -1 mean "this weapon has no such figure" (a melee weapon has no
 * magazine, an undamaged-by-design item has no durability) rather than zero,
 * which would otherwise render as an empty bar or an ominous 0 rounds.
 */
function applyWeapon(d) {
    if (!weaponWrap) return;

    const w = cfg.weapon || {};
    const gun = d.weapon;
    const show = w.enabled !== false
        && !isDead
        && !!gun
        && !(w.hideInVehicle !== false && d.inVehicle);

    weaponWrap.classList.toggle("hidden", !show);
    if (weaponSpacer) weaponSpacer.classList.toggle("hidden", !cfg.icons.noise);
    if (!show) return;

    const dur = gun.durability;
    const hasDur = dur >= 0;
    weaponWrap.classList.toggle("nobar", !hasDur);
    durabilityFill.style.width = (hasDur ? dur : 0) + "%";
    durabilityFill.classList.toggle("low", hasDur && dur <= (w.lowDurability ?? 25));

    const ammo = gun.ammo;
    if (ammo < 0) {
        // Melee or throwable: no magazine to report.
        ammoLoaded.textContent = "";
        ammoReserve.textContent = "";
        weaponWrap.classList.remove("lowammo", "noammo");
        return;
    }

    ammoLoaded.textContent = ammo;
    ammoReserve.textContent = gun.reserve >= 0 ? "/ " + gun.reserve : "";
    weaponWrap.classList.toggle("noammo", ammo === 0);
    weaponWrap.classList.toggle(
        "lowammo",
        ammo > 0 && ammo <= (w.lowAmmo ?? 5)
    );
}

/**
 * Air supply. Rides the live channel because it drains in about ten seconds on
 * stock lungs, which the slower status tick would render as visible steps.
 *
 * The bar is on screen only while submerged (or, with showWhileSwimming, from
 * the moment the player enters the water) -- above the surface the player is
 * breathing and there is nothing to report.
 */
function applyBreath(d) {
    if (!breathWrap) return;

    const b = cfg.breath || {};
    const pct = Math.max(0, Math.min(100, d.breath ?? 100));
    // The live channel ticks on while the player is dead, so the last known
    // death state gates the bar -- otherwise a body in the water would keep
    // reporting air after hideAll() cleared the rest of the HUD.
    const show = b.enabled !== false
        && !isDead
        && (d.submerged || (b.showWhileSwimming && d.swimming));

    breathWrap.classList.toggle("hidden", !show);
    if (breathSpacer) breathSpacer.classList.toggle("hidden", !cfg.icons.noise);

    breathFill.style.width = pct + "%";
    breathWrap.classList.toggle("critical", pct <= (b.criticalPercent ?? 15));
    breathWrap.classList.toggle(
        "low",
        pct <= (b.lowPercent ?? 35) && pct > (b.criticalPercent ?? 15)
    );
}

const veh = {
    wrap: document.getElementById("vehicle"),
    speedNeedle: document.getElementById("speed-needle"),
    rpmNeedle: document.getElementById("rpm-needle"),
    fuelNeedle: document.getElementById("fuel-needle"),
    tempNeedle: document.getElementById("temp-needle"),
    speedValue: document.getElementById("speed-value"),
    speedUnit: document.getElementById("speed-unit"),
    rpmValue: document.getElementById("rpm-value"),
    gearValue: document.getElementById("gear-value"),
};

/**
 * Maps 0..1 onto the gauge sweep. The arcs span 270 degrees with the gap at the
 * bottom, so the needle travels from -135 to +135 degrees.
 */
function needleAngle(fraction) {
    const f = Math.max(0, Math.min(1, fraction || 0));
    return -135 + f * 270;
}

function setNeedle(el, fraction) {
    if (el) el.style.transform = `rotate(${needleAngle(fraction)}deg)`;
}

const SEVERITY = ["ok", "warning", "danger", "critical", "flash"];

/**
 * Applies the severity ramp to one icon.
 * Icons stay on screen permanently; only their colour changes, which is what
 * the reference HUD does.
 */
function applyStat(el, enabled, value, key) {
    if (!el) return;

    if (!enabled) {
        el.classList.add("hidden");
        return;
    }
    el.classList.remove("hidden");

    if (key) applyFill(key, value);

    const t = cfg.thresholds;
    SEVERITY.forEach((c) => el.classList.remove(c));

    if (value <= (t.flash ?? 5)) {
        // Dire: red, and fading slowly in and out.
        el.classList.add("critical", "flash");
    } else if (value <= t.critical) {
        el.classList.add("critical");
    } else if (value <= t.danger) {
        el.classList.add("danger");
    } else if (value <= t.warning) {
        el.classList.add("warning");
    } else {
        el.classList.add("ok");
    }

    // When alwaysShow is off, healthy stats disappear entirely (stricter DayZ).
    if (!cfg.alwaysShow && value > t.fine) {
        el.classList.add("hidden");
    }
}

/**
 * Same as applyStat, but for stats where HIGH is bad instead of low (poop,
 * pee): the icon fills UP as the value rises and turns red as it approaches
 * 100 instead of 0. Every threshold comparison is mirrored around 100 so the
 * same cfg.thresholds numbers still mean "this many percent from the bad end".
 */
function applyStatRising(el, enabled, value, key) {
    if (!el) return;

    if (!enabled) {
        el.classList.add("hidden");
        return;
    }
    el.classList.remove("hidden");

    if (key) applyFill(key, value);

    const t = cfg.thresholds;
    SEVERITY.forEach((c) => el.classList.remove(c));

    if (value >= 100 - (t.flash ?? 5)) {
        el.classList.add("critical", "flash");
    } else if (value >= 100 - t.critical) {
        el.classList.add("critical");
    } else if (value >= 100 - t.danger) {
        el.classList.add("danger");
    } else if (value >= 100 - t.warning) {
        el.classList.add("warning");
    } else {
        el.classList.add("ok");
    }

    if (!cfg.alwaysShow && value < 100 - t.fine) {
        el.classList.add("hidden");
    }
}

function hideAll() {
    Object.values(els).forEach((el) => el && el.classList.add("hidden"));
    staminaWrap.classList.add("hidden");
    if (breathWrap) breathWrap.classList.add("hidden");
    if (weaponWrap) weaponWrap.classList.add("hidden");
    if (micEl) micEl.classList.add("hidden");
    if (powerEl) powerEl.classList.add("hidden");
    if (threatEl) threatEl.classList.add("hidden");
    if (noiseEl) noiseEl.classList.add("hidden");
    if (sleepFaintTimerEl) sleepFaintTimerEl.classList.add("hidden");
    if (blackoutTimerEl) blackoutTimerEl.classList.add("hidden");
}

window.addEventListener("message", (event) => {
    const msg = event.data || {};

    if (msg.action === "config") {
        cfg = Object.assign(cfg, msg.data || {});
        return;
    }

    if (msg.action === "hide") {
        hideAll();
        veh.wrap.classList.remove("visible");
        return;
    }

    if (msg.action === "live") {
        applyLive(msg.data || {});
        return;
    }

    if (msg.action === "vehicle") {
        const d = msg.data || {};
        if (!d.show) {
            veh.wrap.classList.remove("visible");
            return;
        }
        veh.wrap.classList.add("visible");

        setNeedle(veh.speedNeedle, d.speed / (d.maxSpeed || 200));
        setNeedle(veh.rpmNeedle, d.rpm / (d.maxRpm || 80));
        setNeedle(veh.fuelNeedle, (d.fuel || 0) / 100);
        setNeedle(veh.tempNeedle, (d.temperature || 0) / 100);

        veh.speedValue.textContent = Math.max(0, Math.round(d.speed || 0));
        veh.speedUnit.textContent = d.unit || "km/h";
        veh.rpmValue.textContent = Math.max(0, Math.round(d.rpm || 0));
        veh.gearValue.textContent = d.gear || "N";
        return;
    }

    if (msg.action !== "status") return;

    const d = msg.data || {};

    isDead = !!d.dead;
    if (isDead) {
        hideAll();
        return;
    }

    // Grid power. No severity ramp and no fill: it is on or it is out, so it is
    // driven straight off the world state rather than through applyStat.
    if (powerEl) {
        powerEl.classList.toggle("hidden", !cfg.icons.power);
        powerEl.classList.toggle("out", !!d.blackout);
    }
    applyIconTimer(blackoutTimerEl, cfg.icons.power ? d.blackoutSeconds || 0 : 0);

    // Threat. Also binary here -- the Lua side collapses every registered
    // source down to one answer, so this never has to know what is hunting you.
    if (threatEl) {
        threatEl.classList.toggle("hidden", !cfg.icons.threat);
        threatEl.classList.toggle("alert", !!d.threat);
    }

    applyStat(els.energy, cfg.icons.stamina, d.stamina, "energy");
    applyStat(els.hunger, cfg.icons.hunger, d.hunger, "hunger");
    applyStat(els.temperature, cfg.icons.temperature, d.temperature, "temperature");
    applyStat(els.thirst, cfg.icons.thirst, d.thirst, "thirst");
    applyStat(els.health, cfg.icons.health, d.health, "health");

    // Sleep arrives already inverted from the Lua side ("fine" = 100, same as
    // every other icon). Poop/pee arrive RAW instead: they fill up and turn
    // red as the value climbs toward 100, so they use applyStatRising.
    applyStat(els.sleep, cfg.icons.sleep, d.sleep, "sleep");
    applyStatRising(els.poop, cfg.icons.poop, d.poop, "poop");
    applyStatRising(els.pee, cfg.icons.pee, d.pee, "pee");
    applyIconTimer(sleepFaintTimerEl, d.sleepFaintSeconds || 0);

    // Armour is inverted: it is not a survival need, so it only appears WHILE
    // you have some rather than when it runs low.
    if (cfg.icons.armour && d.armour > 0) {
        els.armour.classList.remove("hidden");
        SEVERITY.forEach((c) => els.armour.classList.remove(c));
        els.armour.classList.add("ok");
        applyFill("armour", d.armour);
    } else {
        els.armour.classList.add("hidden");
    }

    // Stamina bar, bottom left.
    const stam = Math.max(0, Math.min(100, d.stamina));
    // Stamina is meaningless while driving, so the bar goes away entirely.
    const showBar = !d.inVehicle
        && (cfg.stamina.alwaysShow || stam < (cfg.stamina.hideAbovePercent ?? 98));
    staminaWrap.classList.toggle("hidden", !showBar);
    staminaFill.style.width = stam + "%";
    staminaFill.classList.toggle("low", stam <= 25);
});
