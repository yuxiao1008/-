-- 佩里科岛物资刷新系统 - 客户端
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
local LocalResourceSpawns = {}
local isSearching = false

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island RESOURCES] " .. msg)
    end
end

-- ==================== 原生 HelpText 提示 ====================
local function ShowHelpText(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ==================== 主渲染线程 ====================
CreateThread(function()
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local foundNearby = false

        for spawn_id, spawn_data in pairs(LocalResourceSpawns) do
            local distance = #(playerCoords - spawn_data.coords)

            if distance <= Config.Resources.global.arrow_distance then
                sleep = 0
                foundNearby = true

                -- 绘制红色向下箭头
                local marker = Config.Resources.global.arrow_marker
                local z_offset = 1.0

                -- 上下浮动效果
                if marker.bob then
                    z_offset = 1.0 + math.sin(GetGameTimer() / 500.0) * 0.2
                end

                DrawMarker(
                    marker.type,
                    spawn_data.coords.x, spawn_data.coords.y, spawn_data.coords.z + z_offset,
                    0.0, 0.0, 0.0,
                    180.0, 0.0, 0.0,  -- 旋转180度使箭头向下
                    marker.size.x, marker.size.y, marker.size.z,
                    marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                    false, false, 2, false, nil, nil, false
                )

                -- 交互提示
                if distance <= Config.Resources.global.interact_distance then
                    ShowHelpText("按 ~INPUT_CONTEXT~ 搜索物资")

                    -- 检测E键按下
                    if IsControlJustReleased(0, 38) and not isSearching then
                        isSearching = true

                        -- 预加载动画字典
                        local animDict = Config.Resources.global.pickup_progress.animation.dict
                        RequestAnimDict(animDict)
                        while not HasAnimDictLoaded(animDict) do
                            Wait(10)
                        end

                        -- 显示进度条
                        local success = lib.progressBar({
                            duration = Config.Resources.global.pickup_progress.duration,
                            label = Config.Resources.global.pickup_progress.label,
                            useWhileDead = Config.Resources.global.pickup_progress.use_while_dead,
                            canCancel = Config.Resources.global.pickup_progress.can_cancel,
                            disable = {
                                car = Config.Resources.global.pickup_progress.disable_control,
                                move = Config.Resources.global.pickup_progress.disable_movement,
                                combat = Config.Resources.global.pickup_progress.disable_control
                            },
                            anim = {
                                dict = animDict,
                                clip = Config.Resources.global.pickup_progress.animation.clip
                            }
                        })

                        if success then
                            -- 进度条完成，触发拾取
                            TriggerServerEvent('yx_island:server:pickup_resource', spawn_id)
                            debug_print(string.format("请求拾取刷新点: %s", spawn_id))
                        else
                            -- 进度条被取消
                            QBCore.Functions.Notify(Config.Resources.notifications.pickup_cancelled, 'error')
                            debug_print("搜索被取消")
                        end

                        -- 清理动画和状态
                        ClearPedTasks(playerPed)
                        isSearching = false
                    end

                    break
                end
            end
        end

        Wait(sleep)
    end
end)

-- ==================== 事件处理 ====================

-- 同步刷新点数据
RegisterNetEvent('yx_island:client:sync_resource_spawns', function(spawns)
    LocalResourceSpawns = spawns
    local count = 0
    for _ in pairs(spawns) do
        count = count + 1
    end
    debug_print(string.format("已同步 %d 个物资刷新点", count))
end)

-- 移除指定刷新点
RegisterNetEvent('yx_island:client:remove_resource_spawn', function(spawn_id)
    if LocalResourceSpawns[spawn_id] then
        LocalResourceSpawns[spawn_id] = nil
        debug_print(string.format("已移除刷新点: %s", spawn_id))
    end
end)

-- 清空所有刷新点
RegisterNetEvent('yx_island:client:clear_resource_spawns', function()
    LocalResourceSpawns = {}
    isSearching = false
    debug_print("已清空所有物资刷新点")
end)

-- 重置所有状态
RegisterNetEvent('yx_island:client:reset_all_states', function()
    LocalResourceSpawns = {}
    isSearching = false
    debug_print("物资刷新状态已重置")
end)
