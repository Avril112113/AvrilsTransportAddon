---@class TestSystem : System
TestSystem = {name="TestSystem"}


SystemManager.addEventHandler(TestSystem, "onVehicleSpawn", 100,
	function(vehicle_id, player, x, y, z, cost)
		if player ~= nil then
			log_info(("Player %s spawned vehicle with id %s"):format(player.name, vehicle_id))
		end
	end
)
