Config = {}

-- How often (ms) the client checks its distance to every zone.
Config.CheckInterval = 1000

-- How long the on-screen alert stays fully visible before it starts fading, in ms.
-- The fade itself is handled in CSS (html/style.css) and takes ~1.2s on top of this.
Config.DisplayTime = 7000

-- Draws a marker + the radius circle at every zone so you can eyeball and
-- tweak placement/size in-game. Turn off once zones are finalized.
Config.DebugMarkers = true

-- Zones the player gets warned about on entry. Add more entries here; each one
-- fires once per entry (it will not fire again until the player leaves the
-- radius and comes back). `sound` is a filename placed in html/sounds/.
Config.Zones = {
    {
        name = 'Human Labs',
        dangerType = 'AI zboub',
        coords = vec3(3545.90, 3698.11, 45.23),
        radius = 300.0,
        sound = 'dangerzone.mp3',
        volume = 0.6,
    },
}
