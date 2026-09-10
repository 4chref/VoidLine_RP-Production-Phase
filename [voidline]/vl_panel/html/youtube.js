/* =============================================================================
   vl_panel -- YouTube broadcast overlay

   Own top-level scope (IIFE), own single 'message' listener filtered on its
   own action values -- same pattern index.html's own comment documents for
   every other script on this page, so this drops in without touching them.

   Shown to EVERY player on vl_panel:youtubeShow (client/panel.lua), fullscreen
   and with sound. Deliberately a plain <iframe src="...">, not the YouTube
   IFrame JS API (YT.Player) -- that needs an extra script fetched from
   www.youtube.com and a callback round-trip before anything plays, which is
   one more thing to silently fail inside NUI. A bare embed URL with
   autoplay=1&mute=0 has no such dependency and YouTube's own player already
   auto-selects the highest quality the connection and player size support,
   so nothing here has to ask for it separately.
   ============================================================================= */

(function () {
    const overlay = document.getElementById('youtube-overlay');
    const frame = document.getElementById('youtube-frame');

    function playVideo(videoId) {
        const src = 'https://www.youtube.com/embed/' + encodeURIComponent(videoId)
            + '?autoplay=1'
            + '&mute=0'
            + '&controls=0'
            + '&disablekb=1'
            + '&fs=0'
            + '&iv_load_policy=3'
            + '&modestbranding=1'
            + '&playsinline=1'
            + '&rel=0'
            + '&vq=hd2160'; // best-effort legacy hint; the player auto-selects quality regardless

        frame.src = src;
        overlay.hidden = false;
        console.log('[vl_panel/youtube] playing', videoId, src);
    }

    function stopVideo() {
        overlay.hidden = true;
        frame.src = ''; // actually stops playback/audio, not just hides the layer
        console.log('[vl_panel/youtube] stopped');
    }

    window.addEventListener('message', (event) => {
        const msg = event.data || {};
        if (msg.action === 'youtubeShow' || msg.action === 'youtubeHide') {
            console.log('[vl_panel/youtube] message received', msg);
        }

        switch (msg.action) {
            case 'youtubeShow':
                if (msg.data && msg.data.videoId) playVideo(msg.data.videoId);
                break;
            case 'youtubeHide':
                stopVideo();
                break;
        }
    });
})();
