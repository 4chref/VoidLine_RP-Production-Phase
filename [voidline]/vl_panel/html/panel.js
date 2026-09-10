/* =============================================================================
   vl_panel -- NUI

   Every button here does exactly one thing: POST to a Lua NUI callback and
   forget. All permission checks and all actual dispatch happen server-side
   (server/main.lua) -- this page never assumes an action succeeded, it just
   asks for it.
   ============================================================================= */

const RESOURCE = (location.hostname || '').replace(/^cfx-nui-/, '') || 'vl_panel';

function post(name, data) {
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

const root = document.getElementById('root');

const els = {
    pillBlackout: document.getElementById('pill-blackout'),
    pillAirraid: document.getElementById('pill-airraid'),
    blackoutDuration: document.getElementById('blackout-duration'),
    alertMessage: document.getElementById('alert-message'),
    pagerTitle: document.getElementById('pager-title'),
    pagerMessage: document.getElementById('pager-message'),
    youtubeUrl: document.getElementById('youtube-url'),
    radar: document.getElementById('radar'),
    playerCount: document.getElementById('player-count'),
};

const ctx = els.radar.getContext('2d');

// Filled in by the 'config' message (from VLPanel.radar) -- not hardcoded
// here, so config.lua stays the one place these numbers live.
let bounds = { mapImage: null, worldMinX: -4300, worldMaxX: 4600, worldMinY: -4700, worldMaxY: 8400 };
let players = [];

// =============================================================================
// OPEN / CLOSE
// =============================================================================

function openPanel() {
    root.classList.remove('hidden');
    resizeCanvas();
}

function closePanel() {
    root.classList.add('hidden');
}

document.getElementById('btn-close').addEventListener('click', () => {
    post('close');
    closePanel();
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) {
        post('close');
        closePanel();
    }
});

// =============================================================================
// STATUS PILLS
// =============================================================================

function setPill(el, active) {
    el.textContent = active ? 'ON' : 'OFF';
    el.classList.toggle('active', !!active);
}

// =============================================================================
// BUTTONS -- each just posts and clears its own input, nothing else
// =============================================================================

document.getElementById('btn-blackout-on').addEventListener('click', () => {
    post('blackoutOn', { duration: els.blackoutDuration.value.trim() });
});

document.getElementById('btn-blackout-off').addEventListener('click', () => {
    post('blackoutOff');
});

document.getElementById('btn-alert-send').addEventListener('click', () => {
    const message = els.alertMessage.value.trim();
    if (!message) return;
    post('alert', { message });
    els.alertMessage.value = '';
});

document.getElementById('btn-pager-send').addEventListener('click', () => {
    const message = els.pagerMessage.value.trim();
    if (!message) return;
    post('pagerAlert', { title: els.pagerTitle.value.trim(), message });
    els.pagerMessage.value = '';
});

document.getElementById('btn-airraid-on').addEventListener('click', () => {
    post('airraidOn');
});

document.getElementById('btn-airraid-off').addEventListener('click', () => {
    post('airraidOff');
});

document.getElementById('btn-youtube-play').addEventListener('click', () => {
    const url = els.youtubeUrl.value.trim();
    if (!url) return;
    post('youtubePlay', { url });
});

document.getElementById('btn-youtube-stop').addEventListener('click', () => {
    post('youtubeStop');
});

// Enter-to-submit on the single-line inputs that have an obvious primary action.
els.alertMessage.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('btn-alert-send').click();
});
els.pagerMessage.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('btn-pager-send').click();
});
els.youtubeUrl.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') document.getElementById('btn-youtube-play').click();
});

// =============================================================================
// RADAR
//
// Drawn over VLPanel.radar.mapImage (config.lua) if that file actually exists
// on disk -- it is not shipped with this resource, same reasoning as the air
// raid siren mp3: redistributing Rockstar's own map texture is not this
// file's call to make, but an image YOU supply and already have the rights
// to is a different matter entirely. Falls back to a plain grid if the file
// 404s, same graceful-degradation pattern used everywhere else in this panel.
//
// Calibration is four numbers in config.lua (worldMinX/Y, worldMaxX/Y) fit
// against known landmarks -- see that file's own comment for the honesty
// caveat on how approximate that fit is. Every dot's position RELATIVE to
// every other dot is always exactly correct regardless; only how well it
// lines up with the map image underneath depends on that calibration.
// =============================================================================

let mapImg = null;      // null until loaded; draws the plain grid until then
let mapImgFailed = false;

function loadMapImage() {
    if (!bounds.mapImage || mapImgFailed) return;

    const img = new Image();
    img.onload = () => { mapImg = img; drawRadar(); };
    img.onerror = () => {
        mapImgFailed = true;
        console.warn(`[vl_panel] radar map image "${bounds.mapImage}" not found -- ` +
            'falling back to a plain grid. Drop your own file in at html/' + bounds.mapImage + '.');
        drawRadar();
    };
    img.src = bounds.mapImage;
}

// =============================================================================
// ZOOM + PAN
//
// No scrollbar anywhere on purpose: the canvas element never grows past its
// own box (that would need overflow, which is exactly the scrollbar this was
// asked to avoid). Instead the WORLD renders bigger/smaller and slides around
// inside a fixed-size canvas via a single 2D transform -- scroll wheel zooms
// centred on the cursor, left-drag pans. Nothing drawn below (map image, grid,
// dots) needs to know zoom exists; it all still draws at its normal "fit the
// whole world in the canvas" coordinates, and the transform does the rest.
// =============================================================================

const ZOOM_MIN = 1;    // never below "whole world fits" -- no reason to zoom OUT past that
const ZOOM_MAX = 14;
let zoom = 1;
let offsetX = 0, offsetY = 0; // screen-space pixels; where base (0,0) lands

function clampZoom(z) {
    return Math.max(ZOOM_MIN, Math.min(ZOOM_MAX, z));
}

/** Keeps the base-space point currently under (mx, my) fixed on screen while
 * zoom changes -- that is what makes it feel like zooming INTO the cursor
 * rather than into the canvas centre. */
function zoomAt(mx, my, factor) {
    const newZoom = clampZoom(zoom * factor);
    if (newZoom === zoom) return;

    const bx = (mx - offsetX) / zoom;
    const by = (my - offsetY) / zoom;
    offsetX = mx - bx * newZoom;
    offsetY = my - by * newZoom;
    zoom = newZoom;
    clampPan();
    if (!dragging) els.radar.style.cursor = zoom > ZOOM_MIN ? 'grab' : 'default';
    drawRadar();
}

/** Keeps the zoomed world from being dragged/zoomed away into empty space --
 * without this, panning far enough (or zooming out after panning) leaves the
 * canvas showing nothing but its own empty background. */
function clampPan() {
    const w = els.radar.width, h = els.radar.height;
    const minOffsetX = w - w * zoom; // world's right edge cannot pass the canvas's left edge
    const minOffsetY = h - h * zoom;
    offsetX = Math.max(minOffsetX, Math.min(0, offsetX));
    offsetY = Math.max(minOffsetY, Math.min(0, offsetY));
}

let dragging = false;
let dragStartX = 0, dragStartY = 0;
let dragStartOffsetX = 0, dragStartOffsetY = 0;

els.radar.addEventListener('wheel', (e) => {
    e.preventDefault();
    const rect = els.radar.getBoundingClientRect();
    const mx = e.clientX - rect.left, my = e.clientY - rect.top;
    zoomAt(mx, my, e.deltaY < 0 ? 1.2 : 1 / 1.2);
}, { passive: false });

els.radar.addEventListener('mousedown', (e) => {
    if (zoom <= ZOOM_MIN) return; // nothing to pan when fully zoomed out
    dragging = true;
    dragStartX = e.clientX; dragStartY = e.clientY;
    dragStartOffsetX = offsetX; dragStartOffsetY = offsetY;
    els.radar.style.cursor = 'grabbing';
});

window.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    offsetX = dragStartOffsetX + (e.clientX - dragStartX);
    offsetY = dragStartOffsetY + (e.clientY - dragStartY);
    clampPan();
    drawRadar();
});

window.addEventListener('mouseup', () => {
    if (!dragging) return;
    dragging = false;
    els.radar.style.cursor = zoom > ZOOM_MIN ? 'grab' : 'default';
});

function resizeCanvas() {
    const rect = els.radar.getBoundingClientRect();
    els.radar.width = Math.max(1, Math.floor(rect.width));
    els.radar.height = Math.max(1, Math.floor(rect.height));
    clampPan();
    drawRadar();
}
window.addEventListener('resize', resizeCanvas);

/** Base (unzoomed) canvas position -- the transform in drawRadar() handles
 * zoom/pan on top of this, so nothing that calls this needs to care. */
function worldToCanvas(x, y) {
    const w = els.radar.width, h = els.radar.height;
    const nx = (x - bounds.worldMinX) / (bounds.worldMaxX - bounds.worldMinX);
    // World Y increases north; canvas Y increases downward, so this is flipped.
    const ny = 1 - (y - bounds.worldMinY) / (bounds.worldMaxY - bounds.worldMinY);
    return [nx * w, ny * h];
}

function drawGrid() {
    const w = els.radar.width, h = els.radar.height;
    ctx.strokeStyle = 'rgba(213, 208, 196, 0.06)';
    ctx.lineWidth = 1 / zoom; // constant on-screen thickness regardless of zoom

    const cols = 12, rows = 12;
    for (let i = 1; i < cols; i++) {
        const x = (i / cols) * w;
        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (let i = 1; i < rows; i++) {
        const y = (i / rows) * h;
        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }

    // Centre crosshair, roughly where the game world's own origin sits.
    const [cx, cy] = worldToCanvas(0, 0);
    const s = 8 / zoom;
    ctx.strokeStyle = 'rgba(213, 208, 196, 0.12)';
    ctx.beginPath(); ctx.moveTo(cx - s, cy); ctx.lineTo(cx + s, cy); ctx.stroke();
    ctx.beginPath(); ctx.moveTo(cx, cy - s); ctx.lineTo(cx, cy + s); ctx.stroke();
}

function drawRadar() {
    const w = els.radar.width, h = els.radar.height;

    // Reset first -- clearRect and the fresh transform below both need to
    // start from identity, not whatever zoom/pan was left over from last draw.
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, w, h);

    // Everything drawn after this point -- map image, grid, dots -- uses its
    // normal "fits the whole world in the canvas" coordinates from
    // worldToCanvas() and never has to know zoom/pan exist; this one transform
    // handles both for all of it at once.
    ctx.setTransform(zoom, 0, 0, zoom, offsetX, offsetY);

    if (mapImg) {
        ctx.drawImage(mapImg, 0, 0, w, h);
        // Grid skipped once the real map is up -- it would just be visual
        // noise over actual coastline detail.
    } else {
        drawGrid();
    }

    // Dots only -- no player names. Radius and outline width are divided by
    // zoom so they stay a constant SCREEN size instead of ballooning into
    // giant circles once zoomed in.
    players.forEach((p) => {
        const [x, y] = worldToCanvas(p.x, p.y);

        ctx.fillStyle = '#8ba870'; // matches --accent in panel.css (af-expeditions' own accent)
        ctx.strokeStyle = 'rgba(0, 0, 0, 0.8)';
        ctx.lineWidth = 1.5 / zoom;
        ctx.beginPath();
        ctx.arc(x, y, 4 / zoom, 0, Math.PI * 2);
        ctx.fill();
        ctx.stroke(); // outline so a green dot still reads clearly over a busy map image
    });

    els.playerCount.textContent = `${players.length} online`;
}

// =============================================================================
// LUA BRIDGE
// =============================================================================

window.addEventListener('message', (event) => {
    const msg = event.data || {};

    switch (msg.action) {
        case 'open':
            openPanel();
            break;
        case 'close':
            closePanel();
            break;
        case 'config':
            bounds = Object.assign(bounds, msg.data || {});
            loadMapImage(); // no-op if already loaded/failed, or if mapImage is unset
            break;
        case 'status':
            setPill(els.pillBlackout, msg.data && msg.data.blackout);
            setPill(els.pillAirraid, msg.data && msg.data.airraid);
            break;
        case 'players':
            players = msg.data || [];
            drawRadar();
            break;
    }
});
