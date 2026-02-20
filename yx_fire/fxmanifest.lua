fx_version 'cerulean'
game 'gta5'

author 'Yx'
description 'QB点火脚本 - 配合z_fires使用'
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
    'z_fire'
}

lua54 'yes' 