const RESOURCE_NAME = 'vl_dailygoods';

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

let allItems = [];
let activeCategory = null;

function renderTabs(categories) {
    const tabs = document.getElementById('shopTabs');
    tabs.innerHTML = categories.map(cat => `
        <div class="shop-tab${cat.id === activeCategory ? ' active' : ''}" data-category="${cat.id}">${cat.label}</div>
    `).join('');

    tabs.querySelectorAll('.shop-tab').forEach(el => {
        el.addEventListener('click', () => {
            activeCategory = el.dataset.category;
            tabs.querySelectorAll('.shop-tab').forEach(t => t.classList.toggle('active', t.dataset.category === activeCategory));
            renderGrid();
        });
    });
}

function renderGrid() {
    const grid = document.getElementById('shopGrid');
    const items = activeCategory ? allItems.filter(i => i.category === activeCategory) : allItems;

    grid.innerHTML = items.map(item => `
        <div class="shop-item" data-item="${item.name}">
            <img src="${itemIconUrl(item.name)}" alt="" onerror="this.style.visibility='hidden'">
            <div class="shop-item-name">${item.label}</div>
            <div class="shop-item-price">${item.price} core</div>
        </div>
    `).join('');

    grid.querySelectorAll('.shop-item').forEach(el => {
        el.addEventListener('click', () => buyItem(el));
    });
}

function buyItem(el) {
    if (el.classList.contains('disabled')) return;
    el.classList.add('disabled');
    fetch(`https://${GetParentResourceName()}/buy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: el.dataset.item })
    })
        .then(res => res.json())
        .then(result => {
            el.classList.remove('disabled');
            if (result && result.success) {
                showNotification('success', `Bought for ${result.price} core`);
            } else {
                showNotification('error', reasonMessage(result && result.reason));
            }
        })
        .catch(() => {
            el.classList.remove('disabled');
            showNotification('error', 'Failed to buy item');
        });
}

function reasonMessage(reason) {
    switch (reason) {
        case 'cant_afford': return "You can't afford that";
        case 'no_space': return 'Not enough inventory space';
        case 'too_far': return 'Too far from the trader';
        default: return 'Failed to buy item';
    }
}

function closeShop() {
    document.getElementById('shop').classList.add('hidden');
    document.body.classList.remove('shop-open');
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

document.getElementById('closeBtn').addEventListener('click', closeShop);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !document.getElementById('shop').classList.contains('hidden')) {
        closeShop();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'open') {
        allItems = data.items || [];
        activeCategory = (data.categories && data.categories[0] && data.categories[0].id) || null;
        document.getElementById('shopTitle').textContent = data.label || 'Daily Goods';
        renderTabs(data.categories || []);
        renderGrid();
        document.getElementById('shop').classList.remove('hidden');
        document.body.classList.add('shop-open');
    } else if (data.action === 'close') {
        document.getElementById('shop').classList.add('hidden');
        document.body.classList.remove('shop-open');
    }
});
