--[[
    资源名称: yx_chunjie
    功能说明: 直升机空投红包（钱袋）系统 - 管理员专用
    作者: 于晓
    版本: 1.3.0
]]

fx_version 'cerulean'
game 'gta5'

author '于晓'
description '直升机空投红包系统 - buzzard2投掷钱袋，碰撞领取随机现金奖励'
version '1.3.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
