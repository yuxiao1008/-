-- ====================================
-- 监狱系统 - 客户端
-- 功能: 处理玩家传送到监狱的逻辑
-- ====================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ====================================
-- 监狱状态变量
-- ====================================
local isInPrison = false
local warningCount = 0
local heightCheckThread = nil
local timeDisplayThread = nil
local remainingTime = 0

-- ====================================
-- 传送到监狱事件
-- ====================================
RegisterNetEvent('yx_prison:teleportToPrison', function()
    local playerPed = PlayerPedId()
    local prisonLocation = Config.Prison.location
    local prisonHeading = Config.Prison.heading
    
    DebugPrint('开始传送玩家到监狱位置: ' .. tostring(prisonLocation))
    
    -- 播放传送效果（可选）
    DoScreenFadeOut(1000)
    Wait(1000)
    
    -- 如果玩家在载具中，先让其下车
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(2000)
    end
    
    -- 执行传送
    SetEntityCoords(playerPed, prisonLocation.x, prisonLocation.y, prisonLocation.z, false, false, false, true)
    SetEntityHeading(playerPed, prisonHeading)
    
    -- 确保玩家落地
    local attempts = 0
    while not HasCollisionLoadedAroundEntity(playerPed) and attempts < 50 do
        Wait(100)
        SetEntityCoords(playerPed, prisonLocation.x, prisonLocation.y, prisonLocation.z, false, false, false, true)
        attempts = attempts + 1
    end
    
    -- 恢复屏幕
    DoScreenFadeIn(1000)
    
    DebugPrint(Translate('debug_teleport_success', {player = 'LocalPlayer'}))
    
    -- 播放传送音效（可选）
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
    
    -- 启动监狱监控
    StartPrisonMonitoring()
end)

-- ====================================
-- 启动监狱监控
-- ====================================
function StartPrisonMonitoring()
    if isInPrison then
        return -- 避免重复启动
    end
    
    isInPrison = true
    warningCount = 0
    
    QBCore.Functions.Notify(Translate('prison_monitoring_start'), 'error', 5000)
    DebugPrint('监狱监控已启动')
    
    -- 启动时间显示线程
    StartTimeDisplay()
    
    -- 启动高度检测线程
    if heightCheckThread then
        heightCheckThread = nil
    end
    
    heightCheckThread = CreateThread(function()
        while isInPrison do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local currentHeight = playerCoords.z
            
            DebugPrint(Translate('debug_height_check', {height = string.format("%.2f", currentHeight), min = Config.Prison.minHeight, max = Config.Prison.maxHeight}))
            
            -- 检查高度是否超出允许范围
            if currentHeight < Config.Prison.minHeight or currentHeight > Config.Prison.maxHeight then
                DebugPrint(Translate('debug_forced_return'))
                ForceTeleportToPrison()
            end
            
            Wait(Config.Prison.checkInterval)
        end
    end)
end

-- ====================================
-- 停止监狱监控
-- ====================================
function StopPrisonMonitoring()
    if not isInPrison then
        return
    end
    
    isInPrison = false
    warningCount = 0
    remainingTime = 0
    
    if heightCheckThread then
        heightCheckThread = nil
    end
    
    if timeDisplayThread then
        timeDisplayThread = nil
    end
    
    QBCore.Functions.Notify(Translate('prison_monitoring_stop'), 'success', 3000)
    DebugPrint('监狱监控已停止')
end

-- ====================================
-- 强制传送回监狱
-- ====================================
function ForceTeleportToPrison()
    local playerPed = PlayerPedId()
    local prisonLocation = Config.Prison.location
    local prisonHeading = Config.Prison.heading
    
    -- 播放传送效果
    DoScreenFadeOut(500)
    Wait(500)
    
    -- 如果玩家在载具中，先让其下车
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(1000)
    end
    
    -- 执行传送
    SetEntityCoords(playerPed, prisonLocation.x, prisonLocation.y, prisonLocation.z, false, false, false, true)
    SetEntityHeading(playerPed, prisonHeading)
    
    -- 确保玩家落地
    local attempts = 0
    while not HasCollisionLoadedAroundEntity(playerPed) and attempts < 50 do
        Wait(100)
        SetEntityCoords(playerPed, prisonLocation.x, prisonLocation.y, prisonLocation.z, false, false, false, true)
        attempts = attempts + 1
    end
    
    -- 恢复屏幕
    DoScreenFadeIn(500)
    
    -- 通知玩家
    QBCore.Functions.Notify(Translate('height_violation'), 'error', 3000)
    PlaySoundFrontend(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", true)
    
    DebugPrint('强制传送完成：玩家已被传送回监狱')
end

-- ====================================
-- 传送到释放位置事件
-- ====================================
RegisterNetEvent('yx_prison:teleportToRelease', function()
    local playerPed = PlayerPedId()
    local releaseLocation = Config.Prison.releaseLocation
    local releaseHeading = Config.Prison.releaseHeading
    
    DebugPrint('开始传送玩家到释放位置: ' .. tostring(releaseLocation))
    
    -- 播放传送效果
    DoScreenFadeOut(1000)
    Wait(1000)
    
    -- 如果玩家在载具中，先让其下车
    if IsPedInAnyVehicle(playerPed, false) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        TaskLeaveVehicle(playerPed, vehicle, 0)
        Wait(2000)
    end
    
    -- 执行传送
    SetEntityCoords(playerPed, releaseLocation.x, releaseLocation.y, releaseLocation.z, false, false, false, true)
    SetEntityHeading(playerPed, releaseHeading)
    
    -- 确保玩家落地
    while not HasCollisionLoadedAroundEntity(playerPed) do
        Wait(0)
        SetEntityCoords(playerPed, releaseLocation.x, releaseLocation.y, releaseLocation.z, false, false, false, true)
    end
    
    -- 恢复屏幕
    DoScreenFadeIn(1000)
    
    DebugPrint('释放传送完成：玩家已被传送到释放位置')
    
    -- 播放释放音效
    PlaySoundFrontend(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", true)
end)

-- ====================================
-- 更新剩余时间事件
-- ====================================
RegisterNetEvent('yx_prison:updateRemainingTime', function(minutes)
    remainingTime = minutes
    DebugPrint('剩余时间更新: ' .. minutes .. ' 分钟')
    
    -- 如果时间为0或负数，自动停止监控
    if minutes <= 0 and isInPrison then
        DebugPrint('刑期已满，停止监控')
        StopPrisonMonitoring()
    end
end)

-- ====================================
-- 停止监狱监控事件 (可供服务端调用)
-- ====================================
RegisterNetEvent('yx_prison:stopMonitoring', function()
    StopPrisonMonitoring()
end)

-- ====================================
-- 路由桶状态变化事件
-- ====================================
RegisterNetEvent('yx_prison:routingBucketChanged', function(bucketId, isInPrison)
    if Config.RoutingBucket and Config.RoutingBucket.enable then
        if isInPrison then
            DebugPrint('已进入路由桶: ' .. tostring(bucketId))
            -- 显示单人世界提示
            QBCore.Functions.Notify(Translate('routing_bucket_isolation_active'), 'primary', 8000)
            
            -- 可选：播放特殊音效提示进入单人世界
            PlaySoundFrontend(-1, "CHALLENGE_UNLOCKED", "HUD_AWARDS", true)
        else
            DebugPrint('已离开路由桶，返回主服务器')
            -- 可选：播放释放音效
            PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS", true)
        end
    end
end)

-- ====================================
-- 时间显示系统
-- ====================================
function StartTimeDisplay()
    if timeDisplayThread then
        timeDisplayThread = nil
    end
    
    -- 立即请求一次剩余时间
    TriggerServerEvent('yx_prison:getRemainingTime')
    
    timeDisplayThread = CreateThread(function()
        while isInPrison do
            -- 每5秒向服务端请求剩余时间
            TriggerServerEvent('yx_prison:getRemainingTime')
            Wait(10000)
        end
    end)
    
    -- 单独的绘制线程，每帧都绘制
    CreateThread(function()
        local cachedText = ''
        local lastUpdateTime = 0
        
        while isInPrison do
            if remainingTime > 0 then
                local currentTime = GetGameTimer()
                
                -- 只在时间变化时更新文本，避免闪烁
                if currentTime - lastUpdateTime > 500 then -- 每500ms更新一次文本缓存
                    local hours = math.floor(remainingTime / 60)
                    local minutes = remainingTime % 60
                    local timeText = ''
                    
                    if hours > 0 then
                        timeText = string.format('%d小时%d分钟', hours, minutes)
                    else
                        timeText = string.format('%d分钟', minutes)
                    end
                    
                    cachedText = '剩余刑期: ' .. timeText
                    if Config.RoutingBucket and Config.RoutingBucket.enable then
                        cachedText = cachedText .. '\n[单人监狱世界]'
                    end
                    
                    lastUpdateTime = currentTime
                end
                
                -- 每帧绘制相同的文本，避免闪烁
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.6, 0.6)
                SetTextColour(255, 255, 255, 255)
                SetTextDropShadow(0, 0, 0, 0, 255)
                SetTextEdge(1, 0, 0, 0, 255)
                SetTextDropShadow()
                SetTextOutline()
                SetTextEntry("STRING")
                AddTextComponentString(cachedText)
                DrawText(0.02, 0.02)
            end
            Wait(0) -- 每帧绘制，但文本内容稳定
        end
    end)
end

-- 将剩余时间转换为易读格式
function FormatTime(minutes)
    if minutes <= 0 then return '已释放' end
    
    local hours = math.floor(minutes / 60)
    local mins = minutes % 60
    
    if hours > 0 then
        return string.format('%d小时%d分钟', hours, mins)
    else
        return string.format('%d分钟', mins)
    end
end

-- ====================================
-- 调试命令 (仅在调试模式下可用)
-- ====================================
if Config.Debug then
    RegisterCommand('prisontime', function()
        TriggerServerEvent('yx_prison:getRemainingTime')
        if isInPrison then
            DebugPrint('当前监狱状态: 是, 剩余时间: ' .. remainingTime .. ' 分钟')
        else
            DebugPrint('当前监狱状态: 否')
        end
    end, false)
end

-- ====================================
-- 资源启动时的客户端初始化
-- ====================================
CreateThread(function()
    Wait(2000)
    DebugPrint('监狱系统客户端已初始化')
end)