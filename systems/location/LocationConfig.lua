---@class LocationConfigZone
---@field name string
---@field transform SWMatrix
---@field size SWZoneSize
---@field tags table<string, string|boolean>

---@class LocationConfig
---@field name string
---@field production LocationRecipe[]
---@field totalProduction table<string,number>  # per second
---@field storageLimit table<ProducibleConfig,number>
---@field storageTypeLimit table<ProducibleType,number>
---@field locationVehicles table<string,{vehicleName:string,offset:SWMatrix}>
LocationConfig = {}
LocationConfig.DEFAULT_VEHICLES = {}
LocationConfig.ACCESS_TYPE_TAGS = {  -- If adjusting, check note at `Variants.general`
	"station", "dock", "ground", "airstrip", "helipad",
}

---@param name string
---@return LocationConfig
function LocationConfig.new(name)
	return shallowCopy(LocationConfig, {
		name=name,
		production={},
		totalProduction={},
		storageLimit={},
		storageTypeLimit={},
		locationVehicles={},
	})
end

---@param recipe LocationRecipe
function LocationConfig:addProduction(recipe)
	table.insert(self.production, recipe)
	for producibleConfig, amount in pairs(recipe.consumes) do
		self.totalProduction[producibleConfig.name] = (self.totalProduction[producibleConfig.name] or 0) - (amount / recipe.rate)
	end
	for producibleConfig, amount in pairs(recipe.produces) do
		self.totalProduction[producibleConfig.name] = (self.totalProduction[producibleConfig.name] or 0) + (amount / recipe.rate)
	end
	return self
end

---@param producibleName string
---@param amount number? # `nil` to remove limit
function LocationConfig:setStorageProducibleLimit(producibleName, amount)
	local producible = Producibles.get(producibleName)
	if producible == nil then
		log_error(("Attempt to set storage limit of invalid producible '%s'"):format(producibleName))
		return self
	end
	self.storageLimit[producible] = amount
	return self
end

---@param producibleType ProducibleType
---@param amount number? # `nil` to remove limit
function LocationConfig:setStorageTypeLimit(producibleType, amount)
	self.storageTypeLimit[producibleType] = amount
	return self
end

---@param enabled boolean
function LocationConfig:setAllStorageTypeLimit(enabled)
	local value = enabled and 0 or nil
	for _, producibleType in pairs(PRODUCIBLE_TYPES) do
		self.storageTypeLimit[producibleType] = value
	end
	return self
end

---@param id string
---@param vehicleName string
---@param offset SWMatrix
function LocationConfig:setLocationVehicle(id, vehicleName, offset)
	self.locationVehicles[id] = {vehicleName=vehicleName, offset=offset}
	return self
end

function LocationConfig:processZones()
	local zones = server.getZones("ata_location="..self.name)
	if #zones <= 0 then
		return false, "No zones for location."
	end
	self.position = {x=0, y=0, z=0}
	---@type LocationConfigZone[]
	self.areas = {}
	---@type LocationConfigZone[]
	self.interfaces = {}
	---@type LocationConfigZone[]
	self.mineralStations = {}  -- Includes any type of mineral loading/unloading area!
	---@type LocationConfigZone[]
	self.containerAreas = {}
	for _, zone in pairs(zones) do
		local tags = {}
		for _, tag in pairs(zone.tags) do
			local tagName, tagValue = tag:match("ata_([%w_-]+)=?(.*)")
			tags[tagName] = #tagValue > 0 and tagValue or true
		end
		if tags.area then
			table.insert(self.areas, {name=zone.name, transform=zone.transform, size=zone.size, tags=tags})
			self.position.x = self.position.x + zone.transform[13]
			self.position.y = self.position.y + zone.transform[14]
			self.position.z = self.position.z + zone.transform[15]
		elseif tags.interface then
			table.insert(self.interfaces, {name=zone.name, transform=zone.transform, size=zone.size, tags=tags})
		elseif tags.mineral then
			table.insert(self.mineralStations, {name=zone.name, transform=zone.transform, size=zone.size, tags=tags})
		elseif tags.container then
			table.insert(self.containerAreas, {name=zone.name, transform=zone.transform, size=zone.size, tags=tags})
		end
	end
	self.position.x = self.position.x / #self.areas
	self.position.y = self.position.y / #self.areas
	self.position.z = self.position.z / #self.areas
	return true
end

---@param transform SWMatrix
function LocationConfig:isInArea(transform)
	for _, areaZone in pairs(self.areas) do
		if server.isInZone(transform, areaZone.name) then
			return true
		end
	end
	return false
end

function LocationConfig:spawnInterfaces()
	for _, interfaceZone in pairs(self.interfaces) do
		local interfaceType = interfaceZone.tags.interface_type
		---@cast interfaceType InterfaceVariantName
		InterfaceSystem.createInterfaceVehicle(interfaceZone.transform, self, interfaceType)
	end
end

local _ZONE_DEFAULT_HEIGHT = 5
function LocationConfig:spawnVehicles()
	local locationData = LocationSystem.data.locations[self.name]

	for _, zone in pairs(self.mineralStations) do
		local zoneAccessType
		for _, accessType in pairs(LocationConfig.ACCESS_TYPE_TAGS) do
			if zone.tags[accessType] then
				zoneAccessType = accessType
				break
			end
		end
		if zone.tags.mineral_loader_y ~= nil then
			local vehicleInfo = self.locationVehicles[zoneAccessType.."_mineral_load"] or LocationConfig.DEFAULT_VEHICLES[zoneAccessType.."_mineral_load"]
			if vehicleInfo == nil then
				log_warn(("Location '%s' is missing vehicle '%s'"):format(self.name, zoneAccessType.."_mineral_unload"))
			else
				local tagYOffset = tonumber(zone.tags.mineral_loader_y) or 0
				local transfrom = matrix.multiply(matrix.multiply(zone.transform, vehicleInfo.offset), matrix.translation(0, -_ZONE_DEFAULT_HEIGHT + tagYOffset, 0))
				local vehicleId = VehicleManager.spawnStaticVehicle(InterfaceSystem, vehicleInfo.vehicleName, transfrom)
				locationData.vehicles[vehicleId] = {type="loader"}
			end
		end
		if zone.tags.mineral_unloader_y ~= nil then
			local vehicleInfo = self.locationVehicles[zoneAccessType.."_mineral_unload"] or LocationConfig.DEFAULT_VEHICLES[zoneAccessType.."_mineral_unload"]
			if vehicleInfo == nil then
				log_warn(("Location '%s' is missing vehicle '%s'"):format(self.name, zoneAccessType.."_mineral_unload"))
			else
				local tagYOffset = tonumber(zone.tags.mineral_unloader_y) or 0
				local transfrom = matrix.multiply(matrix.multiply(zone.transform, vehicleInfo.offset), matrix.translation(0, -_ZONE_DEFAULT_HEIGHT + tagYOffset, 0))
				local vehicleId = VehicleManager.spawnStaticVehicle(InterfaceSystem, vehicleInfo.vehicleName, transfrom)
				locationData.vehicles[vehicleId] = {type="unloader"}
			end
		end
	end
end
function LocationConfig:despawnVehicles()
	local locationData = LocationSystem.data.locations[self.name]
	for vehicleId, vehicleData in pairs(locationData.vehicles) do
		server.despawnVehicle(vehicleId, true)
		locationData.vehicles[vehicleId] = nil
	end
end
