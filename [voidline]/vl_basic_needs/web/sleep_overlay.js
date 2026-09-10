(function () {
    var overlay = document.getElementById('overlay');

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action !== 'sleepOverlay') return;

        if (data.active) {
            overlay.style.setProperty('--darkness', data.darkness ?? 0.6);
            overlay.style.setProperty('--blur', (data.blurPx ?? 12) + 'px');
            overlay.classList.add('active');
        } else {
            overlay.classList.remove('active');
        }
    });
})();
