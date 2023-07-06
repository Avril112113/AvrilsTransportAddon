---@class VehicleData
---@field damage number?

---@class SystemVehicleData
---@field system string
---@field locationName string
---@field spawnTransform SWMatrix


local ADDON_INDEX = server.getAddonIndex()


VehicleManager = {name="VehicleManager"}


EventManager.addEventHandler("onCreate", 2,
	function(is_world_create)
		-- Should we be avoiding the SystemManager here?
		VehicleManager.data = SystemManager.getSaveData(VehicleManager)
		if VehicleManager.data.vehicleData == nil then
			---@type table<integer, VehicleData>
			VehicleManager.data.vehicleData = {}
		end
		if VehicleManager.data.systemVehicles == nil then
			---@type table<integer, SystemVehicleData>
			VehicleManager.data.systemVehicles = {}
		end
	end
)

EventManager.addEventHandler("onVehicleSpawn", 2,
	function (vehicle_id, player, x, y, z, cost)
		if player ~= nil then
			local vehicleData = VehicleManager.getOrCreateVehicle(vehicle_id)
			vehicleData.cost = math.max(0, cost)
			vehicleData.player = player.steam_id
		end
	end
)

EventManager.addEventHandler("onVehicleDespawn", 2,
	function (vehicle_id, player)
		VehicleManager.data.systemVehicles[vehicle_id] = nil
		VehicleManager.data.vehicleData[vehicle_id] = nil
	end
)

EventManager.addEventHandler("onVehicleDamaged", 2,
	function (vehicle_id, damage_amount, voxel_x, voxel_y, voxel_z, body_index)
		local vehicleData = VehicleManager.getOrCreateVehicle(vehicle_id)
		vehicleData.damage = (vehicleData.damage or 0) + damage_amount
	end
)


function VehicleManager.getVehicles()
	return VehicleManager.data.vehicleData
end

---@param vehicle_id number
---@return VehicleData?
function VehicleManager.getVehicle(vehicle_id)
	return VehicleManager.data.vehicleData[vehicle_id]
end

---@param vehicle_id number
---@return VehicleData
function VehicleManager.getOrCreateVehicle(vehicle_id)
	local vehicleData = VehicleManager.data.vehicleData[vehicle_id]
	if vehicleData == nil then
		vehicleData = {}
		VehicleManager.data.vehicleData[vehicle_id] = vehicleData
	end
	return vehicleData
end

---@generic T : any
---@param vehicle_id number
---@param field string
---@param default T
---@return T
function VehicleManager.getVehicleField(vehicle_id, field, default)
	local vehicleData = VehicleManager.getVehicle(vehicle_id)
	if vehicleData == nil then
		return default
	end
	local value = vehicleData[field]
	if value == nil then
		return default
	end
	return value
end

---@generic T : any
---@param vehicle_id number
---@param field string
---@param value T
---@return T
function VehicleManager.setVehicleField(vehicle_id, field, value)
	local vehicleData = VehicleManager.getOrCreateVehicle(vehicle_id)
	vehicleData[field] = value
	return value
end

---@param locationName string
---@param transform SWMatrix
---@return integer vehicleId
function VehicleManager.spawnVehicle(locationName, transform)
	local locationIndex = server.getLocationIndex(ADDON_INDEX, locationName)
	local componentData = assert(server.getLocationComponentData(ADDON_INDEX, locationIndex, 0))
	local vehicleId = assert(server.spawnAddonVehicle(transform, ADDON_INDEX, componentData.id))
	return vehicleId
end

--- Static vehicles have extra data stored so they can be reloaded.
---@param system System
---@param locationName string
---@param transform SWMatrix
---@return integer
function VehicleManager.spawnStaticVehicle(system, locationName, transform)
	local locationIndex = server.getLocationIndex(ADDON_INDEX, locationName)
	local componentData = assert(server.getLocationComponentData(ADDON_INDEX, locationIndex, 0))
	local vehicleId = assert(server.spawnAddonVehicle(transform, ADDON_INDEX, componentData.id))
	VehicleManager.data.systemVehicles[vehicleId] = {
		system=system.name,
		locationName=locationName,
		spawnTransform=transform,
	}
	return vehicleId
end

---@overload fun(vehicleId:integer): nil, string
---@param vehicleId integer
---@return integer
function VehicleManager.respawnStaticVehicle(vehicleId)
	local systemVehicleData = VehicleManager.data.systemVehicles[vehicleId]
	if systemVehicleData == nil then
		return nil, ("System vehicle with id '%.0f' not found."):format(vehicleId)
	end
	if not server.despawnVehicle(vehicleId, true) then
		return nil, "Failed to despawn vehicle."
	end
	VehicleManager.data.systemVehicles[vehicleId] = nil
	local locationIndex = server.getLocationIndex(ADDON_INDEX, systemVehicleData.locationName)
	local componentData = assert(server.getLocationComponentData(ADDON_INDEX, locationIndex, 0))
	local newVehicleId = assert(server.spawnAddonVehicle(systemVehicleData.spawnTransform, ADDON_INDEX, componentData.id))
	VehicleManager.data.systemVehicles[newVehicleId] = {
		system=systemVehicleData.system,
		locationName=systemVehicleData.locationName,
		spawnTransform=systemVehicleData.spawnTransform,
	}
	---@diagnostic disable-next-line: missing-return-value # lies
	return newVehicleId
end
