--[[
    服务端脚本: server/main.lua
    功能说明:
      1. 管理员权限校验（ace 权限系统）
      2. 玩家连接时同步管理员状态到客户端
      3. 接收投掷请求，校验后回调客户端执行生成
      4. 管理活跃钱袋，处理领取请求并广播同步
    作者: 于晓
]]

-- ============================================
-- 本地变量（避免全局污染）
-- ============================================
local QBCore = exports['qb-core']:GetCoreObject()
local player_cooldowns = {} -- 玩家冷却记录表，防止客户端绕过冷却
local active_bags = {}      -- 活跃钱袋追踪表 { [net_id] = { owner_src, claimed } }
local claimed_history = {}  -- 已领取红包历史记录 { [net_id] = true }

-- ============================================
-- 工具函数：检查玩家是否拥有管理员权限
-- ============================================

--- 通过 ace 权限系统检查玩家是否拥有操作权限
--- @param player_id number 玩家服务端ID
--- @return boolean
local function is_player_admin(player_id)
    if not Config.RequireAdmin then
        return true
    end
    return IsPlayerAceAllowed(player_id, Config.AdminPermission)
end

--- 根据 Config.Rewards 概率表随机计算奖励金额
--- @return number 奖励金额
local function roll_reward()
    local roll = math.random(1, 100)
    local cumulative = 0
    for _, reward in ipairs(Config.Rewards) do
        cumulative = cumulative + reward.chance
        if roll <= cumulative then
            return reward.amount
        end
    end
    -- 兜底：返回最后一项（概率表配置异常时）
    return Config.Rewards[#Config.Rewards].amount
end

-- ============================================
-- 管理员状态同步：客户端请求时返回权限结果
-- ============================================
RegisterNetEvent('redpacket:checkAdmin')
AddEventHandler('redpacket:checkAdmin', function()
    local src = source
    local admin_status = is_player_admin(src)
    DebugPrint('玩家 ' .. tostring(src) .. ' 管理员状态查询: ' .. tostring(admin_status))
    TriggerClientEvent('redpacket:setAdmin', src, admin_status)
end)

-- ============================================
-- 玩家加入时自动同步管理员状态
-- ============================================
AddEventHandler('playerConnecting', function(_, _, deferrals)
    -- playerConnecting 阶段无法可靠获取 ace，改用 playerJoining
end)

RegisterNetEvent('onPlayerJoining')
AddEventHandler('onPlayerJoining', function()
    local src = source
    Citizen.SetTimeout(2000, function()
        local admin_status = is_player_admin(src)
        TriggerClientEvent('redpacket:setAdmin', src, admin_status)
        DebugPrint('玩家 ' .. tostring(src) .. ' 加入游戏，同步管理员状态: ' .. tostring(admin_status))

        -- 同步当前所有活跃钱袋给新加入的玩家
        for net_id, _ in pairs(active_bags) do
            TriggerClientEvent('redpacket:trackBag', src, net_id)
        end
    end)
end)

-- ============================================
-- 事件处理：接收投掷请求
-- ============================================
RegisterNetEvent('redpacket:requestSpawn')
AddEventHandler('redpacket:requestSpawn', function(heading)
    local src = source

    if not is_player_admin(src) then
        DebugPrint('玩家 ' .. tostring(src) .. ' 无管理员权限，拒绝投掷请求')
        return
    end

    if type(heading) ~= 'number' then
        DebugPrint('玩家 ' .. tostring(src) .. ' 发送了无效的朝向数据')
        return
    end

    local current_time = GetGameTimer()
    if player_cooldowns[src] and (current_time - player_cooldowns[src]) < Config.CooldownTime then
        DebugPrint('玩家 ' .. tostring(src) .. ' 服务端冷却中，拒绝请求')
        return
    end
    player_cooldowns[src] = current_time

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then
        DebugPrint('无法获取玩家 ' .. tostring(src) .. ' 的Ped')
        return
    end

    local coords = GetEntityCoords(ped)
    if not coords then
        DebugPrint('无法获取玩家 ' .. tostring(src) .. ' 的坐标')
        return
    end

    DebugPrint(string.format(
        '玩家 %d 请求投掷红包 | 坐标: %.2f, %.2f, %.2f | 朝向: %.2f',
        src, coords.x, coords.y, coords.z, heading
    ))

    TriggerClientEvent('redpacket:doSpawn', src, coords, heading)
end)

-- ============================================
-- 钱袋注册：生成者客户端通知服务端新钱袋
-- ============================================
RegisterNetEvent('redpacket:bagSpawned')
AddEventHandler('redpacket:bagSpawned', function(net_id)
    local src = source

    if type(net_id) ~= 'number' then
        DebugPrint('玩家 ' .. tostring(src) .. ' 发送了无效的 net_id')
        return
    end

    -- 注册到活跃钱袋表
    active_bags[net_id] = {
        owner_src = src,
        claimed = false,
    }

    -- 广播给所有客户端追踪此钱袋（生成者客户端会自动忽略已存在的）
    TriggerClientEvent('redpacket:trackBag', -1, net_id)

    DebugPrint('新钱袋已注册 net_id: ' .. tostring(net_id) .. ' | 投放者: ' .. tostring(src))
end)

-- ============================================
-- 领取处理：校验 → 发奖 → 通知 → 广播删除
-- ============================================
RegisterNetEvent('redpacket:claim')
AddEventHandler('redpacket:claim', function(net_id)
    local src = source

    -- 1. 参数校验
    if type(net_id) ~= 'number' then
        DebugPrint('玩家 ' .. tostring(src) .. ' 发送了无效的领取 net_id')
        return
    end

    -- 2. 检查是否在已领取历史中（双重防护）
    if claimed_history[net_id] then
        DebugPrint('领取请求重复（历史记录）：net_id ' .. tostring(net_id))
        return
    end

    -- 3. 检查活跃钱袋表
    local bag = active_bags[net_id]
    if not bag then
        DebugPrint('领取请求无效：net_id ' .. tostring(net_id) .. ' 不存在')
        return
    end

    if bag.claimed then
        DebugPrint('领取请求重复：net_id ' .. tostring(net_id) .. ' 已被领取')
        return
    end

    -- 4. 标记为已领取（立即锁定，防止并发）
    bag.claimed = true
    claimed_history[net_id] = true

    -- 5. 概率计算奖励金额
    local reward_amount = roll_reward()

    -- 6. 通过 QBCore 发放现金
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.AddMoney(Config.MoneyType, reward_amount, 'redpacket-chunjie')
        DebugPrint(string.format('玩家 %d 领取红包成功 | 奖励: $%d | net_id: %d', src, reward_amount, net_id))
    else
        DebugPrint('玩家 ' .. tostring(src) .. ' QBCore Player 对象获取失败，奖励未发放')
    end

    -- 7. 向领取者发送 QBCore 原生通知
    TriggerClientEvent('QBCore:Notify', src, Config.ClaimNotify .. ' 获得 $' .. reward_amount .. ' 现金！', 'success')

    -- 8. 广播给所有客户端彻底删除该物体
    TriggerClientEvent('redpacket:removeBag', -1, net_id)

    -- 9. 从活跃表中移除
    active_bags[net_id] = nil
end)

-- ============================================
-- 钱袋过期：生成者客户端通知服务端超时清理
-- ============================================
RegisterNetEvent('redpacket:bagExpired')
AddEventHandler('redpacket:bagExpired', function(net_id)
    local src = source

    if type(net_id) ~= 'number' then return end

    if active_bags[net_id] then
        active_bags[net_id] = nil
        -- 广播给所有客户端移除
        TriggerClientEvent('redpacket:removeBag', -1, net_id)
        DebugPrint('钱袋过期清理 net_id: ' .. tostring(net_id))
    end
end)

-- ============================================
-- 玩家断开连接时清理冷却记录
-- ============================================
AddEventHandler('playerDropped', function()
    local src = source
    if player_cooldowns[src] then
        player_cooldowns[src] = nil
        DebugPrint('清理玩家 ' .. tostring(src) .. ' 的冷却记录')
    end
end)
