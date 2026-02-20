-- 佩里科岛系统 - 服务端主逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 系统启用状态
IslandSystemEnabled = Config.DefaultEnabled

-- 岛上玩家列表 {source = playerName}
IslandPlayers = {}

-- 等待列表 {source = playerName}
WaitingList = {}

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island DEBUG] " .. msg)
    end
end

-- ==================== 工具函数 ====================
-- 获取岛上玩家数量
function GetIslandPlayerCount()
    local count = 0
    for _ in pairs(IslandPlayers) do
        count = count + 1
    end
    return count
end

-- 获取岛上玩家列表
function GetIslandPlayerList()
    local list = {}
    for source, name in pairs(IslandPlayers) do
        table.insert(list, string.format("[%s] %s", source, name))
    end
    return list
end

-- 获取等待列表玩家数量
function GetWaitingPlayerCount()
    local count = 0
    for _ in pairs(WaitingList) do
        count = count + 1
    end
    return count
end

-- 获取等待列表详情
function GetWaitingPlayerList()
    local list = {}
    for source, name in pairs(WaitingList) do
        table.insert(list, string.format("[%s] %s", source, name))
    end
    return list
end

-- ==================== 玩家状态管理 ====================
-- 设置玩家岛屿状态
function SetPlayerIslandStatus(source, status)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    -- 更新 Metadata
    Player.Functions.SetMetaData("on_island", status)

    -- 更新岛上玩家列表
    if status then
        IslandPlayers[source] = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname
        debug_print(string.format("玩家 %s (ID: %s) 进入佩里科岛", IslandPlayers[source], source))
    else
        if IslandPlayers[source] then
            debug_print(string.format("玩家 %s (ID: %s) 离开佩里科岛", IslandPlayers[source], source))
            IslandPlayers[source] = nil
        end
    end
end

-- 获取玩家岛屿状态
function GetPlayerIslandStatus(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    return Player.PlayerData.metadata.on_island or false
end

-- ==================== 事件处理 ====================
-- 客户端上报进入岛屿
RegisterNetEvent('yx_island:server:enter_island', function()
    local source = source

    -- 检查系统是否开启
    if not IslandSystemEnabled then
        debug_print(string.format("玩家 %s 尝试进入岛屿, 但系统未开启", source))
        return
    end

    SetPlayerIslandStatus(source, true)

    -- 发送通知
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.enter_island, 'primary')
end)

-- 客户端上报离开岛屿
RegisterNetEvent('yx_island:server:leave_island', function()
    local source = source
    SetPlayerIslandStatus(source, false)

    -- 发送通知
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.leave_island, 'primary')
end)

-- 玩家离开服务器时清理状态
AddEventHandler('playerDropped', function()
    local source = source
    if IslandPlayers[source] then
        IslandPlayers[source] = nil
        debug_print(string.format("玩家 %s 离线, 已清理岛屿状态", source))
    end
end)

-- ==================== 系统控制函数 ====================
-- 强制传送所有岛上玩家 (清空所有物品包括武器)
function ForceEvacuateIsland()
    local count = 0
    for source, name in pairs(IslandPlayers) do
        -- 发送警告通知
        TriggerClientEvent('QBCore:Notify', source, Config.Notifications.system_shutdown, 'error')

        -- 等待短暂时间后传送
        SetTimeout(3000, function()
            -- 传送玩家
            TriggerClientEvent('yx_island:client:teleport_to_safe', source)
            debug_print(string.format("已将玩家 %s (ID: %s) 强制传送", name, source))

            -- 清空玩家所有物品 (包括武器)
            SetTimeout(1000, function()
                ClearAllPlayerItems(source)
                TriggerClientEvent('QBCore:Notify', source, "强制撤离, 所有物品已被没收!", 'error')
            end)
        end)

        -- 清除状态
        SetPlayerIslandStatus(source, false)
        count = count + 1
    end

    IslandPlayers = {}
    return count
end

-- ==================== 导出函数 ====================
-- 供其他资源调用
exports('GetSystemStatus', function()
    return IslandSystemEnabled
end)

exports('GetIslandPlayers', function()
    return IslandPlayers
end)

exports('GetIslandPlayerCount', function()
    return GetIslandPlayerCount()
end)

-- ==================== 系统重置函数 ====================
-- 统一重置所有系统状态（用于系统关闭或活动结束）
function ResetIslandSystem()
    debug_print("开始重置岛屿系统...")

    -- 1. 停止活动计时器
    if ActivityTimer then
        StopActivityTimer()
        debug_print("活动计时器已停止")
    end

    -- 2. 清空等待列表
    local waitingCount = GetWaitingPlayerCount()
    if waitingCount > 0 then
        WaitingList = {}
        debug_print(string.format("等待列表已清空 (%s 人)", waitingCount))
    end

    -- 3. 清空岛上玩家列表
    local islandCount = GetIslandPlayerCount()
    if islandCount > 0 then
        IslandPlayers = {}
        debug_print(string.format("岛上玩家列表已清空 (%s 人)", islandCount))
    end

    -- 4. 清空已撤离玩家列表（通过导出函数清空）
    local evacuatedCount = ClearEvacuatedPlayers()
    if evacuatedCount > 0 then
        debug_print(string.format("已撤离玩家列表已清空 (%s 人)", evacuatedCount))
    end

    -- 5. 清空撤离请求列表
    local requestCount = ClearEvacuationRequests()
    if requestCount > 0 then
        debug_print(string.format("撤离请求列表已清空 (%s 个)", requestCount))
    end

    -- 6. 清空所有背包备份
    local backupCount = 0
    for source, _ in pairs(PlayerInventoryBackup) do
        PlayerInventoryBackup[source] = nil
        backupCount = backupCount + 1
    end
    if backupCount > 0 then
        debug_print(string.format("背包备份已清空 (%s 个)", backupCount))
    end

    -- 7. 清理所有死亡背包
    if Config.DeathBag.enabled then
        local bagCount = ClearAllDeathBags()
        if bagCount > 0 then
            debug_print(string.format("死亡背包已清理 (%s 个)", bagCount))
        end
    end

    -- 8. 清空所有物资刷新点
    if Config.Resources and Config.Resources.enabled then
        local resourceCount = exports['yx_Island']:ClearAllResourceSpawns()
        if resourceCount > 0 then
            debug_print(string.format("物资刷新点已清空 (%s 个)", resourceCount))
        end
    end

    -- 9. 清空所有武器箱
    if Config.WeaponBoxes and Config.WeaponBoxes.enabled then
        if exports['yx_Island'] and exports['yx_Island'].ClearAllWeaponBoxes then
            exports['yx_Island']:ClearAllWeaponBoxes()
            debug_print("武器箱已清理")
        end
    end

    -- 10. 重置所有玩家复活次数
    if Config.Revival and Config.Revival.enabled then
        local reviveCount = ResetAllReviveCounts()
        if reviveCount > 0 then
            debug_print(string.format("复活次数已重置 (%s 人)", reviveCount))
        end
    end

    -- 11. 通知所有客户端重置状态
    TriggerClientEvent('yx_island:client:reset_all_states', -1)
    debug_print("已通知所有客户端重置状态")

    print("^2[yx_Island]^0 系统状态已完全重置")
end

-- 导出重置函数供其他资源使用
exports('ResetIslandSystem', ResetIslandSystem)

-- ==================== 资源启动 ====================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    print("^2========================================^0")
    print("^2[yx_Island]^0 佩里科岛系统已加载")
    print("^3系统状态:^0 " .. (IslandSystemEnabled and "^2已开启^0" or "^1未开启^0"))
    print("^3作者:^0 于晓")
    print("^2========================================^0")
end)
