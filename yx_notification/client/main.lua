--[[
    yx_notification 客户端主文件
    功能：接收通知请求，通过 NUI 显示自定义通知
    桥接文件（qb-core 内部）负责拦截 QBCore.Functions.Notify 并调用本资源导出
    作者：于晓
]]

-- ========== 调试输出 ==========

local function DebugPrint(msg)
    if Config.Debug then
        print('^3[yx_notification]^0 ' .. tostring(msg))
    end
end

-- #region agent log
local function DebugLog(location, message, data, hypothesisId)
    TriggerServerEvent('yx_notification:debug:log', location, message, data, hypothesisId)
end
-- #endregion

-- ========== 初始化：同步配置到 NUI ==========

Citizen.CreateThread(function()
    -- 等待 NUI 加载完成
    Citizen.Wait(500)

    -- 同步配置到前端
    SendNUIMessage({
        action = 'config',
        maxNotifications = Config.MaxNotifications,
        animation = Config.Animation,
        types = Config.Types,
    })

    DebugPrint('配置已同步到 NUI')
end)

-- ========== 核心通知函数 ==========

---发送通知到 NUI
---@param message string 通知消息
---@param notify_type string|nil 通知类型 (success/error/primary/warning/police/ambulance)
---@param duration number|nil 显示时长（毫秒）
local function SendNotification(message, notify_type, duration)
    -- #region agent log
    DebugLog('client/main.lua:SendNotification', 'SendNotification called', {message = tostring(message), notify_type = tostring(notify_type), duration = duration}, 'VERIFY')
    -- #endregion
    if not message or message == '' then return end

    -- 类型标准化
    notify_type = notify_type or Config.DefaultType

    -- 处理 table 参数（兼容新版 QBCore table 格式）
    if type(message) == 'table' then
        local data = message
        message = data.text or data.message or data.caption or ''
        notify_type = data.type or data.notifyType or notify_type
        duration = data.length or data.duration or duration
    end

    notify_type = string.lower(tostring(notify_type))

    -- QB 类型映射到自定义类型
    local type_map = {
        ['inform']    = 'primary',
        ['info']      = 'primary',
        ['general']   = 'primary',
        ['default']   = 'primary',
        ['success']   = 'success',
        ['error']     = 'error',
        ['danger']    = 'error',
        ['warning']   = 'warning',
        ['warn']      = 'warning',
        ['police']    = 'police',
        ['ambulance'] = 'ambulance',
        ['ems']       = 'ambulance',
        ['primary']   = 'primary',
    }

    notify_type = type_map[notify_type] or Config.DefaultType
    duration = duration or Config.DefaultDuration

    -- 发送到 NUI
    SendNUIMessage({
        action   = 'notify',
        message  = tostring(message),
        type     = notify_type,
        duration = duration,
    })

    DebugPrint(string.format('通知 [%s]: %s (时长: %dms)', notify_type, message, duration))
end

-- ========== 导出函数（供桥接文件和其他资源调用） ==========

exports('Notify', function(message, notify_type, duration)
    SendNotification(message, notify_type, duration)
end)

-- ========== 事件处理器（兼容服务端触发的通知） ==========

-- QBCore:Notify（服务端 TriggerClientEvent 触发）
RegisterNetEvent('QBCore:Notify', function(message, notify_type, duration)
    -- #region agent log
    DebugLog('client/main.lua:QBCore:Notify', 'QBCore:Notify event fired', {msg_type = type(message), message = type(message) == 'table' and json.encode(message) or tostring(message)}, 'VERIFY')
    -- #endregion
    SendNotification(message, notify_type, duration)
end)

-- QBCore:Client:Notify（旧版 QBCore 兼容）
RegisterNetEvent('QBCore:Client:Notify', function(message, notify_type, duration)
    SendNotification(message, notify_type, duration)
end)

-- 兼容 ox_lib
RegisterNetEvent('ox_lib:notify', function(data)
    if type(data) == 'table' then
        SendNotification(
            data.description or data.title or data.text or '',
            data.type or 'primary',
            data.duration or Config.DefaultDuration
        )
    end
end)

-- 兼容 esx
RegisterNetEvent('esx:showNotification', function(message, notify_type, duration)
    SendNotification(message, notify_type or 'primary', duration)
end)

RegisterNetEvent('ESX:Notify', function(notify_type, duration, message)
    SendNotification(message, notify_type or 'primary', duration)
end)

-- ========== 自定义事件接口 ==========

RegisterNetEvent('yx_notification:client:notify', function(message, notify_type, duration)
    SendNotification(message, notify_type, duration)
end)

DebugPrint('客户端已加载')
