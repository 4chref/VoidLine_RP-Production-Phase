const RESOURCE_NAME = 'vl_armory';

function GetParentResourceName() {
    return RESOURCE_NAME;
}

function itemIconUrl(name) {
    return `nui://ox_inventory/web/images/${name}.png`;
}

function showNotification(type, message) {
    const container = document.getElementById('notificationContainer');
    const el = document.createElement('div');
    el.className = `notification ${type}`;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(() => el.remove(), 3500);
}

function renderItems(items) {
    const grid = document.getElementById('armoryGrid');
    grid.innerHTML = items.map(item => `
        <div class="armory-item" data-item="${item.name}">
            <img src="${itemIconUrl(item.name)}" alt="" onerror="this.style.visibility='hidden'">
            <div class="armory-item-name">${item.label}</div>
        </div>
    `).join('');

    grid.querySelectorAll('.armory-item').forEach(el => {
        el.addEventListener('click', () => takeItem(el));
    });
}

function takeItem(el) {
    if (el.classList.contains('disabled')) return;
    el.classList.add('disabled');
    fetch(`https://${GetParentResourceName()}/take`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: el.dataset.item })
    })
        .then(res => res.json())
        .then(success => {
            el.classList.remove('disabled');
            if (!success) {
                showNotification('error', 'Failed to take item');
            }
        })
        .catch(() => {
            el.classList.remove('disabled');
            showNotification('error', 'Failed to take item');
        });
}

function closeArmory() {
    document.getElementById('armory').classList.add('hidden');
    document.body.classList.remove('armory-open');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

document.getElementById('closeBtn').addEventListener('click', closeArmory);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !document.getElementById('armory').classList.contains('hidden')) {
        closeArmory();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'open') {
        renderItems(data.items || []);
        document.getElementById('armory').classList.remove('hidden');
        document.body.classList.add('armory-open');
    } else if (data.action === 'close') {
        document.getElementById('armory').classList.add('hidden');
        document.body.classList.remove('armory-open');
    }
});
