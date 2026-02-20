-- 佩里科岛系统 - 报名交互 (ox_target + NPC)
-- 作者: 于晓

print("^3[yx_Island REG]^0 registration.lua 开始加载...")

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
local isRegistered = false
local systemEnabled = false
local registrationNPC = nil

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island REG] " .. msg)
    end
end

print("^3[yx_Island REG]^0 调试函数已定义")

-- ==================== NPC 生成 ====================
local function SpawnRegistrationNPC()
    debug_print(">>> 开始生成 NPC...")

    -- 删除旧的 NPC
    if registrationNPC then
        debug_print("删除旧的 NPC")
        DeleteEntity(registrationNPC)
        registrationNPC = nil
    end

    local npcModel = GetHashKey(Config.Registration.npc.model)
    local coords = Config.Registration.location

    debug_print(string.format("NPC 模型: %s (Hash: %s)", Config.Registration.npc.model, npcModel))
    debug_print(string.format("NPC 坐标: %.2f, %.2f, %.2f, %.2f", coords.x, coords.y, coords.z, coords.w))

    -- 请求模型
    debug_print("请求模型...")
    RequestModel(npcModel)
    local timeout = 0
    while not HasModelLoaded(npcModel) and timeout < 100 do
        Wait(100)
        timeout = timeout + 1
    end

    if not HasModelLoaded(npcModel) then
        print("^1[yx_Island REG ERROR]^0 模型加载失败: " .. Config.Registration.npc.model)
        return
    end

    debug_print("模型加载成功")

    -- 创建 NPC
    debug_print("创建 NPC 实体...")
    registrationNPC = CreatePed(4, npcModel, coords.x, coords.y, coords.z - 1.0, coords.w, false, true)

    if not DoesEntityExist(registrationNPC) then
        print("^1[yx_Island REG ERROR]^0 NPC 创建失败!")
        return
    end

    debug_print("NPC 实体创建成功, ID: " .. registrationNPC)

    -- NPC 设置
    debug_print("设置 NPC 属性...")
    SetEntityAsMissionEntity(registrationNPC, true, true)
    SetPedFleeAttributes(registrationNPC, 0, 0)
    SetPedDiesWhenInjured(registrationNPC, false)
    SetPedKeepTask(registrationNPC, true)
    SetBlockingOfNonTemporaryEvents(registrationNPC, true)
    FreezeEntityPosition(registrationNPC, true)
    SetEntityInvincible(registrationNPC, true)

    -- 设置 NPC 动作
    debug_print("设置 NPC 动作: " .. Config.Registration.npc.scenario)
    TaskStartScenarioInPlace(registrationNPC, Config.Registration.npc.scenario, 0, true)

    debug_print("^2报名 NPC 已生成: " .. Config.Registration.npc.model .. "^0")

    -- 添加 ox_target
    debug_print("添加 ox_target 交互...")
    local success, errorMsg = pcall(function()
        exports.ox_target:addLocalEntity(registrationNPC, {
            {
                name = 'island_registration',
                label = Config.Registration.target.label,
                icon = Config.Registration.target.icon,
                distance = Config.Registration.target.distance,
                onSelect = function()
                    debug_print("玩家点击了 NPC")
                    if not isRegistered then
                        -- 报名
                        TriggerServerEvent('yx_island:server:register')
                        isRegistered = true
                        debug_print("玩家已报名")
                    else
                        -- 取消报名
                        TriggerServerEvent('yx_island:server:cancel_register')
                        isRegistered = false
                        debug_print("玩家取消报名")
                    end
                end,
                canInteract = function()
                    return systemEnabled
                end
            }
        })
    end)

    if success then
        debug_print("^2ox_target 交互已添加^0")
    else
        print("^1[yx_Island REG ERROR]^0 ox_target 添加失败: " .. tostring(errorMsg))
    end
end

print("^3[yx_Island REG]^0 NPC 生成函数已定义")

-- ==================== 删除 NPC ====================
local function DeleteRegistrationNPC()
    if registrationNPC then
        debug_print("删除 NPC...")
        pcall(function()
            exports.ox_target:removeLocalEntity(registrationNPC, 'island_registration')
        end)
        DeleteEntity(registrationNPC)
        registrationNPC = nil
        debug_print("报名 NPC 已删除")
    end
end

print("^3[yx_Island REG]^0 NPC 删除函数已定义")

-- ==================== 事件处理 ====================

-- 活动启动时重置报名状态
RegisterNetEvent('yx_island:client:reset_registration', function()
    isRegistered = false
    debug_print("报名状态已重置")
end)

debug_print("注册事件: yx_island:client:reset_registration")

-- 统一重置事件（系统关闭时调用）
RegisterNetEvent('yx_island:client:reset_all_states', function()
    isRegistered = false
    debug_print("报名状态已重置（统一重置）")
end)

-- 系统开关状态同步
RegisterNetEvent('yx_island:client:toggle_system', function(enabled)
    systemEnabled = enabled
    debug_print("^3系统状态更新: " .. (enabled and "开启" or "关闭") .. "^0")

    if enabled then
        -- 系统开启, 生成 NPC
        debug_print("系统开启, 准备生成 NPC...")
        SpawnRegistrationNPC()
    else
        -- 系统关闭, 删除 NPC
        debug_print("系统关闭, 删除 NPC...")
        DeleteRegistrationNPC()
        isRegistered = false
    end
end)

debug_print("注册事件: yx_island:client:toggle_system")

-- ==================== 资源启动/停止 ====================
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    debug_print("^2========================================^0")
    debug_print("^2报名系统已加载^0")

    -- 初始化系统状态
    systemEnabled = Config.DefaultEnabled
    debug_print("^3系统状态: " .. (systemEnabled and "开启" or "关闭") .. "^0")

    -- 如果默认开启, 生成 NPC
    if systemEnabled then
        debug_print("默认开启, 准备生成 NPC...")
        SpawnRegistrationNPC()
    else
        debug_print("默认关闭, 不生成 NPC")
    end

    debug_print("^2========================================^0")
end)

debug_print("注册事件: onResourceStart")

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    debug_print("资源停止, 清理 NPC...")
    -- 清理 NPC
    DeleteRegistrationNPC()
end)

debug_print("注册事件: onResourceStop")

print("^2[yx_Island REG]^0 registration.lua 加载完成!")
