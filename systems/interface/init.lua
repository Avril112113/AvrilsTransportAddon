

---@class InterfaceSystem : System
InterfaceSystem = {name="InterfaceSystem"}
InterfaceSystem.vehicleDevMode = true

---@type table<InterfaceVariantName, InterfaceVariant>
InterfaceSystem.interfaceVariants = {}


---@class LoadedInterface
---@field binnet Binnet
---@field cooldown integer?  # Do not run anything until after this many ticks.
---@field company string?
---@field companyUpdate boolean?

---@type table<integer, LoadedInterface>
InterfaceSystem.loadedInterfaces = {}


SystemManager.addEventHandler(InterfaceSystem, "onCreate", 100,
	function(is_world_create)
		InterfaceSystem.data = SystemManager.getSaveData(InterfaceSystem)

		if InterfaceSystem.data.interfaceVehicles == nil then
			---@type table<integer, {type:InterfaceVariantName,location:string}>
			InterfaceSystem.data.interfaceVehicles = {}
		end

		if not is_world_create then
			for vehicleId, _ in pairs(InterfaceSystem.data.interfaceVehicles) do
				if InterfaceSystem.loadedInterfaces[vehicleId] == nil and server.getVehicleSimulating(vehicleId) then
					InterfaceSystem.loadedInterfaces[vehicleId] = {cooldown=30}
				end
			end
		end
	end
)

local tick = 0
SystemManager.addEventHandler(InterfaceSystem, "onTick", 100,
	function(game_ticks)
		tick = tick + 1

		for vehicle_id, interface in pairs(InterfaceSystem.loadedInterfaces) do
			InterfaceSystem.updateVehicle(vehicle_id, interface)
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleLoad", 100,
	function(vehicle_id)
		if InterfaceSystem.data.interfaceVehicles[vehicle_id] then
			InterfaceSystem.loadedInterfaces[vehicle_id] = {cooldown=30}
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleUnload", 100,
	function(vehicle_id)
		InterfaceSystem.loadedInterfaces[vehicle_id] = nil
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleSpawn", 100,
	function(vehicle_id, player, x, y, z, cost)
		if InterfaceSystem.vehicleDevMode and player ~= nil then
			local locationConfig = LocationSystem.getClosestLocation(server.getPlayerPos(player.peer_id))
			local filename = server.getVehicleData(vehicle_id).filename:lower()
			for interfaceVariantName, interfaceVariant in pairs(InterfaceSystem.interfaceVariants) do
				if filename:find(interfaceVariantName) then
					InterfaceSystem.data.interfaceVehicles[vehicle_id] = {
						type=interfaceVariantName,
						location=locationConfig.name,
					}
					InterfaceSystem.loadedInterfaces[vehicle_id] = {cooldown=30}
					log_info(("Player spawned interface vehicle is of type %s at %s"):format(interfaceVariantName, locationConfig.name))
					return
				end
			end
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleDespawn", 100,
	function(vehicle_id, player)
		InterfaceSystem.loadedInterfaces[vehicle_id] = nil
		InterfaceSystem.data.interfaceVehicles[vehicle_id] = nil
	end
)


---@param transform SWMatrix
---@param locationConfig LocationConfig
---@param interfaceVariantName InterfaceVariantName
function InterfaceSystem.createInterfaceVehicle(transform, locationConfig, interfaceVariantName)
	local interfaceVariant = InterfaceSystem.interfaceVariants[interfaceVariantName]
	if interfaceVariant == nil then
		log_error(("Invalid interface type '%s' at location %s"):format(interfaceVariantName, locationConfig.name))
		return nil
	end
	transform = matrix.multiply(transform, interfaceVariant.offset)
	local vehicleId = VehicleManager.spawnStaticVehicle(InterfaceSystem, interfaceVariant.vehicleName, transform)
	InterfaceSystem.data.interfaceVehicles[vehicleId] = {
		type=interfaceVariantName,
		location=locationConfig.name,
	}
	return vehicleId
end

---@param vehicleId integer
function InterfaceSystem.respawnInterfaceVehicle(vehicleId)
	local interfaceVehicleInfo = InterfaceSystem.data.interfaceVehicles[vehicleId]
	local newVehicleId, err = VehicleManager.respawnStaticVehicle(vehicleId)
	if newVehicleId then
		InterfaceSystem.data.interfaceVehicles[vehicleId] = nil
		InterfaceSystem.data.interfaceVehicles[newVehicleId] = interfaceVehicleInfo
	end
	return newVehicleId, err
end

function InterfaceSystem.despawnAllInterfaces()
	for vehicleId, _ in pairs(InterfaceSystem.data.interfaceVehicles) do
		server.despawnVehicle(vehicleId, true)
	end
end

---@param vehicle_id integer
---@param interface LoadedInterface
function InterfaceSystem.updateVehicle(vehicle_id, interface)
	local data, ok = server.getVehicleButton(vehicle_id, "Enabled")
	if not ok or not data.on then
		if interface.enabled then
			InterfaceSystem.loadedInterfaces[vehicle_id] = {cooldown=30}
		end
		return
	end

	if interface.cooldown ~= nil then
		interface.cooldown = interface.cooldown - 1
		if interface.cooldown <= 0 then
			interface.cooldown = nil
		else
			return
		end
	end

	local interfaceVehicleInfo = InterfaceSystem.data.interfaceVehicles[vehicle_id]
	local interfaceVariant = InterfaceSystem.interfaceVariants[interfaceVehicleInfo.type]

	local doSetup = false
	if not interface.enabled and interface.cooldown == nil then
		interface.binnet = interfaceVariant.binnetBase:new()
		interface.binnet.vehicleId = vehicle_id
		interface.enabled = true
		doSetup = true
		log_info(("Interface vehicle %.0f is being setup"):format(vehicle_id))
	end
	local binnet = interface.binnet

	local readValues = {}
	for i=1,interfaceVariant.binnetReadChannels do
		local dial, ok = server.getVehicleDial(vehicle_id, "O"..i)
		if not ok then
			return -1
		end
		readValues[i] = dial.value
	end
	binnet:process(readValues)

	interface.companyUpdate = nil
	if doSetup or tick % 10 == 0 then
		interface.companyUpdate = true
		local vehiclePos = server.getVehiclePos(vehicle_id, 0, 0, 0)
		local players = PlayerManager.getAllPlayersDistance(vehiclePos, interfaceVariant.range)
		if #players > 0 then
			local companyName = CompanySystem.getPlayerCompanyName(players[1].player)
			if interface.company ~= companyName then
				interface.company = companyName
			end
		end
	end

	if doSetup then
		binnet:send(InterfaceSystem.BinnetPackets.UPDATE_INTERFACE)
	end
	if doSetup or interface.companyUpdate then
		binnet:send(InterfaceSystem.BinnetPackets.UPDATE_COMPANY)
	end

	interfaceVariant:update(doSetup, tick, binnet)

	local writeValues = binnet:write(interfaceVariant.binnetWriteChannels)
	for i=1,interfaceVariant.binnetWriteChannels do
		server.setVehicleKeypad(vehicle_id, "I"..i, writeValues[i] or 0)
	end
end

---@require_folder systems/interface
require("systems.interface.commands")
require("systems.interface.packets")
require("systems.interface.variants")
---@require_folder_finish
