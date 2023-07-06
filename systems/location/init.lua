local RESOURCE_UPDATE_RATE = 60  -- In ticks


---@class LocationSystem : System
LocationSystem = {name="LocationSystem"}
---@type table<string, LocationConfig>
LocationSystem.locations = {}
---@type table<string, ProducibleConfig>
LocationSystem.producibles = {}
LocationSystem.mapId = server.getMapID()


---@param is_world_create boolean Only returns true when the world is first created.
function LocationSystem.onCreate(is_world_create)
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
	end

	for name, locationConfig in pairs(LocationSystem.locations) do
		local ok, msg = locationConfig:processZones()
		if not ok then
			log_error(("Failed to process location '%s': %s"):format(locationConfig.name, msg))
			LocationSystem.locations[name] = nil
		end
	end

	if is_world_create then
		LocationSystem.spawnInterfaces()
	end

	LocationSystem.syncMap()
end

function LocationSystem.onDestroy()
	server.removeMapID(-1, LocationSystem.mapId)
end

local tick = 0
---@param game_ticks number the number of ticks since the last onTick call (normally 1, while sleeping 400.)
function LocationSystem.onTick(game_ticks)
	tick = tick + 1
	local pendingUpdateTicks = LocationSystem.data.pendingUpdateTicks or 0
	pendingUpdateTicks = pendingUpdateTicks + game_ticks
	if tick % RESOURCE_UPDATE_RATE == 0 then
		LocationSystem.updateProduction(pendingUpdateTicks)
		pendingUpdateTicks = 0
	end
	LocationSystem.data.pendingUpdateTicks = pendingUpdateTicks
end

---@param player Player
function LocationSystem.onPlayerJoin(player)
	LocationSystem.syncMap(player)
end


---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@return number
function LocationSystem.storageFreeSpaceFor(locationConfig, producibleConfig)
	local locationData = LocationSystem.data.locations[locationConfig.name]
	local storage = locationData.storage
	local limit = locationConfig.storageLimit[producibleConfig] or locationConfig.storageTypeLimit[producibleConfig.type]
	if limit == nil then
		return math.huge
	end
	return math.min(math.max(limit-storage[producibleConfig.name], 0), limit)
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@param amount number
---@param mode "full"|"partial"|"force"
---@return number remainder
function LocationSystem.storageAdd(locationConfig, producibleConfig, amount, mode)
	local freeSpace = mode == "force" and math.huge or LocationSystem.storageFreeSpaceFor(locationConfig, producibleConfig)
	local locationData = LocationSystem.data.locations[locationConfig.name]
	local storage = locationData.storage

	local transfer = math.min(freeSpace, amount)
	if mode == "full" and amount ~= transfer then
		return amount
	end
	storage[producibleConfig.name] = (storage[producibleConfig.name] or 0) + transfer
	local remainder = amount-transfer
	return remainder
end

---@param locationConfig LocationConfig
---@param producibleConfig ProducibleConfig
---@param amount number
---@param mode "full"|"partial"|"force"
---@return number amount
function LocationSystem.storageRemove(locationConfig, producibleConfig, amount, mode)
	local locationData = LocationSystem.data.locations[locationConfig.name]

	local storage = locationData.storage
	local transfer = mode == "force" and amount or math.min(amount, storage[producibleConfig.name] or 0)
	if transfer == 0 or (mode == "full" and transfer ~= amount) then
		return 0
	end
	storage[producibleConfig.name] = (storage[producibleConfig.name] or 0) - transfer
	return transfer
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
						LocationSystem.storageAdd(locationConfig, producibleConfig, amount*produceCount, "force")
						-- storage[producibleConfig.name] = storage[producibleConfig.name] - amount*produceCount
						-- log_debug(("- - Consumed %s of %s"):format(amount*produceCount, producibleConfig.name))
					end
					for producibleConfig, amount in pairs(recipe.produces) do
						LocationSystem.storageRemove(locationConfig, producibleConfig, amount*produceCount, "force")
						-- storage[producibleConfig.name] = (storage[producibleConfig.name] or 0) + amount*produceCount
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
			local productionDeltas = {}  -- per hour
			if LocationSystem.data.map.production then
				for _, recipe in pairs(locationConfig.production) do
					for producibleConfig, amount in pairs(recipe.consumes) do
						local amountPerHour = (amount / recipe.rate) * 60 * 60
						productionDeltas[producibleConfig.name] = (productionDeltas[producibleConfig.name] or 0) - amountPerHour
						listProducible(producibleConfig.name)
					end
					for producibleConfig, amount in pairs(recipe.produces) do
						local amountPerHour = (amount / recipe.rate) * 60 * 60
						productionDeltas[producibleConfig.name] = (productionDeltas[producibleConfig.name] or 0) + amountPerHour
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
				local delta = productionDeltas[producibleName]
				if LocationSystem.data.map.production and delta then
					if detail then
						detail = detail .. (" (%+g/h)"):format(round(delta, 1))
					else
						detail = ("%+g/h"):format(round(delta, 1))
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

---@param producibleConfig ProducibleConfig
function LocationSystem.addProducible(producibleConfig)
	LocationSystem.producibles[producibleConfig.name] = producibleConfig
	return LocationSystem
end

---@param locationConfig LocationConfig
function LocationSystem.addLocation(locationConfig)
	LocationSystem.locations[locationConfig.name] = locationConfig
	return LocationSystem
end

function LocationSystem.spawnInterfaces()
	for _, locationConfig in pairs(LocationSystem.locations) do
		locationConfig:createInterfaces()
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



SystemManager.registerSystem(LocationSystem)

---@require_folder systems/location
require("systems.location.commands")
require("systems.location.LocationConfig")
require("systems.location.LocationRecipe")
require("systems.location.ProducibleConfig")
---@require_folder_finish

require("config.recipes")
require("config.locations")
