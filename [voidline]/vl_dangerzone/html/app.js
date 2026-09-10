const barTop = document.getElementById('bar-top');
const barBottom = document.getElementById('bar-bottom');
const alertBox = document.getElementById('alert');
const zoneName = document.getElementById('zone-name');
const zoneType = document.getElementById('zone-type');
const sound = document.getElementById('alert-sound');

let hideTimer = null;

function showZoneAlert(data) {
    if (hideTimer) {
        clearTimeout(hideTimer);
        hideTimer = null;
    }

    zoneName.textContent = data.name || '';
    zoneType.textContent = data.dangerType || '';

    if (data.sound) {
        sound.src = `sounds/${data.sound}`;
        sound.volume = typeof data.volume === 'number' ? data.volume : 0.6;
        sound.currentTime = 0;
        sound.play().catch(() => {});
    }

    barTop.classList.add('visible');
    barBottom.classList.add('visible');
    alertBox.classList.add('visible');

    const displayTime = typeof data.displayTime === 'number' ? data.displayTime : 5000;

    hideTimer = setTimeout(() => {
        barTop.classList.remove('visible');
        barBottom.classList.remove('visible');
        alertBox.classList.remove('visible');
        hideTimer = null;
    }, displayTime);
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'showZoneAlert') {
        showZoneAlert(data);
    }
});
