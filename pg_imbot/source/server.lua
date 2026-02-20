_g = {
	KOOKEventsHandler = {},
	QQEventsHandler = {},
	commandSymbolLen = string.len(Config.CommandSymbol),
}

---@class ImBotCommandParams
---@field name string
---@field type? 'number' | 'playerId' | 'string' | 'longString'
---@field optional? boolean

---@param args table
---@param raw string
---@param params ImBotCommandParams[]?
---@return table | string
function ParseArguments(args, raw, params)
    if not params then return args end

    local paramsNum = #params
    for i = 1, paramsNum do
        local arg, param = args[i], params[i]
        local value

        if param.type == 'number' then
            value = tonumber(arg)
        elseif param.type == 'string' then
            value = arg  -- 接受任何字符串，包括纯数字
        elseif param.type == 'playerId' then
            if not arg or not DoesPlayerExist(arg) then
                value = false
			else
				value = tonumber(arg)
            end
        elseif param.type == 'longString' and i == paramsNum then
            if arg then
                local start = raw:find(arg, 1, true)
                value = start and raw:sub(start)
            else
                value = nil
            end
        elseif param.type == 'identifier' then
            -- 专门处理玩家标识符（ID或识别码）
            value = arg
        else
            value = arg
        end

        if not value and (not param.optional or param.optional and arg) then
			return ("命令 '%s' 的参数 %s (%s) 接收到无效的 %s，实际收到 '%s'"):format(string.strsplit(' ', raw) or raw, i, param.name, param.type, arg)
        end

        arg = value

        args[param.name] = arg
        args[i] = nil
    end

    return args
end

---调用事件处理程序
---@param handlers table
---@param request table
---@param response table
---@param data table
local function callEventHandler(handlers, request, response, data)
	if handlers then
		for _, v in pairs(handlers) do
			local doBreak = false
			local _response = setmetatable({}, {
				__index = function(self, index)
					doBreak = true
					return response[index]
				end,
			})
			v(request, _response, data)

			-- 防止重复发送返回信息
			if doBreak then return end
		end
	end

	-- 若对应事件没有注册的处理程序, 或没有处理程序响应, 返回默认响应
	response.writeHead(200)
	response.send()
end

-- HTTP请求处理
SetHttpHandler(function(request, response)
	-- 请求方式错误
	if request.method == 'GET' then
		response.writeHead(404)
		response.send()
		return
	end

	request.setDataHandler(function(data)
		local _data = json.decode(data)
		if request.path:find('/kook') and _data.d.verify_token == Config.KOOK.VerifyToken then
			callEventHandler(_g.KOOKEventsHandler[_data.d.channel_type], request, response, _data.d)
		elseif request.path == '/qq' and string.match(request.address, "([^:]+)") == Config.QQ.Host then
			callEventHandler(_g.QQEventsHandler[_data.post_type], request, response, _data)
		else
			response.writeHead(404)
			response.send()
		end
	end)
end)
