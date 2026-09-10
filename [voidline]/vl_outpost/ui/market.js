let currentListings = [];
let currentBuyOrders = [];
let currentHistory = [];
let currentPickups = [];
let inventoryItems = [];
let allAvailableItems = []; // All available items from ox_inventory (filtered by server)
let availableItems = []; // Available items whitelist from config
let itemLabelMap = {}; // Map of item name -> label
let labelToNameMap = {}; // Map of item label -> name (for buy orders)
let confirmCallback = null; // Callback for confirmation dialog

// Initialize
document.addEventListener('DOMContentLoaded', function() {
    setupEventListeners();
    setupAutoRefresh();
    setupConfirmDialog();
});

// Setup event listeners
function setupEventListeners() {
    // Tab switching
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const tab = btn.dataset.tab;
            switchTab(tab);
        });
    });

    // Close button
    document.getElementById('closeBtn').addEventListener('click', () => {
        closeMarketplace();
    });

    // ESC key to close (only if confirmation dialog is not open)
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            const confirmDialog = document.getElementById('confirmDialog');
            if (!confirmDialog.classList.contains('hidden')) {
                // Let confirmation dialog handle ESC
                return;
            }
            closeMarketplace();
        }
    });

    // Search functionality
    document.getElementById('listingsSearch').addEventListener('input', (e) => {
        filterListings(e.target.value);
    });

    document.getElementById('ordersSearch').addEventListener('input', (e) => {
        filterBuyOrders(e.target.value);
    });

    // Check if pickupsSearch exists before adding event listener
    const pickupsSearch = document.getElementById('pickupsSearch');
    if (pickupsSearch) {
        pickupsSearch.addEventListener('input', (e) => {
            filterPickups(e.target.value);
        });
    }

    // Sell form
    document.getElementById('sellBtn').addEventListener('click', () => {
        handleSellItem();
    });

    // Toggle between "sell for core" and "trade for another item"
    const sellPaymentType = document.getElementById('sellPaymentType');
    if (sellPaymentType) {
        sellPaymentType.addEventListener('change', updateSellPaymentFields);
        updateSellPaymentFields();
    }

    setupAllIconDropdowns();

    // Create order form
    document.getElementById('orderBtn').addEventListener('click', () => {
        handleCreateBuyOrder();
    });

    // Toggle between "pay with core" and "trade another item"
    const orderPaymentType = document.getElementById('orderPaymentType');
    if (orderPaymentType) {
        orderPaymentType.addEventListener('change', updateOrderPaymentFields);
        updateOrderPaymentFields();
    }

    // Order total calculation
    const orderQuantity = document.getElementById('orderQuantity');
    const orderPrice = document.getElementById('orderPrice');
    orderQuantity.addEventListener('input', updateOrderTotal);
    orderPrice.addEventListener('input', updateOrderTotal);
    
    // Item selection for selling
    const sellItemSelect = document.getElementById('sellItemSelect');
    sellItemSelect.addEventListener('change', function() {
        updateSellItemQuantity();
    });

    // History filters
    document.getElementById('applyHistoryFilter').addEventListener('click', () => {
        applyHistoryFilters();
    });
    
    // History search - real-time filtering
    document.getElementById('historySearch').addEventListener('input', (e) => {
        applyHistoryFilters();
    });
    
    // History type filter - real-time filtering
    document.getElementById('historyType').addEventListener('change', () => {
        applyHistoryFilters();
    });
}

// Setup confirmation dialog
function setupConfirmDialog() {
    const confirmDialog = document.getElementById('confirmDialog');
    const confirmYes = document.getElementById('confirmYes');
    const confirmNo = document.getElementById('confirmNo');
    
    confirmYes.addEventListener('click', () => {
        if (confirmCallback) {
            confirmCallback(true);
            confirmCallback = null;
        }
        hideConfirmDialog();
    });
    
    confirmNo.addEventListener('click', () => {
        if (confirmCallback) {
            confirmCallback(false);
            confirmCallback = null;
        }
        hideConfirmDialog();
    });
    
    // Close on ESC key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !confirmDialog.classList.contains('hidden')) {
            if (confirmCallback) {
                confirmCallback(false);
                confirmCallback = null;
            }
            hideConfirmDialog();
        }
    });
}

// Show confirmation dialog
function showConfirmDialog(title, message, callback) {
    const confirmDialog = document.getElementById('confirmDialog');
    const confirmTitle = document.getElementById('confirmDialogTitle');
    const confirmMessage = document.getElementById('confirmDialogMessage');
    
    confirmTitle.textContent = title;
    confirmMessage.textContent = message;
    confirmCallback = callback;
    confirmDialog.classList.remove('hidden');
}

// Hide confirmation dialog
function hideConfirmDialog() {
    const confirmDialog = document.getElementById('confirmDialog');
    confirmDialog.classList.add('hidden');
}

// Switch tabs
function switchTab(tabName) {
    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.tab === tabName) {
            btn.classList.add('active');
        }
    });

    // Update tab content
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
    });

    const targetTab = document.getElementById(`${tabName}-tab`);
    if (targetTab) {
        targetTab.classList.add('active');
    }

    // Refresh data when switching to certain tabs
    if (tabName === 'listings' || tabName === 'buy-orders') {
        fetch('https://' + GetParentResourceName() + '/requestRefresh', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }
    
    // Load history when switching to history tab
    if (tabName === 'history') {
        fetch('https://' + GetParentResourceName() + '/getHistory', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ filters: {} })
        });
    }
}

// Get parent resource name (FiveM NUI)
// In FiveM NUI, GetParentResourceName is a native function
// We'll use a cached value to avoid issues
// Merged into vl_outpost 2026-09-02. This is the NUI callback target, so
// leaving it as 'vl_market' made every fetch go to a resource that no
// longer exists -- "TypeError: Failed to fetch" on every action.
const RESOURCE_NAME = 'vl_outpost';

function GetParentResourceName() {
    // In FiveM, the native GetParentResourceName is available
    // But to avoid recursion, we'll use the known resource name
    // If you need dynamic detection, uncomment the code below
    /*
    try {
        // Access native function through window or global
        const nativeFn = (window && window.GetParentResourceName) || (typeof GetParentResourceName !== 'undefined' ? GetParentResourceName : null);
        if (nativeFn && typeof nativeFn === 'function' && nativeFn !== GetParentResourceName) {
            return nativeFn();
        }
    } catch(e) {
        // Fall through
    }
    */
    return RESOURCE_NAME;
}

// Close marketplace
function closeMarketplace() {
    // Hide UI immediately
    document.getElementById('marketplace').classList.add('hidden');
    document.body.classList.remove('trader-open');

    // Send close callback to client
    fetch('https://' + GetParentResourceName() + '/close', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).catch(err => {
        console.error('Error closing marketplace:', err);
    });
}

// Update sell item quantity based on selected item
function updateSellItemQuantity() {
    const select = document.getElementById('sellItemSelect');
    const selectedValue = select.value;
    const quantityInput = document.getElementById('sellQuantity');
    const availableQty = document.getElementById('sellAvailableQty');
    
    if (selectedValue) {
        const item = inventoryItems.find(i => i.name === selectedValue);
        if (item) {
            availableQty.textContent = item.count;
            quantityInput.max = item.count;
            quantityInput.value = Math.min(parseInt(quantityInput.value) || 1, item.count);
        }
    } else {
        availableQty.textContent = '0';
        quantityInput.max = 1;
        quantityInput.value = 1;
    }
}

// Show/hide the price vs. trade-item fields based on the payment type select
function updateSellPaymentFields() {
    const isTrade = document.getElementById('sellPaymentType').value === 'trade';
    document.getElementById('sellPriceGroup').classList.toggle('hidden', isTrade);
    document.getElementById('sellTradeGroup').classList.toggle('hidden', !isTrade);
    document.getElementById('sellTradeQtyGroup').classList.toggle('hidden', !isTrade);
}

// ox_inventory item icons are served by that resource's own NUI page; a
// sibling resource can reach them through the nui:// scheme without
// duplicating any image assets here.
function itemIconUrl(name) {
    return `nui://ox_inventory/web/images/${name}.png`;
}

// Icon-dropdown picker factory: a real dropdown (not free text) listing
// every item the server allows, icon + label, with a search box since the
// full item list can be long. Used for the sell-tab's "item you want in
// return", and the buy-order tab's "item you want" and "item you're
// offering" -- three instances of the same widget, different element ids.
const iconDropdowns = {};

function createIconDropdown(key, ids) {
    const trigger = document.getElementById(ids.trigger);
    const panel = document.getElementById(ids.panel);
    const search = document.getElementById(ids.search);
    const list = document.getElementById(ids.list);
    const hiddenInput = document.getElementById(ids.hidden);
    const iconEl = document.getElementById(ids.icon);
    const labelEl = document.getElementById(ids.label);
    if (!trigger || !panel) return;

    function closePanel() {
        panel.classList.add('hidden');
    }

    function render(filterText) {
        list.innerHTML = '';

        const query = (filterText || '').toLowerCase().trim();
        const items = allAvailableItems
            .filter((item) => !query || (item.label || item.name).toLowerCase().includes(query) || item.name.toLowerCase().includes(query))
            .sort((a, b) => (a.label || a.name).localeCompare(b.label || b.name))
            .slice(0, 200); // keep the DOM light even on huge item lists

        if (items.length === 0) {
            const empty = document.createElement('div');
            empty.className = 'icon-select-empty';
            empty.textContent = 'No matching items';
            list.appendChild(empty);
            return;
        }

        items.forEach((item) => {
            const row = document.createElement('div');
            row.className = 'icon-select-item';

            const img = document.createElement('img');
            img.src = itemIconUrl(item.name);
            img.alt = '';
            img.addEventListener('error', () => { img.style.visibility = 'hidden'; });

            const span = document.createElement('span');
            span.textContent = item.label || item.name;

            row.appendChild(img);
            row.appendChild(span);
            row.addEventListener('click', () => selectItem(item));
            list.appendChild(row);
        });
    }

    function openPanel() {
        render(search.value);
        panel.classList.remove('hidden');
        search.focus();
    }

    function selectItem(item) {
        hiddenInput.value = item.name;
        labelEl.textContent = item.label || item.name;
        iconEl.src = itemIconUrl(item.name);
        iconEl.style.visibility = 'visible';
        closePanel();
    }

    function reset() {
        hiddenInput.value = '';
        labelEl.textContent = 'Select an item...';
        iconEl.src = '';
        iconEl.style.visibility = 'hidden';
    }

    trigger.addEventListener('click', (e) => {
        e.stopPropagation();
        if (panel.classList.contains('hidden')) openPanel(); else closePanel();
    });

    search.addEventListener('input', () => render(search.value));
    search.addEventListener('click', (e) => e.stopPropagation());

    document.addEventListener('click', (e) => {
        if (!panel.classList.contains('hidden') && !panel.contains(e.target) && e.target !== trigger) {
            closePanel();
        }
    });

    iconEl.addEventListener('error', () => { iconEl.style.visibility = 'hidden'; });

    iconDropdowns[key] = { reset };
}

function setupAllIconDropdowns() {
    createIconDropdown('sellTradeItem', {
        trigger: 'sellTradeItemTrigger', panel: 'sellTradeItemPanel', search: 'sellTradeItemSearch',
        list: 'sellTradeItemList', hidden: 'sellTradeItem', icon: 'sellTradeItemIcon', label: 'sellTradeItemLabel',
    });
    createIconDropdown('orderItem', {
        trigger: 'orderItemTrigger', panel: 'orderItemPanel', search: 'orderItemSearch',
        list: 'orderItemList', hidden: 'orderItemName', icon: 'orderItemIcon', label: 'orderItemLabel',
    });
    createIconDropdown('orderTradeItem', {
        trigger: 'orderTradeItemTrigger', panel: 'orderTradeItemPanel', search: 'orderTradeItemSearch',
        list: 'orderTradeItemList', hidden: 'orderTradeItem', icon: 'orderTradeItemIcon', label: 'orderTradeItemLabel',
    });
}

function resetTradeItemDropdown() {
    if (iconDropdowns.sellTradeItem) iconDropdowns.sellTradeItem.reset();
}

// Handle sell item
function handleSellItem() {
    const itemName = document.getElementById('sellItemSelect').value;
    const quantity = parseInt(document.getElementById('sellQuantity').value);
    const isTrade = document.getElementById('sellPaymentType').value === 'trade';

    if (!itemName || !quantity) {
        showNotification('error', 'Please fill in all fields');
        return;
    }

    if (quantity < 1) {
        showNotification('error', 'Quantity must be at least 1');
        return;
    }

    // Get item metadata
    const item = inventoryItems.find(i => i.name === itemName);
    const metadata = item ? (item.metadata || {}) : {};

    const payload = {
        item: itemName,
        quantity: quantity,
        metadata: metadata
    };

    if (isTrade) {
        const tradeItem = document.getElementById('sellTradeItem').value.trim();
        const tradeQuantity = parseInt(document.getElementById('sellTradeQuantity').value);

        if (!tradeItem) {
            showNotification('error', 'Select the item you want in return');
            return;
        }
        if (!tradeQuantity || tradeQuantity < 1) {
            showNotification('error', 'Trade quantity must be at least 1');
            return;
        }

        payload.price = 0;
        payload.tradeItem = tradeItem;
        payload.tradeQuantity = tradeQuantity;
    } else {
        const price = parseInt(document.getElementById('sellPrice').value);
        if (!price || price < 1) {
            showNotification('error', 'Price must be at least 1');
            return;
        }
        payload.price = price;
    }

    fetch('https://' + GetParentResourceName() + '/listItem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });

    // Clear form
    document.getElementById('sellItemSelect').value = '';
    document.getElementById('sellQuantity').value = '1';
    document.getElementById('sellPrice').value = '';
    resetTradeItemDropdown();
    document.getElementById('sellTradeQuantity').value = '1';
    document.getElementById('sellAvailableQty').textContent = '0';
}

// Handle create buy order
// Show/hide the price vs. trade-item fields on the buy-order form
function updateOrderPaymentFields() {
    const isTrade = document.getElementById('orderPaymentType').value === 'trade';
    document.getElementById('orderPriceGroup').classList.toggle('hidden', isTrade);
    document.getElementById('orderTradeGroup').classList.toggle('hidden', !isTrade);
    document.getElementById('orderTradeQtyGroup').classList.toggle('hidden', !isTrade);
    document.getElementById('orderPriceInfo').classList.toggle('hidden', isTrade);
}

function handleCreateBuyOrder() {
    const itemName = document.getElementById('orderItemName').value;
    const quantity = parseInt(document.getElementById('orderQuantity').value);
    const isTrade = document.getElementById('orderPaymentType').value === 'trade';

    if (!itemName || !quantity) {
        showNotification('error', 'Please fill in all fields');
        return;
    }

    if (quantity < 1) {
        showNotification('error', 'Quantity must be at least 1');
        return;
    }

    const payload = { item: itemName, quantity: quantity };

    if (isTrade) {
        const tradeItem = document.getElementById('orderTradeItem').value;
        const tradeQuantity = parseInt(document.getElementById('orderTradeQuantity').value);

        if (!tradeItem) {
            showNotification('error', 'Select the item you want to offer');
            return;
        }
        if (!tradeQuantity || tradeQuantity < 1) {
            showNotification('error', 'Trade quantity must be at least 1');
            return;
        }

        payload.price = 0;
        payload.tradeItem = tradeItem;
        payload.tradeQuantity = tradeQuantity;
    } else {
        const price = parseInt(document.getElementById('orderPrice').value);
        if (!price || price < 1) {
            showNotification('error', 'Price must be at least 1');
            return;
        }
        payload.price = price;
    }

    fetch('https://' + GetParentResourceName() + '/createBuyOrder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    });

    // Clear form
    if (iconDropdowns.orderItem) iconDropdowns.orderItem.reset();
    if (iconDropdowns.orderTradeItem) iconDropdowns.orderTradeItem.reset();
    document.getElementById('orderQuantity').value = '1';
    document.getElementById('orderPrice').value = '';
    document.getElementById('orderTradeQuantity').value = '1';
    updateOrderTotal();
}

// Update order total
function updateOrderTotal() {
    const quantity = parseInt(document.getElementById('orderQuantity').value) || 0;
    const price = parseInt(document.getElementById('orderPrice').value) || 0;
    const total = quantity * price;
    document.getElementById('orderTotal').textContent = total.toLocaleString();
}

// Render listings
// Barter listings (listing.tradeItem set) show what they want in trade
// instead of a core price -- shared by both listing table renderers.
function formatListingPrice(listing) {
    if (listing.tradeItem) {
        const icon = `<img class="row-price-icon" src="${itemIconUrl(listing.tradeItem)}" alt="" onerror="this.style.visibility='hidden'">`;
        const perUnit = `${icon}${listing.tradeQuantity}x ${escapeHtml(getItemLabel(listing.tradeItem))}`;
        const total = `${icon}${listing.tradeQuantity * listing.quantity}x ${escapeHtml(getItemLabel(listing.tradeItem))}`;
        return { price: perUnit, total: total };
    }
    const totalPrice = listing.price * listing.quantity;
    const icon = `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">`;
    return { price: `${icon}${listing.price.toLocaleString()} Core`, total: `${icon}${totalPrice.toLocaleString()} Core` };
}

function renderListings(listings) {
    currentListings = listings || [];
    const container = document.getElementById('listingsContainer');

    if (currentListings.length === 0) {
        container.innerHTML = '<div class="empty-state">No listings available</div>';
        return;
    }

    const tableRows = currentListings.map(listing => {
        const { price, total } = formatListingPrice(listing);
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(listing.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(listing.item))}</td>
                <td class="row-quantity">${listing.quantity}</td>
                <td class="row-player">${escapeHtml(listing.sellerName || 'Unknown')}</td>
                <td class="row-price">${price}</td>
                <td class="row-total">${total}</td>
                <td class="row-actions">
                    ${listing.seller === GetPlayerServerId() ? 
                        `<span class="action-spacer"></span>
                        <button class="action-btn danger" onclick="cancelListing(${listing.id})">Cancel</button>` : 
                        `<input type="number" class="quantity-input" id="qty-${listing.id}" min="1" max="${listing.quantity}" value="1">
                        <button class="action-btn success" onclick="purchaseItem(${listing.id})">Buy</button>`
                    }
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

function formatOrderPrice(order) {
    if (order.tradeItem) {
        const icon = `<img class="row-price-icon" src="${itemIconUrl(order.tradeItem)}" alt="" onerror="this.style.visibility='hidden'">`;
        const perUnit = `${icon}${order.tradeQuantity}x ${escapeHtml(getItemLabel(order.tradeItem))}`;
        const total = `${icon}${order.tradeQuantity * order.quantity}x ${escapeHtml(getItemLabel(order.tradeItem))}`;
        return { price: perUnit, total: total };
    }
    const totalPrice = order.price * order.quantity;
    const icon = `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">`;
    return { price: `${icon}${order.price.toLocaleString()} Core`, total: `${icon}${totalPrice.toLocaleString()} Core` };
}

// Render buy orders
function renderBuyOrders(orders) {
    currentBuyOrders = orders || [];
    const container = document.getElementById('ordersContainer');
    
    if (currentBuyOrders.length === 0) {
        container.innerHTML = '<div class="empty-state">No buy orders available</div>';
        return;
    }

    const tableRows = currentBuyOrders.map(order => {
        const { price, total } = formatOrderPrice(order);
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(order.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(order.item))}</td>
                <td class="row-quantity">${order.quantity}</td>
                <td class="row-player">${escapeHtml(order.buyerName || 'Unknown')}</td>
                <td class="row-price">${price}</td>
                <td class="row-total">${total}</td>
                <td class="row-actions">
                    ${order.buyer === GetPlayerServerId() ?
                        `<span class="action-spacer"></span>
                        <button class="action-btn danger" onclick="cancelBuyOrder(${order.id})">Cancel</button>` : 
                        `<input type="number" class="quantity-input" id="qty-order-${order.id}" min="1" max="${order.quantity}" value="1">
                        <button class="action-btn success" onclick="fulfillBuyOrder(${order.id})">Fulfill</button>`
                    }
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Buyer</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Render pickups
function renderPickups(pickups) {
    currentPickups = pickups || [];
    const container = document.getElementById('pickupsContainer');
    
    if (!container) {
        return; // Container doesn't exist yet
    }
    
    if (currentPickups.length === 0) {
        container.innerHTML = '<div class="empty-state">No pickups available</div>';
        return;
    }

    const tableRows = currentPickups.map(pickup => {
        const fulfilledDate = new Date(pickup.fulfilledTimestamp * 1000);
        const dateStr = fulfilledDate.toLocaleDateString() + ' ' + fulfilledDate.toLocaleTimeString();
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(pickup.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(pickup.item))}</td>
                <td class="row-quantity">${pickup.quantity}</td>
                <td class="row-player">${escapeHtml(pickup.sellerName || 'Unknown')}</td>
                <td class="row-price">${pickup.price.toLocaleString()} Core</td>
                <td class="row-total">${pickup.totalPrice.toLocaleString()} Core</td>
                <td class="row-date">${dateStr}</td>
                <td class="row-actions">
                    <button class="action-btn success" onclick="pickupOrder(${pickup.id})">Pick Up</button>
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-date">Fulfilled</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Render history
function renderHistory(history) {
    currentHistory = history || [];
    const container = document.getElementById('historyContainer');
    
    if (currentHistory.length === 0) {
        container.innerHTML = '<div class="empty-state">No history available</div>';
        return;
    }

    // Helper function to get name safely
    const getName = (name, fallback = 'Unknown') => {
        if (!name || name === 'undefined' || name.trim() === '') {
            return fallback;
        }
        return name.trim();
    };
    
    if (currentHistory.length === 0) {
        container.innerHTML = '<div class="empty-state">No history available</div>';
        return;
    }
    
    const tableRows = currentHistory.map(entry => {
        const date = new Date(entry.timestamp * 1000);
        const dateStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
        
        let typeLabel = '';
        let sellerName = '';
        let buyerName = '';
        let itemLabel = getItemLabel(entry.item);
        let quantity = entry.quantity || 0;
        let price = entry.price || 0;
        let totalPrice = entry.totalPrice || 0;
        
        switch(entry.type) {
            case 'listing':
                typeLabel = 'Listing Created';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = '-';
                totalPrice = price * quantity;
                break;
            case 'purchase':
                typeLabel = 'Purchase';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = getName(entry.buyerName, 'Unknown');
                break;
            case 'buyOrder':
                typeLabel = 'Buy Order Created';
                sellerName = '-';
                buyerName = getName(entry.buyerName, 'Unknown');
                totalPrice = price * quantity;
                break;
            case 'fulfill':
                typeLabel = 'Order Fulfilled';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = getName(entry.buyerName, 'Unknown');
                break;
            case 'listingCancel':
                typeLabel = 'Listing Cancelled';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = '-';
                totalPrice = 0;
                break;
            case 'buyOrderCancel':
                typeLabel = 'Buy Order Cancelled';
                sellerName = '-';
                buyerName = getName(entry.buyerName, 'Unknown');
                totalPrice = 0;
                break;
        }
        
        return `
            <tr class="history-table-row">
                <td class="history-type">${escapeHtml(typeLabel)}</td>
                <td class="history-item-name"><img class="row-item-icon" src="${itemIconUrl(entry.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(itemLabel)}</td>
                <td class="history-quantity">${quantity}</td>
                <td class="history-player">${escapeHtml(sellerName)}</td>
                <td class="history-player">${escapeHtml(buyerName)}</td>
                <td class="history-unit-price">${price > 0 ? `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">${price.toLocaleString()} Core` : '-'}</td>
                <td class="history-price">${totalPrice > 0 ? `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">${totalPrice.toLocaleString()} Core` : '-'}</td>
                <td class="history-date">${dateStr}</td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="history-table">
            <thead class="history-table-header">
                <tr>
                    <th class="col-type">Type</th>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-player">Buyer</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-date">Date</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Filter listings
function filterListings(searchTerm) {
    const filtered = currentListings.filter(listing => {
        const itemLabel = getItemLabel(listing.item).toLowerCase();
        return itemLabel.includes(searchTerm.toLowerCase()) ||
               listing.item.toLowerCase().includes(searchTerm.toLowerCase()) ||
               (listing.sellerName && listing.sellerName.toLowerCase().includes(searchTerm.toLowerCase()));
    });
    
    const container = document.getElementById('listingsContainer');
    if (filtered.length === 0) {
        container.innerHTML = '<div class="empty-state">No listings match your search</div>';
        return;
    }
    
    const tableRows = filtered.map(listing => {
        const { price, total } = formatListingPrice(listing);
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(listing.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(listing.item))}</td>
                <td class="row-quantity">${listing.quantity}</td>
                <td class="row-player">${escapeHtml(listing.sellerName || 'Unknown')}</td>
                <td class="row-price">${price}</td>
                <td class="row-total">${total}</td>
                <td class="row-actions">
                    ${listing.seller === GetPlayerServerId() ? 
                        `<span class="action-spacer"></span>
                        <button class="action-btn danger" onclick="cancelListing(${listing.id})">Cancel</button>` : 
                        `<input type="number" class="quantity-input" id="qty-${listing.id}" min="1" max="${listing.quantity}" value="1">
                        <button class="action-btn success" onclick="purchaseItem(${listing.id})">Buy</button>`
                    }
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Filter buy orders
function filterBuyOrders(searchTerm) {
    const filtered = currentBuyOrders.filter(order => {
        const itemLabel = getItemLabel(order.item).toLowerCase();
        return itemLabel.includes(searchTerm.toLowerCase()) ||
               order.item.toLowerCase().includes(searchTerm.toLowerCase()) ||
               (order.buyerName && order.buyerName.toLowerCase().includes(searchTerm.toLowerCase()));
    });
    
    const container = document.getElementById('ordersContainer');
    if (filtered.length === 0) {
        container.innerHTML = '<div class="empty-state">No buy orders match your search</div>';
        return;
    }
    
    const tableRows = filtered.map(order => {
        const { price, total } = formatOrderPrice(order);
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(order.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(order.item))}</td>
                <td class="row-quantity">${order.quantity}</td>
                <td class="row-player">${escapeHtml(order.buyerName || 'Unknown')}</td>
                <td class="row-price">${price}</td>
                <td class="row-total">${total}</td>
                <td class="row-actions">
                    ${order.buyer === GetPlayerServerId() ? 
                        `<span class="action-spacer"></span>
                        <button class="action-btn danger" onclick="cancelBuyOrder(${order.id})">Cancel</button>` : 
                        `<input type="number" class="quantity-input" id="qty-order-${order.id}" min="1" max="${order.quantity}" value="1">
                        <button class="action-btn success" onclick="fulfillBuyOrder(${order.id})">Fulfill</button>`
                    }
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Buyer</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Filter pickups
function filterPickups(searchTerm) {
    const filtered = currentPickups.filter(pickup => {
        const itemLabel = getItemLabel(pickup.item).toLowerCase();
        return itemLabel.includes(searchTerm.toLowerCase()) ||
               pickup.item.toLowerCase().includes(searchTerm.toLowerCase()) ||
               (pickup.sellerName && pickup.sellerName.toLowerCase().includes(searchTerm.toLowerCase()));
    });
    
    const container = document.getElementById('pickupsContainer');
    if (filtered.length === 0) {
        container.innerHTML = '<div class="empty-state">No pickups match your search</div>';
        return;
    }
    
    const tableRows = filtered.map(pickup => {
        const fulfilledDate = new Date(pickup.fulfilledTimestamp * 1000);
        const dateStr = fulfilledDate.toLocaleDateString() + ' ' + fulfilledDate.toLocaleTimeString();
        return `
            <tr class="marketplace-table-row">
                <td class="row-item-name"><img class="row-item-icon" src="${itemIconUrl(pickup.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(getItemLabel(pickup.item))}</td>
                <td class="row-quantity">${pickup.quantity}</td>
                <td class="row-player">${escapeHtml(pickup.sellerName || 'Unknown')}</td>
                <td class="row-price">${pickup.price.toLocaleString()} Core</td>
                <td class="row-total">${pickup.totalPrice.toLocaleString()} Core</td>
                <td class="row-date">${dateStr}</td>
                <td class="row-actions">
                    <button class="action-btn success" onclick="pickupOrder(${pickup.id})">Pick Up</button>
                </td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="marketplace-table">
            <thead class="marketplace-table-header">
                <tr>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-date">Fulfilled</th>
                    <th class="col-actions">Actions</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Purchase item
function purchaseItem(listingId) {
    const qtyInput = document.getElementById(`qty-${listingId}`);
    const quantity = parseInt(qtyInput.value) || 1;
    
    fetch('https://' + GetParentResourceName() + '/purchaseItem', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            listingId: listingId,
            quantity: quantity
        })
    });
}

// Cancel listing
function cancelListing(listingId) {
    showConfirmDialog(
        'Cancel Listing',
        'Are you sure you want to cancel this listing?',
        (confirmed) => {
            if (confirmed) {
                fetch('https://' + GetParentResourceName() + '/cancelListing', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        listingId: listingId
                    })
                }).catch(err => {
                    console.error('Error cancelling listing:', err);
                    showNotification('error', 'Failed to cancel listing');
                });
            }
        }
    );
}

// Cancel buy order
function cancelBuyOrder(orderId) {
    showConfirmDialog(
        'Cancel Buy Order',
        'Are you sure you want to cancel this buy order?',
        (confirmed) => {
            if (confirmed) {
                fetch('https://' + GetParentResourceName() + '/cancelBuyOrder', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        orderId: orderId
                    })
                }).catch(err => {
                    console.error('Error cancelling buy order:', err);
                    showNotification('error', 'Failed to cancel buy order');
                });
            }
        }
    );
}

// Fulfill buy order
function fulfillBuyOrder(orderId) {
    const qtyInput = document.getElementById(`qty-order-${orderId}`);
    const quantity = parseInt(qtyInput.value) || 1;
    
    fetch('https://' + GetParentResourceName() + '/fulfillBuyOrder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            orderId: orderId,
            quantity: quantity
        })
    });
}

// Pickup order
function pickupOrder(pickupId) {
    fetch('https://' + GetParentResourceName() + '/pickupOrder', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            pickupId: pickupId
        })
    });
}

// Apply history filters (client-side filtering)
function applyHistoryFilters() {
    const searchTerm = document.getElementById('historySearch').value.trim();
    const typeFilter = document.getElementById('historyType').value;
    
    // Filter history entries client-side
    let filtered = currentHistory;
    
    // Filter by type if selected
    if (typeFilter) {
        filtered = filtered.filter(entry => entry.type === typeFilter);
    }
    
    // Filter by search term (item label, item name, buyer name, seller name)
    if (searchTerm) {
        const searchLower = searchTerm.toLowerCase();
        filtered = filtered.filter(entry => {
            // Search by item label
            const itemLabel = getItemLabel(entry.item).toLowerCase();
            if (itemLabel.includes(searchLower)) {
                return true;
            }
            
            // Search by item name
            if (entry.item && entry.item.toLowerCase().includes(searchLower)) {
                return true;
            }
            
            // Search by buyer name
            if (entry.buyerName && entry.buyerName.toLowerCase().includes(searchLower)) {
                return true;
            }
            
            // Search by seller name
            if (entry.sellerName && entry.sellerName.toLowerCase().includes(searchLower)) {
                return true;
            }
            
            return false;
        });
    }
    
    // Render filtered history
    renderFilteredHistory(filtered);
}

// Render filtered history
function renderFilteredHistory(history) {
    const container = document.getElementById('historyContainer');
    
    if (history.length === 0) {
        container.innerHTML = '<div class="empty-state">No history matches your search</div>';
        return;
    }

    // Helper function to get name safely
    const getName = (name, fallback = 'Unknown') => {
        if (!name || name === 'undefined' || name.trim() === '') {
            return fallback;
        }
        return name.trim();
    };
    
    const tableRows = history.map(entry => {
        const date = new Date(entry.timestamp * 1000);
        const dateStr = date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
        
        let typeLabel = '';
        let sellerName = '';
        let buyerName = '';
        let itemLabel = getItemLabel(entry.item);
        let quantity = entry.quantity || 0;
        let price = entry.price || 0;
        let totalPrice = entry.totalPrice || 0;
        
        switch(entry.type) {
            case 'listing':
                typeLabel = 'Listing Created';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = '-';
                totalPrice = price * quantity;
                break;
            case 'purchase':
                typeLabel = 'Purchase';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = getName(entry.buyerName, 'Unknown');
                break;
            case 'buyOrder':
                typeLabel = 'Buy Order Created';
                sellerName = '-';
                buyerName = getName(entry.buyerName, 'Unknown');
                totalPrice = price * quantity;
                break;
            case 'fulfill':
                typeLabel = 'Order Fulfilled';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = getName(entry.buyerName, 'Unknown');
                break;
            case 'listingCancel':
                typeLabel = 'Listing Cancelled';
                sellerName = getName(entry.sellerName, 'Unknown');
                buyerName = '-';
                totalPrice = 0;
                break;
            case 'buyOrderCancel':
                typeLabel = 'Buy Order Cancelled';
                sellerName = '-';
                buyerName = getName(entry.buyerName, 'Unknown');
                totalPrice = 0;
                break;
        }
        
        return `
            <tr class="history-table-row">
                <td class="history-type">${escapeHtml(typeLabel)}</td>
                <td class="history-item-name"><img class="row-item-icon" src="${itemIconUrl(entry.item)}" alt="" onerror="this.style.visibility='hidden'">${escapeHtml(itemLabel)}</td>
                <td class="history-quantity">${quantity}</td>
                <td class="history-player">${escapeHtml(sellerName)}</td>
                <td class="history-player">${escapeHtml(buyerName)}</td>
                <td class="history-unit-price">${price > 0 ? `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">${price.toLocaleString()} Core` : '-'}</td>
                <td class="history-price">${totalPrice > 0 ? `<img class="row-price-icon" src="${itemIconUrl('core')}" alt="" onerror="this.style.visibility='hidden'">${totalPrice.toLocaleString()} Core` : '-'}</td>
                <td class="history-date">${dateStr}</td>
            </tr>
        `;
    }).join('');
    
    container.innerHTML = `
        <table class="history-table">
            <thead class="history-table-header">
                <tr>
                    <th class="col-type">Type</th>
                    <th class="col-item">Item</th>
                    <th class="col-quantity">Qty</th>
                    <th class="col-player">Seller</th>
                    <th class="col-player">Buyer</th>
                    <th class="col-price">Price</th>
                    <th class="col-total">Total</th>
                    <th class="col-date">Date</th>
                </tr>
            </thead>
            <tbody>
                ${tableRows}
            </tbody>
        </table>
    `;
}

// Show notification
function showNotification(type, message) {
    const container = document.getElementById('notificationContainer');
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    container.appendChild(notification);
    
    setTimeout(() => {
        notification.style.animation = 'slideIn 0.3s ease-out reverse';
        setTimeout(() => {
            notification.remove();
        }, 300);
    }, 3000);
}

// Setup auto refresh
function setupAutoRefresh() {
    setInterval(() => {
        if (document.getElementById('listings-tab').classList.contains('active') ||
            document.getElementById('buy-orders-tab').classList.contains('active')) {
            fetch('https://' + GetParentResourceName() + '/requestRefresh', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({})
            });
        }
    }, 5000); // Refresh every 5 seconds
}

// Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Get item label from item name
function getItemLabel(itemName) {
    if (!itemName) return 'Unknown Item';
    
    // Check if we have a label in our map
    if (itemLabelMap[itemName]) {
        return itemLabelMap[itemName];
    }
    
    // Fallback: format the item name nicely (capitalize and replace underscores)
    return itemName
        .split('_')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
        .join(' ');
}

// Update item label map from inventory items
function updateItemLabelMap() {
    itemLabelMap = {};
    inventoryItems.forEach(item => {
        if (item.name && item.label) {
            itemLabelMap[item.name] = item.label;
        }
    });
}

// Check if item is available (whitelist check)
function isItemAvailable(itemName) {
    if (!itemName) {
        return false;
    }
    
    // If availableItems is empty, all items are available
    if (!availableItems || availableItems.length === 0) {
        return true;
    }
    
    // Normalize item name for comparison
    const normalizedItem = itemName.toLowerCase();
    const normalizedItemUpper = itemName.toUpperCase();
    
    return availableItems.some(available => {
        const normalizedAvailable = available.toLowerCase();
        const normalizedAvailableUpper = available.toUpperCase();
        
        // Check exact match (case-insensitive)
        return normalizedItem === normalizedAvailable || 
               normalizedItemUpper === normalizedAvailableUpper ||
               itemName === available;
    });
}

// Update label to name map from all available items
function updateLabelToNameMap() {
    labelToNameMap = {};
    allAvailableItems.forEach(item => {
        // Only include items that are in the available items list
        if (item.name && item.label && isItemAvailable(item.name)) {
            // Handle case-insensitive matching and multiple items with same label
            const labelLower = item.label.toLowerCase();
            if (!labelToNameMap[labelLower]) {
                labelToNameMap[labelLower] = [];
            }
            labelToNameMap[labelLower].push({
                name: item.name,
                label: item.label
            });
        }
    });
}

// Get item name from label (for buy orders)
function getItemNameFromLabel(label) {
    if (!label) return null;
    
    const labelLower = label.trim().toLowerCase();
    const matches = labelToNameMap[labelLower];
    
    if (matches && matches.length > 0) {
        // If multiple items have the same label, return the first one
        // In most cases, labels should be unique
        return matches[0].name;
    }
    
    // Try exact case-insensitive match first
    for (const [mapLabel, items] of Object.entries(labelToNameMap)) {
        if (mapLabel === labelLower) {
            return items[0].name;
        }
    }
    
    // Try partial match (label contains input or input contains label)
    for (const [mapLabel, items] of Object.entries(labelToNameMap)) {
        if (mapLabel.includes(labelLower) || labelLower.includes(mapLabel)) {
            return items[0].name;
        }
    }
    
    return null;
}

// Validate if label exists
function doesLabelExist(label) {
    if (!label) return false;
    
    const labelLower = label.trim().toLowerCase();
    
    // Check exact match
    if (labelToNameMap[labelLower]) {
        return true;
    }
    
    // Check partial match
    for (const mapLabel of Object.keys(labelToNameMap)) {
        if (mapLabel === labelLower || mapLabel.includes(labelLower) || labelLower.includes(mapLabel)) {
            return true;
        }
    }
    
    return false;
}

// Get player server ID
let playerServerId = 0;
function GetPlayerServerId() {
    return playerServerId;
}

// Populate inventory dropdown
function populateInventoryDropdown() {
    const select = document.getElementById('sellItemSelect');
    const currentValue = select.value;
    
    // Clear existing options except the first one
    select.innerHTML = '<option value="">Select an item from your inventory...</option>';
    
    // Update item label map when inventory items change
    updateItemLabelMap();
    
    // Add inventory items
    inventoryItems.forEach(item => {
        const option = document.createElement('option');
        option.value = item.name;
        option.textContent = `${item.label || item.name} (${item.count}x)`;
        select.appendChild(option);
    });
    
    // Restore selection if item still exists
    if (currentValue) {
        const stillExists = inventoryItems.find(i => i.name === currentValue);
        if (stillExists) {
            select.value = currentValue;
            updateSellItemQuantity();
        }
    }
}

// Message listener from FiveM
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'open':
            document.getElementById('marketplace').classList.remove('hidden');
            document.body.classList.add('trader-open');
            currentListings = data.listings || [];
            currentBuyOrders = data.buyOrders || [];
            currentPickups = data.pickups || [];
            inventoryItems = data.inventoryItems || [];
            allAvailableItems = data.allAvailableItems || [];
            availableItems = data.availableItems || [];
            updateItemLabelMap(); // Update label map when opening
            updateLabelToNameMap(); // Update label-to-name map when opening (filters by available items)
            if (data.playerId) {
                playerServerId = data.playerId;
            }
            renderListings(currentListings);
            renderBuyOrders(currentBuyOrders);
            renderPickups(currentPickups);
            populateInventoryDropdown();
            break;
            
        case 'pickups':
            currentPickups = data.pickups || [];
            renderPickups(currentPickups);
            break;
            
        case 'inventoryItems':
            inventoryItems = data.inventoryItems || [];
            updateItemLabelMap(); // Update label map when inventory changes
            populateInventoryDropdown();
            break;
            
        case 'close':
            document.getElementById('marketplace').classList.add('hidden');
            document.body.classList.remove('trader-open');
            break;
            
        case 'refresh':
            if (data.listings) {
                currentListings = data.listings;
                if (document.getElementById('listings-tab').classList.contains('active')) {
                    const searchTerm = document.getElementById('listingsSearch').value;
                    if (searchTerm) {
                        filterListings(searchTerm);
                    } else {
                        renderListings(currentListings);
                    }
                }
            }
            if (data.buyOrders) {
                currentBuyOrders = data.buyOrders;
                // Always update buy orders when refreshed, regardless of active tab
                const ordersSearch = document.getElementById('ordersSearch');
                const searchTerm = ordersSearch ? ordersSearch.value : '';
                if (searchTerm && document.getElementById('buy-orders-tab').classList.contains('active')) {
                    filterBuyOrders(searchTerm);
                } else {
                    renderBuyOrders(currentBuyOrders);
                }
            }
            if (data.pickups) {
                currentPickups = data.pickups || [];
                // Always update pickups when refreshed, regardless of active tab
                const pickupsSearch = document.getElementById('pickupsSearch');
                const searchTerm = pickupsSearch ? pickupsSearch.value : '';
                if (searchTerm && document.getElementById('pickups-tab').classList.contains('active')) {
                    filterPickups(searchTerm);
                } else {
                    renderPickups(currentPickups);
                }
            }
            break;
            
        case 'history':
            renderHistory(data.history);
            // Re-apply filters if any are active
            const historySearch = document.getElementById('historySearch');
            const historyType = document.getElementById('historyType');
            if ((historySearch && historySearch.value.trim()) || (historyType && historyType.value)) {
                applyHistoryFilters();
            }
            break;
            
        case 'notification':
            showNotification(data.type, data.message);
            break;
    }
});


