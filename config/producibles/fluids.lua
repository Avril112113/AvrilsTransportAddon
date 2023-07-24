---@see SWTankFluidTypeEnum


LocationSystem
	.addProducible(
		ProducibleConfig.new("diesel", PRODUCIBLE_TYPES.fluid)
			:setFluidType(1)
	)
	.addProducible(
		ProducibleConfig.new("jetfuel", PRODUCIBLE_TYPES.fluid)
			:setFluidType(2)
	)
	.addProducible(
		ProducibleConfig.new("oil", PRODUCIBLE_TYPES.fluid)
			:setFluidType(5)
	)
	.addProducible(
		ProducibleConfig.new("slurry", PRODUCIBLE_TYPES.fluid)
			:setFluidType(8)
	)
	-- .addProducible(
	-- 	ProducibleConfig.new("slurry saturated", PRODUCIBLE_TYPES.fluid)
	-- 		:setFluidType(9)
	-- )
