---@overload fun(ctx:CommandCtx): nil, nil, string
---@param ctx CommandCtx
---@return string, CompanyData, nil
local function getCompanyData(ctx)
	local companyName = CompanySystem.getPlayerCompanyName(ctx.player)
	if companyName == nil then
		return nil, nil, "You are not in a company, consider joining one `?company join`"
	end
	local companyData = CompanySystem.getCompany(companyName)
	if companyData == nil then
		CompanySystem.leaveCompany(ctx.player)
		return nil, nil, ("The company you were in no longer exists."):format(companyName)
	end
	return companyName, companyData
end


Command.new("company")
	:setDesc("The main company management command.")
	:setPermission("auth")
	:register()
	:setHandler({"name:string?"}, function(self, ctx, companyName)
		local lines = {}
		companyName = companyName or CompanySystem.getPlayerCompanyName(ctx.player)
		local companyData = companyName and CompanySystem.getCompany(companyName)
		if companyName ~= nil and companyData ~= nil then
			local membersNames = {}
			for steamId, _ in pairs(companyData.members) do
				local player = PlayerManager.getBySteamId(steamId)
				-- TODO: Offline player name
				table.insert(membersNames, player and player.name or steamId)
			end
			local licenceNames = {}
			for licence, _ in pairs(companyData.licences) do
				table.insert(licenceNames, licence)
			end
			table.insert(lines, ("Company: %s\nMoney: $%.2f\nMembers: %s\nLicences: %s"):format(companyName, companyData.money, table.concat(membersNames, ", "), table.concat(licenceNames, ", ")))
		else
			table.insert(lines, "Not in a company.\nConsider `?company create` or `?company join (name)`")
		end
		return 0, table.concat(lines, "\n")
	end)
	:addSubcommand(
		Command.new("list")
			:setDesc("Lists all existing companies.")
			:setHandler({}, function(self, ctx)
				local lines = {"Companies:"}
				-- TODO: Order companies by member count or money.
				for name, data in pairs(CompanySystem.getCompanies()) do
					-- TODO: More info like member count or money.
					table.insert(lines, ("- %s #%.0f $%.2f"):format(name, data.membersCount, data.money))
				end
				return 0, table.concat(lines, "\n")
			end)
	)
	:addSubcommand(
		Command.new("create")
			:setDesc("Create a new company.")
			:setHandler({"name:string"}, function(self, ctx, name)
				if CompanySystem.getPlayerCompanyName(ctx.player) ~= nil then
					return -1, "You are already in a company, consider leaving before creating one."
				end
				local companyData, errMsg = CompanySystem.createCompany(name)
				if companyData == nil then
					return -2, errMsg
				end
				local joined, errMsg = CompanySystem.joinCompany(ctx.player, name)
				if not joined then
					return -3, errMsg
				end
				return 0, "Company created.\nUse `?company` for details."
			end)
	)
	:addSubcommand(
		Command.new("disband")
			:setDesc("Removes the company from existence that you are currently in.")
			:setHandler({}, function(self, ctx)
				local companyName = CompanySystem.getPlayerCompanyName(ctx.player)
				if companyName == nil then
					return -1, "You are not in a company."
				end
				local ok, errMsg = CompanySystem.removeCompany(companyName)
				if not ok then
					return -2, errMsg
				end
				return 0, "Company disbanded."
			end)
	)
	:addSubcommand(
		Command.new("join")
			:setDesc("Join an existing company.")
			:setHandler({"name:string"}, function(self, ctx, name)
				local companyName = CompanySystem.getPlayerCompanyName(ctx.player)
				if companyName ~= nil then
					return -1, "You are already in a company, consider `?company leave`"
				end
				local companyData = CompanySystem.getCompany(name)
				if companyData == nil then
					return -2, ("A company named '%s' doesn't exist."):format(name)
				end
				local ok, errMsg = CompanySystem.joinCompany(ctx.player, name)
				if not ok then
					return -3, errMsg
				end
				return 0, ("You joined the company '%s'."):format(name)
			end)
	)
	:addSubcommand(
		Command.new("leave")
			:setDesc("Leave your company.")
			:setHandler({}, function(self, ctx, ...)
				local companyName = CompanySystem.getPlayerCompanyName(ctx.player)
				if companyName == nil then
					return -1, "You are not in a company, consider joining one `?company join`"
				end
				local ok, errMsg = CompanySystem.leaveCompany(ctx.player)
				if not ok then
					return -2, errMsg
				end
				return 0, ("You left the company '%s'."):format(companyName)
			end)
	)
	:addSubcommand(
		Command.new("money")
			:setDesc("Manage company funds.")
			:setHelpHandler()
			:addSubcommand(
				Command.new("cheat")
					:setPermission("admin")
					:setHandler({"amount:number"}, function(self, ctx, amount)
						local companyName, companyData, err = getCompanyData(ctx)
						if companyName == nil or companyData == nil then
							return -1, err
						end
						companyData.money = companyData.money + amount
						return 0, ("Company now has: $%.2f (%s$%.2f)"):format(companyData.money, amount < 0 and "-" or "+", math.abs(amount))
					end)
			)
	)
	:addSubcommand(
		Command.new("licence")
			:setDesc("Manage company licences.")
			:setHelpHandler()
			:addSubcommand(
				Command.new("cheat")
					:setPermission("admin")
					:setHandler({"name:string"}, function(self, ctx, name)
						local companyName, companyData, err = getCompanyData(ctx)
						if companyName == nil or companyData == nil then
							return -1, err
						end
						if companyData.licences[name] then
							companyData.licences[name] = nil
							return 0, "Revoked company licence: " .. name
						else
							companyData.licences[name] = true
							return 0, "Granted company licence: " .. name
						end
					end)
			)
	)
