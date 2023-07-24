---@see SWTankFluidTypeEnum


Producibles
	.register(
		ProducibleConfig.new("diesel", PRODUCIBLE_TYPES.fluid)
			:setFluidType(1)
	)
	.register(
		ProducibleConfig.new("jetfuel", PRODUCIBLE_TYPES.fluid)
			:setFluidType(2)
	)
	.register(
		ProducibleConfig.new("oil", PRODUCIBLE_TYPES.fluid)
			:setFluidType(5)
	)
	.register(
		ProducibleConfig.new("slurry", PRODUCIBLE_TYPES.fluid)
			:setFluidType(8)
	)
	-- .register(
	-- 	ProducibleConfig.new("slurry saturated", PRODUCIBLE_TYPES.fluid)
	-- 		:setFluidType(9)
	-- )
