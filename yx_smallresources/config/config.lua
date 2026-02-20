--[[
    全局配置文件
    此文件包含所有模块共享的配置项
]]

Config = Config or {}

-- 全局Debug开关 (影响所有模块)
Config.Debug = true

-- 模块开关 (控制各功能是否启用)
Config.Modules = {
    Tips = true,  -- 温馨提示功能
    -- 未来模块可在此添加
}

-- ================================
-- 通用工具函数
-- ================================

--- 调试输出函数
--- 仅在 Config.Debug = true 时输出日志
--- @param prefix string 模块前缀标识
--- @param msg string 要输出的消息
function DebugPrint(prefix, msg)
    if Config.Debug then
        print(string.format('[%s] %s', prefix, msg))
    end
end

