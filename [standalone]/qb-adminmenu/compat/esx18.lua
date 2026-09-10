ESX = exports['es_extended']:getSharedObject()

-- SERVER COMPATIBILITY LAYER
if (IsDuplicityVersion()) then
    SetTimeout(1000, function()
        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `bans` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `name` varchar(50) DEFAULT NULL,
                `license` varchar(50) DEFAULT NULL,
                `discord` varchar(50) DEFAULT NULL,
                `ip` varchar(50) DEFAULT NULL,
                `reason` text DEFAULT NULL,
                `expire` int(11) DEFAULT NULL,
                `bannedby` varchar(255) NOT NULL DEFAULT 'LeBanhammer',
                PRIMARY KEY (`id`)
            )
        ]])

        MySQL.query([[
            CREATE TABLE IF NOT EXISTS `warns` (
                `id` int(11) NOT NULL AUTO_INCREMENT,
                `name` varchar(50) NOT NULL,
                `license` varchar(50) NOT NULL,
                `reason` text NOT NULL,
                `warnedby` varchar(50) NOT NULL,
                `warnedtime` bigint(20) NOT NULL DEFAULT unix_timestamp(),
                PRIMARY KEY (`id`)
            )
        ]])
    end)
    
    Compat = {
        GetPlayer = ESX.GetPlayerFromId,
        GetPlayerFromCharacterIdentifier = ESX.GetPlayerFromIdentifier,
        GetOfflinePlayerFromCharacterIdentifier = function(CitizenId)
            local results = MySQL.query.await("SELECT * FROM `"..Config.DB.CharactersTable.."` WHERE `identifier` = ? LIMIT 1", {CitizenId})
            local PlayerData = nil
            for k1,v1 in ipairs(results) do
                v1.money = json.decode(v1.accounts)
                v1.status = json.decode(v1.status)
                PlayerData = v1
                break
            end
            while not PlayerData do Wait(0) end
            citizenid = PlayerData.identifier
            citizenIdName = "owner"
            amountofVehicles = MySQL.query.await('SELECT COUNT(*) as count FROM `'..Config.DB.VehiclesTable..'` WHERE `'..citizenIdName..'` = ?', {PlayerData.citizenid})
            local FixedPlayerData = {
                id = "OFFLINE",
                name = PlayerData.firstname..' '..PlayerData.lastname,
                identifiers = PlayerData.identifier,
                role = PlayerData.group,
                bank = '$'..comma_value(PlayerData.accounts.bank),
                cash = '$'..comma_value(PlayerData.accounts.money),
                steamid = PlayerData.identifier,
                citizenid = PlayerData.identifier,
                gender = PlayerData.sex,
                nationality = "Unknown",
                phone = PlayerData.phone_number,
                accountid = "Unknown",
                hunger = PlayerData.status["hunger"].percent,
                thirst = PlayerData.status["thirst"].percent,
                injail = "Unknown",
                lastonline = PlayerData.last_seen,
                amountofVehicles = amountofVehicles[1].count,
                job = PlayerData.job,
                rank = PlayerData.job_grade,
                health = 0,
                armor = 0,
                jobboss = "Unknwon",
                duty = "Unknwon",
                gang = "Unknwon",
                gangrank = "Unknwon",
                gangboss = "Unknwon",
                charname = PlayerData.firstname..' '..PlayerData.lastname,
            }
            return FixedPlayerData
        end,
        GetPlayerList = function()
            local PlayerList = {}
            for k, v in pairs(GetPlayers()) do
                v = tonumber(v)
                local Player = ESX.GetPlayerFromId(v)

                if Player then
                    local identifiers, steamIdentifier = GetPlayerIdentifiers(v)
                    for _, v2 in pairs(identifiers) do
                        if string.find(v2, "license:") then
                            steamIdentifier = v2
                        end
                        if not Config.ShowIPInIdentifiers then
                            if string.find(v2, "ip:") then
                                identifiers[_] = nil
                            end
                        end
                    end
                    local playerRole = Player.group

                    local lastOnlineResult = MySQL.query.await("SELECT last_seen FROM `"..Config.DB.CharactersTable.."` WHERE identifier = ?", {Player.getIdentifier()})
                    local amountofVehicles = MySQL.query.await('SELECT COUNT(*) as count FROM `'..Config.DB.VehiclesTable..'` WHERE `owner` = ?', {Player.getIdentifier()})
                    local bank = Player.getAccount('bank').money or "Unknown"
                    local cash = Player.getMoney() or "Unknown"
                    local citizenid = Player.identifier or "Unknown"
                    local gender = Player.get('sex') or "Unknown"
                    local nationality = "Unknown"
                    local phone = "Unknown"
                    local accountid = "Unknown"
                    local hunger = 0
                    local thirst = 0
                    for k2, v2 in pairs(Player.variables.status) do
                        if v2.name == "hunger" then
                            hunger = v2.percent
                        end
                        if v2.name == "thirst" then
                            thirst = v2.percent
                        end
                    end
                    local injail = "Unknown"
                    local lastonline = lastOnlineResult[1].last_seen or "Unknown"
                    local job = Player.job or "Unknown"
                    local rank =  Player.job.grade_label or "Unknown"
                    local health = GetEntityHealth(GetPlayerPed(Player.source)) / 2
                    local armor = GetPedArmour(GetPlayerPed(Player.source))
                    local gang = "Unknown"
                    local charname = Player.getName()
                    local jobboss = "Unknown"
                    local duty = "Unknown"
                    local gangrank = "Unknown"
                    local gangboss = "Unknown"
            
                    table.insert(PlayerList,
                        {
                            id = v,
                            name = GetPlayerName(v),
                            identifiers = json.encode(identifiers),
                            role = LoadedRole[v],
                            bank = '$'..comma_value(bank),
                            cash = '$'..comma_value(cash),
                            steamid = steamIdentifier,
                            citizenid = citizenid,
                            gender = gender,
                            nationality = nationality,
                            phone = phone,
                            accountid = accountid,
                            hunger = hunger,
                            thirst = thirst,
                            injail = injail,
                            lastonline = lastonline,
                            amountofVehicles = amountofVehicles[1].count,
                            job = job,
                            rank = rank,
                            health = health,
                            armor = armor,
                            jobboss = jobboss and "<span class=\"badge badge-success\">"..Lang:t('alerts.yes').."</span>" or "<span class=\"badge badge-danger\">"..Lang:t('alerts.no').."</span>",
                            duty = duty and "<span class=\"badge badge-success\">"..Lang:t('alerts.yes').."</span>" or "<span class=\"badge badge-danger\">"..Lang:t('alerts.no').."</span>",
                            gang = gang,
                            gangrank = gangrank,
                            gangboss = gangboss and "<span class=\"badge badge-success\">"..Lang:t('alerts.yes').."</span>" or "<span class=\"badge badge-danger\">"..Lang:t('alerts.no').."</span>",
                            charname = charname,
                        }
                    )
                end
            end
            return PlayerList
        end,
        SetPlayerJob = function(targetId, job, grade)
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                p.setJob(job, grade)
            end
        end,
        SetPlayerGang = function(targetId, gang, grade)
            -- Unavailable
        end,
        GetPlayerRole = function(targetId)
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                return p.group
            else return nil end
        end,
        GetCharacterName = function(targetId)
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                return p.getName()
            else return nil end
        end,
        ClearPlayerInventory = function (targetId)
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                for k,v in ipairs(p.inventory) do
                    if v.count > 0 then
                        p.setInventoryItem(v.name, 0)
                    end
                end
                TriggerEvent('esx:playerInventoryCleared',targetId)
            end
        end,
        GetVehiclesList = function() return MySQL.query.await("SELECT * FROM vehicles") end,
        GetItemsList = function() return MySQL.query.await("SELECT * FROM items") end,
        GetCharacterIdentifier = function(targetId)
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                return p.PlayerData.citizenid
            else return nil end
        end,
        GetMasterEmployeeList = function()
            local jobs = ESX.GetJobs()
            local list = {}
            for k,v in pairs(jobs) do
                local res = MySQL.query.await("SELECT * FROM `"..Config.DB.CharactersTable.."` WHERE `job` = ?", {v.name})
                local JobEmployees = {}
                for k2,v2 in pairs(res) do
                    local CharName, JobInfo, GradeInfo = "Unknown?", "Unknown?", "Unknown?"

                    CharName = v2.firstname.. " ".. v2.lastname
                    JobInfo = v2.job
                    GradeInfo = v2.grade

                    Online = ESX.GetPlayerFromIdentifier(v2.identifier)
                    table.insert(JobEmployees, {
                        Name = v2.label,
                        CitizenId = v2.identifier,
                        CharName = CharName,
                        IsBoss = false,
                        IsOnline = Online and "<span class=\"badge bg-success text-light\">ONLINE</span>" or "<span class=\"badge bg-danger text-light\">OFFLINE</span>",
                        Grade = {name = v2.job, level = v2.grade},
                    })
                end
                list[k] = JobEmployees
            end
            return list
        end,
        GetMasterGangList = function()
            -- Unavailable
        end,
        CreateCallback = ESX.RegisterServerCallback,
        GetCharacterData = function(targetId)
            local d = {}
            local p = ESX.GetPlayerFromId(targetId)
            if p then
                d.CharacterName = p.getName()
                d.Role = p.getGroup()
                d.Cash = p.getMoney()
                d.Bank = p.getAccount("bank").money
                d.CharacterIdentifier = p.getIdentifier()
                d.Job = p.job.name
                d.Rank = p.job.grade_label
                d.PlayerId = p.source
                d.IsBoss = false
                d.OnDuty = false
                d.GangLabel = nil
                d.GangRank = nil
                d.GangIsBoss = nil
            end
            return d
        end,
        GetLeaderboardInfo = function()
            local money = {}
            local vehicles = {}
            local results = MySQL.query.await("SELECT * FROM `"..Config.DB.CharactersTable.."`")
            for k,v in pairs(results) do
                local charinfo = json.decode(v.charinfo)
                local moneyInfo = json.decode(v.accounts)
                money[#money + 1] = {
                    citizenid = v.identifier,
                    firstname = v.firstname,
                    lastname = v.lastname,
                    cash = moneyInfo.money,
                    bank = moneyInfo.bank,
                    crypto = nil,
                    coins = nil,
                    lastseen = v.last_seen
                }
                results2 = MySQL.query.await("SELECT * FROM `"..Config.DB.VehiclesTable.."` WHERE owner = ?", {v.identifier})
                for k1, v1 in pairs(results2) do
                    if results[k] == nil then
                        return
                    end
                    local firstname = nil
                    local lastname = nil
                    vehicles[#vehicles + 1] = {
                        citizenid = v.identifier,
                        firstname = v.firstname,
                        lastname = v.lastname,
                        vehicle = v1.vehicle,
                    }
                end
            end
            return money, vehicles
        end,
        PlayerActions = {
            AddMoney = function(targetId, amount)
                local p = ESX.GetPlayerFromId(targetId)
                if p then
                    p.addMoney(amount)
                end
            end,
            RemoveMoney = function(targetId, amount)
                local p = ESX.GetPlayerFromId(targetId)
                if p then
                    p.removeMoney(amount)
                end
            end,
            AddBank = function(targetId, amount)
                local p = ESX.GetPlayerFromId(targetId)
                if p then
                    p.addAccountMoney("bank", amount)
                end
            end,
            RemoveBank = function(targetId, amount)
                local p = ESX.GetPlayerFromId(targetId)
                if p then
                    p.removeAccountMoney("bank", amount)
                end
            end,
        },
    }
end


-- CLIENT COMPATIBILITY LAYER
if (not IsDuplicityVersion()) then
    Compat = {
        OpenInventory = function(targetId) 
            TriggerServerEvent("919-Admin:server:OpenInventory", targetId)
        end,
        UncuffSelf = function()
            TriggerEvent('esx_policejob:handcuff')
        end,
        GetClosestObject = ESX.Game.GetClosestObject,
        GetClosestVehicle = ESX.Game.GetClosestVehicle,
        TriggerCallback = ESX.TriggerServerCallback,
    }
end