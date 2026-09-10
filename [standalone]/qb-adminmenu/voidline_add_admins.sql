-- Grants the qb-adminmenu 'admin' role to the 12 staff listed in txAdmin.
--
-- The permissions table is keyed by CITIZENID (per character), while txAdmin
-- lists people by fivem:/discord: identifier, so each one was resolved through
-- the `users` table (users.fivem/discord -> users.userId -> players.userId).
-- Every one of them has exactly one character, so one row each covers them.
--
-- Idempotent: re-running it will not duplicate anyone.
INSERT INTO permissions (name, license, permission, citizenid)
SELECT p.name, p.license, 'admin', p.citizenid
FROM players p
WHERE p.citizenid IN (
    'Y88VB54L', -- 4chraff
    'H79B0R87', -- lavawolf
    'Y94OTMMN', -- spider
    'H6096HG7', -- ntmavectesp
    'Q9Q2B5FK', -- aymencousin
    'KCTXF753', -- fedi
    'VKGT6K23', -- wintf
    'LLEXHW8R', -- clevercat2363
    'NLD84451', -- yassuo
    'IVX36CL9', -- m4vvv
    'N892N8MG', -- s1dj0  (already inserted earlier; the guard below skips it)
    'X1J4TWP5'  -- icyyn
)
AND NOT EXISTS (SELECT 1 FROM permissions x WHERE x.citizenid = p.citizenid);

SELECT id, name, permission, citizenid FROM permissions ORDER BY name;
