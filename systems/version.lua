-- WARNING: THIS IS NOT TESTED!


---@class VersionSystem : System
VersionSystem = {name="VersionSystem"}
VersionSystem.ADDON_VERSION = 0  -- A simple int that is increased each update.
---@type Migrator[]
VersionSystem.migrators = {}



SystemManager.addEventHandler(VersionSystem, "onCreate", 50,
	function(is_world_create)
		VersionSystem.data = SystemManager.getSaveData(VersionSystem)
		if VersionSystem.data.lastVersion == nil then
			VersionSystem.data.lastVersion = VersionSystem.ADDON_VERSION
		elseif VersionSystem.data.lastVersion ~= VersionSystem.ADDON_VERSION then
			-- Only bother sorting if we need to.
			table.sort(VersionSystem.migrators, function (a, b)
				return a.version < b.version
			end)
			-- TODO: Do we want to keep a backup of `g_savedata` in-case something goes wrong?
			local wasMigrationError = false
			for _, migrator in ipairs(VersionSystem.migrators) do
				if migrator.version >= VersionSystem.data.lastVersion then
					local ok, err = migrator.migrate()
					if not ok then
						log_error(("Migration error: %s '%s'\n"):format(migrator.system.name, migrator.name, err or "~Migrator returned false~"))
						wasMigrationError = true
					end
				end
			end
			if wasMigrationError then
				log_error("There was one or multiple migration errors, this may result in lost or corrupted data.\nPlease create an issue at https://github.com/Dude112113/AvrilsTransportAddon\nIf you are going to continue playing anyway, use a new save slot instead of overwriting.")
			end
		end
	end
)


---@param system System
---@param name string
---@param version integer # The version where the migration is required.
---@param migrate fun(): false?, string?
function VersionSystem.addMigration(system, name, version, migrate)
	---@class Migrator
	local migrator = {
		system=system,
		name=name,
		version=version,
		migrate=migrate,
	}
	table.insert(VersionSystem.migrators, migrator)
end
