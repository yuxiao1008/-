--[[
    yx_notification 服务端主文件
    功能：提供服务端通知接口 + 自动安装桥接到 qb-core
    作者：于晓
]]

-- ========== 调试输出 ==========

local function DebugPrint(msg)
    if Config.Debug then
        print('^3[yx_notification:server]^0 ' .. tostring(msg))
    end
end

-- #region agent log
local _debug_ingest_url = 'http://127.0.0.1:7243/ingest/5389157c-5ccb-4d1d-b87c-863cd8e3d110'
local function WriteDebugLog(location, message, data, hypothesisId)
    local ok, json_str = pcall(json.encode, {
        location = location,
        message = message,
        data = data or {},
        hypothesisId = hypothesisId or '',
        timestamp = os.time() * 1000
    })
    if ok then
        PerformHttpRequest(_debug_ingest_url, function(code, text, headers) end, 'POST', json_str, {['Content-Type'] = 'application/json'})
    end
end

RegisterNetEvent('yx_notification:debug:log', function(location, message, data, hypothesisId)
    WriteDebugLog(location, message, data, hypothesisId)
end)

WriteDebugLog('server/main.lua:init', 'Server debug log system working', {}, 'INFRA')
-- #endregion

-- ========== 自动安装桥接文件到 qb-core ==========

local BRIDGE_FILENAME = 'client/yx_notify_bridge.lua'
local BRIDGE_MARKER = '-- yx_notification_bridge'

---生成桥接脚本内容（注入到 qb-core 内部运行）
local function GetBridgeCode()
    return BRIDGE_MARKER .. [=[

--[[
    yx_notification 桥接文件
    此文件由 yx_notification 自动生成，运行在 qb-core 的 Lua 环境中
    功能：覆盖 QBCore.Functions.Notify，重定向通知到 yx_notification
    !! 请勿手动修改此文件，删除 yx_notification 资源后可安全删除此文件 !!
]]

Citizen.CreateThread(function()
    -- 等待 QBCore 初始化完成
    while not QBCore do
        Citizen.Wait(0)
    end
    while not QBCore.Functions do
        Citizen.Wait(0)
    end

    -- 保存原始函数作为回退
    local _original_notify = QBCore.Functions.Notify

    -- 覆盖通知函数
    QBCore.Functions.Notify = function(text, texttype, length)
        -- 如果 yx_notification 正在运行，使用自定义通知
        if GetResourceState('yx_notification') == 'started' then
            exports['yx_notification']:Notify(text, texttype, length)
        elseif _original_notify then
            -- 回退到原始通知
            _original_notify(text, texttype, length)
        end
    end

    print('^2[yx_notification]^0 QBCore.Functions.Notify 已被桥接覆盖')
end)
]=]
end

---安装桥接文件到 qb-core
local function InstallBridge()
    -- 检查 qb-core 是否存在
    if GetResourceState('qb-core') == 'missing' then
        print('^1[yx_notification]^0 错误：未找到 qb-core 资源！')
        return false
    end

    -- 检查桥接文件是否已存在
    local existing = LoadResourceFile('qb-core', BRIDGE_FILENAME)
    if existing and existing:find(BRIDGE_MARKER) then
        DebugPrint('桥接文件已存在于 qb-core 中')
        -- #region agent log
        WriteDebugLog('server/main.lua:install', 'Bridge file already exists', {}, 'FIX')
        -- #endregion
        return true
    end

    -- 写入桥接文件到 qb-core
    local bridge_code = GetBridgeCode()
    local success = SaveResourceFile('qb-core', BRIDGE_FILENAME, bridge_code, -1)
    if not success then
        print('^1[yx_notification]^0 错误：无法写入桥接文件到 qb-core！')
        return false
    end

    -- 读取 qb-core 的 fxmanifest.lua
    local manifest = LoadResourceFile('qb-core', 'fxmanifest.lua')
    if not manifest then
        print('^1[yx_notification]^0 错误：无法读取 qb-core/fxmanifest.lua！')
        return false
    end

    -- 检查 fxmanifest 是否已包含桥接文件
    if not manifest:find('yx_notify_bridge') then
        -- 在 fxmanifest 末尾追加桥接脚本引用
        manifest = manifest .. "\n\n-- yx_notification auto-injected bridge (safe to remove)\nclient_script '" .. BRIDGE_FILENAME .. "'\n"
        SaveResourceFile('qb-core', 'fxmanifest.lua', manifest, -1)

        print('^2[yx_notification]^0 ========================================')
        print('^2[yx_notification]^0 桥接文件已自动安装到 qb-core！')
        print('^3[yx_notification]^0 请执行以下命令完成安装：')
        print('^3[yx_notification]^0   ensure qb-core')
        print('^2[yx_notification]^0 ========================================')

        -- #region agent log
        WriteDebugLog('server/main.lua:install', 'Bridge file installed, need qb-core restart', {}, 'FIX')
        -- #endregion

        return 'need_restart'
    end

    return true
end

-- 资源启动时自动安装
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local result = InstallBridge()
    if result == 'need_restart' then
        -- 自动重启 qb-core
        Citizen.SetTimeout(1000, function()
            print('^3[yx_notification]^0 正在自动重启 qb-core 以加载桥接...')
            ExecuteCommand('ensure qb-core')
        end)
    end
end)

-- ========== 服务端通知接口 ==========

---向指定玩家发送通知
---@param source number 玩家服务端ID
---@param message string 通知消息
---@param notify_type string|nil 通知类型
---@param duration number|nil 显示时长（毫秒）
local function NotifyPlayer(source, message, notify_type, duration)
    if not source or source <= 0 then return end
    if not message or message == '' then return end

    TriggerClientEvent('yx_notification:client:notify', source, message, notify_type or Config.DefaultType, duration or Config.DefaultDuration)
    DebugPrint(string.format('向玩家 %d 发送通知 [%s]: %s', source, notify_type or Config.DefaultType, message))
end

---向所有玩家发送通知
---@param message string 通知消息
---@param notify_type string|nil 通知类型
---@param duration number|nil 显示时长（毫秒）
local function NotifyAll(message, notify_type, duration)
    if not message or message == '' then return end

    TriggerClientEvent('yx_notification:client:notify', -1, message, notify_type or Config.DefaultType, duration or Config.DefaultDuration)
    DebugPrint(string.format('向所有玩家发送通知 [%s]: %s', notify_type or Config.DefaultType, message))
end

-- ========== 导出函数 ==========

exports('NotifyPlayer', function(source, message, notify_type, duration)
    NotifyPlayer(source, message, notify_type, duration)
end)

exports('NotifyAll', function(message, notify_type, duration)
    NotifyAll(message, notify_type, duration)
end)

-- ========== 自定义服务端事件 ==========

RegisterNetEvent('yx_notification:server:notify', function(message, notify_type, duration)
    local src = source
    NotifyPlayer(src, message, notify_type, duration)
end)

RegisterNetEvent('yx_notification:server:notifyAll', function(message, notify_type, duration)
    NotifyAll(message, notify_type, duration)
end)

DebugPrint('服务端已加载')
