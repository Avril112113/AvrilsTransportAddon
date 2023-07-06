local BINNET_READ_COUNT = 3
local BINNET_WRITE_COUNT = 9

local INTERFACE_VEHICLE_LOCATION_NAME = "vehicle_interface"
local INTERFACE_VEHICLE_SPAWN_OFFSET = matrix.translation(0, -1.25, 0)
local INTERFACE_VEHICLE_RANGE = 15


---@class InterfaceSystem : System
InterfaceSystem = {name="InterfaceSystem"}
InterfaceSystem.vehicleDevMode = true


---@class LoadedInterface
---@field binnet Binnet
---@field cooldown integer?  # Do not run anything until after this many ticks.
---@field company string?
---@field companyUpdate boolean?

---@type table<integer, LoadedInterface>
InterfaceSystem.loadedInterfaces = {}


---@param is_world_create boolean Only returns true when the world is first created.
function InterfaceSystem.onCreate(is_world_create)
	InterfaceSystem.data = SystemManager.getSaveData(InterfaceSystem)

	if InterfaceSystem.data.interfaceVehicles == nil then
		---@type table<integer, string>
		InterfaceSystem.data.interfaceVehicles = {}
	end

	if not is_world_create then
		for vehicleId, locationName in pairs(InterfaceSystem.data.interfaceVehicles) do
			if InterfaceSystem.loadedInterfaces[vehicleId] == nil and server.getVehicleSimulating(vehicleId) then
				InterfaceSystem.loadedInterfaces[vehicleId] = {cooldown=30}
			end
		end
	end
end

local tick = 0
---@param game_ticks number the number of ticks since the last onTick call (normally 1, while sleeping 400.)
function InterfaceSystem.onTick(game_ticks)
	tick = tick + 1

	for vehicle_id, interface in pairs(InterfaceSystem.loadedInterfaces) do
		InterfaceSystem.updateVehicle(vehicle_id, interface)
	end
end

---@param vehicle_id number The vehicle ID of the vehicle that was spawned.
function InterfaceSystem.onVehicleLoad(vehicle_id)
	if InterfaceSystem.data.interfaceVehicles[vehicle_id] then
		InterfaceSystem.loadedInterfaces[vehicle_id] = {cooldown=30}
	end
end

---@param vehicle_id number The vehicle ID of the vehicle that was spawned.
function InterfaceSystem.onVehicleUnload(vehicle_id)
	InterfaceSystem.loadedInterfaces[vehicle_id] = nil
end

---@param vehicle_id number The vehicle ID of the vehicle that was spawned.
---@param player Player?
--- @param x number The x coordinate of the vehicle's spawn location relative to world space.
--- @param y number The y coordinate of the vehicle's spawn location relative to world space.
--- @param z number The z coordinate of the vehicle's spawn location relative to world space.
--- @param cost number The cost of the vehicle. Only calculated for player spawned vehicles.
function InterfaceSystem.onVehicleSpawn(vehicle_id, player, x, y, z, cost)
	if InterfaceSystem.vehicleDevMode and player ~= nil then
		local locationConfig = LocationSystem.getClosestLocation(server.getPlayerPos(player.peer_id))
		InterfaceSystem.data.interfaceVehicles[vehicle_id] = locationConfig.name
		InterfaceSystem.loadedInterfaces[vehicle_id] = {cooldown=30}
	end
end

---@param vehicle_id number The vehicle ID of the vehicle that was spawned.
---@param player Player?
function InterfaceSystem.onVehicleDespawn(vehicle_id, player)
	InterfaceSystem.loadedInterfaces[vehicle_id] = nil
	InterfaceSystem.data.interfaceVehicles[vehicle_id] = nil
end


---@param transform SWMatrix
---@param locationConfig LocationConfig
function InterfaceSystem.createInterfaceVehicle(transform, locationConfig)
	transform = matrix.multiply(transform, INTERFACE_VEHICLE_SPAWN_OFFSET)
	local vehicleId = VehicleManager.spawnStaticVehicle(InterfaceSystem, INTERFACE_VEHICLE_LOCATION_NAME, transform)
	InterfaceSystem.data.interfaceVehicles[vehicleId] = locationConfig.name
	return vehicleId
end

---@param vehicleId integer
function InterfaceSystem.respawnInterfaceVehicle(vehicleId)
	local locationName = InterfaceSystem.data.interfaceVehicles[vehicleId]
	local newVehicleId, err = VehicleManager.respawnStaticVehicle(vehicleId)
	if newVehicleId then
		InterfaceSystem.data.interfaceVehicles[vehicleId] = nil
		InterfaceSystem.data.interfaceVehicles[newVehicleId] = locationName
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

	local doSetup = false
	if not interface.enabled and interface.cooldown == nil then
		interface.binnet = InterfaceSystem.BinnetBase:new()
		interface.binnet.vehicleId = vehicle_id
		interface.enabled = true
		doSetup = true
		log_info(("Interface vehicle %.0f is being setup"):format(vehicle_id))
	end
	local binnet = interface.binnet

	local readValues = {}
	for i=1,BINNET_READ_COUNT do
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
		local players = PlayerManager.getAllPlayersDistance(vehiclePos, INTERFACE_VEHICLE_RANGE)
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

	local writeValues = binnet:write(BINNET_WRITE_COUNT)
	for i=1,BINNET_WRITE_COUNT do
		server.setVehicleKeypad(vehicle_id, "I"..i, writeValues[i] or 0)
	end
end


SystemManager.registerSystem(InterfaceSystem)

---@require_folder systems/interface
require("systems.interface.commands")
require("systems.interface.packets")
---@require_folder_finish
