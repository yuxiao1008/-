local QBCore = exports['qb-core']:GetCoreObject()

QBCore.Functions.CreateCallback('yx_hideitem:checkShovel', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local shovel = Player.Functions.GetItemByName('shovel')
        cb(shovel ~= nil and shovel.amount > 0)
    else
        cb(false)
    end
end)

local function createHiddenItemsTable()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS hidden_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            item_name VARCHAR(100) NOT NULL,
            item_amount INT NOT NULL,
            x FLOAT NOT NULL,
            y FLOAT NOT NULL,
            z FLOAT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_citizenid (citizenid),
            INDEX idx_created_at (created_at)
        )
    ]])
end

local function cleanupExpiredItems()
    MySQL.Async.execute('DELETE FROM hidden_items WHERE created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)')
    print('[yx_hideitem] 已清理过期的藏匿物品')
end

CreateThread(function()
    createHiddenItemsTable()
    Wait(5000) -- 等待5秒确保数据库连接稳定
    cleanupExpiredItems()
end)

RegisterNetEvent('yx_hideitem:hideItem', function(itemName, amount, coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    local item = Player.Functions.GetItemByName(itemName)
    if not item or item.amount < amount then
        local itemLabel = QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label or itemName
        TriggerClientEvent('QBCore:Notify', src, '你没有足够的 ' .. itemLabel .. '！', 'error')
        return
    end
    
    Player.Functions.RemoveItem(itemName, amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "remove")
    
    MySQL.Async.insert('INSERT INTO hidden_items (citizenid, item_name, item_amount, x, y, z) VALUES (?, ?, ?, ?, ?, ?)', {
        Player.PlayerData.citizenid,
        itemName,
        amount,
        coords.x,
        coords.y,
        coords.z
    }, function(insertId)
        if insertId then
            local itemLabel = QBCore.Shared.Items[itemName] and QBCore.Shared.Items[itemName].label or itemName
            TriggerClientEvent('QBCore:Notify', src, '成功藏匿了 ' .. amount .. ' 个 ' .. itemLabel .. '！', 'success')
        else
            Player.Functions.AddItem(itemName, amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[itemName], "add")
            TriggerClientEvent('QBCore:Notify', src, '藏匿失败，物品已归还！', 'error')
        end
    end)
end)

RegisterNetEvent('yx_hideitem:digUpItem', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        return
    end
    
    local shovel = Player.Functions.GetItemByName('shovel')
    if not shovel or shovel.amount <= 0 then
        TriggerClientEvent('QBCore:Notify', src, '你需要一把铲子才能挖掘！', 'error')
        return
    end
    
    local searchRadius = 3.0
    MySQL.Async.fetchAll('SELECT * FROM hidden_items WHERE x BETWEEN ? AND ? AND y BETWEEN ? AND ? AND z BETWEEN ? AND ?', {
        coords.x - searchRadius, coords.x + searchRadius,
        coords.y - searchRadius, coords.y + searchRadius,
        coords.z - searchRadius, coords.z + searchRadius
    }, function(result)
        if result and #result > 0 then
            local hiddenItem = result[1]
            
            Player.Functions.AddItem(hiddenItem.item_name, hiddenItem.item_amount)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[hiddenItem.item_name], "add")
            
            MySQL.Async.execute('DELETE FROM hidden_items WHERE id = ?', {hiddenItem.id})
            
            local itemLabel = QBCore.Shared.Items[hiddenItem.item_name] and QBCore.Shared.Items[hiddenItem.item_name].label or hiddenItem.item_name
            TriggerClientEvent('QBCore:Notify', src, '挖掘到了 ' .. hiddenItem.item_amount .. ' 个 ' .. itemLabel .. '！', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, '这里什么也没有...', 'error')
        end
    end)
end)

QBCore.Commands.Add('digup', '在当前位置挖掘藏匿的物品', {}, false, function(source, args)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local ped = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)
        TriggerServerEvent('yx_hideitem:digUpItem', coords)
    end
end)