Locales = {}

-- ====================================
-- 中文语言包
-- ====================================
Locales['zh-CN'] = {
    ['no_permission'] = '您没有权限使用此命令',
    ['player_not_found'] = '未找到ID为 {id} 的玩家',
    ['player_sent_to_prison'] = '玩家 {player} 已被送入监狱',
    ['you_sent_to_prison'] = '您已被送入监狱',
    ['command_usage'] = '使用方法: /guanyaban [玩家ID]',
    ['invalid_player_id'] = '无效的玩家ID',
    ['player_offline'] = '玩家 {id} 不在线',
    ['debug_command_executed'] = '执行关押命令: 目标玩家ID {id}',
    ['debug_event_triggered'] = '触发监狱传送事件: 玩家 {player}',
    ['debug_teleport_success'] = '传送成功: 玩家 {player} 已到达监狱位置',
    ['height_violation'] = '我建议你不要尝试逃跑',
    ['prison_monitoring_start'] = '监狱监控已启动，请勿尝试逃脱',
    ['prison_monitoring_stop'] = '监狱监控已停止',
    ['debug_height_check'] = '高度检测: 当前Z坐标 {height}，允许范围 {min}-{max}',
    ['debug_forced_return'] = '强制传送: 玩家高度超出允许范围',
    ['auto_released'] = '刑期已满，您已被自动释放',
    ['still_in_prison'] = '您仍在服刑中，剩余时间: {time} 分钟',
    ['prison_time_format'] = '{hours}小时{minutes}分钟',
    ['prison_time_minutes'] = '{minutes}分钟',
    ['remaining_time'] = '剩余刑期: {time}',
    ['player_imprisoned_with_time'] = '玩家 {player} 已被关押 {time} 分钟',
    ['command_usage_with_time'] = '使用方法: /guanyaban [玩家ID] [时间(分钟)]',
    ['routing_bucket_enabled'] = '已进入单人监狱世界',
    ['routing_bucket_disabled'] = '已返回主服务器世界',
    ['routing_bucket_create_success'] = '成功创建监狱路由桶 ID: {bucketId}',
    ['routing_bucket_create_failed'] = '创建监狱路由桶失败',
    ['routing_bucket_assign_success'] = '玩家 {player} 已分配到路由桶 {bucketId}',
    ['routing_bucket_assign_failed'] = '分配路由桶失败',
    ['routing_bucket_isolation_active'] = '监狱隔离模式已激活 - 您处于单独的世界中',
    ['routing_bucket_cleanup'] = '清理空闲路由桶: {count} 个',
    ['debug_routing_bucket_info'] = '路由桶信息: 玩家 {player} 在桶 {bucketId}',
    ['debug_routing_bucket_switch'] = '路由桶切换: 从 {fromBucket} 到 {toBucket}',
    ['inventory_cleared'] = '您的背包已被清空',
    ['inventory_clear_success'] = '成功清空玩家 {player} 的背包',
    ['inventory_clear_failed'] = '清空玩家背包失败',
    ['inventory_items_confiscated'] = '您的物品已被没收',
    ['debug_inventory_clear'] = '背包清空: 玩家 {player} 失去 {itemCount} 个物品',
    ['debug_inventory_money_clear'] = '金钱清空: 玩家 {player} 失去现金 ${cash} 银行 ${bank}',
    ['inventory_clear_disabled'] = '背包清空功能已禁用',
    ['auto_revive_success'] = '自动复活成功: 玩家 {player} ({license})',
    ['auto_revive_failed'] = '自动复活失败: 玩家 {player}, 错误: {error}',
    ['auto_revive_notification'] = '您已被自动复活 - 监狱医疗服务',
    ['global_prison_notification'] = '玩家 {player} 因 {reason} 被关押到海上禁闭室',
    ['global_release_notification'] = '玩家 {player} 已从海上禁闭室释放'
}

-- ====================================
-- 英文语言包
-- ====================================
Locales['en-US'] = {
    ['no_permission'] = 'You do not have permission to use this command',
    ['player_not_found'] = 'Player with ID {id} not found',
    ['player_sent_to_prison'] = 'Player {player} has been sent to prison',
    ['you_sent_to_prison'] = 'You have been sent to prison',
    ['command_usage'] = 'Usage: /guanyaban [Player ID]',
    ['invalid_player_id'] = 'Invalid player ID',
    ['player_offline'] = 'Player {id} is offline',
    ['debug_command_executed'] = 'Prison command executed: Target player ID {id}',
    ['debug_event_triggered'] = 'Prison teleport event triggered: Player {player}',
    ['debug_teleport_success'] = 'Teleport successful: Player {player} arrived at prison location',
    ['height_violation'] = 'Position violation detected, teleported back to prison',
    ['prison_monitoring_start'] = 'Prison monitoring activated, do not attempt to escape',
    ['prison_monitoring_stop'] = 'Prison monitoring stopped',
    ['debug_height_check'] = 'Height check: Current Z coordinate {height}, allowed range {min}-{max}',
    ['debug_forced_return'] = 'Forced teleport: Player height outside allowed range',
    ['auto_released'] = 'Sentence completed, you have been automatically released',
    ['still_in_prison'] = 'You are still serving time, remaining: {time} minutes',
    ['prison_time_format'] = '{hours}h {minutes}m',
    ['prison_time_minutes'] = '{minutes}m',
    ['remaining_time'] = 'Remaining sentence: {time}',
    ['player_imprisoned_with_time'] = 'Player {player} has been imprisoned for {time} minutes',
    ['command_usage_with_time'] = 'Usage: /guanyaban [Player ID] [Time(minutes)]',
    ['routing_bucket_enabled'] = 'Entered private prison world',
    ['routing_bucket_disabled'] = 'Returned to main server world',
    ['routing_bucket_create_success'] = 'Successfully created prison routing bucket ID: {bucketId}',
    ['routing_bucket_create_failed'] = 'Failed to create prison routing bucket',
    ['routing_bucket_assign_success'] = 'Player {player} assigned to routing bucket {bucketId}',
    ['routing_bucket_assign_failed'] = 'Failed to assign routing bucket',
    ['routing_bucket_isolation_active'] = 'Prison isolation mode active - You are in a separate world',
    ['routing_bucket_cleanup'] = 'Cleaned up idle routing buckets: {count}',
    ['debug_routing_bucket_info'] = 'Routing bucket info: Player {player} in bucket {bucketId}',
    ['debug_routing_bucket_switch'] = 'Routing bucket switch: From {fromBucket} to {toBucket}',
    ['inventory_cleared'] = 'Your inventory has been cleared',
    ['inventory_clear_success'] = 'Successfully cleared player {player} inventory',
    ['inventory_clear_failed'] = 'Failed to clear player inventory',
    ['inventory_items_confiscated'] = 'Your items have been confiscated',
    ['debug_inventory_clear'] = 'Inventory cleared: Player {player} lost {itemCount} items',
    ['debug_inventory_money_clear'] = 'Money cleared: Player {player} lost cash ${cash} bank ${bank}',
    ['inventory_clear_disabled'] = 'Inventory clearing feature is disabled',
    ['auto_revive_success'] = 'Auto revive successful: Player {player} ({license})',
    ['auto_revive_failed'] = 'Auto revive failed: Player {player}, error: {error}',
    ['auto_revive_notification'] = 'You have been automatically revived - Prison medical service',
    ['global_prison_notification'] = 'Player {player} has been imprisoned for {reason} in the offshore detention center',
    ['global_release_notification'] = 'Player {player} has been released from the offshore detention center'
}

-- ====================================
-- 本地化函数
-- ====================================
function Translate(key, placeholders)
    local currentLocale = Config.Locale or 'en-US'
    local fallbackLocale = 'en-US'
    
    local text = nil
    
    -- 尝试获取当前语言的文本
    if Locales[currentLocale] and Locales[currentLocale][key] then
        text = Locales[currentLocale][key]
    -- 如果当前语言没有，使用默认语言
    elseif Locales[fallbackLocale] and Locales[fallbackLocale][key] then
        text = Locales[fallbackLocale][key]
        if Config.Debug then
            print('[yx_prison] 警告: 键值 "' .. key .. '" 在语言 "' .. currentLocale .. '" 中不存在，使用默认语言')
        end
    else
        -- 如果都没有找到，返回键值本身
        text = key
        if Config.Debug then
            print('[yx_prison] 错误: 键值 "' .. key .. '" 在所有语言包中都不存在')
        end
    end
    
    -- 替换占位符
    if placeholders then
        for placeholder, value in pairs(placeholders) do
            text = string.gsub(text, '{' .. placeholder .. '}', tostring(value))
        end
    end
    
    return text
end