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

--- `LocationConfig.ACCESS_TYPE_TAGS` Must match with MC
---@class InterfaceVariantGeneral : InterfaceVariant
Variants.general = {
	vehicleName="vehicle_interface",
	offset=matrix.translation(0, -1.25, 0),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
	INTERFACE_TAGS={["pump"]=0, ["mineral"]=1},  -- Must match with MC
}
---@param binnet BinnetBase
Variants.general.binnetBase:registerPacketReader(20, function(binnet, reader, packetId)
	binnet:send(packetId)
end)
---@param binnet BinnetBase
Variants.general.binnetBase:registerPacketWriter(20, function(binnet, writer)
	local interfaceInfo = InterfaceSystem.data.interfaceVehicles[binnet.vehicleId]
	local locationConfig = LocationSystem.locations[interfaceInfo.location]

	---@type table<string, {general:boolean?,pump:boolean?,mineral:boolean?,recipe:LocationRecipe?}>
	local infrastructures = {}
	local infrastructureOrder = shallowCopy(LocationConfig.ACCESS_TYPE_TAGS, {})

	for _, interfaceZone in pairs(locationConfig.interfaces) do
		for _, infraTag in ipairs(LocationConfig.ACCESS_TYPE_TAGS) do
			if interfaceZone.tags[infraTag] then
				local infra = infrastructures[infraTag] or {}
				infrastructures[infraTag] = infra
				infra[interfaceZone.tags.interface_type] = true
			end
		end
	end
	for _, recipe in ipairs(locationConfig.production) do
		infrastructures[recipe.name] = {recipe=recipe}
		table.insert(infrastructureOrder, recipe.name)
	end

	for _, infraName in ipairs(infrastructureOrder) do
		local infra = infrastructures[infraName]
		if infra ~= nil then
			writer:writeString(infraName)
			local interfacesByte = 0
			for interfaceTag, i in pairs(Variants.general.INTERFACE_TAGS) do
				if infra[interfaceTag] then
					interfacesByte = interfacesByte | (1<<i)
				end
			end
			if infra.recipe then
				interfacesByte = interfacesByte | (1<<7)
			end
			writer:writeUByte(interfacesByte)
			if infra.recipe then
				writer:writeUByte(0)
				local sizeByteIndex = #writer
				for producibleConfig, amount in pairs(infra.recipe.consumes) do
					writer:writeString(producibleConfig.name)
					writer:writeCustom(-amount/infra.recipe.rate*60*60, -2^24, 2^24, 0.01)
					writer[sizeByteIndex] = writer[sizeByteIndex] + 1
				end
				for producibleConfig, amount in pairs(infra.recipe.produces) do
					writer:writeString(producibleConfig.name)
					writer:writeCustom(amount/infra.recipe.rate*60*60, -2^24, 2^24, 0.01)
					writer[sizeByteIndex] = writer[sizeByteIndex] + 1
				end
			end
		end
	end
end)

---@class LoadedInterface_PumpInterface : LoadedInterface
---@field selectedProducibleName string?
---@field transferAmount number
---@field transferMoney number
---@field receivedFreeAmount number
---@field consumedFreeAmount number
---@field outTankFreeAmount number
---@class InterfaceVariantPump : InterfaceVariant
Variants.pump = {
	vehicleName="vehicle_pump",
	offset=matrix.translation(0, -1.1, -0.25),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
	updateRate=60,
	transferFreeAmount = 5.56,  -- How much fluid is lost when receiving fluid.
	transferLostAmount = 3.8461685181,  -- How much fluid is lost when giving a vehicle fluid.
	respawnOnDeselect = true,  -- To clear the fluid in the pump vehicle to prevent contamination
	setup=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_PumpInterface
		interface.selectedProducibleName = nil
		interface.transferAmount = 0
		interface.transferMoney = 0
		interface.receivedFreeAmount = Variants.pump.transferFreeAmount
		interface.consumedFreeAmount = Variants.pump.transferLostAmount
		interface.outTankFreeAmount = Variants.pump.transferLostAmount
	end,
	update=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_PumpInterface

		if TickManager.sessionTick % self.updateRate ~= 0 then
			return
		end

		local interfaceInfo = InterfaceSystem.data.interfaceVehicles[vehicleId]
		local locationConfig = LocationSystem.locations[interfaceInfo.location]

		local companyData = CompanySystem.getCompany(interface.company)
		if companyData == nil then
			return
		end

		local tankOut, ok = server.getVehicleTank(vehicleId, "fluid_out")  -- Out of location
		if not ok then return end
		local tankIn, ok = server.getVehicleTank(vehicleId, "fluid_in")  -- Into location
		if not ok then return end

		local prevTransferAmount = interface.transferAmount

		for fluidEnum, amount in pairs(tankIn.values) do
			if amount > 0 then
				local producibleConfig = Producibles.getByEnum("fluid", fluidEnum, true)
				if producibleConfig ~= nil then
					if interface.selectedProducibleName ~= producibleConfig.name then
						interface.selectedProducibleName = producibleConfig.name
						interface.transferAmount = 0
						interface.transferMoney = 0
						interface.binnet:send(20)
					end
					local freeAmount = math.min(interface.receivedFreeAmount, amount*15)
					amount = amount + freeAmount
					interface.receivedFreeAmount = interface.receivedFreeAmount - freeAmount
					-- Due to the interface being respawned when deselecting a fluid, we "force" this fluid into the storage.
					local remainder = LocationSystem.storageAdd(locationConfig, producibleConfig, amount, "force")
					server.setVehicleTank(vehicleId, "fluid_in", remainder, fluidEnum)
					interface.transferAmount = interface.transferAmount - (amount-remainder)
					-- FIXME: We are losing some resources https://geometa.co.uk/support/stormworks/20863/
					-- TODO: Give company money.
				else
					-- TODO: Warn the player about invalid fluid...
					server.setVehicleTank(vehicleId, "fluid_in", 0, fluidEnum)
				end
			end
		end

		local selectedProducible = Producibles.byName[interface.selectedProducibleName]
		if selectedProducible ~= nil and interface.selectedTankAmount ~= nil then
			local consumed = interface.selectedTankAmount - tankOut.values[selectedProducible.fluidType]
			if interface.consumedFreeAmount > 0 then
				local freeConsumed = math.min(interface.consumedFreeAmount, consumed)
				interface.consumedFreeAmount = interface.consumedFreeAmount - freeConsumed
				consumed = consumed - freeConsumed
			end
			interface.transferAmount = interface.transferAmount + consumed
			-- TODO: Consume company money.
		end

		local setSelectedTankAmount = false
		for fluidEnum, amount in pairs(tankOut.values) do
			if selectedProducible ~= nil and fluidEnum == selectedProducible.fluidType then
				-- TODO: Replace `companyData.money >= 0` with affordable amount.
				local addAmount = math.min(
					tankOut.capacity - (amount + interface.outTankFreeAmount),
					companyData.money >= 0 and math.huge or 0
				)
				local freeAmount = math.min(interface.outTankFreeAmount, addAmount)
				local storageAmount = addAmount - freeAmount
				addAmount = freeAmount + LocationSystem.storageRemove(locationConfig, selectedProducible, storageAmount, "partial")
				interface.outTankFreeAmount = interface.outTankFreeAmount - freeAmount
				server.setVehicleTank(vehicleId, "fluid_out", amount + addAmount, fluidEnum)
				interface.selectedTankAmount = amount + addAmount
				setSelectedTankAmount = true
			elseif amount ~= 0 then
				server.setVehicleTank(vehicleId, "fluid_out", 0, fluidEnum)
				local tankProducible = Producibles.getByEnum("fluid", fluidEnum, true)
				if tankProducible ~= nil then
					LocationSystem.storageAdd(locationConfig, tankProducible, amount, "force")  -- Should we be forcing it?
				else
					log_error(("Pump interface got producible that isn't valid %s %sL"):format(fluidEnum, amount))
				end
			end
		end
		if not setSelectedTankAmount then
			interface.selectedTankAmount = nil
		end

		if interface.selectedProducibleName ~= nil then
			interface.locked = true
		elseif interface.locked then
			interface.locked = false
			if self.respawnOnDeselect then
				InterfaceSystem.respawnInterfaceVehicle(vehicleId)
			end
		end

		if interface.transferAmount ~= prevTransferAmount then
			interface.binnet:send(21)
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
	interface.transferAmount = 0
	interface.transferMoney = 0
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
--- Send transferred amount and money.
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

	writer:writeCustom(interface.transferAmount, -2^24, 2^24, 0.01)
	writer:writeCustom(interface.transferMoney, -2^24, 2^24, 0.01)
end)


---@class LoadedInterface_MineralInterface : LoadedInterface
---@field selectedProducibleName string?
---@field transferState boolean # true to load minerals
---@field transferAmount number
---@field transferMoney number
---@field loaderSetAmounts table<integer,number>
---@field mineralLoaders integer[]
---@field mineralUnloaders integer[]
---@class InterfaceVariantMineral : InterfaceVariant
Variants.mineral = {
	vehicleName="vehicle_mineral",
	offset=matrix.translation(0, -1.1, -0.25),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
	updateRate=60,
	setup=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_MineralInterface
		interface.selectedProducibleName = nil
		interface.transferAmount = 0
		interface.transferMoney = 0

		interface.loaderSetAmounts = {}

		local interfaceData = InterfaceSystem.data.interfaceVehicles[vehicleId]
		interface.mineralLoaders = interfaceData.assignedVehicles.mineral_loaders or {}
		interface.mineralUnloaders = interfaceData.assignedVehicles.mineral_unloaders or {}
	end,
	update=function(self, vehicleId, interface)
		---@cast interface LoadedInterface_MineralInterface

		if TickManager.sessionTick % self.updateRate ~= 0 then
			return
		end

		local interfaceInfo = InterfaceSystem.data.interfaceVehicles[vehicleId]
		local locationConfig = LocationSystem.locations[interfaceInfo.location]

		local companyData = CompanySystem.getCompany(interface.company)
		if companyData == nil then
			return
		end

		local prevTransferAmount = interface.transferAmount

		for _, unloaderVehicleId in pairs(interface.mineralUnloaders) do
			local hopper, ok = server.getVehicleHopper(unloaderVehicleId, "mineral_unload")
			if ok then
				for mineralEnum, amount in pairs(hopper.values) do
					if amount > 0 then
						local producibleConfig = Producibles.getByEnum("mineral", mineralEnum, true)
						if producibleConfig ~= nil then
							if interface.selectedProducibleName ~= producibleConfig.name then
								interface.selectedProducibleName = producibleConfig.name
								interface.transferAmount = 0
								interface.transferMoney = 0
								interface.binnet:send(20)
							end

							local remainder = LocationSystem.storageAdd(locationConfig, producibleConfig, amount, "partial")
							server.setVehicleHopper(unloaderVehicleId, "mineral_unload", remainder, mineralEnum)
							local transferredAmount = amount-remainder
							interface.transferAmount = interface.transferAmount + transferredAmount
							-- FIXME: We are losing some resources https://geometa.co.uk/support/stormworks/20863/
							-- TODO: Give company money
						else
							-- TODO: Warn the player about invalid mineral...
							server.setVehicleHopper(unloaderVehicleId, "mineral_unload", 0, mineralEnum)
						end
					end
				end
			end
		end

		local selectedProducible = Producibles.byName[interface.selectedProducibleName]
		if selectedProducible ~= nil then
			for loaderVehicleId, setAmount in pairs(interface.loaderSetAmounts) do
				local hopper, ok = server.getVehicleHopper(loaderVehicleId, "mineral_load")
				if ok then
					local consumed = setAmount - hopper.values[selectedProducible.mineralType]
					interface.transferAmount = interface.transferAmount + consumed
					-- FIXME: We are creating free some resources, probably due to https://geometa.co.uk/support/stormworks/20863/
				end
			end
		end

		local LOADER_MINERAL_LIMIT = 45
		for _, loaderVehicleId in pairs(interface.mineralLoaders) do
			local setSelectedAmount = false
			local hopper, ok = server.getVehicleHopper(loaderVehicleId, "mineral_load")
			if ok then
				for mineralEnum, amount in pairs(hopper.values) do
					if interface.transferState and selectedProducible ~= nil and mineralEnum == selectedProducible.mineralType then
						-- TODO: Replace `companyData.money >= 0` with affordable amount.
						local addAmount = math.min(
							LOADER_MINERAL_LIMIT-amount,
							companyData.money >= 0 and math.huge or 0,
							math.floor(LocationSystem.storageFreeSpaceFor(locationConfig, selectedProducible))
						)
						addAmount = LocationSystem.storageRemove(locationConfig, selectedProducible, addAmount, "partial")
						server.setVehicleHopper(loaderVehicleId, "mineral_load", amount + addAmount, mineralEnum)
						interface.loaderSetAmounts[loaderVehicleId] = amount + addAmount
						setSelectedAmount = true
					elseif amount ~= 0 then
						server.setVehicleHopper(loaderVehicleId, "mineral_load", 0, mineralEnum)
						local tankProducible = Producibles.getByEnum("mineral", mineralEnum, true)
						if tankProducible ~= nil then
							LocationSystem.storageAdd(locationConfig, tankProducible, amount, "force")  -- Should we be forcing it?
						else
							-- TODO: Do something :/
							log_info(("Mineral interface loader got producible that isn't valid %s %sL"):format(mineralEnum, amount))
						end
					end
				end
			end
			if not setSelectedAmount then
				interface.loaderSetAmounts[loaderVehicleId] = nil
			end
		end

		if interface.selectedProducibleName ~= nil then
			interface.locked = true
		else
			interface.locked = false
		end

		if interface.transferAmount ~= prevTransferAmount then
			interface.binnet:send(21)
		end
	end,
}
---@param binnet BinnetBase
Variants.mineral.binnetBase:registerPacketReader(20, function(binnet, reader, packetId)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_MineralInterface
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	interface.selectedProducibleName = #reader > 0 and reader:readString() or nil
	interface.transferAmount = 0
	interface.transferMoney = 0
end)
---@param binnet BinnetBase
Variants.mineral.binnetBase:registerPacketWriter(20, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_MineralInterface
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
--- Send transferred amount and money.
---@param binnet BinnetBase
Variants.mineral.binnetBase:registerPacketWriter(21, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_MineralInterface
	if interface.company == nil then
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		return
	end

	writer:writeCustom(interface.transferAmount, -2^24, 2^24, 0.01)
	writer:writeCustom(interface.transferMoney, -2^24, 2^24, 0.01)
end)
--- Transfer state from interface
---@param binnet BinnetBase
Variants.mineral.binnetBase:registerPacketReader(22, function(binnet, writer)
	local interface = InterfaceSystem.loadedInterfaces[binnet.vehicleId]
	---@cast interface LoadedInterface_MineralInterface
	if interface.company == nil then
		interface.transferState = false
		return
	end
	local companyData = CompanySystem.getCompany(interface.company)
	if companyData == nil then
		interface.transferState = false
		return
	end
	interface.transferState = writer:readUByte() > 0
end)
