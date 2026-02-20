local QBCore = exports['qb-core']:GetCoreObject()
local activeZones = {}
local jobCooldowns = {
    ['police'] = 0,
    ['lssd'] = 0
}

-- 检查是否是警察
local function isPolice(Player)
    return Config.PoliceJobs[Player.PlayerData.job.name] ~= nil
end

-- 检查冷却时间
local function checkCooldown(jobName)
    local currentTime = os.time()
    local lastUse = jobCooldowns[jobName] or 0
    local cooldownTime = Config.PoliceJobs[jobName].cooldown
    
    if currentTime - lastUse < cooldownTime then
        return false, math.ceil(cooldownTime - (currentTime - lastUse))
    end
    
    return true
end

-- 验证输入值
local function validateInput(jobName, duration, radius)
    local jobConfig = Config.PoliceJobs[jobName]
    
    -- 转换分钟到秒
    duration = duration * 60
    
    if duration > jobConfig.maxDuration then
        return false, GetText('notify_invalid_duration', jobConfig.maxDuration / 60)
    end
    
    if radius > jobConfig.maxRadius then
        return false, GetText('notify_invalid_radius', jobConfig.maxRadius)
    end
    
    return true
end

-- 创建清除区域
local function createClearZone(coords, duration, radius)
    local zoneId = #activeZones + 1
    activeZones[zoneId] = {
        coords = coords,
        radius = radius,
        timestamp = os.time(),
        blip = {
            sprite = 161,
            color = 1,  -- 红色
            scale = math.min(math.max(radius / 100, 0.6), 2.0), -- 根据半径调整大小，最小0.6，最大2.0
            name = GetText('blip_name')
        }
    }
    
    -- 向所有客户端广播新区域
    TriggerClientEvent('qb-vehicleclear:syncZones', -1, activeZones)
    
    -- 设置区域过期时间
    SetTimeout(duration * 1000, function()
        activeZones[zoneId] = nil
        TriggerClientEvent('qb-vehicleclear:syncZones', -1, activeZones)
    end)
end

-- 通知所有警察
local function notifyAllPolice(playerName, duration, radius)
    local players = QBCore.Functions.GetPlayers()
    for i, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and isPolice(Player) then
            TriggerClientEvent('QBCore:Notify', playerId, 
                GetText('notify_police_zone_created', playerName, radius, duration/60), 
                'primary')
        end
    end
end

-- 清除所有活动区域
local function clearAllZones()
    activeZones = {}
    TriggerClientEvent('qb-vehicleclear:syncZones', -1, activeZones)
end

-- 注册命令
QBCore.Commands.Add('qingche', GetText('command_qingche_desc'), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end
    
    local jobName = Player.PlayerData.job.name
    
    -- 检查是否是警察
    if not isPolice(Player) then
        TriggerClientEvent('QBCore:Notify', source, GetText('notify_no_permission'), 'error')
        return
    end
    
    -- 检查职业冷却时间
    local canUse, remainingTime = checkCooldown(jobName)
    if not canUse then
        TriggerClientEvent('QBCore:Notify', source, 
            GetText('notify_cooldown', remainingTime), 
            'error')
        return
    end
    
    -- 触发客户端输入界面，同时传递职业配置
    local jobConfig = Config.PoliceJobs[jobName]
    TriggerClientEvent('qb-vehicleclear:showInput', source, {
        maxDuration = jobConfig.maxDuration,
        maxRadius = jobConfig.maxRadius
    })
end)

-- 接收客户端输入
RegisterNetEvent('qb-vehicleclear:processInput', function(data)
    local source = source
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player or not isPolice(Player) then return end
    
    local duration = tonumber(data.duration)
    local radius = tonumber(data.radius)
    local jobName = Player.PlayerData.job.name
    
    -- 验证输入
    local valid, message = validateInput(jobName, duration, radius)
    if not valid then
        TriggerClientEvent('QBCore:Notify', source, message, 'error')
        return
    end
    
    -- 获取玩家位置
    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    
    -- 创建清除区域
    createClearZone(coords, duration * 60, radius)
    
    -- 更新职业冷却时间
    jobCooldowns[jobName] = os.time()
    
    -- 获取玩家全名
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- 通知所有警察
    notifyAllPolice(playerName, duration * 60, radius)
    
    -- 通知使用命令的玩家
    TriggerClientEvent('QBCore:Notify', source, 
        GetText('notify_zone_created', radius, duration), 
        'success')
end)

-- 注册取消封控命令
QBCore.Commands.Add('quxiaofengkong', GetText('command_cancel_desc'), {}, false, function(source)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then return end
    
    -- 检查是否是警察
    if not isPolice(Player) then
        TriggerClientEvent('QBCore:Notify', source, GetText('notify_no_permission'), 'error')
        return
    end
    
    -- 检查是否有活动的封控区域
    local hasActiveZones = false
    for _ in pairs(activeZones) do
        hasActiveZones = true
        break
    end
    
    if not hasActiveZones then
        TriggerClientEvent('QBCore:Notify', source, GetText('notify_no_active_zones'), 'error')
        return
    end
    
    -- 清除所有封控区域
    clearAllZones()
    
    -- 获取玩家全名
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- 通知所有警察
    local players = QBCore.Functions.GetPlayers()
    for i, playerId in ipairs(players) do
        local targetPlayer = QBCore.Functions.GetPlayer(playerId)
        if targetPlayer and isPolice(targetPlayer) then
            TriggerClientEvent('QBCore:Notify', playerId, 
                GetText('notify_police_zone_removed', playerName), 
                'primary')
        end
    end
    
    -- 通知使用命令的玩家
    TriggerClientEvent('QBCore:Notify', source, GetText('notify_zone_removed'), 'success')
end)