--scripts_dir = '/usr/share/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'

caching_path = '/opt/caching/'
dofile("/usr/local/freeswitch/scripts/config.lua")
dofile(scripts_dir .. "common/db.lua");

function check_avaialble_agent(campaign_uuid,tenant_uuid)
        local avaialble_agent_collection = mongo_collection_name:getCollection "auto_campaign_originate"
        local query = ''
--      local projection = { uuid=true,flag = true,username = true,agent_uuid=true, _id = false }
        local projection = { auto_campaign_originate_uuid=true,last_calldate = true,campaign_uuid=true,flag = true,agent_uuid=true, _id = false }
        query = { campaign_uuid = campaign_uuid, tenant_uuid = tenant_uuid}
        --query = { campaign_uuid = campaign_uuid, tenant_uuid = tenant_uuid,flag = '0'}
                fs_logger("notice","[auto_campaign.lua::campaign_uuid::"..campaign_uuid)
                fs_logger("notice","[auto_campaign.lua::tenant_uuid::"..tenant_uuid)
--      local cursor = avaialble_agent_collection:find(query, { projection = projection })
        local cursor = avaialble_agent_collection:find(query)
        local avaialble_agent_array = {}
        local available_agent_key = 1
        for avaialble_agent_details in cursor:iterator() do
                local agent_live_status_condition = check_aget_live_status(avaialble_agent_details.agent_uuid)
                fs_logger("notice","[auto_campaign.lua::agent_live_status_condition::"..agent_live_status_condition)
                fs_logger("notice","[auto_campaign.lua::agent_uuid in condition::"..avaialble_agent_details.agent_uuid)
                if(tonumber(agent_live_status_condition) == 0)then
		        avaialble_agent_array[available_agent_key] = avaialble_agent_details;
		        available_agent_key = available_agent_key + 1
		end
        end
        available_agent_key = available_agent_key - 1
        local last_date_key = 1;
        fs_logger("notice","[auto_campaign.lua::Agent adesh avaiable::"..available_agent_key)
        if(avaialble_agent_array[1] == '' or avaialble_agent_array[1] == nil)then
                fs_logger("notice","[auto_campaign.lua::Agent Not avaiable::")
        else
                fs_logger("notice","[auto_campaign.lua::Agent avaiable::")
                local last_calldate = avaialble_agent_array[1]['last_calldate']
                if last_calldate == nil or last_calldate == ''then
                	last_calldate = os.date("%Y-%m-%d 00:00:01")
                end
		 --local last_call_count = avaialble_agent_array[1]['call_count']
                fs_logger("notice","[auto_campaign.lua::Agent adesh1 last_call_count::"..last_calldate)
                for agent_key,agent_value in pairs(avaialble_agent_array) do
                        fs_logger("notice","[auto_campaign.lua::Agent adesh2 avaiable::"..agent_value['call_count']..":::agent_key:::"..agent_key)
                        if agent_value['last_calldate'] == nil or agent_value['last_calldate'] == '' then
                        	agent_value['last_calldate'] = os.date("%Y-%m-%d 00:00:01")
                        end
                        if (agent_value['last_calldate'] <= last_calldate) then
 --                      if (agent_value['call_count'] < last_call_count) then
   --                            last_call_count = agent_value['call_count']
	                         last_calldate = agent_value['last_calldate']                               
                                last_date_key = agent_key
                        end
                end
                fs_logger("notice","[auto_campaign.lua::Agent adesh2 avaiable::"..last_date_key)
        end
        --fs_logger("notice","[auto_campaign.lua::Agent adesh2 avaiable::"..last_date_key)
        --fs_logger("notice","[auto_campaign.lua::Agent adesh2 avaiable::"..avaialble_agent_array[last_date_key]['last_calldate'])
        return avaialble_agent_array[last_date_key];
end
function update_avaialble_agent(campaign_uuid,tenant_uuid,user_name)
        local update_agent_collection = mongo_collection_name:getCollection "auto_campaign_originate"
        local filter = { campaign_uuid = campaign_uuid, tenant_uuid = tenant_uuid,username = user_name}
        local update = {
            ["$set"] = {flag = '1'}
        }
        fs_logger("notice","[auto_campaign.lua::update_avaialble_agent::")
        return update_agent_collection:update(filter, update)
end
function check_aget_live_status(get_agent_uuid)
	local agent_live_collection = mongo_collection_name:getCollection "agent_live_report"
	local projection = { status = true, _id = false }
	local query = { agent_uuid =get_agent_uuid }
	local cursor = agent_live_collection:find(query, { projection = projection })
		agent_live_info_array = ''
		for agent_live_info_details in cursor:iterator() do
			agent_live_info_array = agent_live_info_details;
		end
		local return_status = 1
		if(agent_live_info_array == '')then
			fs_logger("notice","[auto_campaign.lua:: agent_live_report NIL::")
		else
			return_status = agent_live_info_array.status
		end
		fs_logger("notice","[auto_campaign.lua:: agent_live_report status ::"..return_status..":: for "..get_agent_uuid.."")
		return return_status;
end
local currentTimestamp = os.time()
print(currentTimestamp)

if(session:getVariable("sip_h_P-leg_timeout") ~= nil and session:getVariable("sip_h_P-leg_timeout") ~= '')then
--      leg_timeout = session:getVariable("sip_h_P-leg_timeout")
else
--      leg_timeout = 60
end
        leg_timeout = 60

local futureTimestamp = currentTimestamp + tonumber(leg_timeout)
--get the argv values
--scripts_dir = '/usr/share/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'
caching_path = '/opt/caching/'
dofile(scripts_dir .. "common/db.lua");
dofile(scripts_dir .. "common/custom.lua");
local callstart = os.date("%Y-%m-%d %H:%M:%S")
local record_date = os.date("%Y-%m-%d")
local recording_flag = 1
local campaign_uuid = session:getVariable("sip_h_P-campaign_uuid");
local campaign_flag = session:getVariable("sip_h_P-campaign_flag");
fs_logger("notice","[auto_campaign.lua::campaign_uuid::"..campaign_uuid)
local lead_uuid = session:getVariable("sip_h_P-lead_uuid");
local manager_uuid = session:getVariable("sip_h_P-manager_uuid")
session:execute("set", 'sip_h_X-lead_uuid='..lead_uuid)
session:execute("export", 'sip_h_X-auto_fail_flag=true')
session:execute("set", 'sip_h_X-auto_fail_flag=true')
session:execute("export", 'sip_h_X-lead_uuid='..lead_uuid)
session:execute("set", 'sip_h_P-callstart='..callstart)
session:execute("set", 'sip_h_P-callstart='..callstart)
--session:setVariable("ringback", "%(2000,4000,440,480)");
--session:setVariable("instant_ringback", "true");
--session:setVariable("hangup_after_bridge", "true");

local outbound_campaign_collection = mongo_collection_name:getCollection "outbound_campaign"
local lead_originate_collection = mongo_collection_name:getCollection "lead_originate"
local realtime_report_collection = mongo_collection_name:getCollection "realtime_report_count_mgmt"
local manager_realtime_collection = mongo_collection_name:getCollection "manager_realtime_count_mgmt"
local tenant_collection = mongo_collection_name:getCollection "tenant"
local blended_campaign_collection = mongo_collection_name:getCollection "blended_campaign"

if (lead_uuid ~= '') then
	local realtime_query = {lead_uuid = lead_uuid}
	local realtime_cursor = realtime_report_collection:find(realtime_query)
	local realtime_report_array = ""
	for realtime_report_details in realtime_cursor:iterator() do
		realtime_report_array = realtime_report_details;
	end
	if (realtime_report_array == "" )then 
		fs_logger("notice","[auto_campaign.lua::realtime report data not available ::")
	else
		fs_logger("notice","[auto_campaign.lua::realtime report data available ::")
		local update_filter = {lead_uuid = lead_uuid}
     		local update_string = {
                        ['$set'] = {type = 1}
                }
                realtime_report_collection:update(update_filter,update_string)
       end
       --if (manager_uuid ~= '')then
       --	local manager_realtime_query = {lead_uuid = lead_uuid}
       --	local manager_realtime_cursor = manager_realtime_collection:find(manager_realtime_query)
       --	local manager_realtime_array = ''
       --	for manager_realtime_details in manager_realtime_cursor:iterator() do
       --		manager_realtime_array = manager_realtime_details
       --	end
       --	if(manager_realtime_array == '')then
       --		fs_logger("notice","[auto_campaign.lua:: manager realtime report data not available ::")
       --	else
       --		fs_logger("notice","[auto_campaign.lua:: manager realtime report data available ::")
       --		local manager_update_filter = {lead_uuid = lead_uuid}
       --		local manager_update_string = {
       --			['$set'] = {type = 1}
       --		}
       --		manager_realtime_collection:update(manager_update_filter,manager_update_string)
       --	end
       --end
end

local campaign_array = ''
if(campaign_flag == 'blended') then
        local blended_query = {uuid=campaign_uuid}
        local blended_projection = {uuid=true,answering_machine_detection=true,greeting_uuid=true,recording=true,amd_promptuuid=true,_id=false}
        local cursor = blended_campaign_collection:find(blended_query,{projection = blended_projection})
        for blended_campaign_details in cursor:iterator() do
                campaign_array = blended_campaign_details;
        end
else
        local outbound_query = {uuid=campaign_uuid}
        local outbound_projection = {uuid=true,answering_machine_detection=true,greeting_uuid=true,recording=true,amd_promptuuid=true,_id=false}
        local cursor = outbound_campaign_collection:find(outbound_query,{projection = outbound_projection})

        for outbound_campaign_details in cursor:iterator() do
            campaign_array = outbound_campaign_details;
        end
end

if(campaign_array == '')then
        fs_logger("notice","[auto_campaign.lua::Campaign Not avaiable::")
else
        fs_logger("notice","[auto_campaign.lua::Campaign avaiable::")
end

--if(campaign_array ~= '' and tonumber(campaign_array['answering_machine_detection'] == 0))then
        --session:execute("avmd_start","detection_mode=2,inbound_channel=1,outbound_channel=1,debug=1")
        --session:execute("loop_playback", '+3 /usr/share/freeswitch/scripts/call-queue.wav')
        --session:execute("avmd_stop")
--end
--      session:execute("bridge", 'user/104@harsh2.inextrix.com')
--      os.execute("sleep 15")
--      session:execute("playback","/usr/share/freeswitch/scripts/10682567-9747054d80a30e1e2375d6ee7c652231.wav")
if (session:ready()) then
--[[	session:execute("bridge", 'sofia/external/123456@95.111.218.227:5070')
	session:execute("info")
	HangupCauseCode = session:getVariable("sip_bye_h_X-Asterisk-HangupCauseCode")
	fs_logger("notice","[auto_campaign.lua]HangupCauseCode "..HangupCauseCode)

	if(tonumber(HangupCauseCode) == 101)then
		fs_logger("notice","[auto_campaign.lua]ELSE MEANS MACHINE DETACT ")
		session:execute('set','sip_h_X-amd_hangup=true')
		session:execute('export','sip_h_X-amd_hangup=true')	
		session:execute('hangup')
	else   
]]--


        
        fs_logger("notice","[auto_campaign.lua::answering_machine_detection::"..campaign_array['answering_machine_detection'])
      if(campaign_array ~= '' and tonumber(campaign_array['answering_machine_detection']) == 0)then
	fs_logger("notice","[auto_campaign.lua::answering_machine_detection::"..campaign_array['answering_machine_detection'])
        session:execute("amd")
        session:execute("info")
      end
        HangupCauseCode = session:getVariable("amd_result")
        variable_amd_cause = session:getVariable("amd_cause");
        if(HangupCauseCode ~= nil and HangupCauseCode ~= "" and HangupCauseCode == 'MACHINE' and variable_amd_cause ~= 'INITIALSILENCE')then
        --if(HangupCauseCode ~= nil and HangupCauseCode ~= "" and HangupCauseCode == 'MACHINE' and campaign_array ~= '' and tonumber(campaign_array['answering_machine_detection'] == 0) )then
                fs_logger("notice","[auto_campaign.lua]IF MEANS MACHINE DETACT ")
                fs_logger("notice","[auto_campaign.lua]HangupCauseCode "..HangupCauseCode)
                session:execute("set", 'execute_on_answer=record_session $${recordings_dir}/${uuid}.wav')
                session:execute('set','amd_hangup=true')
                if(campaign_array ~= "" and campaign_array['amd_promptuuid'] ~= '')then
                		session:execute("playback","/usr/local/freeswitch/scripts/10682567-9747054d80a30e1e2375d6ee7c652231.wav")
				--session:execute("playback", upload_file_path.."/"..campaign_array['amd_promptuuid']..".wav");
				session:execute("hangup","NORMAL_CLEARING")
		end
                

        else



	
		fs_logger("notice","[auto_campaign.lua]ELSE MEANS HUMAN DETACT ")

		local auto_campaign = session:getVariable("sip_h_P-auto_campaign");
		fs_logger("notice","[auto_campaign.lua]auto_campaign "..auto_campaign)
		local campaign_uuid = session:getVariable("sip_h_P-campaign_uuid");
		fs_logger("notice","[auto_campaign.lua]campaign_uuid "..campaign_uuid)
		local tenant_uuid = session:getVariable("sip_h_P-tenant_uuid");
		fs_logger("notice","[auto_campaign.lua]tenant_uuid "..tenant_uuid)
		local user_uuid = session:getVariable("sip_h_P-user_uuid");
		fs_logger("notice","[auto_campaign.lua]auto_campaign "..user_uuid)
		local lead_number = session:getVariable("Caller-Destination-Number");
		fs_logger("notice","[auto_campaign.lua]lead_number "..lead_number)
		local lead_name = session:getVariable("sip_h_P-lead_name");
		fs_logger("notice","[auto_campaign.lua]lead_name "..lead_name)
		local tenant_domain = session:getVariable("sip_h_P-tenant_domain");
		fs_logger("notice","[auto_campaign.lua]tenant_domain "..tenant_domain)
		local variable_effective_caller_id_name = session:getVariable("variable_effective_caller_id_name");
		fs_logger("notice","[auto_campaign.lua]variable_effective_caller_id_name "..variable_effective_caller_id_name)

		local variable_effective_caller_id_number = session:getVariable("variable_effective_caller_id_number");
		fs_logger("notice","[auto_campaign.lua]variable_effective_caller_id_number "..variable_effective_caller_id_number)

		local uuid = session:getVariable("uuid");
		fs_logger("notice","[auto_campaign.lua]uuid "..uuid)
		maxlength = 10
		session:execute("info")
	--      session:execute("avmd_start","detection_mode=2,inbound_channel=1,outbound_channel=1")
	--      os.execute("sleep 10")
	--      session:execute("playback","/usr/share/freeswitch/scripts/10682567-9747054d80a30e1e2375d6ee7c652231.wav")
	--      session:execute("avmd_stop")
		local agent_available_flag = 1
		local tenant_query = {uuid=tenant_uuid}
		local tenant_cursor = tenant_collection:find(tenant_query)
		local tenant_array = ''
		for tenant_details in tenant_cursor:iterator() do
			tenant_array = tenant_details
		end
		
		if(tenant_array == '')then
			fs_logger("notice","[auto_campaign.lua::Tenant Not avaiable::")
		else
			fs_logger("notice","[auto_campaign.lua::Tenant avaiable::")
			if(tenant_array.concurrent_calls ~= nil and tenant_array.concurrent_calls ~= '' and tonumber(tenant_array.concurrent_calls) > 0) then
				session:execute('limit','hash inbound '..tenant_uuid..' '..tonumber(tenant_array.concurrent_calls)..' !USER_BUSY')
			end
		end        
		if(session:getVariable("amd_hangup") and session:getVariable("amd_hangup") == 'true')then
			session:execute("export","sip_h_X-amd_hangup="..session:getVariable("amd_hangup"))
			session:execute("set", 'sip_h_X-amd_hangup='..session:getVariable("amd_hangup"))
			--session:execute("answer")
			os.execute("sleep 2")
			--session:execute("sleep",2)
			if(campaign_array ~= "" and campaign_array['amd_promptuuid'] ~= '')then
				session:execute("playback", upload_file_path.."/"..campaign_array['amd_promptuuid']..".wav");
				session:execute("hangup","NORMAL_CLEARING")
			end
			return true
		end
	--      session:setVariable("ringback", "%(2000,4000,440,480)");
		if(campaign_array ~= '' and campaign_array['greeting_uuid'] ~= '')then
		        session:execute("set", "ringback="..upload_file_path.."/"..campaign_array['greeting_uuid']..".wav");

		end
		if(campaign_array ~= "" and campaign_array['recording'] == '0') then
		        recording_flag = 0
		        --session:execute('set',"sip_h_X-auto_campaign_recording="..recording_flag)
		        --session:execute('export',"sip_h_X-auto_campaign_recording="..recording_flag)
		end
	--[[
		repeat  
		        -- Create session2
		        retries = retries + 1;
		        if (retries % 2) then 
		            ostr2 = originate_str2;
		        else 
		            ostr2 = originate_str22; 
		        end
		        freeswitch.consoleLog("notice", "*********** Dialing: " .. ostr2 .. " Try: "..retries.." ***********\n");
		        session2 = freeswitch.Session(ostr2, session1);
		        local hcause = session2:hangupCause();
		        freeswitch.consoleLog("notice", "*********** Leg2: " .. hcause .. " Try: " .. retries .. " ***********\n");
		until not ((tonumber(currentTimestamp) < tonumber(futureTimestamp)) or tonumber(agent_available_flag) == 0)
		]]--
		local lead_update_filter = {lead_management_uuid = lead_uuid}
		local lead_originate_update_string = {
		        ['$set'] = {flag = '1'}
		}
		lead_originate_collection:update(lead_update_filter,lead_originate_update_string)
		local i = 0;
		
	--api = freeswitch.API();
	--fs_logger("notice","[auto_campaign.lua] uuid_hold toggle "..uuid)
	--reply = api:executeString("uuid_hold toggle "..uuid);
		while (session:ready() and tonumber(currentTimestamp) < tonumber(futureTimestamp)  and tonumber(agent_available_flag) == 1) do
	--      while (tonumber(currentTimestamp) < tonumber(futureTimestamp)) do               fs_logger("notice","[auto_campaign.lua]currentTimestamp "..currentTimestamp)
		        fs_logger("notice","[auto_campaign.lua]futureTimestamp "..futureTimestamp)
		        currentTimestamp = os.time()
		        fs_logger("notice","[auto_campaign.lua]agent_available_flag "..agent_available_flag)
		        local avaialble_agent_list = check_avaialble_agent(campaign_uuid,tenant_uuid)           --if(avaialble_agent_list ~= nil and avaialble_agent_list ~= '' and avaialble_agent_list.username ~= '' and avaialble_agent_list.agent_uuid ~= '')then
		        --fs_logger("notice","[auto_campaign.lua] uuid_hold toggle  adesh"..avaialble_agent_list.agent_uuid)
		        if(avaialble_agent_list ~= nil and avaialble_agent_list ~= '' and avaialble_agent_list.agent_uuid ~= '')then
		        local agent_live_status = check_aget_live_status(avaialble_agent_list.agent_uuid)
		        if(tonumber(agent_live_status) == 0)then
		                agent_available_flag = 0
	--                      fs_logger("notice","[auto_campaign.lua]avaialble_agent_list.username "..avaialble_agent_list.username)
		                local user_collection = mongo_collection_name:getCollection "user"
		                local user_query = {uuid = avaialble_agent_list.agent_uuid}
		                local user_data = user_collection:find(user_query)
		                local user_array = ''
		                for user_detail in user_data:iterator() do
		                	user_array = user_detail
		                end
		                if user_array == "" then
		                	fs_logger("notice","[auto_campaign.lua] user details not found ")
		                else
		                	fs_logger("notice","[auto_campaign.lua] user details found ")
		                	local customer_callerid_management_collection = mongo_collection_name:getCollection "customer_callerid_management"
				 	customer_caller_uuid = generateUUIDv4()
				 	threeway_agent_extension_uuid = user_array.default_extension
				 	local datatoinsert = {phone_number = lead_number,user_uuid = user_array.default_extension,uuid = customer_caller_uuid}
				 	customer_callerid_management_collection:insert(datatoinsert)
				 end
		                update_avaialble_agent(campaign_uuid,tenant_uuid,avaialble_agent_list.username)
	--                        os.execute("sleep 2")
		                fs_logger("notice","[auto_campaign.lua] uuid_hold toggle "..uuid)
	--reply = api:executeString("uuid_hold toggle "..uuid);
		                local lead_uuid = session:getVariable("sip_h_P-lead_uuid");
		                session:execute("export", 'sip_h_X-Custom-Callid='..session:getVariable("sip_call_id"))
		                session:execute("export", 'sip_h_X-Leaduuid='..lead_uuid)
		                session:execute("export", 'sip_h_X-Autocalltype=true')
		                session:execute("export", 'sip_h_P-callstart='..callstart)
		                session:execute("export", 'sip_h_X-lead_name='..lead_name)
		                session:execute("set", 'sip_h_X-Custom-Callid='..session:getVariable("sip_call_id"))
		                session:execute("set", 'sip_h_X-Leaduuid='..lead_uuid)
		                session:execute("set", 'sip_h_P-callstart='..callstart)
		                session:execute("set", 'sip_h_X-lead_name='..lead_name)
		                session:execute("export", 'threeway_agent_extension_uuid='..threeway_agent_extension_uuid)
		                session:execute("set", 'threeway_agent_extension_uuid='..threeway_agent_extension_uuid)
		                session:execute("set", 'hold_music=/usr/local/freeswitch/scripts/audio/call-queue.wav')
		                session:execute("export", 'hold_music=/usr/local/freeswitch/scripts/audio/call-queue.wav')
		                session:execute("set", 'sip_h_P-agent_uuid='..avaialble_agent_list.agent_uuid)
		                session:execute("set", 'effective_caller_id_name='..lead_number)
		                session:execute("set", 'effective_caller_id_number='..lead_number)
		                session:execute("set", 'sip_h_P-auto_campaign_originate='..avaialble_agent_list.auto_campaign_originate_uuid)
		                session:execute("export", 'execute_on_answer=lua auto_campaign_agent.lua')
		                --session:execute("export", 'execute_on_bridge=lua auto_campaign_agent.lua')
		                if(recording_flag == 0)then
		                      session:execute("set",'custom_recording=0')
		                      session:execute("export",'custom_recording=0')
		                      session:execute('set','recording_follow_transfer=true')
		                      session:execute('set','recording_directory=$${recordings_dir}/'..tenant_domain..'/'..record_date)
		                      session:execute('export','recording_directory=$${recordings_dir}/'..tenant_domain..'/'..record_date)
		                    --  session:execute("set", 'execute_on_answer=record_session $${recordings_dir}/${uuid}.wav')
		                end
				 session:execute('set','hangup_after_bridge=true')
				 session:execute('set','continue_on_fail=TRUE')
	--                      update_avaialble_agent(campaign_uuid,tenant_uuid,avaialble_agent_list.username)
	fs_logger("notice","[auto_campaign.lua]user/"..avaialble_agent_list.username.."@"..avaialble_agent_list.domain.."")
		                session:execute("bridge", 'user/'..avaialble_agent_list.username..'@'..avaialble_agent_list.domain..'')
	--                      session:execute("bridge", 'user/101@beltalk3.inextrix.com')
		                break;
		        end
		        end
		        os.execute("sleep 5")
		end 

	--session:execute("loop_playback", '+50 /usr/share/freeswitch/scripts/call-queue.wav')
	session:hangup();


	end
end
