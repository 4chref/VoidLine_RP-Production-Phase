-- Flattens each shop's categories into a lookup, so client (render) and server
-- (charge) read exactly the same prices from one place.

local function titleCase(name)
    local out = name:gsub('_', ' ')
    return (out:gsub('%a[%w_\']*', function(word)
        return word:sub(1, 1):upper() .. word:sub(2)
    end))
end

for shopId, shop in pairs(Config.Shops) do
    shop.id = shopId
    shop.items = {}
    shop.itemsByName = {}

    for _, category in ipairs(shop.categories or {}) do
        for _, item in ipairs(category.items) do
            local resolved = {
                name = item.name,
                label = item.label or titleCase(item.name),
                price = item.price or shop.defaultPrice or 0,
                model = item.model,
                description = item.description,
                category = category.id,
                categoryLabel = category.label,
            }
            shop.items[#shop.items + 1] = resolved
            shop.itemsByName[item.name] = resolved
        end
    end
end
