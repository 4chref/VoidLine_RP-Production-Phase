if Config.Framework ~= 'primefw' then return end

local framework = 'primefw'
local state = GetResourceState(framework)

if state == 'missing' or state == "unknown" then
    -- Framework can't be used if it's missing or unknown
    return
end

-- Emote command
lib.addCommand('e', {
    help = 'Play an emote',
    params = {
        {
            name = 'emotename',
            help = 'dance, camera, sit or any valid emote.'
        }
    }
}, function(source, args)
    TriggerClientEvent('animations:client:PlayEmote', source, args)
end)

-- Emote command alias
lib.addCommand('emote', {
    help = 'Play an emote',
    params = {
        {
            name = 'emotename',
            help = 'dance, camera, sit or any valid emote.'
        }
    }
}, function(source, args)
    TriggerClientEvent('animations:client:PlayEmote', source, args)
end)

-- Emotebind command (SQL Keybinding)
if Config.SqlKeybinding then
    lib.addCommand('emotebind', {
        help = 'Bind an emote',
        params = {
            {
                name = 'key',
                help = 'num4, num5, num6, num7, num8, num9. Numpad 4-9!'
            },
            {
                name = 'emotename',
                help = 'dance, camera, sit or any valid emote.'
            }
        }
    }, function(source, args)
        TriggerClientEvent('animations:client:BindEmote', source, args)
    end)

    -- Check currently bound emotes
    lib.addCommand('emotebinds', {
        help = 'Check your currently bound emotes.'
    }, function(source)
        TriggerClientEvent('animations:client:EmoteBinds', source)
    end)
end

-- Emote menu commands
lib.addCommand('emotemenu', {
    help = 'Open rpemotes menu (F3) by default.'
}, function(source)
    TriggerClientEvent('animations:client:EmoteMenu', source)
end)

lib.addCommand('em', {
    help = 'Open rpemotes menu (F3) by default.'
}, function(source)
    TriggerClientEvent('animations:client:EmoteMenu', source)
end)

-- List available emotes
lib.addCommand('emotes', {
    help = 'List available emotes.'
}, function(source)
    TriggerClientEvent('animations:client:ListEmotes', source)
end)

-- Set walking style
lib.addCommand('walk', {
    help = 'Set your walking style.',
    params = {
        {
            name = 'style',
            help = '/walks for a list of valid styles'
        }
    }
}, function(source, args)
    TriggerClientEvent('animations:client:Walk', source, args)
end)

-- List available walking styles
lib.addCommand('walks', {
    help = 'List available walking styles.'
}, function(source)
    TriggerClientEvent('animations:client:ListWalks', source)
end)

-- Share emote with a nearby player
lib.addCommand('nearby', {
    help = 'Share emote with a nearby player.',
    params = {
        {
            name = 'emotename',
            help = 'hug, handshake, bro or any valid shared emote.'
        }
    }
}, function(source, args)
    TriggerClientEvent('animations:client:Nearby', source, args)
end)
