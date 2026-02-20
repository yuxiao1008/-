--[[
    yx_notification 配置文件
    所有可调整参数均在此文件中设置
]]

Config = {}

-- 调试模式：true 时在控制台输出详细日志
Config.Debug = true

-- 通知默认显示时长（毫秒）
Config.DefaultDuration = 5000

-- 通知最大堆叠数量（超过时自动移除最早的通知）
Config.MaxNotifications = 5

-- 通知类型对应的图标和颜色配置
-- icon: Font Awesome 图标类名
-- color: 左侧指示条颜色
Config.Types = {
    ['success'] = {
        icon = 'fa-solid fa-circle-check',
        color = '#4CAF50',
        label = '成功',
    },
    ['error'] = {
        icon = 'fa-solid fa-circle-xmark',
        color = '#F44336',
        label = '错误',
    },
    ['primary'] = {
        icon = 'fa-solid fa-circle-info',
        color = '#2196F3',
        label = '信息',
    },
    ['warning'] = {
        icon = 'fa-solid fa-triangle-exclamation',
        color = '#FF9800',
        label = '警告',
    },
    ['police'] = {
        icon = 'fa-solid fa-shield-halved',
        color = '#1565C0',
        label = '警察',
    },
    ['ambulance'] = {
        icon = 'fa-solid fa-truck-medical',
        color = '#E91E63',
        label = '急救',
    },
}

-- 默认通知类型（当传入的类型不在上方列表时使用）
Config.DefaultType = 'primary'

-- 动画配置
Config.Animation = {
    enter = 'animate__backInLeft',   -- 进场动画
    exit  = 'animate__backOutLeft',  -- 出场动画
    speed = 'animate__fast',         -- 动画速度类 (animate__slow / animate__fast / animate__faster)
}

-- 通知声音（设为 false 关闭）
Config.PlaySound = false

