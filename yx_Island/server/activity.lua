-- 佩里科岛系统 - 活动启动逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 活动计时器
local ActivityTimer = nil
local ActivityStartTime = 0

-- 已撤离玩家列表 {source = {name = playerName, reason = "evacuated"/"died"}} - 防止重复报名
EvacuatedPlayers = {}

-- 撤离请求表 {source = {timer_id, evac_coords}} - 用于追踪和取消撤离请求
EvacuationRequests = {}

-- 当前活动选中的撤离点
local ActiveEvacPoints = {}

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island ACTIVITY] " .. msg)
    end
end

-- ==================== 撤离点随机选择 ====================
-- 从所有撤离点中随机选择指定数量
local function RandomSelectEvacPoints()
    local allPoints = Config.Evacuation.all_points
    local count = Config.Evacuation.random_count
    local totalPoints = #allPoints

    -- 验证配置
    if count > totalPoints then
        print(string.format("^1[yx_Island]^0 警告: 随机撤离点数量 (%d) 超过总撤离点数 (%d), 使用所有撤离点", count, totalPoints))
        count = totalPoints
    end

    -- 创建索引数组
    local indices = {}
    for i = 1, totalPoints do
        table.insert(indices, i)
    end

    -- 随机打乱索引
    for i = totalPoints, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end

    -- 选择前 count 个
    local selected = {}
    for i = 1, count do
        table.insert(selected, allPoints[indices[i]])
    end

    debug_print(string.format("已随机选择 %d 个撤离点:", count))
    for i, point in ipairs(selected) do
        debug_print(string.format("  - %s (坐标: %.2f, %.2f, %.2f)", point.name, point.coords.x, point.coords.y, point.coords.z))
    end

    return selected
end

-- ==================== 报名管理 ====================

-- 玩家报名
RegisterNetEvent('yx_island:server:register', function()
    local source = source

    -- 检查系统是否开启
    if not IslandSystemEnabled then
        TriggerClientEvent('QBCore:Notify', source, Config.Notifications.registration_failed, 'error')
        debug_print(string.format("玩家 %s 尝试报名, 但系统未开启", source))
        return
    end

    -- 检查是否已撤离或死亡
    if EvacuatedPlayers[source] then
        local playerData = EvacuatedPlayers[source]
        local reason = playerData.reason or "evacuated"

        if reason == "died" then
            TriggerClientEvent('QBCore:Notify', source, Config.Notifications.already_died, 'error')
            debug_print(string.format("玩家 %s 尝试报名, 但本次行动已死亡", source))
        else
            TriggerClientEvent('QBCore:Notify', source, Config.Notifications.already_evacuated, 'error')
            debug_print(string.format("玩家 %s 尝试报名, 但本次行动已撤离", source))
        end
        return
    end

    -- 检查是否已报名
    if WaitingList[source] then
        TriggerClientEvent('QBCore:Notify', source, Config.Notifications.already_registered, 'error')
        return
    end

    -- 检查是否已在岛上
    if IslandPlayers[source] then
        TriggerClientEvent('QBCore:Notify', source, "你已经在岛上了!", 'error')
        return
    end

    -- 获取玩家信息
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname

    -- 加入等待列表
    WaitingList[source] = playerName
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.registration_success, 'success')
    debug_print(string.format("玩家 %s (ID: %s) 已报名", playerName, source))
end)

-- 取消报名
RegisterNetEvent('yx_island:server:cancel_register', function()
    local source = source

    if WaitingList[source] then
        debug_print(string.format("玩家 %s (ID: %s) 取消报名", WaitingList[source], source))
        WaitingList[source] = nil
        TriggerClientEvent('QBCore:Notify', source, Config.Notifications.cancel_registration, 'primary')
    end
end)

-- ==================== 活动启动 ====================

-- 停止活动计时器
local function StopActivityTimer()
    if ActivityTimer then
        debug_print("停止活动计时器")
        ActivityTimer = nil
        ActivityStartTime = 0
    end
end

-- 启动活动计时器
local function StartActivityTimer()
    -- 停止旧的计时器
    StopActivityTimer()

    ActivityStartTime = os.time()
    local duration = Config.Activity.duration
    local warnings = Config.Activity.warnings

    debug_print(string.format("启动活动计时器, 持续时间: %s 秒", duration))

    -- 创建计时器标记
    ActivityTimer = true

    -- 警告提醒线程
    CreateThread(function()
        for _, warningTime in ipairs(warnings) do
            local triggerTime = duration - warningTime

            -- 等待触发时间（每秒检查标记）
            while ActivityTimer and (os.time() - ActivityStartTime) < triggerTime do
                Wait(1000)
            end

            -- 检查计时器是否仍在运行
            if not ActivityTimer then
                debug_print("警告线程已停止")
                return
            end

            local remainingMinutes = math.floor(warningTime / 60)
            local message = string.format(Config.Notifications.activity_time_warning, remainingMinutes)

            -- 通知所有岛上的玩家
            for source, _ in pairs(IslandPlayers) do
                TriggerClientEvent('QBCore:Notify', source, message, 'warning')
            end

            print(string.format("^3[yx_Island]^0 活动剩余时间: %s 分钟", remainingMinutes))
        end
    end)

    -- 活动结束线程
    CreateThread(function()
        -- 等待活动结束（每秒检查标记）
        while ActivityTimer and (os.time() - ActivityStartTime) < duration do
            Wait(1000)
        end

        -- 检查计时器是否仍在运行
        if not ActivityTimer then
            debug_print("活动结束线程已停止")
            return
        end

        print("^3[yx_Island]^0 活动时间到期, 自动强制关闭...")

        -- 通知所有岛上玩家
        for source, _ in pairs(IslandPlayers) do
            TriggerClientEvent('QBCore:Notify', source, Config.Notifications.activity_auto_close, 'error')
        end

        -- 延迟 5 秒后强制关闭
        Wait(5000)

        -- 再次检查（防止在等待期间被停止）
        if not ActivityTimer then return end

        -- 1. 强制撤离所有玩家 (不返还背包)
        local evacuatedCount = ForceEvacuateIsland()
        print(string.format("^3[yx_Island]^0 已强制撤离 %s 名玩家 (物品已没收)", evacuatedCount))

        -- 2. 关闭撤离点
        TriggerClientEvent('yx_island:client:close_evacuation', -1)

        -- 3. 延迟后完全关闭系统 (等待玩家传送完成)
        Wait(5000)

        -- 最后检查
        if not ActivityTimer then return end

        -- 调用重置函数
        ResetIslandSystem()

        -- 关闭系统
        IslandSystemEnabled = false
        TriggerClientEvent('yx_island:client:toggle_system', -1, false)

        print("^1[yx_Island]^0 系统已完全关闭")
        StopActivityTimer()
    end)
end

-- 启动活动 (由命令调用)
function StartIslandActivity()
    local waitingCount = GetWaitingPlayerCount()

    if waitingCount == 0 then
        print("^1[yx_Island]^0 启动失败! 等待列表为空")
        return false
    end

    print(string.format("^2[yx_Island]^0 活动启动! 共 ^3%s^0 名玩家参与", waitingCount))

    -- 随机选择撤离点
    ActiveEvacPoints = RandomSelectEvacPoints()

    -- 初始化物资刷新点
    if Config.Resources and Config.Resources.enabled then
        local spawnCount = exports['yx_Island']:InitializeResourceSpawns()
        print(string.format("^2[yx_Island]^0 已初始化 %d 个物资刷新点", spawnCount))
    end

    -- 初始化武器箱
    if Config.WeaponBoxes and Config.WeaponBoxes.enabled then
        local boxCount = exports['yx_Island']:InitializeWeaponBoxes()
        print(string.format("^2[yx_Island]^0 已生成 %d 个武器箱", boxCount))
    end

    -- 启动活动计时器
    StartActivityTimer()

    -- 撤离点开启线程
    CreateThread(function()
        local evacuationDelay = Config.Evacuation.delay_open_time
        debug_print(string.format("撤离点将在 %s 秒后开启", evacuationDelay))

        -- 等待延迟时间（每秒检查标记）
        local elapsed = 0
        while ActivityTimer and elapsed < evacuationDelay do
            Wait(1000)
            elapsed = elapsed + 1
        end

        -- 检查计时器是否仍在运行
        if not ActivityTimer then
            debug_print("撤离点开启线程已停止")
            return
        end

        -- 通知所有岛上玩家撤离点已开启
        for source, _ in pairs(IslandPlayers) do
            TriggerClientEvent('QBCore:Notify', source, Config.Notifications.evacuation_opened, 'success')
        end

        -- 通知客户端开启撤离点（传递选中的撤离点列表）
        TriggerClientEvent('yx_island:client:open_evacuation', -1, ActiveEvacPoints)

        print("^2[yx_Island]^0 撤离点已开启")
    end)

    -- 遍历等待列表
    for source, name in pairs(WaitingList) do
        -- 检查玩家是否在线
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            debug_print(string.format("正在处理玩家 %s (ID: %s)", name, source))

            -- 1. 通知玩家
            TriggerClientEvent('QBCore:Notify', source, Config.Notifications.activity_starting, 'primary')

            -- 2. 保存并清空背包
            SetTimeout(1000, function()
                StorePlayerInventory(source)

                -- 3. 延迟后执行空投
                SetTimeout(2000, function()
                    -- 触发客户端空投
                    TriggerClientEvent('yx_island:client:start_airdrop', source)

                    -- 4. 设置玩家岛屿状态
                    SetTimeout(5000, function()
                        SetPlayerIslandStatus(source, true)
                    end)
                end)
            end)
        else
            debug_print(string.format("玩家 %s (ID: %s) 已离线, 跳过", name, source))
        end
    end

    -- 清空等待列表
    WaitingList = {}

    -- 通知所有客户端重置报名状态
    TriggerClientEvent('yx_island:client:reset_registration', -1)
    debug_print("已清空等待列表并通知客户端重置")

    print("^2[yx_Island]^0 所有参与玩家已部署完成!")
    return true
end

-- ==================== 撤离处理 ====================

-- 玩家请求撤离
RegisterNetEvent('yx_island:server:request_evacuation', function(evacCoords)
    local source = source

    -- 检查玩家是否在岛上
    if not IslandPlayers[source] then
        TriggerClientEvent('QBCore:Notify', source, "你不在岛上!", 'error')
        return
    end

    -- 检查是否已有撤离请求（避免重复请求）
    if EvacuationRequests[source] then
        debug_print(string.format("玩家 %s (ID: %s) 已有撤离请求，忽略重复请求", IslandPlayers[source], source))
        return
    end

    debug_print(string.format("玩家 %s (ID: %s) 请求撤离", IslandPlayers[source], source))

    -- 记录撤离请求和坐标
    EvacuationRequests[source] = {
        evac_coords = evacCoords,
        start_time = os.time()
    }

    -- 延迟撤离 (给玩家确认时间)
    SetTimeout(Config.Evacuation.confirm_time * 1000, function()
        -- 检查撤离请求是否仍然有效（可能已被取消）
        if not EvacuationRequests[source] then
            debug_print(string.format("玩家 %s (ID: %s) 的撤离请求已被取消", source, source))
            return
        end

        -- 检查玩家是否仍在岛上
        if not IslandPlayers[source] then
            debug_print(string.format("玩家 %s (ID: %s) 不在岛上，取消撤离", source, source))
            EvacuationRequests[source] = nil
            return
        end

        -- 验证玩家是否仍在撤离范围内
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            local playerCoords = GetEntityCoords(GetPlayerPed(source))
            local evacCoords = EvacuationRequests[source].evac_coords

            if evacCoords then
                local distance = #(playerCoords - evacCoords)

                if distance > Config.Evacuation.wait_range then
                    debug_print(string.format("玩家 %s (ID: %s) 离开撤离范围 (%.2f 米)，取消撤离", IslandPlayers[source], source, distance))
                    TriggerClientEvent('QBCore:Notify', source, "撤离失败: 您已离开撤离范围", 'error')
                    EvacuationRequests[source] = nil
                    return
                end
            end
        end

        -- 执行撤离
        ExecuteEvacuation(source)

        -- 清除撤离请求
        EvacuationRequests[source] = nil
    end)
end)

-- 玩家取消撤离（客户端检测到离开范围时调用）
RegisterNetEvent('yx_island:server:cancel_evacuation', function()
    local source = source

    if EvacuationRequests[source] then
        debug_print(string.format("玩家 %s (ID: %s) 取消撤离请求", IslandPlayers[source] or "未知", source))
        EvacuationRequests[source] = nil
    end
end)

-- 执行撤离
function ExecuteEvacuation(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    local playerName = IslandPlayers[source]
    debug_print(string.format("正在撤离玩家 %s (ID: %s)", playerName, source))

    -- 1. 通知玩家
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.evacuation_success, 'success')

    -- 2. 恢复背包
    RestorePlayerInventory(source)

    -- 3. 添加到已撤离列表，标记为成功撤离（防止重复报名）
    AddPlayerToEvacuatedList(source, playerName, "evacuated")

    -- 4. 传送回集结点
    SetTimeout(1000, function()
        TriggerClientEvent('yx_island:client:teleport_to_return', source)

        -- 5. 清除岛屿状态
        SetTimeout(2000, function()
            SetPlayerIslandStatus(source, false)
        end)
    end)
end

-- ==================== 已撤离玩家管理 ====================
-- 添加玩家到已撤离列表 (供外部调用，如死亡系统)
-- @param source 玩家ID
-- @param playerName 玩家姓名 (可选)
-- @param reason 退出原因: "evacuated" (成功撤离) 或 "died" (死亡)
function AddPlayerToEvacuatedList(source, playerName, reason)
    if not playerName then
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        else
            playerName = "未知玩家"
        end
    end

    reason = reason or "evacuated"

    EvacuatedPlayers[source] = {
        name = playerName,
        reason = reason
    }

    local reasonText = reason == "died" and "死亡" or "撤离"
    debug_print(string.format("玩家 %s (ID: %s) 已加入已撤离列表 (原因: %s)", playerName, source, reasonText))
end

-- 清空已撤离玩家列表 (供系统重置调用)
function ClearEvacuatedPlayers()
    local count = 0
    for source, _ in pairs(EvacuatedPlayers) do
        count = count + 1
    end
    EvacuatedPlayers = {}
    return count
end

-- 清空撤离请求列表 (供系统重置调用)
function ClearEvacuationRequests()
    local count = 0
    for source, _ in pairs(EvacuationRequests) do
        count = count + 1
    end
    EvacuationRequests = {}
    return count
end

-- ==================== 玩家离线处理 ====================
AddEventHandler('playerDropped', function()
    local source = source

    -- 从等待列表移除
    if WaitingList[source] then
        debug_print(string.format("玩家 %s (ID: %s) 离线, 已从等待列表移除", WaitingList[source], source))
        WaitingList[source] = nil
    end

    -- 从已撤离列表移除
    if EvacuatedPlayers[source] then
        local playerData = EvacuatedPlayers[source]
        debug_print(string.format("玩家 %s (ID: %s) 离线, 已从已撤离列表移除", playerData.name, source))
        EvacuatedPlayers[source] = nil
    end

    -- 取消撤离请求
    if EvacuationRequests[source] then
        debug_print(string.format("玩家 %s (ID: %s) 离线, 已取消撤离请求", source, source))
        EvacuationRequests[source] = nil
    end
end)

-- ==================== 导出函数 ====================
exports('StartIslandActivity', StartIslandActivity)
exports('GetWaitingPlayerCount', GetWaitingPlayerCount)
exports('GetWaitingPlayerList', GetWaitingPlayerList)
exports('AddPlayerToEvacuatedList', AddPlayerToEvacuatedList)
exports('ClearEvacuatedPlayers', ClearEvacuatedPlayers)
exports('ClearEvacuationRequests', ClearEvacuationRequests)
