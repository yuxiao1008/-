--[[
    温馨提示模块 - 配置文件
    模块功能: 定时向全体玩家发送随机游戏提示
]]

TipsConfig = TipsConfig or {}

-- 提示间隔时间 (单位: 毫秒)
-- 默认: 30分钟 = 1800000毫秒
TipsConfig.Interval = 1800000

-- 提示前缀 (显示为绿色)
TipsConfig.Prefix = "你知道吗？"

-- 消息发送者名称
TipsConfig.Author = "系统"

-- 颜色配置 (RGB)
TipsConfig.Colors = {
    -- 前缀颜色 (绿色)
    Prefix = {0, 255, 0},
    -- 正文颜色 (白色)
    Text = {255, 255, 255},
}

-- Debug命令名称 (仅在Debug模式下可用)
TipsConfig.DebugCommand = "testtip"

