/* =============================================================================
   vl_identity NUI

   Three surfaces on one page:
     intake    -- sex + height, takes NUI focus
     arrival   -- post-spawn splash, passive, dismisses itself
     card      -- passive ID card overlay, never takes focus

   The blocking "identity reveal" screen that used to sit between the two was
   removed -- the identity number is now the arrival splash's headline, so it
   is announced over live gameplay instead of stopping the flow for it.

   The Lua side drives all of it via SendNUIMessage and waits on the fetch
   callbacks below, so nothing here decides when a screen closes on its own.
   ============================================================================= */

(function () {
    'use strict';

    const RESOURCE = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'vl_identity';

    const post = (name, data) =>
        fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => { /* offline preview */ });

    const $ = (id) => document.getElementById(id);

    const el = {
        arrival:       $('arrival'),
        arrEyebrow:    $('arrEyebrow'),
        arrTitle:      $('arrTitle'),
        arrDesc:       $('arrDesc'),
        arrLines:      $('arrLines'),

        intake:        $('intake'),
        intakeEyebrow: $('intakeEyebrow'),
        intakeHeading: $('intakeHeading'),
        intakeSub:     $('intakeSubtitle'),
        sexChoices:    $('sexChoices'),
        heightRange:   $('heightRange'),
        heightVal:     $('heightVal'),
        heightFill:    $('heightFill'),
        heightMinLbl:  $('heightMinLbl'),
        heightMaxLbl:  $('heightMaxLbl'),
        submit:        $('intakeSubmit'),
        hint:          $('intakeHint'),

        card:          $('card'),
        photo:         $('photo'),
        vid:           $('vid'),
        vsex:          $('vsex'),
    };

    /* =====================================================================
       Screen helpers
       ===================================================================== */

    // hide() finishes on a timer, so a screen reopened inside that window would
    // otherwise be hidden again by the stale timeout. The creation flow retries
    // the intake on a failed server call, which is exactly that case.
    const hideTimers = new WeakMap();

    function show(node) {
        const pending = hideTimers.get(node);
        if (pending) {
            clearTimeout(pending);
            hideTimers.delete(node);
        }
        node.classList.remove('is-out');
        node.hidden = false;
    }

    function hide(node) {
        if (node.hidden || hideTimers.has(node)) return;
        node.classList.add('is-out');
        hideTimers.set(node, setTimeout(() => {
            node.hidden = true;
            node.classList.remove('is-out');
            hideTimers.delete(node);
        }, 400));
    }

    /* =====================================================================
       INTAKE
       ===================================================================== */

    let sex = null;
    let submitted = false;

    function paintSlider() {
        const min = +el.heightRange.min;
        const max = +el.heightRange.max;
        const val = +el.heightRange.value;
        el.heightVal.textContent = val;
        el.heightFill.style.width = ((val - min) / (max - min) * 100) + '%';
    }

    function paintSubmit() {
        el.submit.disabled = sex === null || submitted;
        el.hint.classList.toggle('is-hidden', sex !== null);
    }

    el.sexChoices.addEventListener('click', (e) => {
        const btn = e.target.closest('.choice');
        if (!btn || submitted) return;
        sex = btn.dataset.value;
        for (const b of el.sexChoices.querySelectorAll('.choice')) {
            b.classList.toggle('is-active', b === btn);
        }
        paintSubmit();
    });

    el.heightRange.addEventListener('input', paintSlider);

    el.submit.addEventListener('click', () => {
        if (sex === null || submitted) return;
        submitted = true;
        paintSubmit();
        post('intakeSubmit', { sex: sex, height: +el.heightRange.value });
        hide(el.intake);
    });

    function openIntake(cfg) {
        cfg = cfg || {};
        sex = null;
        submitted = false;

        if (cfg.text) {
            if (cfg.text.eyebrow)  el.intakeEyebrow.textContent = cfg.text.eyebrow;
            if (cfg.text.heading)  el.intakeHeading.textContent = cfg.text.heading;
            if (cfg.text.subtitle) el.intakeSub.textContent     = cfg.text.subtitle;
        }

        const min = cfg.heightMin || 140;
        const max = cfg.heightMax || 210;
        el.heightRange.min = min;
        el.heightRange.max = max;
        el.heightRange.value = cfg.heightDefault || Math.round((min + max) / 2);
        el.heightMinLbl.textContent = min;
        el.heightMaxLbl.textContent = max;

        for (const b of el.sexChoices.querySelectorAll('.choice')) b.classList.remove('is-active');

        paintSlider();
        paintSubmit();
        show(el.intake);
    }

    /* =====================================================================
       ID CARD
       ===================================================================== */

    let cardTimer = null;

    function showCard(card, duration) {
        card = card || {};
        el.vid.textContent  = card.id || '---';
        el.vsex.textContent = (card.sex || '').toUpperCase() || '--';

        if (card.photo && card.photo.length > 100) {
            const src = card.photo.startsWith('data:')
                ? card.photo
                : 'data:image/jpeg;base64,' + card.photo;
            el.photo.style.backgroundImage = `url(${src})`;
            el.photo.classList.remove('empty');
        } else {
            el.photo.style.backgroundImage = 'none';
            el.photo.classList.add('empty');
        }

        el.card.classList.add('visible');
        clearTimeout(cardTimer);
        cardTimer = setTimeout(() => el.card.classList.remove('visible'), duration || 8000);
    }

    /* =====================================================================
       Arrival
       ===================================================================== */

    let arrivalTimer = null;
    let arrivalAudio = null;

    /**
     * The discovery sting is played from af-expeditions rather than copied
     * into this resource: nui:// can read any file another resource lists in
     * its files{} block, and af-expeditions publishes `web/build/**` wholesale.
     * That keeps one copy of a paid script's asset on disk instead of two, and
     * means it cannot drift out of step if that resource updates.
     *
     * Everything is wrapped so a missing af-expeditions -- or a browser that
     * refuses the autoplay -- costs the screen nothing but its sound.
     */
    const playArrivalSound = (src, volume) => {
        if (!src) return;
        try {
            arrivalAudio = new Audio(src);
            arrivalAudio.volume = typeof volume === 'number' ? volume : 0.6;
            const p = arrivalAudio.play();
            if (p && typeof p.catch === 'function') p.catch(() => {});
        } catch (e) { /* no sound, screen still runs */ }
    };

    function showArrival(data) {
        clearTimeout(arrivalTimer);

        const d = data || {};
        if (d.eyebrow) el.arrEyebrow.textContent = d.eyebrow;
        if (d.title)   el.arrTitle.textContent   = d.title;
        if (d.desc)    el.arrDesc.textContent    = d.desc;

        /* `duration` is TOTAL time on screen -- first frame of the fade-in to
           last frame of the fade-out -- because that is the only number anyone
           watching the card can actually measure. The hold is derived from it.

           It used to mean "time before the fade-out starts", which made the
           card outlive its own setting by a fade and made 3000 feel like a
           blink: half a second arriving, half a second leaving, and only about
           two seconds of it actually readable. */
        const total = typeof d.duration === 'number' ? d.duration : 7000;
        const fade  = typeof d.fade === 'number' ? d.fade : 900;

        // Never let the two fades eat the whole card. At the floor it still
        // reads as a deliberate in-and-out rather than a flicker.
        const hold = Math.max(600, total - fade * 2);

        // One source of truth: the CSS transition reads this variable, and the
        // timers below use the same number.
        el.arrival.style.setProperty('--arr-fade', `${fade}ms`);

        el.arrLines.innerHTML = '';
        const lines = Array.isArray(d.lines) ? d.lines : [];

        /* The ladder is derived from the hold rather than fixed, so the lines
           always finish landing while the card is still still -- with a longer
           card they breathe, with a shorter one they tighten up, and neither
           needs this file edited. Capped so a long card does not leave the last
           line arriving minutes in. */
        const step = Math.min(0.45, Math.max(0.18, (hold / 1000) * 0.12));

        lines.forEach((text, i) => {
            const li = document.createElement('li');
            li.textContent = text;
            li.style.animationDelay = `${(fade / 1000) + i * step}s`;
            el.arrLines.appendChild(li);
        });

        el.arrival.hidden = false;
        playArrivalSound(d.sound, d.volume);

        // One frame before adding the class, or the browser batches the
        // un-hide and the transition together and nothing animates.
        requestAnimationFrame(() => {
            requestAnimationFrame(() => el.arrival.classList.add('is-in'));
        });

        // Fade-in has to finish before the hold starts counting, or the card is
        // only readable for `hold` minus the time it spent arriving.
        arrivalTimer = setTimeout(() => {
            el.arrival.classList.remove('is-in');
            // +40ms so the element is not hidden on the exact frame the
            // transition ends, which can clip the last of the fade.
            arrivalTimer = setTimeout(() => { el.arrival.hidden = true; }, fade + 40);
        }, fade + hold);
    }

    /* =====================================================================
       Message router
       ===================================================================== */

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        switch (data.action) {
            case 'openIntake':   openIntake(data);              break;
            case 'showArrival':  showArrival(data);             break;
            case 'showCard':     showCard(data.card, data.duration); break;
            case 'closeAll':
                hide(el.intake);
                break;
        }
    });

    // Enter confirms the intake -- the flow has no cancel path, so there is
    // deliberately no Escape handler. The arrival splash is passive and takes
    // no focus, so it deliberately has no key handling at all.
    window.addEventListener('keydown', (e) => {
        if (e.key !== 'Enter') return;
        if (!el.intake.hidden) el.submit.click();
    });
})();
