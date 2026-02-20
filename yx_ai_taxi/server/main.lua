--[[
    ====================================
    AI 出租车系统 - 服务端主逻辑
    作者：于晓
    描述：处理车辆钥匙分配、车费扣除等服务端逻辑
    ====================================
]]--

-- 获取 QBCore 对象（服务端直接使用 exports）
local QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- 调试打印函数
-- ============================================
local function DebugPrint(msg)
    if Config and Config.Debug then
        print('^3[YX_AI_TAXI]^0 ' .. msg)
    end
end

-- ============================================
-- 给玩家出租车钥匙
-- ============================================
--[[
    接收客户端请求，给玩家分配出租车钥匙
    @param plate string 车牌号
    @description 使用 jaksam vehicles_keys 脚本的 export
]]--
RegisterNetEvent('yx_ai_taxi:giveKeys', function(plate)
    local source = source
    
    -- 检查是否启用钥匙脚本
    if not Config.VehicleKeys.enabled then
        DebugPrint('钥匙脚本集成已禁用')
        return
    end
    
    local script_name = Config.VehicleKeys.script_name
    
    -- 检查钥匙脚本是否已启动
    if GetResourceState(script_name) ~= 'started' then
        DebugPrint('钥匙脚本 ' .. script_name .. ' 未启动')
        return
    end
    
    -- 调用 vehicles_keys 的 export 给玩家钥匙
    -- 参考: https://documentation.jaksam-scripts.com/vehicles-keys/server/give-keys-to-player-id
    local success, err = pcall(function()
        exports[script_name]:giveVehicleKeysToPlayerId(
            source,                         -- 玩家服务端ID
            plate,                          -- 车牌号
            Config.VehicleKeys.key_type     -- 钥匙类型
        )
    end)
    
    if success then
        DebugPrint('已给玩家 ' .. tostring(source) .. ' 分配出租车钥匙，车牌: ' .. plate)
    else
        DebugPrint('给玩家钥匙失败: ' .. tostring(err))
    end
end)

-- ============================================
-- 扣除玩家车费（QBCore）
-- ============================================
--[[
    接收客户端请求，扣除玩家车费
    @param amount number 金额
    @description 使用 QBCore 框架扣除玩家余额（优先现金，不足则银行，支持组合扣款）
]]--
RegisterNetEvent('yx_ai_taxi:deductMoney', function(amount)
    local src = source
    
    print('^3[YX_AI_TAXI]^0 收到扣款请求，玩家: ' .. src .. ', 金额: $' .. tostring(amount))
    
    -- 参数验证
    if not amount or amount <= 0 then
        print('^1[YX_AI_TAXI]^0 无效的扣款金额: ' .. tostring(amount))
        return
    end
    
    -- 获取玩家对象
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then
        print('^1[YX_AI_TAXI]^0 无法获取玩家数据，玩家ID: ' .. tostring(src))
        return
    end
    
    local cash = Player.PlayerData.money.cash or 0
    local bank = Player.PlayerData.money.bank or 0
    local remaining = math.floor(amount)  -- 确保是整数
    
    print(string.format('^3[YX_AI_TAXI]^0 玩家 %d 余额 - 现金: $%d, 银行: $%d, 车费: $%d', src, cash, bank, remaining))
    
    -- 优先从现金扣除
    if cash > 0 and remaining > 0 then
        local deduct_cash = math.min(cash, remaining)
        Player.Functions.RemoveMoney('cash', deduct_cash, 'taxi-fare')
        remaining = remaining - deduct_cash
        print(string.format('^2[YX_AI_TAXI]^0 从现金扣除 $%d', deduct_cash))
    end
    
    -- 如果现金不够，从银行扣除剩余部分
    if remaining > 0 then
        Player.Functions.RemoveMoney('bank', remaining, 'taxi-fare')
        print(string.format('^2[YX_AI_TAXI]^0 从银行扣除 $%d', remaining))
    end
    
    print(string.format('^2[YX_AI_TAXI]^0 玩家 %d 成功支付车费 $%d', src, math.floor(amount)))
end)

-- ============================================
-- 初始化日志
-- ============================================
Citizen.CreateThread(function()
    DebugPrint('[服务端] AI出租车系统已加载')
    
    -- 检查钥匙脚本状态
    if Config.VehicleKeys.enabled then
        local script_name = Config.VehicleKeys.script_name
        if GetResourceState(script_name) == 'started' then
            DebugPrint('[服务端] 钥匙脚本 ' .. script_name .. ' 已检测到')
        else
            DebugPrint('[服务端] 警告: 钥匙脚本 ' .. script_name .. ' 未启动')
        end
    end
    
    -- 检查QBCore状态
    if GetResourceState('qb-core') == 'started' then
        DebugPrint('[服务端] QBCore 已检测到，计费系统已启用')
    else
        DebugPrint('[服务端] 警告: QBCore 未启动，计费系统不可用')
    end
end)

