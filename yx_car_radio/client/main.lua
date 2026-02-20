local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isInEmergencyVehicle = false
local currentVehicle = nil
local isDispatcher = false
local dispatcherJob = nil
local radioChannel = nil
local isTalking = false

-- 辅助函数：检查表是否包含某个值
local function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- 使用配置文件中的紧急车辆类型
local emergencyVehicles = Config.EmergencyVehicles

-- 初始化
Citizen.CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            PlayerData = QBCore.Functions.GetPlayerData()
            break
        end
        Citizen.Wait(100)
    end
end)

-- 检查是否为紧急车辆
local function IsEmergencyVehicle(vehicle)
    if not vehicle or vehicle == 0 then return false end
    
    local vehicleModel = GetEntityModel(vehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    
    for job, vehicles in pairs(emergencyVehicles) do
        for _, model in ipairs(vehicles) do
            if string.lower(vehicleName) == string.lower(model) then
                return true, job
            end
        end
    end
    
    return false, nil
end

-- 连接车载电台
local function ConnectCarRadio(job)
    if not job then 
        if Config.Debug then
            print("[车载电台] 错误: 职业参数为空")
        end
        return 
    end
    
    -- 生成频道名称
    radioChannel = Config.Channels.CarRadioPrefix .. job
    
    -- 使用pma-voice连接到频道
    local success = pcall(function()
        exports['pma-voice']:setVoiceProperty("radioEnabled", true)
        exports['pma-voice']:setVoiceProperty("radioChannel", radioChannel)
    end)
    
    if success then
        if Config.Debug then
            print("[车载电台] 已连接到车载电台频道: " .. radioChannel)
        end
        QBCore.Functions.Notify(Config.Notifications.ConnectedToRadio, 'success')
    else
        print("[车载电台] 错误: 无法连接到pma-voice")
        QBCore.Functions.Notify(Config.Notifications.ConnectionFailed, 'error')
    end
end

-- 断开车载电台
local function DisconnectCarRadio()
    if radioChannel then
        local success = pcall(function()
            exports['pma-voice']:setVoiceProperty("radioEnabled", false)
        end)
        
        if success then
            if Config.Debug then
                print("[车载电台] 已断开车载电台连接")
            end
            QBCore.Functions.Notify(Config.Notifications.DisconnectedFromRadio, 'primary')
        else
            print("[车载电台] 错误: 无法断开车载电台")
        end
        
        radioChannel = nil
    end
end

-- 车辆检测线程
Citizen.CreateThread(function()
    local lastVehicle = 0
    local lastJob = nil
    
    while true do
        local playerPed = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        
        if vehicle ~= 0 and vehicle ~= lastVehicle then
            local isEmergency, job = IsEmergencyVehicle(vehicle)
            
            if isEmergency and job then
                if not isInEmergencyVehicle or lastJob ~= job then
                    isInEmergencyVehicle = true
                    currentVehicle = vehicle
                    lastJob = job
                    ConnectCarRadio(job)
                end
            else
                if isInEmergencyVehicle then
                    isInEmergencyVehicle = false
                    currentVehicle = nil
                    lastJob = nil
                    DisconnectCarRadio()
                end
            end
            
            lastVehicle = vehicle
        elseif vehicle == 0 and isInEmergencyVehicle then
            isInEmergencyVehicle = false
            currentVehicle = nil
            lastVehicle = 0
            lastJob = nil
            DisconnectCarRadio()
        end
        
        Citizen.Wait(1000)
    end
end)

-- 调度员注册命令
RegisterCommand('diaodu', function()
    local playerJob = PlayerData.job.name
    local playerJobGrade = PlayerData.job.grade.level
    
    if table.contains(Config.SupportedJobs, playerJob) then
        TriggerServerEvent('yx_car_radio:registerDispatcher', playerJob)
    else
        QBCore.Functions.Notify(Config.Notifications.OnlyEmergencyJobs, 'error')
    end
end, false)

-- 调度员状态更新
RegisterNetEvent('yx_car_radio:updateDispatcherStatus')
AddEventHandler('yx_car_radio:updateDispatcherStatus', function(dispatcherData)
    isDispatcher = dispatcherData.isDispatcher
    dispatcherJob = dispatcherData.job
    
    if isDispatcher then
        QBCore.Functions.Notify('已注册为调度员', 'success')
    else
        QBCore.Functions.Notify('已注销调度员身份', 'success')
    end
end)

-- 语音控制线程
Citizen.CreateThread(function()
    while true do
        if isInEmergencyVehicle then
            if IsControlPressed(0, Config.Keys.TalkKey) then -- U键
                if not isTalking then
                    isTalking = true
                    
                    if isDispatcher then
                        -- 调度员全频喊话
                        TriggerServerEvent('yx_car_radio:dispatcherBroadcast', dispatcherJob)
                        exports['pma-voice']:setVoiceProperty("radioEnabled", true)
                        exports['pma-voice']:setVoiceProperty("radioChannel", Config.Channels.DispatcherPrefix .. dispatcherJob)
                    else
                        -- 普通警员联系调度员
                        TriggerServerEvent('yx_car_radio:contactDispatcher', PlayerData.job.name)
                        exports['pma-voice']:setVoiceProperty("radioEnabled", true)
                        exports['pma-voice']:setVoiceProperty("radioChannel", Config.Channels.DispatcherPrefix .. PlayerData.job.name)
                    end
                end
            else
                if isTalking then
                    isTalking = false
                    
                    -- 恢复车载电台
                    if radioChannel then
                        exports['pma-voice']:setVoiceProperty("radioChannel", radioChannel)
                    else
                        exports['pma-voice']:setVoiceProperty("radioEnabled", false)
                    end
                    
                    TriggerServerEvent('yx_car_radio:stopTalking')
                end
            end
        end
        
        Citizen.Wait(100)
    end
end)

-- 调度员广播接收
RegisterNetEvent('yx_car_radio:receiveDispatcherBroadcast')
AddEventHandler('yx_car_radio:receiveDispatcherBroadcast', function(job)
    if isInEmergencyVehicle and PlayerData.job.name == job then
        exports['pma-voice']:setVoiceProperty("radioEnabled", true)
        exports['pma-voice']:setVoiceProperty("radioChannel", Config.Channels.DispatcherPrefix .. job)
        
        -- 3秒后恢复车载电台
        Citizen.SetTimeout(3000, function()
            if radioChannel then
                exports['pma-voice']:setVoiceProperty("radioChannel", radioChannel)
            end
        end)
    end
end)

-- 玩家数据更新
RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end) 