---@class LocationRecipe
---@field name string
---@field rate number  -- In seconds
---@field bulk boolean  -- If true, the recipe will should wait until all requirements are met before producing. Otherwise produce based on available input.
---@field consumes table<ProducibleConfig,number>
---@field produces table<ProducibleConfig,number>
RecipeData = {}

---@param name string
---@return LocationRecipe
function RecipeData.new(name)
	local self = shallowCopy(RecipeData, {
		name=name,
		rate=60/DT,
		bulk=true,
		consumes={},
		produces={},
	})
	return self
end

---@param seconds number # In seconds
function RecipeData:setRate(seconds)
	self.rate = seconds
	return self
end

--- If true, the recipe will should wait until all requirements are met before producing.
--- Otherwise produce based on available input.
---@param bulk boolean
function RecipeData:setBulk(bulk)
	self.bulk = bulk
	return self
end

---@param producibleName string
---@param amount number
function RecipeData:setConsumption(producibleName, amount)
	local producible = LocationSystem.producibles[producibleName]
	if producible == nil then
		log_error(("Attempt to set consumption of invalid producible '%s'"):format(producibleName))
		return self
	end
	self.consumes[producible] = amount
	return self
end

---@param producibleName string
---@param amount number
function RecipeData:setProduction(producibleName, amount)
	local producible = LocationSystem.producibles[producibleName]
	if producible == nil then
		log_error(("Attempt to set consumption of invalid producible '%s'"):format(producibleName))
		return self
	end
	self.produces[producible] = amount
	return self
end
