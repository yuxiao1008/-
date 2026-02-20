shared_script '@jg-meac/shared_fg-obfuscated.lua'
fx_version 'cerulean'
game 'gta5'

author '于晓'
description '道路封控脚本'
version '1.1.2'

dependencies {
    'qb-core',
    'ox_lib'
}

-- 保留 config.lua 开源
escrow_ignore {
    'config.lua'
}

shared_scripts {
    '@ox_lib/init.lua',
	'@prism_uipack/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

lua54 'yes'
