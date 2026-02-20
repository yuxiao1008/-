-- 佩里科岛系统 - 命令处理
-- 作者: 于晓

local QBCore = exports['qb-core']:GetCoreObject()

-- ==================== 调试函数 ====================
local function debug_print(msg)
    if Config.Debug then
        print("[yx_Island CMD] " .. msg)
    end
end

-- ==================== 命令: 系统开关 ====================
RegisterCommand(Config.Commands.toggle, function(source, args, rawCommand)
    -- 检查是否为控制台调用
    if Config.Commands.console_only and source ~= 0 then
        TriggerClientEvent('QBCore:Notify', source, "此命令仅限控制台使用", 'error')
        debug_print(string.format("玩家 %s 尝试使用控制台命令, 已拒绝", source))
        return
    end

    local force = args[1] == "force" -- 是否强制关闭

    -- 当前系统状态
    if IslandSystemEnabled then
        -- 尝试关闭系统
        local playerCount = GetIslandPlayerCount()

        if playerCount > 0 and not force then
            -- 有玩家在岛上且非强制模式, 拒绝关闭
            print("^1[yx_Island]^0 关闭失败! 岛上仍有 ^3" .. playerCount .. "^0 名玩家")
            print("^3岛上玩家列表:^0")
            local playerList = GetIslandPlayerList()
            for _, playerInfo in ipairs(playerList) do
                print("  - " .. playerInfo)
            end
            print("^3提示:^0 使用 ^2/" .. Config.Commands.toggle .. " force^0 强制关闭并传送所有玩家")
            return
        end

        if force and playerCount > 0 then
            -- 强制模式: 传送所有玩家
            print("^3[yx_Island]^0 强制关闭模式, 正在传送岛上玩家...")
            local evacuated = ForceEvacuateIsland()
            print("^2[yx_Island]^0 已传送 ^3" .. evacuated .. "^0 名玩家回安全区")
        end

        -- 关闭系统前先重置所有状态
        ResetIslandSystem()

        -- 关闭系统
        IslandSystemEnabled = false
        TriggerClientEvent('yx_island:client:toggle_system', -1, false)
        print("^2[yx_Island]^0 系统已 ^1关闭^0")
        debug_print("系统已关闭")
    else
        -- 开启系统
        IslandSystemEnabled = true
        TriggerClientEvent('yx_island:client:toggle_system', -1, true)
        print("^2[yx_Island]^0 系统已 ^2开启^0")
        debug_print("系统已开启")
    end
end, false)

-- ==================== 命令: 状态查询 ====================
RegisterCommand(Config.Commands.status, function(source, args, rawCommand)
    -- 检查是否为控制台调用
    if Config.Commands.console_only and source ~= 0 then
        TriggerClientEvent('QBCore:Notify', source, "此命令仅限控制台使用", 'error')
        return
    end

    print("^2========== 佩里科岛系统状态 ==========^0")
    print("^3系统状态:^0 " .. (IslandSystemEnabled and "^2已开启^0" or "^1未开启^0"))
    print("^3等待列表人数:^0 " .. GetWaitingPlayerCount())
    print("^3岛上玩家数:^0 " .. GetIslandPlayerCount())

    if GetWaitingPlayerCount() > 0 then
        print("^3等待列表:^0")
        local waitingList = GetWaitingPlayerList()
        for _, playerInfo in ipairs(waitingList) do
            print("  - " .. playerInfo)
        end
    end

    if GetIslandPlayerCount() > 0 then
        print("^3岛上玩家列表:^0")
        local playerList = GetIslandPlayerList()
        for _, playerInfo in ipairs(playerList) do
            print("  - " .. playerInfo)
        end
    end

    print("^2====================================^0")
end, false)

-- ==================== 命令: 启动活动 ====================
RegisterCommand("island_start", function(source, args, rawCommand)
    -- 检查是否为控制台调用
    if Config.Commands.console_only and source ~= 0 then
        TriggerClientEvent('QBCore:Notify', source, "此命令仅限控制台使用", 'error')
        return
    end

    -- 检查系统是否开启
    if not IslandSystemEnabled then
        print("^1[yx_Island]^0 启动失败! 系统未开启")
        print("^3提示:^0 请先使用 ^2/" .. Config.Commands.toggle .. "^0 开启系统")
        return
    end

    -- 启动活动
    local success = StartIslandActivity()
    if not success then
        print("^1[yx_Island]^0 启动失败!")
    end
end, false)

-- ==================== 命令帮助提示 ====================
if Config.Debug then
    print("^3[yx_Island]^0 已注册命令:")
    print("  - ^2/" .. Config.Commands.toggle .. "^0 - 开启/关闭系统")
    print("  - ^2/" .. Config.Commands.toggle .. " force^0 - 强制关闭并传送玩家")
    print("  - ^2/" .. Config.Commands.status .. "^0 - 查看系统状态")
    print("  - ^2/island_start^0 - 启动活动(传送等待玩家上岛)")
end
