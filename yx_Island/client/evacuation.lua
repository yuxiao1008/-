-- 佩里科岛系统 - 撤离点交互
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
local inEvacZone = false
local currentEvacPoint = nil
local isEvacuating = false
local evacuationTimer = 0
local evacuationBlips = {}
local evacuationEnabled = false  -- 撤离点是否已开启
local evacuationStartCoords = nil  -- 撤离开始时的坐标
local activeEvacPoints = {}  -- 当前活动的撤离点列表（由服务端传递）

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island EVAC] " .. msg)
    end
end

-- ==================== 原生 HelpText 提示 ====================
local function ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ==================== Blip 管理 ====================
local function CreateEvacuationBlips()
    -- 删除旧的 Blip
    for _, blip in ipairs(evacuationBlips) do
        RemoveBlip(blip)
    end
    evacuationBlips = {}

    -- 使用服务端传递的撤离点列表（如果有），否则使用配置的所有撤离点
    local points = (#activeEvacPoints > 0) and activeEvacPoints or Config.Evacuation.all_points

    -- 创建新的 Blip
    for i, evacPoint in ipairs(points) do
        local blip = AddBlipForCoord(evacPoint.coords.x, evacPoint.coords.y, evacPoint.coords.z)

        SetBlipSprite(blip, evacPoint.blip.sprite)
        SetBlipColour(blip, evacPoint.blip.color)
        SetBlipScale(blip, evacPoint.blip.scale)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(evacPoint.blip.name)
        EndTextCommandSetBlipName(blip)

        table.insert(evacuationBlips, blip)
        debug_print(string.format("已创建撤离点 Blip: %s", evacPoint.name))
    end
end

local function RemoveEvacuationBlips()
    for _, blip in ipairs(evacuationBlips) do
        RemoveBlip(blip)
    end
    evacuationBlips = {}
    debug_print("已移除所有撤离点 Blip")
end

-- ==================== 主线程 ====================
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local wasInZone = false

        -- 只有撤离点开启时才显示 Marker 和交互
        if evacuationEnabled then
            -- 使用服务端传递的撤离点列表（如果有），否则使用配置的所有撤离点
            local points = (#activeEvacPoints > 0) and activeEvacPoints or Config.Evacuation.all_points

            -- 遍历所有撤离点
            for i, evacPoint in ipairs(points) do
                local distance = #(playerCoords - evacPoint.coords)

                -- 检查是否在可见范围内
                if distance <= 50.0 then
                    sleep = 0

                    -- 绘制 Marker
                    DrawMarker(
                        evacPoint.marker.type,
                        evacPoint.coords.x, evacPoint.coords.y, evacPoint.coords.z - 1.0,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        evacPoint.marker.size.x,
                        evacPoint.marker.size.y,
                        evacPoint.marker.size.z,
                        evacPoint.marker.color.r,
                        evacPoint.marker.color.g,
                        evacPoint.marker.color.b,
                        evacPoint.marker.color.a,
                        false, false, 2, false, nil, nil, false
                    )

                    -- 在交互距离内
                    if distance <= evacPoint.interact_distance then
                        wasInZone = true
                        inEvacZone = true
                        currentEvacPoint = i

                        -- 显示原生提示
                        if not isEvacuating then
                            ShowHelpText("按 ~INPUT_CONTEXT~ 请求撤离 (" .. evacPoint.name .. ")")
                        else
                            ShowHelpText("正在安排撤离... " .. evacuationTimer .. " 秒")
                        end

                        -- 监听 E 键
                        if IsControlJustReleased(0, 38) and not isEvacuating then
                            debug_print("玩家请求撤离")
                            isEvacuating = true
                            evacuationTimer = Config.Evacuation.confirm_time
                            evacuationStartCoords = evacPoint.coords  -- 记录撤离点坐标

                            -- 通知服务端（传递撤离点坐标）
                            TriggerServerEvent('yx_island:server:request_evacuation', evacuationStartCoords)

                            -- 启动倒计时（带范围检测）
                            CreateThread(function()
                                while evacuationTimer > 0 and isEvacuating do
                                    Wait(1000)
                                    evacuationTimer = evacuationTimer - 1

                                    -- 检查玩家是否离开撤离范围
                                    if evacuationStartCoords then
                                        local currentPed = PlayerPedId()
                                        local currentCoords = GetEntityCoords(currentPed)
                                        local distanceFromEvac = #(currentCoords - evacuationStartCoords)

                                        if distanceFromEvac > Config.Evacuation.wait_range then
                                            -- 玩家离开范围，取消撤离
                                            debug_print(string.format("玩家离开撤离范围 (距离: %.2f 米)", distanceFromEvac))
                                            isEvacuating = false
                                            evacuationTimer = 0
                                            evacuationStartCoords = nil

                                            -- 通知服务端取消撤离
                                            TriggerServerEvent('yx_island:server:cancel_evacuation')

                                            QBCore.Functions.Notify(Config.Notifications.evacuation_out_of_range, 'error')
                                            break
                                        end
                                    end
                                end

                                -- 倒计时结束且仍在撤离中
                                if evacuationTimer <= 0 and isEvacuating then
                                    debug_print("撤离倒计时结束")
                                    -- 服务端会处理撤离逻辑
                                end

                                -- 清理状态
                                if evacuationTimer <= 0 then
                                    isEvacuating = false
                                    evacuationStartCoords = nil
                                end
                            end)
                        end

                        break -- 找到最近的撤离点后退出循环
                    end
                end
            end
        else
            -- 撤离点未开启, 如果玩家靠近撤离点坐标, 显示提示
            -- 使用所有撤离点列表检测
            for i, evacPoint in ipairs(Config.Evacuation.all_points) do
                local distance = #(playerCoords - evacPoint.coords)
                if distance <= evacPoint.interact_distance then
                    sleep = 0
                    ShowHelpText(Config.Notifications.evacuation_not_available)
                    break
                end
            end
        end

        -- 如果不在任何撤离点范围内
        if not wasInZone then
            if inEvacZone then
                inEvacZone = false
                currentEvacPoint = nil
                -- 注意: 不在这里取消撤离，因为撤离倒计时线程会通过范围检测来处理
            end
        end

        Wait(sleep)
    end
end)

-- ==================== 事件处理 ====================

-- 开启撤离点
RegisterNetEvent('yx_island:client:open_evacuation', function(selectedPoints)
    evacuationEnabled = true

    -- 保存服务端传递的撤离点列表
    if selectedPoints and #selectedPoints > 0 then
        activeEvacPoints = selectedPoints
        debug_print(string.format("收到服务端选择的 %d 个撤离点", #selectedPoints))
    else
        debug_print("未收到撤离点列表，使用默认配置")
        activeEvacPoints = {}
    end

    CreateEvacuationBlips()
    debug_print("撤离点已开启")
end)

-- 关闭撤离点
RegisterNetEvent('yx_island:client:close_evacuation', function()
    evacuationEnabled = false
    isEvacuating = false        -- 重置撤离中状态
    evacuationTimer = 0         -- 重置倒计时
    inEvacZone = false          -- 重置区域状态
    currentEvacPoint = nil      -- 重置撤离点索引
    evacuationStartCoords = nil -- 重置撤离起始坐标
    activeEvacPoints = {}       -- 清空选中的撤离点列表
    RemoveEvacuationBlips()
    debug_print("撤离点已关闭并重置所有状态")
end)

-- 统一重置事件（系统关闭时调用）
RegisterNetEvent('yx_island:client:reset_all_states', function()
    evacuationEnabled = false
    isEvacuating = false
    evacuationTimer = 0
    inEvacZone = false
    currentEvacPoint = nil
    evacuationStartCoords = nil
    activeEvacPoints = {}       -- 清空选中的撤离点列表
    RemoveEvacuationBlips()
    debug_print("撤离状态已完全重置（统一重置）")
end)

-- 传送到集结点
RegisterNetEvent('yx_island:client:teleport_to_return', function()
    local playerPed = PlayerPedId()

    debug_print("正在传送到集结点...")

    -- 淡出效果
    DoScreenFadeOut(500)
    Wait(500)

    -- 传送
    SetEntityCoords(
        playerPed,
        Config.Evacuation.return_point.x,
        Config.Evacuation.return_point.y,
        Config.Evacuation.return_point.z,
        false, false, false, true
    )
    SetEntityHeading(playerPed, Config.Evacuation.return_heading)

    -- 等待加载
    Wait(500)

    -- 淡入效果
    DoScreenFadeIn(500)

    -- 等待淡入完成后重置角色模型
    Wait(500)
    ExecuteCommand('reloadskin')

    debug_print("已传送到集结点并重置模型")

    -- 重置撤离状态
    isEvacuating = false
    evacuationTimer = 0
    inEvacZone = false
    currentEvacPoint = nil
    evacuationStartCoords = nil
    activeEvacPoints = {}  -- 清空选中的撤离点列表
end)

-- ==================== 资源停止 ====================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 清理 Blips
    RemoveEvacuationBlips()
end)
