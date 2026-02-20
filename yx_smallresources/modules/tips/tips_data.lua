--[[
    温馨提示模块 - 提示库数据
    在此添加或修改游戏提示内容
]]

TipsData = TipsData or {}

-- 防重复配置: 最近N条提示内不允许重复
TipsData.HistorySize = 5

-- 历史记录表 (存储最近发送的提示索引)
TipsData.History = {}

-- 提示库列表
-- 添加新提示只需在此表中新增一行即可
TipsData.List = {
    -- 游戏玩法提示
    "你如果被抢劫，OOC规则上，你有权利要求将自己的手机卡弹出，再交出手机，以保证自己的数据安全",
    "游戏中请尽量使用OBS或者N卡的即时回放功能，以保证自己的个人权益不受侵犯",
    "如果想联系管理员，请前往KOOK[开工单]频道找到我们",
    "车载电台可以保存你的电台音乐信息",
    "我们的玩家手册包含了基本上所有的常见问题和解决方法",
    "如果你上半身受伤，你将无法稳定的举枪瞄准",
    "购买房子可以让你有一个永久的家，你可以在房屋内存储物品、更换衣服等",
    "按~键可以调整自己说话的音量和范围",
    "左Ctrl可以下蹲，右Ctrl可以趴下",
    "获取非法玩法方式最好办法就是通过扮演询问其他非法玩家获取线索",
    "记得定期去ATM机存钱，身上携带大量现金很危险",
    "使用100K、改变天空盒、除草等画质包属于严重违规行为，后台发现第二次将永久封禁",
    "就业中心提供完整的就业信息，你可以在就业中心找到适合自己的工作",
    "不同的非法物品，可能从其他人的手里买更便宜",
    "产业或者组织并不是富豪的专属，只要你愿意，你也主动申请自己的产业",
}

--- 检查索引是否在历史记录中
--- @param index number 提示索引
--- @return boolean 是否在历史中
local function isInHistory(index)
    for _, historyIndex in ipairs(TipsData.History) do
        if historyIndex == index then
            return true
        end
    end
    return false
end

--- 添加索引到历史记录
--- @param index number 提示索引
local function addToHistory(index)
    table.insert(TipsData.History, index)
    -- 维护历史记录长度不超过 HistorySize
    while #TipsData.History > TipsData.HistorySize do
        table.remove(TipsData.History, 1)
    end
end

--- 获取随机提示 (保证最近N条不重复)
--- @return string 随机提示文本
function TipsData.GetRandomTip()
    local totalCount = #TipsData.List
    local historySize = math.min(TipsData.HistorySize, totalCount - 1)
    
    -- 如果提示数量太少，无法保证不重复，降低要求
    if totalCount <= 1 then
        return TipsData.List[1] or "暂无提示"
    end
    
    local index
    local maxAttempts = 50 -- 防止死循环
    local attempts = 0
    
    repeat
        index = math.random(1, totalCount)
        attempts = attempts + 1
    until not isInHistory(index) or attempts >= maxAttempts
    
    -- 添加到历史记录
    addToHistory(index)
    
    return TipsData.List[index]
end

--- 获取提示总数
--- @return number 提示总数
function TipsData.GetTotalCount()
    return #TipsData.List
end

