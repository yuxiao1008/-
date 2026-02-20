fx_version 'cerulean'
game 'gta5'

author 'YX'
description '紧急职业车载电台系统'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qb-core',
    'pma-voice'
}

lua54 'yes' 