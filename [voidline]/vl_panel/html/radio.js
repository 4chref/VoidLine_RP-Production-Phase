/* =============================================================================
   vl_panel -- air raid radio transmission

   Driven by one `radio_show` message from client/airraid.lua. Passive: no NUI
   focus, no input, no callbacks back to Lua.

   Wrapped in an IIFE for the same reason airraid.js is -- every script on this
   page shares one global scope, and `ctx` / `RESOURCE` are already taken.
   ============================================================================= */

(function () {
    'use strict';

    const scene = document.getElementById('radio-scene');
    if (!scene) return;

    const el = {
        channel: document.getElementById('radio-channel'),
        text: document.getElementById('radio-text'),
        caret: document.getElementById('radio-caret'),
    };

    let typeTimer = null;
    let holdTimer = null;
    let outTimer = null;
    let audio = null;

    function stopAudio() {
        if (!audio) return;
        try { audio.pause(); } catch (e) { /* already gone */ }
        audio = null;
    }

    function hide() {
        clearTimeout(typeTimer);
        clearTimeout(holdTimer);
        clearTimeout(outTimer);
        stopAudio();

        scene.classList.add('is-out');
        // Matches the 0.5s exit animation in radio.css.
        outTimer = setTimeout(() => {
            scene.hidden = true;
            scene.classList.remove('is-out');
        }, 520);
    }

    function show(d) {
        clearTimeout(typeTimer);
        clearTimeout(holdTimer);
        clearTimeout(outTimer);
        stopAudio();

        const text = String(d.text || '');
        const typeMs = typeof d.typeMs === 'number' ? d.typeMs : 28;
        const holdMs = typeof d.holdMs === 'number' ? d.holdMs : 12000;

        el.channel.textContent = d.channel || 'EMERGENCY BROADCAST';
        el.text.textContent = '';
        el.caret.hidden = false;

        scene.classList.remove('is-out');
        scene.hidden = false;

        if (d.sound) {
            try {
                audio = new Audio(d.sound);
                audio.volume = typeof d.volume === 'number' ? d.volume : 0.7;
                const p = audio.play();
                if (p && typeof p.catch === 'function') p.catch(() => {});
            } catch (e) { /* no sound, the panel still runs */ }
        }

        // Typed one character at a time with setTimeout rather than a CSS
        // steps() animation: the message is server-supplied, so its length is
        // not known when the stylesheet is written, and a steps() count baked
        // into CSS would desync the caret the moment the text changed.
        let i = 0;
        (function step() {
            if (i >= text.length) {
                // The caret stays for a beat after the last character, then
                // goes -- a still caret under finished text reads as "waiting
                // for more", which this transmission is not.
                typeTimer = setTimeout(() => { el.caret.hidden = true; }, 900);
                return;
            }
            el.text.textContent += text.charAt(i);
            i += 1;
            typeTimer = setTimeout(step, typeMs);
        })();

        // Hold is measured from the END of typing, so a long message is not
        // swallowed by a fixed timer that started while it was still arriving.
        holdTimer = setTimeout(hide, text.length * typeMs + holdMs);
    }

    window.addEventListener('message', (event) => {
        const d = event.data || {};
        if (d.action === 'radio_show') show(d);
        else if (d.action === 'radio_hide') hide();
    });
})();
