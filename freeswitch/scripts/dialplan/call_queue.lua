fs_logger("notice","[dialplan/call_queue.lua][XML_STRING] IN CALL QUEUE")
local call_queue_collection = mongo_collection_name:getCollection "call_queue"
local call_queue_agent_collection = mongo_collection_name:getCollection "call_queue_agent"
local user_collection = mongo_collection_name:getCollection "user"
local extension_collection = mongo_collection_name:getCollection "extensions"
-- local sticky_agent = mongo_collection_name:getCollection "sticky_agent"

local query = { uuid = did_routing_uuid, status = '0' }
local projection = { uuid = true,call_welcome_greeting_uuid=true,for_pbx=true, _id = false, name=true}
local cursor = call_queue_collection:find(query, { projection = projection })
-- iterate over the results
call_queuearray = ''
for  call_queue_details in cursor:iterator() do
    call_queuearray = call_queue_details
end

if(call_queuearray == '')then
	fs_logger("warning","[dialplan/call_queue.lua:: Call Queue: NIL::")
	return true;
end
	call_queue_uuid = call_queuearray.uuid
	

	

header_xml();
callerid_xml();
	if(call_queuearray.for_pbx ~= nil and tonumber(call_queuearray.for_pbx) == 0) then
		fs_logger("warning","[dialplan/call_queue.lua:: pbx call queue::")
		local query = {call_queue_uuid = did_routing_uuid}
		local call_agent_cursor = call_queue_agent_collection:find(query)
		call_queue_agent_array = {}
		call_queue_agent_key = 1
		for  call_queue_agent_details in call_agent_cursor:iterator() do
    			call_queue_agent_array[call_queue_agent_key] = call_queue_agent_details
    			call_queue_agent_key = call_queue_agent_key + 1
		end
		if call_queue_agent_array == "" then
			fs_logger("warning","[dialplan/call_queue.lua:: call queue agent not found::")
		else
			for _,param_value in ipairs(call_queue_agent_array) do
				fs_logger("warning","[dialplan/call_queue.lua:: call queue agent not found::"..param_value['user_uuid'])
				--if param_value['user_uuid'] ~= "" then
					local user_query = {uuid = param_value['user_uuid']}
					local user_cursor = user_collection:find(user_query)
					user_array = ""
					for user_details in user_cursor:iterator() do
						user_array = user_details
					end
					if user_array == "" then
						fs_logger("warning","[dialplan/call_queue.lua:: user array empty::")
					end
				
					if (user_array ~= "" and type(user_array.callkit_token) ~= "table" and user_array.callkit_token ~= nil and user_array.callkit_token ~= "" and user_array.callkit_token ~= "null" and user_array.mobile_type ~= nil and user_array.mobile_type ~= "" and user_array.mobile_type ~= "null")then
						fs_logger("warning","[dialplan/call_queue.lua:: call queue agent not found::"..user_array.uuid)
						local extension_query = {uuid = user_array.default_extension}
						local extension_cursor = extension_collection:find(extension_query)
						extension_array = ""
						for extension_details in extension_cursor:iterator() do
							extension_array = extension_details
						end
						if extension_array ~= "" then
							if notify then
								local notify_call_type = "call_queue"
							notify(xml,user_array.uuid,user_array.callkit_token,user_array.mobile_type,callerid_name,callerid_number,extension_array.username,from_domain,notify_call_type)
							end
						end
					end
				--end			
			end
		end
	end

table.insert(xml, [[<action application="answer"/>]])
if(call_queuearray.call_welcome_greeting_uuid ~= '') then
	table.insert(xml, [[<action application="playback" data="]]..upload_file_path..[[/]]..call_queuearray.call_welcome_greeting_uuid..[[.wav"/>]]);
end
--if(tonumber(destination_number) == 123456)then

if(call_queuearray.for_pbx ~= nil and tonumber(call_queuearray.for_pbx) == 1) then

	if callerid_number == nil or callerid_number == '' then
		callerid_number = params:getHeader("Caller-Caller-ID-Number")
	end
		fs_logger("warning","[dialplan/call_queue.lua:: callerid_number::"..callerid_number)
	local callerid = skip_special_char(callerid_number)
		fs_logger("warning","[dialplan/call_queue.lua:: callerid::"..callerid)
	local lead_info = get_lead_info_for_queue(callerid)
	local lead_name = ""
	local lead_uuid = ""
	if(lead_info ~= nil and lead_info ~= "")then
		if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
			lead_name = lead_array.first_name.."__"..lead_array.last_name
		else
			lead_name = lead_array.first_name
		end
		lead_uuid = lead_info.lead_management_uuid
		fs_logger("warning","[dialplan/call_queue.lua:: Lead found::")
	else
		local str_uuid = generateUUIDv4()
		local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
		local datatoinsert = {phone_number = callerid,custom_phone_number = callerid,first_name = "Anonymous",last_name = "Anonymous",lead_management_uuid=str_uuid,tenant_uuid = caller_tenant_uuid}
		fs_logger("warning","[dialplan/call_queue.lua:: Lead not found and insert str_uuid::"..str_uuid)		
		fs_logger("warning","[dialplan/call_queue.lua:: Lead not found and insert::")		
		lead_mgmt_collection:insert(datatoinsert)
		lead_uuid = str_uuid
		lead_name = "Anonymous"
		
	end
	table.insert(xml, [[<action application="export" data="sip_h_X-Custom-Callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-Custom-Callid=]]..params:getHeader("variable_sip_call_id")..[["/>]]);
	table.insert(xml, [[<action application="export" data="sip_h_X-lead_name=]]..lead_name..[["/>]]);
	table.insert(xml, [[<action application="export" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-lead_name=]]..lead_name..[["/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);
	table.insert(xml, [[<action application="export" data="sip_h_X-inbound_campaign_flag=true"/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-inbound_campaign_flag=true"/>]]);
	table.insert(xml, [[<action application="export" data="sip_h_X-tenant_uuid=]]..caller_tenant_uuid..[["/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-tenant_uuid=]]..caller_tenant_uuid..[["/>]]);
	table.insert(xml, [[<action application="export" data="sip_h_X-queue_name=]]..call_queuearray.name..[["/>]]);
	table.insert(xml, [[<action application="set" data="sip_h_X-queue_name=]]..call_queuearray.name..[["/>]]);
	table.insert(xml, [[<action application="set" data="cc_export_vars=sip_h_X-Custom-Callid,custom_callid,sip_h_X-lead_name,sip_h_X-Leaduuid,sip_h_X-inbound_campaign_flag,sip_h_X-tenant_uuid,sip_h_X-queue_name"/>]]);
	
end
	table.insert(xml, [[<action application="set" data="pbx_feature=call_queue"/>]]);
	table.insert(xml, [[<action application="set" data="result=${luarun(common/callcenter-announce-position.lua ${uuid} ]]..call_queuearray.uuid..[[@default 30000)}"/>]])
	table.insert(xml, [[<action application="export" data="call_queue_id=]]..call_queuearray.uuid..[["/>]])
	table.insert(xml, [[<action application="callcenter" data="]]..call_queuearray.uuid..[[@default"/>]])
	-- table.insert(xml, [[<action application="hangup" data="NORMAL_CLEARING"/>]]);
--else
--	table.insert(xml, [[<action application="callcenter" data="57bd6da2-bf27-11ed-afa1-0242ac120004@default"/>]])
--end
footer_xml();

