--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

-- Callbacks for handling the build process
-- Allows for running external processes, or customising the build output to how you prefer
-- Recommend using LifeBoatAPI.Tools.FileSystemUtils to simplify life

-- Note: THIS FILE IS NOT SANDBOXED. DO NOT REQUIRE CODE FROM LIBRARIES YOU DO NOT 100% TRUST.

local startTime

---@param builder Builder           builder object that will be used to build each file
---@param params MinimizerParams    params that the build process usees to control minification settings
---@param workspaceRoot Filepath    filepath to the root folder of the project
function onLBBuildStarted(builder, params, workspaceRoot)
	startTime = os.clock()
	builder.filter = "script%.lua"
end

--- Runs just before each file is built
---@param builder Builder           builder object that will be used to build each file
---@param params MinimizerParams    params that the build process usees to control minification settings
---@param workspaceRoot Filepath    filepath to the root folder of the project
---@param name string               "require"-style name of the script that's about to be built
---@param inputFile Filepath        filepath to the file that is about to be built
function onLBBuildFileStarted(builder, params, workspaceRoot, name, inputFile)
	local text = LifeBoatAPI.Tools.FileSystemUtils.readAllText(inputFile)
	-- Remove old require sections.
	text = text:gsub("%-%-%-@require_folder ([%w\\/]+)\n.-%-%-%-@require_folder_finish\n", function(path)
		local lines = {
			"---@require_folder " .. path,
			""
		}
		return table.concat(lines, "\n")
	end)
	-- [Re]add the requires, as new sections.
	local replaceCount = 0
	---@param pathStr string
	text, replaceCount = text:gsub("%-%-%-@require_folder ([%w\\/]+)\n", function(pathStr)
		foundReplacement = true
		local path = workspaceRoot
		for part in pathStr:gmatch("([^\\/]*)") do
			if #part > 0 then
				path = path:add("/" .. part)
			end
		end
		local requires = {}
		for i, dir in ipairs(LifeBoatAPI.Tools.FileSystemUtils.findDirsInDir(path)) do
			local dirPath = path:add("/" .. dir)
			local initPath = dirPath:add("/" .. "init.lua")
			local f = io.open(initPath:win(), "r")
			if f then
				f:close()
				local modPath = dirPath:relativeTo(workspaceRoot, true):linux():gsub("/", ".")
				table.insert(requires, ("require(\"%s\")"):format(modPath))
			end
		end
		for i, file in ipairs(LifeBoatAPI.Tools.FileSystemUtils.findFilesInDir(path)) do
			local filePath = path:add("/" .. file)
			if inputFile.rawPath ~= filePath.rawPath and file:sub(-4, -1) == ".lua" then
				local modPath = filePath:relativeTo(workspaceRoot, true):linux():sub(1, -5):gsub("/", ".")
				table.insert(requires, ("require(\"%s\")"):format(modPath))
			end
		end
		local lines = {
			"---@require_folder " .. pathStr,
			table.concat(requires, "\n"),
			"---@require_folder_finish",
			""
		}
		return table.concat(lines, "\n")
	end)
	if replaceCount > 0 then
		LifeBoatAPI.Tools.FileSystemUtils.writeAllText(inputFile, text)
	end
end

---@param builder Builder           builder object that will be used to build each file
---@param params MinimizerParams    params that the build process usees to control minification settings
---@param workspaceRoot Filepath    filepath to the root folder of the project
function onLBBuildComplete(builder, params, workspaceRoot)
	local USERNAME_PATH_PREFIX = "c:\\Users\\"
	local SCRIPT_FILE_NAME = "script.lua"

	---@type string? # !this is used as a fallback! The windows username, to access `AppData/Roaming/Stormworks/`
	local username
	---@type string? # Project name override, defaults to folder name of project
	local projectName

	---@type string
	local workspaceRootPath = workspaceRoot:win()

	if workspaceRootPath:sub(1, #USERNAME_PATH_PREFIX):lower() == USERNAME_PATH_PREFIX:lower() then
		username = workspaceRootPath:sub(#USERNAME_PATH_PREFIX+1)
		username = username:sub(1, username:find("\\")-1)
	end
	assert(username, "Unable to find windows username to access 'AppData/Roaming/Stormworks/' (Infered from input file path)")
	print("Windows username: " .. username)

	---@type string
	if projectName == nil then
		projectName = workspaceRootPath:sub(workspaceRootPath:find("\\[^\\]*$")+1)
	end
	projectName = projectName:gsub("[%c%s!&+:?^{}',;@~#()-<>%[%].=\\%%*/|]", "")
	assert(#projectName > 0, "Project name is empty?")
	print("Project name: " .. projectName)

	local missionScriptPath = LifeBoatAPI.Tools.Filepath:new("C:/Users/" .. username .. "/AppData/Roaming/Stormworks/data/missions/" .. projectName .. "/script.lua")
	print("Output path: " .. missionScriptPath:win())

	local releaseFilePath = builder.outputDirectory:add("/release/" .. SCRIPT_FILE_NAME)
	LifeBoatAPI.Tools.FileSystemUtils.copyFile(releaseFilePath, missionScriptPath)

	print("Build took: ", os.clock() - startTime)
	startTime = nil
end
