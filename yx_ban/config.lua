Config = {}

-- ====================================
-- 基础配置
-- ====================================
Config.Debug = false -- 调试模式开关
Config.Locale = 'zh-CN' -- 默认语言

-- ====================================
-- 监狱系统配置
-- ====================================
Config.Prison = {
    location = vector3(-1643.51, -3944.97, 6.55), -- 监狱传送位置
    heading = 270.0, -- 传送后朝向
    releaseLocation = vector3(54.35, 6341.18, 31.23), -- 释放位置
    releaseHeading = 0.0, -- 释放后朝向
    minHeight = 5.0, -- 最低允许高度（Z坐标）
    maxHeight = 10.0, -- 最高允许高度（Z坐标）
    checkInterval = 5000, -- 高度检测间隔（毫秒）
    syncInterval = 120000, -- 数据库同步间隔（120秒）
    countdownInterval = 1000, -- 倒计时间隔（1秒）
    areaRadius = 50.0, -- 监狱区域检测半径（米）
    defaultTime = 30 -- 默认关押时间（分钟）
}

-- ====================================
-- 路由桶配置（单人监狱世界）
-- ====================================
Config.RoutingBucket = {
    enable = true, -- 是否启用路由桶功能
    mainServerBucket = 0, -- 主服务器路由桶ID
    prisonBucketBase = 1000, -- 监狱路由桶起始ID（1000+玩家ID）
    lockType = 'strict', -- 路由桶锁定类型 ('strict' 或 'relaxed')
    maxBuckets = 1000, -- 最大路由桶数量限制
    autoClean = true, -- 是否自动清理空的路由桶
    cleanInterval = 600000 -- 路由桶清理间隔（10分钟）
}

-- ====================================
-- 数据库配置
-- ====================================
Config.Database = {
    tableName = 'player_jail', -- 数据库表名
    enableDatabase = true -- 是否启用数据库保存
}

-- ====================================
-- 背包管理配置
-- ====================================
Config.Inventory = {
    clearOnJail = true, -- 关押时是否清空背包
    clearMethod = 'items', -- 清空方式：'all'(全部清空) 或 'items'(仅清空物品，保留金钱)
    returnOnRelease = false, -- 释放时是否返还物品（暂不实现，预留功能）
    blacklistItems = {}, -- 黑名单物品（这些物品会被永久删除，不会返还）
    logInventoryActions = true -- 是否记录背包操作日志
}

-- ====================================
-- 自动复活配置
-- ====================================
Config.AutoRevive = {
    enable = true, -- 是否启用监狱自动复活
    interval = 1200000, -- 复活间隔（20分钟 = 1200000毫秒）
    ambulanceResource = 'wasabi_ambulance', -- 救护车资源名称
    logRevive = true -- 是否记录复活日志
}

-- ====================================
-- Chat集成配置
-- ====================================
Config.Chat = {
    enableGlobalNotification = true, -- 是否启用全局关押通知
    chatResource = 'that_plutonChat', -- chat资源名称
    notificationColor = '#FF0000' -- 通知颜色（红色）
}

-- ====================================
-- 权限配置
-- ====================================
Config.RequiredGroup = 'admin' -- 使用关押命令所需的权限组
Config.KookSecurity = {
    enableKookEvents = true, -- 是否启用KOOK事件（建议生产环境设为false）
    allowedSources = {0}, -- 允许调用KOOK事件的source列表（0=控制台，其他为玩家ID）
    requireAdminPermission = true -- KOOK事件是否需要管理员权限
}

-- ====================================
-- 调试函数
-- ====================================
function DebugPrint(msg)
    if Config.Debug then
        print('[yx_prison] ' .. msg)
    end
end