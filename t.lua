g_savedata = {
	ports = {}
}

local tick = 0

function onCreate(is_world_create)
	if is_world_create then
		spawnAll()
	end
end

function spawnAll()
	local addonIndex = server.getAddonIndex()
	local componentIDS = {}

	for locationIndex = 0, server.getAddonData(addonIndex).location_count - 1 do
		local locationData = server.getLocationData(addonIndex, locationIndex)
		if not locationData.is_env_mod then
			for componentIndex = 0, locationData.component_count - 1 do
				local componentData = server.getLocationComponentData(addonIndex, locationIndex, componentIndex)
				componentIDS[locationData.name] = {id = componentData.id, offset = componentData.transform}
			end
		end
	end

    for name, component in pairs(componentIDS) do
        local spawn_zones = server.getZones(name)
        for _, zone in pairs(spawn_zones) do
			local spawn_transform = matrix.multiply(zone.transform, component.offset)
			local vehicle_id = server.spawnAddonVehicle(spawn_transform, addonIndex, component.id)
			local data = server.getVehicleData(vehicle_id)
			table.insert(g_savedata.ports, {id = vehicle_id, tags = data.tags, transform = data.transform})
        end
    end
end

function onTick(game_ticks)

	tick = tick + 1
	if tick == 60 then tick = 0 end

	for _, port in pairs(g_savedata.ports) do

		if port.id % 60 == tick then

			local is_update = false
			local c, u, d, j = server.getTileInventory(port.transform)

			local tank_data, success = server.getVehicleTank(port.id, "diesel_in")
			if success then
				if tank_data.value > 0 then
					d = d + tank_data.value
					server.setVehicleTank(port.id, "diesel_in", 0, 0)
					is_update = true
				end
			end
			local tank_data2, success2 = server.getVehicleTank(port.id, "jet_in")
			if success2 then
				if tank_data2.value > 0 then
					j = j + tank_data2.value
					server.setVehicleTank(port.id, "jet_in", 0, 0)
					is_update = true
				end
			end

			local tank_data, success = server.getVehicleTank(port.id, "diesel_out")
			if success then
				if tank_data.value < tank_data.capacity then
					local delta = tank_data.capacity - tank_data.value
					delta = math.min(delta, d)
					if delta > 0 then
						d = d - delta
						server.setVehicleTank(port.id, "diesel_out", tank_data.value + delta, tank_data.fluid_type)
						is_update = true
					end
				end
			end
			local tank_data2, success2 = server.getVehicleTank(port.id, "jet_out")
			if success2 then
				if tank_data2.value < tank_data2.capacity then
					local delta = tank_data2.capacity - tank_data2.value
					delta = math.min(delta, j)
					if delta > 0 then
						j = j - delta
						server.setVehicleTank(port.id, "jet_out", tank_data2.value + delta, tank_data2.fluid_type)
						is_update = true
					end
				end
			end

			local hopper_data, success3 = server.getVehicleHopper(port.id, "minerals_in")
			if success3 then
				if hopper_data.values[0] > 0 then
					c = c + hopper_data.values[0]
					server.setVehicleHopper(port.id, "minerals_in", 0, 0)
					is_update = true
				end
				if hopper_data.values[11] > 0 then
					u = u + hopper_data.values[11]
					server.setVehicleHopper(port.id, "minerals_in", 0, 11)
					is_update = true
				end
			end

			server.setVehicleKeypad(port.id, "diesel_level", d)
			server.setVehicleKeypad(port.id, "jet_level", j)

			if is_update then
				server.setTileInventory(port.transform, c, u, d, j)
			end
		end
	end
end
