realMinutesToSWDay      60m (3600s)
realMinutesToSWHour     2.5m (150.0s)
~ During sleep
realMinutesToSWDay      0.15m (9.0s)
realMinutesToSWHour     0.00625m (0.375s)

```lua
local function fmtMins(mins) return ("%sm (%ss)"):format(mins, mins*60) end


local realMinutesToSWDay = 60
local realMinutesToSWHour = realMinutesToSWDay / 24

print("realMinutesToSWDay", fmtMins(realMinutesToSWDay))
print("realMinutesToSWHour", fmtMins(realMinutesToSWHour))

local sleepMul = 1/400  -- onTick() gets `400` when sleeping, instead of `1`
print("~ During sleep")
print("realMinutesToSWDay", fmtMins(realMinutesToSWDay*sleepMul))
print("realMinutesToSWHour", fmtMins(realMinutesToSWHour*sleepMul))
```
