Config = {}

-- 紧急车辆配置
Config.EmergencyVehicles = {
    police = {
        'police', 'police2', 'police3', 'police4', 'policeb', 'policet', 'sheriff', 'sheriff2',
        'ambulance', 'firetruk', 'fbi', 'fbi2', 'riot', 'pranger'
    },
    lssd = {
        'sheriff', 'sheriff2', 'sheriff3', 'sheriff4', 'sheriff5', 'sheriff6'
    },
    ambulance = {
        'ambulance', 'ambulance2', 'firetruk', 'firetruk2'
    }
}

-- 支持的职业
Config.SupportedJobs = {
    'police',
    'lssd', 
    'ambulance'
}

-- 频道配置
Config.Channels = {
    -- 车载电台频道前缀
    CarRadioPrefix = "car_radio_",
    
    -- 调度员频道前缀
    DispatcherPrefix = "dispatcher_",
    
    -- 对讲机频道（独立于车载电台）
    RadioPrefix = "radio_"
}

-- 按键配置
Config.Keys = {
    -- 调度员喊话/联系调度员按键
    TalkKey = 85, -- U键
    
    -- 对讲机按键（如果需要）
    RadioKey = 19 -- ALT键
}

-- 通知配置
Config.Notifications = {
    -- 连接车载电台
    ConnectedToRadio = "已连接到车载电台",
    
    -- 断开车载电台
    DisconnectedFromRadio = "已断开车载电台",
    
    -- 注册调度员
    RegisteredDispatcher = "已注册为调度员",
    
    -- 注销调度员
    UnregisteredDispatcher = "已注销调度员身份",
    
    -- 职业已有调度员
    JobHasDispatcher = "该职业已有调度员",
    
    -- 权限不足
    NoPermission = "权限不足",
    
    -- 职业不匹配
    JobMismatch = "职业不匹配",
    
    -- 无调度员
    NoDispatcher = "该职业暂无调度员",
    
    -- 连接失败
    ConnectionFailed = "连接车载电台失败",
    
    -- 只有紧急职业才能注册
    OnlyEmergencyJobs = "只有紧急职业才能注册调度员"
}

-- 调试模式
Config.Debug = false

-- 日志配置
Config.Logging = {
    Enabled = true,
    Level = "info" -- debug, info, warn, error
} 