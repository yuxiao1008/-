local QBCore = exports['qb-core']:GetCoreObject()

-- 调度员状态存储
local dispatchers = {
    police = nil,
    lssd = nil,
    ambulance = nil
}

-- 注册调度员
RegisterNetEvent('yx_car_radio:registerDispatcher')
AddEventHandler('yx_car_radio:registerDispatcher', function(job)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local playerJob = Player.PlayerData.job.name
    local playerId = Player.PlayerData.citizenid
    
    if playerJob ~= job then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.JobMismatch, 'error')
        return
    end
    
    -- 检查是否已经是调度员
    if dispatchers[job] and dispatchers[job] == playerId then
        -- 注销调度员
        dispatchers[job] = nil
        TriggerClientEvent('yx_car_radio:updateDispatcherStatus', src, {
            isDispatcher = false,
            job = nil
        })
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.UnregisteredDispatcher, 'success')
        print(string.format("[车载电台] %s 注销了 %s 调度员身份", Player.PlayerData.charinfo.firstname, job))
    else
        -- 检查是否已有其他调度员
        if dispatchers[job] then
            TriggerClientEvent('QBCore:Notify', src, Config.Notifications.JobHasDispatcher, 'error')
            return
        end
        
        -- 注册调度员
        dispatchers[job] = playerId
        TriggerClientEvent('yx_car_radio:updateDispatcherStatus', src, {
            isDispatcher = true,
            job = job
        })
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.RegisteredDispatcher, 'success')
        print(string.format("[车载电台] %s 注册为 %s 调度员", Player.PlayerData.charinfo.firstname, job))
    end
end)

-- 调度员广播
RegisterNetEvent('yx_car_radio:dispatcherBroadcast')
AddEventHandler('yx_car_radio:dispatcherBroadcast', function(job)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local playerId = Player.PlayerData.citizenid
    
    -- 验证是否为该职业的调度员
    if dispatchers[job] ~= playerId then
        TriggerClientEvent('QBCore:Notify', src, '您不是该职业的调度员', 'error')
        return
    end
    
    -- 向所有同职业的玩家广播
    local Players = QBCore.Functions.GetQBPlayers()
    for _, player in pairs(Players) do
        if player.PlayerData.job.name == job then
            TriggerClientEvent('yx_car_radio:receiveDispatcherBroadcast', player.PlayerData.source, job)
        end
    end
    
    print(string.format("[车载电台] %s 调度员进行了全频广播", Player.PlayerData.charinfo.firstname))
end)

-- 联系调度员
RegisterNetEvent('yx_car_radio:contactDispatcher')
AddEventHandler('yx_car_radio:contactDispatcher', function(job)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local playerJob = Player.PlayerData.job.name
    
    if playerJob ~= job then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.JobMismatch, 'error')
        return
    end
    
    -- 检查是否有调度员
    if not dispatchers[job] then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoDispatcher, 'error')
        return
    end
    
    -- 通知调度员
    local dispatcherPlayer = QBCore.Functions.GetPlayerByCitizenId(dispatchers[job])
    if dispatcherPlayer then
        TriggerClientEvent('QBCore:Notify', dispatcherPlayer.PlayerData.source, 
            string.format('%s 正在联系您', Player.PlayerData.charinfo.firstname), 'primary')
    end
    
    print(string.format("[车载电台] %s 联系了 %s 调度员", Player.PlayerData.charinfo.firstname, job))
end)

-- 停止通话
RegisterNetEvent('yx_car_radio:stopTalking')
AddEventHandler('yx_car_radio:stopTalking', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    -- 这里可以添加停止通话的逻辑
    print(string.format("[车载电台] %s 停止了通话", Player.PlayerData.charinfo.firstname))
end)

-- 玩家断开连接时清理调度员状态
AddEventHandler('playerDropped', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local playerId = Player.PlayerData.citizenid
    
    -- 检查是否为调度员
    for job, dispatcherId in pairs(dispatchers) do
        if dispatcherId == playerId then
            dispatchers[job] = nil
            print(string.format("[车载电台] %s 断开连接，已清理 %s 调度员状态", 
                Player.PlayerData.charinfo.firstname, job))
            break
        end
    end
end)

-- 获取调度员状态命令（管理员用）
QBCore.Commands.Add('dispatchers', '查看当前调度员状态', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    if Player.PlayerData.job.name == 'admin' or Player.PlayerData.job.grade.level >= 4 then
        local status = "当前调度员状态:\n"
        for job, dispatcherId in pairs(dispatchers) do
            if dispatcherId then
                local dispatcherPlayer = QBCore.Functions.GetPlayerByCitizenId(dispatcherId)
                if dispatcherPlayer then
                    status = status .. string.format("%s: %s\n", job, dispatcherPlayer.PlayerData.charinfo.firstname)
                else
                    status = status .. string.format("%s: 离线\n", job)
                end
            else
                status = status .. string.format("%s: 无\n", job)
            end
        end
        TriggerClientEvent('QBCore:Notify', src, status, 'primary', 5000)
    else
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.NoPermission, 'error')
    end
end)

-- 初始化时打印信息
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    print("[车载电台] 紧急职业车载电台系统已启动")
    print("[车载电台] 支持职业: police, lssd, ambulance")
    print("[车载电台] 命令: /diaodu - 注册/注销调度员")
    print("[车载电台] 快捷键: U - 调度员全频喊话 / 联系调度员")
end) 