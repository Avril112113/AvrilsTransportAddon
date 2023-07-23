-- Some alias' used for alias' and types to be more defined in what they are.
---@alias PeerId integer
---@alias SteamId string


require("helpers")

DEFAULT_LOG_LEVEL = 2  -- Only affects what it put into chat, not the debug logs.
require("logging")

g_savedata = {}

require("iostream")
require("binnet")


require("managers.event_manager")

require("managers.version_manager")
require("managers.system_manager")
require("managers.tick_manager")
require("managers.command_manager")
require("managers.player_manager")
require("managers.vehicle_manager")

---@require_folder systems
require("systems.company")
require("systems.interface")
require("systems.location")
require("systems.test")
require("systems.z_save")
---@require_folder_finish
