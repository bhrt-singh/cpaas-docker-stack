fs_logger("notice","[dialplan/external_user.lua][XML_STRING] IN PSTN")
local user_array = get_userinfo(caller_user_uuid)
if(user_array == nil or user_array == '' or user_array.user_group_uuid == '')then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/external_user.lua:: Outgoing rules Not Set1")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end

local user_group_collection = mongo_collection_name:getCollection "user_group"
local query = { uuid = user_array.user_group_uuid, status = '0' }
local projection = { outbound_rule = true, _id = false }
local cursor = user_group_collection:find(query, { projection = projection })
-- iterate over the results
user_group_array = ""
for  user_group_details in cursor:iterator() do
    -- do something with the document
    user_group_array = user_group_details;
end
local destination_length = string.len(destination_number);
if(user_group_array == nil or user_group_array == '' or user_group_array.outbound_rule == '')then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/external_user.lua:: User Group Not Found/ Outgoing rules Not Set2")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end


local outgoing_rules_collection = mongo_collection_name:getCollection "outgoing_rules"
local query = { uuid = user_group_array.outbound_rule, status = '0' }
local projection = { rules = true,uuid= true, _id = false }
local cursor = outgoing_rules_collection:find(query, { projection = projection })
-- iterate over the results
outgoing_rules_array = ""
for  outgoing_rules_details in cursor:iterator() do
    -- do something with the document
    outgoing_rules_array = outgoing_rules_details;
end
local original_destination_number = destination_number
local custom_destination_number = destination_number
if(pstn_destination_number ~= nil)then
	fs_logger("warning","[index/external_user.lua:: pstn_destination_number"..pstn_destination_number)
	destination_length = string.len(pstn_destination_number);
	custom_destination_number = pstn_destination_number
else
	destination_length = string.len(destination_number);
end
if(outgoing_rules_array == '')then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/external_user.lua:: User Group Not Found/ Outgoing rules Not Set3")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end
local loop_break = 0;
local updated_destination_number = '';
local trunk_uuid = '';
local failover_trunk_1_uuid = '';
local failover_trunk_2_uuid = '';
for param_key, param_value in ipairs( outgoing_rules_array.rules ) do
	fs_logger("notice","[dialplan/ring_group.lua] param_key "..param_key.."\n")
	
	fs_logger("notice","[dialplan/ring_group.lua]destination_length "..destination_length.."\n")
	fs_logger("notice","[dialplan/ring_group.lua]destination_length "..param_value['prepend'].."\n")	
	if((param_value.prefix ~= '' or param_value.prefix == '*') and param_value.trunk_uuid ~= '' and (tonumber(destination_length) == tonumber(param_value.length) or tonumber(param_value.length) == 0))then
		local prefix_length = string.len(param_value.prefix);
		local destination_prefix = string.sub(custom_destination_number, 1, tonumber(prefix_length))
		fs_logger("notice","[dialplan/ring_group.lua] length: "..param_value.length.." -- prefix: "..param_value.prefix.." -- strip: "..param_value.strip.." -- prepend: "..param_value.prepend.." -- prefix_length: "..prefix_length.." --  destination_prefix: "..destination_prefix.."\n")
		if(destination_prefix == param_value.prefix or param_value.prefix == '*')then
			fs_logger("notice","[dialplan/ring_group.lua] destination_prefix Matched\n")
			fs_logger("notice","[dialplan/ring_group.lua] custom_destination_number:"..custom_destination_number.."\n")
			updated_destination_number = do_number_translation(param_value.strip,custom_destination_number)
			trunk_uuid = param_value.trunk_uuid;
			failover_trunk_1_uuid = param_value.failover_trunk_1_uuid;
			failover_trunk_2_uuid = param_value.failover_trunk_2_uuid;
			fs_logger("notice","[dialplan/ring_group.lua] updated_destination_number:"..updated_destination_number.."\n")
			updated_destination_number = param_value.prepend..updated_destination_number
			fs_logger("notice","[dialplan/ring_group.lua] updated_destination_number:"..updated_destination_number.."\n")
			break;				
		end
	end		
end
if(updated_destination_number == '' or trunk_uuid == '')then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/external_user.lua:: Outgoing rules Not Set2")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
else
	fs_logger("notice","[index/external_user.lua::updated_destination_number"..updated_destination_number.."\n")
	fs_logger("notice","[index/external_user.lua::trunk_uuid"..trunk_uuid.."\n")
	local trunk_name = get_trunk_info(trunk_uuid)
	display_trunk_name =  trunk_name
	header_xml();	
	callerid_xml();
	local leg_time_out = 30
	selectedcampaignuuid = params:getHeader("sip_h_X-selectedcampaignuuid");
	campaign_flag = params:getHeader('sip_h_X-campaign_flag');
	if(selectedcampaignuuid ~= '' and selectedcampaignuuid ~= nil)then
		local campaign_info = get_campaign_details(selectedcampaignuuid,campaign_flag)
		if(campaign_info ~= nil and campaign_info ~= '' and campaign_info.timeout ~= '' )then
			leg_time_out = campaign_info.timeout
			fs_logger("notice","[index/outbound_call.lua::Outbound campaign Time-out"..leg_time_out.."\n")
		end
	end
	time_out_str = ",leg_timeout="..leg_time_out
	if(tonumber(is_did_number) == 0 and tonumber(did_as_cid) == 0)then
		fs_logger("notice","[index/external_user.lua::DID number As Caller ID"..did_number.."\n")
		table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..did_number..[["/>]]);
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..did_number..[["/>]]);
	end
	table.insert(xml, [[<action application="set" data="hangup_after_bridge=true"/>]]);
	table.insert(xml, [[<action application="set" data="continue_on_fail=TRUE"/>]]);
	--if(tonumber(sip_destination_array.recording) == 0)then
	if(tonumber(custom_record_flag) == 0)then
		table.insert(xml, [[<action application="export" data="custom_recording=0"/>]]);	
		table.insert(xml, [[<action application="export" data="execute_on_answer=record_session $${recordings_dir}/${uuid}.wav"/>]]);
	end
	--else
	--	table.insert(xml, [[<action application="export" data="custom_recording=1"/>]]);
	--end

	if(trunk_name ~= '' and trunk_name ~= nil)then
		table.insert(xml, [[<action application="bridge" data="[sip_h_P-tenant_uuid=]]..caller_tenant_uuid..[[,sip_h_P-user_uuid=]]..caller_user_uuid..[[,sip_h_P-extension_uuid=]]..caller_uuid..[[]]..time_out_str..[[]sofia/gateway/]]..trunk_name..[[/]]..updated_destination_number..[["/>]])	
	end
	if(failover_trunk_1_uuid ~= '' and failover_trunk_1_uuid ~= nil)then
		local trunk_name1 = get_trunk_info(failover_trunk_1_uuid)
		if(trunk_name1~= '' and trunk_name1 ~= nil)then
			table.insert(xml, [[<action application="bridge" data="[sip_h_P-tenant_uuid=]]..caller_tenant_uuid..[[,sip_h_P-user_uuid=]]..caller_user_uuid..[[,sip_h_P-extension_uuid=]]..caller_uuid..[[]]..time_out_str..[[]sofia/gateway/]]..trunk_name1..[[/]]..updated_destination_number..[["/>]])	
		end
	end
	if(failover_trunk_2_uuid ~= '' and failover_trunk_1_uuid ~= nil)then
		local trunk_name2 = get_trunk_info(failover_trunk_2_uuid)
		if(trunk_name2~= '' and trunk_name1 ~= nil)then
			table.insert(xml, [[<action application="bridge" data="[sip_h_P-tenant_uuid=]]..caller_tenant_uuid..[[,sip_h_P-user_uuid=]]..caller_user_uuid..[[,sip_h_P-extension_uuid=]]..caller_uuid..[[]]..time_out_str..[[]sofia/gateway/]]..trunk_name2..[[/]]..updated_destination_number..[["/>]])	
		end
	end
	footer_xml();
end
