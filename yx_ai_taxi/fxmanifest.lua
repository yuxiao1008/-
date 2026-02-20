--[[
    ====================================
    AI 出租车系统 - FiveM 资源
    作者：于晓
    版本：2.0.0
    描述：智能AI出租车召唤与驾驶系统
    ====================================
]]--

fx_version 'cerulean'
game 'gta5'

name 'yx_ai_taxi'
author '于晓'
description 'AI出租车系统 - 智能召唤、驾驶与计费'
version '2.0.0'

-- 共享脚本（客户端和服务端都能访问）
shared_scripts {
    'config.lua',
    'shared/utils.lua'
}

-- 客户端脚本
client_scripts {
    'client/main.lua'
}

-- 服务端脚本
server_scripts {
    'server/main.lua'
}

lua54 'yes'

