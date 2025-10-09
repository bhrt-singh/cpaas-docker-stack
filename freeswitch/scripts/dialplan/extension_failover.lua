local on_busy_failover = session:getVariable("on_busy_failover");
local no_answered_failover = session:getVariable("no_answered_failover");
local not_registered_failover = session:getVariable("not_registered_failover");
local last_disposition = session:getVariable("originate_disposition");
freeswitch.consoleLog ('notice','last_disposition:::'..last_disposition);
if session:ready() then
	if((last_disposition == 'USER_BUSY' or last_disposition == 'NO_USER_RESPONSE') and on_busy_failover and on_busy_failover ~= '')then
		local bridge = on_busy_failover..' XML ${domain_name}'
		freeswitch.consoleLog ('notice',':last_disposition::::::transfer:::'..on_busy_failover);
		session:execute("transfer", bridge)
	end
	if(last_disposition == 'USER_NOT_REGISTERED' and not_registered_failover and not_registered_failover ~= '')then
		local bridge = not_registered_failover..' XML ${domain_name}'
		freeswitch.consoleLog ('notice',':last_disposition::::::transfer:::'..not_registered_failover);
		session:execute("transfer", bridge)
	end
	if(last_disposition == 'NO_ANSWER' and no_answered_failover and no_answered_failover ~= '')then
		local bridge = no_answered_failover..' XML ${domain_name}'
		freeswitch.consoleLog ('notice',':last_disposition::::::transfer:::'..no_answered_failover);
		session:execute("transfer", bridge)
	end
end
