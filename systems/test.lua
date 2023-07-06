---@class TestSystem : System
TestSystem = {name="TestSystem"}


--- @param vehicle_id number The vehicle ID of the vehicle that was spawned.
--- @param player Player?
--- @param x number The x coordinate of the vehicle's spawn location relative to world space.
--- @param y number The y coordinate of the vehicle's spawn location relative to world space.
--- @param z number The z coordinate of the vehicle's spawn location relative to world space.
--- @param cost number The cost of the vehicle. Only calculated for player spawned vehicles.
function TestSystem.onVehicleSpawn(vehicle_id, player, x, y, z, cost)
	if player ~= nil then
		log_info(("Player %s spawned vehicle with id %s"):format(player.name, vehicle_id))
	end
end


SystemManager.registerSystem(TestSystem)
