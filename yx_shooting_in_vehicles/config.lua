Config = {}

-- 基础配置
Config.Debug = true -- 调试模式
Config.Framework = 'qb-core' -- 框架类型

-- 速度配置 (英里/小时)
Config.SpeedThreshold = 30.0 -- 开始影响精度的最低速度 
Config.MaxSpeedForCalculation = 120.0 -- 最大计算速度

-- 精度影响配置
Config.AccuracySettings = {
    minAccuracyLoss = 0.15, -- 最小精度损失 (15%)
    maxAccuracyLoss = 0.65, -- 最大精度损失 (65%)
    smoothingFactor = 0.85, -- 平滑系数，避免突然变化
    updateInterval = 100, -- 更新间隔 (毫秒)
}

-- 武器类别配置
Config.WeaponCategories = {
    -- 手枪类 - 受影响较小
    ['pistols'] = {
        accuracyMultiplier = 0.7,
        weapons = {
            'WEAPON_PISTOL',
            'WEAPON_PISTOL_MK2', 
            'WEAPON_COMBATPISTOL',
            'WEAPON_PISTOL50',
            'WEAPON_SNSPISTOL',
            'WEAPON_HEAVYPISTOL',
            'WEAPON_VINTAGEPISTOL',
            'WEAPON_MARKSMANPISTOL',
            'WEAPON_REVOLVER',
            'WEAPON_REVOLVER_MK2',
            'WEAPON_DOUBLEACTION'
        }
    },
    
    -- 冲锋枪类 - 中等影响
    ['smgs'] = {
        accuracyMultiplier = 1.0,
        weapons = {
            'WEAPON_MICROSMG',
            'WEAPON_SMG',
            'WEAPON_SMG_MK2',
            'WEAPON_ASSAULTSMG',
            'WEAPON_COMBATPDW',
            'WEAPON_MACHINEPISTOL',
            'WEAPON_MINISMG'
        }
    },
    
    -- 突击步枪类 - 高影响
    ['rifles'] = {
        accuracyMultiplier = 1.3,
        weapons = {
            'WEAPON_ASSAULTRIFLE',
            'WEAPON_ASSAULTRIFLE_MK2',
            'WEAPON_CARBINERIFLE',
            'WEAPON_CARBINERIFLE_MK2',
            'WEAPON_ADVANCEDRIFLE',
            'WEAPON_SPECIALCARBINE',
            'WEAPON_SPECIALCARBINE_MK2',
            'WEAPON_BULLPUPRIFLE',
            'WEAPON_BULLPUPRIFLE_MK2',
            'WEAPON_COMPACTRIFLE'
        }
    },
    
    -- 狙击步枪类 - 最高影响
    ['snipers'] = {
        accuracyMultiplier = 1.5,
        weapons = {
            'WEAPON_SNIPERRIFLE',
            'WEAPON_HEAVYSNIPER',
            'WEAPON_HEAVYSNIPER_MK2',
            'WEAPON_MARKSMANRIFLE',
            'WEAPON_MARKSMANRIFLE_MK2'
        }
    },
    
    -- 轻机枪类 - 高影响
    ['lmgs'] = {
        accuracyMultiplier = 1.4,
        weapons = {
            'WEAPON_MG',
            'WEAPON_COMBATMG',
            'WEAPON_COMBATMG_MK2',
            'WEAPON_GUSENBERG'
        }
    }
}

-- 车辆类型影响 (不同车辆类型的颠簸程度不同)
Config.VehicleTypeModifiers = {
    [0] = 1.0,  -- 压缩类
    [1] = 1.1,  -- 轿车类
    [2] = 1.2,  -- SUV类
    [3] = 1.3,  -- 越野车类
    [4] = 1.4,  -- 跑车类
    [5] = 1.0,  -- 超跑类
    [6] = 1.5,  -- 摩托车类
    [7] = 1.2,  -- 工程车类
    [8] = 1.6,  -- 飞机类
    [9] = 1.0,  -- 直升机类
    [10] = 1.8, -- 自行车类
    [11] = 1.7, -- 船类
    [12] = 1.0, -- 火车类
    [13] = 1.0, -- 拖车类
}

-- 通知设置
Config.Notifications = {
    enabled = true, -- 是否启用通知
    showAccuracyChanges = false, -- 是否显示精度变化通知
    notificationType = 'qb-core' -- 通知类型: 'qb-core', 'ox_lib', 'custom'
} 