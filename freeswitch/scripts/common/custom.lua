-- Load config
dofile("/usr/local/freeswitch/scripts/config.lua")
local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")

-- Common log function
function fs_logger(log_type, body_message)
	if tonumber(LOGGER_FLAG) == 0  then
		freeswitch.consoleLog(log_type, body_message .. "\n");
	end	
end



function header_xml()
	xml = {};
        table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
        table.insert(xml, [[<document type="freeswitch/xml">]]);
        table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
        table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
        table.insert(xml, [[<extension name="]]..destination_number..[[">]]);
        fs_logger("info","Generated XML:\n" .. destination_number)
        fs_logger("info","Generated XML:\n" .. originate_destination_number)
        table.insert(xml, [[<condition field="destination_number" expression="]]..skip_special_char(originate_destination_number)..[[">]]);
	table.insert(xml, [[<action application="set" data="effective_destination_number=]]..skip_special_char(destination_number)..[["/>]]);
	table.insert(xml, [[<action application="set" data="custom_destination_number=]]..skip_special_char(destination_number)..[["/>]]);
	table.insert(xml, [[<action application="set" data="sticky_agent_flag=]]..sticky_agent_flag..[["/>]]);
	table.insert(xml, [[<action application="export" data="original_destination_number=]]..skip_special_char(destination_number)..[["/>]]);
	if(tonumber(fail_call_flag) == 0)then
		local callstart = os.date("!%Y-%m-%d %H:%M:%S")
		table.insert(xml, [[<action application="set" data="authentication_type=]]..authentication_type..[["/>]]);	
		table.insert(xml, [[<action application="set" data="custom_callstart=]]..callstart..[["/>]]);	
		table.insert(xml, [[<action application="set" data="tenant_uuid=]]..caller_tenant_uuid..[["/>]]);
		if(tenant_info.concurrent_calls ~= nil and tenant_info.concurrent_calls ~= '' and tonumber(tenant_info.concurrent_calls) > 0) then
			table.insert(xml, [[<action application="limit" data="hash inbound ]]..caller_tenant_uuid..[[  ]]..tonumber(tenant_info.concurrent_calls)..[[ !USER_BUSY" />]]);		
		end
--		table.insert(xml, [[<action application="set" data="max_calls=1" inline="true"/>]]);
		if(from_domain ~= nil and from_domain ~= '')then
--			table.insert(xml, [[<action application="limit" data="db ]]..from_domain..[[ ${sip_auth_username} ${max_calls}"/>]]);
		end
		if(authentication_type == 'auth')then
		
			table.insert(xml, [[<action application="set" data="caller_uuid=]]..caller_uuid..[["/>]]);
			table.insert(xml, [[<action application="set" data="extension_uuid=]]..caller_uuid..[["/>]]);	
			table.insert(xml, [[<action application="set" data="user_uuid=]]..caller_user_uuid..[["/>]]);
		else
			if(ip_map_uuid ~= nil)then
				table.insert(xml, [[<action application="set" data="ip_map_uuid=]]..ip_map_uuid..[["/>]]);
			end
		end
	end
	table.insert(xml, [[<action application="set" data="ringback=%(2000,4000,440,480)"/>]])	
	if(params:getHeader("variable_sip_call_id") and params:getHeader("variable_sip_call_id") ~= nil)then
		table.insert(xml, [[<action application="export" data="custom_callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);
		table.insert(xml, [[<action application="export" data="sip_h_X-a_leg_call_uuid=]]..params:getHeader("variable_call_uuid")..[["/>]]);

		table.insert(xml, [[<action application="export" data="sip_h_X-custom_callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);
		table.insert(xml, [[<action application="set" data="sip_h_X-custom_callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);
--		table.insert(xml, [[<action application="export" data="sip_h_X-destination_number_harsh=]]..original_destination_number..[["/>]]);
--		table.insert(xml, [[<action application="set" data="sip_h_X-destination_number_harsh=]]..original_destination_number..[["/>]]);
		table.insert(xml, [[<action application="export" data="sip_bye_h_custom_callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);					
	end
	if(params:getHeader("variable_sip_from_user") and params:getHeader("variable_sip_from_user") ~= nil)then
		table.insert(xml, [[<action application="set" data="sip_user=]]..skip_plus_sign(params:getHeader("variable_sip_from_user"))..[["/>]]);
	end
	if(call_type == nil)then
		call_type = 'standard'
	end
	if(threeway_agent_extension_uuid ~= "")then
		table.insert(xml, [[<action application="set" data="threeway_agent_extension_uuid=]]..threeway_agent_extension_uuid..[["/>]]);	
	end
	table.insert(xml, [[<action application="set" data="hangup_after_bridge=true"/>]]);
	table.insert(xml, [[<action application="set" data="continue_on_fail=TRUE"/>]]);	
	table.insert(xml, [[<action application="set" data="call_type=]]..call_type..[["/>]]);
--	table.insert(xml, [[<action application="export" data="custom_callstart=]]..callstart..[["/>]]);	
--	table.insert(xml, [[<action application="export" data="custom_destination_number=]]..skip_special_char(destination_number)..[["/>]]);
	local tenant_name = "-"
	if(tenant_info ~= nil and tenant_info.tenant_name ~= nil and tenant_name ~= "")then
		tenant_name = tenant_info.tenant_name
	end
	local set_trunk_name = "-"
	if(display_trunk_name ~= nil and display_trunk_name ~= "")then
		set_trunk_name = display_trunk_name
	end
	local set_user = "-"
	if(caller_user_info ~= nil and caller_user_info.username ~= nil and caller_user_info.username ~= '' )then
		set_user = caller_user_info.username
	end
	--table.insert(xml, [[<action application="export" data="presence_data=tenant_uuid=]]..caller_tenant_uuid..[[,tenant=]]..tenant_name..[[,trunk=]]..set_trunk_name..[[,user=]]..set_user..[["/>]]);
--	table.insert(xml, [[<action application="export" data="presence_data=user_uuid=]]..caller_user_uuid..[["/>]]);
--	table.insert(xml, [[<action application="export" data="extension_uuid=]]..caller_uuid..[["/>]]);
	table.insert(xml, [[<action application="set" data="original_did_number=]]..skip_special_char(destination_number)..[["/>]]);
	table.insert(xml, [[<action application="set" data="hold_music=/usr/local/freeswitch/scripts/audio/call-queue.wav"/>]]);	
	table.insert(xml, [[<action application="bridge_export" data="hold_music=/usr/local/freeswitch/scripts/audio/call-queue.wav"/>]]);	
		
if((tonumber(caller_user_recording_flag) == 0 and tonumber(caller_sip_recording_flag) == 0 )or authentication_type == 'acl')then
	custom_record_flag = 1
	table.insert(xml, [[<action application="set" data="custom_recording=0"/>]]);
	local currentDateTime = os.date("%Y-%m-%d_%H:%M:%S")
	local currentdate = os.date("%Y-%m-%d")
	currentDateTime = string.gsub(currentDateTime, " ", "_")
	recording_filename = destination_number.."_${uuid}.wav"
	if(call_type == 'did')then
		local callerid_number_recording = params:getHeader("Caller-Caller-ID-Number")
		recording_filename = currentdate.."/"..callerid_number_recording.."_"..currentDateTime.."_${uuid}.wav"
	else
		recording_filename = currentdate.."/"..destination_number.."_"..currentDateTime.."_${uuid}.wav"
	end
	fs_logger("info","adesh this is coming in where user is 0 and sip is 0")
	fs_logger("info","recording file n XML:" ..recording_filename)
--table.insert(xml, [[<action application="export" data="nolocal:execute_on_answer=record_session $${recordings_dir}/]]..recording_filename..[["/>]]);
	table.insert(xml, [[<action application="set" data="recording_follow_transfer=true"/>]]);
	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/]]..from_domain..[[/]]..recording_filename..[["/>]]);
	--table.insert(xml, [[<action application="export" data="api_on_answer=uuid_record ${uuid} start $${recordings_dir}/${uuid}.wav"/>]]);
elseif((tonumber(caller_user_recording_flag) == 1 and tonumber(caller_sip_recording_flag) == 0 )or authentication_type == 'acl')then
	custom_record_flag = 1
	table.insert(xml, [[<action application="set" data="custom_recording=0"/>]]);
	local currentDateTime = os.date("%Y-%m-%d_%H:%M:%S")
	local currentdate = os.date("%Y-%m-%d")
	currentDateTime = string.gsub(currentDateTime, " ", "_")
	recording_filename = destination_number.."_${uuid}.wav"
	if(call_type == 'did')then
		local callerid_number_recording = params:getHeader("Caller-Caller-ID-Number")
		recording_filename = currentdate.."/"..callerid_number_recording.."_"..currentDateTime.."_${uuid}.wav"
	else
		recording_filename = currentdate.."/"..destination_number.."_"..currentDateTime.."_${uuid}.wav"
	end
	fs_logger("info","adesh this is coming in where user is 1 and sip is 0")
	fs_logger("info","recording file n XML:" ..recording_filename)
--table.insert(xml, [[<action application="export" data="nolocal:execute_on_answer=record_session $${recordings_dir}/]]..recording_filename..[["/>]]);
	table.insert(xml, [[<action application="set" data="recording_follow_transfer=true"/>]]);
	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/]]..from_domain..[[/]]..recording_filename..[["/>]]);
elseif((tonumber(caller_user_recording_flag) == 0 and tonumber(caller_sip_recording_flag) == 1 ) or authentication_type == 'acl')then
	custom_record_flag = 1
	table.insert(xml, [[<action application="set" data="custom_recording=0"/>]]);
	local currentDateTime = os.date("%Y-%m-%d_%H:%M:%S")
	local currentdate = os.date("%Y-%m-%d")
	currentDateTime = string.gsub(currentDateTime, " ", "_")
	recording_filename = destination_number.."_${uuid}.wav"
	if(call_type == 'did')then
		local callerid_number_recording = params:getHeader("Caller-Caller-ID-Number")
		recording_filename = currentdate.."/"..callerid_number_recording.."_"..currentDateTime.."_${uuid}.wav"
	else
		recording_filename = currentdate.."/"..destination_number.."_"..currentDateTime.."_${uuid}.wav"
	end
	fs_logger("info","adesh this is coming in where user is 0 and sip is 1")
	fs_logger("info","recording file n XML:" ..recording_filename)
--table.insert(xml, [[<action application="export" data="nolocal:execute_on_answer=record_session $${recordings_dir}/]]..recording_filename..[["/>]]);
	table.insert(xml, [[<action application="set" data="recording_follow_transfer=true"/>]]);
	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/]]..from_domain..[[/]]..recording_filename..[["/>]]);
elseif((tonumber(caller_user_recording_flag) == 1 and tonumber(caller_sip_recording_flag) == 1 ) and authentication_type == 'acl')then
	custom_record_flag = 1
	table.insert(xml, [[<action application="set" data="custom_recording=0"/>]]);
	local currentDateTime = os.date("%Y-%m-%d_%H:%M:%S")
	local currentdate = os.date("%Y-%m-%d")
	currentDateTime = string.gsub(currentDateTime, " ", "_")
	recording_filename = destination_number.."_${uuid}.wav"
	if(call_type == 'did')then
		local callerid_number_recording = params:getHeader("Caller-Caller-ID-Number")
		recording_filename = currentdate.."/"..callerid_number_recording.."_"..currentDateTime.."_${uuid}.wav"
	else
		recording_filename = currentdate.."/"..destination_number.."_"..currentDateTime.."_${uuid}.wav"
	end
	fs_logger("info","adesh this is coming in where both is 1")
	fs_logger("info","recording file n XML:" ..recording_filename)
--table.insert(xml, [[<action application="export" data="nolocal:execute_on_answer=record_session $${recordings_dir}/]]..recording_filename..[["/>]]);
	table.insert(xml, [[<action application="set" data="recording_follow_transfer=true"/>]]);
	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/]]..from_domain..[[/]]..recording_filename..[["/>]]);
else	
	fs_logger("info","adesh this is coming in else condition")
		custom_record_flag = 1
	table.insert(xml, [[<action application="set" data="custom_recording=1"/>]]);
end
	table.insert(xml, [[<action application="set" data="webphonetransfer=]]..webphonetransfer..[["/>]]);
--if(sticky_agent_str ~= '')then
--	table.insert(xml, [[<action application="bridge" data="]]..sticky_agent_str..[["/>]]);
--end
	table.insert(xml, [[<action application="bind_meta_app" data="1 b s execute_extension::attended_xfer XML features"/>)]]);
	table.insert(xml, [[<action application="bind_meta_app" data="2 a s execute_extension::attended_xfer XML features"/>)]]);
--	table.insert(xml, [[<action application="bind_meta_app" data="3 a a execute_extension::attended_xfer XML features"/>)]]);	
end

function footer_xml()
        table.insert(xml, [[</condition>]]);
        table.insert(xml, [[</extension>]]);
        table.insert(xml, [[</context>]]);
        table.insert(xml, [[</section>]]);
        table.insert(xml, [[</document>]]);
        XML_STRING = table.concat(xml, "\n");
	fs_logger("info","Generated XML:\n" .. XML_STRING)
end
function header_xml_time_condition()
	xml = {};
        table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
        table.insert(xml, [[<document type="freeswitch/xml">]]);
        table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
        table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
	table.insert(xml, [[<action application="set" data="hangup_after_bridge=true"/>]]);
	table.insert(xml, [[<action application="set" data="original_did_number=]]..skip_special_char(destination_number)..[["/>]]);
	table.insert(xml, [[<action application="set" data="hangup_after_bridge=true"/>]]);
	table.insert(xml, [[<action application="set" data="continue_on_fail=TRUE"/>]]);
	table.insert(xml, [[<action application="bind_meta_app" data="1 b s execute_extension::attended_xfer XML features"/>)]]);	
	table.insert(xml, [[<action application="bind_meta_app" data="2 a s execute_extension::attended_xfer XML features"/>)]]);
end

function footer_xml_time_condition()
        table.insert(xml, [[</context>]]);
        table.insert(xml, [[</section>]]);
        table.insert(xml, [[</document>]]);
        XML_STRING = table.concat(xml, "\n");
	fs_logger("info","Generated XML:\n" .. XML_STRING)
end
-- Set callerid to override in calls
function callerid_xml(type)
	local rotuting_type = type or nil
	if(is_did_number ~= nil and tonumber(is_did_number) == 0)then
		if callerid_number == nil or callerid_number == '' then
			callerid_number = params:getHeader("Caller-Caller-ID-Number")
		end	
		local callerid = skip_special_char(callerid_number)
		local lead_array = get_lead_info(callerid,caller_tenant_uuid)
		if (lead_array == '') then
		fs_logger("warning","[common/custom.lua:: Lead INFO: NIL::")
		else
			
			if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
				lead_name = lead_array.first_name.."__"..lead_array.last_name
			else
				lead_name = lead_array.first_name
			end
		end

		if(lead_name ~= nil and lead_name ~= "")then
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_name=]]..lead_name..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_uuid=]]..lead_array.lead_management_uuid..[["/>]]);
			table.insert(xml, [[<action application="export" data="sip_h_X-Leaduuid=]]..lead_array.lead_management_uuid..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-Leaduuid=]]..lead_array.lead_management_uuid..[["/>]]);
		end
		if(params:getHeader("variable_sip_h_X-Leaduuid") and params:getHeader("variable_sip_h_X-Leaduuid") ~= '')then
			fs_logger("info","Leaduuid for transfer:"..params:getHeader("variable_sip_h_X-Leaduuid"))		
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_uuid=]]..params:getHeader("variable_sip_h_X-Leaduuid")..[["/>]]);
			table.insert(xml, [[<action application="export" data="sip_h_X-Leaduuid=]]..params:getHeader("variable_sip_h_X-Leaduuid")..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-Leaduuid=]]..params:getHeader("variable_sip_h_X-Leaduuid")..[["/>]]);		
		end
	end
        if (callerid_name ~= '' and callerid_name ~= '<null>' and callerid_name ~= nil)  then
                table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..callerid_name..[["/>]]);
        end
        if (callerid_number ~= '' and callerid_number ~= '<null>' and callerid_number ~= nil)  then
                table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..callerid_number..[["/>]]);
        end
        if(rotuting_type == nil)then
	        if(params:getHeader("variable_sip_h_P-effective_caller_id_name") and params:getHeader("variable_sip_h_P-effective_caller_id_name") ~= nil and params:getHeader("variable_sip_h_P-effective_caller_id_name") ~= "")then
			fs_logger("info","WITH H HEADER:"..params:getHeader("variable_sip_h_P-effective_caller_id_name"))
               	table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..params:getHeader("variable_sip_h_P-effective_caller_id_name")..[["/>]]);  
			table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..params:getHeader("variable_sip_h_P-effective_caller_id_name")..[["/>]]);     
	        end
	        if(params:getHeader("variable_effective_caller_id_number") and params:getHeader("variable_effective_caller_id_number") ~= nil and params:getHeader("variable_effective_caller_id_number") ~= "")then
			fs_logger("info","WITH H HEADER:++++"..params:getHeader("variable_effective_caller_id_number"))
			table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..params:getHeader("variable_effective_caller_id_number")..[["/>]]);  
                  	table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..params:getHeader("variable_effective_caller_id_number")..[["/>]]);     
		end
        end
	campaign_uuid = params:getHeader("variable_sip_h_X-selectedcampaignuuid")
	campaign_flag = params:getHeader('variable_sip_h_X-campaign_flag')
	--campaign_uuid = "236195ce-2999-4a14-b2b7-22f28d558e7d"
			fs_logger("info","WITH H three_way_callerid_flag:"..three_way_callerid_flag)	
	if(campaign_uuid ~= nil and campaign_uuid ~= '' and three_way_callerid_flag == 0)then
		fs_logger("info","WITH CAMPAIGN:\n")
		local callerid_management_collection = mongo_collection_name:getCollection "callerid_management"
		local currenttimestamp = os.time()
		fs_logger("info","Generated XML:current timestamp"..currenttimestamp)
		local current_date = os.date("%Y-%m-%d %H:%M:%S", currenttimestamp)
		fs_logger("info","Generated XML:current date"..current_date)
		local callerid_query = {campaign_uuid = campaign_uuid}
		local callerid_data = callerid_management_collection:find(callerid_query)
		local callerid_details  = {}
		local callerid_key = 1
		for callerid_data in callerid_data:iterator() do
			callerid_details[callerid_key] = callerid_data
			callerid_key = callerid_key + 1
		end
		callerid_count = callerid_key - 1
		new_callerid_flag = false
		if (callerid_details ~= nil and callerid_details[tonumber(callerid_count)] ~= nil)then
			fs_logger("info","Generated XML: later_date"..callerid_details[tonumber(callerid_count)]['date'])
			local timestamp = os.time(os.date("*t", os.time{year=string.sub(callerid_details[tonumber(callerid_count)]['date'], 1, 4),month=string.sub(callerid_details[tonumber(callerid_count)]['date'], 6, 7),day=string.sub(callerid_details[tonumber(callerid_count)]['date'], 9, 10),hour=string.sub(callerid_details[tonumber(callerid_count)]['date'], 12, 13),min=string.sub(callerid_details[tonumber(callerid_count)]['date'], 15, 16),sec=string.sub(callerid_details[tonumber(callerid_count)]['date'], 18, 19)}))
			fs_logger("info","Generated XML:later timezone"..timestamp)
			if (timestamp < currenttimestamp)then
				new_callerid_flag = true
			end
		else
			new_callerid_flag = true		
		end
		if new_callerid_flag == true then
			campaign_caller_id = get_campaign_callerid(campaign_uuid,campaign_flag)
		else
			campaign_caller_id = callerid_details[tonumber(callerid_count)]['caller_id']	
		end	
		fs_logger("info","Generated XML:adesh123"..campaign_caller_id)
		if(campaign_caller_id ~= '' and campaign_caller_id ~= nil)then
		         table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..campaign_caller_id..[["/>]]);  
		         table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..campaign_caller_id..[["/>]]); 	
		end
	elseif(three_way_callerid_flag == 1 and threeway_agent_extension ~= "")then
		table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..threeway_agent_extension..[["/>]]);  
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..threeway_agent_extension..[["/>]]);
	elseif(three_way_callerid_flag == 2 and custom_caller_id ~= "") then
		 table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..custom_caller_id..[["/>]]);  
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..custom_caller_id..[["/>]]);	
	end
	previous_caller_id_number = params:getHeader("variable_sip_h_X-previous_caller_id_number")
	if(previous_caller_id_number ~= nil and previous_caller_id_number ~= '')then
		fs_logger("warning","[common/custom.lua:: previous_caller_id_number::"..previous_caller_id_number)
		 table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..previous_caller_id_number..[["/>]]);  
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..previous_caller_id_number..[["/>]]);	
	end	
		if callerid_name == nil or callerid_name == "" or callerid_number == nil or callerid_number == '' then
			callerid_name = params:getHeader("Caller-Caller-ID-Name")
			callerid_number = params:getHeader("Caller-Caller-ID-Number")
		end
	
        return xml
end
function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end 

function explode(div,str)
    if (div=='') then return false end
    local pos,arr = 0,{}
    for st,sp in function() return string.find(str,div,pos,true) end do
        table.insert(arr,string.sub(str,pos,st-1))
        pos = sp + 1
    end
    table.insert(arr,string.sub(str,pos))
    return arr
end

function get_lead_info(callerid_number,tenant_uuid)
	local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
	local query = { custom_phone_number = callerid_number,tenant_uuid = tenant_uuid}
	local cursor = lead_mgmt_collection:find(query)
	lead_array = ''
	lead_name = ''
	for lead_details in cursor:iterator() do
		lead_array = lead_details;
	end
	return lead_array;

end

function get_lead_info_for_queue(callerid_number)
	local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
	local query = { custom_phone_number = callerid_number,tenant_uuid = caller_tenant_uuid }
	local cursor = lead_mgmt_collection:find(query)
	lead_array = ''
	lead_name = ''
	for lead_details in cursor:iterator() do
		lead_array = lead_details;
	end
	if (lead_array == '') then
		fs_logger("warning","[common/custom.lua:: Lead INFO: NIL::")
	else
		if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
			lead_name = lead_array.first_name.."__"..lead_array.last_name
		else
			lead_name = lead_array.first_name
		end
	end
	return lead_array;

end
function get_lead_info_for_queue_custom(callerid_number,caller_tenant_uuid)
        local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
        local query = { custom_phone_number = callerid_number,tenant_uuid = caller_tenant_uuid }
        local cursor = lead_mgmt_collection:find(query)
        lead_array = ''
        lead_name = ''
        for lead_details in cursor:iterator() do
                lead_array = lead_details;
        end
        if (lead_array == '') then
                fs_logger("warning","[common/custom.lua:: Lead INFO: NIL::")
        else
                if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
                        lead_name = lead_array.first_name.."__"..lead_array.last_name
                else
                        lead_name = lead_array.first_name
                end
        end
        return lead_array;

end
function get_time_zone_info(time_zone_uuid)
	local timezone_collection = mongo_collection_name:getCollection "timezone"
	local query = { uuid = time_zone_uuid }
	local projection = { timezone_name = true, _id = false }
	local cursor = timezone_collection:find(query, { projection = projection })
	timezone_array = ''
	for  timezone_details in cursor:iterator() do
		timezone_array = timezone_details;
	end
		timezone_name = ''
	if(timezone_array == '')then
		fs_logger("warning","[common/custom.lua:: Timezone: NIL::")
	else
		timezone_name = timezone_array.timezone_name
	end
	return timezone_name;
end
function get_tenant_info(caller_tenant_uuid)
	local tenant_collection = mongo_collection_name:getCollection "tenant"
	local query = { uuid = caller_tenant_uuid, status = '0' }
	local cursor = tenant_collection:find(query)
	tenant_array = ''
	for tenant_details in cursor:iterator() do
		tenant_array = tenant_details;
	end
	if(tenant_array == '')then
		fs_logger("warning","[common/custom.lua:: Tenant INFO: NIL::")
	end
	return tenant_array;
end
function get_caller_info(caller_uuid)
	local caller_collection = mongo_collection_name:getCollection "extensions"
	local query = { uuid = caller_uuid, status = '0',tenant_uuid = caller_tenant_uuid }
	local cursor = caller_collection:find(query)
	caller_array = ''
	for caller_details in cursor:iterator() do
		caller_array = caller_details;
	end
	if(caller_array == '')then
		fs_logger("warning","[common/custom.lua:: Caller INFO: NIL::")
	end
	return caller_array;
end
function check_extension_info(destination_number,where_type)
	local extension_collection = mongo_collection_name:getCollection "extensions"
	local query = ''
	if(where_type)then
		query = { uuid = destination_number, status = '0', tenant_uuid = caller_tenant_uuid}
	else
		query = { username = destination_number, status = '0', tenant_uuid = caller_tenant_uuid}
	end
	local cursor = extension_collection:find(query)
	sip_destination_array = ''
	for extension_details in cursor:iterator() do
		sip_destination_array = extension_details;
	end
	is_extensions = 1
	if(sip_destination_array == '')then
		fs_logger("warning","[common/custom.lua:: SIP Destination Array: NIL::")
	else
		is_extensions = 0
	end
	return is_extensions;
end
function check_did_info(destination_number)
	local did_collection = mongo_collection_name:getCollection "did"
	local query = { number = ''..destination_number..'', status = '0', tenant_uuid = caller_tenant_uuid}
	local cursor = did_collection:find(query)
	did_destination_array = ''
	for did_details in cursor:iterator() do
		did_destination_array = did_details;
	end
	is_did_number = 1
	if(did_destination_array == '')then
		fs_logger("warning","[common/custom.lua:: DID Destination Array: NIL::")
	else
		is_did_number = 0
	end
	return is_did_number;
end
function check_acl_did_info(destination_number)
	local did_collection = mongo_collection_name:getCollection "did"
	local query = { number = ''..destination_number..'', status = '0'}
	local cursor = did_collection:find(query)
	did_acl_destination_array = ''
	for did_details in cursor:iterator() do
		did_acl_destination_array = did_details;
	end
	if(did_acl_destination_array == '')then
		fs_logger("warning","[common/custom.lua:: DID ACL Destination Array: NIL::")
	end
	return did_acl_destination_array;
end
function custom_routing_forwarding(custom_routing_type,custom_routing_uuid)
	did_routing_uuid = custom_routing_uuid
-- We check routing type based on we will route call on perticular features for Extension:1, IVR:2, Time-Condtion:3, Conference:4, Call Queue:5, RG:6, Voicemail:7, PSTN:8, External User:9, Playback:10 (We will take flag one by one)
	if(tonumber(custom_routing_type) == 0)then
		fs_logger("warning","[dialplan/custom.lua][XML_STRING] DID Routing NOT FOUND")
		err =  "DID Routing NOT FOUND";
		return nil, err
	end

	--FOR Extension
	if(tonumber(custom_routing_type) == 1)then
		is_extensions = check_extension_info(did_routing_uuid,'uuid');
		if(tonumber(is_extensions) == 0)then
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/extensions.lua\n");
			dofile(scripts_dir .. "dialplan/extensions.lua");
		else
			fs_logger("warning","[common/custom.lua:: USER Is Inactive/deleted.")
			dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
			return
		end
	end
	--FOR IVR
	if(tonumber(custom_routing_type) == 2)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/ivr.lua\n");
		dofile(scripts_dir .. "dialplan/ivr.lua");
	end
	--FOR TIME-CONDITION
	if(tonumber(custom_routing_type) == 3)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/time_condition.lua\n");
		dofile(scripts_dir .. "dialplan/time_condition.lua");
	end
	--FOR CONFERENCE
	if(tonumber(custom_routing_type) == 4)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/conference.lua\n");
		dofile(scripts_dir .. "dialplan/conference.lua");
	end
	--FOR CALL QUEUE
	if(tonumber(custom_routing_type) == 5)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/call_queue.lua\n");
		dofile(scripts_dir .. "dialplan/call_queue.lua");
	end
	--FOR RING-GROUP
	if(tonumber(custom_routing_type) == 6)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/ring_group.lua\n");
		dofile(scripts_dir .. "dialplan/ring_group.lua");
	end
	--FOR VOICEMAIL
	if(tonumber(custom_routing_type) == 7)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/voicemail_generate.lua\n");
		dofile(scripts_dir .. "dialplan/voicemail_generate.lua");
	end
	--FOR PSTN
	if(tonumber(custom_routing_type) == 8)then
		pstn_destination_number = custom_routing_uuid
		if(authentication_type == 'auth')then		
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/outbound_call.lua\n");
			dofile(scripts_dir .. "dialplan/outbound_call.lua");
		else		
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/acl_outbound_call.lua\n");
			dofile(scripts_dir .. "dialplan/acl_outbound_call.lua");
		end
	end
	--FOR External User
	if(tonumber(custom_routing_type) == 9)then
		local external_user_array = get_userinfo(custom_routing_uuid)
		if(external_user_array == nil or external_user_array == '' or external_user_array.default_extension == '' or tonumber(external_user_array.extension_type) == 0)then
			hangup_cause = "NO_ROUTE_DESTINATION";
			fail_audio_file = sounds_dir..'pbx/badnumber.wav';
			fs_logger("warning","[index/custom.lua:: Outgoing rules Not Set1")
			dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
			return true;
		else
			pstn_destination_number = external_user_array.default_extension
			fs_logger("notice", "[custom.lua]External USER PSTN Number::"..pstn_destination_number);
		end
		if(authentication_type == 'auth')then
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/external_user.lua\n");
			dofile(scripts_dir .. "dialplan/external_user.lua");
		else		
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/acl_outbound_call.lua\n");
			dofile(scripts_dir .. "dialplan/acl_outbound_call.lua");
		end
	end
	--FOR Playback
	if(tonumber(custom_routing_type) == 10)then
		fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/playback.lua\n");
		dofile(scripts_dir .. "dialplan/playback.lua");
	end
	if(tonumber(custom_routing_type) == 12)then
                fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/"..custom_routing_uuid..".lua\n");
                header_xml()
                table.insert(xml, [[<action application="answer"/>]])
                table.insert(xml, [[<action application="lua" data="]]..scripts_dir..[[dialplan/]]..custom_routing_uuid..[[.lua"/>]])
                footer_xml()
                --dofile(scripts_dir .. "dialplan/"..custom_routing_uuid..".lua");
        end
end
-- Adding slash \ if number starting with +. 
function skip_special_char(destination_number)
	fs_logger("info","Generated XML:\n" .. destination_number)
    destination_number = destination_number:gsub("%s+", "")
    local dnumber = destination_number
	local dfirst =  string.match(dnumber, "^(.)")
	if (dfirst == "+" or dfirst == "*") then
		dnumber = string.gsub(dnumber, "+", "")
	end
    return dnumber
end

function check_feature_code(destination_number)
	local feature_code_collection = mongo_collection_name:getCollection "feature_code"
	local query = ''
	query = { feature_code = ''..destination_number..'', tenant_uuid = caller_tenant_uuid}
	local cursor = feature_code_collection:find(query)
	feature_code_array = ''
	for feature_code_details in cursor:iterator() do
		feature_code_array = feature_code_details;
	end
	is_feature_code = 1
	if(feature_code_array == '')then
		fs_logger("warning","[common/custom.lua:: Feature code not found: NIL::")
	else
		is_feature_code = 0
	end
	return is_feature_code;
end

function get_userinfo(user_uuid)

	local user_collection = mongo_collection_name:getCollection "user"
	local query = { uuid = user_uuid }
	local cursor = user_collection:find(query)
	user_array = ''
	for  user_details in cursor:iterator() do
		user_array = user_details;
	end
	if(user_array == '')then
		fs_logger("warning","[common/custom.lua:: USER is NIL::")
	end
	return user_array;

end
-- Do number translation 
function do_number_translation(number_translation,custom_destination_number)
    local tmp

    tmp = split(number_translation,",")
    for tmp_key,tmp_value in pairs(tmp) do
      tmp_value = string.gsub(tmp_value, "\"", "")
      tmp_str = split(tmp_value,"/")      
      if(tmp_str[1] == '' or tmp_str[1] == nil)then
	return custom_destination_number
      end
      local prefix = string.sub(custom_destination_number,0,string.len(tmp_str[1]));
      if (prefix == tmp_str[1] or tmp_str[1] == '*') then
	   fs_logger("notice","[common/custom.lua::][DONUMBERTRANSLATION] Before Localization : " .. custom_destination_number)
		if(tmp_str[2] ~= nil) then
            if (tmp_str[2] == '*') then
    			custom_destination_number = string.sub(custom_destination_number,(string.len(tmp_str[1])+1))
            else
                if (tmp_str[1] == '*') then
        			custom_destination_number = tmp_str[2] .. custom_destination_number
                else
        			custom_destination_number = tmp_str[2] .. string.sub(custom_destination_number,(string.len(tmp_str[1])+1))
                end
            end
		else
		    custom_destination_number = string.sub(custom_destination_number,(string.len(tmp_str[1])+1))
		end
	   fs_logger("notice","[common/custom.lua::][DONUMBERTRANSLATION] After Localization : " .. custom_destination_number)
      end
    end
    return custom_destination_number
end

function get_trunk_info(trunk_uuid)
local trunk_collection = mongo_collection_name:getCollection "trunk"
local projection = { name = true, _id = false }
local query = { uuid =trunk_uuid,status='0' }
local cursor = trunk_collection:find(query, { projection = projection })
	trunk_info_array = ''
	for trunk_info_details in cursor:iterator() do
		trunk_info_array = trunk_info_details;
	end
	if(trunk_info_array == '')then
		fs_logger("warning","[common/custom.lua:: Trunk not found for "..trunk_uuid.." NIL::")
	end
	return trunk_info_array.name;
end
 function get_trim_value (s)
 	return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
 end
 
function get_campaign_callerid(campaign_uuid,campaign_flag)
	local return_caller_id =""
	local outbound_campaign_collection = mongo_collection_name:getCollection "outbound_campaign"
	local callerid_management_collection = mongo_collection_name:getCollection "callerid_management"
	local inbound_campaign_collection = mongo_collection_name:getCollection "inbound_campaign"
	local blended_campaign_collection = mongo_collection_name:getCollection "blended_campaign"
	local currenttimestamp = os.time()
	local current_date = os.date("%Y-%m-%d %H:%M:%S", currenttimestamp)
	local new_callerid_uuid = generateUUIDv4()
	if (is_did_number ~= nil and is_did_number == 0)then
		local query = { uuid = campaign_uuid }
		local cursor = inbound_campaign_collection:find(query)
		inbound_campaign_array = ''
		for  inbound_campaign_details in cursor:iterator() do
			inbound_campaign_array = inbound_campaign_details;
		end
		if(inbound_campaign_array == '')then
			fs_logger("warning","[common/custom.lua:: Inbound Campaign is NIL::")
		else
			local tenminuteaftertimestamp = currenttimestamp + (tonumber(inbound_campaign_array.caller_id_time) * 60)
			local tenminuteafterdate = os.date("%Y-%m-%d %H:%M:%S", tenminuteaftertimestamp)
			call_id_type = inbound_campaign_array.call_id_type
			
			if(tonumber(call_id_type) == 0 and inbound_campaign_array.call_id_value ~= '')then
				return_caller_id = inbound_campaign_array.call_id_value
				local datatoinsert = {caller_id = return_caller_id,campaign_uuid = inbound_campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 1 and inbound_campaign_array.call_id_value ~= '')then
				caller_id_group_uuid = inbound_campaign_array.call_id_value
				return_caller_id = get_random_caller_id(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = inbound_campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end	
			if(tonumber(call_id_type) == 2 and inbound_campaign_array.call_id_value ~= '')then
				caller_id_group_uuid = inbound_campaign_array.call_id_value
				return_caller_id = get_sequence_base_callerid(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = inbound_campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 3 and inbound_campaign_array.call_id_value ~= '')then
				caller_id_group_uuid = inbound_campaign_array.call_id_value
				return_caller_id = get_prefix_base_caller_id(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = inbound_campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 4)then
				return_caller_id = get_random_plus_destination()
			end
		end
	else
		campaign_array = ''
		if(campaign_flag == 'blended')then
				local query = {uuid = campaign_uuid}
				local cursor = blended_campaign_collection:find(query)
				for blended_campaign_details in cursor:iterator() do
						campaign_array = blended_campaign_details;
				end
		else
				local query = { uuid = campaign_uuid }
				local cursor = outbound_campaign_collection:find(query)
				for  outbound_campaign_details in cursor:iterator() do
						campaign_array = outbound_campaign_details;
				end
		end
		if(campaign_array == '')then
			fs_logger("warning","[common/custom.lua:: Outbound Campaign is NIL::")
		else

			if(campaign_array and campaign_array.caller_id_time ~= nil and campaign_array.caller_id_time ~= "")then
				local tenminuteaftertimestamp = currenttimestamp + (tonumber(campaign_array.caller_id_time) * 60)
			else
				local tenminuteaftertimestamp = currenttimestamp + (60 * 60)			
			end
			local tenminuteafterdate = os.date("%Y-%m-%d %H:%M:%S", tenminuteaftertimestamp)
			call_id_type = campaign_array.call_id_type
			if(tonumber(call_id_type) == 0 and campaign_array.call_id_value ~= '')then
				return_caller_id = campaign_array.call_id_value
				local datatoinsert = {caller_id = return_caller_id,campaign_uuid = campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 1 and campaign_array.call_id_value ~= '')then
				caller_id_group_uuid = campaign_array.call_id_value
				return_caller_id = get_random_caller_id(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end	
			if(tonumber(call_id_type) == 2 and campaign_array.call_id_value ~= '')then
				--PENDING
				caller_id_group_uuid = campaign_array.call_id_value
				return_caller_id = get_sequence_base_callerid(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 3 and campaign_array.call_id_value ~= '')then
				caller_id_group_uuid = campaign_array.call_id_value
				return_caller_id = get_prefix_base_caller_id(caller_id_group_uuid)
				local datatoinsert = {caller_id_group_uuid = caller_id_group_uuid,caller_id = return_caller_id,campaign_uuid = campaign_array.uuid,date = tenminuteafterdate,uuid = new_callerid_uuid}
				callerid_management_collection:insert(datatoinsert)
			end
			if(tonumber(call_id_type) == 4)then
				
				return_caller_id = get_random_plus_destination()
			end
		end
	end
		
		
		
	return return_caller_id;
end
function get_prefix_base_caller_id(caller_id_group_uuid)
	local caller_ids_collection = mongo_collection_name:getCollection "caller_ids"
	local projection = { caller_id = true, _id = false }
	local call_id_destination_number = destination_number
	local caller_id_find = 0
	local prefix_base_caller_id = ''
	while string.len(call_id_destination_number) > 0 do
		local pattern = call_id_destination_number
		local query = { caller_id_group_uuid= caller_id_group_uuid,caller_id = { ["$regex"] = pattern, ["$options"] = "i" } }
		local prefix_len = 0
		local cursor = caller_ids_collection:find(query, { projection = projection })
			caller_id_array = ''
			for caller_id_details in cursor:iterator() do
				caller_id_array = caller_id_details;
				if(prefix_len == 0 or prefix_len < string.len(caller_id_array.caller_id))then
					prefix_len = string.len(caller_id_array.caller_id)
					prefix_base_caller_id = caller_id_array.caller_id
					caller_id_find = 1
					fs_logger("warning","[common/custom.lua:: Prefix base caller id match"..prefix_base_caller_id)
				end
			end
		if(caller_id_find == 1)then break; end
		call_id_destination_number = call_id_destination_number:sub(1, -2)
	end
		fs_logger("warning","[common/custom.lua:: Prefix base caller id match"..prefix_base_caller_id)
	return prefix_base_caller_id
end
function get_random_caller_id(caller_id_group_uuid)
	fs_logger("info","Generated XML:adesh123"..caller_id_group_uuid)
	local random_caller_id = ''
	local caller_ids_collection = mongo_collection_name:getCollection "caller_ids"
	local str=string.format([[
	[
		        { "$match": 
		                       {
		                                       "caller_id_group_uuid":"%s"
		                       }
		        },{ "$sample": { "size": 1 } }
	]
	]],caller_id_group_uuid)
	fs_logger("warning","[common/custom.lua:: random caller id nil::"..str)
	query=mongo.BSON(str)
	local cursor = caller_ids_collection:aggregate(query)
	random_caller_array = ''
	for  random_caller_details in cursor:iterator() do
		random_caller_array = random_caller_details;
	end
	if(random_caller_array == '')then
		fs_logger("warning","[common/custom.lua:: random caller id nil::")
	else
	
		fs_logger("warning","[common/custom.lua::Random caller id"..random_caller_id)
		random_caller_id = random_caller_array.caller_id
	end
	return random_caller_id
end

function get_sequence_base_callerid(callerid_group_uuid)
	fs_logger("warning","[common/custom.lua::Sequence base caller id"..callerid_group_uuid)
	

	 local callerid_sequence_db = mongo_collection_name:getCollection "callerid_sequence_management"
	 local callerid_query = {caller_id_group_uuid = callerid_group_uuid}
	 local callerid_sequence_data = callerid_sequence_db:find(callerid_query)
	 local callerid_sequence_detail = {}
	 local callerid_sequence_key = 1
	 local sequence_callerid_uuid = generateUUIDv4()
	 for callerid_sequence_data in callerid_sequence_data:iterator() do
		 callerid_sequence_detail[callerid_sequence_key] = callerid_sequence_data;
		 callerid_sequence_key = callerid_sequence_key + 1
	 end
	 local callerid_sequence_count = callerid_sequence_key - 1
	 local callerid_sequence = 1
	 if (callerid_sequence_detail ~= '' and callerid_sequence_detail[tonumber(callerid_sequence_count)] ~= nil)then
		fs_logger("warning","[common/custom.lua:: callerid sequence array is not blank::")
			callerid_sequence = callerid_sequence_detail[tonumber(callerid_sequence_count)]['sequence'] + 1
		fs_logger("warning","[common/custom.lua:: callerid sequence array is not blank::"..callerid_sequence)
	 end
	
		fs_logger("warning","[common/custom.lua:: callerid sequence array is blank::"..callerid_sequence)
		fs_logger("warning","[common/custom.lua:: callerid sequence array is  blank::")
		local callerid_collection = mongo_collection_name:getCollection "caller_ids"
		local cquery = { caller_id_group_uuid = callerid_group_uuid}
		local callerid_data = callerid_collection:find(cquery)
		local callerid_details = {}
		local callerid_key = 1
		for callerid_data in callerid_data:iterator() do
			callerid_details[callerid_key] = callerid_data;
			callerid_key = callerid_key + 1
		end
		fs_logger("warning","[common/custom.lua:: callerid count"..tonumber(callerid_key))
		fs_logger("warning","[common/custom.lua:: callerid sequence"..tonumber(callerid_sequence))
		if(tonumber(callerid_key) == tonumber(callerid_sequence))then
	 		local filter = {caller_id_group_uuid = callerid_group_uuid}
			callerid_sequence_db:remove(filter)
			callerid_sequence = 1
		end
		fs_logger("warning","[common/custom.lua:: callerid sequence array is key"..callerid_key)
		fs_logger("warning","[common/custom.lua:: callerid sequence array is not blank::1"..callerid_details[tonumber(callerid_sequence)]['caller_id'])
		if(callerid_details ~= nil and callerid_details[tonumber(callerid_sequence)] ~= nil)then
		fs_logger("warning","[common/custom.lua:: callerid sequence array is not blank::1"..callerid_details[tonumber(callerid_sequence)]['caller_id'])
			sequence_callerid = callerid_details[tonumber(callerid_sequence)]['caller_id']
			local datatoinsert = {caller_id_group_uuid = callerid_group_uuid,caller_id = sequence_callerid,sequence = callerid_sequence,uuid = sequence_callerid_uuid}
			callerid_sequence_db:insert(datatoinsert)
		end
	

	return sequence_callerid

end
function get_random_plus_destination()
	fs_logger("warning","[common/custom.lua:: you are in random plus destination function ")
		fs_logger("warning","[common/custom.lua:: destination number"..params:getHeader("Caller-Destination-Number"))
		destination_number = params:getHeader("Caller-Destination-Number");
		local modified_number = string.sub(destination_number, 1, -5)
		fs_logger("warning","[common/custom.lua:: modified destination number"..modified_number)
		local random_number = math.random(1000, 9999)
		fs_logger("warning","[common/custom.lua:: random number"..modified_number)
		new_destination_number = modified_number .. random_number
		fs_logger("warning","[common/custom.lua:: new destination number"..new_destination_number)

		return new_destination_number
end
function get_campaign_details(campaign_uuid,campaign_flag)
local outbound_campaign_collection = mongo_collection_name:getCollection "outbound_campaign"
local blended_campaign_collection = mongo_collection_name:getCollection "blended_campaign"
local campaign_info_array = ""
        local projection = { timeout = true, _id = false }
        local query = { uuid =campaign_uuid,status='0' }
        if(campaign_flag ~= nil and campaign_flag ~= "" and campaign_flag ~= "blended")then
                local cursor = blended_campaign_collection:find(query, { projection = projection })
                for blended_campaign_info_details in cursor:iterator() do
                        campaign_info_array = blended_campaign_info_details;
                end
        else
                local cursor = outbound_campaign_collection:find(query, { projection = projection })
                for outbound_campaign_info_details in cursor:iterator() do
                        campaign_info_array = outbound_campaign_info_details;
                end
        end

	if(campaign_info_array == '')then

		fs_logger("warning","[common/custom.lua:: Campaign not found::")
	end
	return campaign_info_array;
end
function unset_variable()
	xml = nil
	err = nil
	scripts_dir = nil
	mongo_collection_name = nil
	mongo = nil
	mongo_client = nil
	destination_number = nil
	originate_destination_number = nil
	original_destination_number = nil
	routed_destination_number = nil
	webphonetransfer = nil
	did_as_cid = nil
	custom_record_flag = nil
	to_domain = nil
	from_domain = nil
	caller_uuid = nil
	caller_user_uuid = nil
	caller_tenant_uuid = nil
	authentication_type = nil
	fail_call_flag = nil
	time_condition_frwd = nil
	did_number = nil
	from_ip = nil
	ip_mapping_array = nil
	ipmap_key = nil
	ip_map_uuid = nil
	did_acl_destination_array = nil
	tenant_info = nil
	from_domain = nil
	hangup_cause = nil
	fail_audio_file = nil
	caller_user_recording_flag = nil
	caller_sip_recording_flag = nil
	caller_user_info = nil
	caller_info = nil
	callerid_name = nil
	callerid_number = nil
	is_feature_code = nil
	call_pass_flag = nil
	is_extensions = nil
	is_did_number = nil
	custom_routes = nil
	forward_did_number = nil
	call_type = nil
	did_routing_type = nil
	did_routing_uuid = nil
	pstn_destination_number = nil
	pbx_frwd = nil
	pbx_find = nil
	sip_from_user = nil
	campaign_uuid = nil
	campaign_caller_id = nil
	timezone_array = nil
	timezone_name = nil
	tenant_array = nil
	caller_array = nil
	sip_destination_array = nil
	did_destination_array = nil
	did_acl_destination_array = nil
	custom_routing_type = nil
	user_array = nil
	custom_destination_number = nil
	trunk_info_array = nil
	outbound_campaign_array = nil
	call_id_type = nil
	caller_id_group_uuid = nil
	caller_id_array = nil
	query = nil
	random_caller_array = nil
	random_caller_id = nil
	campaign_info_array = nil
	outgoing_rules_array = nil
	destination_length = nil
	display_trunk_name = nil
	call_queuearray = nil
	conference_array = nil
	on_busy_failover = nil
	no_answered_failover = nil
	not_registered_failover = nil
	follow_destination_array = nil
	user_group_array = nil
	update_caller_array = nil
	ivr_array = nil
	selectedcampaignuuid = nil
	ring_group_array = nil
	ring_group_array = nil
	domain = nil
	time_condition_array = nil
end

function notify(xml,user_uuid,callkit_token,mobile_type,callerid_name,callerid_number,sip_user,domain,notify_call_type)
	fs_logger("info","[NOTIFY] START:")
	fs_logger("warning","[common/custom.lua:: USER UUID  ."..user_uuid)
	fs_logger("warning","[common/custom.lua:: CALLKIT TOKEN ."..callkit_token)
	fs_logger("warning","[common/custom.lua:: MOBILE TYPE ."..mobile_type)
	fs_logger("warning","[common/custom.lua:: MOBILE TYPE ."..notify_call_type)
	call_uuid = params:getHeader("variable_call_uuid")
	fs_logger("warning","[common/custom.lua:: CALL UUID ."..call_uuid)
--	fs_logger("warning","[common/custom.lua:: CALLerid numberr ."..callerid_number)
	if (callerid_name == "" or callerid_name == nil)then
		callerid_name = callerid_number
	end
	local argument1 = sip_user
	local argument2 = domain
		fs_logger("warning","[common/custom.lua:: python argument ."..argument1)
		fs_logger("warning","[common/custom.lua:: python argument ."..argument2)
	local python_response = execute_python_script(argument1,argument2)
		fs_logger("warning","[common/custom.lua:: python_response"..python_response)
	if (trim(python_response) == 'Not_Registered' and mobile_type == 'android')then
		fs_logger("warning","[dialplan/extensions.lua:: not registered")
		table.insert(xml, [[<action application="sleep" data="6000"/>]])
	elseif(trim(python_response) == 'Not_Registered' and mobile_type == 'ios') then
		table.insert(xml, [[<action application="sleep" data="6000"/>]])	
	end
	
end

function execute_python_script(argument1,argument2)
    --local command = string.format('/mnt/myenv/bin/python3.10 /usr/share/freeswitch/scripts/cdrs/register.py "%s"', argument1,argument2)
    local command = string.format('/mnt/myenv/bin/python3.10 '..scripts_dir..'/cdrs/register.py "%s" "%s"', argument1, argument2)

    fs_logger("warning","[common/custom.lua:: command  ."..command)
    local handle = io.popen(command)
    local result = handle:read("*a")
    handle:close()
    return result
end

function skip_plus_sign(destination_number)
	-- trimdestinationnumber = destination_number:gsub("%s+", "")
	local cleanedNumber = string.gsub(destination_number, "+", "")
	return cleanedNumber
end

function trim(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

function check_click2call_info(destination_number)
	local click_to_call_collection = mongo_collection_name:getCollection "click_to_call"
	local query = { device_number = ''..destination_number..'', status = '0', tenant_uuid = caller_tenant_uuid}
	local cursor = click_to_call_collection:find(query)
	local click_to_call_destination_array = ''
	for click_to_call_details in cursor:iterator() do
		click_to_call_destination_array = click_to_call_details;
	end
	if(click_to_call_destination_array == '')then
		fs_logger("warning","[common/custom.lua:: Click to call Array: NIL::")
	end
	return click_to_call_destination_array;
end
function generateUUIDv4()
math.randomseed(os.time())
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end
function check_licence_validate(from_domain)
	local master_admin_collection = mongo_collection_name:getCollection "master_admin"
	local url = "https://"..from_domain..":5000/login/check-license?from=FS"
	local validate_date = os.date("%Y-%m-%d")
	local cursor = master_admin_collection:find({})
	local master_admin_array = ''
	local response = 1
	local check_curl = 0
	for master_admin_details in cursor:iterator() do
		master_admin_array = master_admin_details;
	end
	fs_logger("notice","[common/custom.lua:: master_admin_array::"..master_admin_array.username)
	if(master_admin_array.username ~= nil and master_admin_array.validate_format == nil)then
		fs_logger("notice","[common/custom.lua:: licence valid first time::")
		check_curl = 1
	end
	if(master_admin_array.username ~= nil and master_admin_array.validate_format ~= nil)then
		fs_logger("notice","[common/custom.lua:: validate_date::"..validate_date)
		fs_logger("notice","[common/custom.lua:: validate_format::"..master_admin_array.validate_format)
		local validate_format_convert = licence_date_varification(master_admin_array.validate_format)
		fs_logger("notice","[common/custom.lua:: validate_format_convert::"..validate_format_convert)
			
		if(validate_format_convert < validate_date)then
			fs_logger("notice","[common/custom.lua:: validate_format_convert SMALL to check in CURL::"..validate_format_convert)
			check_curl = 1
		else
			response = 0
		end
		fs_logger("notice","[common/custom.lua:: master_admin_array::"..master_admin_array.username)
	end
	if(check_curl == 1)then
		curl_response = curl(url)
		if(curl_response == nil)then
			fs_logger("notice","[common/custom.lua:: licence valid first time NILL::")		
			response = 1
		elseif(curl_response < validate_date)then
			fs_logger("notice","[common/custom.lua:: licence valid first time SMALL::")
			response = 1
		else		
			fs_logger("notice","[common/custom.lua:: licence valid UPDATE validate_date::"..validate_date)
			response = 0
			local validate_format_str = licence_date_varification(validate_date)			
			fs_logger("notice","[common/custom.lua:: licence valid UPDATE validate_format_str::"..validate_format_str)
			local admin_query = {username = master_admin_array.username}
			local admin_update_string = {
				['$set'] = {validate_format = validate_format_str}
			}
			master_admin_collection:update(admin_query,admin_update_string)
		end
	end
	fs_logger("notice","[common/custom.lua:: :::LICENCE FLAG::: response::"..response)
	return response

end
function curl(url)
	local command = "curl -s " .. url
	local handle = io.popen(command)
	local response = handle:read("*a")
	handle:close()
	return response
end
function licence_date_varification(data)
	local key = "aAbBcCdDeEfFgGhH192837465"
	local result = {}
	local key_len = #key

	for i = 1, #data do
		local char = data:byte(i)
		local key_char = key:byte((i - 1) % key_len + 1)  -- cycle through key chars
		table.insert(result, string.char(bit32.bxor(char, key_char)))
	end
	return table.concat(result)
end

-- Helper function to convert 12-hour time to 24-hour format
local function convert_to_24_hour(time)
    local hour, minute, period = time:match("(%d+):(%d+) (%a+)")
    hour = tonumber(hour)
    minute = tonumber(minute)
    
    if period == "PM" and hour ~= 12 then
        hour = hour + 12
    elseif period == "AM" and hour == 12 then
        hour = 0
    end

    return string.format("%02d:%02d", hour, minute)
end
function check_area_code(area_code_prefix)
	local area_code_match = 1;
	local manage_area_code_collection = mongo_collection_name:getCollection "manage_area_code"
	local query = { code = ''..area_code_prefix..'', tenant_uuid = caller_tenant_uuid}
	local cursor = manage_area_code_collection:find(query)
	local manage_area_code_destination_array = ''
	for manage_area_code_details in cursor:iterator() do
		manage_area_code_destination_array = manage_area_code_details;
	end
	if(manage_area_code_destination_array == '')then
		fs_logger("warning","[common/custom.lua:: Area Code Not Match...::")
	else
		fs_logger("warning","[common/custom.lua:: Area Code Match...:::"..manage_area_code_destination_array.code)
		local manage_states_collection = mongo_collection_name:getCollection "manage_states"
		local manage_states_query = { uuid = manage_area_code_destination_array.state_id,toggle_status = '0'}
		fs_logger("warning","[common/custom.lua:: manage_states query...:::"..manage_area_code_destination_array.state_id)

		local manage_states_cursor = manage_states_collection:find(manage_states_query)
		local manage_states_destination_array = ''
		for manage_states_details in manage_states_cursor:iterator() do
			manage_states_destination_array = manage_states_details;
		end
		if(manage_states_destination_array == '')then
			fs_logger("warning","[common/custom.lua:: manage_states Not Match...::")
		else
			local timezone_collection = mongo_collection_name:getCollection "timezone"
			local time_zone_query = { uuid = manage_area_code_destination_array.timezone_uuid}
			fs_logger("warning","[common/custom.lua:: Time zone query...:::"..manage_area_code_destination_array.timezone_uuid)
	
			local timezone_cursor = timezone_collection:find(time_zone_query)
			local timezone_destination_array = ''
			for timezone_details in timezone_cursor:iterator() do
				timezone_destination_array = timezone_details;
			end
			if(timezone_destination_array == '')then
				fs_logger("warning","[common/custom.lua:: Timezone Not Match...::")
			else
	
				fs_logger("warning","[common/custom.lua:: Timezone GMT Offset...::"..timezone_destination_array.gmtoffset)
				fs_logger("warning","[common/custom.lua:: Timezone GMT timezone_name...::"..timezone_destination_array.timezone_name)
				-- Given details
				local gmtoffset = timezone_destination_array.gmtoffset  -- in seconds
				local timezone_name = timezone_destination_array.timezone_name  -- Just for reference; not used in calculations

				-- Get the current UTC time
				local utc_time = os.time(os.date("!*t"))

				-- Adjust for GMT offset
				local local_time = utc_time + gmtoffset

				-- Format the local time in 12-hour AM/PM format
				local formatted_time = os.date("%I:%M %p", local_time)
				fs_logger("warning","[common/custom.lua:: Timezone GMT formatted_time...::"..formatted_time)
				fs_logger("warning","[common/custom.lua:: Area Code From time::"..manage_area_code_destination_array.start_time)
				fs_logger("warning","[common/custom.lua:: Area Code To time::"..manage_area_code_destination_array.end_time)
				local formatted_time_24 = convert_to_24_hour(formatted_time)
				local from_time_24 = convert_to_24_hour(manage_area_code_destination_array.start_time)
				local to_time_24 = convert_to_24_hour(manage_area_code_destination_array.end_time)
				
				-- Check if formatted_time is within the range
				if formatted_time_24 >= from_time_24 and formatted_time_24 <= to_time_24 then
					fs_logger("warning","[common/custom.lua:: Area Code Type::"..manage_area_code_destination_array.type)
					if(tonumber(manage_area_code_destination_array.type) == 0)then
						area_code_match = 0
					end
					fs_logger("warning","[common/custom.lua:: formatted_time is within the range.")
				else
					fs_logger("warning","[common/custom.lua:: formatted_time is outside the range.")
				end
			end
		end
	end
	return area_code_match
end
function check_dispo_count(destination_number)
	local dispo_flag = 0
	local seven_day_condiiton_count = check_seven_days_dispo(destination_number)
	fs_logger("warning","[common/custom.lua::Count of matching seven_day_condiiton_count:::::"..seven_day_condiiton_count)
	if(tonumber(seven_day_condiiton_count) > 0)then
		dispo_flag = 1
	end
	local severn_in_seven_day_condiiton_count = check_seven_in_seven_days_dispo(destination_number)
	fs_logger("warning","[common/custom.lua::Count of matching severn_in_seven_day_condiiton_count:"..severn_in_seven_day_condiiton_count)
	if(tonumber(seven_day_condiiton_count) > 7)then
		dispo_flag = 1
	end	
	local one_in_three_day_condiiton_count = check_one_in_three_days_dispo(destination_number)
	fs_logger("warning","[common/custom.lua::Count of matching one_in_three_day_condiiton_count:"..one_in_three_day_condiiton_count)
	if(tonumber(one_in_three_day_condiiton_count) > 0)then
		dispo_flag = 1
	end
	dispo_flag = 0
	return dispo_flag
end
function check_seven_days_dispo(destination_number)

	-- MongoDB collections
	local disposition_collection = mongo_collection_name:getCollection("disposition")

	-- Fetch all data from the disposition collection
	local disposition_cursor = disposition_collection:find({}) -- Fetch all records
	
	-- Initialize a table to store matching disposition_uuids
	local disposition_uuids = {}
	
	-- Define the valid codes
	local valid_codes = { RPC = true, RPCP = true, PAYM = true } -- Use a hash table for quick lookup
	
	-- Iterate over the cursor
	for disposition in disposition_cursor:iterator() do
		if disposition.code and valid_codes[disposition.code] then
			table.insert(disposition_uuids, disposition.disposition_uuid)
		end
	end
	
	local disposition_uuids_set = {}

	for _, uuid in ipairs(disposition_uuids) do
		disposition_uuids_set[uuid] = true
	end
	-- Check if we found any matching uuids
	if #disposition_uuids == 0 then
		fs_logger("warning", "No matching dispositions found.")
--		return 0
	else
		fs_logger("info", "Matching disposition_uuids: " .. table.concat(disposition_uuids, ", "))
	end
	
	-- Step 2: Query the cars collection using the filtered uuids
	local cars_collection = mongo_collection_name:getCollection "cdrs"
	
	-- Get the current time and calculate the date 7 days ago
	local current_time = os.time()
	local seven_days_ago = current_time - (7 * 24 * 60 * 60)
	
	-- Convert timestamps to string format for MongoDB query
	local current_time_str = os.date("%Y-%m-%d %H:%M:%S", current_time)
	local seven_days_ago_str = os.date("%Y-%m-%d %H:%M:%S", seven_days_ago)
	

	-- Fetch all data from the cars collection
	local cars_cursor = cars_collection:find({
		--hangup_cause = { ["$exists"] = true },
		destination_number  = destination_number,
		callstart = {
			["$gte"] = seven_days_ago_str,
			["$lte"] = current_time_str,
		}
	})
	fs_logger("info", "check_seven_days_dispo: Count of matching seven_days_ago_str: " .. seven_days_ago_str)
	fs_logger("info", "check_seven_days_dispo: Count of matching current_time_str: " .. current_time_str)

	-- Filter results locally based on `destination_number` and `disposition_uuid`
	local matching_count = 0

	for car in cars_cursor:iterator() do
		-- Check `destination_number` and `disposition_uuid`
		--fs_logger("info", "check_seven_days_dispo: Count of matching ::car.destination_number::: car.hangup_cause: " .. car.hangup_cause)
		if disposition_uuids_set[car.hangup_cause] then
			matching_count = matching_count + 1
		end
	end

	-- Log the final count
	fs_logger("info", "check_seven_days_dispo: Count of matching CDRs: " .. matching_count)

	return matching_count
end
function check_seven_in_seven_days_dispo(destination_number)

	-- MongoDB collections
	local disposition_collection = mongo_collection_name:getCollection("disposition")

	-- Fetch all data from the disposition collection
	local disposition_cursor = disposition_collection:find({}) -- Fetch all records
	
	-- Initialize a table to store matching disposition_uuids
	local disposition_uuids = {}
	
	-- Define the valid codes
	local valid_codes = { WNUM = true, LM = true, MNLM = true, NC = true, OPCA = true } -- Use a hash table for quick lookup
	
	-- Iterate over the cursor
	for disposition in disposition_cursor:iterator() do
		if disposition.code and valid_codes[disposition.code] then
			table.insert(disposition_uuids, disposition.disposition_uuid)
		end
	end
	
	local disposition_uuids_set = {}

	for _, uuid in ipairs(disposition_uuids) do
		disposition_uuids_set[uuid] = true
	end
	-- Check if we found any matching uuids
	if #disposition_uuids == 0 then
		fs_logger("warning", "No matching dispositions found.")
--		return 0
	else
		fs_logger("info", "Matching disposition_uuids: " .. table.concat(disposition_uuids, ", "))
	end
	
	-- Step 2: Query the cars collection using the filtered uuids
	local cars_collection = mongo_collection_name:getCollection "cdrs"
	
	-- Get the current time and calculate the date 7 days ago
	local current_time = os.time()
	local seven_days_ago = current_time - (7 * 24 * 60 * 60)
	
	-- Convert timestamps to string format for MongoDB query
	local current_time_str = os.date("%Y-%m-%d %H:%M:%S", current_time)
	local seven_days_ago_str = os.date("%Y-%m-%d %H:%M:%S", seven_days_ago)
	

	-- Fetch all data from the cars collection
	local cars_cursor = cars_collection:find({
		--hangup_cause = { ["$exists"] = true },
		destination_number  = destination_number,
		callstart = {
			["$gte"] = seven_days_ago_str,
			["$lte"] = current_time_str,
		}
	})
	fs_logger("info", "check_seven_days_dispo: Count of matching seven_days_ago_str: " .. seven_days_ago_str)
	fs_logger("info", "check_seven_days_dispo: Count of matching current_time_str: " .. current_time_str)

	-- Filter results locally based on `destination_number` and `disposition_uuid`
	local matching_count = 0

	for car in cars_cursor:iterator() do
		-- Check `destination_number` and `disposition_uuid`
		--fs_logger("info", "check_seven_days_dispo: Count of matching ::car.destination_number::: car.hangup_cause: " .. car.hangup_cause)
		if disposition_uuids_set[car.hangup_cause] then
			matching_count = matching_count + 1
		end
	end

	-- Log the final count
	fs_logger("info", "check_seven_days_dispo: Count of matching CDRs: " .. matching_count)

	return matching_count
end

function check_one_in_three_days_dispo(destination_number)

	-- MongoDB collections
	local disposition_collection = mongo_collection_name:getCollection("disposition")

	-- Fetch all data from the disposition collection
	local disposition_cursor = disposition_collection:find({}) -- Fetch all records
	
	-- Initialize a table to store matching disposition_uuids
	local disposition_uuids = {}
	
	-- Define the valid codes
	local valid_codes = { MACH = true, MDLV = true, MUND = true } -- Use a hash table for quick lookup
	
	-- Iterate over the cursor
	for disposition in disposition_cursor:iterator() do
		if disposition.code and valid_codes[disposition.code] then
			table.insert(disposition_uuids, disposition.disposition_uuid)
		end
	end
	
	local disposition_uuids_set = {}

	for _, uuid in ipairs(disposition_uuids) do
		disposition_uuids_set[uuid] = true
	end
	-- Check if we found any matching uuids
	if #disposition_uuids == 0 then
		fs_logger("warning", "No matching dispositions found.")
--		return 0
	else
		fs_logger("info", "Matching disposition_uuids: " .. table.concat(disposition_uuids, ", "))
	end
	
	-- Step 2: Query the cars collection using the filtered uuids
	local cars_collection = mongo_collection_name:getCollection "cdrs"
	
	-- Get the current time and calculate the date 3 days ago
	local current_time = os.time()
	local seven_days_ago = current_time - (3 * 24 * 60 * 60)
	
	-- Convert timestamps to string format for MongoDB query
	local current_time_str = os.date("%Y-%m-%d %H:%M:%S", current_time)
	local seven_days_ago_str = os.date("%Y-%m-%d %H:%M:%S", seven_days_ago)
	

	-- Fetch all data from the cars collection
	local cars_cursor = cars_collection:find({
		--hangup_cause = { ["$exists"] = true },
		destination_number  = destination_number,
		callstart = {
			["$gte"] = seven_days_ago_str,
			["$lte"] = current_time_str,
		}
	})
	fs_logger("info", "check_seven_days_dispo: Count of matching seven_days_ago_str: " .. seven_days_ago_str)
	fs_logger("info", "check_seven_days_dispo: Count of matching current_time_str: " .. current_time_str)

	-- Filter results locally based on `destination_number` and `disposition_uuid`
	local matching_count = 0

	for car in cars_cursor:iterator() do
		-- Check `destination_number` and `disposition_uuid`
		--fs_logger("info", "check_seven_days_dispo: Count of matching ::car.destination_number::: car.hangup_cause: " .. car.hangup_cause)
		if disposition_uuids_set[car.hangup_cause] then
			matching_count = matching_count + 1
		end
	end

	-- Log the final count
	fs_logger("info", "check_seven_days_dispo: Count of matching CDRs: " .. matching_count)

	return matching_count
end


-- ::yaksh::
-- Custom function to call the customer API and return decoded response
-- function call_customer_api(mobile_number)
--     local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")

--     local json = {
--         filters = {
--             {
--                 filterDataType = "",
--                 filterValue = mobile_number,
--                 filterColumn = "mobile",
--                 filterOperator = "equalto",
--                 filterCondition = "and"
--             }
--         },
--         page = 1,
--         pageSize = 5
--     }

--     local json_string = dkjson.encode(json)
--     json_string = string.gsub(json_string, '"', '\\"')

--     local bearer_token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ7XCJ1c2VybmFtZVwiOlwiYWRtaW5cIixcImZpcnN0TmFtZVwiOlwiYWRtaW5cIixcImxhc3ROYW1lXCI6XCJhZG1pblwiLFwidXNlcklkXCI6MixcInBhcnRuZXJJZFwiOjEsXCJyb2xlc0xpc3RcIjpcIjFcIixcInNlcnZpY2VBcmVhSWRcIjpudWxsLFwibXZub0lkXCI6MixcInNlcnZpY2VBcmVhSWRMaXN0XCI6W10sXCJzdGFmZklkXCI6MixcImJ1SWRzXCI6W10sXCJyb2xlSWRzXCI6WzFdLFwidGVhbUlkc1wiOlsxXSxcIm12bm9OYW1lXCI6XCJhZG1pblwiLFwibGNvXCI6ZmFsc2UsXCJ0ZWFtc1wiOltcIlBhcmVudFRlYW1cIl19IiwiZXhwIjoxNzUzNDUxMTI0fQ.lec0IcumerHzpbhzmgBoIWU7B3Vw1ZZArLty-nrB6g4"

--     local curl_cmd = "curl -s -X POST https://adoptnettech.in:30080/api/v1/cms/customers/search/Prepaid" ..
--                      "-H \"Content-Type: application/json\" " ..
--                      "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
--                      "-d \"" .. json_string .. "\""

--     local handle = io.popen(curl_cmd)
--     local result = handle:read("*a")
--     handle:close()

--     local decoded_result, pos, err = dkjson.decode(result, 1, nil)

--     if err then
--         fs_logger("err", "[call_customer_api] JSON decode error: " .. err)
--         return nil
--     end

--     return decoded_result
-- end


-- function get_customer_by_accountNumber(account_number)
--     local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")

--    local final_account_number = "A20257175258" .. account_number
--    fs_logger("final_account_number", final_account_number)
--     local json = {
--         filters = {
--             {
--                 filterDataType = "",
--                 filterValue = final_account_number,
--                 filterColumn = "accountNumber",
--                 filterOperator = "equalto",
--                 filterCondition = "and"
--             }
--         },
--         page = 1,
--         status = "Active",
--         pageSize = 10
--     }

--     local json_string = dkjson.encode(json)
--     json_string = string.gsub(json_string, '"', '\\"')

--     local bearer_token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ7XCJ1c2VybmFtZVwiOlwiYWRtaW5cIixcImZpcnN0TmFtZVwiOlwiYWRtaW5cIixcImxhc3ROYW1lXCI6XCJhZG1pblwiLFwidXNlcklkXCI6MixcInBhcnRuZXJJZFwiOjEsXCJyb2xlc0xpc3RcIjpcIjFcIixcInNlcnZpY2VBcmVhSWRcIjpudWxsLFwibXZub0lkXCI6MixcInNlcnZpY2VBcmVhSWRMaXN0XCI6W10sXCJzdGFmZklkXCI6MixcImJ1SWRzXCI6W10sXCJyb2xlSWRzXCI6WzFdLFwidGVhbUlkc1wiOlsxXSxcIm12bm9OYW1lXCI6XCJhZG1pblwiLFwibGNvXCI6ZmFsc2UsXCJ0ZWFtc1wiOltcIlBhcmVudFRlYW1cIl19IiwiZXhwIjoxNzUzNDUxMTI0fQ.lec0IcumerHzpbhzmgBoIWU7B3Vw1ZZArLty-nrB6g4"

--     local curl_cmd = "curl -s -X POST https://adoptnettech.in:30080/api/v1/cms/customers/search/Prepaid" ..
--                      "-H \"Content-Type: application/json\" " ..
--                      "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
--                      "-d \"" .. json_string .. "\""

--     local handle = io.popen(curl_cmd)
--     local result = handle:read("*a")
--     handle:close()

--     local decoded_result, pos, err = dkjson.decode(result, 1, nil)

--     if err then
--         fs_logger("err", "[call_customer_api] JSON decode error: " .. err)
--         return nil
--     end

--     return decoded_result
-- end

	

-- ::Jeel::
-- Custom function to call the customer API and return decoded response
function call_customer_api(mobile_number)
	local base_url = CRM_API_URL
    local api_path = "/cms/customers/search/Prepaid"
    local api_url = base_url .. api_path
  --  local bearer_token = CRM_API_TOKEN

  -- Get bearer token from file
    local bearer_token = get_token()
    if not bearer_token then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Bearer token not found.\n")
        return nil
    end

    local json = {
        filters = {
            {
                filterDataType = "",
                filterValue = mobile_number,
                filterColumn = "mobile",
                filterOperator = "equalto",
                filterCondition = "and"
            }
        },
        page = 1,
        pageSize = 5
    }

    local json_string = dkjson.encode(json)
    json_string = string.gsub(json_string, '"', '\\"')

     -- Build curl command
    local curl_cmd = "curl -s -X POST \"" .. api_url .. "\" " ..
                     "-H \"Content-Type: application/json\" " ..
                     "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
                     "-d \"" .. json_string .. "\""

    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    local decoded_result, pos, err = dkjson.decode(result, 1, nil)

    if err then
        fs_logger("err", "[call_customer_api] JSON decode error: " .. err)
        return nil
    end

    return decoded_result
end


-- ::Jeel::
-- Custom function to find customer by account number
-- function get_customer_by_accountNumber(account_number)
--     local base_url = CRM_API_URL
--     local api_path = "/cpm/customers/search/Prepaid"
--     local api_url = base_url .. api_path
--     local bearer_token = CRM_API_TOKEN
-- 	local final_account_number = COMMON_ACCOUNT_NO .. account_number
--     -- Build JSON payload
-- 	freeswitch.consoleLog("INFO", "Final Account Number: " .. final_account_number .. "\n");
	
--     local json = {
--         filters = {
--             {
--                 filterDataType = "",
--                 filterValue = final_account_number,
--                 filterColumn = "accountNumber",
--                 filterOperator = "equalto",
--                 filterCondition = "and"
--             }
--         },
--         page = 1,
--         status = "Active",
--         pageSize = 10
--     }

--     -- Encode JSON payload
--     local json_string = dkjson.encode(json)
--     json_string = string.gsub(json_string, '"', '\\"')

--     -- Build curl command
--     local curl_cmd = "curl -s -X POST \"" .. api_url .. "\" " ..
--                      "-H \"Content-Type: application/json\" " ..
--                      "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
--                      "-d \"" .. json_string .. "\""

--     freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] CURL Command: " .. curl_cmd .. "\n")

--     -- Execute curl
--     local handle = io.popen(curl_cmd)
--     local result = handle:read("*a")
--     handle:close()

--     -- Decode JSON response
--     local decoded_result, pos, err = dkjson.decode(result, 1, nil)

--     if err then
--         freeswitch.consoleLog("ERR", "[call_customer_api] JSON decode error: " .. err .. "\n")
--         return nil
--     end

--     return decoded_result
-- end

function get_customer_by_accountNumber(account_number)
    local base_url = CRM_API_URL
    local api_path = "/cpm/customers/search/Prepaid"
    local api_url = base_url .. api_path
    -- local bearer_token = CRM_API_TOKEN
    local final_account_number = COMMON_ACCOUNT_NO .. account_number

	-- Get bearer token from file
    local bearer_token = get_token()
    if not bearer_token then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Bearer token not found.\n")
        return nil
    end

	 -- Build JSON payload
    freeswitch.consoleLog("INFO", "bearer_token: " .. bearer_token .. "\n")
    
    -- Build JSON payload
    freeswitch.consoleLog("INFO", "Final Account Number: " .. final_account_number .. "\n")
    
    local json = {
        filters = {
            {
                filterDataType = "",
                filterValue = final_account_number,
                filterColumn = "accountNumber",
                filterOperator = "equalto",
                filterCondition = "and"
            }
        },
        page = 1,
        status = "Active",
        pageSize = 10
    }

    -- Encode JSON payload
    local json_string = dkjson.encode(json)
    json_string = string.gsub(json_string, '"', '\\"')

    -- Build curl command
    local curl_cmd = "curl -sk -X POST \"" .. api_url .. "\" " ..
                     "-H \"Content-Type: application/json\" " ..
                     "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
                     "-d \"" .. json_string .. "\""

    freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] CURL Command: " .. curl_cmd .. "\n")

    -- Execute curl
    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    -- Check if response is empty
    if result == nil or result == "" then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Empty response from API\n")
        return nil
    end

    -- Decode JSON response
    local decoded_result, pos, err = dkjson.decode(result, 1, nil)

    if err then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] JSON decode error: " .. err .. "\n")
        return nil
    end

    -- Check API response status
    if decoded_result.status == 204 then
        freeswitch.consoleLog("NOTICE", "[get_customer_by_accountNumber] No customer found for account number: " .. final_account_number .. "\n")
        return decoded_result -- Return the decoded result even for 204 status
    elseif decoded_result.status == 200 then
        if decoded_result.customerList and #decoded_result.customerList > 0 then
            return decoded_result
        else
            freeswitch.consoleLog("NOTICE", "[get_customer_by_accountNumber] No customer data in response for account number: " .. final_account_number .. "\n")
            return decoded_result -- Return the decoded result even if customerList is empty
        end
    else
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Unexpected API status: " .. tostring(decoded_result.status) .. "\n")
        return nil
    end
end

function get_customer_by_accountNumber_and_mobileNo(account_number, mobileNo)
    local base_url = CRM_API_URL
    local api_path = "/cpm/checkValidAccountAndMobile"
    local api_url = base_url .. api_path
    local final_account_number = COMMON_ACCOUNT_NO .. account_number

    -- Get bearer token from file
    local bearer_token = get_token()
    if not bearer_token then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Bearer token not found.\n")
        return nil
    end

    freeswitch.consoleLog("INFO", "bearer_token: " .. bearer_token .. "\n")
    freeswitch.consoleLog("INFO", "Final Account Number: " .. final_account_number .. "\n")

    -- Build JSON payload
    local json = {
        acctno = final_account_number,
        mobile = "917364657"
    }

    local json_string = dkjson.encode(json)

    local curl_cmd = "curl -sk -w \"HTTPSTATUS:%{http_code}\" -X POST \"" .. api_url .. "\" " ..
                     "-H \"Content-Type: application/json\" " ..
                     "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
                     "-d '" .. json_string .. "'"

    freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] CURL Command: " .. curl_cmd .. "\n")

    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] Raw API response: " .. tostring(result) .. "\n")

    if not result or result == "" then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Empty response from API\n")
        return nil
    end

    local body, status = result:match("^(.*)HTTPSTATUS:(%d+)$")
    status = tonumber(status)

    if not body or not status then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Unable to parse HTTP status\n")
        return nil
    end

    freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] HTTP Status: " .. status .. "\n")
    freeswitch.consoleLog("INFO", "[get_customer_by_accountNumber] Raw JSON Body: " .. body .. "\n")

    if status == 404 then
        freeswitch.consoleLog("NOTICE", "[get_customer_by_accountNumber] Customer not found\n")
        return nil
    end

    local decoded_result, pos, err = dkjson.decode(body, 1, nil)

    if err then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] JSON decode error: " .. err .. "\n")
        return nil
    end

    -- ✅ Return decoded data
    return decoded_result
end


-- function to fetch due date and bill amount
function get_due_date_and_amount(account_number)
	local final_account_number = COMMON_ACCOUNT_NO .. account_number
	local base_url = CRM_API_URL
	local api_path = "/Revenue/getDueDateAndBillAmount?acctno=" .. final_account_number
    local api_url = base_url .. api_path
   
	local bearer_token = get_token()
    if not bearer_token then
        freeswitch.consoleLog("ERR", "[get_due_date_and_amount] Bearer token not found.\n")
        return nil
    end

    local curl_cmd = "curl -sk -w \"HTTPSTATUS:%{http_code}\" -X GET \"" .. api_url .. "\" " ..
	 				 "-H \"Content-Type: application/json\" " ..
                     "-H \"Authorization: Bearer " .. bearer_token .. "\""

    freeswitch.consoleLog("INFO", "[get_due_date_and_amount] CURL Command: " .. curl_cmd .. "\n")


	 -- Execute
    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    -- Split response
    local body, status = result:match("^(.*)HTTPSTATUS:(%d+)$")
    status = tonumber(status)

    freeswitch.consoleLog("INFO", "[get_due_date_and_amount] HTTP Status: " .. tostring(status) .. "\n")
    freeswitch.consoleLog("INFO", "[get_due_date_and_amount] Raw Body: " .. tostring(body) .. "\n")

    if not body or not status then
        freeswitch.consoleLog("ERR", "[get_due_date_and_amount] Invalid response format\n")
        return nil
    end

    -- Decode
    local response, pos, err = dkjson.decode(body, 1, nil)
    if err then
        freeswitch.consoleLog("ERR", "[get_due_date_and_amount] JSON decode error: " .. err .. "\n")
        return nil
    end

    if status ~= 200 then
        freeswitch.consoleLog("ERR", "[get_due_date_and_amount] API returned status: " .. status .. "\n")
        return nil
    end

    return response
end

-- Formate Due date
function format_due_date(iso_date_str)
    local year, month, day = iso_date_str:match("^(%d+)%-(%d+)%-(%d+)")
    local months = {
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    }

    if not year or not month or not day then
        return iso_date_str  -- fallback to original if parsing fails
    end

    local month_index = tonumber(month)
    return day .. "-" .. months[month_index] .. "-" .. year
end


-- ::Jeel::
-- Custom function to get Invoice by customerId
function get_invoice_by_customer(custumerId)
    -- Load dkjson

    local base_url = CRM_API_URL
    local api_path = "/Revenue/invoice/search?billrunid=&docnumber=&customerid=".. custumerId .."&billfromdate=&billtodate=&custmobile=&isInvoiceVoid=true"
    local api_url = base_url .. api_path
    -- local bearer_token = CRM_API_TOKEN
    local simulate_404 = true  -- << Set to true to simulate 404 response


	 -- Get bearer token from file
    local bearer_token = get_token()
    if not bearer_token then
        freeswitch.consoleLog("ERR", "[get_customer_by_accountNumber] Bearer token not found.\n")
        return nil
    end


    local json = {
        page = 1,
        pageSize = 1
    }

        local dummy_404_response = {
            status = 404,
            error = "Not Found",
            message = "No customer found with the given account number.",
            timestamp = os.date("%Y-%m-%d %H:%M:%S")
        }

    -- Encode JSON payload
    local json_string = dkjson.encode(json)
    json_string = string.gsub(json_string, '"', '\\"')

    -- Build curl command
    local curl_cmd = "curl -sk -X POST \"" .. api_url .. "\" " ..
                     "-H \"Content-Type: application/json\" " ..
                     "-H \"Authorization: Bearer " .. bearer_token .. "\" " ..
                     "-d \"" .. json_string .. "\""

    freeswitch.consoleLog("INFO", "[get_Invoice_by_Customer] CURL Command: " .. curl_cmd .. "\n")

    -- Execute curl
    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    -- Decode JSON response
    local decoded_result, pos, err = dkjson.decode(result, 1, nil)

    if err then
        freeswitch.consoleLog("ERR", "[get_Invoice_by_Customer] JSON decode error: " .. err .. "\n")
        return nil
    end

    return decoded_result
    --return dummy_404_response
end

function Send_SMS(mobile, text, templateId)
    local SMS_url = SMS_API_URL
    local SMS_API_TOken = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VybmFtZSI6ImRlbW8iLCJkb21haW4iOiIxOTIuMTY4LjI1LjQiLCJlbWFpbCI6ImRlbW9AZ21haWwuY29tIiwicm9sZSI6InRlbmFudCIsInV1aWQiOiI4OWMxYjkzOS1iYjEzLTQ3NmQtYjIxNy05YmZhNTM3M2VkMGEiLCJ0aW1lem9uZSI6IkFzaWEvS29sa2F0YSIsImlhdCI6MTc1MzE2MzM1NSwiZXhwIjoxNzUzMjQ5NzU1fQ.Lh_f8AxeRG_q1-ayuD9b1uhRYwrGRiTU-X9kKYRVDG4"  -- You must assign it properly

    local json = {
        mobile = mobile,
        text = text,
        templateId = templateId
    }

    local json_string = dkjson.encode(json)

    -- Use single quotes around -d to avoid escaping
    local curl_cmd = "curl -sk -X POST '" .. SMS_url .. "' " ..
                     "-H 'Content-Type: application/json' " ..
                     "-H 'Authorization: Bearer " .. SMS_API_TOken .. "' " ..
                     "-d '" .. json_string .. "' 2>&1"

    freeswitch.consoleLog("INFO", "[Send_SMS] CURL Command: " .. curl_cmd .. "\n")

    local handle = io.popen(curl_cmd)
    local result = handle:read("*a")
    handle:close()

    fs_logger(logger, "notice", "[Send_SMS] Raw CURL response: [" .. tostring(result) .. "]")

    if not result or result == "" then
        freeswitch.consoleLog("ERR", "[Send_SMS] Empty response from SMS API\n")
        return nil
    end

    local decoded_result, pos, err = dkjson.decode(result, 1, nil)

    if err then
        freeswitch.consoleLog("ERR", "[Send_SMS] JSON decode error: " .. err .. "\n")
        return nil
    end

    return decoded_result
end

function get_token()
    local token_path = "/usr/local/freeswitch/token/access_token.txt"
    local token_file = io.open(token_path, "r")

    if token_file then
        local token = token_file:read("*a")
        token_file:close()
        token = token:gsub("%s+", "") -- remove newline or spaces
        freeswitch.consoleLog("info", "[get_token] Using token from file.\n" ..token)
        return token
    else
        local env_token = CRM_API_TOKEN
        if env_token and env_token ~= "" then
            freeswitch.consoleLog("info", "[get_token] Using CRM_API_TOKEN from ENV.\n")
            return env_token
        else
            freeswitch.consoleLog("err", "[get_token] Token file not found and CRM_API_TOKEN ENV not set.\n")
            return nil
        end
    end
end



