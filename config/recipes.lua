--- Predefined recipes.
RecipeDatabase = {}

-- Default rate is per hour.
-- Default bulk is true, set to false to produce every tick using whatever is available.
---@see RecipeData.new

RecipeDatabase.chemical_plant_t1 =
	RecipeData.new("chemical_plant")
		:setBulk(false)
		:setConsumption("oil", 1000)
		:setProduction("diesel", 400)
		:setProduction("jetfuel", 100)
		-- :setBulk(true)
		-- :setRate(10)
		-- :setConsumption("oil", 10)
		-- :setProduction("diesel", 4)
		-- :setProduction("jetfuel", 1)
