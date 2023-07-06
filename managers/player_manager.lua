--[[
	TODO:
		Offline player data.
]]


PlayerManager = {name="PlayerManager"}
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


---@param is_world_create boolean Only returns true when the world is first created.
function PlayerManager.onCreate(is_world_create)
	for _, swplayer in pairs(server.getPlayers()) do
		PlayerManager.setPlayer(swplayer.id, swplayer.steam_id, swplayer.name, swplayer.admin, swplayer.auth)
	end
end

---@param steam_id integer The player's Steam ID (convert to string as soon as possible to prevent loss of data)
---@param name string The player's name
---@param peer_id integer The player's peer ID
---@param is_admin boolean If the player has admin
---@param is_auth boolean If the player is authenticated
function PlayerManager.onPlayerJoinRaw(steam_id, name, peer_id, is_admin, is_auth)
	log_info("Player ", name, " joined the server.")
	PlayerManager.setPlayer(peer_id, steam_id, name, is_admin, is_auth)
end

---@param steam_id number The player's Steam ID (convert to string as soon as possible to prevent loss of data)
---@param name string The player's name
---@param peer_id number The player's peer ID
---@param is_admin boolean If the player has admin
---@param is_auth boolean If the player is authenticated
function PlayerManager.onPlayerLeaveRaw(steam_id, name, peer_id, is_admin, is_auth)
	log_info("Player ", name, " left the server.")
	PlayerManager.unsetPlayer(PlayerManager.playersByPeerId[peer_id])
end


SystemManager.setEventTransformer("onCustomCommand", function(full_message, peer_id, is_admin, is_auth, command, ...)
	local player = PlayerManager.playersByPeerId[peer_id]
	return full_message, player, command, ...
end)
SystemManager.setEventTransformer("onChatMessage", function(peer_id, sender_name, message)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player, sender_name, message
end)

SystemManager.setEventTransformer("onPlayerJoin", function(steam_id, name, peer_id, is_admin, is_auth)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player
end)
SystemManager.setEventTransformer("onPlayerLeave", function(steam_id, name, peer_id, is_admin, is_auth)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player
end)
SystemManager.setEventTransformer("onPlayerSit", function(peer_id, vehicle_id, seat_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player, vehicle_id, seat_name
end)
SystemManager.setEventTransformer("onPlayerUnsit", function(peer_id, vehicle_id, seat_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player, vehicle_id, seat_name
end)
SystemManager.setEventTransformer("onPlayerRespawn", function(peer_id)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player
end)
SystemManager.setEventTransformer("onToggleMap", function(peer_id, is_open)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player, is_open
end)
SystemManager.setEventTransformer("onPlayerDie", function(steam_id, name, peer_id, is_admin, is_auth)
	local player = PlayerManager.playersByPeerId[peer_id]
	return player
end)

SystemManager.setEventTransformer("onVehicleSpawn", function(vehicle_id, peer_id, x, y, z, cost)
	local player = PlayerManager.playersByPeerId[peer_id]
	return vehicle_id, player, x, y, z, cost
end)
SystemManager.setEventTransformer("onVehicleDespawn", function(vehicle_id, peer_id)
	local player = PlayerManager.playersByPeerId[peer_id]
	return vehicle_id, player
end)
SystemManager.setEventTransformer("onVehicleTeleport", function(vehicle_id, peer_id, x, y, z)
	local player = PlayerManager.playersByPeerId[peer_id]
	return vehicle_id, player, x, y, z
end)

SystemManager.setEventTransformer("onButtonPress", function(vehicle_id, peer_id, button_name)
	local player = PlayerManager.playersByPeerId[peer_id]
	return vehicle_id, player, button_name
end)


SystemManager.registerSystem(PlayerManager)
