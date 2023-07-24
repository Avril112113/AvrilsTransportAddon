--[[
	TODO:
		Test permissions
		Command short desc
		Global help command
		Help command only shows commands with permissions
		Command help, subcommands short desc
		Add argument type: list
]]

local BOOLEAN_STRS = {
	["true"]=true,
	["false"]=false,
	yes=true,
	ye=true,
	y=true,
	no=false,
	n=false,
}

CommandManager = {name="CommandManager"}
---@type table<string, Command>
CommandManager.commands = {}
CommandManager.argConverters = {
	string=true,
	---@type fun(args:string[]):(boolean,any)
	number=function(args)
		local value = tonumber(table.remove(args, 1))
		if value == nil then
			return false, "Invalid number."
		end
		return true, value
	end,
	---@type fun(args:string[]):(boolean,any)
	integer=function(args)
		local value = tonumber(table.remove(args, 1))
		if value == nil then
			return false, "Invalid number."
		elseif value % 1 ~= 0 then
			return false, "Decimals are not allowed."
		end
		return true, value
	end,
	---@type fun(args:string[]):(boolean,any)
	boolean=function(args)
		local value = BOOLEAN_STRS[table.remove(args, 1)]
		if value == nil then
			return false, "Invalid boolean, consider 'y' or 'n'."
		end
		return true, value
	end,
	---@type fun(args:string[]):(boolean,any)
	player=function(args)
		local value = table.remove(args, 1)
		local player = PlayerManager.getByName(value) or PlayerManager.getBySteamId(value) or PlayerManager.getByPeerId(tonumber(value))
		if player == nil then
			return false, "Invalid player."
		end
		return true, player
	end,
}


---@class CommandCtx
---@field player Player # The player who invoked the command
---@field command string # The command used to run the handler (excludes arguments to the handler)

---@class CommandHandlerArg
---@field type string
---@field name string
---@field optional boolean

---@alias CommandHandler fun(self:Command, ctx:CommandCtx, ...):(`0`|`-1`,string?)

---@class Command
---@field name string
---@field desc string?
---@field subcommands table<string, Command>
---@field parent Command?
---@field handler nil|CommandHandler
---@field handlerSignature nil|CommandHandlerArg[]
---@field handlerUsage nil|string
---@field permission "all"|"auth"|"admin"
Command = {}

---@param name string
---@return Command
function Command.new(name)
	return shallowCopy(Command, {
		name = name,
		subcommands = {},
	})
end

---@param desc string
function Command:setDesc(desc)
	self.desc = desc
	return self
end

---@param args nil|string[]
---@param f CommandHandler
function Command:setHandler(args, f)
	if args ~= nil then
		local handlerSignature = {}
		local handlerUsageParts = {}
		for i, argType in ipairs(args) do
			local name, typ, optional = argType:match("(%w+):(%w+)(%??)")
			---@type CommandHandlerArg
			local argSig
			if name == nil then
				log_error(("Command '%s' argument signature #%.0f: invalid format."):format(self.name, i))
				argSig = {
					name="UNKNOWN",
					type="string",
					optional=true,
				}
			else
				argSig = {
					name=name,
					type=typ,
					optional=#optional > 0,
				}
				if CommandManager.argConverters[argSig.type] == nil then
					log_error(("Command '%s' argument signature '%s'#%.0f: invalid type '%s'."):format(self.name, argSig.name, i, argSig.type))
				end
			end
			table.insert(handlerSignature, argSig)
			if argSig.optional then
				table.insert(handlerUsageParts, ("[%s:%s]"):format(argSig.name, argSig.type))
			else
				table.insert(handlerUsageParts, ("(%s:%s)"):format(argSig.name, argSig.type))
			end
		end
		self.handlerSignature = handlerSignature
		self.handlerUsage = table.concat(handlerUsageParts, " ")
	end
	self.handler = f
	return self
end

---@param ctx CommandCtx
---@param ... any
function Command:__helpHandler(ctx, ...)
	local args = {...}
	local lines = {}

	if #args > 0 then
		table.insert(lines, "Invalid arguments.\n")
	end

	table.insert(lines, ctx.command)
	table.insert(lines, self.desc)

	local subcommandLines = {}
	for subCmdName, subCmd in pairs(self.subcommands) do
		table.insert(subcommandLines, ("%s %s"):format(subCmdName, subCmd.handlerUsage or ""))
	end
	if #subcommandLines > 0 then
		table.insert(lines, "Subcommands:\n- " .. table.concat(subcommandLines, "\n- "))
	end

	return #args > 0 and -1 or 0, table.concat(lines, "\n")
end
function Command:setHelpHandler()
	self:setHandler(nil, self.__helpHandler)
	return self
end

---@param command Command
function Command:addSubcommand(command)
	self.subcommands[command.name] = command
	if command.parent ~= nil then
		log_warn(("subcommand '%s' is being used for commands '%s' and '%s', parent will not be overridden."):format(command.name, command.parent.name, self.name))
		return self
	end
	command.parent = self
	return self
end

---@param level "all"|"auth"|"admin"
function Command:setPermission(level)
	self.permission = level
	return self
end

---@param player Player
---@return boolean
function Command:checkPermission(player)
	return self.permission == nil or self.permission == "all" or (self.permission == "auth" and player.auth) or (self.permission == "admin" and player.admin)
end

--- Adds this command to the global commands list.
--- Don't call on subcommands
function Command:register()
	CommandManager.commands[self.name] = self
	return self
end


---@return Command
function CommandManager.getCommand(name)
	return CommandManager.commands[name]
end

EventManager.addEventHandler("onCustomCommand", 10,
	function(full_message, player, command, ...)
		local cmd = CommandManager.commands[command:sub(2)]
		if cmd == nil then
			return
		end

		local commandPathTbl = {command}
		local args = {...}
		while true do
			local subCmd = cmd.subcommands[args[1]]
			if subCmd ~= nil then
				table.insert(commandPathTbl, table.remove(args, 1))
				cmd = subCmd
				if subCmd:checkPermission(player) ~= true then
					break
				end
			else
				break
			end
		end
		local commandPath = table.concat(commandPathTbl, " ")

		if cmd:checkPermission(player) ~= true then
			log_cmdResponse(commandPath, player.peer_id, ("Insufficient permission to run this command, you need %s."):format(cmd.permission))
			return
		end

		if cmd.handler == nil then
			local subCmds = {}
			for name, _ in pairs(cmd.subcommands) do
				table.insert(subCmds, name)
			end
			if #subCmds <= 0 then
				table.insert(subCmds, "ERR_EMPTY_COMMAND")
			end
			log_cmdResponse(commandPath, player.peer_id, "Command can not be invoked directly.\nUse one of the subcommands: ", table.concat(subCmds, ", "))
			return
		end
		if #args == 1 and args[1] == "help" then
			local status, msg = Command.__helpHandler(cmd, {player=player, command=commandPath})
			log_cmdResponse(commandPath, player.peer_id, msg)
			return
		end
		if cmd.handlerSignature ~= nil then
			local rawArgs = args
			args = {}
			for i, argSig in ipairs(cmd.handlerSignature) do
				if #rawArgs <= 0 then
					if argSig.optional then
						goto continue
					else
						log_cmdResponse(commandPath, player.peer_id, ("Missing argument '%s'\n%s"):format(argSig.name, ("%s %s"):format(commandPath, cmd.handlerUsage)))
						return
					end
				end
				local converter = CommandManager.argConverters[argSig.type]
				if converter ~= nil and converter ~= true then
					local ok, valueOrMsg = converter(rawArgs)
					if ok then
						table.insert(args, valueOrMsg)
					else
						log_cmdResponse(commandPath, player.peer_id, ("Argument #%.0f: %s"):format(i, valueOrMsg))
						return
					end
				else
					table.insert(args, table.remove(rawArgs, 1))
				end
				::continue::
			end
		end
		local status, msg = cmd:handler({player=player, command=commandPath}, table.unpack(args))
		if msg ~= nil then
			log_cmdResponse(commandPath, player.peer_id, msg)
		else
			log_cmdResponse(commandPath, player.peer_id, ("Command status: %s"):format(status))
		end
	end
)
