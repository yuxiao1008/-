Config = {}

-- 就业点位置配置
Config.JobCenters = {
    {
        coords = vector3(-235.39, -920.63, 32.31), -- 就业中心坐标
        heading = 0.0,
        blipSprite = 280, -- 雷达图标
        blipColor = 5,
        blipScale = 1.0,
        blipName = "就业中心",
        targetLabel = "查看工作机会", -- ox-target互动文本
        targetIcon = "fas fa-briefcase",
        targetDistance = 2.0
    }
}

-- 职业配置
Config.Jobs = {
    {
        name = "baoyang", -- 职业代码
        label = "车辆保养师", -- 职业显示名称
        description = "保养市民车辆获取报酬", -- 职业描述
        salary = 600, -- 基础工资
        icon = "fas fa-wrench",--fas fa-wrench
        helpText = {
            "1. 前往3052地区，打开进货商店",
            "2. 购买保养材料",
            "3. 使用F1打开工作，点击平板，打开平板，",
            "4. 平板选择保养，然后连接车辆，进行保养即可",
            "提示：合格的保养师，记得上班，不然无法接到电话！"
        }
    },
    {
        name = "taxi",
        label = "出租车司机",
        description = "接取乘客订单并送达目的地",
        salary = 1500,
        icon = "fas fa-taxi",
        helpText = {
            "1. 前往7295出租车公司取车",
            "2. 取车后按F1——工作，打开工作相关信息",
            "3. 接收市民订单，送达目的地",
            "4. 完成订单获得报酬",
            "提示：如果你完好的驾驶一段行程，出租车老板格瑞会给你更多的报酬！"
        }
    },
    -- {
    --     name = "delivery",
    --     label = "快递员",
    --     description = "配送包裹和货物到指定地点",
    --     salary = 40,
    --     icon = "fas fa-truck",
    --     helpText = {
    --         "1. 前往快递公司接取任务",
    --         "2. 驾驶配送车辆",
    --         "3. 按时配送包裹到指定地点",
    --         "4. 完成配送获得报酬",
    --         "提示：准时配送可获得额外小费！"
    --     }
    -- },
    -- {
    --     name = "garbage",
    --     label = "垃圾清理工",
    --     description = "清理城市垃圾维护环境卫生",
    --     salary = 35,
    --     icon = "fas fa-trash",
    --     helpText = {
    --         "1. 前往垃圾处理站获取车辆",
    --         "2. 驾驶垃圾车到各个垃圾点",
    --         "3. 收集垃圾并清理街道",
    --         "4. 返回处理站完成任务",
    --         "提示：清理更多垃圾点可获得奖励！"
    --     }
    -- },
    -- {
    --     name = "mining",
    --     label = "矿工",
    --     description = "在矿场开采各种矿物资源",
    --     salary = 60,
    --     icon = "fas fa-hammer",
    --     helpText = {
    --         "1. 前往矿场租用采矿设备",
    --         "2. 寻找矿物节点进行开采",
    --         "3. 收集矿物资源",
    --         "4. 出售矿物获得收入",
    --         "提示：稀有矿物价值更高！"
    --     }
    -- }
}

-- 菜单配置
Config.MenuTitle = "就业中心"
Config.MenuSubtitle = "选择你的职业"

-- 通知消息配置
Config.Notifications = {
    jobChanged = "你已成功入职：%s",
    alreadyHaveJob = "你已经有工作了！",
    noJobAvailable = "当前没有可用的工作",
    helpTitle = "工作帮助 - %s"
}

-- ox-lib配置
Config.UseOxLib = true

-- 调试模式
Config.Debug = false