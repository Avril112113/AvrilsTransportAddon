---@class System
---@field name string
-- -@field onCreate nil|fun(is_world_create:boolean)
-- -@field onDestroy nil|fun()
-- -@field onTick nil|fun(game_ticks:number)
-- -@field onCustomCommand nil|fun(full_message:string, peer_id:integer, is_admin:boolean, is_auth:boolean, command:string, ...: string)
-- -@field onChatMessage nil|fun(peer_id:integer, sender_name:string, message:string)
-- -@field onPlayerJoin nil|fun(steam_id:integer, name:string, peer_id:integer, is_admin:boolean, is_auth:boolean)
-- -@field onPlayerLeave nil|fun(steam_id:integer, name:string, peer_id:integer, is_admin:boolean, is_auth:boolean)


SystemManager = {
	BASE_GAME_EVENTS = {
		"onCreate", "onDestroy",
		"onTick",
		"onCustomCommand", "onChatMessage",

		"onPlayerJoin", "onPlayerLeave",
		"onPlayerSit", "onPlayerUnsit",
		"onPlayerDie", "onPlayerRespawn",

		"onCharacterSit", "onCharacterUnsit",
		"onCharacterPickup",

		"onEquipmentPickup", "onEquipmentDrop",
		"onVehicleSpawn", "onVehicleDespawn",
		"onVehicleLoad", "onVehicleUnload",
		"onVehicleTeleport",
		"onVehicleDamaged",
		"onButtonPress",

		"onObjectLoad", "onObjectUnload",

		"onFireExtinguished",
		"onForestFireSpawned", "onForestFireExtinguised",

		"onTornado", "onMeteor", "onTsunami", "onWhirlpool", "onVolcano",

		"onToggleMap",
		"httpReply",
		"onSpawnAddonComponent",

		-- Some are missing that LifeBoatAPI doesn't have documented.
	},
	eventTransformers = {},
	systems = {},
}

local SYSTEM_EVENT_CTX_NAME = "system:event"
---@param eventName string
function SystemManager.createGameEventHandler(eventName)
	if eventName:sub(-3, -1) == "Raw" then
		eventName = eventName:sub(1, -4)
	end
	if _ENV[eventName] == nil then
		_ENV[eventName] = function(...)
			-- TODO: We could optimize this by already knowing what functions we need to run, rather than finding them each time.
			for _, system in ipairs(SystemManager.systems) do
				local f = system[eventName .. "Raw"]
				if f ~= nil then
					log_setContext(SYSTEM_EVENT_CTX_NAME, ("%s.%s"):format(system.name, eventName))
					f(...)
					log_setContext(SYSTEM_EVENT_CTX_NAME)
				end
				f = system[eventName]
				if f ~= nil then
					log_setContext(SYSTEM_EVENT_CTX_NAME, ("%s.%s"):format(system.name, eventName))
					if SystemManager.eventTransformers[eventName] then
						f(SystemManager.eventTransformers[eventName](...))
					else
						f(...)
					end
					log_setContext(SYSTEM_EVENT_CTX_NAME)
				end
			end
		end
	end
end

---@param system System
function SystemManager.registerSystem(system)
	if system.name == nil then
		system.name = "NO_NAME"
		log_error("System without a name has been registered!")
	end
	table.insert(SystemManager.systems, system)
	for _, eventName in pairs(SystemManager.BASE_GAME_EVENTS) do
		if system[eventName] ~= nil then
			SystemManager.createGameEventHandler(eventName)
		end
	end
end

---@param system System
function SystemManager.getSaveData(system)
	local data = g_savedata[system.name]
	if data == nil then
		data = {}
		g_savedata[system.name] = data
	end
	return data
end

---@param eventName string
---@param f fun(...):...
function SystemManager.setEventTransformer(eventName, f)
	if SystemManager.eventTransformers[eventName] ~= nil then
		log_error("Multiple event transformers are not supported!")
		return
	end
	SystemManager.eventTransformers[eventName] = f
end
