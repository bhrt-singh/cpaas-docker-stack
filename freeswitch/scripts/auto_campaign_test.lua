--scripts_dir = '/usr/share/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'

caching_path = '/opt/caching/'
dofile("/usr/local/freeswitch/scripts/config.lua")
dofile(scripts_dir .. "common/db.lua");
dofile(scripts_dir .. "common/custom.lua");
--[[	session:execute("bridge", 'sofia/external/123456@95.111.218.227:5070')
        session:execute("info")
        HangupCauseCode = session:getVariable("sip_bye_h_X-Asterisk-HangupCauseCode")
        fs_logger("notice","[auto_campaign.lua]HangupCauseCode "..HangupCauseCode)
        if(tonumber(HangupCauseCode) == 101)then
		session:execute('set','amd_hangup=true')
		session:execute('hangup')
]]--
	session:execute("amd")
        session:execute("info")
        HangupCauseCode = session:getVariable("amd_result")
        fs_logger("notice","[auto_campaign.lua]HangupCauseCode "..HangupCauseCode)
        if(HangupCauseCode == 'MACHINE')then
		session:execute('set','amd_hangup=true')
		session:execute('hangup')

	else        
	 session:execute('set','hangup_after_bridge=true')
	 session:execute('set','continue_on_fail=TRUE')
	 session:execute('set','ignore_early_media=false')
        session:execute("bridge", 'user/2003@labtest2.belsmart.io')
        end
return

