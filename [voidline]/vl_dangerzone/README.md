# vl_dangerzone

Shows a 5-second (configurable) af-expeditions-style alert — black top/bottom
letterbox fade + red "YOU ARE ENTERING A DANGER ZONE" text in Bebas Neue,
plus a sound — whenever a player enters a configured radius.

## Setup

1. Edit `config.lua` and add your zones to `Config.Zones`:
   ```lua
   {
       name = 'Human Labs',
       dangerType = 'AI zboub',
       coords = vec3(x, y, z),
       radius = 50.0,
       sound = 'danger_alert.ogg',
       volume = 0.6,
   }
   ```
2. Drop the matching sound file(s) into `html/sounds/` (ogg or mp3).
3. Add `ensure vl_dangerzone` to your server.cfg.

Each zone re-arms itself: the alert only fires again after the player has
left the radius and re-entered it.
