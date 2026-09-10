-- =============================================================================
-- vl_corpseloot
--
-- Searching a downed player opens their REAL ox_inventory (ox's own
-- `otherplayer` path), so everything they carry is already there. Nothing is
-- created, copied or generated -- the "Search body" option is the whole
-- feature.
-- =============================================================================

VLCorpseLoot = {}

-- ox_target option shown on a downed player.
VLCorpseLoot.target = {
    label = 'Search body',
    icon = 'fa-solid fa-hand',
    -- ox_inventory enforces 1.8m of its own on the actual open
    -- (ox_inventory/client.lua:193), so anything larger here just means the
    -- option appears slightly before it will work. Kept in step deliberately.
    distance = 1.8,
}
