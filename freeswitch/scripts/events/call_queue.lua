
local uuid = event:getHeader("Unique-ID")
if(uuid ~= nil)	then
	freeswitch.consoleLog("info", uuid .. " detected tone: \n")
else
	freeswitch.consoleLog("info", "NILLLL detected tone: \n")
end
