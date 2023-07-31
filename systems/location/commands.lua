---@overload fun(ctx:CommandCtx, locationName:string?): nil, string
---@param ctx CommandCtx
---@param locationName string?
---@return LocationConfig
local function getLocationOrNearby(ctx, locationName)
	local locationConfig
	if locationName == nil then
		local locationDist
		locationConfig, locationDist = LocationSystem.getClosestLocation(server.getPlayerPos(ctx.player.peer_id))
		if locationConfig == nil or locationDist > 500 then
			return nil, "You are not close to a location, please specify one."
		end
	else
		locationConfig = LocationSystem.locations[locationName]
		if locationConfig == nil then
			return nil, ("Invalid location '%s'"):format(locationName)
		end
	end
	return locationConfig
end


Command.new("location")
	:setHelpHandler()
	:register()
	:addSubcommand(
		Command.new("respawn")
			:setPermission("admin")
			:setHandler({}, function(self, ctx, ...)
				LocationSystem.despawnVehicles()
				LocationSystem.despawnInterfaces()
				LocationSystem.spawnVehicles()
				LocationSystem.spawnInterfaces()
				return 0, "All location buildings have been respawned."
			end)
	)
	:addSubcommand(
		Command.new("map")
			:setPermission("admin")
			:setHelpHandler()
			:addSubcommand(
				Command.new("all")
					:setDesc("Sets if all map info should be shown or not.")
					:setHandler({"enabled:boolean"}, function(self, ctx, enabled)
						LocationSystem.data.map.shown = enabled
						LocationSystem.data.map.production = enabled
						LocationSystem.data.map.storage = enabled
						LocationSystem.syncMap()
						return 0, LocationSystem.data.map.shown and "Locations and details are now shown on the map." or "Locations and details are no longer shown on map."
					end)
			)
			:addSubcommand(
				Command.new("show")
					:setDesc("Toggles weather or not locations are shown on map.")
					:setHandler({}, function(self, ctx)
						LocationSystem.data.map.shown = not LocationSystem.data.map.shown
						LocationSystem.syncMap()
						return 0, LocationSystem.data.map.shown and "Locations are now shown on map." or "Locations are no longer shown on map."
					end)
			)
			:addSubcommand(
				Command.new("production")
					:setDesc("Toggles weather or not location production & consumption are shown on map.")
					:setHandler({}, function(self, ctx)
						LocationSystem.data.map.production = not LocationSystem.data.map.production
						LocationSystem.syncMap()
						return 0, LocationSystem.data.map.production and "Location production is now shown on map." or "Location production is no longer shown on map."
					end)
			)
			:addSubcommand(
				Command.new("storage")
					:setDesc("Toggles weather or not location storage is shown on map.")
					:setHandler({}, function(self, ctx)
						LocationSystem.data.map.storage = not LocationSystem.data.map.storage
						LocationSystem.syncMap()
						return 0, LocationSystem.data.map.storage and "Location storage is now shown on map." or "Location storage is no longer shown on map."
					end)
			)
	)
	:addSubcommand(
		Command.new("storage")
			:setPermission("admin")
			:setHandler({"location:string?"}, function(self, ctx, locationName)
				local locationConfig, err = getLocationOrNearby(ctx, locationName)
				if locationConfig == nil then
					return -1, err
				end
				local lines = {("Storage for %s:"):format(locationConfig.name)}
				for producibleName, amount in pairs(LocationSystem.storageAll(locationConfig)) do
					table.insert(lines, ("- %s: %.02f"):format(producibleName, amount))
				end
				return 0, table.concat(lines, "\n")
			end)
			:addSubcommand(
				Command.new("add")
					:setDesc("Adds/removes resources from a location's storage.")
					:setHandler({"producible:string", "amount:number", "location:string?"}, function(self, ctx, producibleName, amount, locationName)
						local producibleConfig = Producibles.byName[producibleName]
						if producibleConfig == nil then
							return -1, ("Invalid producible '%s'"):format(producibleName)
						end
						local locationConfig, err = getLocationOrNearby(ctx, locationName)
						if locationConfig == nil then
							return -1, err
						end
						LocationSystem.storageAdd(locationConfig, producibleConfig, amount, "force")
						return 0, ("%s now has %g (%+.2f) of '%s'"):format(locationConfig.name, round(LocationSystem.storageGet(locationConfig, producibleConfig), 1), amount, producibleConfig.name)
					end)
			)
			:addSubcommand(
				Command.new("set")
					:setDesc("Sets resources in a location's storage.")
					:setHandler({"producible:string", "amount:number", "location:string?"}, function(self, ctx, producibleName, amount, locationName)
						local producibleConfig = Producibles.byName[producibleName]
						if producibleConfig == nil then
							return -1, ("Invalid producible '%s'"):format(producibleName)
						end
						local locationConfig, err = getLocationOrNearby(ctx, locationName)
						if locationConfig == nil then
							return -1, err
						end
						LocationSystem.storageSet(locationConfig, producibleConfig, amount, "force")
						return 0, ("%s now has %g of '%s'"):format(locationConfig.name, round(LocationSystem.storageGet(locationConfig, producibleConfig), 1), producibleConfig.name)
					end)
			)
			:addSubcommand(
				Command.new("reset")
					:setDesc("Clears all resources in storage.")
					:setHandler({"location:string?"}, function(self, ctx, locationName)
						local locationConfig, err = getLocationOrNearby(ctx, locationName)
						if locationConfig == nil then
							return -1, err
						end
						local storage = LocationSystem.storageAll(locationConfig)
						for producibleName, amount in pairs(storage) do
							LocationSystem.storageSet(locationConfig, Producibles.get(producibleName), 0, "force")
						end
						return 0, ("%s storage has been cleared."):format(locationConfig.name)
					end)
			)
	)
