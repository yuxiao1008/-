local QBCore = exports['qb-core']:GetCoreObject()

local IGNITE_DISTANCE = 3.0 -- 点燃距离
local IGNITEABLE_MODELS = {
    -- 草地和垃圾桶模型哈希，可根据需要补充
    ["prop_bin_01a"] = true,
    ["prop_bin_02a"] = true,
    ["prop_bin_03a"] = true,
    ["prop_bin_04a"] = true,
    ["prop_bin_05a"] = true,
    ["prop_bin_06a"] = true,
    ["prop_bin_07a"] = true,
    ["prop_bin_08a"] = true,
    ["prop_grass_dry_02"] = true,
    ["prop_grass_dry_03"] = true,
    ["prop_grass_dry_04"] = true,
}

-- 检查玩家是否持有打火机
local function HasLighter()
    local player = PlayerPedId()
    local weapon = GetSelectedPedWeapon(player)
    -- 以打火机为例，假设物品名为'lighter'，可根据实际物品名调整
    return weapon == GetHashKey('WEAPON_PETROLCAN') or QBCore.Functions.HasItem('lighter')
end

-- 查找附近可点燃物体
local function FindIgniteableObject()
    local player = PlayerPedId()
    local coords = GetEntityCoords(player)
    for obj in EnumerateObjects() do
        local objCoords = GetEntityCoords(obj)
        if #(coords - objCoords) < IGNITE_DISTANCE then
            local model = GetEntityModel(obj)
            if IGNITEABLE_MODELS[GetEntityModelName(model)] then
                return obj, objCoords
            end
        end
    end
    return nil, nil
end

-- 监听使用打火机事件
RegisterCommand('ignite', function()
    if not HasLighter() then
        QBCore.Functions.Notify('你没有打火机', 'error')
        return
    end
    local obj, objCoords = FindIgniteableObject()
    if obj then
        -- 调用z_fire导出点燃
        local fireData = {
            ptfxData = {
                type = 'core',
                pos = vector3(objCoords.x, objCoords.y, objCoords.z),
                scale = 1.0
            },
            canSpread = true,
            behavior = 'grass'
        }
        local fireId = exports['z_fire']:createFire(fireData)
        if fireId then
            QBCore.Functions.Notify('你点燃了物体!', 'success')
        else
            QBCore.Functions.Notify('点燃失败', 'error')
        end
    else
        QBCore.Functions.Notify('附近没有可点燃的物体', 'error')
    end
end, false)

-- 可选：给打火机物品添加使用事件
RegisterNetEvent('yx_fire:useLighter', function()
    ExecuteCommand('ignite')
end)

-- 物体枚举器
function EnumerateObjects()
    return coroutine.wrap(function()
        local handle, object = FindFirstObject()
        if not handle or handle == -1 then return end
        local finished = false
        repeat
            coroutine.yield(object)
            finished, object = FindNextObject(handle)
        until not finished
        EndFindObject(handle)
    end)
end

-- 获取实体模型名
function GetEntityModelName(model)
    for name, _ in pairs(IGNITEABLE_MODELS) do
        if GetHashKey(name) == model then
            return name
        end
    end
    return nil
end 