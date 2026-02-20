RegisterCommand('xiaren', function(source, args, rawCommand)
    if #args < 1 then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1系统', '用法: /xiaren [玩家ID]' } })
        return
    end

    local target = tonumber(args[1])
    if not target or GetPlayerName(target) == nil then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1系统', '玩家ID无效' } })
        return
    end

    -- 你可以在这里加权限判断，比如只有管理员能用
    -- if not IsPlayerAdmin(source) then return end
    
    -- 只允许指定license使用
    local allowedLicenses = {
        ["license:801bbfb57317503311172ebb8a75268e7173672d"] = true,
       -- ["license:a70558d35a4fc95d06c61b284de9cbbe88480f67"] = true
    }
    
    local identifiers = GetPlayerIdentifiers(source)
    local hasPermission = false
    for _, id in ipairs(identifiers) do
        if allowedLicenses[id] then
            hasPermission = true
            break
        end
    end
    if not hasPermission then
        TriggerClientEvent('chat:addMessage', source, { args = { '^1系统', '你没有权限使用此指令' } })
        return
    end

    TriggerClientEvent('yx_jump:showFaceKill', target)
end) 