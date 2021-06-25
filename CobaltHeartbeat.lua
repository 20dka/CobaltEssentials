--Copyright (C) 2020, Preston Elam (CobaltTetra) ALL RIGHTS RESERVED
--COBALTESSENTIALS IS PROTECTED UNDER AN GPLv3 LICENSE


local freq = 250 -- adjust this for update rate
local diff = 1000/freq
CreateThread("heartbeat", freq)
local t = 0

function heartbeat()
	t = t + diff
	TriggerLocalEvent("onTick", t)
end
