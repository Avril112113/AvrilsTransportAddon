---@class System
---@field name string


SystemManager = {}


---@param system System
function SystemManager.getSaveData(system)
	local data = g_savedata[system.name]
	if data == nil then
		data = {}
		g_savedata[system.name] = data
	end
	return data
end

---@param system System
---@param eventName string
---@param priority integer # Smaller = first
---@param handler fun():true?
function SystemManager.addEventHandler(system, eventName, priority, handler)
	if system.name == nil then
		system.name = "NO_NAME"
		log_error("System without a name has added a event handler!")
	end
	EventManager.addEventHandler(eventName, priority, handler, ("%s~%s"):format(system.name, eventName))
end

-- Typing: After all managers have transformed them.
if false then
	---@overload fun(system:System, eventName:"onCreate", priority:integer, handler:(fun(is_world_create:boolean):true?))
	---@overload fun(system:System, eventName:"onDestroy", priority:integer, handler:(fun():true?))
	---@overload fun(system:System, eventName:"onTick", priority:integer, handler:(fun(game_ticks:number):true?))
	---@overload fun(system:System, eventName:"onCustomCommand", priority:integer, handler:(fun(full_message:string, player:Player, command:string, ...:string):true?))
	---@overload fun(system:System, eventName:"onChatMessage", priority:integer, handler:(fun(player:Player, sender_name:string, message:string):true?))
	---@overload fun(system:System, eventName:"onSpawnAddonComponent", priority:integer, handler:(fun(vehicle_or_object_id:number,component_name:string,TYPE_STRING:string,addon_index:number):true?))
	---@overload fun(system:System, eventName:"httpReply", priority:integer, handler:(fun(port:number,request:string,reply:string):true?))
	---@overload fun(system:System, eventName:"onToggleMap", priority:integer, handler:(fun(player:Player, is_open:boolean):true?))
	---@overload fun(system:System, eventName:"onPlayerJoin", priority:integer, handler:(fun(player:Player):true?))
	---@overload fun(system:System, eventName:"onPlayerLeave", priority:integer, handler:(fun(player:Player):true?))
	---@overload fun(system:System, eventName:"onPlayerSit", priority:integer, handler:(fun(player:Player, vehicle_id:integer, seat_name:string):true?))
	---@overload fun(system:System, eventName:"onPlayerUnsit", priority:integer, handler:(fun(player:Player, vehicle_id:integer, seat_name:string):true?))
	---@overload fun(system:System, eventName:"onPlayerDie", priority:integer, handler:(fun(player:Player):true?))
	---@overload fun(system:System, eventName:"onPlayerRespawn", priority:integer, handler:(fun(player:Player):true?))
	---@overload fun(system:System, eventName:"onCharacterSit", priority:integer, handler:(fun(object_id:number,vehicle_id:integer,seat_name:string):true?))
	---@overload fun(system:System, eventName:"onCharacterUnsit", priority:integer, handler:(fun(object_id:number,vehicle_id:integer,seat_name:string):true?))
	---@overload fun(system:System, eventName:"onCharacterPickup", priority:integer, handler:(fun(object_id_actor:number,object_id_target:number):true?))
	---@overload fun(system:System, eventName:"onCharacterPickup", priority:integer, handler:(fun(character_object_id:number,creature_object_id:number,CREATURE_TYPE:SWCreatureTypeEnum):true?))
	---@overload fun(system:System, eventName:"onEquipmentPickup", priority:integer, handler:(fun(character_object_id:number,equipment_object_id:number,EQUIPMENT_ID:SWEquipmentTypeEnum):true?))
	---@overload fun(system:System, eventName:"onEquipmentDrop", priority:integer, handler:(fun(character_object_id:number,equipment_object_id:number,EQUIPMENT_ID:SWEquipmentTypeEnum):true?))
	---@overload fun(system:System, eventName:"onVehicleSpawn", priority:integer, handler:(fun(vehicle_id:integer, player:Player, x:number, y:number, z:number, cost:number):true?))
	---@overload fun(system:System, eventName:"onVehicleDespawn", priority:integer, handler:(fun(vehicle_id:integer, player:Player):true?))
	---@overload fun(system:System, eventName:"onVehicleTeleport", priority:integer, handler:(fun(vehicle_id:integer, player:Player, x:number, y:number):true?))
	---@overload fun(system:System, eventName:"onVehicleLoad", priority:integer, handler:(fun(vehicle_id:integer):true?))
	---@overload fun(system:System, eventName:"onVehicleUnload", priority:integer, handler:(fun(vehicle_id:integer):true?))
	---@overload fun(system:System, eventName:"onVehicleDamaged", priority:integer, handler:(fun(vehicle_id:integer,damage_amount:number,voxel_x:number,voxel_y:number,voxel_z:number,body_index:number):true?))
	---@overload fun(system:System, eventName:"onButtonPress", priority:integer, handler:(fun(vehicle_id:integer, player:Player, button_name:string):true?))
	---@overload fun(system:System, eventName:"onObjectLoad", priority:integer, handler:(fun(object_id:number):true?))
	---@overload fun(system:System, eventName:"onObjectUnload", priority:integer, handler:(fun(object_id:number):true?))
	---@overload fun(system:System, eventName:"onFireExtinguished", priority:integer, handler:(fun(fire_x:number,fire_y:number,fire_z:number):true?))
	---@overload fun(system:System, eventName:"onForestFireSpawned", priority:integer, handler:(fun(fire_objective_id:number,fire_x:number,fire_y:number,fire_z:number):true?))
	---@overload fun(system:System, eventName:"onForestFireExtinguised", priority:integer, handler:(fun(fire_objective_id:number,fire_x:number,fire_y:number,fire_z:number):true?))
	---@overload fun(system:System, eventName:"onTornado", priority:integer, handler:(fun(transform:SWMatrix):true?))
	---@overload fun(system:System, eventName:"onMeteor", priority:integer, handler:(fun(transform:SWMatrix):true?))
	---@overload fun(system:System, eventName:"onTsunami", priority:integer, handler:(fun(transform:SWMatrix,magnitude:number):true?))
	---@overload fun(system:System, eventName:"onWhirlpool", priority:integer, handler:(fun(transform:SWMatrix,magnitude:number):true?))
	---@overload fun(system:System, eventName:"onVolcano", priority:integer, handler:(fun(transform:SWMatrix):true?))
	---@overload fun(system:System, eventName:"onOilSpill", priority:integer, handler:(fun(tile_x, tile_y, delta, total, vehicle_id):true?))
	SystemManager.addEventHandler = SystemManager.addEventHandler
end
