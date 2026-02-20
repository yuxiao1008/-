fx_version 'cerulean'
game 'gta5'

author '于晓'
description 'QBCore Hunting System'
version '1.0.2'

escrow_ignore {
    'config.lua',
    'locales.lua',
    'yx_hunter_item.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales.lua'
}

client_scripts {
    'client/main.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua', 
    'server/main.lua'
}
lua54 'yes'

dependency '/assetpacks'