---@class TestSystem : System
TestSystem = {name="TestSystem"}


SystemManager.addEventHandler(TestSystem, "onVehicleSpawn", 100,
	function(vehicle_id, player, x, y, z, cost)
		if player ~= nil then
			log_info(("Player %s spawned vehicle with id %s"):format(player.name, vehicle_id))
		end
	end
)


Command.new("test")
	:setPermission("admin")
	:register()
	:setHandler({"vehicle_id:integer"}, function (self, ctx, vehicle_id)
		local data, ok = server.getVehicleHopper(vehicle_id, "mineral_unload")
		if data == nil or not ok then
			return -1
		end
		---@type table<integer, ProducibleConfig>
		local oreTypeToProducible = {}
		for _, producibleConfig in pairs(Producibles.byName) do
			if producibleConfig.mineralType then
				oreTypeToProducible[producibleConfig.mineralType] = producibleConfig
			end
		end
		local lines = {("Capacity: %s"):format(data.capacity)}
		for oreType, value in pairs(data.values) do
			local producibleConfig = oreTypeToProducible[oreType]
			table.insert(lines, ("%s %s"):format(producibleConfig and producibleConfig.name or oreType, value))
		end
		return 0, table.concat(lines, "\n")
	end)
