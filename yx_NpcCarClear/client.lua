local QBCore = exports['qb-core']:GetCoreObject()
local activeZones = {}
local zoneBlips = {}

-- 创建区域标记
local function createZoneBlip(zoneId, zone)
    if zoneBlips[zoneId] then
        if zoneBlips[zoneId].radius then
            RemoveBlip(zoneBlips[zoneId].radius)
        end
        if zoneBlips[zoneId].center then
            RemoveBlip(zoneBlips[zoneId].center)
        end
    end
    
    local blip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
    SetBlipRotation(blip, 0)
    SetBlipColour(blip, 1)  -- 红色
    SetBlipAlpha(blip, 128) -- 半透明
    
    local centerBlip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
    SetBlipSprite(centerBlip, zone.blip.sprite)
    SetBlipColour(centerBlip, zone.blip.color)
    SetBlipScale(centerBlip, zone.blip.scale)
    SetBlipAsShortRange(centerBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(GetText('blip_name'))
    EndTextCommandSetBlipName(centerBlip)
    
    zoneBlips[zoneId] = {radius = blip, center = centerBlip}
end

-- 清除区域标记
local function clearZoneBlip(zoneId)
    if zoneBlips[zoneId] then
        RemoveBlip(zoneBlips[zoneId].radius)
        RemoveBlip(zoneBlips[zoneId].center)
        zoneBlips[zoneId] = nil
    end
end

-- 更新所有区域标记
local function updateZoneBlips()
    -- 清除所有现有标记
    for zoneId, _ in pairs(zoneBlips) do
        clearZoneBlip(zoneId)
    end
    
    -- 创建新标记
    for zoneId, zone in pairs(activeZones) do
        createZoneBlip(zoneId, zone)
    end
end

-- 同步区域数据
RegisterNetEvent('qb-vehicleclear:syncZones', function(zones)
    activeZones = zones
    updateZoneBlips()
end)

-- 在资源停止时清理
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for zoneId, _ in pairs(zoneBlips) do
            clearZoneBlip(zoneId)
        end
    end
end)

-- 显示输入界面
RegisterNetEvent('qb-vehicleclear:showInput', function(config)
    -- 确保数值是整数
    local maxDurationMinutes = math.floor(config.maxDuration/60)
    local maxRadius = math.floor(config.maxRadius)
    
    local input = lib.inputDialog(GetText('menu_header'), {
        {
            type = 'number',
            label = GetText('menu_duration_label'),
            description = GetText('menu_duration_desc', maxDurationMinutes),
            default = 5,
            min = 1,
            max = maxDurationMinutes,
            required = true
        },
        {
            type = 'number',
            label = GetText('menu_radius_label'),
            description = GetText('menu_radius_desc', maxRadius),
            default = 100,
            min = 10,
            max = maxRadius,
            required = true
        }
    })

    if input then
        local data = {
            duration = input[1],
            radius = input[2]
        }
        TriggerServerEvent('qb-vehicleclear:processInput', data)
    end
end)

-- 检查坐标是否在任意活动区域内
local function isInActiveZone(coords)
    for _, zone in pairs(activeZones) do
        local distance = #(vector3(coords.x, coords.y, coords.z) - vector3(zone.coords.x, zone.coords.y, zone.coords.z))
        if distance <= zone.radius then -- 使用区域特定的半径
            return true
        end
    end
    return false
end

-- 清除区域内的NPC车辆
local function clearAreaVehicles()
    for _, zone in pairs(activeZones) do
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) then
                local vehicleCoords = GetEntityCoords(vehicle)
                local distance = #(vector3(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z) - vector3(zone.coords.x, zone.coords.y, zone.coords.z))
                
                if distance <= zone.radius then -- 使用区域特定的半径
                    local driver = GetPedInVehicleSeat(vehicle, -1)
                    if driver ~= 0 and not IsPedAPlayer(driver) then
                        DeleteEntity(vehicle)
                        DeleteEntity(driver)
                    end
                end
            end
        end
    end
end

-- 主循环
CreateThread(function()
    while true do
        local wait = 1000
        local playerCoords = GetEntityCoords(PlayerPedId())
        
        if isInActiveZone(playerCoords) then
            wait = 100
            -- 禁用车辆生成
            SetVehicleDensityMultiplierThisFrame(0.0)
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            
            -- 清除现有NPC车辆
            clearAreaVehicles()
        end
        
        Wait(wait)
    end
end) 