// NOTE: the marketplace shares this page and its listener switches on
// data.action === 'open'. An unnamespaced 'open' here opened BOTH panels
// at once, stacked. The shop grid's actions are prefixed for that reason.
// Wrapped: the marketplace script shares this page and defines its own
// globals (showNotification, closeShop...). An IIFE keeps the two apart.
(function () {
const RESOURCE_NAME = 'vl_outpost';

function GetParentResourceName() {
    return RESOURCE_NAME;
}

function itemIconUrl(name) {
    return `nui://ox_inventory/web/images/${name}.png`;
}

function showNotification(type, message) {
    const container = document.getElementById('op-notificationContainer');
    const el = document.createElement('div');
    el.className = `op-notification ${type}`;
    el.textContent = message;
    container.appendChild(el);
    setTimeout(() => el.remove(), 3500);
}

let allItems = [];
let layout = 'grid';
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

    // Two layouts off the same data. 'list' stacks full-width rows with a
    // large image and the description beside it -- used by the suit dealer,
    // where there are only a few items and each needs explaining.
    if (layout === 'list') {
        grid.className = 'shop-list';
        grid.innerHTML = items.map(item => `
            <div class="shop-row${item.outside ? ' disabled' : ''}" data-item="${item.name}" data-slot="${item.slot ?? ''}">
                <img src="${itemIconUrl(item.name)}" alt="" onerror="this.style.visibility='hidden'">
                <div class="shop-row-text">
                    <div class="shop-row-name">${item.label}</div>
                    <div class="shop-row-desc">${item.description ?? item.sub ?? ''}</div>
                </div>
                <div class="shop-row-price">${item.outside ? 'Outside' : (item.price > 0 ? item.price + ' core' : (item.slot ? 'Retrieve' : 'Free'))}</div>
            </div>
        `).join('');

        grid.querySelectorAll('.shop-row').forEach(el => {
            el.addEventListener('click', () => buyItem(el));
        });
        return;
    }

    grid.className = 'shop-grid';
    grid.innerHTML = items.map(item => `
        <div class="shop-item" data-item="${item.name}" data-slot="${item.slot ?? ''}">
            <img src="${itemIconUrl(item.name)}" alt="" onerror="this.style.visibility='hidden'">
            <div class="shop-item-name">${item.label}</div>
            <div class="shop-item-sub">${item.sub ?? ''}</div>
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
    fetch(`https://${GetParentResourceName()}/outpost:buy`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        // slot travels with the click: the gunsmith prices a SPECIFIC weapon,
        // and two of the same gun can be in different condition.
        body: JSON.stringify({ name: el.dataset.item, slot: el.dataset.slot || null })
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
        case 'not_owned': return 'You do not own that vehicle';
        case 'already_out': return 'That vehicle is already out';
        case 'spots_full': return 'The retrieve points are occupied';
        case 'purchase_failed': return 'Purchase failed';
        default: return 'Failed to buy item';
    }
}

function closeShop() {
    document.getElementById('shop').classList.add('hidden');
    document.body.classList.remove('shop-open');
    fetch(`https://${GetParentResourceName()}/outpost:close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

document.getElementById('opCloseBtn').addEventListener('click', closeShop);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !document.getElementById('shop').classList.contains('hidden')) {
        closeShop();
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'outpost:open') {
        allItems = data.items || [];
        layout = data.layout || 'grid';
        activeCategory = (data.categories && data.categories[0] && data.categories[0].id) || null;
        document.getElementById('shopTitle').textContent = data.label || 'Outpost';
        renderTabs(data.categories || []);
        renderGrid();
        document.getElementById('shop').classList.remove('hidden');
        document.body.classList.add('shop-open');
    } else if (data.action === 'outpost:close') {
        document.getElementById('shop').classList.add('hidden');
        document.body.classList.remove('shop-open');
    }
});

})();
