--[[
	TODO:
		Offline player data.
]]


PlayerManager = {}
PlayerManager.playersBySteamId = {}
PlayerManager.playersByPeerId = {}
PlayerManager.playersByName = {}


---@param peer_id integer The player's peer ID
---@param steam_id integer|string The player's Steam ID (convert to string as soon as possible to prevent loss of data)
---@param name string The player's name
---@param is_admin boolean If the player has admin
---@param is_auth boolean If the player is authenticated
function PlayerManager.setPlayer(peer_id, steam_id, name, is_admin, is_auth)
	---@class Player
	local player = {
		peer_id = peer_id,
		steam_id = tostring(steam_id),
		name = name,
		admin = is_admin,
		auth = is_auth,
	}
	PlayerManager.playersBySteamId[player.steam_id] = player
	PlayerManager.playersByPeerId[player.peer_id] = player
	PlayerManager.playersByName[player.name] = player
	return player
end
---@param player Player
function PlayerManager.unsetPlayer(player)
	PlayerManager.playersBySteamId[player.steam_id] = nil
	PlayerManager.playersByPeerId[player.peer_id] = nil
	PlayerManager.playersByName[player.name] = nil
end


---@param peer_id integer? The player's peer ID
---@return Player?
function PlayerManager.getByPeerId(peer_id)
	return PlayerManager.playersByPeerId[peer_id]
end

---@param steam_id string|integer? The player's Steam ID
---@return Player?
function PlayerManager.getBySteamId(steam_id)
	return PlayerManager.playersBySteamId[tostring(steam_id)]
end

---@param name string? The player's name
---@return Player?
function PlayerManager.getByName(name)
	return PlayerManager.playersByName[name]
end

---@return table<integer, Player>
function PlayerManager.getAll()
	return PlayerManager.playersByPeerId
end

---@param transform SWMatrix
---@param maxRadius number?
---@return {player:Player, dist:number}[]
function PlayerManager.getAllPlayersDistance(transform, maxRadius)
	maxRadius = maxRadius or math.maxinteger
	local players = {}
	for _, player in pairs(PlayerManager.getAll()) do
		local dist = matrix.distance(server.getPlayerPos(player.peer_id), transform)
		if dist <= maxRadius then
			table.insert(players, {player=player, dist=dist})
		end
	end
	table.sort(players, function(a, b)
		return a.dist < b.dist
	end)
	return players
end


EventManager.addEventHandler("onCreate", 1, function(is_world_create)
	for _, swplayer in pairs(server.getPlayers()) do
		PlayerManager.setPlayer(swplayer.id, swplayer.steam_id, swplayer.name, swplayer.admin, swplayer.auth)
	end
end)

EventManager.addEventHandler("onPlayerJoin", 1, function(steam_id, name, peer_id, is_admin, is_auth)
	log_info(("Player '%s' joined the server."):format(name))
	PlayerManager.setPlayer(peer_id, steam_id, name, is_admin, is_auth)

	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player}
end)
EventManager.addEventHandler("onPlayerLeave", 1, function(steam_id, name, peer_id, is_admin, is_auth)
	log_info(("Player '%s' left the server."):format(name))
	PlayerManager.unsetPlayer(PlayerManager.playersByPeerId[peer_id])

	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player}
end)

EventManager.addEventHandler("onCustomCommand", 1, function(full_message, peer_id, is_admin, is_auth, command, ...)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {full_message, player, command, ...}
end)
EventManager.addEventHandler("onChatMessage", 1, function(peer_id, sender_name, message)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player, sender_name, message}
end)

EventManager.addEventHandler("onPlayerSit", 1, function(peer_id, vehicle_id, seat_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player, vehicle_id, seat_name}
end)
EventManager.addEventHandler("onPlayerUnsit", 1, function(peer_id, vehicle_id, seat_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player, vehicle_id, seat_name}
end)
EventManager.addEventHandler("onPlayerDie", 1, function(steam_id, name, peer_id, is_admin, is_auth)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player}
end)
EventManager.addEventHandler("onPlayerRespawn", 1, function(peer_id)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player}
end)
EventManager.addEventHandler("onToggleMap", 1, function(peer_id, is_open)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {player, is_open}
end)

EventManager.addEventHandler("onVehicleSpawn", 1, function(vehicle_id, peer_id, x, y, z, cost)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {vehicle_id, player, x, y, z, cost}
end)
EventManager.addEventHandler("onVehicleDespawn", 1, function(vehicle_id, peer_id)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {vehicle_id, player}
end)
EventManager.addEventHandler("onVehicleTeleport", 1, function(vehicle_id, peer_id, x, y, z)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {vehicle_id, player, x, y, z}
end)
EventManager.addEventHandler("onButtonPress", 1, function(vehicle_id, peer_id, button_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return "transform", {vehicle_id, player, button_name}
end)


-- Not typing EventManager.addEventHandler, as LuaLS is combining argument types for handlers :/
-- SystemManager.addEventHandler will be typed with the transformed arguments instead.
-- if false then
-- 	---@overload fun(eventName:"onCustomCommand", priority:integer, handler:(fun(full_message:string, player:Player, command:string, ...:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onChatMessage", priority:integer, handler:(fun(player:Player, sender_name:string, message:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerJoin", priority:integer, handler:(fun(player:Player):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerLeave", priority:integer, handler:(fun(player:Player):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerSit", priority:integer, handler:(fun(player:Player, vehicle_id:integer, seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerUnsit", priority:integer, handler:(fun(player:Player, vehicle_id:integer, seat_name:string):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerDie", priority:integer, handler:(fun(player:Player):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onPlayerRespawn", priority:integer, handler:(fun(player:Player):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onToggleMap", priority:integer, handler:(fun(player:Player, is_open:boolean):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleSpawn", priority:integer, handler:(fun(vehicle_id:integer, player:Player, x:number, y:number, z:number, cost:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleDespawn", priority:integer, handler:(fun(vehicle_id:integer, player:Player):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onVehicleTeleport", priority:integer, handler:(fun(vehicle_id:integer, player:Player, x:number, y:number):EventHandlerResult, any[]?))
-- 	---@overload fun(eventName:"onButtonPress", priority:integer, handler:(fun(vehicle_id:integer, player:Player, button_name:string):EventHandlerResult, any[]?))
-- 	EventManager.addEventHandler = EventManager.addEventHandler
-- end
