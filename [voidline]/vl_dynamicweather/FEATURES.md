# Dynamic Weather & Time — Features

A premium, standalone weather + time admin panel for FiveM. Run a realistic automatic
weather cycle across your server, or take full manual control from a stylised Los Santos
map — set one static weather, or build timed forecast schedules that change on their own.

No framework required. No dependencies (MySQL is optional). Just `ensure` and go.

---

## Highlights

- 🗺️ **Interactive map panel** — manage weather straight from a stylised Los Santos map.
- 🌦️ **Static or dynamic** weather per area — a fixed weather, or a timed forecast schedule.
- 📍 **Custom zones** — freehand‑draw or drop a resizable box, curve/reshape, pick any colour.
- ⚡ **Change weather for all** — one click sets every city (or every zone) to a static weather.
- 🕐 **In-game time control** — drive the server clock at your own pace.
- 🌡️ **Your units** — Celsius or Fahrenheit, 12‑hour or 24‑hour clock (one config line each).
- 🌍 **Fully localizable** — English + Turkish included, editable, add any language.
- 🔌 **Developer API** — exports for other resources to read weather/time and drive it.
- 🔒 **Secure & standalone** — fail-closed permissions (dedicated ACE, allowlist, or your own hook), server-side validation, conflicting‑script detection, no framework.

---

## What it does

### Weather & time
- Applies any of the **15 GTA V weather types** with smooth blended transitions.
- Optional **in-game clock control** (the sun / day-night) at a configurable pace (default: a full day in ~48 minutes).
- **Uneven day/night** — a `true`/`false` switch gives any part of the day its own clock speed, so night can last longer than daytime (e.g. 1 real hour of day, 3 real hours of night). Off by default = the classic single speed.
- **Real-time forecasts** — dynamic schedules trigger on the **server's real clock** (with an optional timezone offset), so "rain at 13:00" happens at 13:00 wall-time; the in-game sun stays on its own cycle. Toggle off to schedule by in-game time instead.
- **Display your way** — clock in 24‑hour (default) or 12‑hour (AM/PM, shown on the time inputs too), temperature in **°C or °F** (stored internally in Celsius; a config switch each).
- Every change is broadcast to **all players** instantly and saved automatically.

### Areas — cities & zones
- **4 preset city regions** (Los Santos, Sandy Shores, Paleto Bay, Great Chaparral) ready out of the box.
- **Admin-drawn custom zones** layered on top — zones win on overlap.
- Each area is **independent**: its own weather, temperature and mode.
- Switch the map between **City Wide** and **Zone Base** layers.

### On-map zone editor
- **Draw** freehand points, or **Box** for a ready rectangle you resize by the corners and move by the centre.
- **Shape** — drag corner points, curve edges with the mid-edge handles, or **double-click an edge to add a point**.
- **Colour picker** (HSV wheel + brightness slider) when creating a zone, and again on any zone you select.
- **Rename** / **Change color** / **Delete** a selected zone (Delete confirms in a pop-up); **Hide** the existing zones while you work.
- **Undo / Redo / Reset / Confirm** while drafting; an **ⓘ** help bubble + tooltips on every tool.

### Dynamic forecasts
- Give any area a **timed schedule**: weather + temperature at set times (the server's real clock by default, or the in-game clock — one config line).
- **Drag-and-drop reorder**, edit or remove entries.
- Weather advances through the schedule automatically; the panel shows what's **coming up next**.

### One-click bulk
- **Change Static Weather For All** — with no area selected, set every city (Forecast) or every zone (Zone Base) to a single static weather in one step; dynamic areas are switched to static and saved.

### Weather map & sync
- Per-area **weather icons** on the map, plus flowing **wind ribbons** (decorative animation) on the City Wide layer.
- Weather stays **in sync for everyone in an area** — the client self-heals, correcting any external one-off weather change within ~2s.

### Polished admin UX
- Toast confirmations, disabled-until-valid buttons, confirm pop-ups for deletes.
- Smooth transitions throughout, with a `prefers-reduced-motion` fallback.
- Scales cleanly to different resolutions.

---

## Under the hood *(kept light)*

- **Storage:** JSON file by default (zero setup), or **MySQL via oxmysql** — switch with one config line. Auto-falls back to JSON if oxmysql isn't running. Writes are batched and restart-safe.
- **Security:** every panel action is validated server-side (permission, rate-limited, type/range checked). The server never trusts raw client data. Access is **fail-closed** and gated by a dedicated ACE object (`dynamicweather.admin`), never a `command` wildcard — so a broad `add_ace … command allow` in your `server.cfg` can't hand the panel to everyone; the resource scans for exactly that on start and warns. Grant access however you like: ACE, an identifier allowlist, qb-core's own permissions, or your own hook — and `server/permissions.lua` ships **unencrypted** so you can rewrite the check outright. It also warns if a known conflicting weather/time resource is running.
- **Performance:** map redraws only when content actually changes; weather natives are guarded; saves are debounced.
- **Developer API:** client + server exports let other resources read live weather/time and drive it via temporary overrides (missions, events) without touching the admin setup — including a **per-client local weather** override (`setLocalWeather`), a `cdw:onWeatherChange` client event, and an **`openPanel` export/event** to open the admin panel from another resource (permission-checked). See the README.
- **Localization:** all player/admin text lives in `locale/*.lua` (not escrow-encrypted) — reword or translate freely; add a language by copying one file.
- **Compatibility:** `fx_version 'cerulean'`, `lua54`, standalone (works alongside any framework). Optional dependency: oxmysql (only for SQL storage).

---

## What's included

| | |
|---|---|
| `fxmanifest.lua` | Resource manifest. |
| `config/` | Command, permission, storage, locale, clock pace (incl. uneven day/night), display units (12/24h · °C/°F), city outlines & map labels. |
| `shared/` | Clock-pace table shared by client & server. |
| `locale/` | English + Turkish text, editable; drop-in for more languages. |
| `client/` · `server/` | Runtime logic (weather sync, scheduling, validation, persistence). `server/permissions.lua` stays editable. |
| `html/` | The built UI (loaded by the resource). |
| `data/` | Where JSON storage writes `zones.json`. |
| `sql/` | Reference schema for SQL storage. |
| `README.md` | Installation, configuration and usage guide. |

---

## Requirements

- FiveM server (game build **3258+** recommended).
- **oxmysql** — *optional*, only if you enable SQL storage.

---

Author: **Aiakos** · v1.0.0 · See [README.md](README.md) for setup & configuration.
