-- 佩里科岛系统 - 武器箱服务端逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 活跃武器箱表
local ActiveWeaponBoxes = {}  -- {box_id = {coords, heading, opened}}

-- 访问锁（防止并发）
local BoxLocks = {}  -- {box_id = player_source}

-- 箱子 ID 计数器
local BoxIdCounter = 0

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.WeaponBoxes and Config.WeaponBoxes.debug then
        print("[yx_Island WEAPONBOX] " .. msg)
    end
end

-- ==================== 核心函数 ====================

-- 生成唯一箱子 ID
local function GenerateBoxId()
    BoxIdCounter = BoxIdCounter + 1
    return 'weaponbox_' .. os.time() .. '_' .. BoxIdCounter
end

-- 计算总权重
local function CalculateTotalWeight()
    local total = 0
    for _, loot in ipairs(Config.WeaponBoxes.loot_table) do
        total = total + loot.weight
    end
    return total
end

-- 加权随机选择物品
local function SelectRandomLoot()
    local total_weight = CalculateTotalWeight()
    local random_value = math.random(1, total_weight)

    local cumulative = 0
    for _, loot in ipairs(Config.WeaponBoxes.loot_table) do
        cumulative = cumulative + loot.weight
        if random_value <= cumulative then
            local amount = math.random(loot.min, loot.max)
            debug_print(string.format("随机选择物品: %s x%d (权重: %d/%d)", loot.item, amount, loot.weight, total_weight))
            return loot.item, amount
        end
    end

    -- 保底返回第一个物品
    local fallback = Config.WeaponBoxes.loot_table[1]
    local amount = math.random(fallback.min, fallback.max)
    debug_print(string.format("保底物品: %s x%d", fallback.item, amount))
    return fallback.item, amount
end

-- 尝试锁定箱子
local function TryLockBox(box_id, source)
    if BoxLocks[box_id] then
        debug_print(string.format("箱子 %s 已被玩家 %s 锁定", box_id, BoxLocks[box_id]))
        return false, '其他玩家正在搜索此箱子'
    end

    BoxLocks[box_id] = source
    debug_print(string.format("箱子 %s 已锁定给玩家 %s", box_id, source))
    return true, nil
end

-- 释放箱子锁
local function UnlockBox(box_id)
    if BoxLocks[box_id] then
        debug_print(string.format("释放箱子 %s 的锁", box_id))
        BoxLocks[box_id] = nil
    end
end

-- 验证锁的所有者
local function ValidateLockOwner(box_id, source)
    return BoxLocks[box_id] == source
end

-- 移除单个武器箱
local function RemoveWeaponBox(box_id)
    if ActiveWeaponBoxes[box_id] then
        debug_print(string.format("移除武器箱: %s", box_id))

        -- 通知所有客户端删除实体
        TriggerClientEvent('yx_island:client:remove_weapon_box', -1, box_id)

        -- 清理服务端数据
        ActiveWeaponBoxes[box_id] = nil
        BoxLocks[box_id] = nil
    end
end

-- 给予物品到玩家背包
local function GiveLootToPlayer(source, item_name, amount)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        debug_print(string.format("玩家 %s 不存在", source))
        return false
    end

    -- 使用 QBCore 添加物品
    local success = Player.Functions.AddItem(item_name, amount)

    if success then
        -- 触发物品提示动画
        TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item_name], 'add', amount)
        debug_print(string.format("玩家 %s 获得: %s x%d", GetPlayerName(source), item_name, amount))
    else
        debug_print(string.format("玩家 %s 背包已满，无法添加: %s x%d", GetPlayerName(source), item_name, amount))
    end

    return success
end

-- ==================== 导出函数 ====================

-- 初始化武器箱系统 (在活动开始时调用)
function InitializeWeaponBoxes()
    if not Config.WeaponBoxes or not Config.WeaponBoxes.enabled then
        debug_print("武器箱系统已禁用")
        return 0
    end

    -- 清理旧数据
    ClearAllWeaponBoxes()

    debug_print("开始初始化武器箱...")

    -- 遍历所有配置的生成点
    for index, spawn in ipairs(Config.WeaponBoxes.spawn_points) do
        local box_id = GenerateBoxId()

        -- 获取坐标和朝向（兼容有无 heading 的配置）
        local coords = spawn.coords
        local heading = spawn.heading or 0.0

        -- 存储箱子数据
        ActiveWeaponBoxes[box_id] = {
            coords = coords,
            heading = heading,
            opened = false,
        }

        -- 通知所有客户端生成实体
        TriggerClientEvent('yx_island:client:spawn_weapon_box', -1, box_id, coords, heading)

        debug_print(string.format("生成武器箱 [%d/%d]: %s at %s", index, #Config.WeaponBoxes.spawn_points, box_id, spawn.coords))
    end

    local spawnCount = #Config.WeaponBoxes.spawn_points
    print(string.format("^2[yx_Island]^0 武器箱系统已初始化，共生成 %d 个武器箱", spawnCount))
    return spawnCount
end

-- 清理所有武器箱 (在活动结束时调用)
function ClearAllWeaponBoxes()
    local count = 0
    for box_id, _ in pairs(ActiveWeaponBoxes) do
        RemoveWeaponBox(box_id)
        count = count + 1
    end

    ActiveWeaponBoxes = {}
    BoxLocks = {}
    BoxIdCounter = 0

    if count > 0 then
        debug_print(string.format("已清理 %d 个武器箱", count))
        print(string.format("^2[yx_Island]^0 已清理所有武器箱 (共 %d 个)", count))
    end
end

-- 导出函数供外部调用
exports('InitializeWeaponBoxes', InitializeWeaponBoxes)
exports('ClearAllWeaponBoxes', ClearAllWeaponBoxes)

-- ==================== 事件处理 ====================

-- 玩家请求打开武器箱
RegisterNetEvent('yx_island:server:open_weapon_box', function(box_id)
    local source = source
    local playerName = GetPlayerName(source)

    debug_print(string.format("玩家 %s (ID: %s) 请求打开武器箱: %s", playerName, source, box_id))

    -- 验证箱子存在
    local box_data = ActiveWeaponBoxes[box_id]
    if not box_data then
        debug_print(string.format("武器箱 %s 不存在", box_id))
        TriggerClientEvent('QBCore:Notify', source, '武器箱不存在', 'error')
        return
    end

    -- 验证箱子未被打开
    if box_data.opened then
        debug_print(string.format("武器箱 %s 已被搜索", box_id))
        TriggerClientEvent('QBCore:Notify', source, '武器箱已被搜索', 'error')
        return
    end

    -- 尝试锁定箱子
    local locked, error_msg = TryLockBox(box_id, source)
    if not locked then
        TriggerClientEvent('QBCore:Notify', source, error_msg, 'error')
        return
    end

    debug_print(string.format("触发玩家 %s 的搜索进度条", source))

    -- 触发客户端进度条
    TriggerClientEvent('yx_island:client:start_weapon_box_progress', source, box_id)
end)

-- 玩家完成搜索进度条
RegisterNetEvent('yx_island:server:complete_weapon_box_search', function(box_id)
    local source = source
    local playerName = GetPlayerName(source)

    debug_print(string.format("玩家 %s (ID: %s) 完成搜索: %s", playerName, source, box_id))

    -- 验证锁的所有者
    if not ValidateLockOwner(box_id, source) then
        debug_print(string.format("玩家 %s 不是箱子 %s 的所有者", source, box_id))
        return
    end

    -- 验证箱子数据
    local box_data = ActiveWeaponBoxes[box_id]
    if not box_data then
        debug_print(string.format("武器箱 %s 不存在，释放锁", box_id))
        UnlockBox(box_id)
        return
    end

    if box_data.opened then
        debug_print(string.format("武器箱 %s 已被打开，释放锁", box_id))
        UnlockBox(box_id)
        return
    end

    -- 选择随机物品
    local item_name, amount = SelectRandomLoot()

    -- 给予物品
    local success = GiveLootToPlayer(source, item_name, amount)

    if success then
        -- 标记箱子已打开
        box_data.opened = true

        -- 通知玩家
        local itemLabel = QBCore.Shared.Items[item_name] and QBCore.Shared.Items[item_name].label or item_name
        TriggerClientEvent('QBCore:Notify', source, string.format('获得: %s x%d', itemLabel, amount), 'success')

        debug_print(string.format("玩家 %s 成功搜索武器箱 %s，获得: %s x%d", playerName, box_id, item_name, amount))

        -- 移除武器箱（打开后立即消失）
        RemoveWeaponBox(box_id)
    else
        -- 物品给予失败，释放锁
        UnlockBox(box_id)
        TriggerClientEvent('QBCore:Notify', source, '背包空间不足', 'error')
        debug_print(string.format("玩家 %s 背包已满，无法获得物品", playerName))
    end
end)

-- 玩家取消搜索
RegisterNetEvent('yx_island:server:cancel_weapon_box_search', function(box_id)
    local source = source
    local playerName = GetPlayerName(source)

    debug_print(string.format("玩家 %s (ID: %s) 取消搜索: %s", playerName, source, box_id))

    -- 验证并释放锁
    if ValidateLockOwner(box_id, source) then
        UnlockBox(box_id)
    end
end)

-- ==================== 玩家掉线清理 ====================

AddEventHandler('playerDropped', function()
    local source = source
    local playerName = GetPlayerName(source)

    -- 释放所有该玩家持有的武器箱锁
    for box_id, locked_by in pairs(BoxLocks) do
        if locked_by == source then
            UnlockBox(box_id)
            debug_print(string.format("玩家 %s 掉线，释放武器箱锁: %s", playerName, box_id))
        end
    end
end)

-- ==================== 调试命令 ====================

if Config.WeaponBoxes and Config.WeaponBoxes.debug then
    RegisterCommand('island_boxes', function(source, args)
        if source == 0 then  -- 仅控制台
            print('========== 武器箱状态 ==========')

            local totalBoxes = 0
            for _ in pairs(ActiveWeaponBoxes) do totalBoxes = totalBoxes + 1 end

            print(string.format('总计: %d 个武器箱', totalBoxes))

            for box_id, box_data in pairs(ActiveWeaponBoxes) do
                local status = box_data.opened and '已开启' or '未开启'
                local locked = BoxLocks[box_id] and ('锁定: ' .. GetPlayerName(BoxLocks[box_id])) or '未锁定'
                print(string.format('%s - %s - %s - %s', box_id, status, locked, box_data.coords))
            end

            print('==============================')
        end
    end, true)
end

print("^2[yx_Island]^0 武器箱服务端模块已加载")
