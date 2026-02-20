fx_version 'cerulean'
game 'gta5'

name 'yx_job'
description 'QB框架就业系统 - 支持ox-target和ox-lib菜单'
author 'YX开发'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

dependencies {
    'qb-core',
    'ox_target',
    'ox_lib'
}

lua54 'yes'