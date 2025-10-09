fs_logger("notice","[dialplan/extensions.lua][XML_STRING] IN extensions")
api = freeswitch.API()

local sip_call_forward = sip_destination_array.call_forward
local sip_follow_me = sip_destination_array.follow_me
local default_call_forward_str = ''
local on_busy_str = ''
local no_answered_str = ''
local not_registered_str = ''
local sip_username = sip_destination_array.username
	fs_logger("warning","[dialplan/extensions.lua:: Extension DND mode sip_destination_array.dnd."..sip_destination_array.dnd)
if(tonumber(sip_destination_array.dnd) == '0' or tonumber(sip_destination_array.dnd) == 0 )then
	hangup_cause = "DND_MODE_ENABLE";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[dialplan/extensions.lua:: Extension DND mode enable.")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end
if(sip_call_forward ~= nil)then
	for param_key, param_value in pairs( sip_call_forward ) do
		fs_logger("notice"," [dialplan/extensions.lua] extension "..param_key.."\n")
		if(param_key == 'call_forward')then default_call_forward_str = param_value end
		if(param_key == 'on_busy')then on_busy_str = param_value end
		if(param_key == 'no_answered')then no_answered_str = param_value end
		if(param_key == 'not_registered')then not_registered_str = param_value end
	end
end

if(default_call_forward_str ~= '')then
	if(tonumber(default_call_forward_str['call_forwarding_status']) == 0 and default_call_forward_str['routing_type'] ~= '' and default_call_forward_str['routing_value'] ~= '')then
		fs_logger("notice","[dialplan/extensions.lua][XML_STRING] Call Forwarding Enable")	
		original_destination_number = destination_number
		custom_routing_forwarding(default_call_forward_str['routing_type'],default_call_forward_str['routing_value'])
		return
	end
end

on_busy_failover = ""
if(on_busy_str ~= '')then
	if(tonumber(on_busy_str['on_busy_status']) == 0 and on_busy_str['routing_type'] ~= '' and on_busy_str['routing_value'] ~= '')then
		did_number = destination_number
		on_busy_failover = destination_number.."#PBX#"..on_busy_str['routing_type'].."#"..on_busy_str['routing_value']
		fs_logger("notice","[dialplan/extensions.lua][XML_STRING] on_busy_failover:::"..on_busy_failover)
	end
end

no_answered_failover = ""
if(no_answered_str ~= '')then
	if(tonumber(no_answered_str['no_answered_status']) == 0 and no_answered_str['routing_type'] ~= '' and no_answered_str['routing_value'] ~= '')then
		did_number = destination_number
		no_answered_failover = destination_number.."#PBX#"..no_answered_str['routing_type'].."#"..no_answered_str['routing_value']
		fs_logger("notice","[dialplan/extensions.lua][XML_STRING] no_answered_failover"..no_answered_failover)
	end
end

not_registered_failover = ""
if(not_registered_str ~= '')then
	if(tonumber(not_registered_str['not_registered_status']) == 0 and not_registered_str['routing_type'] ~= '' and not_registered_str['routing_value'] ~= '')then
		did_number = destination_number
		not_registered_failover = destination_number.."#PBX#"..not_registered_str['routing_type'].."#"..not_registered_str['routing_value']
		fs_logger("notice","[dialplan/extensions.lua][XML_STRING] not_registered_failover"..not_registered_failover)
	end
end

if(sip_follow_me ~= nil)then
	if(tonumber(sip_follow_me['follow_me_status']) == 0 and sip_follow_me['destination'] ~= '')then
		fs_logger("notice","[dialplan/extensions.lua][XML_STRING] sip_follow_me"..sip_follow_me['follow_me_status'])
		follow_destination_array = split(sip_follow_me['destination'],",");
		if(follow_destination_array ~= nil)then
			local separated_bridge ="|"
			local follow_me_dlr_str = ""
			local extension_collection = mongo_collection_name:getCollection "extensions"
			local extension_query = ""
			for follow_me_key, follow_me_value in pairs( follow_destination_array ) do
				fs_logger("notice","[dialplan/extensions.lua][XML_STRING] follow_me_value"..follow_me_value)
				extension_query = { uuid = follow_me_value, status = '0', tenant_uuid = caller_tenant_uuid}
				local projection = { username = true, _id = false }
				local cursor = extension_collection:find(extension_query, { projection = projection })
				follow_destination_array = ''
				for extension_details in cursor:iterator() do
					follow_destination_array = extension_details;
				end
				--IGNORE BUSY PENDING
				if(follow_destination_array.username)then
					follow_me_dlr_str = follow_me_dlr_str.."[call_timeout=5]user/"..follow_destination_array.username.."@"..from_domain..separated_bridge
				end
			end
			if(follow_me_dlr_str ~= '')then
				header_xml();
				callerid_xml();

				table.insert(xml, [[<action application="bridge" data="]]..follow_me_dlr_str..[["/>]])
				footer_xml();			
				return
			end
		end
	end
end

if(call_type == nil)then
	call_type = 'local'
end
header_xml();

if(params:getHeader("variable_webphonetransfer") and params:getHeader("variable_webphonetransfer") ~= nil)then
	webphonetransfer = params:getHeader("variable_webphonetransfer")
end
 fs_logger("warning","[dialplan/extensions.lua::is_did_number:: ."..is_did_number)
local caller_id_set_flag = 0
if((caller_info ~= nil and caller_info.device_name ~= '' and tonumber(webphonetransfer) == 0 and authentication_type ~= 'acl' and (tonumber(is_did_number) == 1 or is_did_number == nil)) or (params:getHeader("variable_extension_uuid") and params:getHeader("variable_extension_uuid") ~= nil)) then
	if(call_type ~= 'click2call')then
		caller_id_set_flag = 1
		table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..caller_info.device_name..[["/>]]);
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..caller_info.username..[["/>]]);
	end
end
fs_logger("notice","[dialplan/extensions.lua][XML_STRING] uuid"..sip_destination_array.uuid)
fs_logger("notice","[dialplan/extensions.lua][XML_STRING] recording"..sip_destination_array.recording)
callerid_xml();
--AS client want to override DID as CLI we add below if condition, due to that every time original caller id set in extension call.
if (caller_id_set_flag == 0)then
	local sip_callerid_number = params:getHeader("Caller-Caller-ID-Number")
	table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..sip_callerid_number..[["/>]]);
	table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..sip_callerid_number..[["/>]]);
end
--if(tonumber(sip_destination_array.recording) == 0)then

--	table.insert(xml, [[<action application="set" data="custom_sip_recording=0"/>]]);	
--	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/${uuid}_SIP.wav"/>]]);
--else
--	table.insert(xml, [[<action application="set" data="custom_sip_recording=1"/>]]);
--end


local leg_timeout =60;
local user_array = get_userinfo(sip_destination_array.user_uuid)
if(user_array ~= nil and user_array ~= '' and user_array.default_timeout ~= '')then
	leg_timeout = user_array.default_timeout 
end
local local_bridge_variable = ""
if(tonumber(is_did_number) == 0)then
	if(did_destination_array.codec ~= nil and did_destination_array.codec ~= '')then
		fs_logger("warning","[dialplan/extensions.lua:: DID CODEC ."..did_destination_array.codec)
		local_bridge_variable = local_bridge_variable..",absolute_codec_string=".."^^:"..did_destination_array.codec:gsub("%,", ":")
	end
	if(did_destination_array.timeout ~= nil and did_destination_array.timeout ~= '')then
		fs_logger("warning","[dialplan/extensions.lua:: DID Timeout ."..did_destination_array.timeout)
		leg_timeout =did_destination_array.timeout;
	end
end

if (type(user_array.callkit_token) ~= "table" and user_array.callkit_token ~= nil and user_array.callkit_token ~= "" and user_array.callkit_token ~= "null" and user_array.callkit_token ~= "" and user_array.mobile_type ~= nil and user_array.mobile_type ~= "" and user_array.mobile_type ~= "null")then
	fs_logger("warning","[dialplan/extensions.lua:: CALLKIT TOKEN ."..user_array.callkit_token)
	fs_logger("warning","[dialplan/extensions.lua:: MOBILE TYPE ."..user_array.mobile_type)
	local notify_call_type = "extension"
	if notify then notify(xml,sip_destination_array.user_uuid,user_array.callkit_token,user_array.mobile_type,caller_info.device_name,caller_info.username,sip_username,from_domain,notify_call_type) end
end

		if callerid_number == nil or callerid_number == '' then
			callerid_number = params:getHeader("Caller-Caller-ID-Number")
		end
		fs_logger("warning","[dialplan/extensions.lua:: callerid_number::"..callerid_number)
		local callerid = skip_special_char(callerid_number)
		fs_logger("warning","[dialplan/extensions.lua:: callerid::"..callerid)
		local lead_info = get_lead_info_for_queue(callerid)
		local lead_name = ""
		local lead_uuid = ""

		-- if(lead_info ~= nil and lead_info ~= "")then
		-- 	if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
		-- 		lead_name = lead_array.first_name.."__"..lead_array.last_name
		-- 	else
		-- 		lead_name = lead_array.first_name
		-- 	end
		-- 	lead_uuid = lead_info.lead_management_uuid
		-- 	fs_logger("warning","[dialplan/extensions.lua:: Lead found::")
		-- else 
		-- 	local str_uuid = generateUUIDv4()
		-- 	local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
		-- 	local datatoinsert = {phone_number = callerid,custom_phone_number = callerid,first_name = "Anonymous",last_name = "Anonymous",lead_management_uuid=str_uuid,tenant_uuid = caller_tenant_uuid}
		-- 	fs_logger("warning","[dialplan/extensions.lua:: Lead not found and insert str_uuid::"..str_uuid)		
		-- 	fs_logger("warning","[dialplan/extensions.lua:: Lead not found and insert::")		
		-- 	lead_mgmt_collection:insert(datatoinsert)
		-- 	lead_uuid = str_uuid
		-- 	lead_name = "Anonymous"
		-- 		table.insert(xml, [[<action application="set" data="sip_h_X-incoming_new_lead=true"/>]]);	
		-- end

		if(lead_info ~= nil and lead_info ~= "")then
			if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
					lead_name = lead_array.first_name.."__"..lead_array.last_name
			else
					lead_name = lead_array.first_name
			end
			lead_uuid = lead_info.lead_management_uuid
			fs_logger("warning","[dialplan/extensions.lua:: Lead found::")
		else
			-- ::yaksh::
			--local response = call_customer_api(callerid)
			local response = call_customer_api("9494949449")
			local str_uuid = generateUUIDv4()
			local datatoinsert = ""
			if response and response.customerList and #response.customerList > 0 then
					local customer = response.customerList[1]
					fs_logger("warning", "[IVR] Response of Customer data found from CRM.")

					-- Insert into MongoDB

					local custom_fields_table = {
							ServiceArea = customer.serviceArea or "",
							AccNo = customer.acctno or nil,
							MvnoId = customer.mvnoId or nil,
							Status = customer.status or nil,
							MvnoName = customer.mvnoName or nil
					}

					datatoinsert = {phone_number = callerid, custom_fields = custom_fields_table, email = customer.email, alternate_phone_number = customer.mobile,custom_phone_number = customer.mobile,first_name = customer.name,last_name = "",lead_management_uuid=str_uuid,tenant_uuid = caller_tenant_uuid}
					fs_logger("warning", "[IVR] Local data set.")
			else
					fs_logger("warning", "[IVR] No Customer data found from CRM.")
					datatoinsert = {phone_number = callerid,custom_phone_number = callerid,first_name = "Anonymous",last_name = "Anonymous",lead_management_uuid=str_uuid,tenant_uuid = caller_tenant_uuid}
			end

			local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
			fs_logger("warning","[dialplan/extensions.lua:: Lead not found and insert str_uuid::"..str_uuid)
			fs_logger("warning","[dialplan/extensions.lua:: Lead not found and insert::")
			lead_mgmt_collection:insert(datatoinsert)
			lead_uuid = str_uuid
			lead_name = "Anonymous"
					table.insert(xml, [[<action application="set" data="sip_h_X-incoming_new_lead=true"/>]]);
			end

			table.insert(xml, [[<action application="set" data="sip_h_X-lead_name=]]..lead_name..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_uuid=]]..lead_uuid..[["/>]]);
			table.insert(xml, [[<action application="export" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);

table.insert(xml, [[<action application="set" data="max_calls=1" inline="true"/>]]);
--table.insert(xml, [[<action application="limit" data="db ]]..from_domain..[[ ]]..destination_number..[[ ${max_calls}"/>]]);
--table.insert(xml, [[<action application="limit" data="hash inbound ]]..destination_number..[[_]]..from_domain..[[ 1 !USER_BUSY" />]]);
table.insert(xml, [[<action application="set" data="receiver_extension_uuid=]]..sip_destination_array.uuid..[["/>]]);
table.insert(xml, [[<action application="set" data="receiver_user_uuid=]]..sip_destination_array.user_uuid..[["/>]]);
table.insert(xml, [[<action application="set" data="ringback=%(2000,4000,440,480)"/>]])
table.insert(xml, [[<action application="bridge" data="[leg_timeout=]]..tonumber(leg_timeout)..local_bridge_variable..[[]user/]]..sip_username..[[@]]..from_domain..[["/>]])
table.insert(xml, [[<action application="set" data="on_busy_failover=]]..on_busy_failover..[["/>]]);
table.insert(xml, [[<action application="set" data="no_answered_failover=]]..no_answered_failover..[["/>]]);
table.insert(xml, [[<action application="set" data="not_registered_failover=]]..not_registered_failover..[["/>]]);

table.insert(xml, [[<action application="lua" data="]]..scripts_dir .. [[dialplan/extension_failover.lua"/>]]);
table.insert(xml, [[<condition field="${cond(${user_data ]]..sip_username..[[@]]..from_domain..[[ param vm-enabled} == true ? YES : NO)}" expression="^YES$">]])
table.insert(xml, [[<action application="answer"/>]]);    
if(call_type == 'local') then
 --               fs_logger("warning","[dialplan/extensions.lua:: DID Timeout .adesh")
--             api:executeString("callcenter_config agent set state "..caller_info.username.."."..from_domain.."@default 'In a queue call'")
--             api:executeString("callcenter_config agent set state "..sip_username.."."..from_domain.."@default 'In a queue call'")
end

table.insert(xml, [[<action application="set" data="voicemail_alternate_greet_id=]]..sip_username..[["/>]]);  
table.insert(xml, [[<action application="voicemail" data="default ]]..from_domain..[[ ]]..sip_username..[["/>]]);    
table.insert(xml, [[<anti-action application="hangup" data="${originate_disposition}"/>]])
table.insert(xml, [[</condition>]])
footer_xml();
