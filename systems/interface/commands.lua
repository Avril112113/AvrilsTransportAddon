Command.new("interface")
	:setHelpHandler()
	:register()
	:addSubcommand(
		Command.new("vdev")
			:setPermission("admin")
			:setHandler({}, function(self, ctx)
				InterfaceSystem.vehicleDevMode = not InterfaceSystem.vehicleDevMode
				return 0, InterfaceSystem.vehicleDevMode and "Interface dev mode on." or "Interface dev mode off."
			end)
	)
	:addSubcommand(
		Command.new("fix")
			:setHandler({}, function(self, ctx)
				local foundInterface = false
				local playerPos = server.getPlayerPos(ctx.player.peer_id)
				for vehicleId, interface in pairs(InterfaceSystem.loadedInterfaces) do
					local vehiclePos = server.getVehiclePos(vehicleId, 0, 0, 0)
					if matrix.distance(playerPos, vehiclePos) <= 15 then
						InterfaceSystem.respawnInterfaceVehicle(vehicleId)
						foundInterface = true
					end
				end
				return 0, foundInterface and "Respawned interface." or "Unable to find interface with 15 meters."
			end)
	)
