-- NOTE: ALL binnets share readers/writers!
---@class BinnetBase : Binnet
---@field vehicleId integer
local BinnetBase = Binnet:new()
InterfaceSystem.BinnetBase = BinnetBase

local BinnetPackets = {}
InterfaceSystem.BinnetPackets = BinnetPackets


---@param binnet BinnetBase
BinnetPackets.UPDATE_INTERFACE = BinnetBase:registerPacketWriter(function(binnet, writer)
	-- local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	local locationName = InterfaceSystem.data.interfaceVehicles[binnet.vehicleId]
	if locationName == nil then
		log_error("Attempt to update interface, but has invalid location:", locationName)
		return
	end
	writer:writeString(locationName)
end)
---@param binnet BinnetBase
BinnetPackets.UPDATE_COMPANY = BinnetBase:registerPacketWriter(function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	writer:writeString(interface.company)
	writer:writeCustom(companyData.money, -(2^24), 2^24, 0.01)
	local licenceNames = {}
	for licence, _ in pairs(companyData.licences) do
		table.insert(licenceNames, licence)
	end
	writer:writeUByte(#licenceNames)
	for _, licence in ipairs(licenceNames) do
		writer:writeString(licence)
	end
end)

-- ---@param binnet BinnetBase
-- BinnetBase:registerPacketReader(function(binnet, writer)
-- 	-- local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
-- 	log_info(("Interface %.0f finished loading."):format(binnet.vehicleId))
-- end)
