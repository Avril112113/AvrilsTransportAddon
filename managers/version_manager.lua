---@class VersionSystem : System
VersionManager = {name="VersionManager"}
VersionManager.ADDON_VERSION = 0
---@type Migrator[]
VersionManager.migrators = {}


EventManager.addEventHandler("onCreate", 0,
	function(is_world_create)
		VersionManager.data = SystemManager.getSaveData(VersionManager)
		if VersionManager.data.lastVersion == nil then
			VersionManager.data.lastVersion = VersionManager.ADDON_VERSION
		elseif VersionManager.data.lastVersion ~= VersionManager.ADDON_VERSION then
			-- Only bother sorting if we need to.
			table.sort(VersionManager.migrators, function (a, b)
				return a.version < b.version
			end)
			-- TODO: Do we want to keep a backup of `g_savedata` in-case something goes wrong?
			local wasMigrationError = false
			for _, migrator in ipairs(VersionManager.migrators) do
				if migrator.version >= VersionManager.data.lastVersion then
					-- TODO: If we have `pcall()`, we should use it here.
					local failed, err = migrator.migrate()
					if failed then
						log_error(("Migration error: %s to version %s\n"):format(migrator.system.name, migrator.version, err or "~Migrator returned false~"))
						wasMigrationError = true
					else
						log_info(("Migration applied: %s to version %s"):format(migrator.system.name, migrator.version))
					end
				end
			end
			if wasMigrationError then
				log_error("There was one or multiple migration errors, this may result in lost or corrupted data.\nPlease create an issue at https://github.com/Dude112113/AvrilsTransportAddon\nIf you are going to continue playing anyway, use a new save slot instead of overwriting.")
			end
			VersionManager.data.lastVersion = VersionManager.ADDON_VERSION
		end
	end
)


---@param system System
---@param version integer # The version where the migration is required.
---@param migrate fun(): false?, string?
function VersionManager.addMigration(system, version, migrate)
	---@class Migrator
	local migrator = {
		system=system,
		version=version,
		migrate=migrate,
	}
	table.insert(VersionManager.migrators, migrator)
end
