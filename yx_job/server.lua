local QBCore = exports['qb-core']:GetCoreObject()

-- 处理设置职业事件
RegisterNetEvent('yx_job:server:setJob', function(jobName)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- 验证职业是否存在于配置中
    local jobExists = false
    local jobData = nil
    
    for k, v in pairs(Config.Jobs) do
        if v.name == jobName then
            jobExists = true
            jobData = v
            break
        end
    end
    
    if not jobExists then
        TriggerClientEvent('QBCore:Notify', src, "无效的职业选择", 'error')
        return
    end
    
    -- 检查玩家是否已经有工作
    if Player.PlayerData.job.name ~= 'unemployed' then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications.alreadyHaveJob, 'error')
        return
    end
    
    -- 设置玩家职业
    local success = Player.Functions.SetJob(jobName, 0) -- 0为初级等级
    
    if success then
        -- 发送成功通知
        local message = string.format(Config.Notifications.jobChanged, jobData.label)
        TriggerClientEvent('QBCore:Notify', src, message, 'success')
        
        -- 记录日志（可选）
        if Config.Debug then
            print(string.format("[yx_job] 玩家 %s (ID: %s) 获得职业: %s", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, src, jobData.label))
        end
        
        -- 可以在这里添加额外的奖励或初始化逻辑
        -- 例如给玩家一些起始资金或物品
        -- Player.Functions.AddMoney('cash', 100, '入职奖励')
        
    else
        TriggerClientEvent('QBCore:Notify', src, "设置职业失败，请重试", 'error')
    end
end)

-- 获取所有可用职业（可选功能）
QBCore.Functions.CreateCallback('yx_job:server:getAvailableJobs', function(source, cb)
    local availableJobs = {}
    
    for k, v in pairs(Config.Jobs) do
        table.insert(availableJobs, {
            name = v.name,
            label = v.label,
            description = v.description,
            salary = v.salary
        })
    end
    
    cb(availableJobs)
end)

-- 获取玩家当前职业信息（可选功能）
QBCore.Functions.CreateCallback('yx_job:server:getPlayerJob', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        cb(nil)
        return
    end
    
    cb(Player.PlayerData.job)
end)

-- 处理辞职事件
RegisterNetEvent('yx_job:server:quitJob', function(jobName, jobLabel)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    -- 检查玩家是否真的有这个工作
    if Player.PlayerData.job.name ~= jobName then
        TriggerClientEvent('QBCore:Notify', src, "你当前不是这个职业", 'error')
        return
    end
    
    -- 设置玩家为无业
    local success = Player.Functions.SetJob('unemployed', 0)
    
    if success then
        -- 发送成功通知
        TriggerClientEvent('QBCore:Notify', src, "你已成功辞去 " .. jobLabel .. " 的工作", 'success')
        
        -- 记录日志（可选）
        if Config.Debug then
            print(string.format("[yx_job] 玩家 %s (ID: %s) 辞去职业: %s", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname, src, jobLabel))
        end
        
    else
        TriggerClientEvent('QBCore:Notify', src, "辞职失败，请重试", 'error')
    end
end)

-- 服务器启动时的初始化
CreateThread(function()
    print("^2[yx_job]^7 就业系统已加载")
    if Config.Debug then
        print("^3[yx_job]^7 调试模式已启用")
    end
end)