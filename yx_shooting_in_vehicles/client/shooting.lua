-- 射击精度控制模块
local isAiming = false
local currentWeaponHash = nil
local weaponCategory = nil
local baseAccuracy = 1.0
local appliedAccuracyLoss = 0.0
local smoothedAccuracyLoss = 0.0

-- 武器哈希到类别的映射表
local weaponHashToCategory = {}

-- 统计数据
local shotsFired = 0
local lastDataSync = 0

-- 初始化武器映射表
Citizen.CreateThread(function()
    for categoryName, categoryData in pairs(Config.WeaponCategories) do
        for _, weaponName in ipairs(categoryData.weapons) do
            local weaponHash = GetHashKey(weaponName)
            weaponHashToCategory[weaponHash] = {
                category = categoryName,
                multiplier = categoryData.accuracyMultiplier
            }
        end
    end
    
    if Config.Debug then
        print('[射击精度系统] 武器映射表已初始化')
    end
end)

-- 主要精度控制线程
Citizen.CreateThread(function()
    while true do
        local sleep = 100
        local ped = PlayerPedId()
        
        if isLoggedIn then
            -- 检查是否在瞄准状态
            if IsPlayerFreeAiming(PlayerId()) or IsPlayerFreeAimingAtEntity(PlayerId(), ped) then
                if not isAiming then
                    isAiming = true
                    OnStartAiming()
                end
                
                -- 更新武器信息
                local weaponHash = GetSelectedPedWeapon(ped)
                if weaponHash ~= currentWeaponHash then
                    currentWeaponHash = weaponHash
                    UpdateWeaponCategory()
                end
                
                -- 更新精度修正
                UpdateAccuracyModifier()
                sleep = 50 -- 瞄准时更频繁更新
                
            else
                if isAiming then
                    isAiming = false
                    OnStopAiming()
                end
                sleep = 200
            end
        end
        
        Citizen.Wait(sleep)
    end
end)

-- 开始瞄准时的处理
function OnStartAiming()
    local ped = PlayerPedId()
    currentWeaponHash = GetSelectedPedWeapon(ped)
    UpdateWeaponCategory()
    
    if Config.Debug then
        print('[射击精度系统] 开始瞄准 - 武器: ' .. tostring(currentWeaponHash))
    end
end

-- 停止瞄准时的处理
function OnStopAiming()
    -- 重置武器精度
    if currentWeaponHash and currentWeaponHash ~= 0 then
        RestoreWeaponAccuracy()
    end
    
    appliedAccuracyLoss = 0.0
    smoothedAccuracyLoss = 0.0
    
    if Config.Debug then
        print('[射击精度系统] 停止瞄准 - 精度已重置')
    end
end

-- 更新武器类别
function UpdateWeaponCategory()
    if currentWeaponHash and weaponHashToCategory[currentWeaponHash] then
        weaponCategory = weaponHashToCategory[currentWeaponHash]
        if Config.Debug then
            print('[射击精度系统] 武器类别: ' .. weaponCategory.category .. ' 倍数: ' .. weaponCategory.multiplier)
        end
    else
        weaponCategory = nil
    end
end

-- 更新精度修正值
function UpdateAccuracyModifier()
    if not isInVehicle or not currentVehicle or currentSpeed <= Config.SpeedThreshold then
        -- 不在车内或速度不够，重置精度
        if appliedAccuracyLoss > 0 then
            RestoreWeaponAccuracy()
            appliedAccuracyLoss = 0.0
            smoothedAccuracyLoss = 0.0
        end
        return
    end
    
    -- 计算基础精度损失
    local speedRatio = math.min((currentSpeed - Config.SpeedThreshold) / 
                              (Config.MaxSpeedForCalculation - Config.SpeedThreshold), 1.0)
    
    local targetAccuracyLoss = Config.AccuracySettings.minAccuracyLoss + 
                              (Config.AccuracySettings.maxAccuracyLoss - Config.AccuracySettings.minAccuracyLoss) * speedRatio
    
    -- 应用武器类别倍数
    if weaponCategory then
        targetAccuracyLoss = targetAccuracyLoss * weaponCategory.multiplier
    end
    
    -- 应用车辆类型修正
    local vehicleInfo = GetCurrentVehicleInfo()
    if vehicleInfo and Config.VehicleTypeModifiers[vehicleInfo.class] then
        targetAccuracyLoss = targetAccuracyLoss * Config.VehicleTypeModifiers[vehicleInfo.class]
    end
    
    -- 限制最大值
    targetAccuracyLoss = math.min(targetAccuracyLoss, Config.AccuracySettings.maxAccuracyLoss)
    
    -- 平滑处理，避免突然变化
    smoothedAccuracyLoss = smoothedAccuracyLoss * Config.AccuracySettings.smoothingFactor + 
                          targetAccuracyLoss * (1.0 - Config.AccuracySettings.smoothingFactor)
    
    -- 应用精度修正
    ApplyAccuracyModifier(smoothedAccuracyLoss)
    
    -- 更新全局变量供外部使用
    accuracyModifier = smoothedAccuracyLoss
end

-- 应用精度修正到武器
function ApplyAccuracyModifier(accuracyLoss)
    if not currentWeaponHash or currentWeaponHash == 0 then
        return
    end
    
    local ped = PlayerPedId()
    
    -- 设置武器精度 (值越小精度越差)
    local newAccuracy = baseAccuracy * (1.0 - accuracyLoss)
    newAccuracy = math.max(newAccuracy, 0.1) -- 最低精度限制
    
    -- 使用更有效的native函数来控制武器精度
    if DoesEntityExist(ped) and IsPedArmed(ped, 7) then
        -- 设置武器扩散倍数
        SetPlayerWeaponAccuracyModifier(PlayerId(), newAccuracy)
        
        -- 为了更好的效果，也设置武器伤害倍数 (可选)
        -- SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
        
        -- 应用武器组件精度修正
        local weaponGroup = GetWeapontypeGroup(currentWeaponHash)
        if weaponGroup then
            SetPlayerWeaponTypeAccuracyModifier(PlayerId(), weaponGroup, newAccuracy)
        end
    end
    
    appliedAccuracyLoss = accuracyLoss
    
    if Config.Debug and math.abs(accuracyLoss - lastAccuracyModifier) > 0.01 then
        print(string.format('[射击精度系统] 精度修正: %.2f%% (新精度: %.2f)', 
              accuracyLoss * 100, newAccuracy))
        lastAccuracyModifier = accuracyLoss
    end
end

-- 恢复武器原始精度
function RestoreWeaponAccuracy()
    if not currentWeaponHash or currentWeaponHash == 0 then
        return
    end
    
    local ped = PlayerPedId()
    
    -- 重置武器精度到默认值
    SetPlayerWeaponAccuracyModifier(PlayerId(), baseAccuracy)
    
    local weaponGroup = GetWeapontypeGroup(currentWeaponHash)
    if weaponGroup then
        SetPlayerWeaponTypeAccuracyModifier(PlayerId(), weaponGroup, baseAccuracy)
    end
    
    if Config.Debug then
        print('[射击精度系统] 武器精度已恢复')
    end
end

-- 获取武器信息
function GetCurrentWeaponInfo()
    if not currentWeaponHash or currentWeaponHash == 0 then
        return nil
    end
    
    local weaponName = 'UNKNOWN'
    local category = 'unknown'
    local multiplier = 1.0
    
    if weaponCategory then
        category = weaponCategory.category
        multiplier = weaponCategory.multiplier
    end
    
    return {
        hash = currentWeaponHash,
        name = weaponName,
        category = category,
        multiplier = multiplier,
        accuracyLoss = appliedAccuracyLoss,
        isAiming = isAiming
    }
end

-- 射击事件监听 (额外的精度影响)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if isLoggedIn and isAiming and isInVehicle and currentSpeed > Config.SpeedThreshold then
            local ped = PlayerPedId()
            
            -- 检测射击
            if IsControlJustPressed(0, 24) then -- 鼠标左键/R2
                OnWeaponFired()
            end
        else
            Citizen.Wait(100)
        end
    end
end)

-- 武器开火时的处理
function OnWeaponFired()
    if not isInVehicle or currentSpeed <= Config.SpeedThreshold then
        return
    end
    
    -- 更新统计
    shotsFired = shotsFired + 1
    
    -- 添加额外的射击扩散效果
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    -- 根据速度和武器类型添加视觉抖动效果
    local shakeIntensity = smoothedAccuracyLoss * 0.5
    if shakeIntensity > 0.1 then
        ShakeGameplayCam('HAND_SHAKE', shakeIntensity)
        
        -- 添加短暂的瞄准点偏移
        Citizen.SetTimeout(50, function()
            StopGameplayCamShaking(true)
        end)
    end
    
    -- 同步数据到服务器
    local currentTime = GetGameTimer()
    if currentTime - lastDataSync > 5000 then -- 每5秒同步一次
        TriggerServerEvent('yx_shooting:server:updateAccuracyData', {
            shot_fired = true,
            accuracy_loss = appliedAccuracyLoss,
            speed = currentSpeed,
            weapon_hash = currentWeaponHash,
            vehicle_class = GetCurrentVehicleInfo() and GetCurrentVehicleInfo().class or 0
        })
        lastDataSync = currentTime
    end
    
    -- 反作弊数据发送
    TriggerServerEvent('yx_shooting:server:anticheatCheck', {
        accuracy_loss = appliedAccuracyLoss,
        speed = currentSpeed,
        weapon_hash = currentWeaponHash
    })
    
    if Config.Debug then
        print(string.format('[射击精度系统] 武器开火 - 抖动强度: %.2f', shakeIntensity))
    end
end

-- 数据同步线程
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- 每30秒同步一次基础数据
        
        if isLoggedIn and shotsFired > 0 then
            TriggerServerEvent('yx_shooting:server:updateAccuracyData', {
                speed = currentSpeed,
                accuracy_loss = appliedAccuracyLoss
            })
        end
    end
end)

-- 命令: 查看当前精度状态 (调试用)
RegisterCommand('accuracy_debug', function()
    if not Config.Debug then
        return
    end
    
    local info = GetCurrentWeaponInfo()
    local vehicleInfo = GetCurrentVehicleInfo()
    
    print('=== 射击精度调试信息 ===')
    print('玩家在车内: ' .. tostring(isInVehicle))
    print('当前速度: ' .. string.format('%.1f mph', currentSpeed))
    print('是否瞄准: ' .. tostring(isAiming))
    
    if info then
        print('当前武器哈希: ' .. tostring(info.hash))
        print('武器类别: ' .. info.category)
        print('类别倍数: ' .. string.format('%.2f', info.multiplier))
        print('当前精度损失: ' .. string.format('%.2f%%', info.accuracyLoss * 100))
    end
    
    if vehicleInfo then
        print('车辆类别: ' .. tostring(vehicleInfo.class))
        print('车辆名称: ' .. vehicleInfo.name)
    end
    
    print('总射击数: ' .. shotsFired)
    print('========================')
end, false)

-- 导出函数
exports('GetCurrentWeaponInfo', function()
    return GetCurrentWeaponInfo()
end)

exports('GetWeaponAccuracyLoss', function()
    return appliedAccuracyLoss
end)

exports('IsCurrentlyAiming', function()
    return isAiming
end)

exports('GetShotsFired', function()
    return shotsFired
end) 