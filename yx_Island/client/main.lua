-- 佩里科岛系统 - 客户端主逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
-- 系统启用状态
local systemEnabled = Config.DefaultEnabled

-- 玩家当前是否在岛上
local isOnIsland = false

-- 位置检测线程状态
local checkThreadRunning = false

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island CLIENT] " .. msg)
    end
end

-- ==================== 工具函数 ====================
-- 计算两点之间的距离
local function get_distance(coords1, coords2)
    return #(coords1 - coords2)
end

-- 检查玩家是否在佩里科岛范围内
local function is_in_island_range()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local distance = get_distance(playerCoords, Config.IslandCenter)

    return distance <= Config.IslandRadius
end

-- ==================== 位置检测线程 ====================
local function start_position_check()
    if checkThreadRunning then return end

    checkThreadRunning = true
    debug_print("位置检测线程已启动")

    CreateThread(function()
        while systemEnabled do
            local inRange = is_in_island_range()

            -- 状态变化时触发事件
            if inRange and not isOnIsland then
                -- 进入岛屿
                isOnIsland = true
                TriggerServerEvent('yx_island:server:enter_island')
                debug_print("检测到玩家进入佩里科岛")

            elseif not inRange and isOnIsland then
                -- 离开岛屿
                isOnIsland = false
                TriggerServerEvent('yx_island:server:leave_island')
                debug_print("检测到玩家离开佩里科岛")
            end

            -- 等待检测间隔
            Wait(Config.CheckInterval)
        end

        checkThreadRunning = false
        debug_print("位置检测线程已停止")
    end)
end

-- ==================== 事件处理 ====================
-- 接收服务端系统开关状态
RegisterNetEvent('yx_island:client:toggle_system', function(enabled)
    systemEnabled = enabled
    debug_print("系统状态更新: " .. (enabled and "开启" or "关闭"))

    if enabled then
        -- 系统开启, 启动检测线程
        start_position_check()
    else
        -- 系统关闭, 重置本地状态
        isOnIsland = false
    end
end)

-- 接收服务端传送指令
RegisterNetEvent('yx_island:client:teleport_to_safe', function()
    local playerPed = PlayerPedId()

    print(string.format("^3[yx_Island CLIENT]^0 开始传送玩家到集结点"))

    -- 淡出效果
    DoScreenFadeOut(500)
    Wait(500)

    -- 使用更可靠的传送方法
    local targetCoords = Config.Evacuation.return_point
    local targetHeading = Config.Evacuation.return_heading
    
    print(string.format("^3[yx_Island CLIENT]^0 目标坐标: %.2f, %.2f, %.2f", targetCoords.x, targetCoords.y, targetCoords.z))

    -- 请求碰撞加载
    RequestCollisionAtCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    
    -- 传送玩家
    SetEntityCoordsNoOffset(playerPed, targetCoords.x, targetCoords.y, targetCoords.z, false, false, false)
    SetEntityHeading(playerPed, targetHeading)
    
    -- 冻结玩家，防止掉落
    FreezeEntityPosition(playerPed, true)
    
    -- 等待加载地面
    local attempts = 0
    while not HasCollisionLoadedAroundEntity(playerPed) and attempts < 100 do
        Wait(10)
        attempts = attempts + 1
    end
    
    print(string.format("^2[yx_Island CLIENT]^0 碰撞加载完成 (尝试次数: %d)", attempts))
    
    -- 确保玩家在地面上
    SetPedCoordsKeepVehicle(playerPed, targetCoords.x, targetCoords.y, targetCoords.z)
    
    -- 解冻玩家
    Wait(500)
    FreezeEntityPosition(playerPed, false)

    -- 淡入效果
    DoScreenFadeIn(500)

    -- 等待淡入完成后重置角色模型
    Wait(500)
    ExecuteCommand('reloadskin')

    print(string.format("^2[yx_Island CLIENT]^0 玩家已成功传送到集结点"))
    debug_print("玩家已被传送到安全区并重置模型")
end)

-- ==================== 资源启动/停止 ====================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    debug_print("客户端脚本已加载")

    -- 如果系统默认开启, 启动检测
    if systemEnabled then
        start_position_check()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 如果玩家在岛上, 通知服务端
    if isOnIsland then
        TriggerServerEvent('yx_island:server:leave_island')
    end
end)

-- ==================== 玩家加载完成 ====================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    debug_print("玩家已加载, 系统状态: " .. (systemEnabled and "开启" or "关闭"))

    -- 如果系统开启, 启动检测线程
    if systemEnabled then
        start_position_check()
    end
end)

-- ==================== 玩家登出 ====================
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    -- 重置本地状态
    isOnIsland = false
    systemEnabled = false
    debug_print("玩家已登出, 已重置本地状态")
end)
