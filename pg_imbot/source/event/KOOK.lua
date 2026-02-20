---添加事件处理程序
---@param event string
---@param id string
---@param cb fun(request, response, data)
function KOOK_AddEventHandler(event, id, cb)
	if not _g.KOOKEventsHandler[event] then _g.KOOKEventsHandler[event] = {} end
	_g.KOOKEventsHandler[event][id] = cb
end
exports('KOOK_AddEventHandler', KOOK_AddEventHandler)

---处理 Challenge 请求
KOOK_AddEventHandler('WEBHOOK_CHALLENGE', 'WebChallenge', function(_, response, data)
	response.send(json.encode({ challenge = data.challenge }))
end)

local KOOKCommandHandler = {}

---@class KOOKCommandProperties
---@field params ImBotCommandParams[]?
---@field restricted? { target_id?: string | string[], role_id?: number | number[] }

---添加命令
---@param command string
---@param properties KOOKCommandProperties
---@param cb fun(args, rawData)
function KOOK_AddCommand(command, properties, cb)
	KOOKCommandHandler[command] = { cb = cb, params = properties.params, restricted = properties.restricted }
end
exports('KOOK_AddCommand', KOOK_AddCommand)

---处理命令
KOOK_AddEventHandler('GROUP', 'CommandHandler', function(_, _, data)
	if data.type ~= 1 and data.type ~= 9 then return end

	-- 获取消息内容并分割成数组
	local args = { string.strsplit(' ', data.content) }
		local command = KOOKCommandHandler[args[1]]
	
	-- 如果第一个词是已注册的命令
	if command then
		table.remove(args, 1)
		
			-- 权限检查
			if command.restricted then
				local restricted = command.restricted

				-- 检查是否在指定频道
				if restricted.target_id and not lib.table.contains(
					type(restricted.target_id) == 'table' and restricted.target_id or { restricted.target_id }, data.target_id) then return end

				-- 检查是否有所需角色
				if restricted.role_id then
					if type(restricted.role_id) == 'table' then
						local hasrole = false
						for _, v1 in pairs(restricted.role_id) do
							for _, v2 in pairs(data.extra.author.roles) do
								if v1 == v2 then
									hasrole = true
									break
								end
							end
						end
						if not hasrole then return end
					else
						if not lib.table.contains(data.extra.author.roles, restricted.role_id) then return end
					end
				end
			end

			-- 参数解析
		local parseResp = ParseArguments(args, data.content, command.params)
			if type(parseResp) == 'table' then
				args = parseResp
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = parseResp,
				})
				return
			end

		local callbackSuccess, callbackResp = pcall(command.cb, args, data.content, data)
			if not callbackSuccess then
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = ("命令 '%s' 执行失败！\n%s"):format(args[1] or data.content, callbackResp),
			})
		end
	end
end)

--- 辅助函数：根据社安号获取在线玩家ID
---@param citizenid string
---@return number|nil playerId 如果玩家在线返回ID，否则返回nil
local function GetPlayerIdByCitizenId(citizenid)
	local QBCore = exports['qb-core']:GetCoreObject()
	local players = QBCore.Functions.GetQBPlayers()

	for playerId, player in pairs(players) do
		if player.PlayerData.citizenid == citizenid then
			return tonumber(playerId)
		end
	end

	return nil
end

KOOK_AddCommand('跳脸杀', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发跳脸杀事件
		TriggerClientEvent('yx_jump:showFaceKill', player)
		
		-- 发送成功消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已对玩家 %s 执行跳脸杀', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('脱困', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 设置玩家位置
		local coords = vector3(225.44, -796.58, 30.66)
		SetEntityCoords(GetPlayerPed(player), coords.x, coords.y, coords.z)
		
		-- 发送成功消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已将玩家 %s 传送至脱困点', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('复活', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId

	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()

	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)

	if targetPlayer then
		-- 触发新的复活导出
		local success, err = pcall(function()
			exports['wasabi_ambulance']:RevivePlayer(player)
		end)

		if success then
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已复活玩家 %s', GetPlayerName(player))
			})
		else
			-- 发送失败消息（调用导出失败）
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('复活玩家时发生错误: %s', err or '未知错误')
			})
		end
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('改名', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'firstname', type = 'string' },
		{ name = 'lastname', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local firstname = args.firstname
	local lastname = args.lastname
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 查询玩家信息
	exports.oxmysql:query('SELECT * FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result[1] then
			-- 获取原始角色信息
			local oldCharInfo = json.decode(result[1].charinfo)
			local oldFullName = oldCharInfo.firstname .. " " .. oldCharInfo.lastname
			
			-- 先查找在线玩家并踢出
			local player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
			if player then
				DropPlayer(player.PlayerData.source, '改名生效，需要重新登陆')
				Wait(500)
			end
			
			-- 更新角色信息
			oldCharInfo.firstname = firstname
			oldCharInfo.lastname = lastname
			
			-- 更新数据库
			exports.oxmysql:execute('UPDATE players SET charinfo = ? WHERE citizenid = ?', 
				{json.encode(oldCharInfo), citizenid}, 
				function()
					-- 发送成功消息
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format([[已将玩家改名
社安号：%s
原姓名：%s
现姓名：%s %s]], 
							citizenid,
							oldFullName,
							firstname,
							lastname
						)
					})
				end
			)
		else
			-- 发送未找到玩家消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)


KOOK_AddCommand('给钱', {
	params = {
		{ name = 'identifier', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local identifier = args.identifier
	local amount = args.amount

	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()

	-- 检测输入类型
	local numericId = tonumber(identifier)
	local isCitizenId = string.len(identifier) == 8 and string.match(identifier, '^[A-Z0-9]+$')

	-- 情况1: 输入的是纯数字（可能是在线ID）
	if numericId and not isCitizenId then
		-- 检查玩家是否在线
		if DoesPlayerExist(numericId) then
			local targetPlayer = QBCore.Functions.GetPlayer(numericId)

			if targetPlayer then
				targetPlayer.Functions.AddMoney('bank', amount)

				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('✅ 已给予在线玩家 %s (ID: %s) $%s 银行存款', GetPlayerName(numericId), numericId, amount)
				})
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定在线玩家'
				})
			end
		else
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 玩家ID ' .. numericId .. ' 不在线，请使用社安号进行离线操作'
			})
		end
	-- 情况2: 输入的是社安号
	elseif isCitizenId then
		-- 先检查该社安号的玩家是否在线
		local onlinePlayerId = GetPlayerIdByCitizenId(identifier)

		if onlinePlayerId then
			-- 玩家在线，使用内存操作
			local targetPlayer = QBCore.Functions.GetPlayer(onlinePlayerId)

			if targetPlayer then
				targetPlayer.Functions.AddMoney('bank', amount)

				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('✅ 已给予在线玩家 %s (社安号: %s) $%s 银行存款', GetPlayerName(onlinePlayerId), identifier, amount)
				})
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定在线玩家'
				})
			end
		else
			-- 玩家离线，使用数据库操作
			exports.oxmysql:query('SELECT citizenid, charinfo, money FROM players WHERE citizenid = ?', {identifier}, function(result)
				if result and result[1] then
					local currentMoney = json.decode(result[1].money)
					currentMoney.bank = (currentMoney.bank or 0) + amount

					exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?',
						{json.encode(currentMoney), identifier},
						function(executeResult)
							if executeResult and executeResult.affectedRows and executeResult.affectedRows > 0 then
								local charInfo = json.decode(result[1].charinfo)
								local playerName = charInfo.firstname .. ' ' .. charInfo.lastname

								KOOK_PerformApiRequest('/message/create', {
									type = 1,
									target_id = data.target_id,
									quote = data.msg_id,
									content = string.format('✅ 已给予离线玩家 %s (社安号: %s) $%s 银行存款\n💰 当前银行余额: $%s',
										playerName, identifier, amount, currentMoney.bank)
								})
							else
								KOOK_PerformApiRequest('/message/create', {
									type = 1,
									target_id = data.target_id,
									quote = data.msg_id,
									content = '❌ 数据库更新失败'
								})
							end
						end
					)
				else
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = '❌ 找不到指定社安号的玩家'
					})
				end
			end)
		end
	else
		-- 无效输入格式
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '❌ 无效的输入格式\n请输入：\n• 在线玩家ID (纯数字)\n• 社安号 (8位大写字母数字组合)'
		})
	end
end)

KOOK_AddCommand('减钱', {
	params = {
		{ name = 'identifier', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local identifier = args.identifier
	local amount = args.amount

	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()

	-- 检测输入类型
	local numericId = tonumber(identifier)
	local isCitizenId = string.len(identifier) == 8 and string.match(identifier, '^[A-Z0-9]+$')

	-- 情况1: 输入的是纯数字（可能是在线ID）
	if numericId and not isCitizenId then
		-- 检查玩家是否在线
		if DoesPlayerExist(numericId) then
			local targetPlayer = QBCore.Functions.GetPlayer(numericId)

			if targetPlayer then
				local currentBank = targetPlayer.Functions.GetMoney('bank')
				local currentCash = targetPlayer.Functions.GetMoney('cash')
				local totalMoney = currentBank + currentCash

				if totalMoney >= amount then
					-- 优先扣除银行存款
					if currentBank >= amount then
						targetPlayer.Functions.RemoveMoney('bank', amount)
						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('✅ 已从在线玩家 %s (ID: %s) 扣除 $%s 银行存款', GetPlayerName(numericId), numericId, amount)
						})
					else
						-- 银行不足，先扣完银行再扣现金
						local needFromCash = amount - currentBank
						if currentBank > 0 then
							targetPlayer.Functions.RemoveMoney('bank', currentBank)
						end
						targetPlayer.Functions.RemoveMoney('cash', needFromCash)

						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('✅ 已从在线玩家 %s (ID: %s) 扣除 $%s\n💰 银行扣除: $%s，现金扣除: $%s',
								GetPlayerName(numericId), numericId, amount, currentBank, needFromCash)
						})
					end
				else
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('❌ 玩家 %s 余额不足\n💰 银行: $%s，现金: $%s，总计: $%s，需要: $%s',
							GetPlayerName(numericId), currentBank, currentCash, totalMoney, amount)
					})
				end
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定在线玩家'
				})
			end
		else
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 玩家ID ' .. numericId .. ' 不在线，请使用社安号进行离线操作'
			})
		end
	-- 情况2: 输入的是社安号
	elseif isCitizenId then
		-- 先检查该社安号的玩家是否在线
		local onlinePlayerId = GetPlayerIdByCitizenId(identifier)

		if onlinePlayerId then
			-- 玩家在线，使用内存操作
			local targetPlayer = QBCore.Functions.GetPlayer(onlinePlayerId)

			if targetPlayer then
				local currentBank = targetPlayer.Functions.GetMoney('bank')
				local currentCash = targetPlayer.Functions.GetMoney('cash')
				local totalMoney = currentBank + currentCash

				if totalMoney >= amount then
					-- 优先扣除银行存款
					if currentBank >= amount then
						targetPlayer.Functions.RemoveMoney('bank', amount)
						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('✅ 已从在线玩家 %s (社安号: %s) 扣除 $%s 银行存款', GetPlayerName(onlinePlayerId), identifier, amount)
						})
					else
						-- 银行不足，先扣完银行再扣现金
						local needFromCash = amount - currentBank
						if currentBank > 0 then
							targetPlayer.Functions.RemoveMoney('bank', currentBank)
						end
						targetPlayer.Functions.RemoveMoney('cash', needFromCash)

						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('✅ 已从在线玩家 %s (社安号: %s) 扣除 $%s\n💰 银行扣除: $%s，现金扣除: $%s',
								GetPlayerName(onlinePlayerId), identifier, amount, currentBank, needFromCash)
						})
					end
				else
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('❌ 玩家 %s 余额不足\n💰 银行: $%s，现金: $%s，总计: $%s，需要: $%s',
							GetPlayerName(onlinePlayerId), currentBank, currentCash, totalMoney, amount)
					})
				end
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定在线玩家'
				})
			end
		else
			-- 玩家离线，使用数据库操作
			exports.oxmysql:query('SELECT citizenid, charinfo, money FROM players WHERE citizenid = ?', {identifier}, function(result)
				if result and result[1] then
					local currentMoney = json.decode(result[1].money)
					local currentBank = currentMoney.bank or 0
					local currentCash = currentMoney.cash or 0
					local totalMoney = currentBank + currentCash

					if totalMoney >= amount then
						-- 优先扣除银行存款
						if currentBank >= amount then
							currentMoney.bank = currentBank - amount

							exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?',
								{json.encode(currentMoney), identifier},
								function(executeResult)
									if executeResult and executeResult.affectedRows and executeResult.affectedRows > 0 then
										local charInfo = json.decode(result[1].charinfo)
										local playerName = charInfo.firstname .. ' ' .. charInfo.lastname

										KOOK_PerformApiRequest('/message/create', {
											type = 1,
											target_id = data.target_id,
											quote = data.msg_id,
											content = string.format('✅ 已从离线玩家 %s (社安号: %s) 扣除 $%s 银行存款\n💰 剩余银行余额: $%s',
												playerName, identifier, amount, currentMoney.bank)
										})
									else
										KOOK_PerformApiRequest('/message/create', {
											type = 1,
											target_id = data.target_id,
											quote = data.msg_id,
											content = '❌ 数据库更新失败'
										})
									end
								end
							)
						else
							-- 银行不足，先扣完银行再扣现金
							local needFromCash = amount - currentBank
							local bankDeducted = currentBank
							currentMoney.bank = 0
							currentMoney.cash = currentCash - needFromCash

							exports.oxmysql:execute('UPDATE players SET money = ? WHERE citizenid = ?',
								{json.encode(currentMoney), identifier},
								function(executeResult)
									if executeResult and executeResult.affectedRows and executeResult.affectedRows > 0 then
										local charInfo = json.decode(result[1].charinfo)
										local playerName = charInfo.firstname .. ' ' .. charInfo.lastname

										KOOK_PerformApiRequest('/message/create', {
											type = 1,
											target_id = data.target_id,
											quote = data.msg_id,
											content = string.format('✅ 已从离线玩家 %s (社安号: %s) 扣除 $%s\n💰 银行扣除: $%s，现金扣除: $%s\n💰 剩余银行: $%s，剩余现金: $%s',
												playerName, identifier, amount, bankDeducted, needFromCash, currentMoney.bank, currentMoney.cash)
										})
									else
										KOOK_PerformApiRequest('/message/create', {
											type = 1,
											target_id = data.target_id,
											quote = data.msg_id,
											content = '❌ 数据库更新失败'
										})
									end
								end
							)
						end
					else
						local charInfo = json.decode(result[1].charinfo)
						local playerName = charInfo.firstname .. ' ' .. charInfo.lastname

						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('❌ 玩家 %s (社安号: %s) 余额不足\n💰 银行: $%s，现金: $%s，总计: $%s，需要: $%s',
								playerName, identifier, currentBank, currentCash, totalMoney, amount)
						})
					end
				else
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = '❌ 找不到指定社安号的玩家'
					})
				end
			end)
		end
	else
		-- 无效输入格式
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '❌ 无效的输入格式\n请输入：\n• 在线玩家ID (纯数字)\n• 社安号 (8位大写字母数字组合)'
		})
	end
end)

KOOK_AddCommand('捏脸', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 直接触发服装菜单事件到客户端
		TriggerClientEvent('qb-clothing:client:openMenu', player)
		
		-- 发送成功消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已为玩家 %s 打开捏脸菜单', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('全体复活', {
	params = { }  -- 不需要参数
}, function(_, _, data)
	-- 获取所有在线玩家
	local players = GetPlayers()
	local successCount = 0
	local errorCount = 0
	
	-- 遍历所有在线玩家并复活
	for i = 1, #players do
		local player = tonumber(players[i])
		local success, err = pcall(function()
			-- 触发新医护系统的复活事件
			local reviveData = {}
			reviveData.revive = true
			TriggerClientEvent('ars_ambulancejob:healPlayer', player, reviveData)
		end)
		
		if success then
			successCount = successCount + 1
		else
			errorCount = errorCount + 1
		end
	end
	
	-- 发送结果消息
	local message = string.format('全体复活完成\n成功复活: %d 人', successCount)
	if errorCount > 0 then
		message = message .. string.format('\n失败: %d 人', errorCount)
	end
	
	KOOK_PerformApiRequest('/message/create', {
		type = 1,
		target_id = data.target_id,
		quote = data.msg_id,
		content = message
	})
end)

KOOK_AddCommand('给物品', {
	params = {
		{ name = 'playerId', type = 'playerId' },
		{ name = 'itemName', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local player = args.playerId
	local itemName = args.itemName
	local amount = args.amount
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 检查物品是否存在
		local item = QBCore.Shared.Items[itemName]
		if item then
			-- 给予物品
			targetPlayer.Functions.AddItem(itemName, amount)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已给予玩家 %s %d个 %s', GetPlayerName(player), amount, item.label)
			})
		else
			-- 发送物品不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '物品代码不存在'
			})
		end
	else
		-- 发送找不到玩家消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('删档', {
	params = {
		{ name = 'citizenid', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players where citizenid = ?', { citizenid }, function(result)
		if result[1] then
			-- 使用QBCore的官方函数强制删除角色
			QBCore.Player.ForceDeleteCharacter(citizenid)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已删除社安号为 %s 的角色档案', citizenid)
			})
		else
			-- 发送角色不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('设置工作', {
	params = {
		{ name = 'playerId', type = 'playerId' },
		{ name = 'jobName', type = 'string' },
		{ name = 'grade', type = 'number' }
	}
}, function(args, _, data)
	local player = args.playerId
	local jobName = args.jobName
	local grade = args.grade
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 检查工作是否存在
		if QBCore.Shared.Jobs[jobName] then
			-- 检查职业等级是否存在 (修改这里的检查逻辑)
			if QBCore.Shared.Jobs[jobName].grades[tostring(grade)] then
				-- 设置工作
				targetPlayer.Functions.SetJob(jobName, grade)
				
				-- 发送成功消息
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('已将玩家 %s 的工作设置为 %s (等级 %s)', 
						GetPlayerName(player), 
						QBCore.Shared.Jobs[jobName].label, 
						grade
					)
				})
			else
				-- 发送等级不存在消息
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('该职业等级不存在 (职业: %s, 等级: %s)', jobName, grade)
				})
			end
		else
			-- 发送工作不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
					quote = data.msg_id,
					content = '该职业代码不存在'
			})
		end
	else
		-- 发送找不到玩家消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)


KOOK_AddCommand('虚空帮助', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId

	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()

	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)

	if targetPlayer then
		-- 获取玩家当前坐标
		local ped = GetPlayerPed(player)
		local currentCoords = GetEntityCoords(ped)

		-- 设置玩家到虚空位置（保持X、Y不变，Z设为-210）
		SetEntityCoords(ped, currentCoords.x, currentCoords.y, -210.0)

		-- 等待1秒后复活玩家
		Wait(1000)

		local success, err = pcall(function()
			exports['wasabi_ambulance']:RevivePlayer(player)
		end)

		if not success then
			-- 如果复活失败，发送错误消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('虚空帮助玩家时复活失败: %s', err or '未知错误')
			})
			return
		end

		-- 发送QBCore通知给玩家
		TriggerClientEvent('QBCore:Notify', player, '管理员虚空帮助，已将您复活，祝游戏愉快', 'success')

		-- 发送成功消息到KOOK
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已帮助玩家 %s 脱离虚空并复活', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('加铭牌', {
	params = {
		{ name = 'playerId', type = 'playerId' },
		{ name = 'tag', type = 'string' }
	}
}, function(args, _, data)
	local player = args.playerId
	local tag = args.tag
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发添加铭牌事件
		TriggerEvent('addPlayerTag', player, tag)
		
		-- 发送成功消息到KOOK
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已为玩家 %s 添加铭牌: %s', GetPlayerName(player), tag)
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('清铭牌', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发清空铭牌事件
		TriggerEvent('clearPlayerTags', player)
		
		-- 发送成功消息到KOOK
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已清空玩家 %s 的所有铭牌', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

--查玩家
KOOK_AddCommand('查玩家', {
	params = {
		{ name = 'identifier', type = 'string' }
	}
}, function(args, _, data)
	local identifier = args.identifier
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 判断查询类型
	local isLicense = string.find(identifier, "license:")
	local isCitizenId = string.len(identifier) == 8 -- 社安号通常是8位
	
	-- 根据不同类型进行不同查询
	if isLicense then
		-- 通过license查询所有角色
		local query = 'SELECT * FROM players WHERE license = ?'
		local params = { identifier }
		
		exports.oxmysql:query(query, params, function(results)
			if results and #results > 0 then
				-- 有多个角色的情况
				local message = string.format("该R星识别码下有%d个角色：\n\n", #results)
				
				-- 遍历每个角色显示详细信息
				for i, result in ipairs(results) do
					-- 安全解码JSON数据
					local charInfo = result.charinfo and json.decode(result.charinfo) or {}
					local jobInfo = result.job and json.decode(result.job) or {}
					local gangInfo = result.gang and json.decode(result.gang) or {}
					local moneyInfo = result.money and json.decode(result.money) or {}
					
					-- 格式化最后上线时间
					local lastUpdated = "未知"
					if result.last_updated then
						local timestamp = tonumber(result.last_updated)
						if timestamp then
							if timestamp > 10000000000 then timestamp = timestamp / 1000 end
							lastUpdated = os.date("%Y-%m-%d %H:%M:%S", timestamp)
						else
							lastUpdated = tostring(result.last_updated)
						end
					end
					
					local fullName = (charInfo.firstname and charInfo.lastname) 
						and (charInfo.firstname .. " " .. charInfo.lastname) or "未知"
					
					-- 安全获取工作和帮派信息
					local jobLabel = jobInfo.label or "无"
					local jobGradeName = (jobInfo.grade and jobInfo.grade.name) or "无"
					local gangLabel = gangInfo.label or "无"
					local gangGradeName = (gangInfo.grade and gangInfo.grade.name) or "无"
					local cashAmount = moneyInfo.cash or 0
					local bankAmount = moneyInfo.bank or 0
					
					-- 添加每个角色的详细信息
					message = message .. string.format([[
第%d个角色信息：
游戏名字：%s
社安号：%s
工作：%s (等级 %s)
帮派：%s (等级 %s)
账户余额：现金 $%s | 银行 $%s
最后上线时间：%s
-------------------
]], 
						i,
						fullName,
						result.citizenid or "未知",
						jobLabel,
						jobGradeName,
						gangLabel,
						gangGradeName,
						cashAmount,
						bankAmount,
						lastUpdated
					)
				end
				
				-- 发送查询结果
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = message
				})
			else
				-- 发送未找到玩家消息
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '未找到该R星识别码关联的角色'
				})
			end
		end)
	elseif isCitizenId then
		-- 通过社安号精确查询
		local query = 'SELECT * FROM players WHERE citizenid = ?'
		local params = { identifier }
		
		exports.oxmysql:query(query, params, function(result)
			if result and result[1] then
				-- 安全解码JSON数据
				local charInfo = result[1].charinfo and json.decode(result[1].charinfo) or {}
				local jobInfo = result[1].job and json.decode(result[1].job) or {}
				local gangInfo = result[1].gang and json.decode(result[1].gang) or {}
				local moneyInfo = result[1].money and json.decode(result[1].money) or {}
				
				-- 格式化最后上线时间
				local lastUpdated = "未知"
				if result[1].last_updated then
					local timestamp = tonumber(result[1].last_updated)
					if timestamp then
						if timestamp > 10000000000 then timestamp = timestamp / 1000 end
						lastUpdated = os.date("%Y-%m-%d %H:%M:%S", timestamp)
					else
						lastUpdated = tostring(result[1].last_updated)
					end
				end
				
				local fullName = (charInfo.firstname and charInfo.lastname) 
					and (charInfo.firstname .. " " .. charInfo.lastname) or "未知"
				
				-- 安全获取工作和帮派信息
				local jobLabel = jobInfo.label or "无"
				local jobGradeName = (jobInfo.grade and jobInfo.grade.name) or "无"
				local gangLabel = gangInfo.label or "无"
				local gangGradeName = (gangInfo.grade and gangInfo.grade.name) or "无"
				local cashAmount = moneyInfo.cash or 0
				local bankAmount = moneyInfo.bank or 0
				
				-- 构建回复消息
				local message = string.format([[
玩家信息查询结果：
游戏名字：%s
社安号：%s
R星识别码：%s
工作：%s (等级 %s)
帮派：%s (等级 %s)
账户余额：现金 $%s | 银行 $%s
最后上线时间：%s]], 
					fullName,
					result[1].citizenid or "未知",
					result[1].license or "未知",
					jobLabel,
					jobGradeName,
					gangLabel,
					gangGradeName,
					cashAmount,
					bankAmount,
					lastUpdated
				)
				
				-- 发送查询结果
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = message
				})
			else
				-- 发送未找到玩家消息
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '未找到相关玩家信息'
				})
			end
		end)
	else
		-- 模糊查询，通过名字关键词
		local query = [[
			SELECT 
				citizenid, 
				charinfo,
				license
			FROM 
				players 
			WHERE 
				JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) LIKE ? 
				OR JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) LIKE ?
		]]
		local searchPattern = '%' .. identifier .. '%'
		
		exports.oxmysql:query(query, {searchPattern, searchPattern}, function(results)
			if results and #results > 0 then
				local message = string.format("找到%d位名字含「%s」的玩家：\n", #results, identifier)
				
				-- 遍历所有匹配的玩家，构建列表
				for i, result in ipairs(results) do
					local charInfo = result.charinfo and json.decode(result.charinfo) or {}
					local fullName = (charInfo.firstname and charInfo.lastname) 
						and (charInfo.firstname .. " " .. charInfo.lastname) or "未知"
					message = message .. string.format("%d. %s - 社安号: %s\n", i, fullName, result.citizenid or "未知")
				end
				
				message = message .. "\n请使用「查玩家 社安号」命令查询详细信息"
				
				-- 发送结果列表
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = message
				})
			else
				-- 没有找到匹配的玩家
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format("没有找到名字含「%s」的玩家", identifier)
				})
			end
		end)
	end
end)

KOOK_AddCommand('回库', { -- Add command '回库' (Return to garage_id)
	params = {
		{ name = 'plate', type = 'string' } -- Parameter: vehicle plate number
	},
}, function(args, _, data)
	-- 处理车牌号：去除空格，但保持原始格式（数字或字母）
	local plate = string.gsub(args.plate, "%s+", "") -- Remove spaces only
	                                 -- 只移除空格，保持原始格式
	
	-- Get QBCore instance
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- Query vehicle from database with case-insensitive search for mixed plates
	-- 查询车辆，对混合车牌使用不区分大小写的搜索
	exports.oxmysql:query('SELECT * FROM player_vehicles WHERE UPPER(plate) = UPPER(?)', {plate}, function(result)
		if result[1] then
			-- Trigger return to garage event
			-- 触发回库事件
			TriggerClientEvent('qb-radialmenu:huiku', -1, plate)
			
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已触发回库事件，车牌为 %s 的车辆正在转移至车库', plate)
			})
		else
			-- Send vehicle not found message
			-- 发送车辆不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该车牌号的车辆'
			})
		end
	end)
end)

KOOK_AddCommand('加成就', {
	params = {
		{ name = 'playerId', type = 'playerId' },
		{ name = 'exp', type = 'string' }
	}
}, function(args, _, data)
	local player = args.playerId
	local exp = args.exp
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发添加成就事件
		TriggerEvent('addPlayerExp', player, exp)
		
		-- 发送成功消息到KOOK
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已为玩家 %s 添加成就: %s', GetPlayerName(player), exp)
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('清成就', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发清空成就事件
		TriggerEvent('clearPlayerExps', player)
		
		-- 发送成功消息到KOOK
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已清空玩家 %s 的所有成就', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('打开背包', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, _, data)
	local player = args.playerId
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 获取玩家对象
	local targetPlayer = QBCore.Functions.GetPlayer(player)
	
	if targetPlayer then
		-- 触发打开背包事件
		TriggerClientEvent('inventory:client:OpenInventory', player)
		
		-- 发送成功消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('已为玩家 %s 打开背包', GetPlayerName(player))
		})
	else
		-- 发送失败消息
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '找不到指定玩家'
		})
	end
end)

KOOK_AddCommand('查后备箱', {
	params = {
		{ name = 'plate', type = 'string' }
	}
}, function(args, _, data)
	local plate = args.plate:upper() -- 转换为大写以匹配车牌格式
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 查询inventory_trunk表
	exports.oxmysql:query('SELECT items FROM inventory_trunk WHERE plate = ?', {plate}, function(result)
		if result[1] and result[1].items then
			-- 解析物品数据
			local success, trunkItems = pcall(json.decode, result[1].items)
			if success and trunkItems then
				local itemsList = {}
				
				-- 遍历后备箱物品
				for _, itemData in pairs(trunkItems) do
					-- 获取物品标签（中文名称）
					local itemLabel = QBCore.Shared.Items[itemData.name] and QBCore.Shared.Items[itemData.name].label or itemData.name
					-- 添加到列表
					table.insert(itemsList, string.format('%s   %s   X%d', 
						itemData.name,   -- 物品代码
						itemLabel,       -- 物品名称
						itemData.amount  -- 数量
					))
				end
				
				if #itemsList > 0 then
					-- 构建消息
					local message = string.format([[车辆后备箱内容 (车牌: %s):
%s]], 
						plate,
						table.concat(itemsList, '\n')
					)
					
					-- 发送查询结果
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = message
					})
				else
					-- 后备箱为空
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('车牌为 %s 的车辆后备箱是空的', plate)
					})
				end
			else
				-- JSON解析失败
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('车牌为 %s 的车辆后备箱数据格式错误', plate)
				})
			end
		else
			-- 发送后备箱为空消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('车牌为 %s 的车辆后备箱是空的', plate)
			})
		end
	end)
end)

KOOK_AddCommand('名下车辆', {
	params = {
		{ name = 'citizenid', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 查询玩家名下的车辆
	exports.oxmysql:query('SELECT vehicle, plate FROM player_vehicles WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			local vehicleList = {}
			
			-- 遍历所有车辆
			for _, vehicle in pairs(result) do
				-- 获取车辆名称
				local vehicleHash = vehicle.vehicle
				local vehicleLabel = QBCore.Shared.Vehicles[vehicleHash] and QBCore.Shared.Vehicles[vehicleHash].name or vehicleHash
				
				-- 添加到列表
				table.insert(vehicleList, string.format('[%s][%s][%s]', 
					vehicleHash,    -- 车辆代码
					vehicleLabel,   -- 车辆名称
					vehicle.plate   -- 车牌号
				))
			end
			
			-- 构建消息
			local message = string.format([[该名玩家一共有%d辆车
%s]], 
				#result,
				table.concat(vehicleList, '\n')
			)
			
			-- 发送查询结果
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = message
			})
		else
			-- 发送无车辆消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '该玩家名下没有车辆'
			})
		end
	end)
end)

KOOK_AddCommand('查询库存', {
	params = {
		{ name = 'stashId', type = 'string' }
	}
}, function(args, _, data)
	local stashId = args.stashId
	
	-- 修改SQL查询使用LOWER函数实现不区分大小写
	exports.oxmysql:query('SELECT items FROM inventory_stash WHERE LOWER(stash) = LOWER(?)', {stashId}, function(result)
		if result and result[1] and result[1].items then
			-- 尝试解析物品JSON
			local success, stashItems = pcall(json.decode, result[1].items)
			
			if success and stashItems then
				-- 获取QBCore实例以获取物品标签
				local QBCore = exports['qb-core']:GetCoreObject()
				local content = ""
				local itemCount = 0
				
				-- 检查stashItems是否为数组或对象
				if type(stashItems) == 'table' then
					for slot, itemData in pairs(stashItems) do
						if itemData and itemData.name then
							itemCount = itemCount + 1
							
							-- 获取物品标签
							local itemLabel = itemData.label or 
							                 (QBCore.Shared.Items[itemData.name] and 
							                 QBCore.Shared.Items[itemData.name].label) or 
							                 itemData.name
							
							-- 为每个物品添加格式化信息
							content = content .. "插槽: " .. slot .. 
							          "\n物品: " .. itemData.name .. 
							          "\n(" .. itemLabel .. ") " .. 
							          "\n数量: " .. (itemData.amount or 1) .. "\n\n"
						end
					end
				end
				
				if itemCount > 0 then
					-- 发送查询结果
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('仓库 %s 内容:\n%s', stashId, content)
					})
				else
					-- 仓库为空或格式不正确
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('仓库 %s 是空的或数据格式异常', stashId)
					})
				end
			else
				-- JSON解析失败
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('仓库 %s 数据解析失败', stashId)
				})
			end
		else
			-- 仓库不存在
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('仓库 %s 不存在或无法访问', stashId)
			})
		end
	end)
end)

KOOK_AddCommand('清理物品', {
	params = {
		{ name = 'itemName', type = 'string' },
		{ name = 'stashId', type = 'string' }
	}
}, function(args, _, data)
	local itemName = args.itemName
	local stashId = args.stashId
	
	-- 修改SQL查询使用LOWER函数实现不区分大小写
	exports.oxmysql:query('SELECT items FROM inventory_stash WHERE LOWER(stash) = LOWER(?)', {stashId}, function(result)
		if result and result[1] and result[1].items then
			-- 解析JSON数据
			local success, stashItems = pcall(json.decode, result[1].items)
			
			if success and stashItems then
				local removed = false
				local totalRemoved = 0
				
				-- 遍历并移除指定物品
				for slot, itemData in pairs(stashItems) do
					if itemData and itemData.name == itemName then
						totalRemoved = totalRemoved + (itemData.amount or 1)
						stashItems[slot] = nil -- 移除该物品
						removed = true
					end
				end
				
				if removed then
					-- 将更新后的物品列表保存回数据库，同样使用不区分大小写的查询
					exports.oxmysql:execute('UPDATE inventory_stash SET items = ? WHERE LOWER(stash) = LOWER(?)', 
						{json.encode(stashItems), stashId}, 
						function()
							-- 发送成功消息
							KOOK_PerformApiRequest('/message/create', {
								type = 1,
								target_id = data.target_id,
								quote = data.msg_id,
								content = string.format('已从仓库 %s 移除 %d 个 %s', stashId, totalRemoved, itemName)
							})
						end
					)
				else
					-- 未找到物品
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('仓库 %s 中没有找到物品 %s', stashId, itemName)
					})
				end
			else
				-- JSON解析失败
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('仓库 %s 数据解析失败', stashId)
				})
			end
		else
			-- 仓库不存在
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('仓库 %s 不存在或无法访问', stashId)
			})
		end
	end)
end)

KOOK_AddCommand('清理仓库', {
	params = {
		{ name = 'stashId', type = 'string' }
	}
}, function(args, _, data)
	local stashId = args.stashId
	
	-- 修改SQL查询使用LOWER函数实现不区分大小写
	exports.oxmysql:query('SELECT items FROM inventory_stash WHERE LOWER(stash) = LOWER(?)', {stashId}, function(result)
		if result and result[1] then
			-- 直接清空仓库物品，同样使用不区分大小写的更新
			exports.oxmysql:execute('UPDATE inventory_stash SET items = ? WHERE LOWER(stash) = LOWER(?)', 
				{json.encode({}), stashId}, 
				function()
					-- 发送成功消息
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format('已清空仓库 %s 中的所有物品', stashId)
					})
				end
			)
		else
			-- 仓库不存在
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('仓库 %s 不存在或无法访问', stashId)
			})
		end
	end)
end)

KOOK_AddCommand('转移数据', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'newLicense', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local newLicense = args.newLicense
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 先发送操作开始消息
	KOOK_PerformApiRequest('/message/create', {
		type = 1,
		target_id = data.target_id,
		quote = data.msg_id,
		content = string.format('正在处理数据转移请求...\n社安号: %s\n新识别码: %s', citizenid, newLicense)
	})
	
	-- 先检查旧社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			local oldLicense = result[1].license
			
			-- 检查是否有在线玩家使用这个社安号
			local player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
			if player then
				DropPlayer(player.PlayerData.source, '角色数据转移中，请稍后重新连接')
				Wait(500)
			end
			
			-- 更新数据库中的识别码
			exports.oxmysql:execute('UPDATE players SET license = ? WHERE citizenid = ?', 
				{newLicense, citizenid}, 
				function(rowsAffected)
					-- 无论影响行数如何，都发送操作完成消息
					KOOK_PerformApiRequest('/message/create', {
						type = 1,
						target_id = data.target_id,
						quote = data.msg_id,
						content = string.format([[数据转移完成:
社安号: %s
原识别码: %s
新识别码: %s
影响行数: %s]], 
							citizenid, 
							oldLicense,
							newLicense,
							tostring(rowsAffected or 0)
						)
					})
				end
			)
		else
			-- 发送未找到角色消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号关联的角色'
			})
		end
	end)
end)

KOOK_AddCommand('通行证等级', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local amount = args.amount
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 增加玩家等级
			exports['0bug_Battlepass']:addLevel(citizenid, amount)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已为玩家 (社安号: %s) 增加 %d 级通行证等级', citizenid, amount)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('减通行证等级', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local amount = args.amount
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 减少玩家等级
			exports['0bug_Battlepass']:removeLevel(citizenid, amount)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已为玩家 (社安号: %s) 减少 %d 级通行证等级', citizenid, amount)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('给通行证经验', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local amount = args.amount
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 增加玩家经验值
			exports['0bug_Battlepass']:addXP(citizenid, amount)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已为玩家 (社安号: %s) 增加 %d 点通行证经验值', citizenid, amount)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('设置高级通行证', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'value', type = 'string' } -- 使用 "true" 或 "false" 字符串
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local valueStr = args.value:lower()
	
	-- 将字符串转换为布尔值
	local premium = (valueStr == "true" or valueStr == "1" or valueStr == "是")
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 设置高级通行证状态
			exports['0bug_Battlepass']:setPremium(citizenid, premium)
			
			-- 发送成功消息
			local statusText = premium and "开启" or "关闭"
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已为玩家 (社安号: %s) %s高级通行证', citizenid, statusText)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('给通行证点数', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local amount = args.amount
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 增加通行证点数
			exports['0bug_Battlepass']:addCredit(citizenid, amount)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已为玩家 (社安号: %s) 增加 %d 点通行证点数', citizenid, amount)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('减通行证点数', {
	params = {
		{ name = 'citizenid', type = 'string' },
		{ name = 'amount', type = 'number' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	local amount = args.amount
	
	if amount <= 0 then
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '通行证点数必须为正整数'
		})
		return
	end

	local QBCore = exports['qb-core']:GetCoreObject()
	
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			local currentCredit = exports['0bug_Battlepass']:getCredit(citizenid)
			
			if currentCredit >= amount then
				exports['0bug_Battlepass']:removeCredit(citizenid, amount)
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('已为玩家 (社安号: %s) 减少 %d 点通行证点数', citizenid, amount)
				})
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = string.format('玩家 (社安号: %s) 当前通行证点数不足，仅有 %d 点', citizenid, currentCredit)
				})
			end
		else
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('查通行证点数', {
	params = {
		{ name = 'citizenid', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 查询通行证点数
			local credit = exports['0bug_Battlepass']:getCredit(citizenid)
			
			-- 发送查询结果
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('玩家 (社安号: %s) 当前通行证点数: %d', citizenid, credit)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('清除通行证数据', {
	params = {
		{ name = 'citizenid', type = 'string' }
	}
}, function(args, _, data)
	local citizenid = args.citizenid
	
	-- 获取QBCore实例
	local QBCore = exports['qb-core']:GetCoreObject()
	
	-- 检查社安号是否存在
	exports.oxmysql:query('SELECT license FROM players WHERE citizenid = ?', {citizenid}, function(result)
		if result and #result > 0 then
			-- 清除玩家通行证数据
			exports['0bug_Battlepass']:clearPlayerData(citizenid)
			
			-- 发送成功消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = string.format('已清除玩家 (社安号: %s) 的所有通行证数据', citizenid)
			})
		else
			-- 发送社安号不存在消息
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '未找到该社安号的角色'
			})
		end
	end)
end)

KOOK_AddCommand('清除所有通行证数据', {
	params = { }
}, function(_, _, data)
	-- 清除所有玩家通行证数据
	exports['0bug_Battlepass']:clearPlayersData()
	
	-- 发送成功消息
	KOOK_PerformApiRequest('/message/create', {
		type = 1,
		target_id = data.target_id,
		quote = data.msg_id,
		content = '已清除所有玩家的通行证数据'
	})
end)

KOOK_AddCommand('安全重置通行证', {
	params = { }
}, function(_, _, data)
	-- 先发送操作开始消息
	KOOK_PerformApiRequest('/message/create', {
		type = 1,
		target_id = data.target_id,
		quote = data.msg_id,
		content = '正在安全重置通行证系统，这可能需要几秒钟...'
	})
	
	-- 使用pcall捕获可能的错误
	local success, errorMsg = pcall(function()
		-- 按照安全顺序重置：先处理玩家数据，再处理系统数据
		exports['0bug_Battlepass']:clearPlayersData()
		Wait(1000) -- 等待1秒确保数据清除完成
		exports['0bug_Battlepass']:clearScriptData()
		Wait(500) -- 再等待0.5秒
		
		-- 触发系统初始化事件(如果有的话)
		TriggerEvent('0bug_Battlepass:server:initializeSystem')
	end)
	
	-- 根据执行结果发送不同消息
	if success then
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = '通行证系统已安全重置，所有数据结构已重新初始化'
		})
	else
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('通行证系统重置过程中出现错误: %s\n建议联系开发者检查数据库和脚本', errorMsg or "未知错误")
		})
	end
end)

-- 监狱系统命令
KOOK_AddCommand('关押', {
	params = {
		{ name = 'identifier', type = 'identifier' },
		{ name = 'jailTime', type = 'number' },
		{ name = 'reason', type = 'longString', optional = true }
	}
}, function(args, rawData, data)
	local identifier = args.identifier
	local jailTime = args.jailTime
	local reason = args.reason or '无理由'
	
	-- 自动检测输入类型（ID或识别码）
	local numericId = tonumber(identifier)
	local isPlayerId = numericId and DoesPlayerExist(numericId)
	local isLicense = string.find(identifier, "license:")
	
	-- 调试日志
	print('[DEBUG] 关押命令 - identifier:', identifier)
	print('[DEBUG] 关押命令 - numericId:', numericId)
	print('[DEBUG] 关押命令 - isPlayerId:', isPlayerId)
	print('[DEBUG] 关押命令 - isLicense:', isLicense)
	print('[DEBUG] 关押命令 - jailTime:', jailTime)
	print('[DEBUG] 关押命令 - data.target_id:', data and data.target_id or 'nil')
	print('[DEBUG] 关押命令 - data.msg_id:', data and data.msg_id or 'nil')
	
	if isPlayerId then
		-- 在线玩家，使用原有监狱系统
		local playerId = numericId
		
		TriggerEvent('yx_prison:kook_jail_player', playerId, jailTime, reason, 0)
		
		-- 直接发送成功回复，因为功能正常工作
		print('[DEBUG] 在线关押 - 触发事件完成，发送成功回复')
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('✅ 已执行关押在线玩家 %d 的命令\n⏰ 关押时间: %d分钟\n📝 理由: %s\n💡 请检查游戏内是否生效', 
				playerId, jailTime, reason)
		}, 'POST', function(code, text, headers)
			print('[DEBUG] 在线关押KOOK API响应 - code:', code, 'text:', text)
		end)
	elseif isLicense then
		-- 离线玩家，数据库操作
		print('[DEBUG] 进入离线关押分支，jailTime:', jailTime)
		-- 先检查玩家是否存在
		exports.oxmysql:query('SELECT license, charinfo FROM players WHERE license = ?', {identifier}, function(result)
			print('[DEBUG] 数据库查询结果:', result and #result or 'nil')
			if result and result[1] then
				local charInfo = json.decode(result[1].charinfo)
				local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
				
				-- 使用 INSERT ... ON DUPLICATE KEY UPDATE 来处理重复记录
				local currentTime = os.date('%Y-%m-%d %H:%M:%S')
				local jailTimeInSeconds = jailTime * 60  -- 将分钟转换为秒
				print('[DEBUG] 准备执行数据库操作，jailTime(分钟):', jailTime, 'jailTime(秒):', jailTimeInSeconds)
				exports.oxmysql:execute(
					'INSERT INTO player_jail (license, jail_time, reason, isJailed, jail_start, last_update) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE jail_time = VALUES(jail_time), reason = VALUES(reason), isJailed = 1, jail_start = VALUES(jail_start), last_update = VALUES(last_update)',
					{identifier, jailTimeInSeconds, reason, 1, currentTime, currentTime},
					function(executeResult)
						print('[DEBUG] 数据库执行结果:', executeResult and executeResult.affectedRows or 'nil')
						if executeResult and (executeResult.affectedRows > 0 or executeResult.changedRows >= 0) then
							print('[DEBUG] 关押成功，显示时间:', jailTime)
							print('[DEBUG] 准备发送KOOK回复，target_id:', data.target_id, 'msg_id:', data.msg_id)
							KOOK_PerformApiRequest('/message/create', {
								type = 1,
								target_id = data.target_id,
								quote = data.msg_id,
								content = string.format('✅ 成功关押离线玩家 %s\n🔒 识别码: %s\n⏰ 关押时间: %d分钟\n📝 理由: %s\n💡 玩家上线时将自动进入监狱状态',
									playerName, identifier, jailTime, reason)
							}, 'POST', function(code, text, headers)
								print('[DEBUG] KOOK API响应 - code:', code, 'text:', text)
							end)
						else
							KOOK_PerformApiRequest('/message/create', {
								type = 1,
								target_id = data.target_id,
								quote = data.msg_id,
								content = '❌ 关押操作失败'
							})
						end
					end
				)
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定识别码的玩家'
				})
			end
		end)
	else
		-- 尝试按数字ID处理离线玩家
		local playerId = tonumber(identifier)
		if playerId then
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 玩家ID ' .. playerId .. ' 不在线，请使用识别码进行离线关押'
			})
		else
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 无效的输入格式\n请输入：\n• 在线玩家ID (数字)\n• 玩家识别码 (license:xxxxxxx)'
			})
		end
	end
end)

KOOK_AddCommand('释放', {
	params = {
		{ name = 'identifier', type = 'identifier' }
	}
}, function(args, rawData, data)
	local identifier = args.identifier
	
	-- 自动检测输入类型（ID或识别码）
	local numericId = tonumber(identifier)
	local isPlayerId = numericId and DoesPlayerExist(numericId)
	local isLicense = string.find(identifier, "license:")
	
	-- 调试日志
	print('[DEBUG] 释放命令 - identifier:', identifier)
	print('[DEBUG] 释放命令 - numericId:', numericId)
	print('[DEBUG] 释放命令 - isPlayerId:', isPlayerId)
	print('[DEBUG] 释放命令 - isLicense:', isLicense)
	
	if isPlayerId then
		-- 在线玩家，使用原有监狱系统
		local playerId = numericId
		
		TriggerEvent('yx_prison:kook_release_player', playerId, 0)
		
		-- 直接发送成功回复，因为功能正常工作
		print('[DEBUG] 在线释放 - 触发事件完成，发送成功回复')
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = string.format('✅ 已执行释放在线玩家 %d 的命令\n💡 请检查游戏内是否生效', playerId)
		}, 'POST', function(code, text, headers)
			print('[DEBUG] 在线释放KOOK API响应 - code:', code, 'text:', text)
		end)
	elseif isLicense then
		-- 离线玩家，数据库操作
		-- 先检查玩家是否存在
		exports.oxmysql:query('SELECT license, charinfo FROM players WHERE license = ?', {identifier}, function(result)
			if result and result[1] then
				local charInfo = json.decode(result[1].charinfo)
				local playerName = charInfo.firstname .. ' ' .. charInfo.lastname
				
				-- 检查是否被关押
				exports.oxmysql:query('SELECT * FROM player_jail WHERE license = ? AND isJailed = 1', {identifier}, function(jailResult)
					if jailResult and jailResult[1] then
						-- 释放玩家，更新数据库
						local currentTime = os.date('%Y-%m-%d %H:%M:%S')
						exports.oxmysql:execute('UPDATE player_jail SET isJailed = 0, last_update = ? WHERE license = ?',
							{currentTime, identifier},
							function(executeResult)
								if executeResult and executeResult.affectedRows and executeResult.affectedRows > 0 then
									print('[DEBUG] 释放成功，准备发送KOOK回复')
									KOOK_PerformApiRequest('/message/create', {
										type = 1,
										target_id = data.target_id,
										quote = data.msg_id,
										content = string.format('✅ 成功释放离线玩家 %s\n🔓 识别码: %s\n💡 玩家下次上线时将恢复自由状态',
											playerName, identifier)
									}, 'POST', function(code, text, headers)
										print('[DEBUG] 释放KOOK API响应 - code:', code, 'text:', text)
									end)
								else
									KOOK_PerformApiRequest('/message/create', {
										type = 1,
										target_id = data.target_id,
										quote = data.msg_id,
										content = '❌ 释放操作失败'
									})
								end
							end
						)
					else
						KOOK_PerformApiRequest('/message/create', {
							type = 1,
							target_id = data.target_id,
							quote = data.msg_id,
							content = string.format('✅ 玩家 %s (识别码: %s) 当前未被关押', playerName, identifier)
						})
					end
				end)
			else
				KOOK_PerformApiRequest('/message/create', {
					type = 1,
					target_id = data.target_id,
					quote = data.msg_id,
					content = '❌ 找不到指定识别码的玩家'
				})
			end
		end)
	else
		-- 尝试按数字ID处理离线玩家
		local playerId = tonumber(identifier)
		if playerId then
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 玩家ID ' .. playerId .. ' 不在线，请使用识别码进行离线释放'
			})
		else
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 无效的输入格式\n请输入：\n• 在线玩家ID (数字)\n• 玩家识别码 (license:xxxxxxx)'
			})
		end
	end
end)

KOOK_AddCommand('监狱列表', {
	params = {}
}, function(args, rawData, data)
	TriggerEvent('yx_prison:kook_get_jail_list', 0)
	
	local responseReceived = false
	local eventHandler
	
	eventHandler = AddEventHandler('yx_prison:kook_response', function(success, message, jailList)
		responseReceived = true
		RemoveEventHandler(eventHandler)
		
		local response
		
		if success and jailList then
			if #jailList == 0 then
				response = '📋 监狱当前为空'
			else
				response = '📋 监狱列表：\n'
				for i, prisoner in ipairs(jailList) do
					response = response .. ('🔒 玩家 %d - 剩余时间：%d分钟\n'):format(prisoner.playerId, prisoner.remainingTime)
				end
			end
		else
			response = ('❌ 获取监狱列表失败：%s'):format(message or '未知错误')
		end
		
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = response
		})
	end)
	
	Citizen.SetTimeout(5000, function()
		if not responseReceived then
			RemoveEventHandler(eventHandler)
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 获取监狱列表超时，请检查监狱系统是否正常运行'
			})
		end
	end)
end)

KOOK_AddCommand('查询状态', {
	params = {
		{ name = 'playerId', type = 'playerId' }
	}
}, function(args, rawData, data)
	local playerId = args.playerId
	
	TriggerEvent('yx_prison:kook_get_player_status', playerId, 0)
	
	local responseReceived = false
	local eventHandler
	
	eventHandler = AddEventHandler('yx_prison:kook_response', function(success, message, playerStatus)
		responseReceived = true
		RemoveEventHandler(eventHandler)
		
		local response
		
		if success and playerStatus then
			if playerStatus.isJailed then
				response = ('🔒 玩家 %d 当前被关押\n剩余时间：%d分钟\n关押理由：%s'):format(
					playerId, playerStatus.remainingTime, playerStatus.reason)
			else
				response = ('✅ 玩家 %d 当前自由'):format(playerId)
			end
		else
			response = ('❌ 查询玩家状态失败：%s'):format(message or '未知错误')
		end
		
		KOOK_PerformApiRequest('/message/create', {
			type = 1,
			target_id = data.target_id,
			quote = data.msg_id,
			content = response
		})
	end)
	
	Citizen.SetTimeout(5000, function()
		if not responseReceived then
			RemoveEventHandler(eventHandler)
			KOOK_PerformApiRequest('/message/create', {
				type = 1,
				target_id = data.target_id,
				quote = data.msg_id,
				content = '❌ 查询状态超时，请检查监狱系统是否正常运行'
			})
		end
	end)
end)
