fx_version 'cerulean'
game 'gta5'

description 'YX Hide Item System - 物品藏匿系统'
author 'YX Development'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}

lua54 'yes'