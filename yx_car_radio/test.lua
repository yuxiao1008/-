-- 测试文件 - 用于验证车载电台系统功能

-- 测试车辆检测
local function TestVehicleDetection()
    print("=== 车辆检测测试 ===")
    local testVehicles = {
        "police", "sheriff", "ambulance", "firetruk"
    }
    
    for _, vehicle in ipairs(testVehicles) do
        print(string.format("测试车辆: %s", vehicle))
    end
end

-- 测试频道生成
local function TestChannelGeneration()
    print("=== 频道生成测试 ===")
    local jobs = {"police", "lssd", "ambulance"}
    
    for _, job in ipairs(jobs) do
        local carRadioChannel = Config.Channels.CarRadioPrefix .. job
        local dispatcherChannel = Config.Channels.DispatcherPrefix .. job
        print(string.format("职业: %s", job))
        print(string.format("  车载电台频道: %s", carRadioChannel))
        print(string.format("  调度员频道: %s", dispatcherChannel))
    end
end

-- 测试配置加载
local function TestConfig()
    print("=== 配置测试 ===")
    print("支持的职业数量:", #Config.SupportedJobs)
    print("调试模式:", Config.Debug)
    print("日志启用:", Config.Logging.Enabled)
end

-- 运行测试
Citizen.CreateThread(function()
    Citizen.Wait(2000) -- 等待配置加载
    
    if Config then
        TestConfig()
        TestVehicleDetection()
        TestChannelGeneration()
        print("=== 测试完成 ===")
    else
        print("错误: 配置未加载")
    end
end) 