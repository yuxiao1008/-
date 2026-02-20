-- 佩里科岛搜索物资配置文件
-- 作者: 于晓

Config = {}

-- ==================== 调试设置 ====================
-- 开启后在控制台显示详细日志
Config.Debug = true

-- ==================== 脚本功能开关 ====================
-- 脚本默认状态 (建议设置为 false, 通过命令手动开启)
Config.DefaultEnabled = false

-- ==================== 岛屿坐标设置 ====================
-- 佩里科岛检测范围 (中心点坐标)
Config.IslandCenter = vector3(4840.571, -5174.425, 2.0)

-- 检测半径 (米)
Config.IslandRadius = 2000.0

-- ==================== 位置检测设置 ====================
-- 位置检测间隔 (毫秒) - 建议不低于 3000ms 以优化性能
Config.CheckInterval = 5000

-- ==================== 报名系统设置 ====================
Config.Registration = {
    -- 报名点坐标
    location = vector4(-1026.09, -3018.53, 13.95, 327.57),

    -- NPC 设置
    npc = {
        model = "s_m_m_pilot_01",  -- 机场飞行员模型
        scenario = "WORLD_HUMAN_CLIPBOARD"  -- NPC 动作 (手持剪贴板)
    },

    -- ox_target 设置
    target = {
        label = "报名参加佩里科岛行动",
        icon = "fas fa-clipboard-list",
        distance = 2.5
    }
}

-- ==================== 空投跳伞设置 ====================
Config.Airdrop = {
    -- 空投起点高度
    spawn_height = 2500.0,

    -- 空投起点水平坐标 (佩里科岛上空)
    spawn_center = vector3(4840.571, -5174.425, 2500.0),

    -- 降落点随机分散范围 (米)
    random_spread = 150.0,

    -- 是否禁用降落伤害
    disable_fall_damage = true,

    -- 自动开伞延迟 (毫秒)
    parachute_delay = 1000
}

-- ==================== 撤离系统设置 ====================
Config.Evacuation = {
    -- 所有可用的撤离点列表（每局从中随机选择）
    all_points = {
        {
            name = "北部撤离点",
            coords = vector3(4440.54, -4462.92, 4.33),
            interact_distance = 10.0,
            marker = {
                type = 1,
                size = vector3(2.0, 2.0, 1.0),
                color = {r = 255, g = 165, b = 0, a = 100}
            },
            blip = {
                sprite = 126,  -- 直升机图标
                color = 25,     -- 黄色
                scale = 0.8,
                name = "北部撤离点"
            }
        },
        {
            name = "南部撤离点",
            coords = vector3(4892.42, -5736.97, 26.35),
            interact_distance = 10.0,
            marker = {
                type = 1,
                size = vector3(2.0, 2.0, 1.0),
                color = {r = 255, g = 165, b = 0, a = 100}
            },
            blip = {
                sprite = 126,  -- 直升机图标
                color = 25,     -- 黄色
                scale = 0.8,
                name = "南部撤离点"
            }
        },
        {
            name = "东部撤离点",
            coords = vector3(4973.43, -5170.68, 2.34),
            interact_distance = 10.0,
            marker = {
                type = 1,
                size = vector3(2.0, 2.0, 1.0),
                color = {r = 255, g = 165, b = 0, a = 100}
            },
            blip = {
                sprite = 126,  -- 直升机图标
                color = 25,     -- 黄色
                scale = 0.8,
                name = "东部撤离点"
            }
        },
        {
            name = "高地撤离点",
            coords = vector3(5265.77, -5427.5, 65.6),
            interact_distance = 5.0,
            marker = {
                type = 1,
                size = vector3(2.0, 2.0, 1.0),
                color = {r = 255, g = 165, b = 0, a = 100}
            },
            blip = {
                sprite = 126,  -- 直升机图标
                color = 25,     -- 黄色
                scale = 0.8,
                name = "高地撤离点"
            }
        },
        {
            name = "西部撤离点",
            coords = vector3(4883.08, -5282.66, 8.43),
            interact_distance = 10.0,
            marker = {
                type = 1,
                size = vector3(2.0, 2.0, 1.0),
                color = {r = 255, g = 165, b = 0, a = 100}
            },
            blip = {
                sprite = 126,  -- 直升机图标
                color = 25,     -- 黄色
                scale = 0.8,
                name = "西部撤离点"
            }
        }
    },

    -- 当前活动的撤离点（由服务端随机选择后同步到客户端）
    points = {},

    -- 每局随机选择的撤离点数量
    random_count = 2,

    -- 集结点坐标 (撤离后返回位置)
    return_point = vector3(-959.89, -3004.94, 13.95),
    return_heading = 0.0,

    -- 撤离确认时间 (秒)
    confirm_time = 180,

    -- 撤离等待范围限制 (米) - 玩家触发撤离后必须在此范围内等待
    wait_range = 10.0,

    -- 撤离点延迟开启时间 (秒) - 活动开始后多久开启撤离点
    delay_open_time = 1800  -- 5分钟
}

-- ==================== 活动时间设置 ====================
Config.Activity = {
    -- 活动持续时间 (秒) - 到期后自动强制关闭
    duration = 3600,  -- 10分钟

    -- 活动即将结束提醒时间点 (秒)
    warnings = {
        1500,  -- 25分钟时提醒
        300,  -- 5分钟时提醒
        180,  -- 3分钟时提醒
        60    -- 1分钟时提醒
    }
}

-- ==================== 背包管理设置 ====================
Config.Inventory = {
    -- 允许携带上岛的物品类型
    allowed_item_types = {
        "weapon"  -- 允许所有武器
    },

    -- 是否允许弹药
    allow_ammo = true
}

-- ==================== 传送设置 ====================
-- 安全传送点坐标 (已废弃, 使用 Evacuation.return_point 代替)
Config.SafeZone = {
    coords = vector3(-959.89, -3004.94, 13.95),
    heading = 0.0
}

-- ==================== 通知文本 ====================
Config.Notifications = {
    -- 进入岛屿通知
    enter_island = "你已进入佩里科岛区域",

    -- 离开岛屿通知
    leave_island = "你已离开佩里科岛区域",

    -- 系统关闭警告
    system_shutdown = "行动中止! 强制撤离! (物品将被没收)",

    -- 系统未开启提示
    system_disabled = "佩里科岛行动当前未开启",

    -- 报名相关
    registration_success = "报名成功! 等待行动开始...",
    registration_failed = "报名失败! 系统未开启",
    already_registered = "你已经报名过了!",
    already_evacuated = "本次行动您已成功撤离, 无法重复进入!",
    already_died = "本次行动您已死亡, 无法重复进入!",
    cancel_registration = "已取消报名",

    -- 活动启动
    activity_starting = "行动即将开始! 准备登机...",
    activity_started = "所有人员已部署到佩里科岛!",

    -- 撤离相关
    evacuation_ready = "到达撤离点, 按 [E] 请求撤离",
    evacuation_confirm = "正在安排撤离... (%s秒)",
    evacuation_success = "撤离成功! 已返回集结点",
    evacuation_cancelled = "撤离已取消",
    evacuation_out_of_range = "离开撤离范围! 撤离已取消, 请返回撤离点重新触发",
    evacuation_opened = "撤离点已开启! 请前往标记点撤离",
    evacuation_not_available = "撤离点尚未开启",

    -- 背包相关
    inventory_stored = "非武器物品已暂时收缴, 武器可携带",
    inventory_returned = "你的物品已归还",

    -- 活动时间提醒
    activity_time_warning = "行动剩余时间: %s 分钟!",
    activity_ending_soon = "行动即将结束! 请尽快撤离!",
    activity_auto_close = "行动时间结束! 强制撤离所有人员!"
}

-- ==================== 死亡背包设置 ====================
Config.DeathBag = {
    -- 功能开关
    enabled = true,

    -- 背包模型
    bag_model = "prop_cs_heist_bag_02",

    -- 生成高度偏移（米）
    spawn_height_offset = 0.0,

    -- ox_target 设置
    target = {
        label = "拾取背包物品",
        icon = "fas fa-hand-holding",
        distance = 2.5
    },

    -- qs-inventory 仓库设置（与玩家背包保持一致）
    stash = {
        slots = 40,           -- 仓库格子数（与玩家背包一致）
        max_weight = 120000   -- 最大重量 (120kg，与玩家背包一致)
    },

    -- 背包 ID 前缀
    id_prefix = "deathbag_",

    -- 玩家离线时是否保留背包
    keep_on_disconnect = false,

    -- 背包最大存活时间（秒，0 = 无限制）
    max_lifetime = 0,

    -- 搜索进度条设置
    search_progress = {
        duration = 15000,  -- 搜索时长（毫秒）
        label = "正在搜索背包...",
        use_while_dead = false,
        can_cancel = true,
        disable_control = true,
        disable_movement = true,
        animation = {
            -- 蹲下搜索背包动画（限制移动）
            dict = "mp_weapons_deal_sting",
            clip = "crackhead_bag_loop"
        }
    },

    -- 通知文本
    notifications = {
        bag_created = "你的物品已掉落在原地",
        bag_opened = "正在查看背包...",
        bag_empty = "背包已空",
        kicked_from_activity = "你已死亡, 被迫退出行动",
        search_cancelled = "搜索已取消"
    }
}

-- ==================== 物资刷新系统设置 ====================
Config.Resources = {
    -- 功能开关
    enabled = true,

    -- 全局设置
    global = {
        -- 交互距离（米）
        interact_distance = 2.0,

        -- 红色箭头显示距离（米）
        arrow_distance = 2.0,

        -- 红色箭头配置
        arrow_marker = {
            type = 2,  -- 向下箭头
            size = vector3(0.3, 0.3, 0.3),
            color = {r = 255, g = 0, b = 0, a = 200},  -- 红色
            bob = true  -- 上下浮动
        },

        -- 拾取进度条配置
        pickup_progress = {
            enabled = true,
            duration = 15000,  -- 15秒拾取时长
            label = "正在搜索物资...",
            use_while_dead = false,
            can_cancel = true,
            disable_control = true,
            disable_movement = true,
            animation = {
                dict = "misscarsteal2pervert",
                clip = "pervert_husband"
            }
        }
    },

    -- 区域配置
    zones = {
        -- 区域1：普通区域
        {
            name = "普通区域",
            description = "主别墅及周边建筑",

            -- 每个点位的物品数量范围
            min_amount_per_point = 1,  -- 最小数量
            max_amount_per_point = 3,  -- 最大数量

            -- 刷新点坐标列表（替换为实际坐标）
            spawn_points = {
                vector3(5388.97, -5193.28, 33.0),
                vector3(5405.67, -5170.94, 31.46),
                vector3(5328.89, -5270.63, 33.19),
                vector3(5377.5, -5386.85, 43.49),
                vector3(5374.77, -5379.77, 43.7),
                vector3(5265.75, -5432.32, 65.6),
                vector3(4994.82, -5190.22, 2.51),
                vector3(5000.54, -5165.39, 2.76),
                vector3(4976.2, -5137.37, 2.79),
                vector3(4943.16, -5113.04, 2.99),
                vector3(4990.27, -5113.61, 2.53),
                vector3(5010.67, -5151.03, 2.65),
                vector3(5141.67, -4954.11, 14.36),
                vector3(5144.31, -4953.8, 14.36),
                vector3(5159.83, -4941.77, 13.95),
                vector3(5161.79, -4989.36, 12.69),
                vector3(5178.33, -4991.57, 14.15),
                vector3(5189.56, -5007.24, 13.89),
            },

            -- 物品池（根据 amount 数量刷新）
            loot_table = {
                {name = "loot_rusty_watch", label = "生锈的手表", amount = 12},
                {name = "loot_broken_phone", label = "碎裂的手机", amount = 12},
                {name = "loot_empty_wallet", label = "空钱包", amount = 9},
                {name = "loot_mysterious_button", label = "神秘纽扣", amount = 9},
                {name = "loot_rusty_compass", label = "生锈的指南针", amount = 12},
                {name = "loot_ruby_brooch", label = "红宝石胸针", amount = 3},
                {name = "loot_police_radio", label = "丢失的警用对讲机", amount = 3},
                {name = "loot_security_chip", label = "山猫武装主板", amount = 3},
                {name = "loot_rare_keychain", label = "限量钥匙扣", amount = 3},
                {name = "loot_diamond_earring", label = "钻石耳环", amount = 0},
                {name = "loot_secret_documents", label = "绝密文件", amount = 3},
                {name = "loot_sapphire_ring", label = "蓝宝石戒指", amount = 0},
                {name = "loot_pink_diamond", label = "粉钻", amount = 0},
                {name = "loot_cosmic_coin", label = "金色影子硬币", amount = 0}
            }
        },

        -- 区域2：战斗区域
        {
            name = "战斗区域",
            description = "高风险战斗区域",

            -- 每个点位的物品数量范围
            min_amount_per_point = 1,  -- 最小数量
            max_amount_per_point = 3,  -- 最大数量

            -- 刷新点坐标列表（根据最新点位配置）
            spawn_points = {
                vector3(4805.44, -4316.57, 7.3),
                vector3(4905.96, -4944.21, 3.37),
                vector3(4884.27, -4915.33, 3.38),
                vector3(4901.16, -4922.7, 3.36),
                vector3(4887.69, -4933.92, 3.37),
                vector3(5144.33, -4954.4, 14.36),
                vector3(5141.72, -4954.13, 14.36),
                vector3(5146.16, -4964.38, 14.09),
                vector3(5149.31, -4960.97, 14.01),
                vector3(5159.29, -4946.66, 13.92),
                vector3(5161.57, -4941.97, 13.86),
                vector3(5141.35, -4962.17, 14.3),
                vector3(4962.37, -5107.26, 2.98),
                vector3(4963.32, -5109.0, 2.98),
                vector3(5000.8, -5165.74, 2.76),
                vector3(4999.79, -5163.55, 2.76),
                vector3(5010.68, -5151.23, 2.65),
                vector3(4999.93, -5149.27, 2.58),
                vector3(4979.53, -5209.95, 2.5),
                vector3(5102.49, -5521.18, 54.2),
                vector3(5103.55, -5525.04, 54.22),
                vector3(5109.3, -5519.38, 54.25),
                vector3(5266.21, -5436.13, 65.6),
                vector3(5266.73, -5430.17, 141.05),
                vector3(5379.09, -5387.62, 43.51),
                vector3(5266.23, -5254.83, 25.48),
                vector3(5258.29, -5252.59, 25.37),
                vector3(5328.55, -5270.25, 33.19),
                vector3(5329.95, -5272.05, 33.19),
                vector3(5328.12, -5266.08, 33.19),
                vector3(5404.79, -5171.99, 31.45),
                vector3(5405.83, -5170.5, 31.46)
            },

            -- 物品池
            loot_table = {
                {name = "loot_rusty_watch", label = "生锈的手表", amount = 9},
                {name = "loot_broken_phone", label = "碎裂的手机", amount = 9},
                {name = "loot_empty_wallet", label = "空钱包", amount = 6},
                {name = "loot_mysterious_button", label = "神秘纽扣", amount = 6},
                {name = "loot_rusty_compass", label = "生锈的指南针", amount = 9},
                {name = "loot_ruby_brooch", label = "红宝石胸针", amount = 6},
                {name = "loot_police_radio", label = "丢失的警用对讲机", amount = 6},
                {name = "loot_security_chip", label = "山猫武装主板", amount = 6},
                {name = "loot_rare_keychain", label = "限量钥匙扣", amount = 6},
                {name = "loot_diamond_earring", label = "钻石耳环", amount = 3},
                {name = "loot_secret_documents", label = "绝密文件", amount = 3},
                {name = "loot_sapphire_ring", label = "蓝宝石戒指", amount = 3},
                {name = "loot_pink_diamond", label = "粉钻", amount = 0},
                {name = "loot_cosmic_coin", label = "金色影子硬币", amount = 1}
            }
        },

        -- 区域3：险恶区域
        {
            name = "险恶区域",
            description = "极度危险区域",

            -- 每个点位的物品数量范围
            min_amount_per_point = 3,  -- 最小数量
            max_amount_per_point = 6,  -- 最大数量

            -- 刷新点坐标列表（替换为实际坐标）
            spawn_points = {
                vector3(4503.42, -4521.75, 4.41),
                vector3(4503.86, -4555.48, 4.17),
                vector3(4528.66, -4535.23, 7.55),
                vector3(4504.01, -4547.05, 4.03),
                vector3(4533.31, -4536.86, 4.43),
                vector3(4536.59, -4518.86, 5.14),
                vector3(5064.18, -4590.28, 2.86),
                vector3(5067.33, -4591.47, 2.86),
                vector3(5092.86, -4603.24, 3.06),
                vector3(5117.9, -4611.63, 3.05),
                vector3(5136.56, -4621.85, 2.22),
                vector3(5175.65, -4650.35, 2.83),
                vector3(5092.53, -4683.26, 2.41),
            },

            -- 物品池
            loot_table = {
                {name = "loot_rusty_watch", label = "生锈的手表", amount = 6},
                {name = "loot_broken_phone", label = "碎裂的手机", amount = 6},
                {name = "loot_empty_wallet", label = "空钱包", amount = 3},
                {name = "loot_mysterious_button", label = "神秘纽扣", amount = 3},
                {name = "loot_rusty_compass", label = "生锈的指南针", amount = 6},
                {name = "loot_ruby_brooch", label = "红宝石胸针", amount = 6},
                {name = "loot_police_radio", label = "丢失的警用对讲机", amount = 6},
                {name = "loot_security_chip", label = "山猫武装主板", amount = 6},
                {name = "loot_rare_keychain", label = "限量钥匙扣", amount = 6},
                {name = "loot_diamond_earring", label = "钻石耳环", amount = 3},
                {name = "loot_secret_documents", label = "绝密文件", amount = 6},
                {name = "loot_sapphire_ring", label = "蓝宝石戒指", amount = 3},
                {name = "loot_pink_diamond", label = "粉钻", amount = 0},
                {name = "loot_cosmic_coin", label = "金色影子硬币", amount = 1}
            }
        },

        -- 区域4：隐藏区域
        {
            name = "别墅区",
            description = "高价值区域",

            -- 每个点位的物品数量范围
            min_amount_per_point = 5,  -- 最小数量
            max_amount_per_point = 10, -- 最大数量

            -- 刷新点坐标列表（替换为实际坐标）
            spawn_points = {
                vector3(5006.63, -5786.38, 17.83),
                vector3(5081.32, -5755.03, 15.83),
                vector3(5013.74, -5754.59, 28.9),
                vector3(5006.5, -5753.7, 28.85),
                vector3(4998.49, -5751.78, 14.84),
                vector3(5000.53, -5754.19, 14.84),
                vector3(5003.94, -5749.46, 14.84),
                vector3(5011.32, -5742.87, 15.48),
                vector3(5016.58, -5746.48, 15.48),
                vector3(5014.09, -5752.19, 15.48),
                vector3(5006.55, -5756.15, 15.48),
                vector3(5010.63, -5757.28, 15.48),
                vector3(5029.99, -5737.07, 17.87),
            },

            -- 物品池
            loot_table = {
                {name = "loot_rusty_watch", label = "生锈的手表", amount = 3},
                {name = "loot_broken_phone", label = "碎裂的手机", amount = 3},
                {name = "loot_empty_wallet", label = "空钱包", amount = 0},
                {name = "loot_mysterious_button", label = "神秘纽扣", amount = 0},
                {name = "loot_rusty_compass", label = "生锈的指南针", amount = 3},
                {name = "loot_ruby_brooch", label = "红宝石胸针", amount = 3},
                {name = "loot_police_radio", label = "丢失的警用对讲机", amount = 3},
                {name = "loot_security_chip", label = "山猫武装主板", amount = 3},
                {name = "loot_rare_keychain", label = "限量钥匙扣", amount = 3},
                {name = "loot_diamond_earring", label = "钻石耳环", amount = 0},
                {name = "loot_secret_documents", label = "绝密文件", amount = 2},
                {name = "loot_sapphire_ring", label = "蓝宝石戒指", amount = 0},
                {name = "loot_pink_diamond", label = "粉钻", amount = 0},
                {name = "loot_cosmic_coin", label = "金色影子硬币", amount = 1}
            }
        }
    },

    -- 通知文本
    notifications = {
        pickup_success = "拾取了 %s x%d",
        pickup_failed = "背包已满，无法拾取",
        no_items = "该位置已被搜刮",
        pickup_cancelled = "搜索已取消"
    }
}

-- ==================== 命令权限设置 ====================
Config.Commands = {
    -- 主命令名称
    toggle = "island_toggle",

    -- 状态查询命令
    status = "island_status",

    -- 仅允许控制台执行
    console_only = true
}

-- ==================== 武器箱系统 ====================
Config.WeaponBoxes = {
    -- 武器箱系统总开关
    enabled = true,

    -- 实体模型
    prop_model = 'prop_box_ammo03a',  -- GTA V 弹药箱模型

    -- 生成点位（使用默认位置，后续可替换）
    spawn_points = {
        {coords = vector3(4438.41, -4482.21, 3.41)},
        {coords = vector3(3905.68, -4700.36, 3.43)},
        {coords = vector3(4077.26, -4662.17, 3.37)},
        {coords = vector3(4966.9, -5602.52, 22.79)},
        {coords = vector3(5475.39, -5836.52, 18.67)},
        {coords = vector3(4987.16, -5877.9, 19.64)},
        {coords = vector3(4913.16, -5829.72, 27.16)},
        {coords = vector3(4912.61, -5232.88, 1.62)},
        {coords = vector3(5006.23, -5197.03, 1.61)},
        {coords = vector3(5178.44, -5127.96, 2.2)},
        {coords = vector3(4824.98, -4317.58, 4.49)},
        {coords = vector3(4518.45, -4519.31, 3.47)},
        {coords = vector3(5401.5, -5177.75, 30.54)},
        {coords = vector3(5259.73, -5261.79, 24.56)},
        {coords = vector3(4999.93, -5164.89, 1.86)},
        {coords = vector3(5082.82, -5729.9, 14.87)},
        {coords = vector3(4995.78, -5733.8, 18.98)},
        {coords = vector3(4974.96, -5797.67, 19.98)},
        {coords = vector3(5009.02, -5760.27, 18.99)},
        {coords = vector3(5259.0, -5438.3, 64.54)},
        {coords = vector3(5126.38, -5521.41, 53.29)},
        {coords = vector3(4900.95, -4903.15, 2.47)},
        {coords = vector3(5070.05, -4601.48, 1.96)},
        {coords = vector3(5171.72, -4658.05, 1.63)},
        {coords = vector3(5178.83, -5146.67, 2.35)},
        {coords = vector3(5327.32, -5265.28, 32.24)},
        {coords = vector3(4901.12, -5344.7, 9.25)},
        {coords = vector3(5147.14, -4934.02, 14.57)},
        {coords = vector3(5191.25, -5011.43, 13.01)},
        {coords = vector3(5203.52, -5119.57, 5.25)},
    },

    -- ox_target 交互配置
    interaction = {
        distance = 2.5,              -- 交互距离
        label = '搜索武器箱',        -- 交互文本
        icon = 'fas fa-box-open',    -- 图标
    },

    -- 进度条配置 (使用 ox_lib)
    progress = {
        duration = 8000,                 -- 搜索时长 (毫秒)
        label = '正在搜索武器箱...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
        },
        animation = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer',
            flag = 1,
        },
    },

    -- 物品池（加权随机）
    -- 格式: {item = '物品代码', min = 最小数量, max = 最大数量, weight = 权重}
    -- 权重越高，被抽中概率越大
    -- 每次开箱保证获得一个物品
    loot_table = {
        {item = 'weapon_sawnoffshotgun', min = 1, max = 1, weight = 20},
        {item = 'weapon_g17tan', min = 1, max = 1, weight = 30},
        {item = 'pistol_ammo', min = 1, max = 3, weight = 18},
        {item = 'shotgun_ammo', min = 1, max = 3, weight = 12},
        {item = 'armor', min = 2, max = 3, weight = 20},
    },

    -- 调试模式
    debug = false,
}

-- ==================== 复活系统 ====================
Config.Revival = {
    -- 是否启用复活系统
    enabled = false,

    -- 最大复活次数
    max_revives = 2,

    -- 复活等待位置（航空母舰）
    waiting_point = vector3(3092.99, -4717.15, 15.26),
    waiting_heading = 0.0,

    -- 携带武器复活的费用（美元）
    weapon_cost = 1300,

    -- 默认武器配置（物品形式）
    weapon_item = 'weapon_switchblade',  -- 武器物品代码
    weapon_label = '弹簧刀',             -- 武器显示名称
    weapon_amount = 1,                    -- 物品数量
    weapon_give_delay = 15000,            -- 武器给予延迟（毫秒，等待玩家着陆）

    -- 通知消息
    notifications = {
        revival_success = '复活成功! 准备重新空投...',
        revival_declined = '你已退出本次行动!',
        insufficient_funds = '余额不足，无法携带武器!',
        max_revives_reached = '复活次数已用尽，无法继续行动!',
        weapon_incoming = '15秒后将获得武器，请注意安全着陆!',
        weapon_received = '已获得武器: ',
    },

    -- 复活菜单配置
    menu = {
        title = '复活选项',
        description_template = '死亡次数: %d | 剩余复活次数: %d',

        -- 菜单选项
        options = {
            with_weapon = {
                title = '携带武器复活 ($%d)',
                description = '花费 $%d 携带%s重新空投到岛上',
                icon = 'gun',
            },
            without_weapon = {
                title = '空手复活 (免费)',
                description = '免费重新空投到岛上，但不携带任何武器',
                icon = 'person-running',
            },
            decline = {
                title = '放弃行动',
                description = '退出本次活动，传送回集结点',
                icon = 'circle-xmark',
            },
        },
    },
}
