RegisterNetEvent("custom-delete-vehicle", function(plate)
    local targetPlate = string.upper(plate)

    for _, veh in pairs(GetGamePool("CVehicle")) do
        local vehPlate = string.upper(GetVehicleNumberPlateText(veh)):gsub("%s+", "")
        if vehPlate == targetPlate then
            -- 请求控制权
            NetworkRequestControlOfEntity(veh)
            local timeout = 0
            while not NetworkHasControlOfEntity(veh) and timeout < 50 do
                Wait(10)
                NetworkRequestControlOfEntity(veh)
                timeout += 1
            end

            if NetworkHasControlOfEntity(veh) then
                SetEntityAsMissionEntity(veh, true, true)
                DeleteEntity(veh)
                print("[回库系统] 已强制删除实体车辆: " .. vehPlate)
            else
                print("[回库系统] 无法获取控制权，删除失败: " .. vehPlate)
            end

            break -- 删除后退出循环
        end
    end
end)
