--[[
    yx_notification - 现代极简通知系统
    作者：于晓
    版本：1.0.0
    描述：完全替代 QBCore 默认通知，现代极简黑白灰设计
]]

fx_version 'cerulean'
game 'gta5'

author '于晓'
description '现代极简通知系统 - 替代QBCore默认通知'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

lua54 'yes'

