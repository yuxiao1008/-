-- 佩里科岛系统 - 死亡背包服务端逻辑
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 死亡背包数据表 {bag_id = bag_data}
DeathBags = {}

-- 背包 ID 计数器
local BagIdCounter = 0

-- 背包访问锁（防止并发访问）
local BagLocks = {}

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island DEATH] " .. msg)
    end
end

-- ==================== 核心函数 ====================

-- 生成唯一背包 ID
local function GenerateBagId()
    BagIdCounter = BagIdCounter + 1
    return Config.DeathBag.id_prefix .. os.time() .. "_" .. BagIdCounter
end

-- 获取玩家所有物品
local function GetPlayerInventoryItems(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return {} end

    local items = {}

    -- 获取背包物品
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.amount > 0 then
            table.insert(items, {
                slot = slot,
                name = item.name,
                amount = item.amount,
                info = item.info,
                type = item.type
            })
        end
    end

    return items
end


-- 清空玩家背包
function ClearPlayerInventory(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end

    for slot, item in pairs(Player.PlayerData.items) do
        if item then
            Player.Functions.RemoveItem(item.name, item.amount, slot)
        end
    end
    debug_print(string.format("已清空玩家 %s 的背包", source))
end

-- 创建死亡背包
function CreateDeathBag(source, deathCoords)
    print(string.format("^3[yx_Island DEATH]^0 CreateDeathBag 被调用，玩家: %s", source))

    if not Config.DeathBag.enabled then
        print("^1[yx_Island DEATH]^0 死亡背包功能未启用")
        return
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print(string.format("^1[yx_Island DEATH]^0 无法获取玩家 %s 的 QBCore 对象", source))
        return
    end

    print(string.format("^2[yx_Island DEATH]^0 玩家对象获取成功: %s", Player.PlayerData.charinfo.firstname))

    -- 1. 生成背包 ID
    local bagId = GenerateBagId()
    local stashId = bagId
    print(string.format("^3[yx_Island DEATH]^0 生成背包ID: %s", bagId))

    -- 2. 获取玩家物品
    local items = GetPlayerInventoryItems(source)
    print(string.format("^3[yx_Island DEATH]^0 玩家物品数量: %d", #items))

    if #items == 0 then
        print("^3[yx_Island DEATH]^0 玩家无物品，不生成背包")
        return false
    end

    -- 6. 在服务端创建网络实体
    print(string.format("^3[yx_Island DEATH]^0 正在创建背包实体: %s", bagId))

    -- 稍微降低高度，让背包贴地
    local spawnCoords = vector3(
        deathCoords.x,
        deathCoords.y,
        deathCoords.z - 0.5  -- 降低0.5米
    )

    local bagObject = CreateObject(
        GetHashKey(Config.DeathBag.bag_model),
        spawnCoords.x, spawnCoords.y, spawnCoords.z,
        true,  -- isNetwork
        false, -- bScriptHostObj (改为 false)
        true   -- dynamic (改为 true)
    )

    -- 等待实体创建
    local timeout = 0
    while not DoesEntityExist(bagObject) and timeout < 50 do
        Wait(10)
        timeout = timeout + 1
    end

    if not DoesEntityExist(bagObject) then
        print(string.format("^1[yx_Island DEATH]^0 实体创建失败，物品保留在玩家身上"))
        return false
    end

    -- 获取网络ID
    local netId = NetworkGetNetworkIdFromEntity(bagObject)
    print(string.format("^2[yx_Island DEATH]^0 背包实体已创建: Entity %s, NetID %s", bagObject, netId))

    -- 3. 清空玩家背包（实体创建成功后才清空）
    ClearPlayerInventory(source)

    -- 7. 通知所有客户端（发送网络ID）
    TriggerClientEvent('yx_island:client:spawn_death_bag', -1, bagId, deathCoords, netId)

    -- 4. 记录背包数据
    DeathBags[bagId] = {
        owner_source = source,
        owner_name = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname,
        coords = deathCoords,
        items = items,
        stash_id = stashId,
        created_at = os.time(),
        entity = bagObject,
        netId = netId,
        stash_initialized = false  -- 标记stash是否已初始化
    }

    debug_print(string.format("创建死亡背包 %s，共 %d 件物品", bagId, #items))
    return true
end

-- 检查并清理空背包
local function CheckAndCleanEmptyBag(bagId)
    if not DeathBags[bagId] then return end

    local stashId = DeathBags[bagId].stash_id

    -- 使用qs-inventory的GetStashItems导出检查
    local success, stashItems = pcall(function()
        return exports['qs-inventory']:GetStashItems(stashId)
    end)
    
    local isEmpty = true
    if success and stashItems and type(stashItems) == "table" then
        -- 检查是否有物品
        for slot, item in pairs(stashItems) do
            if item and type(item) == "table" and item.amount and item.amount > 0 then
                isEmpty = false
                print(string.format("^3[yx_Island DEATH]^0 背包 %s 槽位 %s 有物品: %s x%d", bagId, slot, item.name, item.amount))
                break
            end
        end
    else
        print(string.format("^3[yx_Island DEATH]^0 无法获取背包 %s 的物品数据", bagId))
    end

    -- 如果仓库为空，清理背包
    if isEmpty then
        print(string.format("^3[yx_Island DEATH]^0 背包 %s 已空，自动清理", bagId))
        RemoveDeathBag(bagId)
    else
        print(string.format("^2[yx_Island DEATH]^0 背包 %s 仍有物品，保留", bagId))
    end
end

-- 移除单个背包
function RemoveDeathBag(bagId)
    if not DeathBags[bagId] then return end

    print(string.format("^3[yx_Island DEATH]^0 正在移除背包: %s", bagId))

    -- 1. 删除服务端实体
    if DeathBags[bagId].entity and DoesEntityExist(DeathBags[bagId].entity) then
        DeleteEntity(DeathBags[bagId].entity)
        print(string.format("^2[yx_Island DEATH]^0 已删除服务端实体: %s", DeathBags[bagId].entity))
    end

    -- 2. 通知客户端删除实体
    TriggerClientEvent('yx_island:client:remove_death_bag', -1, bagId)

    -- 3. 清除stash数据（使用qs-inventory的导出）
    local stashId = DeathBags[bagId].stash_id
    local success = pcall(function()
        exports['qs-inventory']:ClearOtherInventory('stash', stashId)
    end)
    
    if success then
        print(string.format("^2[yx_Island DEATH]^0 已清除stash数据: %s", stashId))
    else
        print(string.format("^1[yx_Island DEATH]^0 清除stash数据失败: %s", stashId))
    end

    -- 4. 清除数据
    DeathBags[bagId] = nil
    BagLocks[bagId] = nil

    print(string.format("^2[yx_Island DEATH]^0 已移除背包 %s", bagId))
end

-- 清理所有背包
function ClearAllDeathBags()
    local count = 0
    for bagId, _ in pairs(DeathBags) do
        RemoveDeathBag(bagId)
        count = count + 1
    end

    debug_print(string.format("已清理 %d 个死亡背包", count))
    return count
end

-- ==================== 事件处理 ====================

-- 玩家死亡事件 (由客户端触发)
RegisterNetEvent('yx_island:server:player_died', function(deathCoords)
    local source = source

    print(string.format("^3[yx_Island DEATH]^0 收到玩家 %s 的死亡事件", source))
    print(string.format("^3[yx_Island DEATH]^0 死亡坐标: %.2f, %.2f, %.2f", deathCoords.x, deathCoords.y, deathCoords.z))

    -- 检查玩家是否在岛上
    if not IslandPlayers[source] then
        print(string.format("^1[yx_Island DEATH]^0 玩家 %s 不在岛上，跳过死亡处理", source))
        print(string.format("^1[yx_Island DEATH]^0 当前岛上玩家列表:"))
        for id, name in pairs(IslandPlayers) do
            print(string.format("  - [%s] %s", id, name))
        end
        return
    end

    print(string.format("^2[yx_Island DEATH]^0 玩家 %s 在岛上死亡", source))

    -- 创建死亡背包（如果玩家有物品）
    if Config.DeathBag.enabled then
        CreateDeathBag(source, deathCoords)
    end

    -- 玩家死亡后踢出活动
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local playerName = Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname

        -- 标记为已死亡
        if not EvacuatedPlayers then EvacuatedPlayers = {} end
        EvacuatedPlayers[source] = {
            name = playerName,
            reason = "死亡"
        }

        -- 从岛上玩家列表移除
        IslandPlayers[source] = nil

        -- 通知玩家
        TriggerClientEvent('QBCore:Notify', source, Config.DeathBag.notifications.kicked_from_activity, 'error', 5000)

        print(string.format("^1[yx_Island DEATH]^0 玩家 %s 已被标记为死亡并退出活动", source))
    end
end)

-- 打开背包菜单（使用ox_lib显示可选拾取）
RegisterNetEvent('yx_island:server:open_death_bag', function(bagId)
    local source = source

    -- 1. 检查背包是否存在
    if not DeathBags[bagId] then
        TriggerClientEvent('QBCore:Notify', source, "背包不存在", 'error')
        return
    end

    -- 2. 防并发访问
    if BagLocks[bagId] then
        TriggerClientEvent('QBCore:Notify', source, "有人正在查看背包", 'error')
        return
    end

    local items = DeathBags[bagId].items
    local ownerName = DeathBags[bagId].owner_name
    
    print(string.format("^3[yx_Island DEATH]^0 玩家 %s 正在查看背包 %s", source, bagId))

    -- 3. 检查是否还有物品
    if not items or #items == 0 then
        TriggerClientEvent('QBCore:Notify', source, "背包已空", 'error')
        -- 清理空背包
        RemoveDeathBag(bagId)
        return
    end

    -- 4. 发送物品列表到客户端显示菜单
    TriggerClientEvent('yx_island:client:show_bag_menu', source, bagId, items, ownerName)
end)

-- 拾取单个物品
RegisterNetEvent('yx_island:server:take_bag_item', function(bagId, itemIndex)
    local source = source

    -- 检查背包是否存在
    if not DeathBags[bagId] then
        TriggerClientEvent('QBCore:Notify', source, "背包不存在", 'error')
        return
    end

    local items = DeathBags[bagId].items
    local item = items[itemIndex]

    if not item then
        TriggerClientEvent('QBCore:Notify', source, "物品不存在", 'error')
        return
    end

    -- 获取玩家对象
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print(string.format("^1[yx_Island DEATH]^0 无法获取玩家 %s 的对象", source))
        return
    end

    -- 获取物品友好名称
    local itemLabel = item.name
    if QBCore.Shared.Items and QBCore.Shared.Items[item.name] then
        itemLabel = QBCore.Shared.Items[item.name].label or item.name
    end

    -- 尝试给予物品
    local success = Player.Functions.AddItem(item.name, item.amount, false, item.info or {})

    if success then
        print(string.format("^2[yx_Island DEATH]^0 给予物品成功: %s x%d", item.name, item.amount))

        -- 从背包中移除该物品
        table.remove(DeathBags[bagId].items, itemIndex)

        TriggerClientEvent('QBCore:Notify', source,
            string.format("拾取了 %s x%d", itemLabel, item.amount),
            'success')
        
        -- 检查背包是否为空
        if #DeathBags[bagId].items == 0 then
            print(string.format("^3[yx_Island DEATH]^0 背包 %s 已空，自动清理", bagId))
            RemoveDeathBag(bagId)
        else
            -- 刷新菜单，显示剩余物品
            TriggerClientEvent('yx_island:client:refresh_bag_menu', source, bagId, DeathBags[bagId].items, DeathBags[bagId].owner_name)
        end
    else
        print(string.format("^1[yx_Island DEATH]^0 给予物品失败: %s x%d (背包已满)", item.name, item.amount))
        TriggerClientEvent('QBCore:Notify', source, "背包已满，无法拾取", 'error')
    end
end)

-- 拾取全部物品
RegisterNetEvent('yx_island:server:take_all_items', function(bagId)
    local source = source

    -- 检查背包是否存在
    if not DeathBags[bagId] then
        TriggerClientEvent('QBCore:Notify', source, "背包不存在", 'error')
        return
    end

    local items = DeathBags[bagId].items
    local ownerName = DeathBags[bagId].owner_name

    if not items or #items == 0 then
        TriggerClientEvent('QBCore:Notify', source, "背包已空", 'error')
        RemoveDeathBag(bagId)
        return
    end

    -- 获取玩家对象
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        print(string.format("^1[yx_Island DEATH]^0 无法获取玩家 %s 的对象", source))
        return
    end

    print(string.format("^3[yx_Island DEATH]^0 玩家 %s 正在拾取全部物品", source))
    
    local successCount = 0
    local failCount = 0
    local remainingItems = {}
    
    for _, item in ipairs(items) do
        -- 尝试给予物品
        local success = Player.Functions.AddItem(item.name, item.amount, false, item.info or {})
        
        if success then
            print(string.format("^2[yx_Island DEATH]^0 给予物品成功: %s x%d", item.name, item.amount))
            successCount = successCount + 1
        else
            print(string.format("^1[yx_Island DEATH]^0 给予物品失败: %s x%d (背包已满)", item.name, item.amount))
            failCount = failCount + 1
            -- 保留未拾取的物品
            table.insert(remainingItems, item)
        end
        
        Wait(50) -- 避免并发问题
    end

    -- 更新背包物品列表
    DeathBags[bagId].items = remainingItems

    -- 通知玩家
    if successCount > 0 then
        TriggerClientEvent('QBCore:Notify', source, 
            string.format("从 %s 的背包中获得了 %d 件物品", ownerName, successCount), 
            'success', 5000)
    end
    
    if failCount > 0 then
        TriggerClientEvent('QBCore:Notify', source, 
            string.format("有 %d 件物品无法拾取（背包已满）", failCount), 
            'error')
        
        -- 刷新菜单显示剩余物品
        TriggerClientEvent('yx_island:client:refresh_bag_menu', source, bagId, remainingItems, ownerName)
    else
        -- 所有物品都拾取完毕，清理背包
        print(string.format("^2[yx_Island DEATH]^0 所有物品已拾取，清理背包 %s", bagId))
        RemoveDeathBag(bagId)
    end

    print(string.format("^2[yx_Island DEATH]^0 拾取完成: 成功 %d 件, 失败 %d 件", successCount, failCount))
end)

-- 玩家离线时清理其背包
AddEventHandler('playerDropped', function()
    local source = source

    if not Config.DeathBag.keep_on_disconnect then
        for bagId, bagData in pairs(DeathBags) do
            if bagData.owner_source == source then
                debug_print(string.format("玩家 %s 离线，清理其背包 %s", source, bagId))
                RemoveDeathBag(bagId)
            end
        end
    end
end)

-- ==================== 调试命令 ====================

-- 查看所有背包
RegisterCommand('island_bags', function()
    print("^3[yx_Island]^0 当前死亡背包:")
    local count = 0
    for bagId, bagData in pairs(DeathBags) do
        count = count + 1
        print(string.format("  - %s: %s (%d 件物品)",
            bagId, bagData.owner_name, #bagData.items))
    end
    if count == 0 then
        print("  (无)")
    end
end, true)

-- 强制清理所有背包
RegisterCommand('island_clearbags', function()
    local count = ClearAllDeathBags()
    print(string.format("^2[yx_Island]^0 已清理 %d 个背包", count))
end, true)
