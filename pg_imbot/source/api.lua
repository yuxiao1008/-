---KOOK API请求
---@param action string
---@param data table
---@param method? 'POST' | 'GET'
---@param cb? function
function KOOK_PerformApiRequest(action, data, method, cb)
    PerformHttpRequest(('https://www.kookapp.cn/api/v%s%s'):format(Config.KOOK.ApiVersion, action), function(code, text, headers)
        if cb then
            cb(code, text, headers)
        end
    end, method or 'POST', json.encode(data), {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bot ' .. Config.KOOK.Token
    })
end
exports('KOOK_PerformApiRequest', KOOK_PerformApiRequest)

---QQ API请求
---@param action string
---@param data table
---@param cb? function
function QQ_PerformApiRequest(action, data, cb)
    PerformHttpRequest(('http://%s:%s/%s'):format(Config.QQ.Host, Config.QQ.Port, action), function(code, text, headers)
        if cb then
            cb(code, text, headers)
        end
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json' })
end
exports('QQ_PerformApiRequest', QQ_PerformApiRequest)
