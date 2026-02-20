-- 佩里科岛搜索物资脚本
-- 作者: 于晓
-- 版本: 2.0.0

fx_version 'cerulean'
game 'gta5'

description '佩里科岛搜索物资系统'
version '2.0.1'
author '于晓'

lua54 'yes'

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/registration.lua',
    'client/airdrop.lua',
    'client/evacuation.lua',
    'client/death.lua',
    'client/resources.lua',
    'client/weapon_boxes.lua'
}

server_scripts {
    '@qb-core/shared/locale.lua',
    'server/main.lua',
    'server/inventory.lua',
    'server/weapon_boxes.lua',
    'server/activity.lua',
    'server/commands.lua',
    'server/death.lua',
    'server/resources.lua'
}
