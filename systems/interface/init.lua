

---@class InterfaceSystem : System
InterfaceSystem = {name="InterfaceSystem"}
InterfaceSystem.vehicleDevMode = true

---@type table<InterfaceVariantName, InterfaceVariant>
InterfaceSystem.interfaceVariants = {}


---@class LoadedInterface
---@field active boolean?
---@field company string?
---@field binnet Binnet?
---@field cooldown integer?
---@field locked boolean? # If true, company will not change nor will the interface be disabled.

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
					InterfaceSystem._loadInterface(vehicleId)
				end
			end
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onTick", 100,
	function(game_ticks)
		for vehicle_id, interface in pairs(InterfaceSystem.loadedInterfaces) do
			InterfaceSystem.updateVehicle(vehicle_id, interface)
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleLoad", 100,
	function(vehicle_id)
		if InterfaceSystem.data.interfaceVehicles[vehicle_id] then
			InterfaceSystem._loadInterface(vehicle_id)
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleUnload", 100,
	function(vehicle_id)
		InterfaceSystem._unloadInterface(vehicle_id)
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
					-- onVehicleLoad does the rest of the setup
					log_info(("Player spawned interface vehicle is of type %s at %s"):format(interfaceVariantName, locationConfig.name))
					return
				end
			end
		end
	end
)

SystemManager.addEventHandler(InterfaceSystem, "onVehicleDespawn", 100,
	function(vehicle_id, player)
		InterfaceSystem._unloadInterface(vehicle_id)
		InterfaceSystem.data.interfaceVehicles[vehicle_id] = nil
	end
)


---@param vehicleId integer
---@return LoadedInterface
function InterfaceSystem._loadInterface(vehicleId)
	-- If the interface exists and isn't loaded already.
	if InterfaceSystem.data.interfaceVehicles[vehicleId] and InterfaceSystem.loadedInterfaces[vehicleId] == nil then
		InterfaceSystem.loadedInterfaces[vehicleId] = {cooldown=10}
	end
	return InterfaceSystem.loadedInterfaces[vehicleId]
end
function InterfaceSystem._reloadInterface(vehicleId)
	InterfaceSystem.loadedInterfaces[vehicleId] = {}
	return InterfaceSystem.loadedInterfaces[vehicleId]
end
function InterfaceSystem._unloadInterface(vehicleId)
	InterfaceSystem.loadedInterfaces[vehicleId] = nil
end


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

---@param vehicleId integer
---@param interface LoadedInterface
function InterfaceSystem.updateVehicle(vehicleId, interface)
	if not server.getVehicleSimulating(vehicleId) then
		return
	end

	local interfaceVehicleInfo = InterfaceSystem.data.interfaceVehicles[vehicleId]
	local interfaceVariant = InterfaceSystem.interfaceVariants[interfaceVehicleInfo.type]

	if interface.cooldown ~= nil then
		interface.cooldown = interface.cooldown - 1
		if interface.cooldown <= 0 then
			interface.cooldown = nil
		else
			return
		end
	end

	local prevCompany = interface.company
	if interface.locked ~= true and TickManager.sessionTick % 10 == 0 then
		local vehiclePos = server.getVehiclePos(vehicleId, 0, 0, 0)
		local players = PlayerManager.getAllPlayersDistance(vehiclePos, interfaceVariant.range)
		local prevActive = interface.active
		interface.active = #players > 0 and players[1].dist <= interfaceVariant.range
		interface.company = #players > 0 and CompanySystem.getPlayerCompanyName(players[1].player) or nil
		if interface.active ~= prevActive then
			server.setVehicleKeypad(vehicleId, "Enabled", interface.active and 1 or 0)
		end
		-- local button, ok = server.getVehicleButton(vehicleId, "Enabled")
		-- if ok and button.on ~= interface.active then
		-- 	server.pressVehicleButton(vehicleId, "Enabled")
		-- end
		if not interface.active then
			interface.binnet = nil
			return
		end
	elseif not interface.active then
		-- local button, ok = server.getVehicleButton(vehicleId, "Enabled")
		-- if ok and button.on ~= interface.active then
		-- 	server.pressVehicleButton(vehicleId, "Enabled")
		-- 	log_info(("Interface vehicle %.0f active state changed to %s"):format(vehicleId, interface.active))
		-- end
		return
	end

	local doSetup = false
	if interface.binnet == nil then
		log_info(("Interface vehicle %.0f is being setup"):format(vehicleId))
		interface.binnet = interfaceVariant.binnetBase:new()
		interface.binnet.vehicleId = vehicleId
		doSetup = true
	end
	local binnet = interface.binnet
	---@cast binnet -?

	local readValues = {}
	for i=1,interfaceVariant.binnetReadChannels do
		local dial, ok = server.getVehicleDial(vehicleId, "O"..i)
		if not ok then
			return
		end
		readValues[i] = dial.value
	end
	binnet:process(readValues)

	if doSetup then
		binnet:send(InterfaceSystem.BinnetPackets.UPDATE_INTERFACE)
	end
	if doSetup or interface.company ~= prevCompany then
		binnet:send(InterfaceSystem.BinnetPackets.UPDATE_COMPANY)
	end

	if doSetup and interfaceVariant.setup then
		interfaceVariant:setup(vehicleId, interface)
	end
	if interfaceVariant.update then
		interfaceVariant:update(vehicleId, interface)
	end

	local writeValues = binnet:write(interfaceVariant.binnetWriteChannels)
	for i=1,interfaceVariant.binnetWriteChannels do
		server.setVehicleKeypad(vehicleId, "I"..i, writeValues[i] or 0)
	end
end

---@require_folder systems/interface
require("systems.interface.commands")
require("systems.interface.packets")
require("systems.interface.variants")
---@require_folder_finish
