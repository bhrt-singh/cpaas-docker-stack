fs_logger("notice","[dialplan/acl_outbound_call.lua][XML_STRING] IN PSTN")
local outgoing_rules_collection = mongo_collection_name:getCollection "outgoing_rules"
local query = { tenant_uuid = caller_tenant_uuid, status = '0' }
local projection = { rules = true, _id = false }
local cursor = outgoing_rules_collection:find(query, { projection = projection })
-- iterate over the results
outgoing_rules_array = {}
local outgoing_rules_key=1;
for  outgoing_rules_details in cursor:iterator() do
    -- do something with the document
    outgoing_rules_array[outgoing_rules_key] = outgoing_rules_details;
outgoing_rules_key = outgoing_rules_key+1
end
local destination_length = string.len(destination_number);
if((outgoing_rules_array == '' or outgoing_rules_array[1] == nil) and tenant_info.outgoing_rule_uuid ~= '')then
	fs_logger("notice","[index/acl_outbound_call.lua:: Tenant Out going ID::"..tenant_info.outgoing_rule_uuid)
	local query = { uuid = tenant_info.outgoing_rule_uuid, status = '0' }
	local projection = { rules = true, _id = false }
	local cursor = outgoing_rules_collection:find(query, { projection = projection })
	-- iterate over the results
	outgoing_rules_array = {}
	local outgoing_rules_key=1;
	for  outgoing_rules_details in cursor:iterator() do
	    -- do something with the document
	    outgoing_rules_array[outgoing_rules_key] = outgoing_rules_details;
	outgoing_rules_key = outgoing_rules_key+1
	end

end
if(outgoing_rules_array == '' or outgoing_rules_array[1] == nil)then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/acl_outbound_call.lua:: User Group Not Found/ Outgoing rules Not Set3")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end
local original_destination_number = destination_number
local custom_destination_number = destination_number
if(pstn_destination_number ~= nil)then
	fs_logger("warning","[index/acl_outbound_call.lua:: pstn_destination_number"..pstn_destination_number)
	destination_length = string.len(pstn_destination_number);
	custom_destination_number = pstn_destination_number
else
	destination_length = string.len(destination_number);
end
local loop_break = 0;
local updated_destination_number = '';
local trunk_uuid = '';
local failover_trunk_1_uuid = '';
local failover_trunk_2_uuid = '';
for outgoing_rules_param_key, outgoing_rules_param_value in ipairs( outgoing_rules_array ) do
	if(outgoing_rules_param_value.rules ~= nil and outgoing_rules_param_value.rules ~= '')then
		for param_key, param_value in ipairs( outgoing_rules_param_value.rules ) do
			fs_logger("notice","[dialplan/acl_outbound_call.lua] param_key "..param_key.."\n")			
			fs_logger("notice","[dialplan/acl_outbound_call.lua]destination_length "..destination_length.."\n")
			fs_logger("notice","[dialplan/acl_outbound_call.lua]destination_length "..param_value['prepend'].."\n")	
			if((param_value.prefix ~= '' or param_value.prefix == '*') and param_value.trunk_uuid ~= '' and (tonumber(destination_length) == tonumber(param_value.length) or tonumber(param_value.length) == 0))then
				local prefix_length = string.len(param_value.prefix);
				local destination_prefix = string.sub(custom_destination_number, 1, tonumber(prefix_length))
				fs_logger("notice","[dialplan/acl_outbound_call.lua] length: "..param_value.length.." -- prefix: "..param_value.prefix.." -- strip: "..param_value.strip.." -- prepend: "..param_value.prepend.." -- prefix_length: "..prefix_length.." --  destination_prefix: "..destination_prefix.."\n")
				if(destination_prefix == param_value.prefix or param_value.prefix == '*')then
					fs_logger("notice","[dialplan/acl_outbound_call.lua] destination_prefix Matched\n")
					fs_logger("notice","[dialplan/acl_outbound_call.lua] custom_destination_number:"..custom_destination_number.."\n")
					updated_destination_number = do_number_translation(param_value.strip,custom_destination_number)
					trunk_uuid = param_value.trunk_uuid;
					failover_trunk_1_uuid = param_value.failover_trunk_1_uuid;
					failover_trunk_2_uuid = param_value.failover_trunk_2_uuid;
					fs_logger("notice","[dialplan/acl_outbound_call.lua] updated_destination_number:"..updated_destination_number.."\n")
					updated_destination_number = param_value.prepend..updated_destination_number
					fs_logger("notice","[dialplan/acl_outbound_call.lua] updated_destination_number:"..updated_destination_number.."\n")
					loop_break = 1;					
					break;				
				end
			end
		end
		if(tonumber(loop_break) == 1)then
			break;		
		end
	end	
end
destination_number = updated_destination_number
if(updated_destination_number == '' or trunk_uuid == '')then
	hangup_cause = "NO_ROUTE_DESTINATION";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[index/acl_outbound_call.lua:: Outgoing rules Not Set")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
else
	fs_logger("notice","[index/acl_outbound_call.lua::updated_destination_number"..updated_destination_number.."\n")
	fs_logger("notice","[index/acl_outbound_call.lua::trunk_uuid"..trunk_uuid.."\n")
	local trunk_name = get_trunk_info(trunk_uuid)
	display_trunk_name =  trunk_name

	header_xml();
	callerid_xml();
	local leg_time_out = 30
	selectedcampaignuuid = params:getHeader("sip_h_X-selectedcampaignuuid");
	if(selectedcampaignuuid ~= '' and selectedcampaignuuid ~= nil)then
		local outbound_campaign_info = get_campaign_details(selectedcampaignuuid)
		if(outbound_campaign_info ~= nil and outbound_campaign_info ~= '' and outbound_campaign_info.timeout ~= '' )then
			leg_time_out = outbound_campaign_info.timeout
			fs_logger("notice","[index/outbound_call.lua::Outbound campaign Time-out"..leg_time_out.."\n")
		end
	end
	time_out_str = "leg_timeout="..leg_time_out
	if(tonumber(is_did_number) == 0 and tonumber(did_as_cid) == 0)then
		if(did_number == nil or did_number == '' )then
                        did_number = params:getHeader("variable_forward_did_number");
                        original_destination_number =  params:getHeader("variable_forward_did_number");
                end	
		fs_logger("notice","[index/acl_outbound_call.lua::DID number As Caller ID"..did_number.."\n")
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
	table.insert(xml, [[<action application="set" data="did_pstn=0"/>]]);		
	--else
	--	table.insert(xml, [[<action application="export" data="custom_recording=1"/>]]);
	--end

	if(trunk_name ~= '' and trunk_name ~= nil)then
		table.insert(xml, [[<action application="bridge" data="[]]..time_out_str..[[]sofia/gateway/]]..trunk_name..[[/]]..updated_destination_number..[["/>]])	
	end
	if(failover_trunk_1_uuid ~= '' and failover_trunk_1_uuid ~= nil)then
		local trunk_name1 = get_trunk_info(failover_trunk_1_uuid)
		if(trunk_name1~= '' and trunk_name1 ~= nil)then
			table.insert(xml, [[<action application="bridge" data="[]]..time_out_str..[[]sofia/gateway/]]..trunk_name1..[[/]]..updated_destination_number..[["/>]])	
		end
	end
	if(failover_trunk_2_uuid ~= '' and failover_trunk_1_uuid ~= nil)then
		local trunk_name2 = get_trunk_info(failover_trunk_2_uuid)
		if(trunk_name2~= '' and trunk_name1 ~= nil)then
			table.insert(xml, [[<action application="bridge" data="[]]..time_out_str..[[]sofia/gateway/]]..trunk_name2..[[/]]..updated_destination_number..[["/>]])	
		end
	end
	footer_xml();
end

