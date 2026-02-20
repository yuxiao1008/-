fx_version 'cerulean'
game 'gta5'

author 'YX Team'
description 'QB框架监狱系统 - 支持管理员关押玩家到指定监狱位置'
version '1.0.0'

-- 依赖资源
dependencies {
    'qb-core',
    'oxmysql'
}

-- 共享文件
shared_scripts {
    'config.lua',
    'locales.lua'
}

-- 客户端文件
client_scripts {
    'client.lua'
}

-- 服务端文件
server_scripts {
    'server.lua'
}

-- Lua 版本
lua54 'yes'