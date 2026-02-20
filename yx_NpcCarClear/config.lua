Config = {}

-- 语言设置 (cn = 中文, en = 英文)
-- 切换语言只需要修改这一行：'cn' 或 'en'
Config.Language = 'cn'

-- 语言系统初始化
Locales = Locales or {}

-- 创建全局语言变量存储
Lang = {
    -- 中文语言包
    cn = {
        -- 菜单相关
        menu_header = '道路封控设置',
        menu_duration_label = '持续时间（分钟）',
        menu_duration_desc = '设置道路封控持续时间，最大%d分钟',
        menu_radius_label = '最大半径（米）',
        menu_radius_desc = '设置清除NPC车辆的范围半径，最大%d米',
        
        -- 地图标记
        blip_name = '封控区域',
        
        -- 通知消息
        notify_no_permission = '只有警察才能使用此命令！',
        notify_cooldown = '命令冷却中，还需等待%d秒',
        notify_invalid_duration = '持续时间不能超过%d分钟',
        notify_invalid_radius = '范围不能超过%d米',
        notify_zone_created = '已清除半径%d米内的NPC车辆，持续%d分钟',
        notify_zone_removed = '已解除所有道路封控状态',
        notify_no_active_zones = '当前没有活动的封控区域！',
        
        -- 警察通知
        notify_police_zone_created = '%s警官已启动道路封控\n范围: %d米\n持续: %d分钟',
        notify_police_zone_removed = '%s警官已解除所有道路封控状态',
        
        -- 命令描述
        command_qingche_desc = '清除附近NPC车辆',
        command_cancel_desc = '取消当前的道路封控状态'
    },
    
    en = {
        -- 菜单相关
        menu_header = 'Road Control Settings',
        menu_duration_label = 'Duration (minutes)',
        menu_duration_desc = 'Set road control duration, maximum %d minutes',
        menu_radius_label = 'Maximum Radius (meters)',
        menu_radius_desc = 'Set NPC vehicle clearing range radius, maximum %d meters',
        
        -- 地图标记
        blip_name = 'Control Zone',
        
        -- 通知消息
        notify_no_permission = 'Only police can use this command!',
        notify_cooldown = 'Command on cooldown, wait %d seconds',
        notify_invalid_duration = 'Duration cannot exceed %d minutes',
        notify_invalid_radius = 'Radius cannot exceed %d meters',
        notify_zone_created = 'Cleared NPC vehicles within %d meters radius for %d minutes',
        notify_zone_removed = 'All road control status has been lifted',
        notify_no_active_zones = 'No active control zones currently!',
        
        -- 警察通知
        notify_police_zone_created = 'Officer %s has activated road control\nRange: %d meters\nDuration: %d minutes',
        notify_police_zone_removed = 'Officer %s has lifted all road control status',
        
        -- 命令描述
        command_qingche_desc = 'Clear nearby NPC vehicles',
        command_cancel_desc = 'Cancel current road control status'
    }
}
function GetText(key, ...)
    local currentLang = Config.Language or 'cn'
    if Lang[currentLang] and Lang[currentLang][key] then
        local text = Lang[currentLang][key]
        if ... then
            local success, result = pcall(string.format, text, ...)
            if success then
                return result
            else
                return text
            end
        else
            return text
        end
    else
        if Lang.cn and Lang.cn[key] then
            local text = Lang.cn[key]
            if ... then
                local success, result = pcall(string.format, text, ...)
                if success then
                    return result
                else
                    return text
                end
            else
                return text
            end
        end
        return key
    end
end

-- 兼容性别名
_ = GetText

-- 允许使用该命令的警察职业
Config.PoliceJobs = {
    ['police'] = {
        maxDuration = 1000,  -- 最大持续时间（秒）
        maxRadius = 300,     -- 最大范围（米）
        cooldown = 600     -- 冷却时间（秒）
    },
    ['lssd'] = {
        maxDuration = 1000,  -- 最大持续时间（秒）
        maxRadius = 300,     -- 最大范围（米）
        cooldown = 600     -- 冷却时间（秒）
    }
}

-- 默认值
Config.DefaultRadius = 100.0 -- 默认半径（米）
Config.DefaultDuration = 300  -- （秒）5分钟 