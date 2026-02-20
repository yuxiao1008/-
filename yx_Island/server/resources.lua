-- 佩里科岛物资刷新系统 - 服务端
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 当前活动的刷新点数据 {spawn_id = spawn_data}
ActiveResourceSpawns = {}

-- 刷新点ID计数器
local SpawnIdCounter = 0

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island RESOURCES] " .. msg)
    end
end

-- ==================== 核心函数 ====================

-- 生成唯一刷新点ID
local function GenerateSpawnId()
    SpawnIdCounter = SpawnIdCounter + 1
    return "resource_spawn_" .. os.time() .. "_" .. SpawnIdCounter
end

-- Fisher-Yates 洗牌算法
local function ShuffleTable(tbl)
    local shuffled = {}
    for i, v in ipairs(tbl) do
        shuffled[i] = v
    end

    for i = #shuffled, 2, -1 do
        local j = math.random(1, i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    return shuffled
end

-- 为单个区域生成刷新点
local function GenerateZoneSpawns(zone, zone_index)
    debug_print(string.format("正在生成区域 %d (%s) 的刷新点...", zone_index, zone.name))

    -- 1. 获取数量范围
    local min_amount = zone.min_amount_per_point or 1
    local max_amount = zone.max_amount_per_point or 1

    -- 2. 为每个物品生成分配方案（将总量分配到多个点位）
    local item_allocations = {}  -- 所有物品的点位分配
    
    for _, item in ipairs(zone.loot_table) do
        if item.amount > 0 then
            -- 将该物品的总量分配到多个点位
            local remaining = item.amount
            local point_count = 0
            
            while remaining > 0 do
                -- 计算该点位可以分配的最小和最大数量
                local min_for_point = math.min(min_amount, remaining)  -- 不能超过剩余量
                local max_for_point = math.min(max_amount, remaining)  -- 不能超过剩余量
                
                -- 随机生成该点位的数量
                local amount_for_point
                if min_for_point == max_for_point then
                    -- 如果最小值等于最大值，直接使用
                    amount_for_point = min_for_point
                else
                    -- 随机选择
                    amount_for_point = math.random(min_for_point, max_for_point)
                end
                
                table.insert(item_allocations, {
                    name = item.name,
                    label = item.label,
                    amount = amount_for_point
                })
                
                remaining = remaining - amount_for_point
                point_count = point_count + 1
            end
            
            debug_print(string.format("物品 %s: 总量 %d，分配到 %d 个点位", item.label, item.amount, point_count))
        end
    end

    if #item_allocations == 0 then
        debug_print(string.format("警告: 区域 %d 没有可刷新的物品", zone_index))
        return {}
    end

    debug_print(string.format("区域 %d 总共需要 %d 个刷新点位", zone_index, #item_allocations))

    -- 3. 打乱分配顺序（让物品随机分布）
    local shuffled_allocations = ShuffleTable(item_allocations)

    -- 4. 打乱刷新点顺序
    local shuffled_points = ShuffleTable(zone.spawn_points)

    -- 5. 将分配好的物品放到点位上
    local active_spawns = {}
    local items_to_spawn = math.min(#shuffled_allocations, #shuffled_points)

    for i = 1, items_to_spawn do
        local spawn_id = GenerateSpawnId()
        local allocation = shuffled_allocations[i]

        table.insert(active_spawns, {
            spawn_id = spawn_id,
            coords = shuffled_points[i],
            zone_id = zone_index,
            zone_name = zone.name,
            item = allocation
        })

        debug_print(string.format("点位 %d: %s x%d", i, allocation.label, allocation.amount))
    end

    debug_print(string.format("区域 %d 生成了 %d 个刷新点 (每点数量范围: %d-%d)", 
        zone_index, #active_spawns, min_amount, max_amount))

    if #shuffled_allocations > #shuffled_points then
        debug_print(string.format("警告: 区域 %d 需要 %d 个点位，但只有 %d 个点位配置，部分物品未刷新",
            zone_index, #shuffled_allocations, #shuffled_points))
    end

    return active_spawns
end

-- 初始化所有区域的刷新点
function InitializeResourceSpawns()
    if not Config.Resources.enabled then
        debug_print("物资刷新系统未启用")
        return 0
    end

    ClearAllResourceSpawns()
    local total_spawns = 0

    for zone_index, zone in ipairs(Config.Resources.zones) do
        local zone_spawns = GenerateZoneSpawns(zone, zone_index)

        for _, spawn in ipairs(zone_spawns) do
            ActiveResourceSpawns[spawn.spawn_id] = spawn
            total_spawns = total_spawns + 1
        end
    end

    TriggerClientEvent('yx_island:client:sync_resource_spawns', -1, ActiveResourceSpawns)
    print(string.format("^2[yx_Island RESOURCES]^0 已初始化 %d 个物资刷新点", total_spawns))
    return total_spawns
end

-- 玩家拾取物资
RegisterNetEvent('yx_island:server:pickup_resource', function(spawn_id)
    local source = source

    -- 验证刷新点是否存在
    if not ActiveResourceSpawns[spawn_id] then
        TriggerClientEvent('QBCore:Notify', source, Config.Resources.notifications.no_items, 'error')
        debug_print(string.format("玩家 %s 尝试拾取不存在的刷新点: %s", source, spawn_id))
        return
    end

    local spawn_data = ActiveResourceSpawns[spawn_id]
    local item = spawn_data.item
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        debug_print(string.format("无法获取玩家 %s 的数据", source))
        return
    end

    -- 添加物品到背包（使用物品的实际数量）
    local amount = item.amount or 1
    local success = Player.Functions.AddItem(item.name, amount)

    if success then
        local message = string.format(Config.Resources.notifications.pickup_success, item.label, amount)
        TriggerClientEvent('QBCore:Notify', source, message, 'success')

        -- 移除刷新点
        ActiveResourceSpawns[spawn_id] = nil
        TriggerClientEvent('yx_island:client:remove_resource_spawn', -1, spawn_id)

        debug_print(string.format("玩家 %s 拾取了 %s x%d (刷新点: %s)", source, item.name, amount, spawn_id))
    else
        TriggerClientEvent('QBCore:Notify', source, Config.Resources.notifications.pickup_failed, 'error')
        debug_print(string.format("玩家 %s 背包已满，无法拾取 %s x%d", source, item.name, amount))
    end
end)

-- 清空所有刷新点
function ClearAllResourceSpawns()
    local count = 0
    for _ in pairs(ActiveResourceSpawns) do
        count = count + 1
    end

    ActiveResourceSpawns = {}
    TriggerClientEvent('yx_island:client:clear_resource_spawns', -1)

    debug_print(string.format("已清空 %d 个物资刷新点", count))
    return count
end

-- ==================== 导出函数 ====================
exports('InitializeResourceSpawns', InitializeResourceSpawns)
exports('ClearAllResourceSpawns', ClearAllResourceSpawns)
exports('GetActiveResourceCount', function()
    local count = 0
    for _ in pairs(ActiveResourceSpawns) do
        count = count + 1
    end
    return count
end)
