---@return CompanyData
local function _createEmptyCompany()
	---@class CompanyData
	return {
		---@type table<SteamId, true>
		members={},
		membersCount=0,
		money=0,
		---@type table<string, true>
		licences={},
	}
end


---@class CompanySystem : System
CompanySystem = {name="CompanySystem"}


SystemManager.addEventHandler(CompanySystem, "onCreate", 100,
	function (is_world_create)
		CompanySystem.data = SystemManager.getSaveData(CompanySystem)

		if CompanySystem.data.companies == nil then
			---@type table<string, CompanyData>
			CompanySystem.data.companies = {}
		end
		if CompanySystem.data.members == nil then
			---@type table<SteamId, string>
			CompanySystem.data.members = {}
		end
	end
)


---@return table<string, CompanyData>
function CompanySystem.getCompanies()
	return CompanySystem.data.companies
end

---@param name string
---@return CompanyData?
function CompanySystem.getCompany(name)
	return CompanySystem.getCompanies()[name]
end

---@param player Player
---@return string?
function CompanySystem.getPlayerCompanyName(player)
	return CompanySystem.data.members[player.steam_id]
end

---@overload fun(name:string):(nil, string)
---@param name string
---@return CompanyData
function CompanySystem.createCompany(name)
	local companies = CompanySystem.getCompanies()
	if companies[name] ~= nil then
		return nil, "Company already exists with that name."
	end
	---@type CompanyData
	local companyData = _createEmptyCompany()
	companies[name] = companyData
	---@diagnostic disable-next-line: missing-return-value # wtf is it going on about?
	return companyData
end

---@param name string
---@return boolean, string?
function CompanySystem.removeCompany(name)
	local companies = CompanySystem.getCompanies()
	if companies[name] == nil then
		return false, "Company does not exist."
	end
	for steamId, _ in pairs(companies[name].members) do
		local player = PlayerManager.getBySteamId(steamId)
		if player ~= nil then
			log_sendPeer(player.peer_id, "The company you were in has been disbanded.")
		end
		-- TODO: use `CompanySystem.leaveCompany()` however offline players aren't supported yet.
		CompanySystem.data.members[steamId] = nil
	end
	companies[name] = nil
	return true
end

---@param player Player
---@param name string
---@return boolean, string?
function CompanySystem.joinCompany(player, name)
	local companyData = CompanySystem.getCompany(name)
	if companyData == nil then
		return false, "Company does not exist."
	elseif CompanySystem.data.members[player.steam_id] ~= nil then
		return false, "Already in a company."
	end
	CompanySystem.data.members[player.steam_id] = name
	companyData.members[player.steam_id] = true
	companyData.membersCount = companyData.membersCount + 1
	return true
end

---@param player Player
---@return boolean, string?
function CompanySystem.leaveCompany(player)
	if CompanySystem.data.members[player.steam_id] == nil then
		return false, "Not in a company."
	end
	local companyData = CompanySystem.getCompany(CompanySystem.data.members[player.steam_id])
	CompanySystem.data.members[player.steam_id] = nil
	if companyData == nil then
		log_warn(("Player '%s' was in a company that doesn't exist."):format(player.name))
	else
		companyData.members[player.steam_id] = nil
		companyData.membersCount = companyData.membersCount - 1
	end
	return true
end


---@require_folder systems/company
require("systems.company.commands")
---@require_folder_finish
