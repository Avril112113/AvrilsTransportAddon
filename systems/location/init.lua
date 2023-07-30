local RESOURCE_UPDATE_RATE = 60  -- In ticks


---@class LocationSystem : System
LocationSystem = {name="LocationSystem"}
---@type table<string, LocationConfig>
LocationSystem.locations = {}
LocationSystem.mapId = server.getMapID()


SystemManager.addEventHandler(LocationSystem, "onCreate", 100,
	function(is_world_create)
		LocationSystem.data = SystemManager.getSaveData(LocationSystem)
		if LocationSystem.data.map == nil then
			LocationSystem.data.map = {shown=false, production=false, storage=false}
		end
		if LocationSystem.data.locations == nil then
			---@type table<string,LocationData>
			LocationSystem.data.locations = {}
		end
		for locationName, locationConfig in pairs(LocationSystem.locations) do
			---@class LocationData
			local locationData = LocationSystem.data.locations[locationName]
			if locationData == nil then
				locationData = {}
				LocationSystem.data.locations[locationName] = locationData
			end
			if locationData.storage == nil then
				---@type table<string, number>
				locationData.storage = {}
			end
			for _, recipe in ipairs(locationConfig.production) do
				for producible, amount in pairs(recipe.consumes) do
					if locationData.storage[producible.name] == nil then
						locationData.storage[producible.name] = 0
					end
				end
				for producible, amount in pairs(recipe.produces) do
					if locationData.storage[producible.name] == nil then
						locationData.storage[producible.name] = 0
					end
				end
			end
			if locationData.productionTicks == nil then
				---@type table<string, integer>
				locationData.productionTicks = {}
			end
			if locationData.vehicles == nil then
				---@type table<integer, {type:string,[any]:any}>
				locationData.vehicles = {}
			end
		end

		for name, locationConfig in pairs(LocationSystem.locations) do
			local ok, msg = locationConfig:processZones()
			if not ok then
				log_error(("Failed to process location '%s': %s"):format(locationConfig.name, msg))
				LocationSystem.locations[name] = nil
			end
		end

		if is_world_create then
			LocationSystem.spawnVehicles()
			LocationSystem.spawnInterfaces()
		end

		LocationSystem.syncMap()
	end
)

SystemManager.addEventHandler(LocationSystem, "onDestroy", 100,
	function()
		server.removeMapID(-1, LocationSystem.mapId)
	end
)

SystemManager.addEventHandler(LocationSystem, "onTick", 100,
	function(game_ticks)
		local pendingUpdateTicks = LocationSystem.data.pendingUpdateTicks or 0
		pendingUpdateTicks = pendingUpdateTicks + game_ticks
		if TickManager.sessionTick % RESOURCE_UPDATE_RATE == 0 then
			LocationSystem.updateProduction(pendingUpdateTicks)
			pendingUpdateTicks = 0
		end
		LocationSystem.data.pendingUpdateTicks = pendingUpdateTicks

		if TickManager.sessionTick % 60 == 0 then
			for _, player in pairs(PlayerManager.getWithMapOpen()) do
				LocationSystem.syncMap(player)
			end
		end
	end
)

SystemManager.addEventHandler(LocationSystem, "onPlayerJoin", 100,
	function(player)
		LocationSystem.syncMap(player)
	end
)

SystemManager.addEventHandler(LocationSystem, "onToggleMap", 100,
	function(player, is_open)
		if is_open then
			LocationSystem.syncMap(player)
		end
	end
)


---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@return number remainder
function LocationSystem.storageGet(locationConfig, producibleConfig)
	local locationData = LocationSystem.data.locations[locationConfig.name]
	local storage = locationData.storage
	return storage[producibleConfig.name] or 0
end

---@param locationConfig LocationConfig
---@return table<string, number>
function LocationSystem.storageAll(locationConfig)
	return LocationSystem.data.locations[locationConfig.name].storage
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@return number
function LocationSystem.storageLimitFor(locationConfig, producibleConfig)
	return locationConfig.storageLimit[producibleConfig] or locationConfig.storageTypeLimit[producibleConfig.type] or math.huge
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@return number
function LocationSystem.storageFreeSpaceFor(locationConfig, producibleConfig)
	local storage = LocationSystem.storageAll(locationConfig)
	local limit = LocationSystem.storageLimitFor(locationConfig, producibleConfig)
	return math.min(math.max(limit-(storage[producibleConfig.name] or 0), 0), limit)
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@param amount number
---@param mode "full"|"partial"|"force"
---@return number remainder # Amount left over that wasn't able to be added.
function LocationSystem.storageAdd(locationConfig, producibleConfig, amount, mode)
	local freeSpace = mode == "force" and math.huge or LocationSystem.storageFreeSpaceFor(locationConfig, producibleConfig)
	local storage = LocationSystem.storageAll(locationConfig)

	local transfer = math.min(freeSpace, amount)
	if mode == "full" and amount ~= transfer then
		return amount
	end
	storage[producibleConfig.name] = (storage[producibleConfig.name] or 0) + transfer
	LocationSystem._storageCheckSetNil(locationConfig, producibleConfig)
	return amount-transfer
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@param amount number
---@param mode "full"|"partial"|"force"
---@return number amount # The amount that was removed.
function LocationSystem.storageRemove(locationConfig, producibleConfig, amount, mode)
	local storage = LocationSystem.storageAll(locationConfig)
	local transfer = mode == "force" and amount or math.min(amount, storage[producibleConfig.name] or 0)
	if transfer == 0 or (mode == "full" and transfer ~= amount) then
		return 0
	end
	storage[producibleConfig.name] = (storage[producibleConfig.name] or 0) - transfer
	LocationSystem._storageCheckSetNil(locationConfig, producibleConfig)
	return transfer
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@param amount number
---@param mode "full"|"partial"|"force"
---@return number remainder # Amount left over that wasn't able to be added.
function LocationSystem.storageSet(locationConfig, producibleConfig, amount, mode)
	local storage = LocationSystem.storageAll(locationConfig)
	local setAmount = mode == "force" and amount or math.min(amount, LocationSystem.storageLimitFor(locationConfig, producibleConfig))
	if mode == "full" and amount ~= setAmount then
		return 0
	end
	storage[producibleConfig.name] = setAmount
	LocationSystem._storageCheckSetNil(locationConfig, producibleConfig)
	return amount-setAmount
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
function LocationSystem._storageCheckSetNil(locationConfig, producibleConfig)
	local storage = LocationSystem.storageAll(locationConfig)
	if storage[producibleConfig.name] == 0 and locationConfig.totalProduction[producibleConfig.name] == nil then
		storage[producibleConfig.name] = nil
	end
end

---@param pendingUpdateTicks integer
function LocationSystem.updateProduction(pendingUpdateTicks)
	for locationName, locationConfig in pairs(LocationSystem.locations) do
		-- log_debug(("Updating production at %s"):format(locationConfig.name))
		local locationData = LocationSystem.data.locations[locationName]
		local storage = locationData.storage
		local productionTicks = locationData.productionTicks  -- Time since last production
		for _, recipe in ipairs(locationConfig.production) do
			local maxTimeProduceCount
			if recipe.bulk then
				productionTicks[recipe.name] = (productionTicks[recipe.name] or 0) + pendingUpdateTicks
				maxTimeProduceCount = productionTicks[recipe.name] >= (recipe.rate/DT) and 1 or 0
			else
				maxTimeProduceCount = pendingUpdateTicks/(recipe.rate/DT)
			end
			if maxTimeProduceCount > 0 then
				local maxResourceProduceCount = math.huge
				for producible, amount in pairs(recipe.consumes) do
					if storage[producible.name] and storage[producible.name] > 0 then
						maxResourceProduceCount = math.min(maxResourceProduceCount, storage[producible.name]/amount)
					else
						maxResourceProduceCount = 0
						break
					end
				end
				if maxResourceProduceCount > 0 then
					for producible, amount in pairs(recipe.produces) do
						local freeSpace = LocationSystem.storageFreeSpaceFor(locationConfig, ProducibleConfig)
						if freeSpace > 0 then
							maxResourceProduceCount = math.min(maxResourceProduceCount, freeSpace/amount)
						else
							maxResourceProduceCount = 0
							break
						end
					end
				end
				local produceCount = math.min(maxTimeProduceCount, maxResourceProduceCount)
				if recipe.bulk then
					produceCount = math.floor(produceCount)
				end
				if produceCount > 0 then
					if recipe.bulk then
						productionTicks[recipe.name] = nil
					end
					-- log_debug(("- Recipe %s"):format(recipe.name))
					for producibleConfig, amount in pairs(recipe.consumes) do
						LocationSystem.storageRemove(locationConfig, producibleConfig, amount*produceCount, "force")
						-- log_debug(("- - Consumed %s of %s"):format(amount*produceCount, producibleConfig.name))
					end
					for producibleConfig, amount in pairs(recipe.produces) do
						LocationSystem.storageAdd(locationConfig, producibleConfig, amount*produceCount, "force")
						-- log_debug(("- - Produced %s of %s"):format(amount*produceCount, producibleConfig.name))
					end
				end
			end
		end
	end
end

---@param player Player?
function LocationSystem.syncMap(player)
	local peerId = player and player.peer_id or -1
	server.removeMapObject(peerId, LocationSystem.mapId)
	if LocationSystem.data.map.shown then
		for locationName, locationConfig in pairs(LocationSystem.locations) do
			local locationData = LocationSystem.data.locations[locationName]
			local hoverLines = {}

			---@type table<string, true>
			local produciblesOrdered = {}
			---@type string[]
			local produciblesList = {}
			local function listProducible(producibleName)
				if not produciblesOrdered[producibleName] then
					table.insert(produciblesList, producibleName)
					produciblesOrdered[producibleName] = true
				end
			end

			---@type table<string, number>
			if LocationSystem.data.map.production then
				for _, recipe in pairs(locationConfig.production) do
					for producibleConfig, amount in pairs(recipe.consumes) do
						listProducible(producibleConfig.name)
					end
					for producibleConfig, amount in pairs(recipe.produces) do
						listProducible(producibleConfig.name)
					end
				end
			end
			if LocationSystem.data.map.storage then
				for producibleName, _ in pairs(locationData.storage) do
					listProducible(producibleName)
				end
			end

			for _, producibleName in ipairs(produciblesList) do
				local detail
				if LocationSystem.data.map.storage then
					detail = ("%g"):format(round(locationData.storage[producibleName], 1))
				end
				local delta = locationConfig.totalProduction[producibleName]
				if LocationSystem.data.map.production and delta then
					if detail then
						detail = detail .. (" (%+g/h)"):format(round(delta * 60 * 60, 1))
					else
						detail = ("%+g/h"):format(round(delta * 60 * 60, 1))
					end
				end
				table.insert(hoverLines, ("%s: %s"):format(producibleName, detail))
			end

			if LocationSystem.data.map.production then
				for _, recipe in pairs(locationConfig.production) do
					table.insert(hoverLines, (recipe.name:gsub("_", " ")))
				end
			end

			server.addMapObject(
				peerId, LocationSystem.mapId,
				0, 0,
				locationConfig.position.x, locationConfig.position.z,
				0, 0,
				0, 0,
				locationName, 0, table.concat(hoverLines, "\n"),
				255, 197, 132, 127
			)
		end
	end
end

---@param locationConfig LocationConfig
function LocationSystem.addLocation(locationConfig)
	LocationSystem.locations[locationConfig.name] = locationConfig
	return LocationSystem
end

function LocationSystem.spawnInterfaces()
	for _, locationConfig in pairs(LocationSystem.locations) do
		locationConfig:spawnInterfaces()
	end
end
function LocationSystem.despawnInterfaces()
	InterfaceSystem.despawnAllInterfaces()
end

function LocationSystem.spawnVehicles()
	for _, locationConfig in pairs(LocationSystem.locations) do
		locationConfig:spawnVehicles()
	end
end
function LocationSystem.despawnVehicles()
	for _, locationConfig in pairs(LocationSystem.locations) do
		locationConfig:despawnVehicles()
	end
end

---@param transform SWMatrix
---@return LocationConfig, number
function LocationSystem.getClosestLocation(transform)
	local closestLocation
	local closestDist = math.maxinteger
	for _, locationConfig in pairs(LocationSystem.locations) do
		local dist = matrix.distance(transform, matrix.translation(locationConfig.position.x, locationConfig.position.y, locationConfig.position.z))
		if dist < closestDist then
			closestLocation = locationConfig
			closestDist = dist
		end
	end
	return closestLocation, closestDist
end


---@require_folder systems/location
require("systems.location.commands")
require("systems.location.LocationConfig")
require("systems.location.LocationRecipe")
require("systems.location.ProducibleConfig")
require("systems.location.Producibles")
---@require_folder_finish

require("config.recipes")
require("config.locationDefaultVehicles")
require("config.locations")
