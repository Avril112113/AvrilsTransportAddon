-- NOTE: This file must be ordered after `packets.lua` (which is based on file name)
-- Packet ids 20+ are free to use for interface variant specific data.

---@alias InterfaceVariantName "general"|"pump"|"mineral"


---@class InterfaceVariant
---@field vehicleName string
---@field offset SWMatrix
---@field range number
---@field binnetReadChannels integer
---@field binnetWriteChannels integer
---@field binnetBase Binnet
---@field setup nil|fun(self, vehicleId:integer, interface:LoadedInterface)
---@field update nil|fun(self, vehicleId:integer, interface:LoadedInterface)


---@type InterfaceVariant
InterfaceSystem.interfaceVariants.general = {
	vehicleName="vehicle_interface",
	offset=matrix.translation(0, -1.25, 0),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=9,
	binnetBase=InterfaceSystem.BinnetBase:new(),
}

---@type InterfaceVariant
InterfaceSystem.interfaceVariants.pump = {
	vehicleName="vehicle_pump",
	offset=matrix.translation(0, -0.5, 0),
	range=15,
	binnetReadChannels=3,
	binnetWriteChannels=3,
	binnetBase=InterfaceSystem.BinnetBase:new(),
}

