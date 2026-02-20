-- 佩里科岛系统 - 跳伞空投
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
local isAirdropping = false

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island AIRDROP] " .. msg)
    end
end

-- ==================== 工具函数 ====================

-- 生成随机空投坐标
local function generate_airdrop_coords()
    local baseCoords = Config.Airdrop.spawn_center
    local spread = Config.Airdrop.random_spread

    -- 在范围内随机偏移
    local offsetX = math.random(-spread, spread)
    local offsetY = math.random(-spread, spread)

    return vector3(
        baseCoords.x + offsetX,
        baseCoords.y + offsetY,
        Config.Airdrop.spawn_height
    )
end

-- ==================== 空投执行 ====================

-- 执行空投
RegisterNetEvent('yx_island:client:start_airdrop', function()
    if isAirdropping then
        debug_print("空投已在进行中, 跳过")
        return
    end

    isAirdropping = true
    debug_print("开始执行空投...")

    local playerPed = PlayerPedId()

    -- 淡出屏幕
    DoScreenFadeOut(500)
    Wait(500)

    -- 生成空投坐标
    local airdropCoords = generate_airdrop_coords()
    debug_print(string.format("空投坐标: %.2f, %.2f, %.2f", airdropCoords.x, airdropCoords.y, airdropCoords.z))

    -- 传送到空中
    SetEntityCoords(playerPed, airdropCoords.x, airdropCoords.y, airdropCoords.z, false, false, false, true)

    -- 设置玩家为自由落体状态
    SetEntityVelocity(playerPed, 0.0, 0.0, -1.0)

    -- 等待加载
    Wait(1000)

    -- 淡入屏幕
    DoScreenFadeIn(1000)

    -- 赋予降落伞
    GiveWeaponToPed(playerPed, GetHashKey("GADGET_PARACHUTE"), 1, false, true)
    SetPedParachuteTintIndex(playerPed, -1)

    debug_print("已赋予降落伞")

    -- 延迟后自动开伞
    SetTimeout(Config.Airdrop.parachute_delay, function()
        if not HasPedGotWeapon(playerPed, GetHashKey("GADGET_PARACHUTE"), false) then
            debug_print("玩家未持有降落伞, 重新赋予")
            GiveWeaponToPed(playerPed, GetHashKey("GADGET_PARACHUTE"), 1, false, true)
        end

        -- 强制开伞
        ForcePedToOpenParachute(playerPed)
        debug_print("已自动开伞")
    end)

    -- 禁用降落伤害 (可选)
    if Config.Airdrop.disable_fall_damage then
        CreateThread(function()
            while isAirdropping do
                local currentPed = PlayerPedId()
                SetPedCanRagdoll(currentPed, false)
                SetPedCanRagdollFromPlayerImpact(currentPed, false)

                -- 检查是否落地（距离地面小于2米且速度慢，或在水中游泳）
                local heightAboveGround = GetEntityHeightAboveGround(currentPed)
                local isSwimming = IsPedSwimming(currentPed)
                local isUnderwater = IsPedSwimmingUnderWater(currentPed)

                if (heightAboveGround < 2.0 and GetEntitySpeed(currentPed) < 1.0) or isSwimming or isUnderwater then
                    debug_print("玩家已落地")
                    isAirdropping = false

                    -- 恢复碰撞
                    SetPedCanRagdoll(currentPed, true)
                    SetPedCanRagdollFromPlayerImpact(currentPed, true)

                    -- 移除降落伞
                    RemoveWeaponFromPed(currentPed, GetHashKey("GADGET_PARACHUTE"))

                    -- 通知玩家
                    QBCore.Functions.Notify("成功降落佩里科岛!", 'success')
                end

                Wait(100)
            end
        end)
    end

    debug_print("空投完成")
end)

-- ==================== 资源停止 ====================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 如果正在空投, 恢复玩家状态
    if isAirdropping then
        local playerPed = PlayerPedId()
        SetPedCanRagdoll(playerPed, true)
        SetPedCanRagdollFromPlayerImpact(playerPed, true)
    end
end)
