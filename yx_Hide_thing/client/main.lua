local QBCore = exports['qb-core']:GetCoreObject()

-- 材质类别检测函数
local function checkMaterialType(materialHash)
    -- 明确的硬质材质（绝对禁止）
    local hardMaterials = {
        1187676648,  -- 混凝土
        1144315351,  -- 混凝土2
        1144315879,  -- 混凝土3
        -1624480709, -- 沥青
        1426120651,  -- 金属
        951832588,   -- 瓷砖
        581794674,   -- 石材
        1907048430,  -- 建筑材料
    }
    
    -- 明确的软质材质（绝对允许）
    local softMaterials = {
        -461750719,  -- 草地
        -840216541,  -- 泥土
        510490462,   -- 泥浆
        1333033863,  -- 土壤
        3881986,     -- 沙地
        3794946,     -- 砾石
        -700658213,  -- 自然土壤
        -2041329971, -- 天然砾石
    }
    
    -- 检查是否为硬质材质
    for i = 1, #hardMaterials do
        if hardMaterials[i] == materialHash then
            return "forbidden"
        end
    end
    
    -- 检查是否为软质材质
    for i = 1, #softMaterials do
        if softMaterials[i] == materialHash then
            return "allowed"
        end
    end
    
    return "unknown"
end

-- 备用检测条件
local function checkBackupConditions(coords)
    -- 检查是否在明显的城市区域
    local x, y = coords.x, coords.y
    
    -- 洛圣都市中心核心区域（绝对禁止）
    if x >= -800 and x <= 800 and y >= -1200 and y <= 600 then
        return false, "城市区域地面不适合挖坑！"
    end
    
    -- 检查海拔高度（山区通常允许）
    if coords.z > 150.0 then
        return true -- 山区允许
    end
    
    -- 其他区域默认允许
    return true
end

local function isValidDiggingLocation()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    -- 1. 检查是否在室内
    if GetInteriorFromEntity(playerPed) ~= 0 then
        return false
    end
    
    -- 2. 检查是否在水中
    if IsEntityInWater(playerPed) then
        return false
    end
    
    -- 3. 检查脚下地面材质（基于材质类别判断）
    -- 使用 raycast 获取脚下地面材质
    local raycast = StartExpensiveSynchronousShapeTestLosProbe(
        playerCoords.x, playerCoords.y, playerCoords.z + 0.5,
        playerCoords.x, playerCoords.y, playerCoords.z - 2.0,
        1, playerPed, 0
    )
    local _, hit, _, _, materialHash = GetShapeTestResult(raycast)
    
    if hit then
        -- 调试信息
        print("检测到地面材质哈希: " .. tostring(materialHash))
        
        -- 使用更智能的材质判断方法
        local materialResult = checkMaterialType(materialHash)
        
        if materialResult == "forbidden" then
            print("地面材质被禁止: " .. tostring(materialHash))
            return false, "这里的地面太硬，无法挖坑！"
        elseif materialResult == "allowed" then
            print("地面材质允许挖掘: " .. tostring(materialHash))
            return true
        else
            -- 未知材质，使用备用检测
            print("未知地面材质，使用备用检测: " .. tostring(materialHash))
            return checkBackupConditions(playerCoords)
        end
    end
    
    -- raycast 失败，使用备用检测
    return checkBackupConditions(playerCoords)
end

local function playDiggingAnimation()
    local playerPed = PlayerPedId()
    
    RequestAnimDict("random@burial")
    while not HasAnimDictLoaded("random@burial") do
        Citizen.Wait(100)
    end
    
    RequestModel(`prop_tool_shovel`)
    RequestModel(`prop_ld_shovel_dirt`)
    while not HasModelLoaded(`prop_tool_shovel`) or not HasModelLoaded(`prop_ld_shovel_dirt`) do
        Citizen.Wait(100)
    end
    
    local shovelProp = CreateObject(`prop_tool_shovel`, 0.0, 0.0, 0.0, true, true, false)
    local dirtProp = CreateObject(`prop_ld_shovel_dirt`, 0.0, 0.0, 0.0, true, true, false)
    
    AttachEntityToEntity(shovelProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.24, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    AttachEntityToEntity(dirtProp, playerPed, GetPedBoneIndex(playerPed, 28422), 0.0, 0.0, 0.24, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    
    TaskPlayAnim(playerPed, "random@burial", "a_burial", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    CreateThread(function()
        Wait(10000)
        if DoesEntityExist(shovelProp) then
            DeleteEntity(shovelProp)
        end
        if DoesEntityExist(dirtProp) then
            DeleteEntity(dirtProp)
        end
        ClearPedTasks(playerPed)
    end)
end

local function hideItem()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local canDig, errorMsg = isValidDiggingLocation()
    if not canDig then
        local message = errorMsg or "你不能在这里挖坑！请前往自然地面。"
        QBCore.Functions.Notify(message, "error")
        return
    end
    
    QBCore.Functions.TriggerCallback('yx_hideitem:checkShovel', function(hasShovel)
        if not hasShovel then
            QBCore.Functions.Notify("你需要一把铲子才能挖坑！", "error")
            return
        end
        
        local playerInventory = exports['qs-inventory']:getUserInventory()
        if not playerInventory or next(playerInventory) == nil then
            QBCore.Functions.Notify("你的背包里没有任何物品可以藏匿！", "error")
            return
        end
        
        local availableItems = {}
        local itemOptions = {}
        
        for slot, item in pairs(playerInventory) do
            if item and item.name and item.amount and item.amount > 0 then
                -- 排除铲子和一些不应该藏匿的物品
                if item.name ~= 'shovel' and item.name ~= 'id_card' and item.name ~= 'driver_license' and item.name ~= 'weaponlicense' then
                    local itemLabel = item.label or item.name
                    local optionText = itemLabel .. " (数量: " .. item.amount .. ")"
                    
                    availableItems[item.name] = {
                        name = item.name,
                        label = itemLabel,
                        amount = item.amount,
                        slot = slot
                    }
                    
                    itemOptions[#itemOptions + 1] = {
                        value = item.name,
                        text = optionText
                    }
                end
            end
        end
        
        if #itemOptions == 0 then
            QBCore.Functions.Notify("你的背包里没有可以藏匿的物品！", "error")
            return
        end
        
        local input = exports['qb-input']:ShowInput({
            header = "选择要藏匿的物品",
            submitText = "下一步",
            inputs = {
                {
                    text = "选择物品",
                    name = "selectedItem",
                    type = "select",
                    options = itemOptions,
                    isRequired = true
                }
            }
        })
        
        if input and input.selectedItem then
            local selectedItem = availableItems[input.selectedItem]
            if selectedItem then
                TriggerEvent('yx_hideitem:selectAmount', {
                    item = selectedItem.name,
                    label = selectedItem.label,
                    maxAmount = selectedItem.amount,
                    coords = playerCoords
                })
            end
        end
        
    end)
end

RegisterNetEvent('yx_hideitem:selectAmount', function(data)
    local input = exports['qb-input']:ShowInput({
        header = "藏匿 " .. data.label,
        submitText = "确认藏匿",
        inputs = {
            {
                text = "数量 (最大: " .. data.maxAmount .. ")",
                name = "amount",
                type = "number",
                isRequired = true,
                default = 1
            }
        }
    })
    
    if input and input.amount then
        local amount = tonumber(input.amount)
        if not amount or amount <= 0 then
            QBCore.Functions.Notify("数量必须是正数！", "error")
            return
        end
        
        if amount > data.maxAmount then
            QBCore.Functions.Notify("数量不能超过你拥有的数量！", "error")
            return
        end
        
        playDiggingAnimation()
        
        if lib and lib.progressBar then
            lib.progressBar({
                duration = 10000,
                label = '正在挖坑藏匿物品...',
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                },
                anim = {
                    dict = 'random@burial',
                    clip = 'a_burial'
                },
            })
        else
            exports['progressbar']:Progress({
                name = "hiding_item",
                duration = 10000,
                label = "正在挖坑藏匿物品...",
                useWhileDead = false,
                canCancel = true,
                controlDisables = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                },
                animation = {
                    animDict = "random@burial",
                    anim = "a_burial",
                },
            }, function(cancelled)
                if not cancelled then
                    TriggerServerEvent('yx_hideitem:hideItem', data.item, amount, data.coords)
                else
                    QBCore.Functions.Notify("藏匿被取消！", "error")
                end
                ClearPedTasks(PlayerPedId())
            end)
        end
    end
end)

local function digUpItem()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    local canDig, errorMsg = isValidDiggingLocation()
    if not canDig then
        local message = errorMsg or "你不能在这里挖掘！请前往自然地面。"
        QBCore.Functions.Notify(message, "error")
        return
    end
    
    QBCore.Functions.TriggerCallback('yx_hideitem:checkShovel', function(hasShovel)
        if not hasShovel then
            QBCore.Functions.Notify("你需要一把铲子才能挖掘！", "error")
            return
        end
        
        playDiggingAnimation()
        
        if lib and lib.progressBar then
            lib.progressBar({
                duration = 8000,
                label = '正在挖掘寻找藏匿物品...',
                useWhileDead = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true,
                },
                anim = {
                    dict = 'random@burial',
                    clip = 'a_burial'
                },
            })
        else
            exports['progressbar']:Progress({
                name = "digging_item",
                duration = 8000,
                label = "正在挖掘寻找藏匿物品...",
                useWhileDead = false,
                canCancel = true,
                controlDisables = {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                },
                animation = {
                    animDict = "random@burial",
                    anim = "a_burial",
                },
            }, function(cancelled)
                if not cancelled then
                    TriggerServerEvent('yx_hideitem:digUpItem', playerCoords)
                else
                    QBCore.Functions.Notify("挖掘被取消！", "error")
                end
                ClearPedTasks(playerPed)
            end)
        end
    end)
end

RegisterCommand('hideitem', function()
    hideItem()
end, false)

RegisterCommand('digup', function()
    digUpItem()
end, false)

TriggerEvent('chat:addSuggestion', '/hideitem', '藏匿物品到地下')
TriggerEvent('chat:addSuggestion', '/digup', '挖掘藏匿的物品')