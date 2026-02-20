local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local isLoggedIn = false

-- 本地变量
local currentVehicle = nil
local currentSpeed = 0.0
local isInVehicle = false
local accuracyModifier = 0.0
local lastAccuracyModifier = 0.0

-- 初始化事件监听
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    isLoggedIn = true
    if Config.Debug then
        print('[射击精度系统] 玩家已加载')
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    PlayerData = {}
    isLoggedIn = false
    if Config.Debug then
        print('[射击精度系统] 玩家已卸载')
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

-- 主要监控线程
Citizen.CreateThread(function()
    while true do
        local sleep = 1000
        
        if isLoggedIn then
            local ped = PlayerPedId()
            
            -- 检查玩家是否在车辆中
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                
                if vehicle ~= 0 then
                    currentVehicle = vehicle
                    isInVehicle = true
                    
                    -- 获取车辆速度 (转换为英里/小时)
                    local speedVector = GetEntitySpeed(vehicle)
                    currentSpeed = speedVector * 2.23694 -- 从米/秒转换为英里/小时
                    
                    sleep = Config.AccuracySettings.updateInterval
                    
                    if Config.Debug then
                        local coords = GetEntityCoords(ped)
                        local heading = GetEntityHeading(vehicle)
                        DrawText3D(coords.x, coords.y, coords.z + 1.0, 
                            string.format("速度: %.1f mph | 精度修正: %.2f", currentSpeed, accuracyModifier))
                    end
                else
                    -- 重置状态
                    ResetVehicleState()
                    sleep = 500
                end
            else
                -- 玩家不在车辆中
                ResetVehicleState()
                sleep = 500
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- 重置车辆状态函数
function ResetVehicleState()
    if isInVehicle then
        currentVehicle = nil
        currentSpeed = 0.0
        isInVehicle = false
        accuracyModifier = 0.0
        lastAccuracyModifier = 0.0
        
        if Config.Debug then
            print('[射击精度系统] 车辆状态已重置')
        end
    end
end

-- 获取当前车辆信息
function GetCurrentVehicleInfo()
    if not isInVehicle or not currentVehicle then
        return nil
    end
    
    local vehicleClass = GetVehicleClass(currentVehicle)
    local vehicleModel = GetEntityModel(currentVehicle)
    local vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    
    return {
        entity = currentVehicle,
        class = vehicleClass,
        model = vehicleModel,
        name = vehicleName,
        speed = currentSpeed
    }
end

-- 调试显示3D文本函数
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local p = GetGameplayCamCoords()
    local distance = GetDistanceBetweenCoords(p.x, p.y, p.z, x, y, z, 1)
    local scale = (1 / distance) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov
    
    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(0)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- 导出函数
exports('IsVehicleSpeedAffectingAccuracy', function()
    return isInVehicle and currentSpeed > Config.SpeedThreshold
end)

exports('GetCurrentAccuracyModifier', function()
    return accuracyModifier
end)

exports('GetCurrentVehicleSpeed', function()
    return currentSpeed
end)

exports('IsPlayerInVehicle', function()
    return isInVehicle
end) 