---Gang names must be lower case (top level table key)
---@type table<string, Gang>
return {
    ['none'] = {
        label = 'No Gang',
        grades = {
            [0] = { name = 'Unaffiliated' },
        },
    },
    ['2'] = {
        label = '2',
        grades = {
            [0] = { name = '2' },
        },
    },
    ['ballas'] = {
        label = 'Ballas',
        grades = {
            [1] = { name = '1', isboss = true, bankAuth = true },
            [0] = { name = 'Member' },
        },
    },
}