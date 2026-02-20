--[[
    客户端脚本: client/main.lua
    功能说明:
      1. 检测玩家是否为管理员且驾驶 buzzard2 直升机
      2. 在直升机中显示左上角原生按键提示，按R键投掷红包
      3. 生成带物理重力和红色烟雾的钱袋物体
      4. 钱袋落地后切换特效、添加小地图标记
      5. 所有玩家可通过碰撞/靠近领取钱袋
    作者: 于晓
]]

-- ============================================
-- 本地变量（避免全局污染）
-- ============================================
local is_cooldown = false               -- 投掷冷却状态
local is_admin = false                  -- 管理员状态（由服务端同步）
local spawned_bags = {}                 -- 钱袋追踪表（哈希表）{ [net_id] = bag_data }
local allowed_vehicle_hash = nil        -- 缓存允许的载具模型哈希值

-- ============================================
-- 初始化：注册帮助文本条目 + 缓存模型哈希
-- ============================================
Citizen.CreateThread(function()
    -- 注册原生帮助文本条目
    AddTextEntry(Config.HelpTextEntry, Config.HelpText)

    -- 缓存允许的载具哈希（避免每帧计算）
    allowed_vehicle_hash = GetHashKey(Config.AllowedVehicle)

    DebugPrint('客户端初始化完成，允许载具: ' .. Config.AllowedVehicle)

    -- 请求服务端同步管理员状态
    TriggerServerEvent('redpacket:checkAdmin')
end)

-- ============================================
-- 服务端回调：同步管理员状态
-- ============================================
RegisterNetEvent('redpacket:setAdmin')
AddEventHandler('redpacket:setAdmin', function(status)
    is_admin = (status == true)
    DebugPrint('管理员状态更新: ' .. tostring(is_admin))
end)

-- ============================================
-- 辅助函数
-- ============================================

--- 每帧调用，在左上角显示原生按键提示
local function show_help_text()
    BeginTextCommandDisplayHelp(Config.HelpTextEntry)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

--- 检查当前载具是否为允许的直升机
--- @param vehicle number 载具实体ID
--- @return boolean
local function is_allowed_helicopter(vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return GetEntityModel(vehicle) == allowed_vehicle_hash
end

--- 判断当前玩家是否有权限使用红包功能
--- @return boolean
local function has_permission()
    if not Config.RequireAdmin then
        return true
    end
    return is_admin
end

--- 请求并等待模型加载完成
--- @param model_hash number 模型哈希值
--- @return boolean 是否加载成功
local function load_model(model_hash)
    RequestModel(model_hash)
    local timeout = 50
    while not HasModelLoaded(model_hash) and timeout > 0 do
        Citizen.Wait(20)
        timeout = timeout - 1
    end
    if not HasModelLoaded(model_hash) then
        DebugPrint('模型加载失败: ' .. tostring(model_hash))
        return false
    end
    return true
end

--- 请求并等待粒子特效字典加载完成
--- @param ptfx_dict string 粒子特效字典名
--- @return boolean 是否加载成功
local function load_ptfx(ptfx_dict)
    RequestNamedPtfxAsset(ptfx_dict)
    local timeout = 50
    while not HasNamedPtfxAssetLoaded(ptfx_dict) and timeout > 0 do
        Citizen.Wait(20)
        timeout = timeout - 1
    end
    if not HasNamedPtfxAssetLoaded(ptfx_dict) then
        DebugPrint('粒子特效字典加载失败: ' .. ptfx_dict)
        return false
    end
    return true
end

--- 为落地的钱袋创建小地图标记
--- @param coords vector3 钱袋坐标
--- @return number|nil 标记句柄
local function create_bag_blip(coords)
    if not Config.BlipEnabled then return nil end

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.BlipSprite)
    SetBlipColour(blip, Config.BlipColor)
    SetBlipScale(blip, Config.BlipScale)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.BlipName)
    EndTextCommandSetBlipName(blip)

    DebugPrint('创建小地图标记')
    return blip
end

--- 完整清理一个钱袋的所有关联资源（仅owner客户端调用）
--- @param bag table 钱袋追踪数据
local function cleanup_bag(bag)
    if not bag then return end

    -- 停止空中特效
    if bag.ptfx_handle and bag.ptfx_handle ~= 0 then
        StopParticleFxLooped(bag.ptfx_handle, false)
    end

    -- 停止落地特效
    if bag.land_ptfx and bag.land_ptfx ~= 0 then
        StopParticleFxLooped(bag.land_ptfx, false)
    end

    -- 移除小地图标记
    if bag.blip and DoesBlipExist(bag.blip) then
        RemoveBlip(bag.blip)
    end

    -- 删除物体实体
    if bag.obj and DoesEntityExist(bag.obj) then
        DeleteEntity(bag.obj)
    end

    DebugPrint('钱袋资源已完整清理')
end

-- ============================================
-- 主检测线程：检测 buzzard2 驾驶 + R键按下
-- ============================================
Citizen.CreateThread(function()
    while true do
        local sleep_time = Config.IdleInterval
        local ped = PlayerPedId()

        if has_permission() and IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)

            if GetPedInVehicleSeat(vehicle, -1) == ped and is_allowed_helicopter(vehicle) then
                sleep_time = Config.CheckInterval

                DisableControlAction(0, Config.InputKey, true)
                show_help_text()

                if IsDisabledControlJustPressed(0, Config.InputKey) then
                    if not is_cooldown then
                        is_cooldown = true
                        local heading = GetEntityHeading(vehicle)

                        DebugPrint('检测到R键按下，发送投掷请求，朝向: ' .. heading)
                        TriggerServerEvent('redpacket:requestSpawn', heading)

                        Citizen.SetTimeout(Config.CooldownTime, function()
                            is_cooldown = false
                            DebugPrint('投掷冷却结束')
                        end)
                    else
                        DebugPrint('投掷冷却中，忽略本次按键')
                    end
                end
            end
        end

        Citizen.Wait(sleep_time)
    end
end)

-- ============================================
-- 钱袋落地检测线程（仅对本客户端生成的钱袋）
-- ============================================
Citizen.CreateThread(function()
    while true do
        local has_active_bags = false

        for net_id, bag in pairs(spawned_bags) do
            -- 只有 owner 客户端才负责落地检测和特效切换
            if bag.is_owner and not bag.claimed and not bag.landed then
                if bag.obj and DoesEntityExist(bag.obj) then
                    has_active_bags = true
                    local velocity = GetEntityVelocity(bag.obj)
                    local speed = #(velocity)

                    if speed < Config.LandVelocityThreshold then
                        bag.landed = true
                        local bag_coords = GetEntityCoords(bag.obj)
                        DebugPrint(string.format('钱袋落地于: %.2f, %.2f, %.2f', bag_coords.x, bag_coords.y, bag_coords.z))

                        -- 停止空中烟雾特效
                        if bag.ptfx_handle and bag.ptfx_handle ~= 0 then
                            StopParticleFxLooped(bag.ptfx_handle, false)
                            bag.ptfx_handle = 0
                            DebugPrint('停止空中烟雾特效')
                        end

                        -- 切换为落地特效
                        if load_ptfx(Config.LandPtfxDict) then
                            UseParticleFxAssetNextCall(Config.LandPtfxDict)
                            local land_ptfx = StartParticleFxLoopedOnEntity(
                                Config.LandPtfxName, bag.obj,
                                0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                Config.LandPtfxScale, false, false, false
                            )
                            if land_ptfx and land_ptfx ~= 0 then
                                SetParticleFxLoopedColour(land_ptfx,
                                    Config.PtfxColor.r, Config.PtfxColor.g, Config.PtfxColor.b, false)
                                bag.land_ptfx = land_ptfx
                                DebugPrint('落地红色烟雾已附加')
                            end
                        end

                        -- 添加小地图标记
                        bag.blip = create_bag_blip(bag_coords)
                    end
                end
            end
        end

        if has_active_bags then
            Citizen.Wait(Config.LandCheckInterval)
        else
            Citizen.Wait(500)
        end
    end
end)

-- ============================================
-- 碰撞领取检测线程（所有玩家均可领取）
-- 性能分级：>100m 低频轮询 | ≤100m 高频精确检测 | 无红包时休眠
-- ============================================
Citizen.CreateThread(function()
    while true do
        local has_nearby = false   -- 是否有红包在激活范围内（≤100m）
        local has_any_bag = false  -- 是否存在任何未领取的红包
        local ped = PlayerPedId()

        -- 排除：驾驶投掷直升机（buzzard2）的玩家不参与碰撞领取
        local skip_claim = false
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped and is_allowed_helicopter(vehicle) then
                skip_claim = true
            end
        end

        if not skip_claim then
            -- 确定检测实体：在载具中用载具坐标，否则用玩家坐标
            local check_entity = ped
            if IsPedInAnyVehicle(ped, false) then
                check_entity = GetVehiclePedIsIn(ped, false)
            end
            local check_coords = GetEntityCoords(check_entity)

            for net_id, bag in pairs(spawned_bags) do
                if not bag.claimed then
                    has_any_bag = true

                    -- 惰性解析：从 net_id 获取本地实体句柄
                    if not bag.obj or not DoesEntityExist(bag.obj) then
                        if NetworkDoesNetworkIdExist(net_id) then
                            bag.obj = NetworkGetEntityFromNetworkId(net_id)
                        end
                    end

                    if bag.obj and DoesEntityExist(bag.obj) and IsEntityVisible(bag.obj) then
                        local bag_coords = GetEntityCoords(bag.obj)
                        local dist = #(check_coords - bag_coords)

                        -- 第一级：100米激活范围检测
                        if dist < Config.ClaimActiveRange then
                            has_nearby = true

                            -- 第二级：3米精确碰撞检测（仅在激活范围内执行）
                            if dist < Config.ClaimDistance then
                                bag.claimed = true

                                SetEntityVisible(bag.obj, false, false)
                                SetEntityCollision(bag.obj, false, false)

                                DebugPrint('Debug：检测到触碰到了钱袋')

                                TriggerServerEvent('redpacket:claim', net_id)
                            end
                        end
                    end
                end
            end
        end -- end if not skip_claim

        -- 三级休眠策略：
        --   有红包在100m内 → 高频检测（每帧）
        --   有红包但都>100m → 低频轮询（1秒）
        --   无红包 → 休眠（500ms）
        if has_nearby then
            Citizen.Wait(Config.ClaimCheckInterval)
        elseif has_any_bag then
            Citizen.Wait(Config.ClaimFarInterval)
        else
            Citizen.Wait(500)
        end
    end
end)

-- ============================================
-- 服务端回调：生成物体 + 粒子特效 + 注册追踪
-- ============================================
RegisterNetEvent('redpacket:doSpawn')
AddEventHandler('redpacket:doSpawn', function(coords, heading)
    if not coords or not coords.x or not coords.y or not coords.z then
        DebugPrint('收到无效坐标数据，取消生成')
        return
    end

    local spawn_x = coords.x
    local spawn_y = coords.y
    local spawn_z = coords.z + Config.SpawnOffsetZ

    DebugPrint(string.format('生成钱袋于: %.2f, %.2f, %.2f', spawn_x, spawn_y, spawn_z))

    -- 1. 加载模型
    local model_hash = GetHashKey(Config.PropModel)
    if not load_model(model_hash) then return end

    -- 2. 创建网络同步物体
    local obj = CreateObject(model_hash, spawn_x, spawn_y, spawn_z, true, true, false)
    if not DoesEntityExist(obj) then
        DebugPrint('物体创建失败')
        SetModelAsNoLongerNeeded(model_hash)
        return
    end

    -- 3. 设置物理属性
    SetEntityHasGravity(obj, true)
    SetEntityCollision(obj, true, true)
    ActivatePhysics(obj)
    SetEntityHeading(obj, heading or 0.0)

    DebugPrint('钱袋已生成并启用物理属性，实体ID: ' .. tostring(obj))
    SetModelAsNoLongerNeeded(model_hash)

    -- 4. 等待物体注册到网络（获取 net_id）
    local net_id = nil
    local timeout = 50
    while not NetworkGetEntityIsNetworked(obj) and timeout > 0 do
        Citizen.Wait(10)
        timeout = timeout - 1
    end
    if NetworkGetEntityIsNetworked(obj) then
        net_id = NetworkGetNetworkIdFromEntity(obj)
    end

    if not net_id then
        DebugPrint('无法获取物体的网络ID，删除物体')
        DeleteEntity(obj)
        return
    end

    DebugPrint('物体网络ID: ' .. tostring(net_id))

    -- 5. 附加红色烟雾粒子特效
    local ptfx_handle = 0
    if load_ptfx(Config.PtfxDict) then
        UseParticleFxAssetNextCall(Config.PtfxDict)
        ptfx_handle = StartParticleFxLoopedOnEntity(
            Config.PtfxName, obj,
            0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            Config.PtfxScale, false, false, false
        )
        if ptfx_handle and ptfx_handle ~= 0 then
            SetParticleFxLoopedColour(ptfx_handle,
                Config.PtfxColor.r, Config.PtfxColor.g, Config.PtfxColor.b, false)
            DebugPrint('红色烟雾特效已附加，句柄: ' .. tostring(ptfx_handle))
        else
            DebugPrint('粒子特效启动失败')
            ptfx_handle = 0
        end
    end

    -- 6. 注册到本地追踪表（owner 拥有完整数据）
    local bag_data = {
        net_id = net_id,
        obj = obj,
        ptfx_handle = ptfx_handle,
        land_ptfx = nil,
        blip = nil,
        landed = false,
        claimed = false,
        is_owner = true,
        spawn_time = GetGameTimer(),
    }
    spawned_bags[net_id] = bag_data

    -- 7. 通知服务端注册此钱袋，服务端会广播给所有客户端
    TriggerServerEvent('redpacket:bagSpawned', net_id)

    -- 8. 生命周期到期自动清理
    Citizen.SetTimeout(Config.PropLifetime, function()
        if spawned_bags[net_id] and not spawned_bags[net_id].claimed then
            cleanup_bag(spawned_bags[net_id])
            spawned_bags[net_id] = nil
            TriggerServerEvent('redpacket:bagExpired', net_id)
            DebugPrint('钱袋已超时自动清理 net_id: ' .. tostring(net_id))
        end
    end)
end)

-- ============================================
-- 服务端广播：追踪远程钱袋（非生成者客户端）
-- ============================================
RegisterNetEvent('redpacket:trackBag')
AddEventHandler('redpacket:trackBag', function(net_id)
    -- 已在追踪中则跳过（owner 客户端已在 doSpawn 中注册）
    if spawned_bags[net_id] then return end

    spawned_bags[net_id] = {
        net_id = net_id,
        obj = nil,          -- 由碰撞检测线程惰性解析
        claimed = false,
        is_owner = false,   -- 非生成者，无 ptfx/blip 管理权
    }
    DebugPrint('开始追踪远程钱袋 net_id: ' .. tostring(net_id))
end)

-- ============================================
-- 服务端广播：移除钱袋（已被领取或过期）
-- ============================================
RegisterNetEvent('redpacket:removeBag')
AddEventHandler('redpacket:removeBag', function(net_id)
    local bag = spawned_bags[net_id]
    if not bag then return end

    if bag.is_owner then
        -- owner 客户端负责完整清理（特效、标记、实体）
        cleanup_bag(bag)
    else
        -- 非 owner：仅隐藏实体（实体由 owner 删除，OneSync 会同步）
        if bag.obj and DoesEntityExist(bag.obj) then
            SetEntityVisible(bag.obj, false, false)
        end
    end

    spawned_bags[net_id] = nil
    DebugPrint('钱袋已移除 net_id: ' .. tostring(net_id))
end)

-- ============================================
-- 资源停止时清理所有钱袋
-- ============================================
AddEventHandler('onResourceStop', function(resource_name)
    if resource_name ~= GetCurrentResourceName() then return end

    for net_id, bag in pairs(spawned_bags) do
        if bag.is_owner then
            cleanup_bag(bag)
        end
    end
    spawned_bags = {}
    DebugPrint('资源停止，已清理所有钱袋')
end)
