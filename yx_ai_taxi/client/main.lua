--[[
    ====================================
    AI 出租车系统 - 客户端主逻辑
    作者：于晓
    描述：处理出租车召唤、生成、驾驶和到达逻辑
    ====================================
]]--

-- ============================================
-- 本地变量（避免全局污染）
-- ============================================
local current_taxi = nil          -- 当前出租车实体
local current_driver = nil        -- 当前司机NPC实体
local current_blip = nil          -- 当前地图标记
local is_taxi_active = false      -- 出租车是否激活中
local destination_coords = nil    -- 目标坐标（玩家发起命令时的位置）

-- 第二阶段：行程状态变量
local trip_state = 'none'         -- 行程状态: none/waiting/boarding/confirming/driving/completed
local waypoint_coords = nil       -- Waypoint目标坐标
local is_player_in_taxi = false   -- 玩家是否在出租车内
local is_driver_rushed = false    -- 司机是否被催促过

-- 第三阶段：计费相关变量
local trip_start_coords = nil     -- 行程起始坐标
local current_fare = 0            -- 当前车费
local show_fare_ui = false        -- 是否显示车费UI
local taxi_spawn_time = 0         -- 出租车生成时间（用于超时检测）

-- ============================================
-- 前向声明（解决函数相互调用问题）
-- ============================================
local StartBoardingCheckThread
local StartWaypointConfirmThread
local StartTripMonitorThread
local StartExitCheckThread
local StartAutoExitThread
local StartIdleTimeoutThread
local CreateTaxiBlip
local RemoveTaxiBlip
local DriverLeave
local ShowNotification
local SettleFare
local UpdateCurrentFare
local DriverSpeak
local HandleFareEvasion
local CalculateFare
local DeductPlayerMoney
local SendFareEvasionAlert

-- ============================================
-- 模型加载函数（异步安全）
-- ============================================
--[[
    异步加载模型
    @param model_name string 模型名称
    @return boolean 是否加载成功
    @description 使用异步方式加载模型，带超时保护
]]--
local function LoadModelAsync(model_name)
    local model_hash = GetHashKey(model_name)
    
    -- 检查模型是否有效
    if not IsModelValid(model_hash) then
        DebugPrint('无效的模型: ' .. model_name)
        return false
    end
    
    -- 请求模型
    RequestModel(model_hash)
    
    -- 异步等待加载完成，带超时保护
    local timeout = Config.Taxi.model_load_timeout
    local start_time = GetGameTimer()
    
    while not HasModelLoaded(model_hash) do
        if GetGameTimer() - start_time > timeout then
            DebugPrint('模型加载超时: ' .. model_name)
            return false
        end
        Citizen.Wait(10)
    end
    
    DebugPrint('模型加载成功: ' .. model_name)
    return true
end

-- ============================================
-- 释放模型函数
-- ============================================
--[[
    释放已加载的模型
    @param model_name string 模型名称
    @return void
]]--
local function ReleaseModel(model_name)
    local model_hash = GetHashKey(model_name)
    SetModelAsNoLongerNeeded(model_hash)
    DebugPrint('释放模型: ' .. model_name)
end

-- ============================================
-- 道路节点查找函数
-- ============================================
--[[
    在指定范围内查找合法道路节点
    @param player_coords vector3 玩家坐标
    @return vector3|nil, number|nil 道路坐标和朝向，找不到返回nil
    @description 在玩家周围随机搜索合法道路节点
]]--
local function FindRoadNodeNearPlayer(player_coords)
    local min_dist = Config.Taxi.spawn_radius_min
    local max_dist = Config.Taxi.spawn_radius_max
    local attempts = Config.Taxi.node_search_attempts
    
    for i = 1, attempts do
        -- 生成随机角度和距离
        local angle = GetRandomAngle()
        local distance = GetRandomFloat(min_dist, max_dist)
        
        -- 计算搜索坐标
        local search_coords = GetOffsetCoords(player_coords, angle, distance)
        
        -- 使用原生函数查找最近的道路节点
        local found, node_coords, heading = GetClosestVehicleNodeWithHeading(
            search_coords.x,
            search_coords.y,
            search_coords.z,
            1,    -- 节点类型：1 = 普通道路
            3.0,  -- 搜索半径
            0     -- 标志
        )
        
        if found then
            DebugPrint(string.format('找到道路节点 (尝试 %d/%d): %.2f, %.2f, %.2f', 
                i, attempts, node_coords.x, node_coords.y, node_coords.z))
            return node_coords, heading
        end
        
        DebugPrint(string.format('搜索道路节点失败 (尝试 %d/%d)', i, attempts))
    end
    
    return nil, nil
end

-- ============================================
-- 创建地图标记函数
-- ============================================
--[[
    为出租车创建地图标记（Blip）
    @param entity number 实体ID
    @return number Blip ID
]]--
CreateTaxiBlip = function(entity)
    local blip = AddBlipForEntity(entity)
    
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, false)
    
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blip.name)
    EndTextCommandSetBlipName(blip)
    
    DebugPrint('创建出租车Blip: ' .. tostring(blip))
    return blip
end

-- ============================================
-- 移除地图标记函数
-- ============================================
--[[
    移除地图标记
    @return void
]]--
RemoveTaxiBlip = function()
    if current_blip and DoesBlipExist(current_blip) then
        RemoveBlip(current_blip)
        DebugPrint('移除出租车Blip')
    end
    current_blip = nil
end

-- ============================================
-- 生成出租车函数
-- ============================================
--[[
    在指定位置生成出租车
    @param spawn_coords vector3 生成坐标
    @param heading number 朝向
    @return number|nil 车辆实体ID，失败返回nil
]]--
local function SpawnTaxi(spawn_coords, heading)
    local vehicle_model = Config.Taxi.model
    
    -- 加载车辆模型
    if not LoadModelAsync(vehicle_model) then
        return nil
    end
    
    -- 创建车辆
    local vehicle = CreateVehicle(
        GetHashKey(vehicle_model),
        spawn_coords.x,
        spawn_coords.y,
        spawn_coords.z,
        heading,
        true,   -- 网络实体
        false   -- 脚本托管
    )
    
    if not DoesEntityExist(vehicle) then
        DebugPrint('车辆创建失败')
        ReleaseModel(vehicle_model)
        return nil
    end
    
    -- 等待实体完全加载
    local wait_count = 0
    while not DoesEntityExist(vehicle) and wait_count < 50 do
        Citizen.Wait(100)
        wait_count = wait_count + 1
    end
    
    if not DoesEntityExist(vehicle) then
        DebugPrint('车辆实体等待超时')
        ReleaseModel(vehicle_model)
        return nil
    end
    
    -- 验证坐标有效性
    local vehicle_coords = GetEntityCoords(vehicle)
    if vehicle_coords.x == 0.0 and vehicle_coords.y == 0.0 and vehicle_coords.z == 0.0 then
        DebugPrint('车辆坐标无效')
        DeleteEntity(vehicle)
        ReleaseModel(vehicle_model)
        return nil
    end
    
    -- 设置车辆属性
    SetEntityAsMissionEntity(vehicle, true, true)  -- 设为任务实体，防止被刷掉
    SetVehicleOnGroundProperly(vehicle)            -- 确保车辆正确放置在地面
    SetVehicleEngineOn(vehicle, true, true, false) -- 启动引擎
    SetVehicleDoorsLocked(vehicle, 1)              -- 解锁车门（1 = 解锁）
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)  -- 允许所有玩家开门
    SetVehicleNeedsToBeHotwired(vehicle, false)    -- 不需要热接线启动
    
    -- 设置燃油为满油状态
    SetVehicleFuelLevel(vehicle, 100.0)
    
    -- 兼容 CDN 燃料系统
    if GetResourceState('cdn-fuel') == 'started' then
        pcall(function()
            exports['cdn-fuel']:SetFuel(vehicle, 100.0)
        end)
        DebugPrint('通过 cdn-fuel 设置燃油为满油')
    end
    
    -- 给玩家车辆钥匙（通过服务端）
    if Config.VehicleKeys.enabled then
        local plate = GetVehicleNumberPlateText(vehicle)
        if plate then
            -- 去除车牌前后空格
            plate = plate:gsub("^%s*(.-)%s*$", "%1")
            TriggerServerEvent('yx_ai_taxi:giveKeys', plate)
            DebugPrint('请求服务端给玩家钥匙，车牌: ' .. plate)
        end
    end
    
    -- 释放模型
    ReleaseModel(vehicle_model)
    
    DebugPrint('出租车生成成功: ' .. tostring(vehicle))
    return vehicle
end

-- ============================================
-- 生成司机NPC函数
-- ============================================
--[[
    在车辆内生成司机NPC
    @param vehicle number 车辆实体ID
    @return number|nil NPC实体ID，失败返回nil
]]--
local function SpawnDriver(vehicle)
    local driver_model = Config.Driver.model
    
    -- 加载NPC模型
    if not LoadModelAsync(driver_model) then
        return nil
    end
    
    -- 获取车辆坐标
    local vehicle_coords = GetEntityCoords(vehicle)
    
    -- 创建NPC
    local ped = CreatePedInsideVehicle(
        vehicle,
        4,  -- PED类型：4 = 市民
        GetHashKey(driver_model),
        -1, -- 座位：-1 = 驾驶座
        true,   -- 网络实体
        false   -- 脚本托管
    )
    
    if not DoesEntityExist(ped) then
        DebugPrint('司机NPC创建失败')
        ReleaseModel(driver_model)
        return nil
    end
    
    -- 设置NPC属性
    SetEntityAsMissionEntity(ped, true, true)      -- 设为任务实体
    SetBlockingOfNonTemporaryEvents(ped, true)     -- 阻止临时事件打断
    SetPedCanBeDraggedOut(ped, false)              -- 防止被拖出车辆
    SetPedCanBeKnockedOffVehicle(ped, 1)           -- 防止被撞下车
    
    -- 释放模型
    ReleaseModel(driver_model)
    
    DebugPrint('司机NPC生成成功: ' .. tostring(ped))
    return ped
end

-- ============================================
-- 设置驾驶任务函数
-- ============================================
--[[
    让司机驾驶到目标位置
    @param driver number 司机NPC实体ID
    @param vehicle number 车辆实体ID
    @param target_coords vector3 目标坐标
    @param speed number|nil 可选驾驶速度，默认使用Config.Driver.driving_speed
    @param driving_style number|nil 可选驾驶风格，默认使用Config.Driver.driving_style
    @return void
]]--
local function SetDriverTask(driver, vehicle, target_coords, speed, driving_style)
    -- 清除当前任务
    ClearPedTasks(driver)
    
    local drive_speed = speed or Config.Driver.driving_speed
    local style = driving_style or Config.Driver.driving_style
    
    -- 获取目标点附近的道路节点（确保目的地在路上）
    local found, road_coords, road_heading = GetClosestVehicleNodeWithHeading(
        target_coords.x,
        target_coords.y,
        target_coords.z,
        1, 3.0, 0
    )
    
    local final_coords = found and road_coords or target_coords
    
    -- 设置驾驶任务
    TaskVehicleDriveToCoordLongrange(
        driver,
        vehicle,
        final_coords.x,
        final_coords.y,
        final_coords.z,
        drive_speed,
        style,
        Config.Driver.stop_distance
    )
    
    DebugPrint(string.format('设置驾驶任务: 目标 (%.2f, %.2f, %.2f), 速度: %.1f, 风格: %d', 
        final_coords.x, final_coords.y, final_coords.z, drive_speed, style))
end

-- ============================================
-- 获取玩家Waypoint坐标
-- ============================================
--[[
    获取玩家地图上标记的Waypoint坐标
    @return vector3|nil Waypoint坐标，没有则返回nil
]]--
local function GetWaypointCoords()
    -- 使用Blip类型8获取Waypoint
    local waypoint_blip = GetFirstBlipInfoId(8)
    
    if not DoesBlipExist(waypoint_blip) then
        return nil
    end
    
    local coords = GetBlipCoords(waypoint_blip)
    
    -- 获取地面高度
    local found, ground_z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    if found then
        coords = vector3(coords.x, coords.y, ground_z)
    end
    
    DebugPrint(string.format('获取Waypoint坐标: %.2f, %.2f, %.2f', coords.x, coords.y, coords.z))
    return coords
end

-- ============================================
-- 检查玩家座位是否合法
-- ============================================
--[[
    检查玩家当前座位是否在允许的后座列表中
    @param vehicle number 车辆实体ID
    @return boolean 是否在合法座位
]]--
local function IsPlayerInAllowedSeat(vehicle)
    local player_ped = PlayerPedId()
    local player_seat = nil
    
    -- 遍历所有座位检查玩家在哪个座位
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        if GetPedInVehicleSeat(vehicle, seat) == player_ped then
            player_seat = seat
            break
        end
    end
    
    if player_seat == nil then
        return false
    end
    
    -- 检查是否在允许的座位列表中
    for _, allowed_seat in ipairs(Config.Trip.allowed_seats) do
        if player_seat == allowed_seat then
            DebugPrint('玩家在合法座位: ' .. tostring(player_seat))
            return true
        end
    end
    
    DebugPrint('玩家在非法座位: ' .. tostring(player_seat))
    return false
end

-- ============================================
-- 显示屏幕帮助文本
-- ============================================
--[[
    在屏幕上显示帮助文本提示
    @param text string 提示文本
    @return void
]]--
local function ShowHelpText(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

-- ============================================
-- 计算车费
-- ============================================
--[[
    根据起始点和终点计算车费
    @param start_coords vector3 起始坐标
    @param end_coords vector3 终点坐标
    @return number 车费金额
]]--
CalculateFare = function(start_coords, end_coords)
    local distance = GetDistanceBetweenCoords(start_coords, end_coords, true)
    local fare = Config.Fare.base_fare + (distance * Config.Fare.per_meter)
    -- 确保不低于最低收费
    if fare < Config.Fare.min_fare then
        fare = Config.Fare.min_fare
    end
    return math.floor(fare)
end

-- ============================================
-- 实时计算当前车费
-- ============================================
--[[
    根据当前位置实时计算车费
    @return number 当前车费
]]--
UpdateCurrentFare = function()
    if trip_start_coords and current_taxi and DoesEntityExist(current_taxi) then
        local current_coords = GetEntityCoords(current_taxi)
        current_fare = CalculateFare(trip_start_coords, current_coords)
    end
    return current_fare
end

-- ============================================
-- 司机说话函数
-- ============================================
--[[
    让司机说话
    @param speech_name string 语音名称
    @return void
]]--
DriverSpeak = function(speech_name)
    if not Config.DriverSpeech.enabled then return end
    if not current_driver or not DoesEntityExist(current_driver) then return end
    
    PlayPedAmbientSpeechNative(current_driver, speech_name, 'SPEECH_PARAMS_FORCE_SHOUTED')
    DebugPrint('司机说话: ' .. speech_name)
end

-- ============================================
-- 扣除玩家余额（QBCore）
-- ============================================
--[[
    通过QBCore扣除玩家余额（优先现金，不足则银行）
    @param amount number 金额
    @return boolean 是否成功
]]--
DeductPlayerMoney = function(amount)
    -- 尝试使用QBCore
    if GetResourceState('qb-core') ~= 'started' then
        DebugPrint('QBCore未启动，跳过扣款')
        return true  -- 没有QBCore时默认成功（不触发霸王车）
    end
    
    local QBCore = exports['qb-core']:GetCoreObject()
    if not QBCore then
        DebugPrint('无法获取QBCore对象')
        return true
    end
    
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or not Player.money then
        DebugPrint('无法获取玩家数据')
        return true
    end
    
    local cash = Player.money.cash or 0
    local bank = Player.money.bank or 0
    local total = cash + bank
    
    DebugPrint(string.format('玩家余额 - 现金: $%d, 银行: $%d, 车费: $%d', cash, bank, amount))
    
    -- 检查总余额是否足够
    if total < amount then
        DebugPrint('余额不足，触发霸王车')
        return false
    end
    
    -- 触发服务端扣款（服务端会自动选择从现金或银行扣除）
    TriggerServerEvent('yx_ai_taxi:deductMoney', amount)
    DebugPrint('已发送扣款请求')
    return true
end

-- ============================================
-- 霸王车报警（rcore_dispatch）
-- ============================================
--[[
    发送霸王车报警到警察调度系统
    @param coords vector3 事件坐标
    @return void
    @description 使用 rcore_dispatch API 发送警报给 police 和 lssd
]]--
SendFareEvasionAlert = function(coords)
    -- 检查是否启用报警功能
    if not Config.Dispatch.enabled then
        DebugPrint('报警功能已禁用')
        return
    end
    
    -- 检查 rcore_dispatch 是否已启动
    if GetResourceState('rcore_dispatch') ~= 'started' then
        DebugPrint('rcore_dispatch 未启动，跳过报警')
        return
    end
    
    -- 获取玩家数据
    local playerData = nil
    local success, err = pcall(function()
        playerData = exports['rcore_dispatch']:GetPlayerData()
    end)
    
    if not success or not playerData then
        DebugPrint('获取玩家数据失败: ' .. tostring(err))
        -- 使用基础坐标发送警报
        playerData = {
            coords = coords,
            street = '未知位置',
            sex = '未知'
        }
    end
    
    -- 翻译性别为中文
    local sex_cn = '未知'
    if playerData.sex == 'male' then
        sex_cn = '男'
    elseif playerData.sex == 'female' then
        sex_cn = '女'
    end
    
    -- 构建警报信息
    local alertText = string.format(
        '出租车司机报警：有乘客拒绝支付车费 %s%d，企图逃单！嫌疑人性别：%s，最后出现在 %s 附近。',
        Config.Fare.currency_symbol,
        current_fare > 0 and current_fare or Config.Fare.min_fare,
        sex_cn,
        playerData.street or '未知位置'
    )
    
    -- 构建警报数据
    local alertData = {
        code = Config.Dispatch.code,
        default_priority = Config.Dispatch.priority,
        coords = playerData.coords or coords,
        job = Config.Dispatch.jobs,  -- police 和 lssd
        text = alertText,
        type = 'alerts',
        blip_time = Config.Dispatch.blip_time,
        blip = {
            sprite = Config.Dispatch.blip_sprite,
            colour = Config.Dispatch.blip_colour,
            scale = Config.Dispatch.blip_scale,
            text = Config.Dispatch.blip_text,
            flashes = Config.Dispatch.blip_flashes,
            radius = 0
        }
    }
    
    -- 发送警报
    TriggerServerEvent('rcore_dispatch:server:sendAlert', alertData)
    DebugPrint('已发送霸王车警报到调度系统')
end

-- ============================================
-- 霸王车处理
-- ============================================
--[[
    处理玩家余额不足的情况
    @return void
]]--
HandleFareEvasion = function()
    ShowNotification(Config.Messages.fare_insufficient)
    
    if current_driver and DoesEntityExist(current_driver) then
        local player_ped = PlayerPedId()
        local player_coords = GetEntityCoords(player_ped)
        
        -- 司机愤怒说话
        DriverSpeak(Config.DriverSpeech.angry)
        
        -- 司机下车
        TaskLeaveVehicle(current_driver, current_taxi, 0)
        
        -- 发送警报到 rcore_dispatch（霸王车报警）
        SendFareEvasionAlert(player_coords)
        
        -- 等待司机下车后攻击玩家
        Citizen.SetTimeout(2000, function()
            if current_driver and DoesEntityExist(current_driver) then
                -- 设置司机为敌对
                SetPedAsEnemy(current_driver, true)
                SetPedCombatAttributes(current_driver, 46, true)
                -- 攻击玩家
                TaskCombatPed(current_driver, player_ped, 0, 16)
                
                DebugPrint('霸王车处理：司机攻击玩家')
            end
        end)
    end
    
    -- 清理状态
    RemoveTaxiBlip()
    trip_state = 'none'
    waypoint_coords = nil
    is_player_in_taxi = false
    is_driver_rushed = false
    is_taxi_active = false
    show_fare_ui = false
    current_fare = 0
    trip_start_coords = nil
end

-- ============================================
-- 结算车费
-- ============================================
--[[
    行程结束时结算车费
    @return boolean 是否支付成功
]]--
SettleFare = function()
    if current_fare <= 0 then
        current_fare = Config.Fare.min_fare
    end
    
    DebugPrint('结算车费: ' .. Config.Fare.currency_symbol .. current_fare)
    
    -- 尝试扣款
    local paid = DeductPlayerMoney(current_fare)
    
    if paid then
        ShowNotification(string.format(Config.Messages.fare_paid, Config.Fare.currency_symbol, current_fare))
        -- 司机告别
        DriverSpeak(Config.DriverSpeech.arrive)
        return true
    else
        -- 霸王车处理
        HandleFareEvasion()
        return false
    end
end

-- ============================================
-- 司机驶离函数
-- ============================================
--[[
    让司机驾车离开并清理资源
    @return void
]]--
DriverLeave = function()
    DebugPrint('司机准备驶离')
    
    -- 捕获当前引用，避免闭包问题
    local ref_driver = current_driver
    local ref_taxi = current_taxi
    
    if ref_driver and DoesEntityExist(ref_driver) and 
       ref_taxi and DoesEntityExist(ref_taxi) then
        ClearPedTasks(ref_driver)
        
        TaskVehicleDriveWander(
            ref_driver, ref_taxi,
            Config.Driver.driving_speed,
            Config.Driver.driving_style
        )
        
        -- 延迟后标记为不再需要（让游戏自然清理）
        Citizen.SetTimeout(Config.Trip.driver_leave_delay, function()
            if ref_driver and DoesEntityExist(ref_driver) then
                SetEntityAsMissionEntity(ref_driver, false, true)
                SetEntityAsNoLongerNeeded(ref_driver)
            end
            if ref_taxi and DoesEntityExist(ref_taxi) then
                SetEntityAsMissionEntity(ref_taxi, false, true)
                SetEntityAsNoLongerNeeded(ref_taxi)
            end
            DebugPrint('司机和车辆已标记为不再需要')
        end)
    end
    
    -- 立即重置所有状态变量
    RemoveTaxiBlip()
    current_driver = nil
    current_taxi = nil
    trip_state = 'none'
    waypoint_coords = nil
    is_player_in_taxi = false
    is_driver_rushed = false
    is_taxi_active = false
    show_fare_ui = false
    current_fare = 0
    trip_start_coords = nil
    destination_coords = nil
    taxi_spawn_time = 0
end

-- ============================================
-- 显示通知函数
-- ============================================
--[[
    显示屏幕通知
    @param message string 消息内容
    @return void
]]--
ShowNotification = function(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, true)
end

-- ============================================
-- 清理出租车资源函数
-- ============================================
--[[
    清理所有出租车相关资源
    @return void
]]--
local function CleanupTaxi()
    -- 移除Blip
    RemoveTaxiBlip()
    
    -- 使用 SetEntityAsNoLongerNeeded 让游戏自然清理，减少突兀感
    if current_driver and DoesEntityExist(current_driver) then
        SetEntityAsMissionEntity(current_driver, false, true)
        SetEntityAsNoLongerNeeded(current_driver)
        DebugPrint('司机标记为不再需要')
    end
    current_driver = nil
    
    if current_taxi and DoesEntityExist(current_taxi) then
        SetEntityAsMissionEntity(current_taxi, false, true)
        SetEntityAsNoLongerNeeded(current_taxi)
        DebugPrint('出租车标记为不再需要')
    end
    current_taxi = nil
    
    -- 重置所有状态变量
    is_taxi_active = false
    destination_coords = nil
    trip_state = 'none'
    waypoint_coords = nil
    is_player_in_taxi = false
    is_driver_rushed = false
    show_fare_ui = false
    current_fare = 0
    trip_start_coords = nil
    taxi_spawn_time = 0
    
    DebugPrint('出租车资源清理完成')
end

-- ============================================
-- 到达检测线程（第一阶段：出租车到达玩家位置）
-- ============================================
--[[
    监控出租车是否到达玩家召唤位置，或玩家是否靠近出租车
    @return void
    @description 使用异步线程持续检测，避免阻塞主线程
]]--
local function StartArrivalCheckThread()
    Citizen.CreateThread(function()
        -- 预缓存配置值
        local arrival_dist = Config.Driver.arrival_distance
        local nearby_dist = Config.Trip.player_nearby_distance
        local check_interval = Config.Intervals.arrival_check
        
        while is_taxi_active and trip_state == 'waiting' do
            -- 检查实体是否有效且可见
            if not current_taxi or not DoesEntityExist(current_taxi) then
                DebugPrint('出租车实体丢失，清理资源')
                CleanupTaxi()
                break
            end
            
            -- 额外检查：确保车辆确实存在于游戏世界中
            local taxi_coords = GetEntityCoords(current_taxi)
            if taxi_coords.x == 0.0 and taxi_coords.y == 0.0 and taxi_coords.z == 0.0 then
                DebugPrint('出租车坐标无效，可能未正确生成')
                CleanupTaxi()
                ShowNotification(Config.Messages.no_road_found)
                break
            end
            
            -- 缓存玩家 Ped（避免每帧调用）
            local player_ped = PlayerPedId()
            local player_coords = GetEntityCoords(player_ped)
            
            -- 计算距离
            local distance_to_dest = #(taxi_coords - destination_coords)
            local distance_to_player = #(taxi_coords - player_coords)
            
            DebugPrint(string.format('距离召唤点: %.2f 米, 距离玩家: %.2f 米', distance_to_dest, distance_to_player))
            
            -- 检查是否到达
            if distance_to_dest <= arrival_dist or distance_to_player <= nearby_dist then
                -- 再次验证实体存在
                if not current_taxi or not DoesEntityExist(current_taxi) then
                    DebugPrint('到达时发现出租车实体丢失')
                    CleanupTaxi()
                    break
                end
                
                if distance_to_player <= nearby_dist then
                    DebugPrint('玩家靠近出租车，触发到达')
                else
                    DebugPrint('出租车已到达玩家召唤位置')
                end
                
                -- 停止车辆
                if current_driver and DoesEntityExist(current_driver) then
                    ClearPedTasks(current_driver)
                end
                
                -- 设置车辆完全停止
                SetVehicleForwardSpeed(current_taxi, 0.0)
                SetVehicleHandbrake(current_taxi, true)
                
                -- 显示到达通知
                ShowNotification(Config.Messages.taxi_arrived)
                
                -- 移除Blip
                RemoveTaxiBlip()
                
                -- 切换到上车等待状态
                trip_state = 'boarding'
                DebugPrint('切换状态: boarding')
                
                -- 启动上车检测线程
                StartBoardingCheckThread()
                break
            end
            
            -- 等待下一次检测
            Citizen.Wait(check_interval)
        end
    end)
end

-- ============================================
-- 上车检测线程（第二阶段）
-- ============================================
--[[
    监控玩家是否上车，提供手动上车功能
    @return void
]]--
StartBoardingCheckThread = function()
    Citizen.CreateThread(function()
        local is_entering = false  -- 防止重复触发进入动作
        -- 预缓存配置值
        local nearby_dist = Config.Trip.player_nearby_distance
        local confirm_key = Config.Trip.confirm_key
        local seat_priority = {1, 2, 0}  -- 后座左、后座右、副驾驶
        -- 缓存玩家ID（在循环外获取，循环内只在必要时更新）
        local cached_player_id = PlayerId()
        local cached_player_ped = PlayerPedId()
        local last_ped_check = 0
        
        while trip_state == 'boarding' do
            -- 检查实体是否有效
            if not current_taxi or not DoesEntityExist(current_taxi) then
                DebugPrint('出租车实体丢失')
                CleanupTaxi()
                break
            end
            
            -- 每500ms更新一次玩家Ped缓存（玩家ped可能变化）
            local now = GetGameTimer()
            if now - last_ped_check > 500 then
                cached_player_ped = PlayerPedId()
                last_ped_check = now
            end
            
            local player_vehicle = GetVehiclePedIsIn(cached_player_ped, false)
            
            -- 检查玩家是否已经在出租车内
            if player_vehicle == current_taxi then
                DebugPrint('玩家进入出租车')
                
                is_player_in_taxi = true
                trip_state = 'confirming'
                DebugPrint('切换状态: confirming')
                
                -- 启动Waypoint确认线程
                StartWaypointConfirmThread()
                break
            end
            
            -- 如果玩家不在车内，检测是否靠近出租车并提供手动上车
            if not is_entering then
                local player_coords = GetEntityCoords(cached_player_ped)
                local taxi_coords = GetEntityCoords(current_taxi)
                local distance = #(player_coords - taxi_coords)
                
                -- 玩家在上车距离内
                if distance <= nearby_dist then
                    -- 显示上车提示
                    ShowHelpText(Config.HelpText.enter_taxi)
                    
                    -- 检测E键按下
                    if IsControlJustPressed(0, confirm_key) then
                        DebugPrint('玩家按E键上车')
                        is_entering = true
                        
                        -- 强制解锁车门
                        SetVehicleDoorsLocked(current_taxi, 1)
                        SetVehicleDoorsLockedForAllPlayers(current_taxi, false)
                        SetVehicleDoorsLockedForPlayer(current_taxi, cached_player_id, false)
                        DebugPrint('上车前解锁车门')
                        
                        -- 清除玩家当前任务
                        ClearPedTasks(cached_player_ped)
                        ClearPedTasksImmediately(cached_player_ped)
                        
                        -- 查找空座位
                        local seat_to_enter = nil
                        for _, seat in ipairs(seat_priority) do
                            if IsVehicleSeatFree(current_taxi, seat) then
                                seat_to_enter = seat
                                break
                            end
                        end
                        
                        if seat_to_enter ~= nil then
                            TaskEnterVehicle(cached_player_ped, current_taxi, 5000, seat_to_enter, 2.0, 1, 0)
                            DebugPrint('触发进入车辆任务，座位: ' .. tostring(seat_to_enter))
                            
                            -- 启动监控线程（捕获当前变量）
                            local enter_ped = cached_player_ped
                            local enter_taxi = current_taxi
                            local enter_player_id = cached_player_id
                            
                            Citizen.CreateThread(function()
                                local start_time = GetGameTimer()
                                local timeout = 3000  -- 缩短超时时间到3秒
                                local task_started = false
                                
                                Citizen.Wait(300)  -- 等待任务启动
                                
                                while GetGameTimer() - start_time < timeout do
                                    -- 检查玩家是否成功上车
                                    if GetVehiclePedIsIn(enter_ped, false) == enter_taxi then
                                        DebugPrint('玩家成功进入车辆')
                                        is_entering = false
                                        return
                                    end
                                    
                                    -- 检查车辆是否存在
                                    if not enter_taxi or not DoesEntityExist(enter_taxi) then
                                        DebugPrint('车辆不存在，重置状态')
                                        break
                                    end
                                    
                                    -- 持续解锁车门
                                    SetVehicleDoorsLocked(enter_taxi, 1)
                                    SetVehicleDoorsLockedForPlayer(enter_taxi, enter_player_id, false)
                                    
                                    -- 检测上车任务状态（TASK_ENTER_VEHICLE = 160）
                                    local is_task_active = GetIsTaskActive(enter_ped, 160)
                                    
                                    if is_task_active then
                                        task_started = true
                                    elseif task_started then
                                        -- 任务曾经启动过但现在停止了，说明被取消
                                        DebugPrint('上车任务被取消，重置状态')
                                        break
                                    end
                                    
                                    Citizen.Wait(50)  -- 更高频率检测
                                end
                                
                                DebugPrint('上车检测结束，重置状态')
                                is_entering = false
                            end)
                        else
                            DebugPrint('没有空座位')
                            is_entering = false
                        end
                    end
                end
            end
            
            Citizen.Wait(0)  -- 需要每帧检测按键
        end
    end)
end

-- ============================================
-- Waypoint确认线程（第二阶段）
-- ============================================
--[[
    等待玩家设置Waypoint并确认目的地
    @return void
]]--
StartWaypointConfirmThread = function()
    Citizen.CreateThread(function()
        local last_no_waypoint_notify = 0
        local last_vehicle_check = 0
        -- 预缓存配置值
        local confirm_key = Config.Trip.confirm_key
        local base_fare = Config.Fare.base_fare
        -- 缓存玩家 Ped
        local cached_player_ped = PlayerPedId()
        
        while trip_state == 'confirming' do
            local current_time = GetGameTimer()
            
            -- 每500ms检查一次玩家是否在车内并更新缓存
            if current_time - last_vehicle_check > 500 then
                last_vehicle_check = current_time
                cached_player_ped = PlayerPedId()  -- 更新缓存
                local player_vehicle = GetVehiclePedIsIn(cached_player_ped, false)
                
                if player_vehicle ~= current_taxi then
                    DebugPrint('玩家离开出租车（确认阶段）')
                    ShowNotification(Config.Messages.player_left)
                    trip_state = 'boarding'
                    is_player_in_taxi = false
                    StartBoardingCheckThread()
                    break
                end
            end
            
            -- 检查是否有Waypoint
            waypoint_coords = GetWaypointCoords()
            
            if waypoint_coords then
                ShowHelpText(Config.HelpText.confirm_trip)
                
                if IsControlJustPressed(0, confirm_key) then
                    DebugPrint('玩家确认目的地')
                    trip_state = 'driving'
                    
                    -- 记录行程起始坐标
                    trip_start_coords = GetEntityCoords(current_taxi)
                    current_fare = base_fare
                    show_fare_ui = true
                    
                    -- 司机问候
                    DriverSpeak(Config.DriverSpeech.greet)
                    
                    -- 显示出发通知
                    ShowNotification(Config.Messages.trip_started)
                    
                    -- 释放手刹，启动驾驶
                    SetVehicleHandbrake(current_taxi, false)
                    SetVehicleMaxSpeed(current_taxi, 50.0)
                    SetDriverTask(current_driver, current_taxi, waypoint_coords, Config.Driver.trip_speed)
                    
                    -- 重新创建Blip追踪出租车
                    current_blip = CreateTaxiBlip(current_taxi)
                    
                    -- 启动行程监控线程
                    StartTripMonitorThread()
                    break
                end
            else
                ShowHelpText(Config.HelpText.set_waypoint)
                
                if current_time - last_no_waypoint_notify > 5000 then
                    ShowNotification(Config.Messages.no_waypoint)
                    last_no_waypoint_notify = current_time
                end
            end
            
            Citizen.Wait(0)
        end
    end)
end

-- ============================================
-- 行程监控线程（第二阶段）
-- ============================================
--[[
    监控行程状态：跳车检测、到达检测和催促功能
    @return void
]]--
StartTripMonitorThread = function()
    Citizen.CreateThread(function()
        -- 预缓存配置值
        local stop_dist = Config.Driver.stop_distance
        local rush_key = Config.Trip.rush_key
        local confirm_key = Config.Trip.confirm_key
        local rush_speed = Config.Driver.rush_speed
        local rush_style = Config.Driver.driving_style_rush
        local driving_speed = Config.Driver.driving_speed
        local driving_style = Config.Driver.driving_style
        local leave_delay = Config.Trip.driver_leave_delay
        -- 预缓存提示文字
        local rush_hint = Config.HelpText.rush_driver
        local stop_hint = Config.HelpText.stop_here
        local rush_stop_hint = rush_hint .. '~n~' .. stop_hint
        -- 缓存玩家 Ped
        local cached_player_ped = PlayerPedId()
        local last_ped_update = 0
        
        while trip_state == 'driving' do
            -- 检查实体是否有效
            if not current_taxi or not DoesEntityExist(current_taxi) then
                DebugPrint('出租车实体丢失（行程中）')
                CleanupTaxi()
                break
            end
            
            -- 每200ms更新一次玩家Ped缓存
            local now = GetGameTimer()
            if now - last_ped_update > 200 then
                cached_player_ped = PlayerPedId()
                last_ped_update = now
            end
            
            local player_vehicle = GetVehiclePedIsIn(cached_player_ped, false)
            
            -- 检查玩家是否跳车
            if player_vehicle ~= current_taxi then
                DebugPrint('玩家中途下车')
                
                UpdateCurrentFare()
                show_fare_ui = false
                
                -- 结算车费
                SettleFare()
                
                -- 司机驶离
                if current_driver and DoesEntityExist(current_driver) and 
                   current_taxi and DoesEntityExist(current_taxi) then
                    ClearPedTasks(current_driver)
                    TaskVehicleDriveWander(current_driver, current_taxi, driving_speed, driving_style)
                    
                    -- 捕获当前引用
                    local ref_driver = current_driver
                    local ref_taxi = current_taxi
                    
                    Citizen.SetTimeout(leave_delay, function()
                        if ref_driver and DoesEntityExist(ref_driver) then
                            SetEntityAsMissionEntity(ref_driver, false, true)
                            SetEntityAsNoLongerNeeded(ref_driver)
                        end
                        if ref_taxi and DoesEntityExist(ref_taxi) then
                            SetEntityAsMissionEntity(ref_taxi, false, true)
                            SetEntityAsNoLongerNeeded(ref_taxi)
                        end
                    end)
                end
                
                -- 重置所有状态（必须重置 trip_state 为 'none' 才能再次呼叫）
                RemoveTaxiBlip()
                current_driver = nil
                current_taxi = nil
                waypoint_coords = nil
                is_player_in_taxi = false
                is_driver_rushed = false
                is_taxi_active = false
                trip_state = 'none'  -- 重置为 'none' 允许再次呼叫
                trip_start_coords = nil
                current_fare = 0
                destination_coords = nil  -- 也重置目的地坐标
                DebugPrint('中途下车，状态已重置，可以再次呼叫')
                break
            end
            
            -- 实时更新车费
            UpdateCurrentFare()
            
            -- 计算距离
            local show_stop_hint_flag = false
            if waypoint_coords then
                local taxi_coords = GetEntityCoords(current_taxi)
                local distance = #(taxi_coords - waypoint_coords)
                show_stop_hint_flag = (distance <= stop_dist)
            end
            
            -- 显示提示
            if show_stop_hint_flag then
                if not is_driver_rushed then
                    ShowHelpText(rush_stop_hint)
                else
                    ShowHelpText(stop_hint)
                end
            else
                if not is_driver_rushed then
                    ShowHelpText(rush_hint)
                end
            end
            
            -- 检测空格键催促司机
            if not is_driver_rushed and IsControlJustPressed(0, rush_key) then
                is_driver_rushed = true
                DebugPrint('玩家催促司机')
                ShowNotification(Config.Messages.driver_rush)
                
                DriverSpeak(Config.DriverSpeech.rush_complain)
                
                if current_driver and DoesEntityExist(current_driver) and 
                   current_taxi and DoesEntityExist(current_taxi) and waypoint_coords then
                    ClearPedTasks(current_driver)
                    TaskVehicleDriveToCoordLongrange(
                        current_driver, current_taxi,
                        waypoint_coords.x, waypoint_coords.y, waypoint_coords.z,
                        rush_speed, rush_style, stop_dist
                    )
                    DebugPrint('已重新设置激进驾驶任务')
                end
            end
            
            -- 检测E键停车
            if waypoint_coords and show_stop_hint_flag and IsControlJustPressed(0, confirm_key) then
                DebugPrint('玩家命令停车')
                
                if current_driver and DoesEntityExist(current_driver) then
                    ClearPedTasks(current_driver)
                    TaskVehicleTempAction(current_driver, current_taxi, 1, 3000)
                end
                
                SetVehicleMaxSpeed(current_taxi, 0.0)
                SetVehicleForwardSpeed(current_taxi, 0.0)
                SetVehicleHandbrake(current_taxi, true)
                
                ShowNotification(Config.Messages.trip_completed)
                RemoveTaxiBlip()
                trip_state = 'completed'
                
                StartAutoExitThread()
                break
            end
            
            Citizen.Wait(0)
        end
    end)
end

-- ============================================
-- 自动下车流程（行程结束）
-- ============================================
--[[
    到达目的地后自动让玩家下车，然后清理资源
    @return void
]]--
StartAutoExitThread = function()
    Citizen.CreateThread(function()
        -- 捕获当前引用，避免闭包问题
        local ref_taxi = current_taxi
        local ref_driver = current_driver
        local cached_player_ped = PlayerPedId()
        
        -- 计算最终车费
        UpdateCurrentFare()
        
        -- 隐藏车费UI
        show_fare_ui = false
        
        -- 等待车辆完全停止
        Citizen.Wait(1000)
        
        -- 结算车费
        local paid = SettleFare()
        
        -- 如果霸王车，SettleFare会处理后续逻辑
        if not paid then
            return
        end
        
        -- 让玩家自动下车
        if ref_taxi and DoesEntityExist(ref_taxi) then
            TaskLeaveVehicle(cached_player_ped, ref_taxi, 0)
            DebugPrint('玩家自动下车')
        end
        
        -- 等待玩家完成下车动作（最多5秒，带防死逻辑）
        local exit_timeout = GetGameTimer() + 5000
        local check_count = 0
        while GetGameTimer() < exit_timeout and check_count < 50 do
            check_count = check_count + 1
            local player_vehicle = GetVehiclePedIsIn(cached_player_ped, false)
            if not ref_taxi or not DoesEntityExist(ref_taxi) or player_vehicle ~= ref_taxi then
                DebugPrint('玩家已下车')
                break
            end
            Citizen.Wait(100)
        end
        
        -- 5秒后清理车辆和司机
        DebugPrint('5秒后清理车辆和司机')
        Citizen.Wait(5000)
        
        -- 将车辆和司机标记为不再需要
        if ref_driver and DoesEntityExist(ref_driver) then
            SetEntityAsMissionEntity(ref_driver, false, true)
            SetEntityAsNoLongerNeeded(ref_driver)
            DebugPrint('司机已标记为不再需要')
        end
        
        if ref_taxi and DoesEntityExist(ref_taxi) then
            SetEntityAsMissionEntity(ref_taxi, false, true)
            SetEntityAsNoLongerNeeded(ref_taxi)
            DebugPrint('车辆已标记为不再需要')
        end
        
        -- 完整重置所有状态变量
        current_taxi = nil
        current_driver = nil
        current_blip = nil
        trip_state = 'none'
        waypoint_coords = nil
        is_player_in_taxi = false
        is_driver_rushed = false
        trip_start_coords = nil
        current_fare = 0
        is_taxi_active = false
        destination_coords = nil
        taxi_spawn_time = 0
        
        DebugPrint('行程完成，资源已清理')
    end)
end

-- ============================================
-- 下车检测线程（备用，用于玩家中途下车）
-- ============================================
--[[
    检测玩家下车后清理资源
    @return void
]]--
StartExitCheckThread = function()
    Citizen.CreateThread(function()
        while trip_state == 'completed' do
            local player_ped = PlayerPedId()
            local player_vehicle = GetVehiclePedIsIn(player_ped, false)
            
            -- 玩家已下车
            if player_vehicle ~= current_taxi then
                DebugPrint('玩家已下车，行程结束')
                
                -- 司机驶离
                DriverLeave()
                break
            end
            
            Citizen.Wait(Config.Intervals.seat_check)
        end
    end)
end

-- ============================================
-- 召唤出租车主函数
-- ============================================
--[[
    召唤出租车的主要逻辑
    @return void
]]--
local function CallTaxi()
    -- 检查是否已有出租车在途中或行程中
    if is_taxi_active or trip_state ~= 'none' then
        ShowNotification(Config.Messages.already_called)
        return
    end
    
    -- 显示召唤中提示
    ShowNotification(Config.Messages.taxi_spawning)
    
    -- 获取玩家当前坐标作为目的地
    local player_ped = PlayerPedId()
    destination_coords = GetEntityCoords(player_ped)
    
    DebugPrint(string.format('玩家坐标: %.2f, %.2f, %.2f', 
        destination_coords.x, destination_coords.y, destination_coords.z))
    
    -- 查找合法道路节点
    local spawn_coords, spawn_heading = FindRoadNodeNearPlayer(destination_coords)
    
    if not spawn_coords then
        ShowNotification(Config.Messages.no_road_found)
        DebugPrint('未找到合法道路节点')
        return
    end
    
    -- 生成出租车
    current_taxi = SpawnTaxi(spawn_coords, spawn_heading)
    
    if not current_taxi then
        ShowNotification(Config.Messages.no_road_found)
        DebugPrint('出租车生成失败')
        return
    end
    
    -- 生成司机
    current_driver = SpawnDriver(current_taxi)
    
    if not current_driver then
        ShowNotification(Config.Messages.no_road_found)
        CleanupTaxi()
        DebugPrint('司机生成失败')
        return
    end
    
    -- 再次验证实体存在（防止在生成过程中被系统清理）
    Citizen.Wait(500)  -- 短暂等待让游戏世界稳定
    
    if not current_taxi or not DoesEntityExist(current_taxi) then
        ShowNotification(Config.Messages.no_road_found)
        CleanupTaxi()
        DebugPrint('出租车在验证时丢失')
        return
    end
    
    if not current_driver or not DoesEntityExist(current_driver) then
        ShowNotification(Config.Messages.no_road_found)
        CleanupTaxi()
        DebugPrint('司机在验证时丢失')
        return
    end
    
    -- 创建地图标记
    current_blip = CreateTaxiBlip(current_taxi)
    
    -- 验证Blip创建成功
    if not current_blip or not DoesBlipExist(current_blip) then
        DebugPrint('Blip创建失败，重试')
        Citizen.Wait(100)
        current_blip = CreateTaxiBlip(current_taxi)
    end
    
    -- 设置驾驶任务
    SetDriverTask(current_driver, current_taxi, destination_coords)
    
    -- 标记为激活状态
    is_taxi_active = true
    trip_state = 'waiting'  -- 初始状态：等待出租车到达
    taxi_spawn_time = GetGameTimer()  -- 记录生成时间
    
    -- 显示成功通知
    ShowNotification(Config.Messages.taxi_called)
    
    -- 启动到达检测线程
    StartArrivalCheckThread()
    
    -- 启动超时检测线程
    StartIdleTimeoutThread()
    
    DebugPrint('出租车召唤完成，状态: waiting')
end

-- ============================================
-- 超时检测线程
-- ============================================
--[[
    检测出租车是否超时无人上车
    @return void
]]--
StartIdleTimeoutThread = function()
    Citizen.CreateThread(function()
        -- 预缓存配置值
        local timeout_ms = Config.Trip.idle_timeout
        local driving_speed = Config.Driver.driving_speed
        local driving_style = Config.Driver.driving_style
        local leave_delay = Config.Trip.driver_leave_delay
        
        while is_taxi_active and (trip_state == 'waiting' or trip_state == 'boarding') do
            -- 检查是否超时
            if GetGameTimer() - taxi_spawn_time > timeout_ms then
                DebugPrint('出租车等待超时')
                ShowNotification(Config.Messages.taxi_timeout)
                
                -- 捕获当前引用
                local ref_driver = current_driver
                local ref_taxi = current_taxi
                
                -- 让司机驶离
                if ref_driver and DoesEntityExist(ref_driver) and 
                   ref_taxi and DoesEntityExist(ref_taxi) then
                    ClearPedTasks(ref_driver)
                    TaskVehicleDriveWander(ref_driver, ref_taxi, driving_speed, driving_style)
                    
                    -- 立即重置状态
                    RemoveTaxiBlip()
                    current_driver = nil
                    current_taxi = nil
                    is_taxi_active = false
                    trip_state = 'none'
                    
                    -- 延迟后标记为不再需要
                    Citizen.SetTimeout(leave_delay, function()
                        if ref_driver and DoesEntityExist(ref_driver) then
                            SetEntityAsMissionEntity(ref_driver, false, true)
                            SetEntityAsNoLongerNeeded(ref_driver)
                        end
                        if ref_taxi and DoesEntityExist(ref_taxi) then
                            SetEntityAsMissionEntity(ref_taxi, false, true)
                            SetEntityAsNoLongerNeeded(ref_taxi)
                        end
                    end)
                else
                    CleanupTaxi()
                end
                break
            end
            
            Citizen.Wait(5000)  -- 每5秒检测一次
        end
    end)
end

-- ============================================
-- 注册命令
-- ============================================
RegisterCommand(Config.Command.name, function(source, args, rawCommand)
    CallTaxi()
end, false)

-- 添加命令提示（F8控制台可见）
TriggerEvent('chat:addSuggestion', '/' .. Config.Command.name, Config.Command.help)

-- ============================================
-- 资源停止时清理（强制删除，确保不留残留）
-- ============================================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- 移除Blip
        if current_blip and DoesBlipExist(current_blip) then
            RemoveBlip(current_blip)
        end
        
        -- 强制删除实体（资源停止时需要立即清理）
        if current_driver and DoesEntityExist(current_driver) then
            DeleteEntity(current_driver)
        end
        if current_taxi and DoesEntityExist(current_taxi) then
            DeleteEntity(current_taxi)
        end
        
        -- 重置所有状态
        current_taxi = nil
        current_driver = nil
        current_blip = nil
        is_taxi_active = false
        destination_coords = nil
        trip_state = 'none'
        waypoint_coords = nil
        is_player_in_taxi = false
        is_driver_rushed = false
        show_fare_ui = false
        current_fare = 0
        trip_start_coords = nil
        taxi_spawn_time = 0
        
        DebugPrint('资源停止，清理完成')
    end
end)

-- ============================================
-- 车费UI显示线程（性能优化版）
-- ============================================
Citizen.CreateThread(function()
    -- 预缓存字符串格式
    local fare_format = '车费: %s%d'
    local currency = Config.Fare.currency_symbol
    
    while true do
        -- 空闲时长休眠，降低 resmon 占用
        if not is_taxi_active then
            Citizen.Wait(1000)  -- 空闲时每秒检测一次
        elseif show_fare_ui and trip_state == 'driving' then
            -- 绘制黑色背景框
            DrawRect(0.92, 0.90, 0.15, 0.05, 0, 0, 0, 180)
            
            -- 显示车费文字
            SetTextFont(0)
            SetTextScale(0.4, 0.4)
            SetTextColour(255, 255, 0, 255)
            SetTextOutline()
            SetTextEntry('STRING')
            AddTextComponentString(string.format(fare_format, currency, current_fare))
            DrawText(0.865, 0.885)
            
            Citizen.Wait(0)
        else
            Citizen.Wait(500)  -- 非驾驶状态时降低检测频率
        end
    end
end)

-- ============================================
-- 初始化日志
-- ============================================
Citizen.CreateThread(function()
    DebugPrint('AI出租车系统已加载')
    DebugPrint('使用 /' .. Config.Command.name .. ' 召唤出租车')
end)

