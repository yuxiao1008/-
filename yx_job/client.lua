local QBCore = exports['qb-core']:GetCoreObject()
local lib = exports['ox_lib']
local PlayerData = QBCore.Functions.GetPlayerData()

-- 监听玩家数据更新
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    CreateJobCenterBlips()
    SetupJobCenterTargets()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- 创建雷达点
function CreateJobCenterBlips()
    for k, v in pairs(Config.JobCenters) do
        local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
        SetBlipSprite(blip, v.blipSprite)
        SetBlipColour(blip, v.blipColor)
        SetBlipScale(blip, v.blipScale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(v.blipName)
        EndTextCommandSetBlipName(blip)
    end
end

-- 设置ox-target互动点
function SetupJobCenterTargets()
    if not exports['ox_target'] then
        print("错误：未找到ox_target资源")
        return
    end
    
    for k, v in pairs(Config.JobCenters) do
        exports['ox_target']:addBoxZone({
            coords = v.coords,
            size = vec3(2, 2, 2),
            rotation = v.heading,
            options = {
                {
                    name = 'job_center_' .. k,
                    icon = v.targetIcon,
                    label = v.targetLabel,
                    distance = v.targetDistance,
                    onSelect = function()
                        OpenJobMenu()
                    end
                }
            }
        })
    end
end

-- 打开就业菜单
function OpenJobMenu()
    -- 基础检查
    if not lib then
        print("错误：未找到ox_lib资源")
        return
    end
    
    if not Config or not Config.Jobs then
        print("错误：配置未正确加载")
        return
    end
    
    -- 构建简单的选项数组
    local options = {}
    
    -- 简化的job选项构建
    for _, job in pairs(Config.Jobs) do
        if job.name and job.label and job.description then
            local option = {
                title = job.label,
                description = job.description .. " (基础时薪工资: $" .. (job.salary or 0) .. ")",
                icon = job.icon,
                onSelect = function()
                    -- 如果是当前职业，显示职业管理菜单
                    if PlayerData and PlayerData.job and PlayerData.job.name == job.name then
                        ShowCurrentJobMenu(job.name, job.label, job.helpText)
                    else
                        -- 否则选择新职业
                        SelectJob(job.name, job.label, job.helpText)
                    end
                end
            }
            
            -- 标识当前职业但不禁用
            if PlayerData and PlayerData.job and PlayerData.job.name == job.name then
                option.description = option.description .. " - 当前职业"
            end
            
            options[#options + 1] = option
        end
    end
    
    if #options == 0 then
        QBCore.Functions.Notify("没有可用的工作", 'error')
        return
    end
    
    -- 直接调用，使用最简单的结构
    exports.ox_lib:registerContext({
        id = 'job_menu',
        title = Config.MenuTitle or "就业中心", 
        options = options
    })
    
    exports.ox_lib:showContext('job_menu')
end

-- 显示当前职业管理菜单
function ShowCurrentJobMenu(jobName, jobLabel, helpText)
    local options = {}
    
    -- 查看工作帮助选项
    options[#options + 1] = {
        title = "查看工作帮助",
        description = "查看 " .. jobLabel .. " 的详细工作指南",
        icon = "fas fa-question-circle",
        onSelect = function()
            ShowJobHelp(jobLabel, helpText)
        end
    }
    
    -- 辞职选项
    options[#options + 1] = {
        title = "辞去工作",
        description = "辞去当前的 " .. jobLabel .. " 工作",
        icon = "fas fa-times-circle",
        onSelect = function()
            ShowQuitJobConfirm(jobName, jobLabel)
        end
    }
    
    -- 返回选项
    options[#options + 1] = {
        title = "返回",
        description = "返回就业中心主菜单",
        icon = "fas fa-arrow-left",
        onSelect = function()
            OpenJobMenu()
        end
    }
    
    exports.ox_lib:registerContext({
        id = 'current_job_menu',
        title = "职业管理 - " .. jobLabel,
        options = options
    })
    
    exports.ox_lib:showContext('current_job_menu')
end

-- 显示辞职确认菜单
function ShowQuitJobConfirm(jobName, jobLabel)
    local options = {}
    
    -- 确认辞职
    options[#options + 1] = {
        title = "确认辞职",
        description = "确认辞去 " .. jobLabel .. " 工作，成为无业人员",
        icon = "fas fa-check-circle",
        onSelect = function()
            QuitJob(jobName, jobLabel)
        end
    }
    
    -- 取消
    options[#options + 1] = {
        title = "取消",
        description = "取消辞职，返回职业管理",
        icon = "fas fa-times",
        onSelect = function()
            -- 从Config中重新获取helpText
            local helpText = nil
            for _, job in pairs(Config.Jobs or {}) do
                if job.name == jobName then
                    helpText = job.helpText
                    break
                end
            end
            ShowCurrentJobMenu(jobName, jobLabel, helpText)
        end
    }
    
    exports.ox_lib:registerContext({
        id = 'quit_job_confirm',
        title = "辞职确认",
        options = options
    })
    
    exports.ox_lib:showContext('quit_job_confirm')
end

-- 辞职处理
function QuitJob(jobName, jobLabel)
    -- 触发服务器事件辞职
    TriggerServerEvent('yx_job:server:quitJob', jobName, jobLabel)
    
    -- 关闭所有菜单
    exports.ox_lib:hideContext()
    
    -- 显示辞职成功消息
    QBCore.Functions.Notify("你已成功辞去 " .. jobLabel .. " 的工作", 'success')
end

-- 选择职业
function SelectJob(jobName, jobLabel, helpText)
    -- 检查玩家是否已经有工作
    if PlayerData and PlayerData.job and PlayerData.job.name ~= 'unemployed' then
        local alreadyHaveJobMsg = (Config.Notifications and Config.Notifications.alreadyHaveJob) or "你已经有工作了！"
        QBCore.Functions.Notify(alreadyHaveJobMsg, 'error')
        return
    end
    
    -- 触发服务器事件设置职业
    TriggerServerEvent('yx_job:server:setJob', jobName)
    
    -- 显示工作帮助
    ShowJobHelp(jobLabel, helpText)
end

-- 显示工作帮助
function ShowJobHelp(jobLabel, helpText)
    if not helpText or #helpText == 0 then
        return
    end
    
    local helpOptions = {}
    
    for i, text in ipairs(helpText) do
        helpOptions[#helpOptions + 1] = {
            title = "步骤 " .. i,
            description = text,
            icon = "fas fa-info-circle"
        }
    end
    
    helpOptions[#helpOptions + 1] = {
        title = "关闭帮助",
        description = "祝你工作愉快！",
        icon = "fas fa-times",
        onSelect = function()
            exports.ox_lib:hideContext()
        end
    }
    
    exports.ox_lib:registerContext({
        id = 'job_help',
        title = "工作帮助 - " .. jobLabel,
        options = helpOptions
    })
    
    exports.ox_lib:showContext('job_help')
end

-- 调试功能（可选）
if Config and Config.Debug then
    RegisterCommand('jobmenu', function()
        OpenJobMenu()
    end, false)
    
    RegisterCommand('jobhelp', function(source, args)
        if args[1] then
            local jobName = args[1]
            for k, v in pairs(Config.Jobs or {}) do
                if v.name == jobName then
                    ShowJobHelp(v.label, v.helpText)
                    return
                end
            end
            print("未找到职业: " .. jobName)
        else
            print("用法: /jobhelp [职业名称]")
        end
    end, false)
    
    -- 添加配置检查命令
    RegisterCommand('checkconfig', function()
        print("=== 配置检查 ===")
        print("Config 存在:", Config ~= nil)
        if Config then
            print("Config.Jobs 存在:", Config.Jobs ~= nil)
            if Config.Jobs then
                print("Jobs 数量:", #Config.Jobs)
                for i, job in ipairs(Config.Jobs) do
                    print("Job " .. i .. ":", job.name, job.label)
                end
            end
            print("Config.MenuTitle:", Config.MenuTitle)
        end
        print("PlayerData 存在:", PlayerData ~= nil)
        if PlayerData then
            print("PlayerData.job 存在:", PlayerData.job ~= nil)
            if PlayerData.job then
                print("当前职业:", PlayerData.job.name)
            end
        end
    end, false)
end

-- 初始化
CreateThread(function()
    Wait(1000)
    CreateJobCenterBlips()
    SetupJobCenterTargets()
end)