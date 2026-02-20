-- 佩里科岛系统 - 死亡背包客户端逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 本地变量 ====================
-- 本地背包实体表 {bag_id = entity_handle}
local LocalDeathBags = {}

-- 模型哈希
local BagModel = GetHashKey(Config.DeathBag.bag_model)

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island DEATH] " .. msg)
    end
end

-- ==================== 死亡检测 ====================

-- 记录是否已处理死亡（防止重复触发）
local deathHandled = false

-- 监听游戏伤害事件检测死亡
AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= "CEventNetworkEntityDamage" then return end

    local victim, attacker, victimDied, weaponHash = data[1], data[2], data[4], data[5]
    local playerPed = PlayerPedId()

    -- 检查是否是本地玩家死亡
    if victim ~= playerPed then return end

    -- 检测玩家是否死亡
    local victimDiedAndPlayer = victimDied and (IsPedDeadOrDying(victim, true) or IsPedFatallyInjured(victim))

    if victimDiedAndPlayer and not deathHandled then
        deathHandled = true

        local coords = GetEntityCoords(playerPed)

        print("^3[yx_Island DEATH]^0 检测到玩家死亡 (gameEventTriggered)")
        print(string.format("^3[yx_Island DEATH]^0 死亡坐标: %.2f, %.2f, %.2f", coords.x, coords.y, coords.z))

        -- 通知服务端
        TriggerServerEvent('yx_island:server:player_died', coords)
        print("^3[yx_Island DEATH]^0 已通知服务端玩家死亡")

        -- 延迟重置标记，防止在复活后无法再次检测
        SetTimeout(10000, function()
            deathHandled = false
            debug_print("死亡处理标记已重置")
        end)
    end
end)

-- ==================== 背包实体管理 ====================

-- 生成背包实体
RegisterNetEvent('yx_island:client:spawn_death_bag', function(bagId, coords, netId)
    print(string.format("^3[yx_Island DEATH]^0 收到生成背包请求: %s (NetID: %s)", bagId, netId or "无"))

    -- 检查是否已经创建过这个背包
    if LocalDeathBags[bagId] then
        print(string.format("^1[yx_Island DEATH]^0 背包 %s 已存在，跳过创建", bagId))
        return
    end

    local bagEntity

    if netId then
        -- 如果有网络ID，等待实体出现
        print(string.format("^3[yx_Island DEATH]^0 等待网络实体出现: NetID %s", netId))

        local timeout = 0
        while not NetworkDoesEntityExistWithNetworkId(netId) and timeout < 100 do
            Wait(50)
            timeout = timeout + 1
        end

        if NetworkDoesEntityExistWithNetworkId(netId) then
            bagEntity = NetworkGetEntityFromNetworkId(netId)
            print(string.format("^2[yx_Island DEATH]^0 获取到网络实体: %s", bagEntity))

            -- 等待实体完全同步
            Wait(100)

            -- 在客户端设置实体属性
            if DoesEntityExist(bagEntity) then
                -- 贴地
                PlaceObjectOnGroundProperly(bagEntity)

                -- 冻结位置
                FreezeEntityPosition(bagEntity, true)

                -- 设置为任务实体（防止被清理）
                SetEntityAsMissionEntity(bagEntity, true, true)

                -- 设置不会被武器摧毁
                SetEntityCanBeDamaged(bagEntity, false)

                print(string.format("^2[yx_Island DEATH]^0 已配置背包实体属性"))
            end
        else
            print(string.format("^1[yx_Island DEATH]^0 网络实体未出现，超时"))
            return
        end
    else
        -- 没有网络ID则本地创建（不应该发生）
        print(string.format("^1[yx_Island DEATH]^0 警告: 未收到网络ID，使用本地创建"))
        return
    end

    -- 记录实体
    LocalDeathBags[bagId] = bagEntity

    -- 添加 ox_target
    Wait(500) -- 等待实体完全加载
    exports.ox_target:addLocalEntity(bagEntity, {
        {
            name = "open_death_bag_" .. bagId,
            label = Config.DeathBag.target.label,
            icon = Config.DeathBag.target.icon,
            distance = Config.DeathBag.target.distance,
            canInteract = function()
                -- 检查是否正在执行进度条（自定义进度条系统使用全局变量 isDoingAction）
                if isDoingAction ~= nil then
                    return not isDoingAction
                end
                return true
            end,
            onSelect = function()
                print(string.format("^3[yx_Island DEATH]^0 玩家交互背包: %s", bagId))
                StartSearchingBag(bagId)
            end
        }
    })

    print(string.format("^2[yx_Island DEATH]^0 已配置背包实体 %s (Entity: %s)", bagId, bagEntity))
end)

-- 开始搜索背包（带进度条）
function StartSearchingBag(bagId)
    local progressConfig = Config.DeathBag.search_progress

    print(string.format("^3[yx_Island DEATH]^0 开始搜索背包: %s", bagId))
    print(string.format("^3[yx_Island DEATH]^0 动画字典: %s, 动画: %s", progressConfig.animation.dict, progressConfig.animation.clip))

    -- 使用自定义进度条系统
    TriggerEvent("progressbar:client:progress", {
        name = "search_death_bag",
        duration = progressConfig.duration,
        label = progressConfig.label,
        useWhileDead = progressConfig.use_while_dead,
        canCancel = progressConfig.can_cancel,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = progressConfig.animation.dict,
            anim = progressConfig.animation.clip,
            flags = 1,  -- 使用标志 1（与你们服务器的动作配置一致）
        },
    }, function(cancelled)
        -- 无论完成还是取消，都清理动作
        local ped = PlayerPedId()
        ClearPedTasks(ped)
        ClearPedSecondaryTask(ped)
        StopAnimTask(ped, progressConfig.animation.dict, progressConfig.animation.clip, 1.0)

        if not cancelled then
            -- 进度条完成，通知服务端打开背包
            print(string.format("^2[yx_Island DEATH]^0 搜索完成，打开背包: %s", bagId))
            TriggerServerEvent('yx_island:server:open_death_bag', bagId)
        else
            -- 进度条被取消
            print(string.format("^1[yx_Island DEATH]^0 搜索被取消: %s", bagId))
            QBCore.Functions.Notify(Config.DeathBag.notifications.search_cancelled, 'error')
        end
    end)
end

-- 显示背包菜单
RegisterNetEvent('yx_island:client:show_bag_menu', function(bagId, items, ownerName)
    if not items or #items == 0 then
        return
    end

    print(string.format("^3[yx_Island DEATH]^0 显示背包菜单: %s (%d 件物品)", bagId, #items))

    -- 构建菜单选项
    local options = {}

    -- 添加"拾取全部"选项
    table.insert(options, {
        title = '🎒 拾取全部物品',
        description = string.format('将所有物品 (%d件) 拾取到背包', #items),
        icon = 'hands',
        onSelect = function()
            TriggerServerEvent('yx_island:server:take_all_items', bagId)
        end
    })

    -- 添加分隔线
    table.insert(options, {
        title = '━━━━━━━━━━━━━━━',
        disabled = true
    })

    -- 添加每个物品
    for index, item in ipairs(items) do
        -- 获取物品显示名称
        local itemLabel = item.name
        local itemDesc = '点击拾取该物品'
        
        -- 尝试获取物品信息
        if QBCore.Shared.Items and QBCore.Shared.Items[item.name] then
            itemLabel = QBCore.Shared.Items[item.name].label or item.name
            itemDesc = QBCore.Shared.Items[item.name].description or itemDesc
        end

        table.insert(options, {
            title = string.format('%s x%d', itemLabel, item.amount),
            description = itemDesc,
            icon = 'box',
            image = 'nui://qs-inventory/html/images/' .. item.name .. '.png',
            onSelect = function()
                TriggerServerEvent('yx_island:server:take_bag_item', bagId, index)
            end
        })
    end

    -- 显示菜单
    lib.registerContext({
        id = 'death_bag_menu_' .. bagId,
        title = string.format('💀 %s 的背包', ownerName),
        options = options
    })

    lib.showContext('death_bag_menu_' .. bagId)
end)

-- 刷新背包菜单
RegisterNetEvent('yx_island:client:refresh_bag_menu', function(bagId, items, ownerName)
    -- 重新显示菜单
    TriggerEvent('yx_island:client:show_bag_menu', bagId, items, ownerName)
end)

-- 移除背包实体
RegisterNetEvent('yx_island:client:remove_death_bag', function(bagId)
    local entity = LocalDeathBags[bagId]
    if not entity then return end

    -- 1. 移除 ox_target
    exports.ox_target:removeLocalEntity(entity, "open_death_bag_" .. bagId)

    -- 2. 删除实体
    if DoesEntityExist(entity) then
        DeleteEntity(entity)
    end

    -- 3. 清除记录
    LocalDeathBags[bagId] = nil

    debug_print(string.format("已移除背包实体 %s", bagId))
end)

-- 重置所有状态
RegisterNetEvent('yx_island:client:reset_all_states', function()
    -- 清理所有本地背包实体
    for bagId, entity in pairs(LocalDeathBags) do
        exports.ox_target:removeLocalEntity(entity, "open_death_bag_" .. bagId)

        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    LocalDeathBags = {}
    debug_print("已清理所有死亡背包实体")
end)

-- ==================== 复活玩家 ====================

-- 复活死亡的玩家
RegisterNetEvent('yx_island:client:revive_player', function()
    print("^2[yx_Island DEATH]^0 正在复活玩家...")

    -- 重置死亡处理标记
    deathHandled = false
    debug_print("死亡处理标记已重置（复活时）")

    -- 调用医护脚本的全局复活函数
    if _G.stopPlayerDeath then
        _G.stopPlayerDeath()
        print("^2[yx_Island DEATH]^0 已调用 stopPlayerDeath() 复活玩家")
    else
        -- 备用复活方案（如果医护脚本未加载）
        local playerPed = PlayerPedId()

        -- 清除死亡状态
        SetEntityHealth(playerPed, 200)
        ClearPedTasksImmediately(playerPed)

        -- 恢复玩家控制
        SetEntityInvincible(playerPed, false)
        FreezeEntityPosition(playerPed, false)

        print("^3[yx_Island DEATH]^0 使用备用方案复活玩家")
    end

    QBCore.Functions.Notify("你已被救护队复活", 'success')
end)

-- ==================== 资源停止 ====================
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    -- 清理所有背包实体
    for bagId, entity in pairs(LocalDeathBags) do
        exports.ox_target:removeLocalEntity(entity, "open_death_bag_" .. bagId)

        if DoesEntityExist(entity) then
            DeleteEntity(entity)
        end
    end

    debug_print("资源停止，已清理所有背包实体")
end)
