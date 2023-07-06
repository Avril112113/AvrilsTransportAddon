-- NOTE: File starts with `z_` so it is the last system to be registered.

---@class SaveSystem : System
SaveSystem = {name="SaveSystem"}


function SaveSystem.onDestroy()
	if SaveSystem.markedForReset then
		g_savedata = {}
		log_warn("Reset savedata due to being marked to do so.")
	end
end

function SaveSystem.markForReset()
	SaveSystem.markedForReset = true
end


SystemManager.registerSystem(SaveSystem)


Command.new("savedata")
	:setDesc("!DEV COMMAND!\nUsed to modify save data.")
	:setPermission("admin")
	:register()
	:setHandler({"path:string?"}, function(self, ctx, path)
		local pathParts = {}
		if path ~= nil and #path > 0 then
			for part in path:gmatch("[^.]+") do
				table.insert(pathParts, part)
			end
		end
		local obj = g_savedata
		local objPathParts = {"g_savedata"}
		for _, part in ipairs(pathParts) do
			table.insert(objPathParts, part)
			obj = obj[part]
			if obj == nil then
				break
			end
		end
		return 0, table.concat(objPathParts, ".") .. " =\n" .. toStringRepr(obj, 0)
	end)
	:addSubcommand(
		Command.new("reset")
			:setDesc("!EXTREMELY DANGEROUS!\nMark savedata to be reset upon script reload, as if a new world was created.")
			:setHandler({}, function(self, ctx)
				SaveSystem.markForReset()
				return 0, "Save data marked for reset."
			end)
	)
