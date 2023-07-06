---@alias EventName string|"onCreate"|"onDestroy"|"onTick"|"onCustomCommand"|"onChatMessage"|"onPlayerJoin"|"onPlayerLeave"|"onPlayerSit"|"onPlayerUnsit"|"onPlayerDie"|"onPlayerRespawn"|"onCharacterSit"|"onCharacterUnsit"|"onCharacterPickup"|"onEquipmentPickup"|"onEquipmentDrop"|"onVehicleSpawn"|"onVehicleDespawn"|"onVehicleLoad"|"onVehicleUnload"|"onVehicleTeleport"|"onVehicleDamaged"|"onButtonPress"|"onObjectLoad"|"onObjectUnload"|"onFireExtinguished"|"onForestFireSpawned"|"onForestFireExtinguised"|"onTornado"|"onMeteor"|"onTsunami"|"onWhirlpool"|"onVolcano"|"onToggleMap"|"httpReply"|"onSpawnAddonComponent"
---@alias EventHandlerResult true|"transform"|nil|false
---@alias EventHandler fun(...): EventHandlerResult, any[]?


---@class EventManager
---@field eventName string
EventManager = {
	BASE_GAME_EVENTS={
		onCreate=true, onDestroy=true,
		onTick=true,
		onCustomCommand=true, onChatMessage=true,

		onPlayerJoin=true, onPlayerLeave=true,
		onPlayerSit=true, onPlayerUnsit=true,
		onPlayerDie=true, onPlayerRespawn=true,

		onCharacterSit=true, onCharacterUnsit=true,
		onCharacterPickup=true,

		onEquipmentPickup=true, onEquipmentDrop=true,
		onVehicleSpawn=true, onVehicleDespawn=true,
		onVehicleLoad=true, onVehicleUnload=true,
		onVehicleTeleport=true,
		onVehicleDamaged=true,
		onButtonPress=true,

		onObjectLoad=true, onObjectUnload=true,

		onFireExtinguished=true,
		onForestFireSpawned=true, onForestFireExtinguised=true,

		onTornado=true, onMeteor=true, onTsunami=true, onWhirlpool=true, onVolcano=true,

		onToggleMap=true,
		httpReply=true,
		onSpawnAddonComponent=true,

		-- Some are missing that LifeBoatAPI doesn't have documented.
	},
	---@type table<string, EventHandler[]>
	eventHandlers={},
	---@type table<EventHandler, string>
	eventHandlerLogContexts={},
	---@type table<string, table<integer, integer>> # To track where each priority goes, as some will share the same priority and others not.
	eventHandlerPriorityIndices={},
	---@type table<string, boolean>
	createdBaseEventFunctions={},
}

---@param name string
---@param ... any # Event arguments
function EventManager.fireEvent(name, ...)
	local eventHandlers = EventManager.eventHandlers[name]
	local args = {...}
	if eventHandlers and #eventHandlers > 0 then
		for _, eventHandler in ipairs(eventHandlers) do
			log_setContext("eventContext", EventManager.eventHandlerLogContexts[eventHandler])
			local result, transformed = eventHandler(table.unpack(args))
			if result == "transform" and transformed ~= nil then
				args = transformed
			elseif result == true then
				break
			end
		end
		log_setContext("eventContext", nil)
	end
end

--- A `handler` can return `true` to cancel the event, so lower priority events don't get called.
--- A `handler` can return `"transform"` followed by a table list of new arguments for lower priority events.
---@param name EventName
---@param priority integer # Smaller = first
---@param handler EventHandler
---@param logContext string?
function EventManager.addEventHandler(name, priority, handler, logContext)
	EventManager.eventHandlers[name] = EventManager.eventHandlers[name] or {}
	local handlers = EventManager.eventHandlers[name]
	local index = EventManager.getHandlerInsertIndex(name, priority)
	table.insert(handlers, index, handler)
	EventManager.shiftHandlerInsertPriorities(name, priority, index)
	EventManager.eventHandlerLogContexts[handler] = logContext
	if EventManager.BASE_GAME_EVENTS[name] and _ENV[name] == nil then
		_ENV[name] = function(...)
			EventManager.fireEvent(name, ...)
		end
	end
	-- log_debug(("Added event handler: %s:%.0f @ %.0f%s"):format(name, priority, index, logContext and " '" .. logContext .. "'" or ""))
end

---@param name EventName
---@param priority integer
---@return integer
function EventManager.getHandlerInsertIndex(name, priority)
	local priorityIndices = EventManager.eventHandlerPriorityIndices[name]
	if priorityIndices == nil then
		return 1
	end
	local index = 1
	for i, v in pairs(priorityIndices) do
		if i <= priority then
			index = math.max(index, v)
		end
	end
	return index
end

---@param name EventName
---@param priority integer
---@param index integer
function EventManager.shiftHandlerInsertPriorities(name, priority, index)
	local priorityIndicies = EventManager.eventHandlerPriorityIndices[name]
	if priorityIndicies == nil then
		priorityIndicies = {}
		EventManager.eventHandlerPriorityIndices[name] = priorityIndicies
	end
	for i, v in pairs(priorityIndicies) do
		if v > index then
			priorityIndicies[i] = v+1
		end
	end
	priorityIndicies[priority] = index+1
end


-- Not typing EventManager.addEventHandler, as LuaLS is combining argument types for handlers :/
-- SystemManager.addEventHandler will be typed with the transformed arguments instead.
-- -- Typing
-- if false then
-- 	---@overload fun(eventName:"onCreate", priority:integer, handler:(fun(is_world_create:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onDestroy", priority:integer, handler:(fun():EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onTick", priority:integer, handler:(fun(game_ticks:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onCustomCommand", priority:integer, handler:(fun(full_message:string, peer_id:integer, is_admin:boolean, is_auth:boolean, command:string, ...:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onChatMessage", priority:integer, handler:(fun(peer_id:integer,sender_name:string,message:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onSpawnAddonComponent", priority:integer, handler:(fun(vehicle_or_object_id:number,component_name:string,TYPE_STRING:string,addon_index:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"httpReply", priority:integer, handler:(fun(port:number,request:string,reply:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onToggleMap", priority:integer, handler:(fun(peer_id:integer,is_open:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerJoin", priority:integer, handler:(fun(steam_id:number,name:string,peer_id:integer,is_admin:boolean,is_auth:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerLeave", priority:integer, handler:(fun(steam_id:number,name:string,peer_id:integer,is_admin:boolean,is_auth:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerSit", priority:integer, handler:(fun(peer_id:integer,vehicle_id:integer,seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerUnsit", priority:integer, handler:(fun(peer_id:integer,vehicle_id:integer,seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerDie", priority:integer, handler:(fun(steam_id:number,name:string,peer_id:integer,is_admin:boolean,is_auth:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerRespawn", priority:integer, handler:(fun(peer_id:integer):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onCharacterSit", priority:integer, handler:(fun(object_id:number,vehicle_id:integer,seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onCharacterUnsit", priority:integer, handler:(fun(object_id:number,vehicle_id:integer,seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onCharacterPickup", priority:integer, handler:(fun(object_id_actor:number,object_id_target:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onCharacterPickup", priority:integer, handler:(fun(character_object_id:number,creature_object_id:number,CREATURE_TYPE:SWCreatureTypeEnum):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onEquipmentPickup", priority:integer, handler:(fun(character_object_id:number,equipment_object_id:number,EQUIPMENT_ID:SWEquipmentTypeEnum):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onEquipmentDrop", priority:integer, handler:(fun(character_object_id:number,equipment_object_id:number,EQUIPMENT_ID:SWEquipmentTypeEnum):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleSpawn", priority:integer, handler:(fun(vehicle_id:integer,peer_id:integer,x:number,y:number,z:number,cost:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleDespawn", priority:integer, handler:(fun(vehicle_id:integer,peer_id:integer):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleLoad", priority:integer, handler:(fun(vehicle_id:integer):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleUnload", priority:integer, handler:(fun(vehicle_id:integer):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleTeleport", priority:integer, handler:(fun(vehicle_id:integer,peer_id:integer,x:number,y:number,z:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleDamaged", priority:integer, handler:(fun(vehicle_id:integer,damage_amount:number,voxel_x:number,voxel_y:number,voxel_z:number,body_index:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onButtonPress", priority:integer, handler:(fun(vehicle_id:integer,peer_id:integer,button_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onObjectLoad", priority:integer, handler:(fun(object_id:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onObjectUnload", priority:integer, handler:(fun(object_id:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onFireExtinguished", priority:integer, handler:(fun(fire_x:number,fire_y:number,fire_z:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onForestFireSpawned", priority:integer, handler:(fun(fire_objective_id:number,fire_x:number,fire_y:number,fire_z:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onForestFireExtinguised", priority:integer, handler:(fun(fire_objective_id:number,fire_x:number,fire_y:number,fire_z:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onTornado", priority:integer, handler:(fun(transform:SWMatrix):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onMeteor", priority:integer, handler:(fun(transform:SWMatrix):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onTsunami", priority:integer, handler:(fun(transform:SWMatrix,magnitude:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onWhirlpool", priority:integer, handler:(fun(transform:SWMatrix,magnitude:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVolcano", priority:integer, handler:(fun(transform:SWMatrix):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onOilSpill", priority:integer, handler:(fun(tile_x, tile_y, delta, total, vehicle_id):EventHandlerResult, any[]?))
-- 	EventManager.addEventHandler = SystemManager.addEventHandler
-- end
