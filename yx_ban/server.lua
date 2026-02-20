-- ====================================
-- 监狱系统 - 服务端
-- 基于license的持久化监狱系统
-- ====================================

local QBCore = exports['qb-core']:GetCoreObject()

-- ====================================
-- 全局变量
-- ====================================
local JailedPlayers = {} -- 内存中的监狱玩家列表 {license: {data}}
local DatabaseReady = false
local ActiveRoutingBuckets = {} -- 活跃的路由桶记录 {bucketId: {license, lastUsed}}
local NextBucketId = Config.RoutingBucket.prisonBucketBase
local PlayerReviveTimes = {} -- 玩家复活时间记录 {license: lastReviveTime}

-- ====================================
-- 数据库初始化
-- ====================================
CreateThread(function()
    if not Config.Database.enableDatabase then
        DebugPrint('数据库功能已禁用')
        return
    end
    
    -- 创建数据库表
    local createTableQuery = string.format([[
        CREATE TABLE IF NOT EXISTS `%s` (
            `license` varchar(100) NOT NULL PRIMARY KEY,
            `jail_time` int(11) NOT NULL DEFAULT 0,
            `reason` varchar(255) DEFAULT NULL,
            `isJailed` tinyint(1) NOT NULL DEFAULT 0,
            `jail_start` timestamp DEFAULT CURRENT_TIMESTAMP,
            `last_update` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], Config.Database.tableName)
    
    exports.oxmysql:execute(createTableQuery, {}, function(result)
        if result then
            DebugPrint('数据库表 ' .. Config.Database.tableName .. ' 初始化成功')
            DatabaseReady = true
        else
            DebugPrint('数据库表初始化失败')
        end
    end)
end)

-- ====================================
-- 数据库操作函数
-- ====================================

-- 将玩家添加到监狱
function AddPlayerToJail(license, jailTimeMinutes, reason)
    if not DatabaseReady then
        DebugPrint('数据库未就绪，无法添加监狱记录')
        return false
    end
    
    local jailTimeSeconds = jailTimeMinutes * 60
    local query = string.format([[
        INSERT INTO `%s` (license, jail_time, reason, isJailed) 
        VALUES (?, ?, ?, 1) 
        ON DUPLICATE KEY UPDATE 
        jail_time = VALUES(jail_time), 
        reason = VALUES(reason), 
        isJailed = 1,
        last_update = CURRENT_TIMESTAMP
    ]], Config.Database.tableName)
    
    exports.oxmysql:execute(query, {license, jailTimeSeconds, reason}, function(result)
        if result then
            DebugPrint('成功添加监狱记录: ' .. license .. ' (' .. jailTimeMinutes .. '分钟)')
        else
            DebugPrint('添加监狱记录失败: ' .. license)
        end
    end)
    
    return true
end

-- 从监狱释放玩家
function ReleasePlayerFromJail(license)
    if not DatabaseReady then
        DebugPrint('数据库未就绪，无法释放玩家')
        return false
    end
    
    local query = string.format([[
        UPDATE `%s` SET isJailed = 0, jail_time = 0 WHERE license = ?
    ]], Config.Database.tableName)
    
    exports.oxmysql:execute(query, {license}, function(result)
        if result then
            DebugPrint('成功释放玩家: ' .. license)
        else
            DebugPrint('释放玩家失败: ' .. license)
        end
    end)
    
    return true
end

-- 更新玩家剩余时间
function UpdatePlayerJailTime(license, jailTimeSeconds)
    if not DatabaseReady then return end
    
    local query = string.format([[
        UPDATE `%s` SET jail_time = ?, last_update = CURRENT_TIMESTAMP WHERE license = ? AND isJailed = 1
    ]], Config.Database.tableName)
    
    exports.oxmysql:execute(query, {jailTimeSeconds, license}, function(result)
        -- 静默更新，不输出日志避免刷屏
    end)
end

-- 从数据库加载所有监狱玩家
function LoadJailedPlayersFromDatabase()
    if not DatabaseReady then
        DebugPrint('数据库未就绪，跳过加载')
        return
    end
    
    CreateThread(function()
        local query = string.format('SELECT * FROM `%s` WHERE isJailed = 1 AND jail_time > 0', Config.Database.tableName)
        
        -- 使用同步方式加载数据
        local success, results = pcall(function()
            return exports.oxmysql:query_async(query, {})
        end)
        
        if success and results then
            DebugPrint('从数据库加载了 ' .. #results .. ' 条监狱记录')
            
            for _, row in ipairs(results) do
                JailedPlayers[row.license] = {
                    license = row.license,
                    jailTime = row.jail_time,
                    reason = row.reason,
                    source = nil -- 玩家可能不在线
                }
                DebugPrint('加载监狱玩家: ' .. row.license .. ' 剩余 ' .. math.ceil(row.jail_time / 60) .. ' 分钟')
            end
            
            local loadedCount = 0
            for _ in pairs(JailedPlayers) do
                loadedCount = loadedCount + 1
            end
            DebugPrint('监狱数据加载完成，当前内存中有 ' .. loadedCount .. ' 名监狱玩家')
        else
            DebugPrint('加载监狱数据失败: ' .. tostring(results))
            
            -- 尝试备用方法
            Wait(1000)
            exports.oxmysql:execute(query, {}, function(backupResults)
                if backupResults then
                    DebugPrint('[备用方法] 从数据库加载了 ' .. #backupResults .. ' 条监狱记录')
                    
                    for _, row in ipairs(backupResults) do
                        JailedPlayers[row.license] = {
                            license = row.license,
                            jailTime = row.jail_time,
                            reason = row.reason,
                            source = nil
                        }
                        DebugPrint('[备用方法] 加载监狱玩家: ' .. row.license .. ' 剩余 ' .. math.ceil(row.jail_time / 60) .. ' 分钟')
                    end
                else
                    DebugPrint('[备用方法] 监狱数据加载失败')
                end
            end)
        end
    end)
end

-- ====================================
-- 路由桶管理函数
-- ====================================

-- 创建新的监狱路由桶
function CreatePrisonRoutingBucket(license)
    if not Config.RoutingBucket.enable then
        DebugPrint('路由桶功能已禁用，跳过创建')
        return nil
    end
    
    -- 检查是否已存在该玩家的路由桶
    for bucketId, data in pairs(ActiveRoutingBuckets) do
        if data.license == license then
            DebugPrint('玩家 ' .. license .. ' 已存在路由桶: ' .. bucketId)
            data.lastUsed = os.time()
            return bucketId
        end
    end
    
    -- 创建新的路由桶ID
    local bucketId = NextBucketId
    NextBucketId = NextBucketId + 1
    
    -- 防止超出最大限制
    if NextBucketId > (Config.RoutingBucket.prisonBucketBase + Config.RoutingBucket.maxBuckets) then
        NextBucketId = Config.RoutingBucket.prisonBucketBase
    end
    
    -- 记录活跃路由桶
    ActiveRoutingBuckets[bucketId] = {
        license = license,
        created = os.time(),
        lastUsed = os.time()
    }
    
    DebugPrint(Translate('routing_bucket_create_success', {bucketId = bucketId}))
    return bucketId
end

-- 将玩家分配到路由桶
function AssignPlayerToRoutingBucket(source, bucketId)
    if not Config.RoutingBucket.enable then
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end
    
    local success = pcall(function()
        SetPlayerRoutingBucket(source, bucketId)
        SetRoutingBucketEntityLockdownMode(bucketId, Config.RoutingBucket.lockType)
    end)
    
    if success then
        local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        DebugPrint(Translate('routing_bucket_assign_success', {player = playerName, bucketId = bucketId}))
        DebugPrint(Translate('debug_routing_bucket_info', {player = playerName, bucketId = bucketId}))
        
        -- 通知玩家
        TriggerClientEvent('QBCore:Notify', source, Translate('routing_bucket_enabled'), 'primary')
        TriggerClientEvent('yx_prison:routingBucketChanged', source, bucketId, true)
        
        return true
    else
        DebugPrint(Translate('routing_bucket_assign_failed'))
        return false
    end
end

-- 将玩家从路由桶移到主服务器
function RemovePlayerFromRoutingBucket(source)
    if not Config.RoutingBucket.enable then
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        return false
    end
    
    local license = Player.PlayerData.license
    local currentBucket = GetPlayerRoutingBucket(source)
    
    local success = pcall(function()
        SetPlayerRoutingBucket(source, Config.RoutingBucket.mainServerBucket)
    end)
    
    if success then
        local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
        DebugPrint(Translate('debug_routing_bucket_switch', {fromBucket = currentBucket, toBucket = Config.RoutingBucket.mainServerBucket}))
        
        -- 清理路由桶记录
        for bucketId, data in pairs(ActiveRoutingBuckets) do
            if data.license == license then
                ActiveRoutingBuckets[bucketId] = nil
                DebugPrint('清理路由桶记录: ' .. bucketId .. ' (玩家: ' .. license .. ')')
                break
            end
        end
        
        -- 通知玩家
        TriggerClientEvent('QBCore:Notify', source, Translate('routing_bucket_disabled'), 'success')
        TriggerClientEvent('yx_prison:routingBucketChanged', source, Config.RoutingBucket.mainServerBucket, false)
        
        return true
    else
        DebugPrint(Translate('routing_bucket_assign_failed'))
        return false
    end
end

-- 获取玩家的监狱路由桶ID
function GetPlayerPrisonBucket(license)
    for bucketId, data in pairs(ActiveRoutingBuckets) do
        if data.license == license then
            return bucketId
        end
    end
    return nil
end

-- 清理空闲的路由桶
function CleanupIdleRoutingBuckets()
    if not Config.RoutingBucket.enable or not Config.RoutingBucket.autoClean then
        return
    end
    
    local currentTime = os.time()
    local cleanupCount = 0
    local toCleanup = {}
    
    for bucketId, data in pairs(ActiveRoutingBuckets) do
        -- 检查玩家是否还在线
        local Player = nil
        local players = QBCore.Functions.GetPlayers()
        
        for _, playerId in ipairs(players) do
            local p = QBCore.Functions.GetPlayer(playerId)
            if p and p.PlayerData.license == data.license then
                Player = p
                break
            end
        end
        
        -- 如果玩家离线或超过清理时间，标记为需要清理
        if not Player or (currentTime - data.lastUsed) > (Config.RoutingBucket.cleanInterval / 1000) then
            table.insert(toCleanup, bucketId)
        end
    end
    
    -- 执行清理
    for _, bucketId in ipairs(toCleanup) do
        ActiveRoutingBuckets[bucketId] = nil
        cleanupCount = cleanupCount + 1
    end
    
    if cleanupCount > 0 then
        DebugPrint(Translate('routing_bucket_cleanup', {count = cleanupCount}))
    end
end

-- ====================================
-- KOOK事件安全验证
-- ====================================

-- 验证KOOK事件调用权限
function ValidateKookEventSecurity(eventSource, eventName)
    if not Config.KookSecurity.enableKookEvents then
        DebugPrint('KOOK事件已禁用: ' .. eventName)
        return false, 'KOOK事件功能已禁用'
    end
    
    -- 检查允许的source列表
    local isAllowedSource = false
    for _, allowedSource in ipairs(Config.KookSecurity.allowedSources) do
        if eventSource == allowedSource then
            isAllowedSource = true
            break
        end
    end
    
    if not isAllowedSource then
        DebugPrint('KOOK事件权限不足: source ' .. tostring(eventSource) .. ' 不在允许列表中')
        return false, '权限不足：未授权的调用源'
    end
    
    -- 如果要求管理员权限且source不是控制台
    if Config.KookSecurity.requireAdminPermission and eventSource ~= 0 then
        local Player = QBCore.Functions.GetPlayer(eventSource)
        if not Player then
            return false, '玩家对象获取失败'
        end
        
        -- 检查管理员权限（根据你的权限系统调整）
        if not QBCore.Functions.HasPermission(eventSource, Config.RequiredGroup) then
            DebugPrint('KOOK事件权限不足: 玩家 ' .. eventSource .. ' 缺乏管理员权限')
            return false, '权限不足：需要管理员权限'
        end
    end
    
    DebugPrint('KOOK事件权限验证通过: ' .. eventName .. ' (source: ' .. eventSource .. ')')
    return true, '权限验证通过'
end

-- ====================================
-- Chat系统集成
-- ====================================

-- 发送全局监狱通知
function SendGlobalPrisonNotification(playerName, reason, isRelease)
    if not Config.Chat.enableGlobalNotification then
        return
    end
    
    local messageKey = isRelease and 'global_release_notification' or 'global_prison_notification'
    local message = Translate(messageKey, {player = playerName, reason = reason})
    
    -- 检查chat资源是否存在
    local chatResourceState = GetResourceState(Config.Chat.chatResource)
    if chatResourceState ~= 'started' then
        DebugPrint('Chat资源未启动，跳过全局通知: ' .. Config.Chat.chatResource)
        return
    end
    
    -- 使用chat资源的SendMessage函数发送全局消息
    local success = pcall(function()
        exports[Config.Chat.chatResource]:addMessage(-1, {
            template = '<div class="chat-message" style="color: ' .. Config.Chat.notificationColor .. '; font-weight: bold;">&lrm;' .. message .. '&lrm;</div>',
            args = {}
        })
    end)
    
    if success then
        DebugPrint('全局监狱通知已发送: ' .. message)
    else
        DebugPrint('全局监狱通知发送失败，尝试备用方法')
        
        -- 备用方法：直接触发chat事件
        local backupSuccess = pcall(function()
            TriggerClientEvent('chat:addMessage', -1, {
                template = '<div class="chat-message" style="color: ' .. Config.Chat.notificationColor .. '; font-weight: bold;">&lrm;' .. message .. '&lrm;</div>',
                args = {}
            })
        end)
        
        if backupSuccess then
            DebugPrint('备用方法发送全局监狱通知成功')
        else
            DebugPrint('全局监狱通知发送完全失败')
        end
    end
end

-- ====================================
-- 自动复活系统
-- ====================================

-- 自动复活监狱玩家
function AutoReviveJailedPlayer(source, license)
    if not Config.AutoRevive.enable then
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        DebugPrint('自动复活失败: 玩家对象获取失败 ' .. license)
        return false
    end
    
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- 尝试调用救护车资源的复活导出
    local success, err = pcall(function()
        exports[Config.AutoRevive.ambulanceResource]:RevivePlayer(source)
    end)
    
    if success then
        -- 记录复活时间
        PlayerReviveTimes[license] = os.time()
        
        if Config.AutoRevive.logRevive then
            DebugPrint(Translate('auto_revive_success', {player = playerName, license = license}))
        end
        
        -- 通知玩家
        TriggerClientEvent('QBCore:Notify', source, Translate('auto_revive_notification'), 'primary', 3000)
        
        return true
    else
        DebugPrint(Translate('auto_revive_failed', {player = playerName, error = tostring(err)}))
        return false
    end
end

-- 检查是否需要自动复活
function CheckAutoRevive(source, license)
    if not Config.AutoRevive.enable or not JailedPlayers[license] then
        return false
    end
    
    local currentTime = os.time()
    local lastReviveTime = PlayerReviveTimes[license] or 0
    local timeSinceLastRevive = (currentTime - lastReviveTime) * 1000 -- 转换为毫秒
    
    -- 检查是否达到复活间隔
    if timeSinceLastRevive >= Config.AutoRevive.interval then
        return AutoReviveJailedPlayer(source, license)
    end
    
    return false
end

-- ====================================
-- 背包管理函数
-- ====================================

-- 清空玩家背包
function ClearPlayerInventory(source)
    if not Config.Inventory.clearOnJail then
        DebugPrint(Translate('inventory_clear_disabled'))
        return false
    end
    
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        DebugPrint('ClearPlayerInventory: 玩家对象获取失败')
        return false
    end
    
    local license = Player.PlayerData.license
    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    local itemCount = 0
    local cashAmount = 0
    local bankAmount = 0
    
    local success = pcall(function()
        -- 清空物品背包
        if Config.Inventory.clearMethod == 'all' or Config.Inventory.clearMethod == 'items' then
            -- 获取当前物品数量（用于日志）
            for slot, item in pairs(Player.PlayerData.items) do
                if item and item.amount and item.amount > 0 then
                    itemCount = itemCount + item.amount
                end
            end
            
            -- 安全清空所有物品槽
            if Player.PlayerData.items then
                -- 逐个清空物品槽以确保完全清空
                for slot, item in pairs(Player.PlayerData.items) do
                    if item and item.amount and item.amount > 0 then
                        Player.Functions.RemoveItem(item.name, item.amount, slot)
                    end
                end
                -- 确保数据结构完全清空
                Player.PlayerData.items = {}
            end
            Player.Functions.Save()
            
            -- 通知客户端更新背包界面
            TriggerClientEvent('QBCore:Notify', source, Translate('inventory_items_confiscated'), 'error')
            -- 兼容多种背包系统
            TriggerClientEvent('inventory:client:UpdatePlayerInventory', source, true)
            TriggerClientEvent('qb-inventory:client:UpdatePlayerInventory', source, true)
            TriggerClientEvent('lj-inventory:client:UpdatePlayerInventory', source, true)
        end
        
        -- 清空金钱（如果配置为全部清空）
        if Config.Inventory.clearMethod == 'all' then
            cashAmount = Player.PlayerData.money.cash or 0
            bankAmount = Player.PlayerData.money.bank or 0
            
            -- 清空现金和银行余额
            Player.Functions.RemoveMoney('cash', cashAmount, '监狱没收')
            Player.Functions.RemoveMoney('bank', bankAmount, '监狱没收')
        end
    end)
    
    if success then
        -- 记录日志
        if Config.Inventory.logInventoryActions then
            if itemCount > 0 then
                DebugPrint(Translate('debug_inventory_clear', {player = playerName, itemCount = itemCount}))
            end
            if cashAmount > 0 or bankAmount > 0 then
                DebugPrint(Translate('debug_inventory_money_clear', {player = playerName, cash = cashAmount, bank = bankAmount}))
            end
        end
        
        -- 通知管理员
        DebugPrint(Translate('inventory_clear_success', {player = playerName}))
        
        -- 通知玩家
        TriggerClientEvent('QBCore:Notify', source, Translate('inventory_cleared'), 'error', 5000)
        
        return true
    else
        DebugPrint(Translate('inventory_clear_failed'))
        return false
    end
end

-- 检查物品是否在黑名单中
function IsItemBlacklisted(itemName)
    if not Config.Inventory.blacklistItems or #Config.Inventory.blacklistItems == 0 then
        return false
    end
    
    for _, blacklistedItem in ipairs(Config.Inventory.blacklistItems) do
        if itemName == blacklistedItem then
            return true
        end
    end
    return false
end

-- 获取玩家背包物品数量（用于统计）
function GetPlayerItemCount(Player)
    local count = 0
    if Player and Player.PlayerData and Player.PlayerData.items then
        for slot, item in pairs(Player.PlayerData.items) do
            if item and item.amount and item.amount > 0 then
                count = count + item.amount
            end
        end
    end
    return count
end

-- ====================================
-- 监狱管理函数
-- ====================================

-- 关押玩家
function JailPlayer(source, targetId, jailTimeMinutes, reason)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        return false, '玩家不存在'
    end
    
    local license = TargetPlayer.PlayerData.license
    local playerName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    reason = reason or '违反服务器规则'
    
    -- 添加到内存
    JailedPlayers[license] = {
        license = license,
        jailTime = jailTimeMinutes * 60,
        reason = reason,
        source = TargetPlayer.PlayerData.source
    }
    
    -- 初始化复活时间
    PlayerReviveTimes[license] = os.time()
    
    -- 添加到数据库
    AddPlayerToJail(license, jailTimeMinutes, reason)
    
    -- 清空背包（如果启用）
    if Config.Inventory.clearOnJail then
        ClearPlayerInventory(TargetPlayer.PlayerData.source)
    end
    
    -- 创建并分配路由桶（如果启用）
    local bucketId = nil
    if Config.RoutingBucket.enable then
        bucketId = CreatePrisonRoutingBucket(license)
        if bucketId then
            AssignPlayerToRoutingBucket(TargetPlayer.PlayerData.source, bucketId)
            -- 存储路由桶ID到监狱数据中
            JailedPlayers[license].bucketId = bucketId
        end
    end
    
    -- 传送到监狱
    TriggerClientEvent('yx_prison:teleportToPrison', TargetPlayer.PlayerData.source)
    
    -- 发送全局通知
    SendGlobalPrisonNotification(playerName, reason, false)
    
    -- 通知
    TriggerClientEvent('QBCore:Notify', source, '玩家 ' .. playerName .. ' 已被关押 ' .. jailTimeMinutes .. ' 分钟', 'success')
    if bucketId then
        TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, '您已被关押 ' .. jailTimeMinutes .. ' 分钟，已进入单人监狱世界。原因: ' .. reason, 'error')
    else
        TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, '您已被关押 ' .. jailTimeMinutes .. ' 分钟，原因: ' .. reason, 'error')
    end
    
    DebugPrint('关押玩家: ' .. playerName .. ' (' .. license .. ') ' .. jailTimeMinutes .. ' 分钟')
    return true, '关押成功'
end

-- 释放玩家
function ReleasePlayer(source, targetId)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        return false, '玩家不存在'
    end
    
    local license = TargetPlayer.PlayerData.license
    local playerName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    
    if not JailedPlayers[license] then
        return false, '该玩家不在监狱中'
    end
    
    -- 从路由桶移除（如果启用）
    if Config.RoutingBucket.enable then
        RemovePlayerFromRoutingBucket(TargetPlayer.PlayerData.source)
    end
    
    -- 从内存移除
    JailedPlayers[license] = nil
    PlayerReviveTimes[license] = nil
    
    -- 从数据库移除
    ReleasePlayerFromJail(license)
    
    -- 传送到释放位置
    TriggerClientEvent('yx_prison:teleportToRelease', TargetPlayer.PlayerData.source)
    TriggerClientEvent('yx_prison:stopMonitoring', TargetPlayer.PlayerData.source)
    
    -- 发送全局通知
    SendGlobalPrisonNotification(playerName, '', true)
    
    -- 通知
    TriggerClientEvent('QBCore:Notify', source, '玩家 ' .. playerName .. ' 已被释放', 'success')
    TriggerClientEvent('QBCore:Notify', TargetPlayer.PlayerData.source, '您已被释放出狱', 'success')
    
    DebugPrint('释放玩家: ' .. playerName .. ' (' .. license .. ')')
    return true, '释放成功'
end

-- 获取玩家剩余时间
function GetPlayerJailTime(license)
    if JailedPlayers[license] then
        return math.ceil(JailedPlayers[license].jailTime / 60) -- 返回分钟
    end
    return 0
end

-- ====================================
-- 事件处理
-- ====================================

-- 检查玩家是否在监狱区域内
function IsPlayerInPrisonArea(src)
    local playerPed = GetPlayerPed(src)
    if not playerPed or playerPed == 0 then return false end
    
    local coords = GetEntityCoords(playerPed)
    local prisonLocation = Config.Prison.location
    local distance = #(coords - prisonLocation)
    
    -- 使用配置文件中的检测半径
    return distance < Config.Prison.areaRadius
end

-- 统一的玩家监狱状态检查函数（增强版）
function CheckPlayerPrisonOnLogin(src, eventName)
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        DebugPrint('[' .. eventName .. '] 玩家对象获取失败: ' .. tostring(src))
        return 
    end
    
    local license = Player.PlayerData.license
    DebugPrint('[' .. eventName .. '] 玩家登录，检查监狱状态: ' .. license .. ' (ID: ' .. src .. ')')
    
    -- 自动执行监狱状态检查
    CreateThread(function()
        Wait(4000) -- 等待4秒确保完全就绪
        
        -- 确认玩家仍在线
        local CurrentPlayer = QBCore.Functions.GetPlayer(src)
        if not CurrentPlayer then
            DebugPrint('[' .. eventName .. '] 玩家已离线，跳过检查: ' .. license)
            return
        end
        
        -- 检查数据库是否就绪
        if not DatabaseReady then
            DebugPrint('[' .. eventName .. '] 数据库未就绪，跳过检查: ' .. license)
            return
        end
        
        DebugPrint('[' .. eventName .. '] 开始查询数据库: ' .. license)
        
        -- 查询所有相关记录（包括已过期的）
        local queryAll = string.format('SELECT * FROM `%s` WHERE license = ? AND isJailed = 1', Config.Database.tableName)
        
        local success, results = pcall(function()
            return exports.oxmysql:query_async(queryAll, {license})
        end)
        
        local shouldBeInPrison = false
        local prisonData = nil
        
        if success and results and #results > 0 then
            local row = results[1]
            if row.jail_time > 0 then
                -- 仍有刑期
                shouldBeInPrison = true
                prisonData = {
                    license = row.license,
                    jailTime = row.jail_time,
                    reason = row.reason,
                    source = src
                }
                DebugPrint('[' .. eventName .. '] 发现有效监狱记录: ' .. license .. ' 剩余 ' .. math.ceil(row.jail_time / 60) .. ' 分钟')
            else
                -- 刑期已满
                DebugPrint('[' .. eventName .. '] 发现已过期监狱记录: ' .. license .. ' 需要清理')
                -- 清理过期记录
                ReleasePlayerFromJail(license)
            end
        end
        
        -- 检查玩家当前位置
        local isInPrisonArea = IsPlayerInPrisonArea(src)
        
        if shouldBeInPrison then
            -- 应该在监狱中，确保source正确设置
            prisonData.source = src
            JailedPlayers[license] = prisonData
            AutoRestorePrisonState(src, license, prisonData)
            DebugPrint('[' .. eventName .. '] 玩家重新上线，恢复监狱计时: ' .. license)
        elseif isInPrisonArea then
            -- 不应该在监狱中，但当前在监狱区域 - 自动释放到释放点
            DebugPrint('[' .. eventName .. '] 玩家刑期已满但仍在监狱区域，自动传送到释放点: ' .. license)
            TriggerClientEvent('yx_prison:teleportToRelease', src)
            TriggerClientEvent('QBCore:Notify', src, '您已刑满释放', 'success')
        else
            -- 正常状态，无需处理
            DebugPrint('[' .. eventName .. '] 玩家状态正常: ' .. license)
        end
        
        -- 备用异步查询（如果同步查询失败）
        if not success then
            DebugPrint('[' .. eventName .. '] 同步查询失败，使用备用方法: ' .. license)
            
            exports.oxmysql:execute(queryAll, {license}, function(backupResults)
                if backupResults and #backupResults > 0 then
                    local row = backupResults[1]
                    if row.jail_time > 0 then
                        DebugPrint('[' .. eventName .. '-备用] 发现监狱记录: ' .. license .. ' 剩余 ' .. math.ceil(row.jail_time / 60) .. ' 分钟')
                        
                        local FinalPlayer = QBCore.Functions.GetPlayer(src)
                        if FinalPlayer then
                            JailedPlayers[license] = {
                                license = row.license,
                                jailTime = row.jail_time,
                                reason = row.reason,
                                source = src
                            }
                            AutoRestorePrisonState(src, license, JailedPlayers[license])
                        end
                    else
                        -- 检查是否在监狱区域但刑期已满
                        if IsPlayerInPrisonArea(src) then
                            DebugPrint('[' .. eventName .. '-备用] 玩家刑期已满但在监狱区域，传送到释放点: ' .. license)
                            TriggerClientEvent('yx_prison:teleportToRelease', src)
                            TriggerClientEvent('QBCore:Notify', src, '您已刑满释放', 'success')
                        end
                        ReleasePlayerFromJail(license)
                    end
                end
            end)
        end
    end)
end

-- 主要玩家登录事件 - QBCore (修正source问题)
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    DebugPrint('QBCore:Server:PlayerLoaded 事件触发: ' .. tostring(src))
    
    if src and src > 0 then
        CheckPlayerPrisonOnLogin(src, 'PlayerLoaded')
    else
        DebugPrint('QBCore:Server:PlayerLoaded source无效，跳过检查')
    end
end)

-- 多角色系统兼容 - 角色选择完成事件
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    DebugPrint('QBCore:Server:OnPlayerLoaded 事件触发: ' .. tostring(src))
    
    if src and src > 0 then
        CheckPlayerPrisonOnLogin(src, 'OnPlayerLoaded')
    end
end)

-- qb-multicharacter 兼容事件
RegisterNetEvent('qb-multicharacter:server:loadUserData', function()
    local src = source
    DebugPrint('qb-multicharacter:server:loadUserData 事件触发: ' .. tostring(src))
    
    if src and src > 0 then
        CreateThread(function()
            Wait(2000) -- 等待角色数据完全加载
            CheckPlayerPrisonOnLogin(src, 'MultiCharacter')
        end)
    end
end)

-- um-multicharacter 兼容事件 (根据你的日志判断)
RegisterNetEvent('um-multichara:server:playerLoaded', function()
    local src = source
    DebugPrint('um-multichara:server:playerLoaded 事件触发: ' .. tostring(src))
    
    if src and src > 0 then
        CreateThread(function()
            Wait(1000) -- 稍等数据加载
            CheckPlayerPrisonOnLogin(src, 'UMMultiChar')
        end)
    end
end)


-- 自动静默恢复监狱状态
function AutoRestorePrisonState(src, license, prisonData)
    prisonData.source = src
    
    local remainingMinutes = math.ceil(prisonData.jailTime / 60)
    if remainingMinutes > 0 then
        DebugPrint('[自动恢复] 传送玩家到监狱: ' .. license .. ' 剩余 ' .. remainingMinutes .. ' 分钟')
        
        -- 重新清空背包（防止玩家重新登录时绕过清空）
        if Config.Inventory.clearOnJail then
            ClearPlayerInventory(src)
        end
        
        -- 恢复路由桶（如果启用）
        if Config.RoutingBucket.enable then
            local bucketId = CreatePrisonRoutingBucket(license)
            if bucketId then
                AssignPlayerToRoutingBucket(src, bucketId)
                prisonData.bucketId = bucketId
            end
        end
        
        -- 直接传送到监狱，无延迟
        TriggerClientEvent('yx_prison:teleportToPrison', src)
        
        -- 只在调试模式下显示通知，否则静默处理
        if Config.Debug then
            TriggerClientEvent('QBCore:Notify', src, '监狱状态已恢复，剩余时间: ' .. remainingMinutes .. ' 分钟', 'error')
        end
    else
        -- 时间已到，自动释放
        if Config.RoutingBucket.enable then
            RemovePlayerFromRoutingBucket(src)
        end
        JailedPlayers[license] = nil
        ReleasePlayerFromJail(license)
        DebugPrint('[自动恢复] 玩家刑期已满，自动释放: ' .. license)
    end
end

-- 恢复玩家监狱状态的通用函数
function RestorePlayerPrisonState(src, license, prisonData)
    prisonData.source = src
    
    local remainingMinutes = math.ceil(prisonData.jailTime / 60)
    if remainingMinutes > 0 then
        DebugPrint('恢复监狱状态: ' .. license .. ' 剩余 ' .. remainingMinutes .. ' 分钟')
        
        -- 延迟传送，确保玩家完全加载
        CreateThread(function()
            Wait(1000)
            TriggerClientEvent('yx_prison:teleportToPrison', src)
            TriggerClientEvent('QBCore:Notify', src, '您仍在服刑中，剩余时间: ' .. remainingMinutes .. ' 分钟', 'error')
        end)
    else
        -- 时间已到，释放
        JailedPlayers[license] = nil
        ReleasePlayerFromJail(license)
        DebugPrint('玩家刑期已满，自动释放: ' .. license)
    end
end

-- 检查在线玩家的监狱状态（仅用于资源启动）
function CheckOnlinePlayersJailStatus()
    local players = QBCore.Functions.GetPlayers()
    DebugPrint('资源启动，检查 ' .. #players .. ' 名在线玩家的监狱状态')
    
    for _, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player then
            local license = Player.PlayerData.license
            
            if JailedPlayers[license] then
                DebugPrint('恢复在线监狱玩家: ' .. license .. ' (ID: ' .. playerId .. ')')
                RestorePlayerPrisonState(playerId, license, JailedPlayers[license])
            end
        end
    end
end

-- 玩家离线事件
AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player then
        local license = Player.PlayerData.license
        
        if JailedPlayers[license] then
            JailedPlayers[license].source = nil
            DebugPrint('监狱玩家离线: ' .. license)
        end
    end
end)

-- 获取剩余时间事件
RegisterNetEvent('yx_prison:getRemainingTime', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    local license = Player.PlayerData.license
    local remainingMinutes = GetPlayerJailTime(license)
    
    TriggerClientEvent('yx_prison:updateRemainingTime', src, remainingMinutes)
end)

-- ====================================
-- 在线玩家倒计时系统（只对在线玩家计算时间）
-- ====================================
CreateThread(function()
    while true do
        Wait(Config.Prison.countdownInterval)
        
        local toRelease = {}
        
        for license, data in pairs(JailedPlayers) do
            -- 只对在线玩家计算时间
            if data.source and QBCore.Functions.GetPlayer(data.source) then
                data.jailTime = data.jailTime - 1
                
                -- 检查自动复活
                CheckAutoRevive(data.source, license)
                
                if data.jailTime <= 0 then
                    -- 刑期已满
                    table.insert(toRelease, license)
                end
            else
                -- 玩家离线，时间暂停，更新离线状态
                if data.source then
                    DebugPrint('监狱玩家离线，时间暂停: ' .. license)
                    data.source = nil
                end
            end
        end
        
        -- 释放刑满玩家
        for _, license in ipairs(toRelease) do
            local data = JailedPlayers[license]
            JailedPlayers[license] = nil
            PlayerReviveTimes[license] = nil
            ReleasePlayerFromJail(license)
            
            if data.source then
                -- 获取玩家信息用于全局通知
                local Player = QBCore.Functions.GetPlayer(data.source)
                if Player then
                    local playerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
                    -- 发送全局通知
                    SendGlobalPrisonNotification(playerName, '', true)
                end
                
                -- 从路由桶移除（如果启用）
                if Config.RoutingBucket.enable then
                    RemovePlayerFromRoutingBucket(data.source)
                end
                
                TriggerClientEvent('yx_prison:teleportToRelease', data.source)
                TriggerClientEvent('yx_prison:stopMonitoring', data.source)
                TriggerClientEvent('QBCore:Notify', data.source, '刑期已满，您已被自动释放', 'success')
            end
            
            DebugPrint('刑期已满自动释放: ' .. license)
        end
    end
end)

-- ====================================
-- 数据库同步系统（只同步在线玩家数据）
-- ====================================
CreateThread(function()
    while true do
        Wait(Config.Prison.syncInterval)
        
        if DatabaseReady then
            local syncCount = 0
            local totalCount = 0
            
            for license, data in pairs(JailedPlayers) do
                totalCount = totalCount + 1
                
                -- 只同步在线玩家的数据
                if data.source and QBCore.Functions.GetPlayer(data.source) then
                    UpdatePlayerJailTime(license, data.jailTime)
                    syncCount = syncCount + 1
                end
            end
            
            if totalCount > 0 then
                DebugPrint('已同步 ' .. syncCount .. '/' .. totalCount .. ' 名在线监狱玩家的数据到数据库')
            end
        end
    end
end)

-- ====================================
-- 路由桶清理系统
-- ====================================
CreateThread(function()
    while true do
        Wait(Config.RoutingBucket.cleanInterval)
        CleanupIdleRoutingBuckets()
    end
end)

-- ====================================
-- 命令系统
-- ====================================
if Config.Debug then
    RegisterCommand('guanyaban', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        if not args[1] then
            TriggerClientEvent('QBCore:Notify', src, '使用方法: /guanyaban [玩家ID] [时间(分钟)] [原因]', 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        local jailTime = tonumber(args[2]) or Config.Prison.defaultTime
        local reason = table.concat(args, ' ', 3) or '违反服务器规则'
        
        if not targetId then
            TriggerClientEvent('QBCore:Notify', src, '无效的玩家ID', 'error')
            return
        end
        
        local success, message = JailPlayer(src, targetId, jailTime, reason)
        TriggerClientEvent('QBCore:Notify', src, message, success and 'success' or 'error')
    end, false)
    
    RegisterCommand('shijain', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        if not args[1] then
            TriggerClientEvent('QBCore:Notify', src, '使用方法: /shijain [玩家ID]', 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        if not targetId then
            TriggerClientEvent('QBCore:Notify', src, '无效的玩家ID', 'error')
            return
        end
        
        local success, message = ReleasePlayer(src, targetId)
        TriggerClientEvent('QBCore:Notify', src, message, success and 'success' or 'error')
    end, false)
    
    RegisterCommand('prisonlist', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        local count = 0
        for license, data in pairs(JailedPlayers) do
            count = count + 1
            local remainingMinutes = math.ceil(data.jailTime / 60)
            TriggerClientEvent('chatMessage', src, '^3[监狱列表]^7', '', '^5' .. license .. '^7 剩余: ^6' .. remainingMinutes .. '分钟^7')
        end
        
        if count == 0 then
            TriggerClientEvent('QBCore:Notify', src, '当前没有玩家在监狱中', 'primary')
        else
            TriggerClientEvent('QBCore:Notify', src, '监狱中共有 ' .. count .. ' 名玩家', 'primary')
        end
    end, false)
    
    RegisterCommand('prisonreload', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        TriggerClientEvent('QBCore:Notify', src, '正在重新加载监狱数据...', 'primary')
        DebugPrint('手动重新加载监狱数据库记录 - 执行人: ' .. Player.PlayerData.license)
        
        -- 清空当前内存数据
        local oldCount = 0
        for _ in pairs(JailedPlayers) do
            oldCount = oldCount + 1
        end
        JailedPlayers = {}
        
        -- 重新加载
        LoadJailedPlayersFromDatabase()
        
        -- 等待加载完成并显示结果
        CreateThread(function()
            Wait(3000) -- 减少等待时间
            local newCount = 0
            for _ in pairs(JailedPlayers) do
                newCount = newCount + 1
            end
            
            TriggerClientEvent('QBCore:Notify', src, '重载完成: ' .. oldCount .. ' -> ' .. newCount .. ' 名监狱玩家', 'success')
            DebugPrint('重载完成: 旧数据 ' .. oldCount .. ' 条, 新数据 ' .. newCount .. ' 条')
            
            -- 只在资源重载时检查在线玩家
            if newCount > 0 then
                DebugPrint('重载后检查在线玩家状态...')
                CheckOnlinePlayersJailStatus()
            end
        end)
    end, false)
    
    RegisterCommand('prisoncheck', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        if not args[1] then
            TriggerClientEvent('QBCore:Notify', src, '使用方法: /prisoncheck [玩家ID]', 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
        
        if not TargetPlayer then
            TriggerClientEvent('QBCore:Notify', src, '玩家不存在', 'error')
            return
        end
        
        local license = TargetPlayer.PlayerData.license
        local playerName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
        
        if JailedPlayers[license] then
            local remainingMinutes = math.ceil(JailedPlayers[license].jailTime / 60)
            TriggerClientEvent('QBCore:Notify', src, '玩家 ' .. playerName .. ' 在监狱中，剩余: ' .. remainingMinutes .. ' 分钟', 'primary')
            DebugPrint('检查结果: ' .. playerName .. ' (' .. license .. ') 在监狱中，剩余 ' .. remainingMinutes .. ' 分钟')
        else
            TriggerClientEvent('QBCore:Notify', src, '玩家 ' .. playerName .. ' 不在监狱中', 'primary')
            DebugPrint('检查结果: ' .. playerName .. ' (' .. license .. ') 不在监狱中')
        end
    end, false)
    
    RegisterCommand('prisoncheckme', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        local license = Player.PlayerData.license
        TriggerClientEvent('QBCore:Notify', src, '正在检查您的监狱状态...', 'primary')
        DebugPrint('玩家手动检查自己的监狱状态: ' .. license)
        
        CreateThread(function()
            if not DatabaseReady then
                TriggerClientEvent('QBCore:Notify', src, '数据库未就绪', 'error')
                return
            end
            
            local query = string.format('SELECT * FROM `%s` WHERE license = ? AND isJailed = 1 AND jail_time > 0', Config.Database.tableName)
            
            exports.oxmysql:execute(query, {license}, function(results)
                if results and #results > 0 then
                    local row = results[1]
                    local remainingMinutes = math.ceil(row.jail_time / 60)
                    
                    TriggerClientEvent('QBCore:Notify', src, '发现监狱记录，剩余: ' .. remainingMinutes .. ' 分钟，正在恢复状态...', 'error')
                    DebugPrint('[手动检查] 发现监狱记录: ' .. license .. ' 剩余 ' .. remainingMinutes .. ' 分钟')
                    
                    -- 添加到内存
                    JailedPlayers[license] = {
                        license = row.license,
                        jailTime = row.jail_time,
                        reason = row.reason,
                        source = src
                    }
                    
                    -- 使用自动恢复函数（静默处理）
                    AutoRestorePrisonState(src, license, JailedPlayers[license])
                else
                    TriggerClientEvent('QBCore:Notify', src, '您当前不在监狱中', 'success')
                    DebugPrint('[手动检查] 未找到监狱记录: ' .. license)
                end
            end)
        end)
    end, false)
    
    RegisterCommand('prisontestlogin', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        TriggerClientEvent('QBCore:Notify', src, '手动测试登录检查事件...', 'primary')
        DebugPrint('手动测试登录检查事件 - 玩家: ' .. Player.PlayerData.license)
        
        -- 手动触发所有登录检查
        CheckPlayerPrisonOnLogin(src, 'ManualTest')
    end, false)
    
    RegisterCommand('prisonstatus', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        local onlineCount = 0
        local offlineCount = 0
        
        for license, data in pairs(JailedPlayers) do
            if data.source and QBCore.Functions.GetPlayer(data.source) then
                onlineCount = onlineCount + 1
                local remainingMinutes = math.ceil(data.jailTime / 60)
                TriggerClientEvent('chatMessage', src, '^2[在线]^7', '', '^5' .. license .. '^7 剩余: ^6' .. remainingMinutes .. '分钟^7')
            else
                offlineCount = offlineCount + 1
                local remainingMinutes = math.ceil(data.jailTime / 60)
                TriggerClientEvent('chatMessage', src, '^1[离线]^7', '', '^5' .. license .. '^7 剩余: ^6' .. remainingMinutes .. '分钟^7 ^3(时间已暂停)^7')
            end
        end
        
        TriggerClientEvent('QBCore:Notify', src, '监狱状态: 在线 ' .. onlineCount .. ' 名, 离线 ' .. offlineCount .. ' 名', 'primary')
    end, false)
    
    RegisterCommand('routingbuckets', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        if not Config.RoutingBucket.enable then
            TriggerClientEvent('QBCore:Notify', src, '路由桶功能已禁用', 'error')
            return
        end
        
        local bucketCount = 0
        for bucketId, data in pairs(ActiveRoutingBuckets) do
            bucketCount = bucketCount + 1
            local age = os.time() - data.created
            TriggerClientEvent('chatMessage', src, '^4[路由桶]^7', '', '^5桶ID: ' .. bucketId .. '^7 玩家: ^6' .. data.license .. '^7 存活: ^3' .. age .. '秒^7')
        end
        
        if bucketCount == 0 then
            TriggerClientEvent('QBCore:Notify', src, '当前没有活跃的路由桶', 'primary')
        else
            TriggerClientEvent('QBCore:Notify', src, '活跃路由桶: ' .. bucketCount .. ' 个', 'primary')
        end
    end, false)
    
    RegisterCommand('clearinventory', function(source, args, rawCommand)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        
        if not Player then return end
        
        if not args[1] then
            TriggerClientEvent('QBCore:Notify', src, '使用方法: /clearinventory [玩家ID]', 'error')
            return
        end
        
        local targetId = tonumber(args[1])
        local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
        
        if not TargetPlayer then
            TriggerClientEvent('QBCore:Notify', src, '玩家不存在', 'error')
            return
        end
        
        local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
        local itemCount = GetPlayerItemCount(TargetPlayer)
        
        if ClearPlayerInventory(targetId) then
            TriggerClientEvent('QBCore:Notify', src, '成功清空玩家 ' .. targetName .. ' 的背包 (' .. itemCount .. ' 个物品)', 'success')
        else
            TriggerClientEvent('QBCore:Notify', src, '清空玩家背包失败', 'error')
        end
    end, false)
    
    DebugPrint('调试命令已注册: /guanyaban, /shijain, /prisonlist, /prisonreload, /prisoncheck, /prisoncheckme, /prisontestlogin, /prisonstatus, /routingbuckets, /clearinventory')
end

-- ====================================
-- 资源启动
-- ====================================
CreateThread(function()
    Wait(3000) -- 等待数据库和QBCore完全加载
    
    print('^2[yx_prison]^7 基于license的监狱系统启动中...')
    print('^3[yx_prison]^7 数据库: ' .. (Config.Database.enableDatabase and '^2启用^7' or '^1禁用^7'))
    print('^3[yx_prison]^7 调试模式: ' .. (Config.Debug and '^2启用^7' or '^1禁用^7'))
    print('^3[yx_prison]^7 多角色兼容: ^2启用^7 (支持 um-multichara, qb-multicharacter)')
    print('^3[yx_prison]^7 自动检测: ^2启用^7 (玩家登录时自动恢复监狱状态)')
    print('^3[yx_prison]^7 时间计算: ^2在线计时^7 (只有在线玩家的监狱时间才会流逝)')
    
    -- 等待数据库完全就绪
    local attempts = 0
    while not DatabaseReady and attempts < 10 do
        Wait(1000)
        attempts = attempts + 1
        DebugPrint('等待数据库就绪... 尝试 ' .. attempts .. '/10')
    end
    
    if DatabaseReady then
        DebugPrint('数据库已就绪，开始加载监狱数据')
        LoadJailedPlayersFromDatabase()
        
        -- 给数据加载充足的时间
        Wait(5000)
        
        local count = 0
        for _ in pairs(JailedPlayers) do
            count = count + 1
        end
        
        DebugPrint('监狱系统启动完成，当前内存中有 ' .. count .. ' 名监狱玩家')
        print('^2[yx_prison]^7 监狱系统启动完成 (监狱玩家: ' .. count .. ')')
        
        -- 检查在线玩家是否需要恢复监狱状态
        if count > 0 then
            DebugPrint('检查在线玩家的监狱状态...')
            CheckOnlinePlayersJailStatus()
        end
    else
        print('^1[yx_prison]^7 警告: 数据库未就绪，监狱数据可能无法正确加载')
    end
end)

-- ====================================
-- KOOK机器人调用事件
-- ====================================

-- KOOK关押玩家事件
RegisterNetEvent('yx_prison:kook_jail_player', function(targetId, jailTime, reason, source)
    local kookSource = source or 0
    
    -- 安全验证
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_jail_player')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    -- 验证参数
    if not targetId or not tonumber(targetId) then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '无效的玩家ID'
        })
        return
    end
    
    local jailTimeMinutes = tonumber(jailTime) or Config.Prison.defaultTime
    local jailReason = reason or '违反服务器规则'
    
    -- 执行关押
    local success, message = JailPlayer(kookSource, targetId, jailTimeMinutes, jailReason)
    
    -- 获取玩家信息
    local playerInfo = ''
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if TargetPlayer then
        playerInfo = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    end
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, {
        success = success,
        message = message,
        playerInfo = playerInfo,
        jailTime = jailTimeMinutes,
        reason = jailReason,
        playerId = targetId
    })
end)

-- KOOK释放玩家事件
RegisterNetEvent('yx_prison:kook_release_player', function(targetId, source)
    local kookSource = source or 0
    
    -- 安全验证
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_release_player')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    -- 验证参数
    if not targetId or not tonumber(targetId) then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '无效的玩家ID'
        })
        return
    end
    
    -- 获取玩家信息
    local playerInfo = ''
    local remainingTime = 0
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if TargetPlayer then
        playerInfo = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
        local license = TargetPlayer.PlayerData.license
        if JailedPlayers[license] then
            remainingTime = math.ceil(JailedPlayers[license].jailTime / 60)
        end
    end
    
    -- 执行释放
    local success, message = ReleasePlayer(kookSource, targetId)
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, {
        success = success,
        message = message,
        playerInfo = playerInfo,
        remainingTime = remainingTime,
        playerId = targetId
    })
end)

-- KOOK获取监狱列表事件
RegisterNetEvent('yx_prison:kook_get_jail_list', function(source)
    local kookSource = source or 0
    
    -- 安全验证（查询类事件）
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_get_jail_list')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    local jailedList = {}
    local onlineCount = 0
    local offlineCount = 0
    
    for license, data in pairs(JailedPlayers) do
        local playerInfo = {
            license = license,
            remainingTime = math.ceil(data.jailTime / 60),
            reason = data.reason or '未知',
            isOnline = false,
            playerName = '未知玩家',
            playerId = 'N/A'
        }
        
        -- 检查玩家是否在线
        if data.source then
            local player = QBCore.Functions.GetPlayer(data.source)
            if player then
                playerInfo.isOnline = true
                playerInfo.playerName = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
                playerInfo.playerId = tostring(player.PlayerData.source)
                onlineCount = onlineCount + 1
            end
        end
        
        if not playerInfo.isOnline then
            offlineCount = offlineCount + 1
        end
        
        table.insert(jailedList, playerInfo)
    end
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, {
        success = true,
        jailedList = jailedList,
        totalCount = #jailedList,
        onlineCount = onlineCount,
        offlineCount = offlineCount
    })
end)

-- KOOK查询玩家监狱状态事件
RegisterNetEvent('yx_prison:kook_get_player_status', function(targetId, source)
    local kookSource = source or 0
    
    -- 安全验证（查询类事件）
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_get_player_status')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    -- 验证参数
    if not targetId or not tonumber(targetId) then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '无效的玩家ID'
        })
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '找不到指定玩家'
        })
        return
    end
    
    local license = TargetPlayer.PlayerData.license
    local playerInfo = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    
    local statusInfo = {
        success = true,
        playerInfo = playerInfo,
        playerId = targetId,
        isJailed = false
    }
    
    -- 检查监狱状态
    if JailedPlayers[license] then
        local prisonData = JailedPlayers[license]
        statusInfo.isJailed = true
        statusInfo.remainingTime = math.ceil(prisonData.jailTime / 60)
        statusInfo.reason = prisonData.reason or '未知'
        statusInfo.isOnline = prisonData.source ~= nil
        statusInfo.bucketId = prisonData.bucketId
        statusInfo.routingBucketEnabled = Config.RoutingBucket.enable
        statusInfo.inventoryCleared = Config.Inventory.clearOnJail
    end
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, statusInfo)
end)

-- KOOK清空背包事件
RegisterNetEvent('yx_prison:kook_clear_inventory', function(targetId, source)
    local kookSource = source or 0
    
    -- 安全验证
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_clear_inventory')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    -- 检查功能是否启用
    if not Config.Inventory.clearOnJail then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '背包清空功能已禁用'
        })
        return
    end
    
    -- 验证参数
    if not targetId or not tonumber(targetId) then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '无效的玩家ID'
        })
        return
    end
    
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    if not TargetPlayer then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '找不到指定玩家'
        })
        return
    end
    
    local playerInfo = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
    local itemCount = GetPlayerItemCount(TargetPlayer)
    
    -- 执行清空
    local success = ClearPlayerInventory(targetId)
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, {
        success = success,
        message = success and '背包清空成功' or '背包清空失败',
        playerInfo = playerInfo,
        itemCount = itemCount,
        clearMethod = Config.Inventory.clearMethod,
        playerId = targetId
    })
end)

-- KOOK获取路由桶状态事件
RegisterNetEvent('yx_prison:kook_get_routing_bucket_status', function(source)
    local kookSource = source or 0
    
    -- 安全验证（查询类事件）
    local isValid, securityMessage = ValidateKookEventSecurity(kookSource, 'kook_get_routing_bucket_status')
    if not isValid then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = securityMessage
        })
        return
    end
    
    if not Config.RoutingBucket.enable then
        TriggerEvent('yx_prison:kook_response', kookSource, {
            success = false,
            message = '路由桶功能已禁用'
        })
        return
    end
    
    local bucketList = {}
    for bucketId, data in pairs(ActiveRoutingBuckets) do
        table.insert(bucketList, {
            bucketId = bucketId,
            license = data.license,
            age = os.time() - data.created,
            lastUsed = os.time() - data.lastUsed
        })
    end
    
    -- 返回结果
    TriggerEvent('yx_prison:kook_response', kookSource, {
        success = true,
        bucketList = bucketList,
        totalBuckets = #bucketList
    })
end)

DebugPrint('KOOK事件接口已注册完成')