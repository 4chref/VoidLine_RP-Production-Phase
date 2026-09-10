-- VoidLine: server-only override for the two Discord webhook URLs, sourced
-- from convars instead of ever being written into config.lua -- config.lua
-- is a SHARED script (loads client-side too), so a real secret has no
-- business living there. This file is server-only and loads before
-- server/main.lua and server/adminactions.lua (see fxmanifest.lua), so by
-- the time either of those reads Config.LogsWebhook / Config.ScreenshotWebhook
-- it's already whatever was set below -- or still blank, if you haven't set
-- the convars yet, in which case both features stay silently disabled (see
-- the "Webhook missing from config!" / "Screenshot webhook not configured."
-- guards in main.lua and adminactions.lua).
--
-- Add your own webhook URLs to server.cfg (NOT this file, and NOT
-- config.lua) with plain `set`, not `setr` -- `setr` replicates a convar to
-- every connected client, which would hand your webhook URL to anyone
-- opening their F8 console:
--
--   set qb_adminmenu_logs_webhook "https://discord.com/api/webhooks/..."
--   set qb_adminmenu_screenshot_webhook "https://discord.com/api/webhooks/..."
--
-- Put those lines somewhere private (server.cfg itself, or a separate
-- gitignored cfg you `exec` from it) -- either way, never commit them
-- alongside this resource's own files.

Config.LogsWebhook = GetConvar('qb_adminmenu_logs_webhook', '')
Config.ScreenshotWebhook = GetConvar('qb_adminmenu_screenshot_webhook', '')
