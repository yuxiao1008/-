--[[
    yx_smallresources - 杂项小功能集合
    作者: YX
    版本: 1.0.0
    描述: 整合多个小功能的FiveM脚本资源
]]

fx_version 'cerulean'
game 'gta5'

name 'yx_smallresources'
author '于晓'
description '杂项小功能集合'
version '1.0.0'

-- 全局共享配置
shared_scripts {
    'config/config.lua',
}

-- ================================
-- 模块: 温馨提示系统 (Tips)
-- ================================
server_scripts {
    'modules/tips/config.lua',
    'modules/tips/tips_data.lua',
    'modules/tips/server.lua',
}

-- ================================
-- 未来模块可在此处添加
-- 示例:
-- 'modules/新模块名/config.lua',
-- 'modules/新模块名/server.lua',
-- 'modules/新模块名/client.lua',
-- ================================

