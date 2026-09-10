(function () {
'use strict';
/* =============================================================================
   vl_airraid -- NUI audio engine

   Adapted directly from vl_combat_drone/html/index.html's drone-siren audio
   engine, which already proved this exact technique out in production on this
   server: one Web Audio PannerNode per source, the LISTENER fixed at the
   origin with the default orientation, and each source's position streamed in
   from Lua already expressed in listener space (x = right, y = up, z = behind
   the camera -- see client/main.lua's cameraBasis()). That is mathematically
   identical to moving/rotating the listener to track the camera, and far
   cheaper: three numbers per site per tick, no AudioListener.orientation calls,
   no version-dependent Web Audio API surface to depend on.

   What differs from the drone engine, and why:
     - All 19 sites share ONE mp3. loadBuffer()'s cache means it is fetched and
       decoded exactly once no matter how many sites are sounding -- this
       matters far more here than it did for a handful of drones.
     - Positions arrive BATCHED (sound_pos_batch, one message per tick covering
       every currently-audible site) rather than one message per source, since
       up to 19 sources can be live at once here against a drone engine that
       rarely has more than one or two.
     - Fade-IN is configurable per the brief ("smooth fade-in/fade-out"), not a
       fixed time-constant -- a civil defense siren winds up slower than it
       cuts off, so the two are deliberately different lengths in config.lua.
     - A limiter sits on the master bus (see LOUDNESS below). A drone engine
       only ever has a couple of voices live; this one can have several
       overlapping sirens at once by design (that is the whole point of the
       wide, overlapping ranges), and independent Web Audio gains SUM at the
       destination -- three sirens at "full" individual volume do not sound
       3x more present, they clip and blast. The drone engine never needed
       this because it never had enough simultaneous voices to hit it.
     - Each voice resumes its loop at the correct PHASE, not always at 0:00 --
       see startVoice()'s `elapsed` handling. A drone's siren starts fresh
       every time because a drone is a new event; a fixed-site siren is meant
       to read as having been running continuously since the raid began.
   ========================================================================== */

const RESOURCE = (location.hostname || '').replace(/^cfx-nui-/, '') || 'vl_airraid';

function report(name, data) {
  try {
    fetch('https://' + RESOURCE + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).catch(function () {});
  } catch (e) { /* not running inside NUI (e.g. opened in a normal browser) */ }
}

const AudioCtx = window.AudioContext || window.webkitAudioContext;
const ctx = new AudioCtx();

const master = ctx.createGain();
// Kept live by the 'master_volume' message -- sent roughly once a second the
// whole time a raid is active, as VLAirRaid.audio.masterVolume * however much
// of the citywide siren zone you are currently inside (see client/main.lua's
// startRangeCheck / zoneGain). This default only matters before the first
// message arrives -- it should never sit at 1.0 either way.
master.gain.value = 0.55;

// =============================================================================
// LOUDNESS
//
// Three layers, loudest-to-quietest control:
//   1. VLAirRaid.audio.volume (config.lua) -- per-site, before anything sums.
//   2. master.gain -- overall trim AND the citywide zone fade, both folded
//      into the same live 'master_volume' value so leaving the zone reads as
//      the whole city fading behind you, not each site running out alone.
//   3. This limiter -- a safety net for when several sites' gains sum anyway.
//
// (3) exists because Web Audio gains SUM at the destination: two sirens each
// at "full" individual volume do not read as one siren twice as loud, they
// add up and clip. Standing where 2-3 site ranges overlap (common now that
// ranges are wide and deliberately overlapping, see config.lua's
// rangeMultiplier) is exactly when this bites -- that summed blast, not any
// one voice's own volume, was the original "blasting me" report. It is
// self-adjusting: only engages once the sum actually gets loud, so a single
// distant siren is left alone and only a genuine pile-up gets pulled down.
//
// If it is STILL too loud after a tune: turn down (1) or (2) first -- config.lua,
// no JS edit needed. Only touch the numbers below if quiet moments still spike
// (rare; means the limiter itself needs to bite harder, not that the base
// volume is wrong).
const limiter = ctx.createDynamicsCompressor();
limiter.threshold.value = -18; // dB -- engages earlier than before (was -10)
limiter.knee.value = 4;        // dB -- tighter knee: less "creeps up before it bites"
limiter.ratio.value = 20;      // near brick-wall beyond the threshold
limiter.attack.value = 0.003;  // seconds -- fast enough to catch the initial wail peak
limiter.release.value = 0.25;  // seconds -- slow enough not to audibly "pump" on a slow siren

master.connect(limiter);
limiter.connect(ctx.destination);

/* Decoded AudioBuffers, keyed BY SOURCE PATH.

   This used to be a single `buffer` variable, from when the siren was the only
   sound this page ever played -- loadBuffer() took a `src`, ignored it after
   the first call, and handed every later voice whatever had been decoded first.

   That is a real bug the moment there are two sounds, and it is exactly what
   made the sirens play intruder.mp3: the outpost alarm loads at ~11s, the
   sirens at ~22s, so the alarm won the cache and every siren voice was handed
   its buffer.

   Keyed per path, both live side by side and each voice gets its own. */
const buffers = new Map();          // src -> AudioBuffer
const bufferPromises = new Map();   // src -> Promise<AudioBuffer> while in flight
const sounds = new Map(); // site id -> voice

// CEF usually allows autoplay, but an AudioContext created before the page had
// focus can still come up suspended. Resuming is idempotent, so it costs
// nothing to retry it on every incoming message.
function wake() {
  if (ctx.state !== 'running') ctx.resume().catch(() => {});
}

function loadBuffer(src) {
  if (buffers.has(src)) return Promise.resolve(buffers.get(src));
  if (bufferPromises.has(src)) return bufferPromises.get(src);

  const p = fetch(src)
    .then((r) => {
      if (!r.ok) throw new Error('HTTP ' + r.status + ' fetching ' + src);
      return r.arrayBuffer();
    })
    .then((ab) => {
      if (!ab || ab.byteLength === 0) throw new Error('empty file: ' + src);
      return new Promise((res, rej) => ctx.decodeAudioData(ab, res, rej));
    })
    .then((buf) => {
      buffers.set(src, buf);
      bufferPromises.delete(src);
      // Named in the report so a future "wrong sound" question is answered by
      // the console instead of by reading this file.
      report('audioLoaded', { src: src, seconds: Number(buf.duration.toFixed(3)) });
      return buf;
    })
    .catch((err) => {
      bufferPromises.delete(src);
      report('audioError', { src: src, error: String(err && err.message ? err.message : err) });
      throw err;
    });

  bufferPromises.set(src, p);
  return p;
}

function startVoice(cfg) {
  wake();

  // Resurrect a voice still fading out from a very recent stop (the player
  // stepped just out of range and straight back in). Without cancelling the
  // pending teardown AND ramping gain back up, the voice would survive muted
  // forever with nothing left to ever unmute it.
  let v = sounds.get(cfg.id);
  if (v) {
    v.stopping = false;
    if (v.teardown) { clearTimeout(v.teardown); v.teardown = null; }
    const rampS = Math.max((cfg.fadeInMs || 2500) / 3000, 0.01);
    v.gain.gain.cancelScheduledValues(ctx.currentTime);
    v.gain.gain.setTargetAtTime(v.volume, ctx.currentTime, rampS);
    return v;
  }

  const panner = ctx.createPanner();
  panner.panningModel   = 'HRTF';
  panner.distanceModel  = cfg.distanceModel || 'linear';
  panner.refDistance    = cfg.refDistance || 60;
  panner.maxDistance    = cfg.maxDistance || 450;
  panner.rolloffFactor  = cfg.rolloff || 1.0;
  panner.coneInnerAngle = 360; // omnidirectional -- a siren, not a speaker

  const gain = ctx.createGain();
  gain.gain.value = 0.0001; // faded up once the buffer is actually playing

  panner.connect(gain);
  gain.connect(master);

  v = {
    id: cfg.id,
    panner: panner,
    gain: gain,
    node: null,
    volume: cfg.volume === undefined ? 1.0 : cfg.volume,
    fadeInMs: cfg.fadeInMs || 2500,
    pos: { x: 0, y: 0, z: 0 },
    target: { x: 0, y: 0, z: 0 },
    seeded: false,
    stopping: false,
    teardown: null,
  };
  sounds.set(cfg.id, v);

  loadBuffer(cfg.src).then((buf) => {
    if (!sounds.has(cfg.id) || v.stopping) return;
    const node = ctx.createBufferSource();
    node.buffer = buf;

    // Sirens loop until stopped ("till I stop the script"). The outpost
    // intruder alarm instead plays a FIXED NUMBER of times and falls silent --
    // cfg.plays. A Web Audio buffer source cannot be restarted once it has
    // ended, so each repeat needs a fresh node; `onended` re-arms one until the
    // count runs out, then stops the voice through the normal fade-out path so
    // it tears down like any other.
    const plays = Number(cfg.plays) || 0;
    node.loop = plays <= 0;

    if (!node.loop) {
        let remaining = plays - 1;
        const again = () => {
            if (!sounds.has(cfg.id) || v.stopping) return;

            if (remaining <= 0) {
                stopVoice(cfg.id, cfg.fadeOutMs);
                return;
            }

            remaining -= 1;
            const next = ctx.createBufferSource();
            next.buffer = buf;
            next.loop = false;
            next.onended = again;
            next.connect(panner);
            next.start(0);
            v.node = next;
        };
        node.onended = again;
    }

    // Resume the loop at the phase it would be at if it had genuinely been
    // playing since the raid started, instead of always starting at 0:00.
    // cfg.elapsed (seconds since raidStartedAt, computed in Lua) modulo the
    // buffer's own length is exactly "how far into the loop are we right now" --
    // this is what makes walking into a site's zone ten seconds into a raid
    // sound like catching an already-sounding siren, not triggering a new one.
    // Phase-lock only applies to a looping voice. A one-shot alarm you have
    // just walked into earshot of should start at 0:00, not halfway through.
    const offset = (node.loop && buf.duration > 0) ? ((cfg.elapsed || 0) % buf.duration) : 0;

    node.connect(panner);
    node.start(0, offset);
    v.node = node;
    v.gain.gain.setTargetAtTime(v.volume, ctx.currentTime, Math.max(v.fadeInMs / 3000, 0.01));
  }).catch(() => { sounds.delete(cfg.id); });

  return v;
}

function stopVoice(id, fadeMs) {
  const v = sounds.get(id);
  if (!v || v.stopping) return;
  v.stopping = true;

  const ms = (fadeMs === undefined ? 1800 : fadeMs);
  v.gain.gain.cancelScheduledValues(ctx.currentTime);
  v.gain.gain.setTargetAtTime(0.0001, ctx.currentTime, Math.max(ms / 3000, 0.01));

  v.teardown = setTimeout(() => {
    if (!v.stopping) return; // resurrected while fading out
    if (v.node) { try { v.node.stop(); } catch (e) {} try { v.node.disconnect(); } catch (e) {} }
    try { v.panner.disconnect(); } catch (e) {}
    try { v.gain.disconnect(); } catch (e) {}
    if (sounds.get(id) === v) sounds.delete(id);
  }, ms + 60);
}

function stopAllVoices(fadeMs) {
  Array.from(sounds.keys()).forEach((id) => stopVoice(id, fadeMs));
}

function setVoicePosition(id, x, y, z) {
  const v = sounds.get(id);
  if (!v) return;
  v.target.x = x; v.target.y = y; v.target.z = z;
  if (!v.seeded) { // first sample: snap, so the siren doesn't glide in from the origin
    v.pos.x = x; v.pos.y = y; v.pos.z = z;
    v.seeded = true;
    applyPosition(v);
  }
}

function applyPosition(v) {
  const p = v.panner;
  if (p.positionX) {
    p.positionX.value = v.pos.x;
    p.positionY.value = v.pos.y;
    p.positionZ.value = v.pos.z;
  } else {
    p.setPosition(v.pos.x, v.pos.y, v.pos.z); // deprecated path, still needed on older CEF
  }
}

// =============================================================================
// FRAME LOOP -- eases each voice toward its latest reported position.
//
// Lua reports positions on a ~20Hz cadence (config.lua's orientationIntervalMs),
// not per frame -- SendNUIMessage is not free. Stepping the panner straight to
// each sample would sound like the siren stutters as the camera turns; easing
// toward it every animation frame keeps the panning smooth in between samples.
// =============================================================================

let lastFrame = performance.now();

function frame(now) {
  const dt = Math.min((now - lastFrame) / 1000, 0.25);
  lastFrame = now;

  if (sounds.size > 0) {
    // Exponential ease, framerate independent. 14/s converges in ~200ms, well
    // inside the ~50ms gap between Lua samples, so it tracks a turning camera
    // without reintroducing the stepping the easing exists to remove.
    const k = 1 - Math.exp(-14 * dt);
    sounds.forEach((v) => {
      if (!v.seeded) return;
      v.pos.x += (v.target.x - v.pos.x) * k;
      v.pos.y += (v.target.y - v.pos.y) * k;
      v.pos.z += (v.target.z - v.pos.z) * k;
      applyPosition(v);
    });
  }

  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// =============================================================================
// LUA BRIDGE
// =============================================================================

window.addEventListener('message', (event) => {
  const d = event.data || {};
  wake();

  switch (d.action) {
    case 'master_volume':
      // Lua now sends this every ~1s as the player moves (masterVolume * the
      // live zone-distance factor -- see client/main.lua's startRangeCheck),
      // not once at raid-start. An instant .value jump every second would
      // sound like small audible steps while driving away from the zone;
      // ramping toward it keeps that fade smooth between samples, the same
      // reasoning as the per-voice fade in/out below.
      if (typeof d.value === 'number') {
        master.gain.cancelScheduledValues(ctx.currentTime);
        master.gain.setTargetAtTime(d.value, ctx.currentTime, 0.6);
      }
      break;
    case 'sound_start':
      startVoice(d);
      break;
    case 'sound_pos_batch':
      (d.positions || []).forEach((p) => setVoicePosition(p.id, p.x, p.y, p.z));
      break;
    case 'sound_stop':
      stopVoice(d.id, d.fadeMs);
      break;
    case 'sound_stop_all':
      stopAllVoices(d.fadeMs);
      break;
  }
});

// Announce ourselves. If Lua never sees this, the page did not load at all --
// which would otherwise leave every command printing success with no sound
// ever playing and nothing in the console to explain why.
report('ready', { audio: ctx.state, alive: true });
})();
