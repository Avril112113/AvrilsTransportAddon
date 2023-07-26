-- Packets for all binnet interface variants.
-- Packet ids 0-19 (inclusive) are reserved for these packets.

---@class BinnetBase : Binnet
---@field new fun(self): BinnetBase
---@field vehicleId integer
local BinnetBase = Binnet:new()
InterfaceSystem.BinnetBase = BinnetBase

local BinnetPackets = {}
InterfaceSystem.BinnetPackets = BinnetPackets


---@param binnet BinnetBase
BinnetPackets.UPDATE_INTERFACE = BinnetBase:registerPacketWriter(0, function(binnet, writer)
	-- local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	local interfaceVehicleInfo = InterfaceSystem.data.interfaceVehicles[binnet.vehicleId]
	if interfaceVehicleInfo == nil then
		log_error("Binnet: Attempt to update invalid interface:", binnet.vehicleId)
		return
	end
	writer:writeString(interfaceVehicleInfo.location)
end)
---@param binnet BinnetBase
BinnetPackets.UPDATE_COMPANY = BinnetBase:registerPacketWriter(1, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	writer:writeString(interface.company)
	writer:writeCustom(companyData.money, -2^24, 2^24, 0.01)
	local licenceNames = {}
	for licence, _ in pairs(companyData.licences) do
		table.insert(licenceNames, licence)
	end
	writer:writeUByte(#licenceNames)
	for _, licence in ipairs(licenceNames) do
		writer:writeString(licence)
	end
end)


---@param binnet BinnetBase
BinnetBase:registerPacketReader(2, function(binnet, reader, packetId)
	local filter = nil
	if #reader > 0 then
		filter = PRODUCIBLE_TYPE_INDICES[reader:readUByte()]
	end
	local minQuantity = -math.huge
	if #reader > 0 then
		-- To save on packet size, we're keeping it small. This can be updated if ever needed.
		minQuantity = reader:readUByte()
	end
	binnet:send(BinnetPackets.UPDATE_LOCATION_STORAGE, filter, minQuantity)
end)
---@param binnet BinnetBase
BinnetPackets.UPDATE_LOCATION_STORAGE = BinnetBase:registerPacketWriter(2, function(binnet, writer, filterType, minQuantity)
	minQuantity = minQuantity or -math.huge
	local interfaceInfo = InterfaceSystem.data.interfaceVehicles[binnet.vehicleId]
	local locationConfig = LocationSystem.locations[interfaceInfo.location]
	local storage = LocationSystem.storageAll(locationConfig)
	---@type table<string, boolean>
	local produciblesWritten = {}
	local function writeProducible(producibleName)
		if produciblesWritten[producibleName] == nil then
			local producibleConfig = Producibles.get(producibleName)
			if
				(filterType == nil or producibleConfig.type == filterType) and
				storage[producibleName] ~= nil and
				storage[producibleName] > minQuantity
			then
				produciblesWritten[producibleName] = true
				writer:writeString(producibleName)
				writer:writeCustom(storage[producibleName] or 0, -2^24, 2^24, 0.01)
			end
		end
	end
	for _, recipe in ipairs(locationConfig.production) do
		for producible, _ in pairs(recipe.consumes) do
			writeProducible(producible.name)
		end
		for producible, _ in pairs(recipe.produces) do
			writeProducible(producible.name)
		end
	end
	for producibleName, amount in pairs(storage) do
		writeProducible(producibleName)
	end
end)
