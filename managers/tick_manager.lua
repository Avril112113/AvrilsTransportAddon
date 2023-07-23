---@class VersionSystem : System
TickManager = {name="TickManager"}
TickManager.sessionTick = 0

EventManager.addEventHandler("onCreate", 10,
	function(is_world_create)
		TickManager.data = SystemManager.getSaveData(TickManager)
		TickManager.data.gameTick = TickManager.data.gameTick or 0
		TickManager.data.worldTick = TickManager.data.worldTick or 0

		-- TickManager._replicate()
	end
)

EventManager.addEventHandler("onTick", 10,
	function(game_ticks)
		TickManager.sessionTick = TickManager.sessionTick + 1
		TickManager.data.gameTick = TickManager.data.gameTick + 1
		TickManager.data.worldTick = TickManager.data.worldTick + game_ticks

		-- TickManager._replicate()
	end
)

-- function TickManager._replicate()
-- 	TickManager.gameTick = TickManager.data.gameTick
-- 	TickManager.worldTick = TickManager.data.worldTick
-- end
