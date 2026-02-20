RegisterNetEvent('yx_jump:showFaceKill')
AddEventHandler('yx_jump:showFaceKill', function()
    -- 显示NUI
    SetNuiFocus(true, false)
    SendNUIMessage({ action = "show" })

    -- 2秒后关闭NUI并杀死玩家
    Citizen.CreateThread(function()
        Citizen.Wait(1000)
        SendNUIMessage({ action = "hide" })
        SetNuiFocus(false, false)
        -- 杀死玩家
        local ped = PlayerPedId()
        SetEntityHealth(ped, 0)
        -- 传送玩家到指定位置
        SetEntityCoords(ped, 407.8, -964.69, -99.0, false, false, false, true)
    end)
end) 