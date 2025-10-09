    freeswitch.consoleLog("INFO","avmd_detect call ")
    freeswitch.consoleLog("INFO","avmd_detect call ")
session:execute("info")
    avmd_detect = session:getVariable("avmd_detect")
--session:execute("info")
    freeswitch.consoleLog("INFO", string.format("avmd_detect call %s", amd_detect))
return
--[[
local dst_number = argv[1]
-- Connecting to the freeswitch API.
api = freeswitch.API()
use_amd = api:executeString("amd_available")
 
-- subscriber_session = freeswitch.Session("{ignore_early_media=true}sofia/gateway/mygw/" .. dst_number)
 
--while (subscriber_session:ready() and not subscriber_session:answered()) do
  -- Waiting for answer.
 -- freeswitch.msleep(500)
--end
if (session:ready() ~= true) then
        return
end
freeswitch.consoleLog("notice","[avmd.lua]")	
if session:ready() and session:answered() then
freeswitch.consoleLog("notice","[avmd.lua] in session")
	      --session:execute("avmd_start","simplified_estimation=0,inbound_channel=1,outbound_channel=0,sample_n_continuous_streak=25,sample_n_to_skip=18,debug=0,report_status=0")
session:execute("avmd_start","detection_mode=2,report_status=0,debug=0,outbound_channel=0")
    -- Giving some time to AMD to work on the call.
    session:sleep(3000)
    session:execute("avmd_stop")
    avmd_detect = session:getVariable("avmd_detect")
--session:execute("info")
    freeswitch.consoleLog("INFO", string.format("avmd_detect call %s", amd_detect))
--[[    if amd_detect == "machine" then
      freeswitch.consoleLog("INFO", "amd_status: machine")
      session:execute("wait_for_silence", "300 30 5 25000")
      session:execute("playback", "/usr/local/freeswitch/scripts/audio/en/us/callie/ivr/8000/ivr-welcome_to_freeswitch.wav")
      session:hangup()
      return
    end
]]--    
--    return
    -- Do your actions if human answered. Ex. Transfer to operator/user 100.
--    session:execute("bridge", "user/100")
--end
