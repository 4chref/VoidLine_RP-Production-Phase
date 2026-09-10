// --- Background music: autoplay, with a user-controlled mute toggle ---
const bgMusic = document.getElementById('bgMusic');
bgMusic.volume = 1;

function forcePlay() {
  bgMusic.play().catch(() => {
    // autoplay blocked on this pass, retry shortly
    setTimeout(forcePlay, 300);
  });
}
forcePlay();

// belt-and-suspenders: if playback stalls for any reason other than a
// deliberate mute, resume it
bgMusic.addEventListener('pause', () => {
  if (!bgMusic.muted) forcePlay();
});

// --- Mute toggle ---
const muteBtn = document.getElementById('muteBtn');

function setMuted(muted) {
  bgMusic.muted = muted;
  muteBtn.classList.toggle('muted', muted);
  muteBtn.setAttribute('aria-label', muted ? 'Unmute music' : 'Mute music');
  muteBtn.title = muted ? 'Unmute music' : 'Mute music';
  if (!muted) forcePlay();
}

muteBtn.addEventListener('click', () => setMuted(!bgMusic.muted));

// --- Character crossfade cycle ---
const chars = document.querySelectorAll('.char-img');
let charIndex = 0;

setInterval(() => {
  chars[charIndex].classList.remove('active');
  charIndex = (charIndex + 1) % chars.length;
  chars[charIndex].classList.add('active');
}, 5000); // 3s fully visible + ~2s smooth crossfade

// --- Fake progress + status text ---
const fill = document.querySelector('.progress-fill');
const percentEl = document.getElementById('percent');
const loadingTextEl = document.getElementById('loadingText');

const stages = [
  'Loading assets...',
  'Downloading resources...',
  'Building interiors...',
  'Syncing character data...',
  'Preparing vehicles...',
  'Loading scripts...',
  'Connecting to server...',
  'Almost there...'
];

let progress = 0;
let stageIndex = 0;
loadingTextEl.textContent = stages[0];

function tick() {
  // ease toward 100%, never quite blocking, mirrors real asset loading feel
  const remaining = 100 - progress;
  const step = Math.max(0.15, remaining * 0.02) * (0.5 + Math.random());
  progress = Math.min(99, progress + step);

  fill.style.width = progress + '%';
  percentEl.textContent = Math.floor(progress) + '%';

  const targetStage = Math.min(stages.length - 1, Math.floor((progress / 100) * stages.length));
  if (targetStage !== stageIndex) {
    stageIndex = targetStage;
    loadingTextEl.textContent = stages[stageIndex];
  }
}

setInterval(tick, 250);

// --- Hook into real FiveM loading events if available ---
window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || !data.eventName) return;

  if (data.eventName === 'loadProgress' && typeof data.loadFraction === 'number') {
    progress = Math.min(99, data.loadFraction * 100);
    fill.style.width = progress + '%';
    percentEl.textContent = Math.floor(progress) + '%';
  }

  if (data.eventName === 'setPlayerName' && typeof data.name === 'string') {
    document.getElementById('playerName').textContent = data.name;
  }

  if (data.eventName === 'onYouConnect' || data.eventName === 'shutdown') {
    progress = 100;
    fill.style.width = '100%';
    percentEl.textContent = '100%';
    loadingTextEl.textContent = 'Connecting...';
  }
});
