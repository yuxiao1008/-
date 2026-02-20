--[[
    温馨提示模块 - 服务端逻辑
    功能: 定时向全体玩家发送随机游戏提示
    作者: 于晓
]]

local MODULE_NAME = 'Tips'

-- 检查模块是否启用
if not Config.Modules.Tips then
    print('[yx_smallresources] 温馨提示模块已禁用')
    return
end

local Tips = {}

--- 向全体玩家发送提示消息
--- @param tipText string 提示文本内容
function Tips.BroadcastTip(tipText)
    -- 构建消息 (全部绿色)
    local formattedMessage = string.format("%s %s", TipsConfig.Prefix, tipText)
    
    -- 使用 chatMessage 事件发送给所有玩家
    -- -1 表示广播给所有客户端
    -- author 设为空字符串 "" 则不显示 "xxx says:"
    -- 使用 TipsConfig.Colors.Prefix 作为整体消息颜色
    TriggerClientEvent('chatMessage', -1, "", TipsConfig.Colors.Prefix, formattedMessage)
    
    -- Debug日志
    DebugPrint(MODULE_NAME, '已发送提示: ' .. tipText)
end

--- 发送随机提示
function Tips.SendRandomTip()
    local tip = TipsData.GetRandomTip()
    Tips.BroadcastTip(tip)
end

-- 定时器线程
Citizen.CreateThread(function()
    -- 等待资源完全加载
    Citizen.Wait(5000)
    
    -- 模块启动信息 (始终显示)
    print(string.format(
        '[yx_smallresources] 温馨提示模块已启动 | 提示数量: %d | 间隔: %d秒',
        TipsData.GetTotalCount(),
        TipsConfig.Interval / 1000
    ))
    
    -- 主循环
    while true do
        -- 等待设定的间隔时间
        Citizen.Wait(TipsConfig.Interval)
        
        -- 检查是否有玩家在线
        local playerCount = GetNumPlayerIndices()
        if playerCount > 0 then
            Tips.SendRandomTip()
        end
    end
end)

-- Debug命令: 立即触发一条随机提示
if Config.Debug then
    RegisterCommand(TipsConfig.DebugCommand, function(source, args, rawCommand)
        -- source 为 0 表示控制台调用
        if source == 0 then
            DebugPrint(MODULE_NAME, '控制台触发测试提示')
            Tips.SendRandomTip()
        else
            -- 玩家调用
            DebugPrint(MODULE_NAME, '玩家 ' .. GetPlayerName(source) .. ' 触发测试提示')
            Tips.SendRandomTip()
        end
    end, false) -- false 表示任何人都可以使用(仅Debug模式下注册)
    
    DebugPrint(MODULE_NAME, 'Debug模式已启用，可使用 /' .. TipsConfig.DebugCommand .. ' 命令测试')
end

-- 资源停止时的清理
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then
        return
    end
    print('[yx_smallresources] 温馨提示模块已停止')
end)

