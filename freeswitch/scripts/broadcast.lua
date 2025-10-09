--scripts_dir = '/usr/share/freeswitch/scripts/'
local json = require("cjson")
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'
dofile("/usr/local/freeswitch/scripts/config.lua")
caching_path = '/opt/caching/'
dofile(scripts_dir .. "common/db.lua");

dofile(scripts_dir .. "common/custom.lua");
fs_logger("notice","[scripts/voicebroadcast.lua] execution start of voice broadcast")
local broadcast_uuid = session:getVariable("sip_h_P-campaign_uuid")
local tenant_uuid = session:getVariable("sip_h_P-tenant_uuid")
local lead_uuid = session:getVariable("sip_h_p-lead_uuid")
local phone_number = session:getVariable("Caller-Destination-Number")
local tenant_domain = session:getVariable("sip_h_P-tenant_domain")
local record_date = os.date("%Y-%m-%d")
fs_logger("notice","[scripts/voicebroadcast.lua] broadcastuuid  "..broadcast_uuid)
fs_logger("notice","[scripts/voicebroadcast.lua] tenantuuid  "..tenant_uuid)
fs_logger("notice","[scripts/voicebroadcast.lua] leaduuid  "..lead_uuid)
fs_logger("notice","[scripts/voicebroadcast.lua] phone_number  "..phone_number)
fs_logger("notice","[scripts/voicebroadcast.lua] tenant_domain  "..tenant_domain)
fs_logger("notice","[scripts/voicebroadcast.lua] record_date  "..record_date)

local voice_broadcast_collection = mongo_collection_name:getCollection "voice_broadcast"
local dnc_collection = mongo_collection_name:getCollection "dnc"
local survey_details_collection = mongo_collection_name:getCollection "survey_details"
local voice_broadcast_query = {uuid = broadcast_uuid}
local cursor = voice_broadcast_collection:find(voice_broadcast_query)
local voice_broadcast_array = ""
for voice_broadcast_details in cursor:iterator() do
	voice_broadcast_array = voice_broadcast_details
end

if voice_broadcast_array == "" then
	fs_logger("warning","[voicebroadcast.lua] :: Voicebroadcast Not avaiable::")
else
	fs_logger("warning","[voicebroadcast.lua] :: Voicebroadcast is available::")
	-- welcome prompt playing
	local welcome_details = {}
	local welcome_key = 0
	local welcome_prompt_data = voice_broadcast_array.welcome_prompt_selected_value
	for _, entry in ipairs(welcome_prompt_data) do
		welcome_details[welcome_key] = entry.value
		welcome_key = welcome_key + 1
	end 
	--session:execute("answer")
	--session:execute("playback",upload_file_path.."/"..voice_broadcast_array.exit_prompt_uuid..".wav")
	if(voice_broadcast_array.recording == '0')then
		session:execute("set",'custom_recording=0')
		session:execute("set", 'execute_on_answer=record_session $${recordings_dir}/'..tenant_domain..'/'..record_date..'/${uuid}.wav')
	end
	session:execute("set", 'sip_h_P-voicebroadcast=true')
--	welcome_prompt_digit = session:playAndGetDigits(0, 1, 3, 10000, "#",upload_file_path.."/"..voice_broadcast_array.welcome_prompt_uuid..".wav" , scripts_dir.."/audio/ivr-invalid_sound_prompt.wav", allowed_digits);
	local allowed_digits = "[0-2]"

	-- welcome_prompt_digit = session:playAndGetDigits(0, 1, 1, 10000, "#",upload_file_path.."/"..voice_broadcast_array.welcome_prompt_uuid..".wav" , "", allowed_digits);
	if(voice_broadcast_array and voice_broadcast_array.skip == 'false')then
		welcome_prompt_digit = session:playAndGetDigits(0, 1, voice_broadcast_array.playfile_time, 10000, "#",upload_file_path.."/"..voice_broadcast_array.welcome_prompt_uuid..".wav" , "", allowed_digits);
	elseif(voice_broadcast_array and voice_broadcast_array.skip == 'true')then
		welcome_prompt_digit = 0;
	end
	--welcome_prompt_digit = session:playAndGetDigits(1, 1, 3, 3000, "#","/usr/share/freeswitch/scripts/call-queue.wav", "/usr/share/freeswitch/scripts/10682567-9747054d80a30e1e2375d6ee7c652231.wav", allowed_digits);
	fs_logger("warning","[voicebroadcast.lua] ::pressed digits::"..welcome_prompt_digit)
	if(welcome_prompt_digit == "")then
		fs_logger("warning","[voicebroadcast.lua] ::pressed in digits::"..welcome_prompt_digit)
		session:execute("playback",upload_file_path.."/"..voice_broadcast_array.exit_prompt_uuid..".wav")
		session:hangup();
		return true;
	end
	if (tonumber(welcome_prompt_digit) == 0)then
		fs_logger("warning","[voicebroadcast.lua] :: user has pressed the 0 and continue the call")
		if tonumber(voice_broadcast_array.broadcast_type) == 0 then
			fs_logger("warning","[voicebroadcast.lua] :: broadcast have survey in their additional setting")
			session:execute("set", 'sip_h_P-voicebroadcast_type=0')
			local survey_data = voice_broadcast_array.survey_value
			--local survey_details = {}
			--local survey_key = 1
			--for _ , entry in ipairs(survey_data) do
			--	fs_logger("warning","[voicebroadcast.lua] :: survey prompt uuid"..entry.prompt_uuid)
			--	fs_logger("warning","[voicebroadcast.lua] :: survey from digit"..entry.from)
			--	fs_logger("warning","[voicebroadcast.lua] :: survey to digit"..entry.to)
			--	survey_digit = session:playAndGetDigits(entry.from, entry.to, 3, 3000, "#","/usr/share/freeswitch/scripts/call-queue.wav", "", "\\d+");
			--	fs_logger("warning","[voicebroadcast.lua] :: pressed survey digit"..survey_digit)
			--	survey_details[survey_key]['greeting_name'] = 'new_greeting'..survey_key
			--	survey_details[survey_key]['greeting_uuid'] = entry.prompt_uuid
			--	survey_details[survey_key]['pressed_survey_digit'] = survey_digit
			--	survey_key = survey_key + 1
			--		
			--end
			local survey_details = {}
			local survey_key = 1
			for _, entry in ipairs(survey_data) do
    				fs_logger("warning", "[voicebroadcast.lua] :: survey prompt uuid" .. entry.prompt_uuid)
    				fs_logger("warning", "[voicebroadcast.lua] :: survey from digit" .. entry.from)
    				fs_logger("warning", "[voicebroadcast.lua] :: survey to digit" .. entry.to)
    				survey_details[survey_key] = {}  -- Initialize the subtable for this survey key
    				local survey_allowed_digits = "["..entry.from.."-"..entry.to.."]"
    				fs_logger("warning", "[voicebroadcast.lua] :: allowed survey digit" ..survey_allowed_digits)
	    			--survey_digit = session:playAndGetDigits(1,1, 3, 10000, "#",upload_file_path.."/"..entry.prompt_uuid..".wav", scripts_dir.."/audio/ivr-invalid_sound_prompt.wav", survey_allowed_digits)
				survey_digit = session:playAndGetDigits(1,1, 1, 10000, "#",upload_file_path.."/"..entry.prompt_uuid..".wav", "", survey_allowed_digits)	    			
    				fs_logger("warning", "[voicebroadcast.lua] :: pressed survey digit" .. survey_digit)

    				-- Assign values to the subtable
    				survey_details[survey_key]['greeting_name'] = entry.prompt_name
    				survey_details[survey_key]['greeting_uuid'] = entry.prompt_uuid
    				survey_details[survey_key]['pressed_survey_digit'] = survey_digit
    				survey_key = survey_key + 1
			end
			 local survey_string = json.encode(survey_details)
			fs_logger("warning","[voicebroadcast.lua] :: survey stored data"..survey_string)
			session:execute("set", 'sip_h-p_survey_string='..survey_string)
			--local datatoinsert = {voicebroadcast_uuid = broadcast_uuid,tenant_uuid = tenant_uuid,lead_uuid = lead_uuid,survey_data = survey_string}
			--survey_details_collection:insert(datatoinsert)
		else
			fs_logger("warning","[voicebroadcast.lua] :: broadcast havr Ivr in their additional setting")
			session:execute("set", 'sip_h_P-voicebroadcast_type=1')
			session:execute("ivr",voice_broadcast_array.ivr_uuid)
			
			
			--session:execute("set", 'sip_h_P-voicebroadcast_flag=IVR')
		end
		-- play the exit sound and hangup
		session:execute("playback",upload_file_path.."/"..voice_broadcast_array.exit_prompt_uuid..".wav")	
	
	elseif (tonumber(welcome_prompt_digit) == 1) then
		fs_logger("warning","[voicebroadcast.lua] :: user has pressed the 1 and call go to Not interested")
		session:execute("playback",welcome_details[1])
		session:execute("set", 'sip_h_P-voicebroadcast_type=2')
		--session:execute("set", 'sip_h_P-voicebroadcast_flag=NOT_INTERESTED')
		session:hangup();
	elseif (tonumber(welcome_prompt_digit) == 2) then
		fs_logger("warning","[voicebroadcast.lua] :: user has pressed the 2 and call go to Dnc")
		session:execute("playback",welcome_details[2])
		session:execute("set", 'sip_h_P-voicebroadcast_type=3')
		--session:execute("set", 'sip_h_P-voicebroadcast_flag=DNC')
		session:hangup();
		dnc_uuid = generateUUIDv4()
		local datatoinsert = {voicebroadcast_uuid = broadcast_uuid,tenant_uuid = tenant_uuid,lead_uuid = lead_uuid,phone_number = phone_number,status = '0',global_status = '0',uuid = dnc_uuid}
		dnc_collection:insert(datatoinsert)
	end
	
	
 end




