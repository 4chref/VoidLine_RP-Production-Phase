-- Flattens Config.Categories into Config.Items (ordered, category-tagged)
-- and Config.ItemsByName (lookup), resolving label/price defaults once here
-- so client (render) and server (charge) both read the exact same values.

local function titleCase(name)
    local out = name:gsub('_', ' ')
    return (out:gsub('%a[%w_\']*', function(word)
        return word:sub(1, 1):upper() .. word:sub(2)
    end))
end

Config.Items = {}
Config.ItemsByName = {}

for _, category in ipairs(Config.Categories) do
    for _, item in ipairs(category.items) do
        local resolved = {
            name = item.name,
            label = item.label or titleCase(item.name),
            price = item.price or Config.DefaultPrice,
            category = category.id,
            categoryLabel = category.label,
        }
        Config.Items[#Config.Items + 1] = resolved
        Config.ItemsByName[item.name] = resolved
    end
end
