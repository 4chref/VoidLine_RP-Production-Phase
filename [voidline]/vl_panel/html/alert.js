/* ==========================================================================
   VAULT 13 — CENTRAL COMMUNICATION NETWORK
   Handles incoming NUI "alert" messages: queues them, runs a short
   transmission-acquisition sequence, reveals the message, then tears
   down cleanly. No overlapping transmissions.
   ========================================================================== */

function initVault13() {
    var stage = document.getElementById('vault-stage');
    var template = document.getElementById('transmission-template');
    var soundEl = document.getElementById('alert');

    if (!stage || !template || !soundEl) {
        console.error('[vault13] required DOM nodes missing, aborting init', {
            stage: !!stage, template: !!template, soundEl: !!soundEl
        });
        return;
    }

    var queue = [];
    var busy = false;
    var currentChip = null;
    var txCounter = 100 + Math.floor(Math.random() * 800);
    var audioCtx = null;

    var DEFAULTS = {
        duration: 12000,     // ms the message stays fully readable after reveal
        typeSpeed: 22,       // ms per character during the typewriter reveal
        typeMax: 3200,       // hard cap on total typewriter time for long messages
        sequence: true,      // whether to run the acquisition sequence at all
        soundEnabled: true,
        volume: 0.1
    };

    var SEVERITY_LABEL = {
        public:    'PUBLIC COMMUNICATION',
        notice:    'OFFICIAL NOTICE',
        warning:   'SECURITY WARNING',
        priority:  'PRIORITY TRANSMISSION',
        emergency: 'EMERGENCY BROADCAST'
    };

    function wait(ms) { return new Promise(function (res) { setTimeout(res, ms); }); }

    function pad(n, len) {
        n = String(n);
        while (n.length < len) n = '0' + n;
        return n;
    }

    function timestamp() {
        var d = new Date();
        return pad(d.getHours(), 2) + ':' + pad(d.getMinutes(), 2) + ':' + pad(d.getSeconds(), 2);
    }

    function transmissionId() {
        var d = new Date();
        var stamp = d.getFullYear() + pad(d.getMonth() + 1, 2) + pad(d.getDate(), 2);
        txCounter += 1;
        return 'V13-' + stamp + '-' + pad(txCounter % 10000, 4);
    }

    function channelFor(issuer) {
        var h = 0;
        for (var i = 0; i < issuer.length; i++) h = (h * 31 + issuer.charCodeAt(i)) >>> 0;
        return 'PUBLIC-' + pad((h % 9) + 1, 2);
    }

    // -- synthesized tones, so no extra audio assets are required -----------
    function getAudioCtx() {
        if (!audioCtx) {
            var Ctx = window.AudioContext || window.webkitAudioContext;
            if (!Ctx) return null;
            audioCtx = new Ctx();
        }
        return audioCtx;
    }

    function tone(freq, durMs, gainAmt, type) {
        try {
            var ctx = getAudioCtx();
            if (!ctx) return;
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            osc.type = type || 'sine';
            osc.frequency.value = freq;
            gain.gain.setValueAtTime(0, ctx.currentTime);
            gain.gain.linearRampToValueAtTime(gainAmt, ctx.currentTime + 0.01);
            gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + durMs / 1000);
            osc.connect(gain);
            gain.connect(ctx.destination);
            osc.start();
            osc.stop(ctx.currentTime + durMs / 1000 + 0.02);
        } catch (e) { /* audio backend unavailable */ }
    }

    function staticBurst(durMs, gainAmt) {
        try {
            var ctx = getAudioCtx();
            if (!ctx) return;
            var frames = Math.floor(ctx.sampleRate * (durMs / 1000));
            var buffer = ctx.createBuffer(1, frames, ctx.sampleRate);
            var data = buffer.getChannelData(0);
            for (var i = 0; i < frames; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / frames);
            var src = ctx.createBufferSource();
            var gain = ctx.createGain();
            gain.gain.value = gainAmt;
            src.buffer = buffer;
            src.connect(gain);
            gain.connect(ctx.destination);
            src.start();
        } catch (e) { /* audio backend unavailable */ }
    }

    function playSequenceSound(severity, volumeScale) {
        var v = Math.max(0, Math.min(1, volumeScale));
        if (v <= 0) return;
        if (severity === 'emergency') {
            tone(220, 380, 0.05 * v, 'sawtooth');
            setTimeout(function () { staticBurst(260, 0.06 * v); }, 300);
        } else if (severity === 'warning') {
            tone(740, 90, 0.045 * v, 'square');
            setTimeout(function () { tone(740, 90, 0.045 * v, 'square'); }, 150);
        } else if (severity === 'priority') {
            tone(880, 110, 0.045 * v, 'square');
        } else {
            tone(660, 90, 0.04 * v, 'sine');
        }
    }

    function playChime(volumeScale, soundFile) {
        try {
            if (soundFile && soundEl.getAttribute('data-file') !== soundFile) {
                soundEl.src = soundFile;
                soundEl.setAttribute('data-file', soundFile);
            }
            soundEl.volume = Math.max(0, Math.min(1, volumeScale));
            soundEl.currentTime = 0;
            soundEl.play().catch(function () {});
        } catch (e) { /* audio backend unavailable */ }
    }

    // -- queue ---------------------------------------------------------------
    function enqueue(data) {
        queue.push(data);
        updateChip();
        processQueue();
    }

    function processQueue() {
        if (busy || queue.length === 0) return;
        busy = true;
        renderTransmission(queue.shift());
    }

    function updateChip() {
        if (!currentChip) return;
        var n = queue.length;
        var countEl = currentChip.querySelector('.queue-count');
        if (n > 0) {
            countEl.textContent = n;
            currentChip.classList.add('visible');
        } else {
            currentChip.classList.remove('visible');
        }
    }

    // -- typewriter ------------------------------------------------------------
    function typeMessage(textEl, cursorEl, message, perCharMs, onDone) {
        if (!message.length) { onDone(0); return; }
        var i = 0;
        var start = Date.now();
        (function tick() {
            i++;
            textEl.textContent = message.slice(0, i);
            if (i < message.length) {
                setTimeout(tick, perCharMs);
            } else {
                cursorEl.classList.add('hidden');
                onDone(Date.now() - start);
            }
        })();
    }

    // -- main render -------------------------------------------------------------
    function renderTransmission(data) {
        var node = template.content.firstElementChild.cloneNode(true);

        var issuer = (data.issuer || 'UNKNOWN').toString().toUpperCase();
        var message = (data.message || '').toString();
        var severity = (data.severity || 'notice').toString().toLowerCase();
        if (!SEVERITY_LABEL[severity]) severity = 'notice';

        if (severity !== 'public' && severity !== 'notice') node.classList.add('sev-' + severity);

        var els = {
            phaseText: node.querySelector('.phase-text'),
            phaseDot: node.querySelector('.phase-dot'),
            receiveTrack: node.querySelector('.receive-bar-track'),
            receiveFill: node.querySelector('.receive-bar-fill'),
            liveDot: node.querySelector('.live-dot'),
            liveLabel: node.querySelector('.live-label'),
            contentBlock: node.querySelector('.content-block'),
            severityLabel: node.querySelector('.severity-label'),
            sourceName: node.querySelector('.source-name'),
            textEl: node.querySelector('.message-text'),
            cursorEl: node.querySelector('.cursor'),
            txId: node.querySelector('.tx-id'),
            txChannel: node.querySelector('.tx-channel'),
            txTimestamp: node.querySelector('.tx-timestamp'),
            archiveId: node.querySelector('.archive-id'),
            holdFill: node.querySelector('.hold-fill'),
            footerStatus: node.querySelector('.footer-status')
        };

        var txId = transmissionId();
        els.severityLabel.textContent = SEVERITY_LABEL[severity];
        els.sourceName.textContent = issuer;
        els.txId.textContent = txId;
        els.txChannel.textContent = channelFor(issuer);
        els.txTimestamp.textContent = timestamp();
        els.archiveId.textContent = txId;

        currentChip = node.querySelector('.queue-chip');
        stage.appendChild(node);
        updateChip();

        var soundEnabled = data.soundEnabled !== false;
        var volume = typeof data.volume === 'number' ? data.volume : DEFAULTS.volume;
        var sequenceEnabled = data.sequence !== false;
        var perCharMs = typeof data.typeSpeed === 'number' && data.typeSpeed > 0
            ? data.typeSpeed : DEFAULTS.typeSpeed;
        var typeMax = DEFAULTS.typeMax;
        perCharMs = Math.min(perCharMs, message.length ? (typeMax / message.length) : perCharMs);

        var totalDuration = typeof data.duration === 'number' && data.duration > 0
            ? data.duration : DEFAULTS.duration;

        if (soundEnabled) playSequenceSound(severity, volume * 8);

        runIntroSequence(els, severity, sequenceEnabled).then(function () {
            if (soundEnabled) playChime(volume, data.soundFile);
            els.contentBlock.classList.add('revealed');

            typeMessage(els.textEl, els.cursorEl, message, perCharMs, function (typeElapsed) {
                var holdMs = Math.max(1500, totalDuration - typeElapsed);
                els.holdFill.classList.add('running');
                els.holdFill.style.animationDuration = holdMs + 'ms';

                setTimeout(function () {
                    teardown(node, els);
                }, holdMs);
            });
        });
    }

    function runIntroSequence(els, severity, sequenceEnabled) {
        if (!sequenceEnabled) {
            els.phaseText.parentElement.style.display = 'none';
            return Promise.resolve();
        }

        function setPhase(text) {
            var line = els.phaseText.parentElement;
            line.style.animation = 'none';
            // eslint-disable-next-line no-unused-expressions
            line.offsetHeight; // force reflow to restart the fade-in
            line.style.animation = '';
            els.phaseText.textContent = text;
        }

        setPhase('SIGNAL DETECTED');

        return wait(160)
            .then(function () { setPhase('ESTABLISHING CONNECTION...'); return wait(230); })
            .then(function () {
                setPhase('VAULT 13 // INCOMING TRANSMISSION');
                els.liveDot.classList.add('receiving');
                els.liveLabel.textContent = 'RECEIVING';
                return wait(180);
            })
            .then(function () {
                els.receiveTrack.classList.add('active');
                return animateReceive(els);
            })
            .then(function () {
                setPhase('TRANSMISSION VERIFIED');
                els.liveDot.classList.remove('receiving');
                els.liveLabel.textContent = 'SECURE CONNECTION';
                return wait(220);
            })
            .then(function () {
                els.phaseText.parentElement.style.display = 'none';
                els.receiveTrack.style.display = 'none';
            });
    }

    function animateReceive(els) {
        return new Promise(function (resolve) {
            var pct = 0;
            var blocks = 10;
            var timer = setInterval(function () {
                pct += 8 + Math.floor(Math.random() * 14);
                if (pct >= 100) pct = 100;
                var filled = Math.round((pct / 100) * blocks);
                var bar = new Array(filled + 1).join('█') + new Array(blocks - filled + 1).join('░');
                els.phaseText.textContent = 'RECEIVING ' + bar + ' ' + pct + '%';
                els.receiveFill.style.width = pct + '%';
                if (pct >= 100) {
                    clearInterval(timer);
                    resolve();
                }
            }, 40);
        });
    }

    function teardown(node, els) {
        els.footerStatus.textContent = 'TRANSMISSION COMPLETE';
        els.liveLabel.textContent = 'TRANSMISSION COMPLETE';

        setTimeout(function () {
            els.footerStatus.textContent = 'CHANNEL CLOSED';
            node.classList.add('leaving');

            setTimeout(function () {
                if (node.parentNode) node.parentNode.removeChild(node);
                currentChip = null;
                busy = false;
                processQueue();
            }, 520);
        }, 300);
    }

    window.addEventListener('message', function (event) {
        var data = event.data;
        if (!data || data.type !== 'alert') return;
        if (!data.enable) return;
        enqueue(data);
    });

    console.log('[vault13] transmission system ready');
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initVault13);
} else {
    initVault13();
}
