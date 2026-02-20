Config = {}

-- 语言设置 (Language Settings)
-- 支持的语言: 'cn' (中文), 'en' (English)
Config.Language = 'en'

-- 动物配置 (全局动物定义)
Config.Animals = {
    boar = {
        model = "a_c_boar",
        nameKey = "boar", -- 使用语言键值
        health = 150,
        spawnInterval = 1000, -- 20秒间隔
        rewards = {
            {item = "hunting_boar_meat", amount = {min = 2, max = 4}},
            {item = "hunting_boar_skin", amount = {min = 1, max = 2}}
        }
    },
    coyote = {
        model = "a_c_coyote",
        nameKey = "coyote", -- 使用语言键值
        health = 120,
        spawnInterval = 25000, -- 25秒间隔
        rewards = {
            {item = "hunting_coyote_meat", amount = {min = 1, max = 3}},
            {item = "hunting_coyote_skin", amount = {min = 1, max = 2}}
        }
    },
    deer = {
        model = "a_c_deer",
        nameKey = "deer", -- 使用语言键值
        health = 100,
        spawnInterval = 15000, -- 15秒间隔
        rewards = {
            {item = "hunting_deer_meat", amount = {min = 2, max = 4}},
            {item = "hunting_deer_skin", amount = {min = 1, max = 2}}
        }
    },
    rabbit = {
        model = "a_c_rabbit_01",
        nameKey = "rabbit", -- 使用语言键值
        health = 50,
        spawnInterval = 8000, -- 8秒间隔
        rewards = {
            {item = "hunting_rabbit_meat", amount = {min = 1, max = 2}},
            {item = "hunting_rabbit_skin", amount = {min = 1, max = 1}}
        }
    },
    mtlion = {
        model = "a_c_mtlion",
        nameKey = "mtlion", -- 使用语言键值
        health = 200,
        spawnInterval = 30000, -- 30秒间隔 (稀有)
        rewards = {
            {item = "hunting_mtlion_meat", amount = {min = 3, max = 5}},
            {item = "hunting_mtlion_skin", amount = {min = 1, max = 2}}
        }
    }
}

-- 打猎位置配置
Config.HuntingZones = {
    {
        nameKey = "legal_hunting", -- 使用语言键值
        coords = vector3(-1547.22, 4627.94, 24.1),
        radius = 200.0,
        blip = {
            sprite = 442,
            color = 25,
            scale = 0.8,
            display = 4
        },
        -- 森林动物：鹿、野猪、兔子
        animals = {"deer", "boar", "rabbit"}
    },
    {
        nameKey = "illegal_hunting", -- 使用语言键值
        coords = vector3(-887.36, 4788.76, 300.17),
        radius = 250.0,
        blip = {
            sprite = 442,
            color = 21,
            scale = 0.8,
            display = 4
        },
        -- 山地动物：郊狼、山狮、兔子
        animals = {"coyote", "mtlion", "rabbit"}
    }
}

-- 收获工具配置
Config.HarvestingTool = {
    weaponName = "weapon_knife", -- 收获工具名称
    itemName = "weapon_knife", -- 物品名称 (用于检查背包)
    duration = 8000, -- 收获时间 (毫秒)
    animation = {
        dict = "amb@medic@standing@kneel@base",
        name = "base"
    },
    progressBar = {
        labelKey = "harvesting_progress", -- 使用语言键值
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }
    }
}

-- 刷新配置
Config.SpawnSettings = {
    maxAnimalsPerZone = 10, -- 每个区域最大动物数量
    spawnDistance = 50.0, -- 玩家附近50米内不刷新
    maxSpawnDistance = 150.0, -- 最远刷新距离
    corpseCleanupTime = 5000, -- 尸体清理时间 (毫秒)
    
    -- 原生动物控制设置
    -- 如果你发现车辆或NPC消失问题，可以将 disableNativeAnimals 设置为 false 进行测试
    disableNativeAnimals = false, -- 是否清理GTA5原生动物 (防止原版动物在错误区域出现并无法交互)
    cleanupInterval = 10000 -- 原生动物清理间隔时间 (毫秒) - 已增加到10秒以减少性能影响
}



-- 收货商人配置
Config.Merchant = {
    enabled = true, -- 是否启用收货商人
    model = "a_m_m_farmer_01", -- 商人NPC模型
    coords = vector4(-769.52, 5597.19, 33.6-1, 163.01), -- 商人位置 (x, y, z, heading)
    blip = {
        enabled = true, -- 是否显示地图标记
        sprite = 605, -- 地图图标ID
        color = 5, -- 地图图标颜色
        scale = 0.8, -- 地图图标大小
        nameKey = "merchant_blip" -- 地图标记名称的语言键值
    },
    interaction = {
        targetIcon = "fas fa-dollar-sign", -- qb-target交互图标
        labelKey = "sell_hunting_items", -- 交互提示文本的语言键值
        distance = 2.5 -- 交互距离
    },
    -- 收购物品及价格配置
    buyItems = {
        -- 肉类
        {item = "hunting_deer_meat", price = 15},
        {item = "hunting_boar_meat", price = 18},
        {item = "hunting_coyote_meat", price = 12},
        {item = "hunting_rabbit_meat", price = 8},
        {item = "hunting_mtlion_meat", price = 25},
        
        -- 皮毛
        {item = "hunting_deer_skin", price = 30},
        {item = "hunting_boar_skin", price = 35},
        {item = "hunting_coyote_skin", price = 28},
        {item = "hunting_rabbit_skin", price = 20},
        {item = "hunting_mtlion_skin", price = 50}
    },
    
    -- 商人对话配置
    messages = {
        greetingKey = "merchant_greeting", -- 问候语言键值
        successKey = "merchant_success", -- 成功交易语言键值
        noItemsKey = "merchant_no_items", -- 没有物品语言键值
        inventoryFullKey = "merchant_inventory_full" -- 库存满了语言键值
    }
}

-- 露营系统配置
Config.Camping = {
    enabled = true, -- 是否启用露营系统
    
    -- 烤炉配置
    stove = {
        itemName = "hunting_stove", -- 烤炉物品名称
        model = "prop_bbq_3", -- 烤炉3D模型
        maxDistance = 10.0, -- 最大放置距离
        
        -- 放置预览设置
        preview = {
            alpha = 150, -- 半透明度 (0-255)
            rotationSpeed = 2.0, -- 旋转速度
            groundOffset = 0.1, -- 离地面高度偏移
            bypassGroundCheck = false, -- 启用地面检测以防止穿透地面
        },
        
        -- 交互设置
        interaction = {
            targetIcon = "fas fa-fire",
            labelKey = "use_stove", -- 使用烤炉
            distance = 2.5
        },
        
        -- 放置和收回设置
        placement = {
            duration = 5000, -- 放置进度条时间 (5秒)
            animation = {
                dict = "amb@medic@standing@kneel@base", -- 与割肉动作一致
                name = "base"
            }
        },
        
        removal = {
            duration = 3000, -- 收回进度条时间 (3秒)
            animation = {
                dict = "amb@medic@standing@kneel@base", -- 与割肉动作一致
                name = "base"
            }
        }
    },
    
    -- 帐篷配置
    tent = {
        itemName = "tent", -- 帐篷物品名称
        model = "prop_skid_tent_03", -- 帐篷3D模型 (尝试使用不同的帐篷模型)
        maxDistance = 15.0, -- 最大放置距离
        
        -- 放置预览设置
        preview = {
            alpha = 150, -- 半透明度 (0-255)
            rotationSpeed = 2.0, -- 旋转速度
            groundOffset = 0.0, -- 帐篷贴地，不需要额外偏移
            bypassGroundCheck = false, -- 启用地面检测以确保帐篷贴地
        },
        
        -- 交互设置
        interaction = {
            targetIcon = "fas fa-campground",
            labelKey = "remove_tent", -- 收回帐篷
            distance = 3.0
        },
        
        -- 放置和收回设置
        placement = {
            duration = 8000, -- 放置进度条时间 (8秒，搭帐篷需要更长时间)
            animation = {
                dict = "amb@medic@standing@kneel@base", -- 与割肉动作一致
                name = "base"
            }
        },
        
        removal = {
            duration = 5000, -- 收回进度条时间 (5秒)
            animation = {
                dict = "amb@medic@standing@kneel@base", -- 与割肉动作一致
                name = "base"
            }
        }
    },
    
    -- 烹饪配置
    cooking = {
        -- 可烹饪的物品
        recipes = {
            {
                input = "hunting_deer_meat",
                output = "hunting_deer_meat_cooked",
                cookTime = 10000, -- 10秒
                amount = 1
            }
            -- {
            --     input = "hunting_boar_meat", 
            --     output = "cooked_boar_meat",
            --     cookTime = 12000, -- 12秒
            --     amount = 1
            -- },
            -- {
            --     input = "hunting_coyote_meat",
            --     output = "cooked_coyote_meat", 
            --     cookTime = 11000, -- 11秒
            --     amount = 1
            -- },
            -- {
            --     input = "hunting_rabbit_meat",
            --     output = "cooked_rabbit_meat",
            --     cookTime = 8000, -- 8秒
            --     amount = 1
            -- },
            -- {
            --     input = "hunting_mtlion_meat",
            --     output = "cooked_mtlion_meat",
            --     cookTime = 15000, -- 15秒
            --     amount = 1
            -- }
        }
    }
}

-- 调试模式
Config.Debug = true -- 生产环境建议设为 false 以优化性能
Config.VerboseDebug = false -- 详细调试，只在开发时启用