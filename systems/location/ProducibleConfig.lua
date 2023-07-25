---@enum ProducibleType
PRODUCIBLE_TYPES = {
	fluid="fluid",
	mineral="mineral",
	passenger="passenger",
	vehicle="vehicle",
}
-- Simply provides a way to use numbers instead, primarily for binnet.
PRODUCIBLE_TYPE_INDICES = {
	PRODUCIBLE_TYPES.fluid,
	PRODUCIBLE_TYPES.mineral,
	PRODUCIBLE_TYPES.passenger,
	PRODUCIBLE_TYPES.vehicle,
}

---@class ProducibleConfig
---@field name string
---@field type ProducibleType
---@field passengerVariants {enum:"outfit"|"creature", type:integer}[]
ProducibleConfig = {}

---@param name string
---@param producibleType ProducibleType
---@return ProducibleConfig
function ProducibleConfig.new(name, producibleType)
	local self = shallowCopy(ProducibleConfig, {name=name, type=producibleType})
	if producibleType == "passenger" then
		self.passengerVariants = {}
	end
	return self
end

---@param fluidType integer
function ProducibleConfig:setFluidType(fluidType)
	---@cast fluidType SWTankFluidTypeEnum
	self.fluidType = fluidType
	return self
end

---@param mineralType integer
function ProducibleConfig:setMineralType(mineralType)
	---@cast mineralType SWOreTypeEnum
	self.mineralType = mineralType
	return self
end

---@param passengerEnum "outfit"|"creature"
---@param passengerType integer
function ProducibleConfig:addPassengerVariant(passengerEnum, passengerType)
	---@cast passengerType SWOutfitTypeEnum|SWCreatureTypeEnum
	table.insert(self.passengerVariants, {
		enum=passengerEnum,
		type=passengerType,
	})
	return self
end

---@param vehicleLocationName string
function ProducibleConfig:setVehicleLocationName(vehicleLocationName)
	self.vehicleLocationName = vehicleLocationName
	return self
end
