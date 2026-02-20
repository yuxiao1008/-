--[[
    ====================================
    AI 出租车系统 - 共享工具函数
    作者：于晓
    描述：客户端和服务端通用的工具函数
    ====================================
]]--

--[[
    调试日志输出函数
    @param msg string 要输出的消息
    @return void
    @description 根据Config.Debug开关决定是否输出日志
]]--
function DebugPrint(msg)
    if Config.Debug then
        print('[YX_AI_TAXI] ' .. tostring(msg))
    end
end

--[[
    计算两点之间的距离
    @param coords1 vector3 第一个坐标点
    @param coords2 vector3 第二个坐标点
    @return number 两点之间的距离
]]--
function GetDistanceBetweenCoords(coords1, coords2)
    return #(coords1 - coords2)
end

--[[
    生成指定范围内的随机浮点数
    @param min number 最小值
    @param max number 最大值
    @return number 随机浮点数
]]--
function GetRandomFloat(min, max)
    return min + (max - min) * math.random()
end

--[[
    生成随机角度（0-360度）
    @return number 随机角度
]]--
function GetRandomAngle()
    return math.random() * 360.0
end

--[[
    根据角度和距离计算偏移坐标
    @param origin vector3 原点坐标
    @param angle number 角度（度）
    @param distance number 距离（米）
    @return vector3 计算后的坐标
]]--
function GetOffsetCoords(origin, angle, distance)
    local rad = math.rad(angle)
    local x = origin.x + math.cos(rad) * distance
    local y = origin.y + math.sin(rad) * distance
    local z = origin.z
    return vector3(x, y, z)
end

