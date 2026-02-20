---添加事件处理程序
---@param event string
---@param id string
---@param cb fun(data)
function QQ_AddEventHandler(event, id, cb)
    if not _g.QQEventsHandler[event] then _g.QQEventsHandler[event] = {} end
	_g.QQEventsHandler[event][id] = cb
end
exports('QQ_AddEventHandler', QQ_AddEventHandler)

local QQCommandHandler = {}

---@class QQCommandProperties
---@field params ImBotCommandParams[]?
---@field restricted? { user_id?: number | number[], group_id?: number | number[] }

---添加命令
---@param command string
---@param properties QQCommandProperties
---@param cb fun(args, rawData)
function QQ_AddCommand(command, properties, cb)
	QQCommandHandler[command] = { cb = cb, params = properties.params, restricted = properties.restricted }
end
exports('QQ_AddCommand', QQ_AddCommand)

-- 处理命令
QQ_AddEventHandler('message', 'CommandHandler', function(_, response, data)
    if string.sub(data.raw_message, 1, _g.commandSymbolLen) == Config.CommandSymbol then
		local raw = string.sub(data.raw_message, _g.commandSymbolLen + 1)
		local args = { string.strsplit(' ', raw) }
		local command = QQCommandHandler[args[1]]
		table.remove(args, 1)
		if command then
			-- 权限检查
            if command.restricted then
				local restricted = command.restricted
                -- 检查是否特定账号私聊
                if data.message_type == 'private' and restricted.user_id and not lib.table.contains(
					type(restricted.user_id) == 'table' and restricted.user_id or { restricted.user_id }, data.user_id) then return end

                -- 检查是否特定群聊
                if data.message_type == 'group' and restricted.group_id and not lib.table.contains(
					type(restricted.group_id) == 'table' and restricted.group_id or { restricted.group_id }, data.group_id) then return end
            end

			-- 参数解析
			local parseResp = ParseArguments(args, raw, command.params)
			if type(parseResp) == 'table' then
				args = parseResp
			else
				response.writeHead(200)
				response.send(json.encode({
					reply = parseResp,
				}))
				return
			end

			local callbackSuccess, callbackResp = pcall(command.cb, args, raw)
			if not callbackSuccess then
				response.writeHead(200)
				response.send(json.encode({
					reply = ("命令 '%s' 执行失败！\n%s"):format(string.strsplit(' ', raw) or raw, callbackResp),
				}))
			end
		end
	end
end)
