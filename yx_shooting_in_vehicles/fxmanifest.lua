fx_version 'cerulean'
game 'gta5'

author '于晓'
description '车辆射击精度系统'
version '1.0.0'

-- QB-Core依赖
dependency 'qb-core'

-- 客户端脚本
client_scripts {
    'client/main.lua',
    'client/shooting.lua'
}

-- 服务端脚本  
server_scripts {
    'server/main.lua'
}

-- 共享配置
shared_scripts {
    'config.lua'
}

-- 导出函数
exports {
    'IsVehicleSpeedAffectingAccuracy',
    'GetCurrentAccuracyModifier'
} 