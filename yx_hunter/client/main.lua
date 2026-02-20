local QBCore = exports['qb-core']:GetCoreObject()
local spawnedAnimals = {}
local huntingBlips = {}
local syncedAnimals = {} -- 服务端同步的动物
local merchantNPC = nil -- 商人NPC
local merchantBlip = nil -- 商人地图标记

-- 安全的语言函数调用
-- Safe language function calls
local function SafeGetZoneName(key)
    if GetZoneName and key then
        return GetZoneName(key)
    end
    -- 如果语言系统未加载，返回默认值
    local defaultNames = {
        legal_hunting = "Legal Hunting",
        illegal_hunting = "Illegal Hunting"
    }
    return defaultNames[key] or key
end

local function SafeGetAnimalName(key)
    if GetAnimalName and key then
        return GetAnimalName(key)
    end
    -- 如果语言系统未加载，返回默认值
    local defaultNames = {
        boar = "Boar",
        coyote = "Coyote", 
        deer = "Deer",
        rabbit = "Rabbit",
        mtlion = "Mountain Lion"
    }
    return defaultNames[key] or key
end

local function SafeL(key, ...)
    if _L and key then
        return _L(key, ...)
    end
    
    -- 如果语言系统未加载，返回常用的默认翻译
    local defaultTranslations = {
        ["interactions.harvesting_progress"] = "Harvesting animal...",
        ["interactions.harvest_animal"] = "Harvest %s", 
        ["interactions.sell_hunting_items"] = "Sell Hunting Items",
        ["notifications.animal_spawned"] = "%s spawned near you!",
        ["notifications.cannot_harvest"] = "Cannot harvest this animal!",
        ["notifications.killer_only"] = "Only the killer can harvest this animal!",
        ["notifications.too_far"] = "You are too far from the animal!",
        ["notifications.need_tool"] = "You need %s to harvest animals!",
        ["notifications.harvest_cancelled"] = "Harvest cancelled",
        ["notifications.harvesting_animal"] = "Harvesting %s...",
        ["notifications.not_in_zone"] = "You are not in any hunting zone!",
        ["notifications.no_ground"] = "No suitable ground location found",
        ["notifications.animal_config_error"] = "Animal configuration error: %s",
        ["notifications.no_animals_configured"] = "No animals configured for this area",
        ["debug.all_animals_cleared"] = "All hunting animals cleared",
        ["debug.resource_stopped"] = "YX Hunter resource stopped, cleanup complete",
        -- 商人相关翻译
        ["merchant_blip"] = "Hunting Merchant",
        ["merchant_greeting"] = "Hello hunter! I buy all kinds of hunting materials at good prices.",
        ["merchant_success"] = "Transaction completed! Sold %d items for $%d",
        ["merchant_no_items"] = "You don't have any hunting items to sell.",
        ["merchant_inventory_full"] = "Sorry, my inventory is full right now."
    }
    
    if defaultTranslations[key] then
        if ... then
            return string.format(defaultTranslations[key], ...)
        else
            return defaultTranslations[key]
        end
    end
    
    -- 如果没有找到翻译，返回键值
    return key or "Unknown"
end

-- 优化的原生动物禁用系统 (修复车辆消失问题)
function DisableNativeAnimalSpawning()
    -- 动物模型哈希值列表
    local nativeAnimalModels = {
        GetHashKey("a_c_boar"),
        GetHashKey("a_c_coyote"), 
        GetHashKey("a_c_deer"),
        GetHashKey("a_c_rabbit_01"),
        GetHashKey("a_c_mtlion"),
        GetHashKey("a_c_pig"),
        GetHashKey("a_c_cow")
    }
    
    -- 使用定期清理特定动物实体的方式，不影响车辆和其他NPC
    
    -- 定期清理原生动物线程
    CreateThread(function()
        while true do
            Wait(Config.SpawnSettings.cleanupInterval or 5000) -- 使用配置的清理间隔
            
            local peds = GetGamePool('CPed')
            local cleanupCount = 0
            
            for _, ped in ipairs(peds) do
                if DoesEntityExist(ped) and ped ~= PlayerPedId() then
                    local pedModel = GetEntityModel(ped)
                    
                    -- 检查是否为原生动物模型
                    for _, animalModel in ipairs(nativeAnimalModels) do
                        if pedModel == animalModel then
                            -- 检查是否为我们控制的动物
                            local isOurAnimal = false
                            
                            -- 检查同步动物列表
                            for _, syncedAnimal in pairs(syncedAnimals) do
                                if syncedAnimal.entity == ped then
                                    isOurAnimal = true
                                    break
                                end
                            end
                            
                            -- 检查生成动物列表
                            if not isOurAnimal then
                                for _, spawnedAnimal in pairs(spawnedAnimals) do
                                    if spawnedAnimal.entity == ped then
                                        isOurAnimal = true
                                        break
                                    end
                                end
                            end
                            
                            -- 只删除非脚本控制的原生动物，并添加额外安全检查
                            if not isOurAnimal then
                                -- 额外安全检查：确保不是玩家或其他重要NPC
                                if not IsPedAPlayer(ped) and not IsPedInAnyVehicle(ped, false) then
                                    if Config.VerboseDebug then
                                        print("[YX Hunter] Removing native animal: " .. tostring(pedModel))
                                    end
                                    DeleteEntity(ped)
                                    cleanupCount = cleanupCount + 1
                                end
                            end
                            break
                        end
                    end
                end
            end
            
            if cleanupCount > 0 and Config.Debug then
                print("[YX Hunter] Cleaned up " .. cleanupCount .. " native animals")
            end
        end
    end)
    
    if Config.Debug then
        print("[YX Hunter] Native animal cleanup system enabled")
        print("[YX Hunter] Will periodically remove native animals while preserving vehicles and other NPCs")
    end
end

-- 创建收货商人
function CreateHuntingMerchant()
    if not Config.Merchant.enabled then return end
    
    local merchantConfig = Config.Merchant
    local hash = GetHashKey(merchantConfig.model)
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    
    -- 创建商人NPC
    merchantNPC = CreatePed(4, hash, merchantConfig.coords.x, merchantConfig.coords.y, merchantConfig.coords.z, merchantConfig.coords.w, false, false)
    
    if DoesEntityExist(merchantNPC) then
        -- 设置NPC属性
        SetEntityAsMissionEntity(merchantNPC, true, true)
        SetPedCanRagdoll(merchantNPC, false)
        SetEntityInvincible(merchantNPC, true)
        SetBlockingOfNonTemporaryEvents(merchantNPC, true)
        SetPedCanBeTargetted(merchantNPC, false)
        SetPedCanBeDraggedOut(merchantNPC, false)
        FreezeEntityPosition(merchantNPC, true)
        
        -- 确保NPC在地面上
        PlaceObjectOnGroundProperly(merchantNPC)
        
        -- 添加qb-target交互 (使用直接文本避免语言键值显示问题)
        local interactionLabel = SafeL("interactions." .. merchantConfig.interaction.labelKey)
        
        -- 如果翻译失败，使用硬编码的后备文本
        if interactionLabel == ("interactions." .. merchantConfig.interaction.labelKey) then
            interactionLabel = "出售狩猎物品" -- 默认中文
            if Config.Language == 'en' then
                interactionLabel = "Sell Hunting Items"
            end
        end
        
        if Config.Debug then
            print("[YX Hunter] Merchant interaction label: '" .. interactionLabel .. "'")
            print("[YX Hunter] Language key: 'interactions." .. merchantConfig.interaction.labelKey .. "'")
        end
        
        exports['qb-target']:AddTargetEntity(merchantNPC, {
            options = {
                {
                    type = "client",
                    event = "yx-hunter:client:openMerchant",
                    icon = merchantConfig.interaction.targetIcon,
                    label = interactionLabel
                }
            },
            distance = merchantConfig.interaction.distance
        })
        
        -- 创建地图标记
        if merchantConfig.blip.enabled then
            merchantBlip = AddBlipForCoord(merchantConfig.coords.x, merchantConfig.coords.y, merchantConfig.coords.z)
            SetBlipSprite(merchantBlip, merchantConfig.blip.sprite)
            SetBlipDisplay(merchantBlip, 4)
            SetBlipScale(merchantBlip, merchantConfig.blip.scale)
            SetBlipColour(merchantBlip, merchantConfig.blip.color)
            SetBlipAsShortRange(merchantBlip, true)
            
            local blipName = SafeL(merchantConfig.blip.nameKey)
            
            -- 如果翻译失败，使用硬编码的后备文本
            if blipName == merchantConfig.blip.nameKey then
                blipName = "狩猎商人" -- 默认中文
                if Config.Language == 'en' then
                    blipName = "Hunting Merchant"
                end
            end
            
            if Config.Debug then
                print("[YX Hunter] Merchant blip name: '" .. blipName .. "'")
                print("[YX Hunter] Blip language key: '" .. merchantConfig.blip.nameKey .. "'")
            end
            
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(blipName)
            EndTextCommandSetBlipName(merchantBlip)
        end
        
        if Config.Debug then
            print("[YX Hunter] Hunting merchant created at " .. tostring(merchantConfig.coords))
        end
    else
        if Config.Debug then
            print("[YX Hunter] Failed to create hunting merchant")
        end
    end
    
    SetModelAsNoLongerNeeded(hash)
end

-- 清理商人
function ClearHuntingMerchant()
    if DoesEntityExist(merchantNPC) then
        exports['qb-target']:RemoveTargetEntity(merchantNPC)
        DeleteEntity(merchantNPC)
        merchantNPC = nil
    end
    
    if merchantBlip and DoesBlipExist(merchantBlip) then
        RemoveBlip(merchantBlip)
        merchantBlip = nil
    end
end

-- 商人交互事件
RegisterNetEvent('yx-hunter:client:openMerchant', function()
    -- 显示问候语
    local greeting = SafeL(Config.Merchant.messages.greetingKey)
    
    -- 如果翻译失败，使用硬编码的后备文本
    if greeting == Config.Merchant.messages.greetingKey then
        greeting = "你好，猎人！我以好价格收购各种狩猎材料。" -- 默认中文
        if Config.Language == 'en' then
            greeting = "Hello hunter! I buy all kinds of hunting materials at good prices."
        end
    end
    
    if Config.Debug then
        print("[YX Hunter] Merchant greeting: '" .. greeting .. "'")
        print("[YX Hunter] Greeting language key: '" .. Config.Merchant.messages.greetingKey .. "'")
    end
    
    QBCore.Functions.Notify(greeting, 'info', 3000)
    
    -- 触发服务端处理销售
    TriggerServerEvent('yx-hunter:server:sellHuntingItems')
end)

-- ==================== 露营系统 ====================
local placedStoves = {} -- 已放置的烤炉
local placedTents = {} -- 已放置的帐篷
local placementMode = false -- 是否在放置模式
local placementType = nil -- 当前放置的物品类型 ("stove" 或 "tent")
local previewObject = nil -- 预览物体
local currentRotation = 0.0 -- 当前旋转角度

-- 全局清理放置模式函数
function ForceCleanupPlacementMode()
    if Config.Debug then
        print("[YX Hunter] Force cleanup placement mode - Mode: " .. tostring(placementMode) .. ", Type: " .. tostring(placementType) .. ", Preview exists: " .. tostring(DoesEntityExist(previewObject)))
    end
    
    placementMode = false
    placementType = nil
    currentRotation = 0.0
    
    if DoesEntityExist(previewObject) then
        DeleteEntity(previewObject)
        previewObject = nil
        if Config.Debug then
            print("[YX Hunter] Deleted preview object during force cleanup")
        end
    end
end

-- 通用放置预览系统
function StartItemPlacement(itemType)
    if not Config.Camping.enabled then 
        QBCore.Functions.Notify("露营系统已禁用", 'error', 3000)
        return 
    end
    
    if placementMode then 
        QBCore.Functions.Notify("已经在放置模式中", 'error', 3000)
        return 
    end
    
    local itemConfig = Config.Camping[itemType]
    if not itemConfig then
        QBCore.Functions.Notify("未知的物品类型", 'error', 3000)
        return
    end
    
    if Config.Debug then
        print("[YX Hunter] Starting " .. itemType .. " placement mode")
    end
    
    placementMode = true
    placementType = itemType
    currentRotation = 0.0
    
    -- 显示指导信息
    QBCore.Functions.Notify(SafeL("notifications.placement_instructions"), 'info', 5000)
    
    -- 预加载模型
    local model = GetHashKey(itemConfig.model)
    if Config.Debug then
        print("[YX Hunter] Loading " .. itemType .. " model: " .. itemConfig.model .. " (hash: " .. model .. ")")
    end
    
    RequestModel(model)
    local attempts = 0
    while not HasModelLoaded(model) and attempts < 100 do
        Wait(50)
        attempts = attempts + 1
    end
    
    if not HasModelLoaded(model) then
        QBCore.Functions.Notify("无法加载" .. itemType .. "模型", 'error', 3000)
        placementMode = false
        placementType = nil
        return
    end
    
    -- 创建预览物体
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    if Config.Debug then
        print("[YX Hunter] Creating preview object at: " .. tostring(playerCoords))
    end
    
    previewObject = CreateObject(model, playerCoords.x + 2.0, playerCoords.y + 2.0, playerCoords.z, false, false, false)
    
    if not DoesEntityExist(previewObject) then
        QBCore.Functions.Notify("无法创建预览物体", 'error', 3000)
        placementMode = false
        SetModelAsNoLongerNeeded(model)
        return
    end
    
    SetEntityAlpha(previewObject, itemConfig.preview.alpha, false)
    SetEntityCollision(previewObject, false, false)
    SetEntityCanBeDamaged(previewObject, false)
    SetEntityInvincible(previewObject, true)
    
    if Config.Debug then
        print("[YX Hunter] Preview object created successfully, entity ID: " .. previewObject)
    end
    
    -- 放置预览循环
    CreateThread(function()
        while placementMode and DoesEntityExist(previewObject) do
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            
            -- 使用摄像机方向计算目标位置
            local camCoord = GetGameplayCamCoord()
            local camRot = GetGameplayCamRot(2)
            local camForward = RotationToDirection(camRot)
            local targetDistance = 5.0 -- 固定距离
            
            local targetCoords = camCoord + (camForward * targetDistance)
            
            -- 根据物品类型获取配置
            local currentItemConfig = Config.Camping[placementType]
            local groundOffset = currentItemConfig and currentItemConfig.preview.groundOffset or 0.1
            local maxDistance = currentItemConfig and currentItemConfig.maxDistance or 10.0
            local bypassGroundCheck = currentItemConfig and currentItemConfig.preview.bypassGroundCheck or false
            
            local finalCoords
            
            if bypassGroundCheck then
                -- 跳过地面检测，直接使用目标坐标，但确保不低于地面
                local groundFound, groundZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 10.0, false)
                local minZ = groundFound and groundZ or targetCoords.z
                local finalZ = math.max(targetCoords.z, minZ) + groundOffset
                finalCoords = vector3(targetCoords.x, targetCoords.y, finalZ)
                if Config.Debug then
                    print("[YX Hunter] Bypassing ground check for " .. placementType .. ", but ensuring min Z: " .. minZ)
                end
            else
                -- 获取地面高度，使用更可靠的方法
                local groundFound, groundZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 10.0, false)
                
                -- 如果找不到地面，使用目标坐标的Z值
                if not groundFound or groundZ == 0.0 then
                    groundZ = targetCoords.z
                    if Config.Debug then
                        print("[YX Hunter] No ground found, using target Z: " .. groundZ)
                    end
                end
                
                finalCoords = vector3(targetCoords.x, targetCoords.y, groundZ + groundOffset)
            end
            
            -- 检查与玩家的距离
            local distance = #(playerCoords - finalCoords)
            
            -- 更新预览物体位置和旋转
            SetEntityCoords(previewObject, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false, false)
            SetEntityHeading(previewObject, currentRotation)
            
            -- 根据距离设置透明度
            if distance <= maxDistance then
                local previewAlpha = currentItemConfig and currentItemConfig.preview.alpha or 150
                SetEntityAlpha(previewObject, previewAlpha, false)
            else
                SetEntityAlpha(previewObject, 80, false) -- 红色表示太远
            end
            
            -- 处理输入
            HandlePlacementInput()
            
            if Config.Debug then
                -- 显示调试信息
                local debugText = string.format("距离: %.1fm | 旋转: %.0f°", distance, currentRotation)
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.4, 0.4)
                SetTextColour(255, 255, 255, 255)
                SetTextEntry("STRING")
                AddTextComponentString(debugText)
                DrawText(0.5, 0.1)
            end
            
            Wait(0)
        end
        
        if Config.Debug then
            print("[YX Hunter] Placement loop ended")
        end
    end)
    
    SetModelAsNoLongerNeeded(model)
end

-- 处理放置模式的输入
function HandlePlacementInput()    
    -- 多种方法检测ESC键
    if IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 322) then 
        if Config.Debug then
            print("[YX Hunter] ESC pressed - cancelling placement")
        end
        CancelItemPlacement()
        return
    end
    
    -- 多种方法检测回车键
    if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 18) or IsDisabledControlJustPressed(0, 191) then 
        if Config.Debug then
            print("[YX Hunter] Enter pressed - confirming placement")
        end
        ConfirmItemPlacement()
        return
    end
    
    -- 鼠标滑轮控制旋转
    if IsControlJustPressed(0, 180) then -- Mouse wheel up
        local currentItemConfig = Config.Camping[placementType]
        local rotationSpeed = currentItemConfig and currentItemConfig.preview.rotationSpeed or 2.0
        currentRotation = currentRotation + rotationSpeed
        if currentRotation >= 360.0 then
            currentRotation = currentRotation - 360.0
        end
        if Config.Debug then
            print("[YX Hunter] Rotated to: " .. currentRotation)
        end
    elseif IsControlJustPressed(0, 181) then -- Mouse wheel down
        local currentItemConfig = Config.Camping[placementType]
        local rotationSpeed = currentItemConfig and currentItemConfig.preview.rotationSpeed or 2.0
        currentRotation = currentRotation - rotationSpeed
        if currentRotation < 0.0 then
            currentRotation = currentRotation + 360.0
        end
        if Config.Debug then
            print("[YX Hunter] Rotated to: " .. currentRotation)
        end
    end
    
    -- 显示控制提示（在屏幕上方显示）
    SetTextFont(0)
    SetTextProportional(1)
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 200)
    SetTextEntry("STRING")
    AddTextComponentString(SafeL("notifications.placement_instructions"))
    DrawText(0.5, 0.05)
end

-- 取消物品放置
function CancelItemPlacement()
    if not placementMode then return end
    
    if Config.Debug then
        print("[YX Hunter] Cancelling " .. (placementType or "item") .. " placement")
    end
    
    placementMode = false
    placementType = nil
    
    if DoesEntityExist(previewObject) then
        DeleteEntity(previewObject)
        previewObject = nil
        if Config.Debug then
            print("[YX Hunter] Preview object deleted")
        end
    end
    
    QBCore.Functions.Notify(SafeL("notifications.placement_cancelled"), 'error', 2000)
end

-- 确认物品放置
function ConfirmItemPlacement()
    if not placementMode then return end
    if not DoesEntityExist(previewObject) then return end
    if not placementType then return end
    
    local itemConfig = Config.Camping[placementType]
    if not itemConfig then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local objectCoords = GetEntityCoords(previewObject)
    local distance = #(playerCoords - objectCoords)
    
    if Config.Debug then
        print("[YX Hunter] Attempting to place " .. placementType .. ":")
        print("  Player coords: " .. tostring(playerCoords))
        print("  Object coords: " .. tostring(objectCoords))
        print("  Distance: " .. distance)
        print("  Max distance: " .. itemConfig.maxDistance)
    end
    
    -- 检查距离
    if distance > itemConfig.maxDistance then
        local tooFarKey = placementType == "tent" and "notifications.tent_too_far" or "notifications.stove_too_far"
        QBCore.Functions.Notify(SafeL(tooFarKey), 'error', 3000)
        if Config.Debug then
            print("[YX Hunter] Placement failed: too far")
        end
        return
    end
    
    local finalCoords
    
    -- 检查是否要绕过地面检测
    if itemConfig.preview.bypassGroundCheck then
        -- 直接使用物体当前位置
        finalCoords = objectCoords
        if Config.Debug then
            print("  Bypassing ground check, using object position: " .. tostring(finalCoords))
        end
    else
        -- 使用原来的地面检测逻辑
        local groundFound, groundZ = GetGroundZFor_3dCoord(objectCoords.x, objectCoords.y, objectCoords.z + 20.0, false)
        
        if Config.Debug then
            print("  Object Z: " .. objectCoords.z)
            print("  Ground found: " .. tostring(groundFound))
            print("  Ground Z: " .. tostring(groundZ))
        end
        
        -- 如果地面检测失败或返回无效值，使用物体当前Z坐标
        if not groundFound or groundZ <= 0 or groundZ > 1000 then
            groundZ = objectCoords.z
            if Config.Debug then
                print("  Using object Z as ground (ground detection failed)")
            end
        end
        
        local heightDiff = math.abs(objectCoords.z - groundZ)
        if Config.Debug then
            print("  Final Ground Z: " .. groundZ)
            print("  Height diff: " .. heightDiff)
        end
        
        -- 大幅放宽地面检测条件
        if heightDiff > 20.0 then
            groundZ = objectCoords.z
            if Config.Debug then
                print("  Ground detection seems unreliable, using object position")
            end
        end
        
        finalCoords = vector3(objectCoords.x, objectCoords.y, groundZ + itemConfig.preview.groundOffset)
    end
    
    if Config.Debug then
        print("[YX Hunter] Final placement coords: " .. tostring(finalCoords))
    end
    
    -- 临时结束放置模式以避免干扰
    local tempCoords = finalCoords
    local tempRotation = currentRotation
    placementMode = false
    if DoesEntityExist(previewObject) then
        DeleteEntity(previewObject)
        previewObject = nil
    end
    
    -- 开始放置进度条
    local progressLabel = SafeL("interactions.placing_" .. placementType)
    if progressLabel == ("interactions.placing_" .. placementType) then
        if placementType == "tent" then
            progressLabel = "搭建帐篷中..."
            if Config.Language == 'en' then
                progressLabel = "Setting up tent..."
            end
        else
            progressLabel = "放置烤炉中..."
            if Config.Language == 'en' then
                progressLabel = "Placing stove..."
            end
        end
    end
    
    exports['progressbar']:Progress({
        name = "placing_" .. placementType,
        duration = itemConfig.placement.duration,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = itemConfig.placement.animation.dict,
            anim = itemConfig.placement.animation.name,
        }
    }, function(cancelled)
        -- 停止动画
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        
        if not cancelled then
            -- 进度条完成，发送放置请求到服务端
            if placementType == "tent" then
                TriggerServerEvent('yx-hunter:server:placeTent', {
                    coords = tempCoords,
                    heading = tempRotation
                })
            else
                TriggerServerEvent('yx-hunter:server:placeStove', {
                    coords = tempCoords,
                    heading = tempRotation
                })
            end
            
            if Config.Debug then
                print("[YX Hunter] " .. placementType .. " placement progress completed, sent to server")
            end
        else
            if Config.Debug then
                print("[YX Hunter] " .. placementType .. " placement cancelled during progress")
            end
            QBCore.Functions.Notify(SafeL("notifications.placement_cancelled"), 'error', 2000)
        end
    end)
end

-- 旋转转方向向量
function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    
    return vector3(
        -math.sin(z) * num,
        math.cos(z) * num,
        math.sin(x)
    )
end

-- 处理烤炉放置成功
RegisterNetEvent('yx-hunter:client:stovePlaced', function(stoveData)
    -- 强制清理放置模式
    ForceCleanupPlacementMode()
    
    local model = GetHashKey(Config.Camping.stove.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- 创建烤炉对象
    local stove = CreateObject(model, stoveData.coords.x, stoveData.coords.y, stoveData.coords.z, false, false, false)
    SetEntityHeading(stove, stoveData.heading)
    PlaceObjectOnGroundProperly(stove)
    FreezeEntityPosition(stove, true)
    
    -- 存储烤炉信息
    placedStoves[stoveData.id] = {
        entity = stove,
        coords = stoveData.coords,
        heading = stoveData.heading,
        owner = stoveData.owner
    }
    
    -- 添加qb-target交互
    local interactionLabel = SafeL("interactions.use_stove")
    if interactionLabel == "interactions.use_stove" then
        interactionLabel = "使用烤炉"
        if Config.Language == 'en' then
            interactionLabel = "Use Stove"
        end
    end
    
    -- 获取移除标签
    local removeLabel = SafeL("interactions.remove_stove")
    if removeLabel == "interactions.remove_stove" then
        removeLabel = "收回烤炉"
        if Config.Language == 'en' then
            removeLabel = "Remove Stove"
        end
    end
    
    exports['qb-target']:AddTargetEntity(stove, {
        options = {
            {
                type = "client",
                event = "yx-hunter:client:useStove",
                icon = Config.Camping.stove.interaction.targetIcon,
                label = interactionLabel,
                stoveId = stoveData.id
            },
            {
                type = "client", 
                event = "yx-hunter:client:removeStove",
                icon = "fas fa-trash",
                label = removeLabel,
                stoveId = stoveData.id,
                canInteract = function(entity, distance, data)
                    -- 简化权限检查，避免复杂的逻辑
                    local playerServerId = GetPlayerServerId(PlayerId())
                    local stoveData = placedStoves[data.stoveId]
                    
                    if not stoveData then
                        if Config.Debug then
                            print("[YX Hunter] canInteract: Stove data not found for " .. tostring(data.stoveId))
                        end
                        return false
                    end
                    
                    local canRemove = stoveData.owner == playerServerId
                    if Config.Debug then
                        print("[YX Hunter] canInteract check - Player: " .. playerServerId .. ", Owner: " .. stoveData.owner .. ", Can remove: " .. tostring(canRemove))
                    end
                    return canRemove
                end
            }
        },
        distance = Config.Camping.stove.interaction.distance
    })
    
    QBCore.Functions.Notify(SafeL("notifications.stove_placed"), 'success', 3000)
    SetModelAsNoLongerNeeded(model)
end)

-- 处理帐篷放置成功
RegisterNetEvent('yx-hunter:client:tentPlaced', function(tentData)
    -- 强制清理放置模式
    ForceCleanupPlacementMode()
    
    local model = GetHashKey(Config.Camping.tent.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- 创建帐篷对象
    local tent = CreateObject(model, tentData.coords.x, tentData.coords.y, tentData.coords.z, false, false, false)
    SetEntityHeading(tent, tentData.heading)
    
    -- 等待实体完全加载
    Wait(100)
    
    -- 确保帐篷正确贴地
    local success = PlaceObjectOnGroundProperly(tent)
    if Config.Debug then
        print("[YX Hunter] PlaceObjectOnGroundProperly result: " .. tostring(success))
        print("[YX Hunter] Tent coords before adjustment: " .. tostring(GetEntityCoords(tent)))
    end
    
    -- 无论自动贴地是否成功，都进行额外的地面检测以确保帐篷贴地
    local currentCoords = GetEntityCoords(tent)
    local groundFound, groundZ = GetGroundZFor_3dCoord(currentCoords.x, currentCoords.y, currentCoords.z + 20.0, false)
    
    if groundFound and groundZ > -1000.0 then
        -- 将帐篷放置在地面上，应用配置的偏移
        local finalZ = groundZ + Config.Camping.tent.preview.groundOffset
        SetEntityCoordsNoOffset(tent, currentCoords.x, currentCoords.y, finalZ, false, false, false)
        
        if Config.Debug then
            print("[YX Hunter] Final tent placement - Ground Z: " .. groundZ .. ", Final Z: " .. finalZ)
            print("[YX Hunter] Tent coords after adjustment: " .. tostring(GetEntityCoords(tent)))
        end
    elseif Config.Debug then
        print("[YX Hunter] Ground detection failed for tent, keeping original position")
    end
    
    FreezeEntityPosition(tent, true)
    
    -- 存储帐篷信息
    placedTents[tentData.id] = {
        entity = tent,
        coords = tentData.coords,
        heading = tentData.heading,
        owner = tentData.owner
    }
    
    -- 添加qb-target交互（只有移除功能）
    local removeLabel = SafeL("interactions.remove_tent")
    if removeLabel == "interactions.remove_tent" then
        removeLabel = "收回帐篷"
        if Config.Language == 'en' then
            removeLabel = "Remove Tent"
        end
    end
    
    exports['qb-target']:AddTargetEntity(tent, {
        options = {
            {
                type = "client", 
                event = "yx-hunter:client:removeTent",
                icon = Config.Camping.tent.interaction.targetIcon,
                label = removeLabel,
                tentId = tentData.id,
                canInteract = function(entity, distance, data)
                    -- 简化权限检查
                    local playerServerId = GetPlayerServerId(PlayerId())
                    local tentData = placedTents[data.tentId]
                    
                    if not tentData then
                        if Config.Debug then
                            print("[YX Hunter] canInteract: Tent data not found for " .. tostring(data.tentId))
                        end
                        return false
                    end
                    
                    local canRemove = tentData.owner == playerServerId
                    if Config.Debug then
                        print("[YX Hunter] canInteract check - Player: " .. playerServerId .. ", Owner: " .. tentData.owner .. ", Can remove: " .. tostring(canRemove))
                    end
                    return canRemove
                end
            }
        },
        distance = Config.Camping.tent.interaction.distance
    })
    
    QBCore.Functions.Notify(SafeL("notifications.tent_placed"), 'success', 3000)
    SetModelAsNoLongerNeeded(model)
end)

-- 处理烤炉移除
RegisterNetEvent('yx-hunter:client:stoveRemoved', function(stoveId)
    if Config.Debug then
        print("[YX Hunter] Client received stoveRemoved event for ID: " .. stoveId)
    end
    
    if placedStoves[stoveId] then
        local stove = placedStoves[stoveId].entity
        if Config.Debug then
            print("[YX Hunter] Found stove in placedStoves, entity: " .. tostring(stove))
            print("[YX Hunter] Entity exists: " .. tostring(DoesEntityExist(stove)))
        end
        
        if DoesEntityExist(stove) then
            exports['qb-target']:RemoveTargetEntity(stove)
            DeleteEntity(stove)
            if Config.Debug then
                print("[YX Hunter] Removed target and deleted entity")
            end
        end
        placedStoves[stoveId] = nil
        
        if Config.Debug then
            print("[YX Hunter] Cleared stove from placedStoves table")
        end
    else
        if Config.Debug then
            print("[YX Hunter] Stove not found in placedStoves table")
        end
    end
end)

-- 处理帐篷移除
RegisterNetEvent('yx-hunter:client:tentRemoved', function(tentId)
    if Config.Debug then
        print("[YX Hunter] Client received tentRemoved event for ID: " .. tentId)
    end
    
    if placedTents[tentId] then
        local tent = placedTents[tentId].entity
        if Config.Debug then
            print("[YX Hunter] Found tent in placedTents, entity: " .. tostring(tent))
            print("[YX Hunter] Entity exists: " .. tostring(DoesEntityExist(tent)))
        end
        
        if DoesEntityExist(tent) then
            exports['qb-target']:RemoveTargetEntity(tent)
            DeleteEntity(tent)
            if Config.Debug then
                print("[YX Hunter] Removed target and deleted entity")
            end
        end
        placedTents[tentId] = nil
        
        if Config.Debug then
            print("[YX Hunter] Cleared tent from placedTents table")
        end
    else
        if Config.Debug then
            print("[YX Hunter] Tent not found in placedTents table")
        end
    end
end)

-- 使用烤炉
RegisterNetEvent('yx-hunter:client:useStove', function(data)
    local stoveId = data.stoveId
    if not placedStoves[stoveId] then return end
    
    -- 强制清理任何残留的放置模式
    ForceCleanupPlacementMode()
    
    -- 获取玩家背包中的可烹饪肉类
    QBCore.Functions.TriggerCallback('yx-hunter:server:getAvailableMeat', function(availableMeat)
        if #availableMeat == 0 then
            QBCore.Functions.Notify(SafeL("notifications.no_meat_to_cook"), 'error', 3000)
            return
        end
        
        -- 创建ox_lib菜单选项
        local options = {}
        for _, meatData in pairs(availableMeat) do
            table.insert(options, {
                title = meatData.label .. " (x" .. meatData.amount .. ")",
                description = "烹饪时间: " .. math.floor(meatData.cookTime/1000) .. "秒",
                icon = 'utensils',
                onSelect = function()
                    -- 开始烹饪这种肉类
                    TriggerServerEvent('yx-hunter:server:startCooking', {
                        stoveId = stoveId,
                        selectedMeat = meatData.input
                    })
                end
            })
        end
        
        -- 显示ox_lib菜单
        local menuTitle = SafeL("notifications.select_meat_title")
        if menuTitle == "notifications.select_meat_title" then
            menuTitle = "选择要烹饪的肉类"
            if Config.Language == 'en' then
                menuTitle = "Select Meat to Cook"
            end
        end
        
        lib.registerContext({
            id = 'cooking_menu',
            title = menuTitle,
            options = options
        })
        
        lib.showContext('cooking_menu')
        
    end)
end)

-- 移除烤炉
RegisterNetEvent('yx-hunter:client:removeStove', function(data)
    local stoveId = data.stoveId
    if not placedStoves[stoveId] then 
        if Config.Debug then
            print("[YX Hunter] Cannot remove stove: stove not found in placedStoves")
        end
        return 
    end
    
    -- 强制清理任何残留的放置模式
    ForceCleanupPlacementMode()
    
    -- 只有主人可以移除
    local playerServerId = GetPlayerServerId(PlayerId())
    if placedStoves[stoveId].owner ~= playerServerId then
        QBCore.Functions.Notify("只有主人可以移除这个烤炉！", 'error', 3000)
        if Config.Debug then
            print("[YX Hunter] Cannot remove stove: not owner (Player: " .. playerServerId .. ", Owner: " .. placedStoves[stoveId].owner .. ")")
        end
        return
    end
    
    if Config.Debug then
        print("[YX Hunter] Starting stove removal process for stove: " .. stoveId)
    end
    
    -- 开始收回进度条
    local progressLabel = SafeL("interactions.removing_stove")
    if progressLabel == "interactions.removing_stove" then
        progressLabel = "收回烤炉中..."
        if Config.Language == 'en' then
            progressLabel = "Removing stove..."
        end
    end
    
    exports['progressbar']:Progress({
        name = "removing_stove",
        duration = Config.Camping.stove.removal.duration,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = Config.Camping.stove.removal.animation.dict,
            anim = Config.Camping.stove.removal.animation.name,
        }
    }, function(cancelled)
        -- 停止动画
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        
        if not cancelled then
            -- 进度条完成，发送移除请求到服务端
            TriggerServerEvent('yx-hunter:server:removeStove', stoveId)
            
            if Config.Debug then
                print("[YX Hunter] Stove removal progress completed, sent to server")
            end
        else
            if Config.Debug then
                print("[YX Hunter] Stove removal cancelled during progress")
            end
            QBCore.Functions.Notify("收回取消", 'error', 2000)
        end
    end)
end)

-- 移除帐篷
RegisterNetEvent('yx-hunter:client:removeTent', function(data)
    local tentId = data.tentId
    if not placedTents[tentId] then 
        if Config.Debug then
            print("[YX Hunter] Cannot remove tent: tent not found in placedTents")
        end
        return 
    end
    
    -- 强制清理任何残留的放置模式
    ForceCleanupPlacementMode()
    
    -- 只有主人可以移除
    local playerServerId = GetPlayerServerId(PlayerId())
    if placedTents[tentId].owner ~= playerServerId then
        QBCore.Functions.Notify("只有主人可以移除这个帐篷！", 'error', 3000)
        if Config.Debug then
            print("[YX Hunter] Cannot remove tent: not owner (Player: " .. playerServerId .. ", Owner: " .. placedTents[tentId].owner .. ")")
        end
        return
    end
    
    if Config.Debug then
        print("[YX Hunter] Starting tent removal process for tent: " .. tentId)
    end
    
    -- 开始收回进度条
    local progressLabel = SafeL("interactions.removing_tent")
    if progressLabel == "interactions.removing_tent" then
        progressLabel = "收回帐篷中..."
        if Config.Language == 'en' then
            progressLabel = "Packing tent..."
        end
    end
    
    exports['progressbar']:Progress({
        name = "removing_tent",
        duration = Config.Camping.tent.removal.duration,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = Config.Camping.tent.removal.animation.dict,
            anim = Config.Camping.tent.removal.animation.name,
        }
    }, function(cancelled)
        -- 停止动画
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        
        if not cancelled then
            -- 进度条完成，发送移除请求到服务端
            TriggerServerEvent('yx-hunter:server:removeTent', tentId)
            
            if Config.Debug then
                print("[YX Hunter] Tent removal progress completed, sent to server")
            end
        else
            if Config.Debug then
                print("[YX Hunter] Tent removal cancelled during progress")
            end
            QBCore.Functions.Notify("收回取消", 'error', 2000)
        end
    end)
end)

-- 开始烤炉放置
function StartStovePlacement()
    StartItemPlacement("stove")
end

-- 开始帐篷放置
function StartTentPlacement()
    StartItemPlacement("tent")
end

-- 物品使用事件 - 烤炉
RegisterNetEvent('yx-hunter:client:useStoveItem', function()
    if Config.Debug then
        print("[YX Hunter] Received useStoveItem event")
    end
    StartStovePlacement()
end)

-- 物品使用事件 - 帐篷
RegisterNetEvent('yx-hunter:client:useTentItem', function()
    if Config.Debug then
        print("[YX Hunter] Received useTentItem event")
    end
    StartTentPlacement()
end)

-- 调试命令 - 测试烤炉放置
if Config.Debug then
    RegisterCommand('teststove', function(source, args, rawCommand)
        print("[YX Hunter] Testing stove placement...")
        print("  Config.Camping.enabled: " .. tostring(Config.Camping.enabled))
        print("  placementMode: " .. tostring(placementMode))
        print("  Config.Camping.stove exists: " .. tostring(Config.Camping.stove ~= nil))
        if Config.Camping.stove then
            print("  Stove model: " .. tostring(Config.Camping.stove.model))
            print("  Stove itemName: " .. tostring(Config.Camping.stove.itemName))
        end
        StartStovePlacement()
    end, false)
    
    RegisterCommand('groundtest', function(source, args, rawCommand)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local camCoord = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        local camForward = RotationToDirection(camRot)
        local targetCoords = camCoord + (camForward * 5.0)
        
        print("=== Ground Test ===")
        print("Player coords: " .. tostring(playerCoords))
        print("Target coords: " .. tostring(targetCoords))
        
        local groundFound, groundZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 10.0, false)
        print("Ground found: " .. tostring(groundFound))
        print("Ground Z: " .. tostring(groundZ))
        
        local distance = #(playerCoords - targetCoords)
        print("Distance: " .. distance)
        print("Max distance: " .. Config.Camping.stove.maxDistance)
        print("Can place: " .. tostring(distance <= Config.Camping.stove.maxDistance))
    end, false)
    
    RegisterCommand('cancelstove', function(source, args, rawCommand)
        if placementMode then
            print("[YX Hunter] Forcing cancellation of item placement")
            CancelItemPlacement()
        else
            print("[YX Hunter] Not in placement mode")
        end
    end, false)
    
    RegisterCommand('forcestove', function(source, args, rawCommand)
        if placementMode and DoesEntityExist(previewObject) then
            print("[YX Hunter] Forcing item placement")
            ConfirmItemPlacement()
        else
            print("[YX Hunter] Not in placement mode or no preview object")
        end
    end, false)
    
    RegisterCommand('liststoves', function(source, args, rawCommand)
        print("=== Placed Stoves ===")
        local count = 0
        for stoveId, stoveData in pairs(placedStoves) do
            count = count + 1
            print("Stove " .. count .. ":")
            print("  ID: " .. stoveId)
            print("  Owner: " .. stoveData.owner)
            print("  Coords: " .. tostring(stoveData.coords))
            print("  Entity exists: " .. tostring(DoesEntityExist(stoveData.entity)))
        end
        if count == 0 then
            print("No stoves placed")
        end
    end, false)
    
    RegisterCommand('testcook', function(source, args, rawCommand)
        -- 测试烹饪菜单
        QBCore.Functions.TriggerCallback('yx-hunter:server:getAvailableMeat', function(availableMeat)
            if #availableMeat == 0 then
                print("No meat available for cooking")
                return
            end
            
            print("=== Available Meat for Cooking ===")
            for i, meatData in pairs(availableMeat) do
                print("Meat " .. i .. ":")
                print("  Input: " .. meatData.input)
                print("  Label: " .. meatData.label)
                print("  Amount: " .. meatData.amount)
                print("  Cook time: " .. meatData.cookTime .. "ms")
                print("  Output: " .. meatData.output)
            end
        end)
    end, false)
    
    RegisterCommand('cleanstove', function(source, args, rawCommand)
        print("[YX Hunter] Forcing cleanup of placement mode")
        ForceCleanupPlacementMode()
        print("[YX Hunter] Cleanup completed")
    end, false)
    
    RegisterCommand('testtent', function(source, args, rawCommand)
        StartTentPlacement()
    end, false)
    
    RegisterCommand('listtents', function(source, args, rawCommand)
        print("=== Placed Tents ===")
        local count = 0
        for tentId, tentData in pairs(placedTents) do
            count = count + 1
            print("Tent " .. count .. ":")
            print("  ID: " .. tentId)
            print("  Owner: " .. tentData.owner)
            print("  Coords: " .. tostring(tentData.coords))
            print("  Entity exists: " .. tostring(DoesEntityExist(tentData.entity)))
            if DoesEntityExist(tentData.entity) then
                local entityCoords = GetEntityCoords(tentData.entity)
                print("  Current entity coords: " .. tostring(entityCoords))
            end
        end
        if count == 0 then
            print("No tents placed")
        end
    end, false)
    
    RegisterCommand('fixtent', function(source, args, rawCommand)
        print("=== Fixing All Tent Positions ===")
        local fixed = 0
        for tentId, tentData in pairs(placedTents) do
            if DoesEntityExist(tentData.entity) then
                local tent = tentData.entity
                local currentCoords = GetEntityCoords(tent)
                local groundFound, groundZ = GetGroundZFor_3dCoord(currentCoords.x, currentCoords.y, currentCoords.z + 20.0, false)
                
                if groundFound and groundZ > -1000.0 then
                    local finalZ = groundZ + Config.Camping.tent.preview.groundOffset
                    SetEntityCoordsNoOffset(tent, currentCoords.x, currentCoords.y, finalZ, false, false, false)
                    PlaceObjectOnGroundProperly(tent)
                    fixed = fixed + 1
                    print("Fixed tent " .. tentId .. " - moved from Z:" .. currentCoords.z .. " to Z:" .. finalZ)
                end
            end
        end
        print("Fixed " .. fixed .. " tents")
    end, false)
    
    -- 强制调试烤炉放置（即使Debug=false也可用）
    RegisterCommand('debugstove', function(source, args, rawCommand)
        print("[YX Hunter] Force debugging stove placement...")
        print("  Config.Camping.enabled: " .. tostring(Config.Camping.enabled))
        print("  placementMode: " .. tostring(placementMode))
        print("  Config.Camping.stove exists: " .. tostring(Config.Camping.stove ~= nil))
        if Config.Camping.stove then
            print("  Stove model: " .. tostring(Config.Camping.stove.model))
            print("  Stove itemName: " .. tostring(Config.Camping.stove.itemName))
        end
        StartStovePlacement()
    end, false)
    
    -- 测试地面检测
    RegisterCommand('testground', function(source, args, rawCommand)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local camCoord = GetGameplayCamCoord()
        local camRot = GetGameplayCamRot(2)
        
        print("=== Ground Detection Test ===")
        print("Player coords: " .. tostring(playerCoords))
        print("Camera coords: " .. tostring(camCoord))
        
        for distance = 1, 10, 2 do
            local camForward = RotationToDirection(camRot)
            local targetCoords = camCoord + (camForward * distance)
            
            local groundFound, groundZ = GetGroundZFor_3dCoord(targetCoords.x, targetCoords.y, targetCoords.z + 10.0, false)
            print("Distance " .. distance .. "m - Target: " .. tostring(targetCoords) .. " -> Ground found: " .. tostring(groundFound) .. ", Z: " .. tostring(groundZ))
        end
    end, false)
    
    -- 检查附近动物类型
    RegisterCommand('checkanimal', function(source, args, rawCommand)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        print("=== Nearby Animals Check ===")
        
        -- 检查脚本动物
        local scriptCount = 0
        for _, animal in pairs(syncedAnimals) do
            if DoesEntityExist(animal.entity) then
                local animalCoords = GetEntityCoords(animal.entity)
                local distance = #(playerCoords - animalCoords)
                if distance <= 50.0 then
                    scriptCount = scriptCount + 1
                    print("Script Animal " .. scriptCount .. ":")
                    print("  ID: " .. animal.id)
                    print("  Type: " .. SafeGetAnimalName(animal.animalKey))
                    print("  Distance: " .. string.format("%.1f", distance) .. "m")
                    print("  Dead: " .. tostring(animal.isDead))
                    print("  Has Target: " .. tostring(animal.hasTarget))
                end
            end
        end
        
        -- 检查原版动物（基于模型哈希）
        local nativeCount = 0
        local nativeModels = {
            [GetHashKey("a_c_boar")] = "Native Boar",
            [GetHashKey("a_c_coyote")] = "Native Coyote", 
            [GetHashKey("a_c_deer")] = "Native Deer",
            [GetHashKey("a_c_rabbit_01")] = "Native Rabbit",
            [GetHashKey("a_c_mtlion")] = "Native Mountain Lion"
        }
        
        for model, name in pairs(nativeModels) do
            local handle, ped = FindFirstPed()
            local success = true
            
            repeat
                if DoesEntityExist(ped) and GetEntityModel(ped) == model then
                    local pedCoords = GetEntityCoords(ped)
                    local distance = #(playerCoords - pedCoords)
                    if distance <= 50.0 then
                        nativeCount = nativeCount + 1
                        print("Native Animal " .. nativeCount .. ":")
                        print("  Type: " .. name)
                        print("  Distance: " .. string.format("%.1f", distance) .. "m")
                        print("  Dead: " .. tostring(IsEntityDead(ped)))
                        print("  WARNING: This is a native animal and cannot be harvested!")
                    end
                end
                success, ped = FindNextPed(handle)
            until not success
            
            EndFindPed(handle)
        end
        
        print("Summary: " .. scriptCount .. " script animals, " .. nativeCount .. " native animals")
        if nativeCount > 0 and Config.SpawnSettings.disableNativeAnimals then
            print("WARNING: Native animals detected but should be disabled! Check config.")
        end
    end, false)
    
    -- 测试交互距离
    RegisterCommand('testinteract', function(source, args, rawCommand)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        
        print("=== Interaction Distance Test ===")
        
        for _, animal in pairs(syncedAnimals) do
            if DoesEntityExist(animal.entity) and animal.isDead then
                local animalCoords = GetEntityCoords(animal.entity)
                local distance = #(playerCoords - animalCoords)
                local canInteract = distance <= 15.0
                
                print("Dead Animal:")
                print("  Type: " .. SafeGetAnimalName(animal.animalKey))
                print("  Distance: " .. string.format("%.1f", distance) .. "m")
                print("  Can Interact: " .. tostring(canInteract))
                print("  Has Target: " .. tostring(animal.hasTarget))
            end
        end
    end, false)
end

-- 开始烹饪进度条
RegisterNetEvent('yx-hunter:client:startCookingProgress', function(data)
    local recipe = data.recipe
    local stoveId = data.stoveId
    
    if not placedStoves[stoveId] then return end
    
    -- 烹饪进度条
    local progressLabel = SafeL("interactions.cooking_progress")
    if progressLabel == "interactions.cooking_progress" then
        progressLabel = "烹饪中..."
        if Config.Language == 'en' then
            progressLabel = "Cooking..."
        end
    end
    
    exports['progressbar']:Progress({
        name = "cooking_" .. stoveId,
        duration = recipe.cookTime,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = "amb@prop_human_bbq@male@idle_a",
            anim = "idle_b",
        }
    }, function(cancelled)
        -- 停止动画
        local playerPed = PlayerPedId()
        ClearPedTasks(playerPed)
        
        if not cancelled then
            -- 烹饪完成
            TriggerServerEvent('yx-hunter:server:completeCooking', {
                recipe = recipe,
                stoveId = stoveId
            })
        end
    end)
end)

-- 初始化脚本
CreateThread(function()
    Wait(2000) -- 增加等待时间确保所有脚本加载完成
    
    -- 调试: 检查语言系统是否加载
    if Config.Debug then
        if _L then
            print("[YX Hunter] Language system loaded successfully")
            print("[YX Hunter] Current language: " .. (Config.Language or "unknown"))
            print("[YX Hunter] Test translation: " .. SafeL("interactions.harvesting_progress"))
        else
            print("[YX Hunter] Language system not loaded, using defaults")
            print("[YX Hunter] Test translation: " .. SafeL("interactions.harvesting_progress"))
        end
    end
    
    -- 根据配置决定是否禁用原生动物刷新
    if Config.SpawnSettings.disableNativeAnimals then
        DisableNativeAnimalSpawning()
        if Config.Debug then
            print("[YX Hunter] Native animal spawning disabled - only script animals will spawn in hunting zones")
        end
    else
        if Config.Debug then
            print("[YX Hunter] WARNING: Native animals enabled - may conflict with script animals")
        end
    end
    
    CreateHuntingZones()
    StartSyncedAnimalLoop()
    
    -- 延迟创建收货商人，确保所有系统加载完成
    if Config.Merchant.enabled then
        Wait(1000) -- 额外等待确保语言系统加载
        CreateHuntingMerchant()
    end
end)

-- 清理现有地图标记
function ClearHuntingZones()
    for _, blip in pairs(huntingBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    huntingBlips = {}
end

-- 创建打猎区域标记
function CreateHuntingZones()
    for i, zone in pairs(Config.HuntingZones) do
        -- 创建中心点标记
        local blip = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
        SetBlipSprite(blip, zone.blip.sprite)
        SetBlipDisplay(blip, 4) -- 强制设置为4 (both map and minimap)
        SetBlipScale(blip, zone.blip.scale)
        SetBlipColour(blip, zone.blip.color)
        SetBlipAsShortRange(blip, true)
        
        -- 设置blip名称
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(SafeGetZoneName(zone.nameKey))
        EndTextCommandSetBlipName(blip)
        
        table.insert(huntingBlips, blip)
        
        -- 创建区域范围标记
        local radiusBlip = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius)
        SetBlipHighDetail(radiusBlip, true)
        SetBlipColour(radiusBlip, zone.blip.color)
        SetBlipAlpha(radiusBlip, 128) -- 半透明
        
        table.insert(huntingBlips, radiusBlip)
        
        if Config.Debug then
            print(SafeL("debug.zone_created", SafeGetZoneName(zone.nameKey), tostring(zone.coords), zone.radius))
        end
    end
end

-- 同步动物状态循环
function StartSyncedAnimalLoop()
    CreateThread(function()
        local cleanupCounter = 0
        
        while true do
            -- 检查同步动物的死亡状态
            CheckSyncedAnimalDeathStatus()
            
            -- 每30秒进行一次内存清理
            cleanupCounter = cleanupCounter + 1
            if cleanupCounter >= 30 then
                CleanupInvalidAnimals()
                cleanupCounter = 0
            end
            
            Wait(1000) -- 优化: 从0.5秒增加到1秒，减少CPU负载
        end
    end)
end

-- 计算区域内动物数量 (优化版本 - 批量检查实体存在性)
function CountAnimalsInZone(zoneIndex)
    local count = 0
    local entitiesToCheck = {}
    
    -- 先收集需要检查的实体
    for _, animal in pairs(spawnedAnimals) do
        if animal.zone == zoneIndex then
            table.insert(entitiesToCheck, animal.entity)
        end
    end
    
    -- 批量检查实体存在性
    for _, entity in pairs(entitiesToCheck) do
        if DoesEntityExist(entity) then
            count = count + 1
        end
    end
    
    return count
end

-- 计算区域内特定动物类型的数量 (优化版本)
function CountSpecificAnimalInZone(zoneIndex, animalKey)
    local count = 0
    local entitiesToCheck = {}
    
    -- 先收集需要检查的实体
    for _, animal in pairs(spawnedAnimals) do
        if animal.zone == zoneIndex and animal.animalKey == animalKey then
            table.insert(entitiesToCheck, animal.entity)
        end
    end
    
    -- 批量检查实体存在性
    for _, entity in pairs(entitiesToCheck) do
        if DoesEntityExist(entity) then
            count = count + 1
        end
    end
    
    return count
end

-- 尝试刷新特定动物
function TrySpawnSpecificAnimal(zone, zoneIndex, animalKey, animalConfig)
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    -- 寻找合适的刷新点
    local spawnCoords = FindSuitableSpawnLocation(zone, playerCoords)
    if not spawnCoords then 
        if Config.Debug then
            print(SafeL("debug.no_spawn_point"))
        end
        return 
    end
    
    -- 刷新动物
    SpawnAnimal(animalConfig, spawnCoords, zoneIndex, animalKey)
end

-- 寻找合适的刷新位置
function FindSuitableSpawnLocation(zone, playerCoords)
    local attempts = 0
    local maxAttempts = 15
    
    while attempts < maxAttempts do
        local angle = math.random() * 2 * math.pi
        local distance = math.random(Config.SpawnSettings.spawnDistance, Config.SpawnSettings.maxSpawnDistance)
        
        local x = zone.coords.x + math.cos(angle) * distance
        local y = zone.coords.y + math.sin(angle) * distance
        
        -- 获取地面高度，从较高位置开始搜索
        local found, z = GetGroundZFor_3dCoord(x, y, zone.coords.z + 100.0, false)
        
        if found then
            local spawnCoords = vector3(x, y, z + 1.0) -- 稍微抬高一点避免卡在地面
            local distanceToPlayer = #(spawnCoords - playerCoords)
            
            -- 确保不在玩家附近刷新
            if distanceToPlayer >= Config.SpawnSettings.spawnDistance then
                -- 额外检查：确保不在水中
                local waterHeight = GetWaterHeight(x, y, z)
                local isInWater = false
                
                -- 检查水位高度（GetWaterHeight 可能返回 boolean 或 number）
                if type(waterHeight) == "number" and waterHeight > -1000000.0 then
                    isInWater = (z <= waterHeight)
                end
                
                if not isInWater then
                    if Config.Debug then
                        print(SafeL("debug.spawn_point_found", tostring(spawnCoords), math.floor(distanceToPlayer)))
                    end
                    return spawnCoords
                else
                    if Config.Debug then
                        print(SafeL("debug.skip_water", tostring(spawnCoords)))
                    end
                end
            end
        else
            if Config.Debug then
                print(SafeL("debug.no_ground_found", x, y, zone.coords.z))
            end
        end
        
        attempts = attempts + 1
    end
    
    if Config.Debug then
        print(SafeL("debug.spawn_attempts_failed", maxAttempts))
    end
    return nil
end

-- 刷新动物
function SpawnAnimal(animalConfig, coords, zoneIndex, animalKey)
    local hash = GetHashKey(animalConfig.model)
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    
    -- 创建动物 (使用动物PED组：28 = MOVE_GROUPS_ANIMAL)
    local animal = CreatePed(28, hash, coords.x, coords.y, coords.z, math.random(0, 360), false, false)
    
    -- 等待实体完全创建
    Wait(100)
    
    if DoesEntityExist(animal) then
        -- 设置实体属性
        SetEntityAsMissionEntity(animal, true, true)
        SetPedCanRagdoll(animal, true)
        SetEntityInvincible(animal, false)
        
        -- 确保动物在地面上
        PlaceObjectOnGroundProperly(animal)
        
        -- 设置生命值
        SetEntityMaxHealth(animal, animalConfig.health)
        SetEntityHealth(animal, animalConfig.health)
        
        -- 确认动物还活着
        if GetEntityHealth(animal) <= 0 then
            SetEntityHealth(animal, animalConfig.health)
            if Config.Debug then
                print(SafeL("debug.animal_health_reset"))
            end
        end
        
        -- 设置动物行为
        SetPedFleeAttributes(animal, 0, 0)
        SetPedCombatAttributes(animal, 17, 1)
        SetBlockingOfNonTemporaryEvents(animal, false)
        
        -- 给动物一些初始任务
        TaskWanderStandard(animal, 10.0, 10)
        
        -- 存储动物信息
        local animalData = {
            entity = animal,
            config = animalConfig,
            zone = zoneIndex,
            animalKey = animalKey,
            spawnTime = GetGameTimer(),
            isDead = false,
            isHarvested = false
        }
        
        table.insert(spawnedAnimals, animalData)
        
        if Config.Debug then
            local health = GetEntityHealth(animal)
            print(SafeL("debug.animal_spawned_debug", SafeGetAnimalName(animalKey), animalKey, zoneIndex))
            print(SafeL("debug.spawn_coords", tostring(coords)))
            print(SafeL("debug.spawn_health", health, animalConfig.health))
            print(SafeL("debug.spawn_entity", animal))
        end
    else
        if Config.Debug then
            print(SafeL("debug.entity_creation_failed"))
        end
    end
    
    SetModelAsNoLongerNeeded(hash)
end

-- 检查同步动物死亡状态
function CheckSyncedAnimalDeathStatus()
    local playerCoords = GetEntityCoords(PlayerPedId())
    
    for _, animal in pairs(syncedAnimals) do
        if DoesEntityExist(animal.entity) and not animal.isDead then
            if IsEntityDead(animal.entity) then
                animal.isDead = true
                
                -- 通知服务端动物已死亡 (只通知一次)
                TriggerServerEvent('yx-hunter:server:animalDied', animal.id)
                
                -- 为本地检测到的死亡动物也添加收获目标
                CreateThread(function()
                    Wait(500) -- 等待服务端处理
                    if DoesEntityExist(animal.entity) and IsEntityDead(animal.entity) and not animal.hasTarget then
                        animal.hasTarget = true -- 标记已添加目标，避免重复
                        AddAnimalHarvestTarget(animal)
                        if Config.Debug then
                            print(SafeL("debug.add_harvest_dead", SafeGetAnimalName(animal.animalKey), animal.id))
                        end
                    end
                end)
                
                if Config.Debug then
                    print(SafeL("debug.death_detected", SafeGetAnimalName(animal.animalKey), animal.id))
                end
            end
        elseif animal.isDead and not DoesEntityExist(animal.entity) and not animal.hasTarget then
            -- 动物已死亡但实体不存在，且玩家接近时尝试重新创建
            if animal.coords then
                local distance = #(playerCoords - animal.coords)
                if distance < 150.0 and not animal.recreating then
                    animal.recreating = true -- 防止重复创建
                    
                    if Config.Debug then
                        print("[YX Hunter] Dead animal entity missing, recreating near player: " .. SafeGetAnimalName(animal.animalKey))
                    end
                    
                    CreateThread(function()
                        local hash = GetHashKey(animal.config.model)
                        RequestModel(hash)
                        while not HasModelLoaded(hash) do
                            Wait(10)
                        end
                        
                        -- 获取地面高度
                        local found, z = GetGroundZFor_3dCoord(animal.coords.x, animal.coords.y, animal.coords.z + 50.0, false)
                        if not found then
                            z = animal.coords.z
                        end
                        
                        local finalCoords = vector3(animal.coords.x, animal.coords.y, z + 1.0)
                        
                        -- 创建死亡状态的动物
                        local newAnimal = CreatePed(28, hash, finalCoords.x, finalCoords.y, finalCoords.z, math.random(0, 360), false, false)
                        
                        Wait(100)
                        
                        if DoesEntityExist(newAnimal) then
                            -- 设置基本属性
                            SetEntityAsMissionEntity(newAnimal, true, true)
                            SetPedCanRagdoll(newAnimal, true)
                            PlaceObjectOnGroundProperly(newAnimal)
                            
                            -- 设置为死亡状态
                            SetEntityMaxHealth(newAnimal, animal.config.health)
                            SetEntityHealth(newAnimal, 0)
                            
                            -- 强制布娃娃状态
                            SetPedToRagdoll(newAnimal, 5000, 5000, 0, false, false, false)
                            ClearPedTasksImmediately(newAnimal)
                            SetBlockingOfNonTemporaryEvents(newAnimal, true)
                            
                            -- 更新动物引用
                            animal.entity = newAnimal
                            animal.recreating = false
                            
                            -- 等待确保死亡状态生效，然后添加收获目标
                            Wait(500)
                            if DoesEntityExist(newAnimal) and IsEntityDead(newAnimal) and not animal.hasTarget then
                                animal.hasTarget = true
                                AddAnimalHarvestTarget(animal)
                                if Config.Debug then
                                    print(SafeL("debug.add_harvest_dead", SafeGetAnimalName(animal.animalKey), animal.id))
                                end
                            end
                        else
                            animal.recreating = false
                        end
                        
                        SetModelAsNoLongerNeeded(hash)
                    end)
                end
            end
        end
    end
end

-- 添加动物收获目标
function AddAnimalHarvestTarget(animalData)
    if Config.Debug then
        print(SafeL("debug.adding_harvest_target", SafeGetAnimalName(animalData.animalKey), animalData.entity, tostring(DoesEntityExist(animalData.entity))))
        if DoesEntityExist(animalData.entity) then
            print(SafeL("debug.animal_death_status", tostring(IsEntityDead(animalData.entity))))
            print(SafeL("debug.animal_health_status", GetEntityHealth(animalData.entity)))
        end
    end
    
    -- 为小动物设置特殊处理，防止过早despawn
    if animalData.animalKey == "rabbit" and DoesEntityExist(animalData.entity) then
        SetEntityAsMissionEntity(animalData.entity, true, true)
        if Config.Debug then
            print("[YX Hunter] Set rabbit as mission entity to prevent despawn: " .. animalData.id)
        end
    end
    
    if DoesEntityExist(animalData.entity) then
        exports['qb-target']:AddTargetEntity(animalData.entity, {
            options = {
                {
                    type = "client",
                    event = "yx-hunter:client:harvestAnimal",
                    icon = "fas fa-knife-kitchen",
                    label = SafeL("interactions.harvest_animal", SafeGetAnimalName(animalData.animalKey)),
                    animalData = animalData
                }
            },
            distance = 15.0 -- 增加交互距离以支持远距离射击和小动物交互
        })
        
        if Config.Debug then
            print(SafeL("debug.harvest_target_added", SafeGetAnimalName(animalData.animalKey)))
        end
    else
        if Config.Debug then
            print(SafeL("debug.harvest_target_failed", SafeGetAnimalName(animalData.animalKey)))
        end
    end
end

-- 清理无效动物 (优化版本 - 批量处理和内存优化)
function CleanupInvalidAnimals()
    local cleanupCount = 0
    
    -- 清理spawnedAnimals
    for i = #spawnedAnimals, 1, -1 do
        local animal = spawnedAnimals[i]
        if not DoesEntityExist(animal.entity) then
            table.remove(spawnedAnimals, i)
            cleanupCount = cleanupCount + 1
            if Config.Debug then
                print(SafeL("debug.cleanup_invalid", SafeGetAnimalName(animal.animalKey)))
            end
        end
    end
    
    -- 清理syncedAnimals中已收获的过期动物
    for i = #syncedAnimals, 1, -1 do
        local animal = syncedAnimals[i]
        if DoesEntityExist(animal.entity) then
            -- 检查是否已经收获且超过清理时间
            local currentTime = GetGameTimer()
            if animal.isDead and animal.isHarvested and animal.harvestTime and 
               (currentTime - animal.harvestTime) > 30000 then -- 30秒后清理
                -- 移除qb-target
                exports['qb-target']:RemoveTargetEntity(animal.entity)
                -- 删除实体
                DeleteEntity(animal.entity)
                table.remove(syncedAnimals, i)
                cleanupCount = cleanupCount + 1
                if Config.Debug then
                    print("[YX Hunter] Cleaned up harvested animal: " .. animal.id)
                end
            end
        else
            -- 实体不存在，直接移除引用
            table.remove(syncedAnimals, i)
            cleanupCount = cleanupCount + 1
        end
    end
    
    if Config.Debug and cleanupCount > 0 then
        print("[YX Hunter] Total cleaned up: " .. cleanupCount .. " animal references")
    end
end

-- 清理所有动物的事件
RegisterNetEvent('yx-hunter:client:clearAllAnimals', function()
    -- 清理本地刷新的动物
    for _, animal in pairs(spawnedAnimals) do
        if DoesEntityExist(animal.entity) then
            DeleteEntity(animal.entity)
        end
    end
    spawnedAnimals = {}
    
    -- 清理同步的动物
    for _, animal in pairs(syncedAnimals) do
        if DoesEntityExist(animal.entity) then
            DeleteEntity(animal.entity)
        end
    end
    syncedAnimals = {}
    
    if Config.Debug then
        print(SafeL("debug.all_animals_cleared"))
    end
end)

-- 服务端同步刷新动物事件
RegisterNetEvent('yx-hunter:client:spawnSyncedAnimal', function(animalData)
    -- 检查是否已存在相同ID的动物
    for _, existingAnimal in pairs(syncedAnimals) do
        if existingAnimal.id == animalData.id then
            return -- 已存在，不重复刷新
        end
    end
    
    local hash = GetHashKey(animalData.config.model)
    
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    
    -- 获取地面高度
    local found, z = GetGroundZFor_3dCoord(animalData.coords.x, animalData.coords.y, animalData.coords.z + 50.0, false)
    if not found then
        z = animalData.coords.z
    end
    
    local finalCoords = vector3(animalData.coords.x, animalData.coords.y, z + 1.0)
    
    -- 创建动物
    local animal = CreatePed(28, hash, finalCoords.x, finalCoords.y, finalCoords.z, math.random(0, 360), false, false)
    
    Wait(100)
    
    if DoesEntityExist(animal) then
        -- 设置实体属性
        SetEntityAsMissionEntity(animal, true, true)
        SetPedCanRagdoll(animal, true)
        SetEntityInvincible(animal, false)
        PlaceObjectOnGroundProperly(animal)
        
        -- 设置生命值
        SetEntityMaxHealth(animal, animalData.config.health)
        SetEntityHealth(animal, animalData.config.health)
        
        -- 设置动物行为
        SetPedFleeAttributes(animal, 0, 0)
        SetPedCombatAttributes(animal, 17, 1)
        SetBlockingOfNonTemporaryEvents(animal, false)
        TaskWanderStandard(animal, 10.0, 10)
        
        -- 存储同步动物信息
        local syncedAnimalData = {
            id = animalData.id,
            entity = animal,
            config = animalData.config,
            coords = animalData.coords, -- 保存原始坐标用于重新创建
            zone = animalData.zone,
            animalKey = animalData.animalKey,
            spawnTime = animalData.spawnTime,
            isDead = false,
            isHarvested = false
        }
        
        table.insert(syncedAnimals, syncedAnimalData)
        
        if Config.Debug then
            print(SafeL("debug.sync_spawn", SafeGetAnimalName(animalData.animalKey), animalData.id))
        end
    end
    
    SetModelAsNoLongerNeeded(hash)
end)

-- 同步动物死亡事件
RegisterNetEvent('yx-hunter:client:animalDied', function(animalId, killerId)
    for _, animal in pairs(syncedAnimals) do
        if animal.id == animalId and not animal.isDead then
            animal.isDead = true
            animal.killer = killerId -- 记录击杀者ID
            
            -- 检查实体是否存在
            if DoesEntityExist(animal.entity) then
                if not IsEntityDead(animal.entity) then
                    -- 立即设置为0血量
                    SetEntityHealth(animal.entity, 0)
                    
                    if Config.Debug then
                        print(SafeL("debug.force_kill", SafeGetAnimalName(animal.animalKey), animalId))
                    end
                end
                
                -- 确保动物进入死亡状态和布娃娃效果
                CreateThread(function()
                    Wait(200) -- 等待死亡处理
                    if DoesEntityExist(animal.entity) then
                        -- 强制布娃娃状态
                        SetPedToRagdoll(animal.entity, 2000, 2000, 0, false, false, false)
                        
                        -- 禁用AI任务
                        ClearPedTasksImmediately(animal.entity)
                        SetBlockingOfNonTemporaryEvents(animal.entity, true)
                        
                        -- 等待一下确保死亡状态完全生效，然后添加收获目标
                        Wait(300)
                        if DoesEntityExist(animal.entity) and IsEntityDead(animal.entity) and not animal.hasTarget then
                            animal.hasTarget = true -- 标记已添加目标
                            AddAnimalHarvestTarget(animal)
                            if Config.Debug then
                                print(SafeL("debug.add_harvest_dead", SafeGetAnimalName(animal.animalKey), animalId))
                            end
                        end
                    end
                end)
            else
                -- 实体不存在，可能由于距离太远被despawn了，需要重新创建一个死亡状态的动物
                if Config.Debug then
                    print("[YX Hunter] Animal entity despawned, recreating dead animal: " .. SafeGetAnimalName(animal.animalKey))
                end
                
                CreateThread(function()
                    local hash = GetHashKey(animal.config.model)
                    RequestModel(hash)
                    while not HasModelLoaded(hash) do
                        Wait(10)
                    end
                    
                    -- 获取玩家坐标来重新创建动物
                    local playerCoords = GetEntityCoords(PlayerPedId())
                    local animalCoords = animal.coords
                    local distance = #(playerCoords - animalCoords)
                    
                    -- 只有在玩家距离合理时才重新创建
                    if distance < 200.0 then
                        -- 获取地面高度
                        local found, z = GetGroundZFor_3dCoord(animalCoords.x, animalCoords.y, animalCoords.z + 50.0, false)
                        if not found then
                            z = animalCoords.z
                        end
                        
                        local finalCoords = vector3(animalCoords.x, animalCoords.y, z + 1.0)
                        
                        -- 创建死亡状态的动物
                        local newAnimal = CreatePed(28, hash, finalCoords.x, finalCoords.y, finalCoords.z, math.random(0, 360), false, false)
                        
                        Wait(100)
                        
                        if DoesEntityExist(newAnimal) then
                            -- 设置基本属性
                            SetEntityAsMissionEntity(newAnimal, true, true)
                            SetPedCanRagdoll(newAnimal, true)
                            PlaceObjectOnGroundProperly(newAnimal)
                            
                            -- 设置为死亡状态
                            SetEntityMaxHealth(newAnimal, animal.config.health)
                            SetEntityHealth(newAnimal, 0) -- 直接设置为死亡
                            
                            -- 强制布娃娃状态
                            SetPedToRagdoll(newAnimal, 5000, 5000, 0, false, false, false)
                            ClearPedTasksImmediately(newAnimal)
                            SetBlockingOfNonTemporaryEvents(newAnimal, true)
                            
                            -- 更新动物引用
                            animal.entity = newAnimal
                            
                            -- 等待确保死亡状态生效，然后添加收获目标
                            Wait(500)
                            if DoesEntityExist(newAnimal) and IsEntityDead(newAnimal) and not animal.hasTarget then
                                animal.hasTarget = true
                                AddAnimalHarvestTarget(animal)
                                if Config.Debug then
                                    print(SafeL("debug.add_harvest_dead", SafeGetAnimalName(animal.animalKey), animalId))
                                end
                            end
                        end
                    end
                    
                    SetModelAsNoLongerNeeded(hash)
                end)
            end
            
            if Config.Debug then
                print(SafeL("debug.death_sync_received", SafeGetAnimalName(animal.animalKey), animalId, killerId))
            end
            break
        end
    end
end)

-- 移除同步动物事件
RegisterNetEvent('yx-hunter:client:removeAnimal', function(animalId)
    for i = #syncedAnimals, 1, -1 do
        local animal = syncedAnimals[i]
        if animal.id == animalId then
            if DoesEntityExist(animal.entity) then
                exports['qb-target']:RemoveTargetEntity(animal.entity)
                DeleteEntity(animal.entity)
            end
            table.remove(syncedAnimals, i)
            if Config.Debug then
                print(SafeL("debug.animal_removed", SafeGetAnimalName(animal.animalKey), animalId))
            end
            break
        end
    end
end)

-- 调试刷新动物事件
RegisterNetEvent('yx-hunter:client:debugSpawnAnimal', function()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- 找到玩家当前所在的打猎区域
    local currentZone = nil
    local currentZoneIndex = nil
    
    for zoneIndex, zone in pairs(Config.HuntingZones) do
        local distance = #(playerCoords - zone.coords)
        if distance <= zone.radius then
            currentZone = zone
            currentZoneIndex = zoneIndex
            break
        end
    end
    
    if currentZone then
        -- 获取该区域可刷新的动物
        if #currentZone.animals > 0 then
            local randomAnimalKey = currentZone.animals[math.random(1, #currentZone.animals)]
            local animalConfig = Config.Animals[randomAnimalKey]
            
            if animalConfig then
                -- 在玩家附近生成动物（10-20米范围）
                local angle = math.random() * 2 * math.pi
                local distance = math.random(10, 20)
                
                local x = playerCoords.x + math.cos(angle) * distance
                local y = playerCoords.y + math.sin(angle) * distance
                
                local found, z = GetGroundZFor_3dCoord(x, y, playerCoords.z + 10.0, false)
                
                if found then
                    local spawnCoords = vector3(x, y, z + 1.0)
                    SpawnAnimal(animalConfig, spawnCoords, currentZoneIndex, randomAnimalKey)
                    
                    QBCore.Functions.Notify(SafeL('notifications.animal_spawned', SafeGetAnimalName(randomAnimalKey)), 'success')
                    if Config.Debug then
                        print(SafeL("debug.debug_spawn_success", SafeGetAnimalName(randomAnimalKey), randomAnimalKey, tostring(spawnCoords)))
                    end
                else
                    QBCore.Functions.Notify(SafeL('notifications.no_ground'), 'error')
                end
            else
                QBCore.Functions.Notify(SafeL('notifications.animal_config_error', randomAnimalKey), 'error')
            end
        else
            QBCore.Functions.Notify(SafeL('notifications.no_animals_configured'), 'error')
        end
    else
        QBCore.Functions.Notify(SafeL('notifications.not_in_zone'), 'error')
        if Config.Debug then
            print(SafeL("debug.debug_spawn_failed", tostring(playerCoords)))
        end
    end
end)

-- 收获动物事件
RegisterNetEvent('yx-hunter:client:harvestAnimal', function(data)
    local animalData = data.animalData
    local currentPlayerId = GetPlayerServerId(PlayerId())
    
    -- 检查动物是否已死亡且未收获
    if not animalData.isDead or animalData.isHarvested then
        QBCore.Functions.Notify(SafeL('notifications.cannot_harvest'), 'error')
        return
    end
    
    -- 检查是否是击杀者（只有击杀者可以收获）
    if animalData.killer and animalData.killer ~= currentPlayerId then
        QBCore.Functions.Notify(SafeL('notifications.killer_only'), 'error')
        return
    end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local animalCoords = GetEntityCoords(animalData.entity)
    local distance = #(playerCoords - animalCoords)
    
    -- 检查距离 (增加到10米以支持远距离射击)
    if distance > 10.0 then
        QBCore.Functions.Notify(SafeL('notifications.too_far'), 'error')
        return
    end
    
    -- 检查是否有收获工具
    QBCore.Functions.TriggerCallback('yx-hunter:server:hasHarvestTool', function(hasTool)
        if hasTool then
            StartHarvestingAnimation(animalData)
        else
            local toolName = QBCore.Shared.Items[Config.HarvestingTool.itemName] and 
                           QBCore.Shared.Items[Config.HarvestingTool.itemName].label or 
                           Config.HarvestingTool.itemName
            QBCore.Functions.Notify(SafeL('notifications.need_tool', toolName), 'error')
        end
    end)
end)

-- 开始收获动画
function StartHarvestingAnimation(animalData)
    local playerPed = PlayerPedId()
    
    -- 标记为正在收获
    animalData.isHarvesting = true
    
    -- 面向动物
    local animalCoords = GetEntityCoords(animalData.entity)
    local playerCoords = GetEntityCoords(playerPed)
    local heading = GetHeadingFromVector_2d(animalCoords.x - playerCoords.x, animalCoords.y - playerCoords.y)
    SetEntityHeading(playerPed, heading)
    
    -- 播放收获动画 (从config获取)
    local animDict = Config.HarvestingTool.animation.dict
    local animName = Config.HarvestingTool.animation.name
    
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Wait(10)
    end
    
    TaskPlayAnim(playerPed, animDict, animName, 8.0, -8.0, -1, 1, 0, false, false, false)
    
    QBCore.Functions.Notify(SafeL('notifications.harvesting_animal', SafeGetAnimalName(animalData.animalKey)), 'info')
    
    -- 显示进度条 (使用config配置)
    if exports['progressbar'] then
        local progressConfig = {
            name = "harvesting_animal",
            duration = Config.HarvestingTool.duration,
            label = SafeL('interactions.' .. (Config.HarvestingTool.progressBar.labelKey or 'harvesting_progress')),
            useWhileDead = Config.HarvestingTool.progressBar.useWhileDead,
            canCancel = Config.HarvestingTool.progressBar.canCancel,
            controlDisables = Config.HarvestingTool.progressBar.controlDisables,
        }
        
        exports['progressbar']:Progress(progressConfig, function(cancelled)
            ClearPedTasksImmediately(playerPed)
            
            if not cancelled then
                -- 收获完成
                CompleteHarvesting(animalData)
            else
                QBCore.Functions.Notify(SafeL('notifications.harvest_cancelled'), 'error')
                animalData.isHarvesting = false
            end
        end)
    else
        -- 如果没有进度条，直接等待配置的时间
        Wait(Config.HarvestingTool.duration)
        ClearPedTasksImmediately(playerPed)
        CompleteHarvesting(animalData)
    end
end

-- 完成收获
function CompleteHarvesting(animalData)
    animalData.isHarvested = true
    animalData.isHarvesting = false
    
    -- 移除qb-target
    exports['qb-target']:RemoveTargetEntity(animalData.entity)
    
    -- 发送到服务器处理奖励
    TriggerServerEvent('yx-hunter:server:harvestAnimal', animalData.config.rewards, animalData.animalKey, animalData.id)
    
    -- 如果是同步动物，通知服务端已收获
    if animalData.id then
        TriggerServerEvent('yx-hunter:server:animalHarvested', animalData.id)
    end
    
    if Config.Debug then
        local displayId = animalData.id or animalData.entity
        print(SafeL("debug.harvest_complete", SafeGetAnimalName(animalData.animalKey), displayId))
    end
    
    -- 如果不是同步动物，本地清理
    if not animalData.id then
        CreateThread(function()
            Wait(Config.SpawnSettings.corpseCleanupTime)
            if DoesEntityExist(animalData.entity) then
                DeleteEntity(animalData.entity)
            end
        end)
    end
end

-- 语言切换事件
RegisterNetEvent('yx-hunter:client:refreshLanguage', function()
    -- 重新创建地图标记以更新语言
    ClearHuntingZones()
    
    -- 重新创建商人以更新语言
    if Config.Merchant.enabled then
        ClearHuntingMerchant()
    end
    
    Wait(100) -- 短暂等待确保清理完成
    CreateHuntingZones()
    
    -- 重新创建商人
    if Config.Merchant.enabled then
        CreateHuntingMerchant()
    end
    
    if Config.Debug then
        print("[YX Hunter] Language switched, refreshed map blips and merchant")
    end
end)

-- 清理资源
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- 删除所有刷新的动物
        for _, animal in pairs(spawnedAnimals) do
            if DoesEntityExist(animal.entity) then
                DeleteEntity(animal.entity)
            end
        end
        
        -- 删除地图标记
        for _, blip in pairs(huntingBlips) do
            RemoveBlip(blip)
        end
        
        -- 清理商人
        ClearHuntingMerchant()
        
        if Config.Debug then
            print(SafeL("debug.resource_stopped"))
        end
    end
end)