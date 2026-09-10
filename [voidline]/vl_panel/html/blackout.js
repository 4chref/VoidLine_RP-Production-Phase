/* =============================================================================
   vl_blackout -- countdown + audio cue

   The countdown is driven off a wall-clock deadline rather than by decrementing
   a counter, so it cannot drift if a tick is late or the tab is throttled.
   One interval at 250ms, no per-frame work.
   ========================================================================== */

(function () {
    'use strict';

    var hud   = document.getElementById('hud');
    var label = document.getElementById('label');
    var clock = document.getElementById('clock');
    var cue   = document.getElementById('cue');

    var ticker = null;      // countdown interval
    var fader = null;       // audio fade interval
    var soundStop = null;   // timeout that ends the cue
    var endsAt = 0;
    var urgentAt = 30;

    function clearTimers() {
        if (ticker) { clearInterval(ticker); ticker = null; }
        if (fader) { clearInterval(fader); fader = null; }
        if (soundStop) { clearTimeout(soundStop); soundStop = null; }
    }

    function format(totalSeconds) {
        var s = Math.max(0, Math.floor(totalSeconds));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ':' + (r < 10 ? '0' : '') + r;
    }

    function tick() {
        var left = (endsAt - Date.now()) / 1000;
        clock.textContent = format(left);
        hud.classList.toggle('is-urgent', left <= urgentAt);
        if (left <= 0) {
            clearInterval(ticker);
            ticker = null;
        }
    }

    /* Resource name is resolved rather than hardcoded so renaming the folder
       does not silently break the callback. */
    var RESOURCE = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'vl_blackout';

    var endReported = false;

    /* The client drives the unstable-grid flicker off this, so it must fire
       exactly once per blackout however the track happens to finish: playing
       out naturally, or being faded by the safety cap. */
    function reportSoundEnded() {
        if (endReported) return;
        endReported = true;
        fetch('https://' + RESOURCE + '/soundEnded', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: '{}'
        }).catch(function () {});
    }

    /* ---- audio ----------------------------------------------------------- */

    function fadeTo(target, seconds, onDone) {
        if (fader) clearInterval(fader);
        var steps = Math.max(1, Math.round(seconds * 20));
        var start = cue.volume;
        var i = 0;
        fader = setInterval(function () {
            i++;
            var v = start + (target - start) * (i / steps);
            cue.volume = Math.min(1, Math.max(0, v));
            if (i >= steps) {
                clearInterval(fader);
                fader = null;
                if (onDone) onDone();
            }
        }, 50);
    }

    function startSound(cfg) {
        if (!cfg) return;

        cue.src = cfg.file;
        cue.loop = false;         // plays once at the start, then silence
        cue.currentTime = 0;
        cue.volume = 0;
        cue.onended = reportSoundEnded;

        // A track that fails to load would otherwise never report, leaving the
        // client to sit on its cap. Treat a load error as "no audio".
        cue.onerror = reportSoundEnded;

        var p = cue.play();
        if (p && p.catch) {
            p.then(function () {
                fadeTo(cfg.volume, cfg.fadeIn || 0.1);
            }).catch(function () {
                // Autoplay refused (should not happen inside CEF, but be safe):
                // retry on the first interaction of any kind.
                var unlock = function () {
                    cue.play().then(function () { fadeTo(cfg.volume, cfg.fadeIn || 0.1); })
                              .catch(function () {});
                    window.removeEventListener('keydown', unlock);
                    window.removeEventListener('mousemove', unlock);
                };
                window.addEventListener('keydown', unlock);
                window.addEventListener('mousemove', unlock);
            });
        } else {
            fadeTo(cfg.volume, cfg.fadeIn || 0.1);
        }

        // Safety cap only. The cue plays once and normally ends on its own well
        // before this fires; this exists so a track LONGER than the configured
        // window still gets faded out instead of running past it.
        var ms = Math.max(0, (cfg.duration || 0) * 1000 - (cfg.fadeOut || 0) * 1000);
        soundStop = setTimeout(function () {
            if (cue.paused || cue.ended) return;
            fadeTo(0, cfg.fadeOut || 1, function () {
                cue.pause();
                reportSoundEnded();
            });
        }, ms);
    }

    function stopSound(fadeOut) {
        if (soundStop) { clearTimeout(soundStop); soundStop = null; }
        if (cue.paused) return;
        fadeTo(0, fadeOut || 0.6, function () {
            cue.pause();
            cue.currentTime = 0;
        });
    }

    /* ---- messages -------------------------------------------------------- */

    function start(data) {
        clearTimers();
        endReported = false;

        urgentAt = data.urgentAt || 30;
        endsAt = Date.now() + (Number(data.seconds) || 0) * 1000;

        if (data.label) label.textContent = data.label;

        if (data.showTimer !== false) {
            hud.hidden = false;
            hud.classList.remove('is-out', 'is-urgent');
            tick();
            ticker = setInterval(tick, 250);
        } else {
            hud.hidden = true;
        }

        startSound(data.sound);
    }

    function stop() {
        clearTimers();
        stopSound(0.6);

        if (!hud.hidden) {
            hud.classList.add('is-out');
            setTimeout(function () {
                hud.hidden = true;
                hud.classList.remove('is-out');
            }, 400);
        }
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action === 'start') start(data);
        else if (data.action === 'stop') stop();
    });
})();
