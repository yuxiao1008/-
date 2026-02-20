-- 佩里科岛系统 - 武器箱客户端逻辑
-- 作者: 于晓

-- ==================== 本地变量 ====================
-- 本地武器箱实体表
local ClientWeaponBoxes = {}  -- {box_id = {entity, netId, coords}}

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.WeaponBoxes and Config.WeaponBoxes.debug then
        print("[yx_Island WEAPONBOX CLIENT] " .. msg)
    end
end

-- ==================== ox_target 交互 ====================

-- 添加武器箱交互点
local function AddWeaponBoxTarget(entity, box_id)
    exports.ox_target:addLocalEntity(entity, {
        {
            name = 'open_weapon_box_' .. box_id,
            label = Config.WeaponBoxes.interaction.label,
            icon = Config.WeaponBoxes.interaction.icon,
            distance = Config.WeaponBoxes.interaction.distance,
            onSelect = function()
                debug_print(string.format("玩家交互武器箱: %s", box_id))
                TriggerServerEvent('yx_island:server:open_weapon_box', box_id)
            end
        }
    })
    debug_print(string.format("已添加 ox_target 交互: %s", box_id))
end

-- ==================== 网络事件 ====================

-- 生成武器箱实体
RegisterNetEvent('yx_island:client:spawn_weapon_box', function(box_id, coords, heading)
    debug_print(string.format("收到生成武器箱请求: %s at %s", box_id, coords))

    -- 检查是否已经创建过这个箱子
    if ClientWeaponBoxes[box_id] then
        debug_print(string.format("武器箱 %s 已存在，跳过创建", box_id))
        return
    end

    -- 加载模型
    local model = GetHashKey(Config.WeaponBoxes.prop_model)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) and timeout < 100 do
        Wait(50)
        timeout = timeout + 1
    end

    if not HasModelLoaded(model) then
        debug_print(string.format("模型加载超时: %s", Config.WeaponBoxes.prop_model))
        return
    end

    debug_print(string.format("模型已加载: %s", Config.WeaponBoxes.prop_model))

    -- 创建实体
    local entity = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)

    if not DoesEntityExist(entity) then
        debug_print(string.format("实体创建失败: %s", box_id))
        SetModelAsNoLongerNeeded(model)
        return
    end

    -- 设置实体属性
    SetEntityHeading(entity, heading)
    PlaceObjectOnGroundProperly(entity)
    FreezeEntityPosition(entity, true)
    SetEntityAsMissionEntity(entity, true, true)
    SetEntityCanBeDamaged(entity, false)

    debug_print(string.format("实体已创建并配置: %s (Entity ID: %s)", box_id, entity))

    -- 获取网络 ID
    local netId = NetworkGetNetworkIdFromEntity(entity)

    -- 存储数据
    ClientWeaponBoxes[box_id] = {
        entity = entity,
        netId = netId,
        coords = coords,
    }

    -- 添加 ox_target 交互（稍微延迟确保实体完全加载）
    Wait(100)
    AddWeaponBoxTarget(entity, box_id)

    -- 释放模型
    SetModelAsNoLongerNeeded(model)

    debug_print(string.format("武器箱 %s 生成完成", box_id))
end)

-- 移除武器箱实体
RegisterNetEvent('yx_island:client:remove_weapon_box', function(box_id)
    debug_print(string.format("收到移除武器箱请求: %s", box_id))

    local box_data = ClientWeaponBoxes[box_id]

    if not box_data then
        debug_print(string.format("武器箱 %s 不存在于本地表中", box_id))
        return
    end

    -- 移除 ox_target 交互
    if DoesEntityExist(box_data.entity) then
        exports.ox_target:removeLocalEntity(box_data.entity, 'open_weapon_box_' .. box_id)
        debug_print(string.format("已移除 ox_target 交互: %s", box_id))

        -- 删除实体
        DeleteEntity(box_data.entity)
        debug_print(string.format("已删除实体: %s (Entity ID: %s)", box_id, box_data.entity))
    else
        debug_print(string.format("实体不存在，跳过删除: %s", box_id))
    end

    -- 清除本地数据
    ClientWeaponBoxes[box_id] = nil
    debug_print(string.format("武器箱 %s 移除完成", box_id))
end)

-- 开始搜索进度条
RegisterNetEvent('yx_island:client:start_weapon_box_progress', function(box_id)
    debug_print(string.format("开始搜索进度条: %s", box_id))

    -- 使用 ox_lib 进度条
    local success = lib.progressBar({
        duration = Config.WeaponBoxes.progress.duration,
        label = Config.WeaponBoxes.progress.label,
        useWhileDead = Config.WeaponBoxes.progress.useWhileDead,
        canCancel = Config.WeaponBoxes.progress.canCancel,
        disable = Config.WeaponBoxes.progress.disable,
        anim = {
            dict = Config.WeaponBoxes.progress.animation.dict,
            clip = Config.WeaponBoxes.progress.animation.clip,
            flag = Config.WeaponBoxes.progress.animation.flag,
        },
    })

    if success then
        debug_print(string.format("搜索完成: %s", box_id))
        -- 进度条完成，通知服务器
        TriggerServerEvent('yx_island:server:complete_weapon_box_search', box_id)
    else
        debug_print(string.format("搜索取消: %s", box_id))
        -- 进度条取消，通知服务器释放锁
        TriggerServerEvent('yx_island:server:cancel_weapon_box_search', box_id)
    end
end)

-- ==================== 系统重置 ====================

-- 当系统重置时清理所有武器箱
RegisterNetEvent('yx_island:client:reset_all_states', function()
    debug_print("系统重置，清理所有武器箱")

    local count = 0
    for box_id, box_data in pairs(ClientWeaponBoxes) do
        if DoesEntityExist(box_data.entity) then
            -- 移除 ox_target
            exports.ox_target:removeLocalEntity(box_data.entity, 'open_weapon_box_' .. box_id)

            -- 删除实体
            DeleteEntity(box_data.entity)

            count = count + 1
            debug_print(string.format("清理武器箱: %s", box_id))
        end
    end

    -- 清空本地表
    ClientWeaponBoxes = {}

    if count > 0 then
        debug_print(string.format("已清理 %d 个武器箱实体", count))
    end
end)

-- ==================== 动画预加载 ====================

-- 预加载搜索动画字典
CreateThread(function()
    if Config.WeaponBoxes and Config.WeaponBoxes.enabled then
        local dict = Config.WeaponBoxes.progress.animation.dict

        RequestAnimDict(dict)

        local timeout = 0
        while not HasAnimDictLoaded(dict) and timeout < 100 do
            Wait(100)
            timeout = timeout + 1
        end

        if HasAnimDictLoaded(dict) then
            debug_print(string.format("动画字典已加载: %s", dict))
        else
            print(string.format("^1[yx_Island WEAPONBOX]^0 警告: 动画字典加载失败: %s", dict))
        end
    end
end)

print("^2[yx_Island]^0 武器箱客户端模块已加载")
