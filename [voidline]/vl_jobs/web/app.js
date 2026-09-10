/* =============================================================================
   vl_jobs NUI -- the foreman's board

   Replaces an ox_lib context menu. The Lua side sends one `open` message
   carrying every job plus the current shift state; this file owns selection and
   nothing else. Starting or quitting a shift posts back and closes -- no state
   is decided here, so the menu can never disagree with the server.
   ============================================================================= */

(function () {
    'use strict';

    const RESOURCE = (typeof GetParentResourceName === 'function')
        ? GetParentResourceName()
        : 'vl_jobs';

    const post = (name, data) =>
        fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => { /* offline preview */ });

    const $ = (id) => document.getElementById(id);

    const el = {
        root:       $('root'),
        brandSub:   $('brandSub'),
        list:       $('jobList'),
        title:      $('detailTitle'),
        img:        $('detailImg'),
        desc:       $('detailDesc'),
        stats:      $('statGrid'),
        cta:        $('ctaBtn'),
        ctaLabel:   $('ctaLabel'),
        ctaHint:    $('ctaHint'),
        quit:       $('quitBtn'),
    };

    let jobs = [];
    let activeKey = null;
    let running = null;   // key of the shift in progress, or null

    /* -------------------------------------------------------------------- */

    /* ox_inventory serves its item art over nui://, so any image already in
       web/images/ can be used here without shipping a copy. Missing art is
       hidden rather than left as a broken-image glyph. */
    const IMG = (name) => `nui://ox_inventory/web/images/${name}.png`;

    // af-camping's ingredient slot: big value on top, small caps label under.
    const slot = (label, value) => {
        const d = document.createElement('div');
        d.className = 'ingredient-slot';
        const v = document.createElement('span');
        v.className = 'ingredient-slot__count';
        v.textContent = value;
        const k = document.createElement('span');
        k.className = 'ingredient-slot__name';
        k.textContent = label;
        d.append(v, k);
        return d;
    };

    function renderDetail() {
        const job = jobs.find((j) => j.key === activeKey);
        if (!job) return;

        el.title.textContent = job.label || '—';
        el.desc.textContent = job.description || '';

        if (job.image) {
            el.img.src = IMG(job.image);
            el.img.hidden = false;
            el.img.onerror = () => { el.img.hidden = true; };
        } else {
            el.img.hidden = true;
        }

        el.stats.innerHTML = '';
        el.stats.append(
            slot('Tasks', String(job.points ?? '—')),
            slot('Kit', job.tool || 'None'),
            slot('Pay', job.reward || '—'),
            slot('Per task', job.duration || '—'),
        );

        const isRunning = running === job.key;

        el.cta.disabled = !job.enabled || isRunning;
        el.ctaLabel.textContent = isRunning ? 'On shift' : (job.enabled ? 'Start shift' : 'Unavailable');

        el.ctaHint.textContent = isRunning
            ? 'Head to the marked points'
            : (job.enabled ? 'Equipment is handed out on the spot' : 'The foreman has nothing like this going');
    }

    function renderList() {
        el.list.innerHTML = '';

        jobs.forEach((job) => {
            const b = document.createElement('button');
            b.type = 'button';
            b.className = 'recipe-card';
            b.disabled = !job.enabled;

            if (job.key === activeKey) b.classList.add('is-active');
            if (running === job.key)   b.classList.add('is-running');
            if (!job.enabled)          b.classList.add('is-locked');

            const icon = document.createElement('span');
            icon.className = 'recipe-card__icon';
            if (job.image) {
                const im = document.createElement('img');
                im.className = 'recipe-card__img';
                im.src = IMG(job.image);
                im.alt = '';
                im.onerror = () => im.remove();
                icon.appendChild(im);
            }

            const body = document.createElement('span');
            body.className = 'recipe-card__body';

            const name = document.createElement('span');
            name.className = 'recipe-card__name';
            name.textContent = job.label || job.key;

            const desc = document.createElement('span');
            desc.className = 'recipe-card__desc';
            desc.textContent = job.description || '';

            body.append(name, desc);

            const tag = document.createElement('span');
            tag.className = 'recipe-card__tag';
            tag.textContent = running === job.key ? 'ON SHIFT' : (job.reward || '');

            b.append(icon, body, tag);

            // Selecting only changes what the right panel shows. Taking the
            // shift is the CTA -- one click should never commit you to work.
            b.addEventListener('click', () => {
                if (!job.enabled) return;
                activeKey = job.key;
                renderList();
                renderDetail();
            });

            el.list.appendChild(b);
        });
    }

    /* -------------------------------------------------------------------- */

    function close() {
        el.root.classList.remove('is-open');
        // Matches the 0.18s fade in style.css; hiding on the same frame would
        // cut it off.
        setTimeout(() => { el.root.hidden = true; }, 200);
    }

    el.cta.addEventListener('click', () => {
        if (el.cta.disabled || !activeKey) return;
        post('start', { key: activeKey });
        close();
    });

    el.quit.addEventListener('click', () => {
        post('quit', {});
        close();
    });

    const dismiss = () => { post('close', {}); close(); };

    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') dismiss();
    });

    /* -------------------------------------------------------------------- */

    window.addEventListener('message', (event) => {
        const d = event.data || {};
        if (d.action !== 'open') return;

        jobs = Array.isArray(d.jobs) ? d.jobs : [];
        running = d.running || null;

        el.brandSub.textContent = d.subtitle || 'Foreman’s board';

        // Open on the shift in progress if there is one, otherwise the first
        // one that can actually be taken -- never on a locked card, which would
        // greet the player with a dead panel.
        activeKey = running
            || (jobs.find((j) => j.enabled) || jobs[0] || {}).key
            || null;

        // The quit button only exists when there is something to quit.
        el.quit.hidden = !running;

        renderList();
        renderDetail();

        el.root.hidden = false;
        requestAnimationFrame(() => {
            requestAnimationFrame(() => el.root.classList.add('is-open'));
        });
    });
})();
