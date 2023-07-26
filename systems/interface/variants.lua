-- NOTE: This file must be ordered after `packets.lua` (which is based on file name)
-- Packet ids 20+ are free to use for interface variant specific data.

---@alias InterfaceVariantName "general"|"pump"|"mineral"


---@class InterfaceVariant
---@field vehicleName string
---@field offset SWMatrix
---@field range number
---@field binnetReadChannels integer
---@field binnetWriteChannels integer
---@field binnetBase BinnetBase
---@field setup nil|fun(self, vehicleId:integer, interface:LoadedInterface)
---@field update nil|fun(self, vehicleId:integer, interface:LoadedInterface)


local Variants = InterfaceSystem.interfaceVariants

---@type InterfaceVariant
Variants.general = {
	vehicleName="vehicle_interface",
	offset=matrix.translation(0, -1.25, 0),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
}

---@class LoadedInterface_PumpInterface : LoadedInterface
---@field selectedProducibleName string?
---@field autoSelectCooldown number?
---@field pumpAmount number
---@field pumpMoney number
---@type InterfaceVariant
Variants.pump = {
	vehicleName="vehicle_pump",
	offset=matrix.translation(0, -1.1, -0.25),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
	updateRate=60,
	setup=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_PumpInterface
		interface.selectedProducibleName = nil
		interface.autoSelectCooldown = 0
		interface.pumpAmount = 0
		interface.pumpMoney = 0
	end,
	update=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_PumpInterface

		if TickManager.sessionTick % self.updateRate ~= 0 then
			return
		end

		local interfaceInfo = InterfaceSystem.data.interfaceVehicles[vehicleId]
		local locationConfig = LocationSystem.locations[interfaceInfo.location]

		if interface.company == nil then
			return
		end
		local companyData = CompanySystem.getCompany(interface.company)
		if companyData == nil then
			return
		end

		local tankOut, ok = server.getVehicleTank(vehicleId, "fluid_out")  -- Out of location
		if not ok then return end
		local tankIn, ok = server.getVehicleTank(vehicleId, "fluid_in")  -- Into location
		if not ok then return end

		local prevPumpAmount = interface.pumpAmount

		for fluidEnum, amount in pairs(tankIn.values) do
			if amount > 0 then
				local producibleConfig = Producibles.getByEnum("fluid", fluidEnum, true)
				if producibleConfig ~= nil then
					if interface.selectedProducibleName ~= producibleConfig.name then
						if interface.autoSelectCooldown <= 0 then
							interface.selectedProducibleName = producibleConfig.name
							interface.pumpAmount = 0
							interface.pumpMoney = 0
							interface.binnet:send(20)
						end
					end
					local remainder = LocationSystem.storageAdd(locationConfig, producibleConfig, amount, "partial")
					server.setVehicleTank(vehicleId, "fluid_in", remainder, fluidEnum)
					interface.pumpAmount = interface.pumpAmount - (amount-remainder)
					-- FIXME: We are only getting half the fluid? https://geometa.co.uk/support/stormworks/20863/
					-- TODO: Give company money.
				else
					-- TODO: Warn the player about invalid fluid...
					server.setVehicleTank(vehicleId, "fluid_in", 0, fluidEnum)
				end
			end
		end

		local selectedProducible = Producibles.byName[interface.selectedProducibleName]
		if selectedProducible ~= nil and interface.selectedTankAmount ~= nil then
			local consumedFluid = interface.selectedTankAmount - tankOut.values[selectedProducible.fluidType]
			interface.pumpAmount = interface.pumpAmount + consumedFluid
			-- TODO: Consume company money. We are accepting negative money as a possibility.
		end

		local setSelectedTankAmount = false
		for fluidEnum, amount in pairs(tankOut.values) do
			if selectedProducible ~= nil and fluidEnum == selectedProducible.fluidType then
				-- FIXME: This is just completley broken? Getting infinite fluid.
				-- TODO: Replace `companyData.money >= 0` with affordable amount.
				local addAmount = math.min(tankOut.capacity-amount, companyData.money >= 0 and math.huge or 0)
				addAmount = LocationSystem.storageRemove(locationConfig, selectedProducible, addAmount, "partial")
				server.setVehicleTank(vehicleId, "fluid_out", amount + addAmount, fluidEnum)
				interface.selectedTankAmount = amount + addAmount
				setSelectedTankAmount = true
			elseif amount ~= 0 then
				server.setVehicleTank(vehicleId, "fluid_out", 0, fluidEnum)
				local tankProducible = Producibles.getByEnum("fluid", fluidEnum, true)
				if tankProducible ~= nil then
					LocationSystem.storageAdd(locationConfig, tankProducible, amount, "force")  -- Should we be forcing it?
					-- TODO: Refund company for fluid.
				else
					-- TODO: Do something :/
					log_info(("Pump interface got fluid that isn't a refundable producible %s %sL"):format(fluidEnum, amount))
				end
			end
		end
		if not setSelectedTankAmount then
			interface.selectedTankAmount = nil
		end

		if interface.pumpAmount ~= prevPumpAmount then
			interface.binnet:send(21)
		end

		if interface.autoSelectCooldown ~= nil then
			interface.autoSelectCooldown = interface.autoSelectCooldown - self.updateRate
		end
	end,
}
---@param binnet BinnetBase
Variants.pump.binnetBase:registerPacketReader(20, function(binnet, reader, packetId)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_PumpInterface
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	interface.selectedProducibleName = #reader > 0 and reader:readString() or nil
	interface.autoSelectCooldown = 180
	interface.pumpAmount = 0
	interface.pumpMoney = 0
end)
---@param binnet BinnetBase
Variants.pump.binnetBase:registerPacketWriter(20, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_PumpInterface
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	if interface.selectedProducibleName then
		writer:writeString(interface.selectedProducibleName)
	end
end)
---@param binnet BinnetBase
Variants.pump.binnetBase:registerPacketWriter(21, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_PumpInterface
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	writer:writeCustom(interface.pumpAmount, -2^24, 2^24, 0.01)
	writer:writeCustom(interface.pumpMoney, -2^24, 2^24, 0.01)
end)
