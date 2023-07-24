Producibles = {}
Producibles.byName = {}
Producibles.ofType = {}
Producibles.enums = {fluid={}, mineral={}}


---@param producibleConfig ProducibleConfig
function Producibles.register(producibleConfig)
	Producibles.byName[producibleConfig.name] = producibleConfig
	Producibles.ofType[producibleConfig.type] = Producibles.ofType[producibleConfig.type] or {}
	table.insert(Producibles.ofType[producibleConfig.type], producibleConfig)
	if producibleConfig.fluidType ~= nil then
		Producibles.enums.fluid[producibleConfig.fluidType] = producibleConfig
	end
	if producibleConfig.mineralType ~= nil then
		Producibles.enums.mineral[producibleConfig.mineralType] = producibleConfig
	end
	return Producibles
end

---@param producibleName string
---@return ProducibleConfig
function Producibles.get(producibleName)
	local producibleConfig = Producibles.byName[producibleName]
	if producibleConfig == nil then
		log_error(("Producible '%s' does not exist."):format(producibleName))
		error(("Producible '%s' does not exist."):format(producibleName))
	end
	return producibleConfig
end

---@param producibleType ProducibleType
---@return ProducibleConfig[]
function Producibles.getAllOfType(producibleType)
	return Producibles.ofType[producibleType] or {}
end

---@param enumType "fluid"|"mineral"
---@param enumValue integer
---@return ProducibleConfig
function Producibles.getByEnum(enumType, enumValue)
	local producibleConfig = Producibles.enums[enumType][enumValue]
	if producibleConfig == nil then
		log_error(("Producible by SW enum %s[%.0f] does not exist."):format(enumType, enumValue))
		error(("Producible by SW enum %s[%.0f] does not exist."):format(enumType, enumValue))
	end
	return producibleConfig
end


---@require_folder config/producibles
require("config.producibles.fluids")
require("config.producibles.manufactured")
require("config.producibles.minerals")
require("config.producibles.passengers")
---@require_folder_finish
