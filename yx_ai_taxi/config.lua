--[[
    ====================================
    AI 出租车系统 - 配置文件
    作者：于晓
    描述：所有可调整参数统一管理
    ====================================
]]--

Config = {}

-- ============================================
-- 调试模式配置
-- ============================================
Config.Debug = true  -- true: 开启调试日志输出, false: 关闭

-- ============================================
-- 出租车生成配置
-- ============================================
Config.Taxi = {
    model = 'taxi',                 -- 出租车模型名称
    spawn_radius_min = 100.0,        -- 最小生成距离（米）
    spawn_radius_max = 150.0,       -- 最大生成距离（米）
    node_search_attempts = 10,      -- 道路节点搜索尝试次数
    model_load_timeout = 10000,     -- 模型加载超时时间（毫秒）
}

-- ============================================
-- NPC 司机配置
-- ============================================
Config.Driver = {
    model = 'a_m_m_indian_01',      -- 司机NPC模型
    driving_style = 786603,         -- 驾驶风格（786603 = 正常驾驶，避让车辆）
    driving_style_rush = 2883621,   -- 催促后驾驶风格（激进：超车、闯红灯）
    driving_speed = 20.0,           -- 接客驾驶速度（m/s，约72km/h）
    trip_speed = 25.0,              -- 行程驾驶速度（m/s，约90km/h）
    rush_speed = 35.0,              -- 催促后驾驶速度（m/s，约126km/h）
    arrival_distance = 8.0,         -- 接客到达距离（米）- 出租车到达召唤点的判定距离
    stop_distance = 50.0,           -- 行程停车距离（米）- 50米范围内可按E停车
}

-- ============================================
-- 行程配置
-- ============================================
Config.Trip = {
    confirm_key = 38,               -- 确认按键（38 = E键）
    rush_key = 22,                  -- 催促按键（22 = 空格键）
    driver_leave_delay = 3000,      -- 司机驶离延迟（毫秒）
    player_nearby_distance = 10.0,  -- 玩家靠近出租车触发到达的距离（米）
    idle_timeout = 180000,          -- 无人上车超时时间（毫秒，3分钟）
}

-- ============================================
-- 计费配置
-- ============================================
Config.Fare = {
    base_fare = 200,                 -- 基础费用（美元）
    per_meter = 0.08,               -- 每米费用（美元）
    min_fare = 200,                  -- 最低收费（美元）
    currency_symbol = '$',          -- 货币符号
}

-- ============================================
-- 地图标记（Blip）配置
-- ============================================
Config.Blip = {
    sprite = 198,                   -- Blip图标类型（198 = 出租车图标）
    color = 5,                      -- Blip颜色（5 = 黄色）
    scale = 0.8,                    -- Blip大小
    name = '出租车',                 -- Blip显示名称
}

-- ============================================
-- 通知消息配置
-- ============================================
Config.Messages = {
    -- 第一阶段消息
    taxi_called = '~g~出租车已为您派出，请稍候...',
    taxi_arrived = '~y~出租车已到达，请上车！',
    no_road_found = '~r~附近没有找到合适的道路，请换个位置再试。',
    already_called = '~r~您已经呼叫了出租车，请等待到达。',
    taxi_spawning = '~b~正在为您寻找附近的出租车...',
    taxi_timeout = '~r~出租车等待超时已离开。',
    -- 第二阶段消息
    wrong_seat = '~r~请坐后座，老板！',
    no_waypoint = '~y~请在地图上标记目的地，老板。',
    trip_started = '~g~好的老板，马上出发！',
    trip_completed = '~g~目的地到了，老板，祝您旅途愉快！',
    player_left = '~r~乘客已离开，行程取消。',
    driver_rush = '~y~好的老板，我开快点！',
    -- 计费消息
    fare_paid = '~g~车费 %s%d 已支付，感谢乘车！',
    fare_insufficient = '~r~余额不足！你这是霸王车啊！',
}

-- ============================================
-- 命令配置
-- ============================================
Config.Command = {
    name = 'calltaxi',              -- 召唤出租车的命令名
    help = '召唤一辆AI出租车',       -- 命令帮助说明
}

-- ============================================
-- 检测间隔配置
-- ============================================
Config.Intervals = {
    arrival_check = 500,            -- 到达检测间隔（毫秒）
    blip_update = 100,              -- Blip位置更新间隔（毫秒）
    seat_check = 200,               -- 座位检测间隔（毫秒）
    waypoint_check = 500,           -- 路径点检测间隔（毫秒）
    trip_check = 500,               -- 行程状态检测间隔（毫秒）
}

-- ============================================
-- 屏幕提示配置
-- ============================================
Config.HelpText = {
    enter_taxi = '按 ~INPUT_CONTEXT~ 上车',
    confirm_trip = '按 ~INPUT_CONTEXT~ 确认前往目的地',
    set_waypoint = '请在地图上标记您的目的地',
    rush_driver = '按 ~INPUT_JUMP~ 催促司机开快点',
    stop_here = '按 ~INPUT_CONTEXT~ 在这里停车',
}

-- ============================================
-- 车辆钥匙脚本配置（jaksam vehicles_keys）
-- ============================================
Config.VehicleKeys = {
    enabled = true,                     -- 是否启用钥匙脚本集成
    script_name = 'vehicles_keys',      -- 钥匙脚本资源名
    key_type = 'temporary',             -- 钥匙类型: temporary/owned/other_player
}

-- ============================================
-- 司机语音配置
-- ============================================
Config.DriverSpeech = {
    enabled = true,                     -- 是否启用司机语音
    -- 语音名称和参数
    greet = 'GENERIC_HI',               -- 上车问候
    rush_complain = 'GENERIC_FRIGHTENED_HIGH', -- 催促时抱怨
    arrive = 'GENERIC_BYE',             -- 到达告别
    angry = 'GENERIC_INSULT_HIGH',      -- 霸王车时愤怒
}

-- ============================================
-- 报警配置（rcore_dispatch）
-- ============================================
Config.Dispatch = {
    enabled = true,                     -- 是否启用报警功能
    jobs = {'police', 'lssd'},          -- 接收警报的职业
    code = '10-31 - 霸王车',            -- 警报代码
    priority = 'medium',                -- 警报优先级: low/medium/high
    blip_time = 60,                     -- 警报Blip显示时间（秒）
    blip_sprite = 198,                  -- Blip图标（198 = 出租车）
    blip_colour = 1,                    -- Blip颜色（1 = 红色）
    blip_scale = 0.8,                   -- Blip大小
    blip_text = '霸王车 - 出租车逃单',  -- Blip文字
    blip_flashes = true,                -- Blip是否闪烁
}

