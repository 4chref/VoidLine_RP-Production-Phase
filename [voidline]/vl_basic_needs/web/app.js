(function () {
    const hud = document.getElementById('hud');
    const rows = {
        poop: document.getElementById('row-poop'),
        sleep: document.getElementById('row-sleep'),
        pee: document.getElementById('row-pee')
    };

    let lastValues = { poop: -1, sleep: -1, pee: -1 };

    function severityClass(value) {
        if (value >= 100) return 'crit';
        if (value >= 75) return 'high';
        if (value >= 50) return 'warn';
        return '';
    }

    function filledPillCount(value) {
        // 0-24 -> 1, 25-49 -> 2, 50-74 -> 3, 75-100 -> 4, and 0 -> 0
        if (value <= 0) return 0;
        if (value < 25) return 1;
        if (value < 50) return 2;
        if (value < 75) return 3;
        return 4;
    }

    function updateRow(name, value) {
        const row = rows[name];
        if (!row) return;

        row.classList.remove('warn', 'high', 'crit');
        const sev = severityClass(value);
        if (sev) row.classList.add(sev);

        const filled = filledPillCount(value);
        const pills = row.querySelectorAll('.pill');
        pills.forEach((pill, i) => {
            if (i < filled) {
                pill.classList.add('filled');
            } else {
                pill.classList.remove('filled');
            }
        });

        const pct = row.querySelector('.need-pct');
        if (pct) pct.textContent = Math.round(value) + '%';
    }

    function applyUpdate(needs) {
        if (!needs) return;
        ['poop', 'sleep', 'pee'].forEach((key) => {
            const val = Math.max(0, Math.min(100, Number(needs[key]) || 0));
            if (val !== lastValues[key]) {
                lastValues[key] = val;
                updateRow(key, val);
            }
        });
    }

    function setPosition(position) {
        hud.classList.remove('position-bottom-right', 'position-bottom-left', 'position-top-right', 'position-top-left', 'position-middle-right', 'position-middle-left');
        hud.classList.add('position-' + (position || 'middle-right'));
    }

    window.addEventListener('message', (event) => {
        const data = event.data;
        if (!data || !data.action) return;

        switch (data.action) {
            case 'update':
                applyUpdate(data.needs);
                break;
            case 'setPosition':
                setPosition(data.position);
                break;
        }
    });

    // tell the client script the UI is ready to receive messages
    const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'basic_needs';
    fetch(`https://${resourceName}/ready`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    }).catch(() => {});
})();
