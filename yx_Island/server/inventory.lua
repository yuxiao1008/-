-- 佩里科岛系统 - 背包管理模块
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 全局变量 ====================
-- 存储玩家原始背包数据 {source = {confiscated_items = {}, timestamp}}
PlayerInventoryBackup = {}

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island INVENTORY] " .. msg)
    end
end

-- ==================== 工具函数 ====================
-- 判断物品是否为武器
local function IsWeaponItem(itemName)
    -- QBCore 武器物品通常以 weapon_ 开头
    if string.match(itemName, "^weapon_") then
        return true
    end

    -- 也可以检查 QBCore.Shared.Weapons
    if QBCore.Shared.Weapons[itemName] then
        return true
    end

    return false
end

-- 判断物品是否允许携带
local function IsAllowedItem(itemName)
    -- 检查是否为武器
    if IsWeaponItem(itemName) then
        return true
    end

    -- 检查是否为弹药 (如果配置允许)
    if Config.Inventory.allow_ammo and string.match(itemName, "ammo") then
        return true
    end

    return false
end

-- ==================== 背包管理函数 ====================

-- 保存并部分清空玩家背包 (保留武器)
function StorePlayerInventory(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        debug_print(string.format("玩家 %s 不存在, 无法保存背包", source))
        return false
    end

    -- 使用 qs-inventory 导出函数获取玩家物品
    local success, playerItems = pcall(function()
        return exports['qs-inventory']:GetInventory(source)
    end)

    if not success then
        debug_print("获取 QS 库存失败, 尝试使用 QBCore 方法")
        -- 备用方案: 使用 QBCore 自带方法
        playerItems = Player.PlayerData.items or {}
    end

    -- 分类物品: 需要没收的和允许携带的
    local confiscatedItems = {}
    local allowedCount = 0
    local confiscatedCount = 0

    for slot, item in pairs(playerItems) do
        if item and item.name and item.amount then
            if IsAllowedItem(item.name) then
                -- 允许携带的物品 (武器/弹药)
                allowedCount = allowedCount + 1
                debug_print(string.format("  [保留] %s x%s (槽位: %s)", item.name, item.amount, slot))
            else
                -- 需要没收的物品
                confiscatedItems[slot] = item
                confiscatedCount = confiscatedCount + 1
                debug_print(string.format("  [没收] %s x%s (槽位: %s)", item.name, item.amount, slot))
            end
        end
    end

    -- 备份需要没收的物品
    PlayerInventoryBackup[source] = {
        confiscated_items = confiscatedItems,
        timestamp = os.time()
    }

    debug_print(string.format("玩家 %s 背包分类完成: 保留 %s 件, 没收 %s 件", source, allowedCount, confiscatedCount))

    -- 移除需要没收的物品
    for slot, item in pairs(confiscatedItems) do
        local removeSuccess = pcall(function()
            Player.Functions.RemoveItem(item.name, item.amount, slot)
        end)

        if not removeSuccess then
            debug_print(string.format("移除物品失败: %s", item.name))
        end
    end

    -- 发送通知
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.inventory_stored, 'primary')
    debug_print(string.format("已没收玩家 %s 的 %s 件非武器物品", source, confiscatedCount))

    return true
end

-- 恢复玩家背包
function RestorePlayerInventory(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        debug_print(string.format("玩家 %s 不存在, 无法恢复背包", source))
        return false
    end

    -- 检查是否有备份数据
    if not PlayerInventoryBackup[source] then
        debug_print(string.format("玩家 %s 没有备份数据", source))
        return false
    end

    local backupData = PlayerInventoryBackup[source]
    debug_print(string.format("正在恢复玩家 %s 的背包...", source))

    -- 恢复物品
    if backupData.confiscated_items then
        for slot, item in pairs(backupData.confiscated_items) do
            if item and item.name and item.amount then
                local restoreSuccess = pcall(function()
                    -- 使用 QBCore 方法添加物品
                    Player.Functions.AddItem(item.name, item.amount, slot, item.info)
                end)

                if not restoreSuccess then
                    debug_print(string.format("恢复物品失败: %s", item.name))
                end
            end
        end
    end

    -- 发送通知
    TriggerClientEvent('QBCore:Notify', source, Config.Notifications.inventory_returned, 'success')
    debug_print(string.format("已恢复玩家 %s 的背包", source))

    -- 清除备份数据
    PlayerInventoryBackup[source] = nil

    return true
end

-- 强制恢复所有玩家背包 (用于紧急情况)
function RestoreAllInventories()
    local count = 0
    for source, data in pairs(PlayerInventoryBackup) do
        if RestorePlayerInventory(source) then
            count = count + 1
        end
    end
    debug_print(string.format("批量恢复完成, 共恢复 %s 个玩家的背包", count))
    return count
end

-- 清空玩家所有物品 (包括武器) - 用于强制撤离
function ClearAllPlayerItems(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        debug_print(string.format("玩家 %s 不存在, 无法清空背包", source))
        return false
    end

    debug_print(string.format("开始清空玩家 %s 的所有物品 (包括武器)...", source))

    -- 尝试使用 QS 库存清空
    local clearSuccess = pcall(function()
        exports['qs-inventory']:ClearInventory(source)
    end)

    if not clearSuccess then
        debug_print("使用 QS 清空失败, 尝试手动清空")
        -- 备用方案: 手动清空所有物品
        if Player.PlayerData.items then
            for slot, item in pairs(Player.PlayerData.items) do
                if item and item.name and item.amount then
                    Player.Functions.RemoveItem(item.name, item.amount, slot)
                    debug_print(string.format("  [移除] %s x%s", item.name, item.amount))
                end
            end
        end
    end

    -- 清空背包备份数据
    if PlayerInventoryBackup[source] then
        PlayerInventoryBackup[source] = nil
        debug_print(string.format("玩家 %s 的背包备份已清空", source))
    end

    debug_print(string.format("^1玩家 %s 的所有物品已清空 (强制撤离)^0", source))
    return true
end

-- ==================== 事件处理 ====================

-- 玩家离线时清除背包备份
AddEventHandler('playerDropped', function()
    local source = source
    if PlayerInventoryBackup[source] then
        debug_print(string.format("玩家 %s 离线，清除背包备份数据", source))
        PlayerInventoryBackup[source] = nil
    end
end)

-- ==================== 导出函数 ====================
exports('StorePlayerInventory', StorePlayerInventory)
exports('RestorePlayerInventory', RestorePlayerInventory)
exports('RestoreAllInventories', RestoreAllInventories)
exports('ClearAllPlayerItems', ClearAllPlayerItems)
