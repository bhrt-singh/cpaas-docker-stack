fs_logger("notice","[dialplan/ring_group.lua][XML_STRING] IN RING GROUP")
local rg_collection = mongo_collection_name:getCollection "ring_group"
local user_collection = mongo_collection_name:getCollection "user" 


local query = { uuid = did_routing_uuid, status = '0' }
local projection = { extension_list = true, type = true,greeting_uuid=true, timeout = true,for_pbx=true, _id = false,uuid = true }
local cursor = rg_collection:find(query, { projection = projection })
-- iterate over the results
ring_group_array = ''
for  ring_group_details in cursor:iterator() do
    -- do something with the document
    ring_group_array = ring_group_details;
end

if(ring_group_array == '')then
	fs_logger("warning","[dialplan/ring_group.lua:: Ring Group: NIL::")
	return true;
end
	extension_list = ring_group_array.extension_list;
	ring_group_type = ring_group_array.type;
	ring_group_timeout = ring_group_array.timeout;
	ring_group_id = ring_group_array.uuid;
	
	if(ring_group_timeout == nil)then ring_group_timeout =  30 end
--fs_logger("notice","[dialplan/ring_group.lua]:: extension_list:: "..extension_list.."::ring_group_type:"..ring_group_type)
if(tonumber(ring_group_type) == 1)then
	bridge_separete_type = ','
else
	bridge_separete_type = '|'
end
	domain = params:getHeader("variable_sip_to_host");
	sip_port = 5060
	if(params:getHeader("variable_sip_to_port"))then
		sip_port = params:getHeader("variable_sip_to_port")
	end
	ringgroup_dlr_str=''
--	params_ring = JSON:decode(extension_list)
	Count = 0
	bridge_string = '{ignore_early_media=true}'
	
	if(extension_list ~= nil)then
		local caller_id_var = '';
		if(tonumber(is_did_number) == 0 and tonumber(did_as_cid) == 0)then
                        if(did_number == nil or did_number == '' )then
                                did_number = params:getHeader("variable_forward_did_number");
                                original_destination_number =  params:getHeader("variable_forward_did_number");
                        end		
			caller_id_var = "sip_h_P-effective_caller_id_name = "..did_number..",sip_h_P-effective_caller_id_number = "..did_number..","
		end
			local destination_array = {}
			local destination_key = 1
			for _, param_value in ipairs( extension_list ) do
				if(tonumber(param_value['extension_type']) == 0)then
					fs_logger("warning","[dialplan/ring_group.lua:: Ring Group: NIL::"..param_value['extension_type'])
					fs_logger("warning","[dialplan/ring_group.lua:: Ring Group: NIL::"..param_value['user_uuid'])
					local destination_entry = {} -- Create a new table for each destination
        				destination_entry['destination_number'] = param_value['user_uuid']
        				destination_entry['extension'] = param_value['extension']
					destination_array[destination_key] = destination_entry
					destination_key = destination_key + 1
					bridge_string =	bridge_string.."[call_timeout="..ring_group_timeout.."]user/"..param_value['extension'].."@"..from_domain..bridge_separete_type
				else
					if(authentication_type == "auth")then
						bridge_string =	bridge_string.."["..caller_id_var.."sip_h_P-tenant_uuid="..caller_tenant_uuid..",call_timeout="..ring_group_timeout..",leg_timeout="..ring_group_timeout..",sip_h_P-user_uuid="..caller_user_uuid..",sip_h_P-extension_uuid="..caller_uuid.."]sofia/${sofia_profile_name}/"..param_value['extension'].."@${domain}:"..sip_port..bridge_separete_type
					else
						bridge_string =	bridge_string.."["..caller_id_var.."call_timeout="..ring_group_timeout..",leg_timeout="..ring_group_timeout..",sip_h_P-tenant_uuid="..caller_tenant_uuid..",sip_h_P-authentication_type="..authentication_type.."]sofia/${sofia_profile_name}/"..param_value['extension'].."@${domain}:"..sip_port..bridge_separete_type
					end
			--variable_sip_h_P-authentication_type = authentication_type

				end
			end

		header_xml();
		if (destination_array ~= "") then
			--local callerid_name = params:getHeader("sip_h_P-effective_caller_id_name")
			--local callerid_number = params:getHeader("sip_h_P-effective_caller_id_name")
			for param_key,param_value in ipairs(destination_array) do
				local user_query = {uuid = param_value.destination_number}
				local user_cursor = user_collection:find(user_query)
				user_array = ""
				for user_details in user_cursor:iterator() do
					user_array = user_details;
				end
				if (user_array ~= "" and type(user_array.callkit_token) ~= "table" and user_array.callkit_token ~= nil and user_array.callkit_token ~= "" and user_array.callkit_token ~= "null" and user_array.mobile_type ~= nil and user_array.mobile_type ~= "" and user_array.mobile_type ~= "null")then
					if notify then
					local notify_call_type = "ringgroup"	notify(xml,user_array.uuid,user_array.callkit_token,user_array.mobile_type,callerid_name,callerid_number,param_value.extension,from_domain,notify_call_type)
					end
				end
			end	
		end
		
		--table.insert(xml, [[<action application="answer"/>]]);
		if(ring_group_array.greeting_uuid ~= '') then
			--table.insert(xml, [[<action application="playback" data="]]..upload_file_path..[[/]]..ring_group_array.greeting_uuid..[[.wav"/>]]);
			table.insert(xml, [[<action application="set" data="ringback=]]..upload_file_path..[[/]]..ring_group_array.greeting_uuid..[[.wav"/>]]);
		end
		callerid_xml('ring_group');
		if(ring_group_array.for_pbx ~= nil and tonumber(ring_group_array.for_pbx) == 1)then
			if callerid_number == nil or callerid_number == '' then
				callerid_number = params:getHeader("Caller-Caller-ID-Number")
			end
			fs_logger("warning","[dialplan/ring_group.lua:: callerid_number::"..callerid_number)
			local callerid = skip_special_char(callerid_number)
			fs_logger("warning","[dialplan/ring_group.lua:: callerid::"..callerid)
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
				table.insert(xml, [[<action application="set" data="sip_h_X-incoming_new_lead=true"/>]]);	
			end
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_name=]]..lead_name..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-lead_uuid=]]..lead_uuid..[["/>]]);
			table.insert(xml, [[<action application="export" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);
			table.insert(xml, [[<action application="set" data="sip_h_X-Leaduuid=]]..lead_uuid..[["/>]]);
		end
		table.insert(xml, [[<action application="set" data="pbx_feature=ring_group"/>]]);		      
		table.insert(xml, [[<action application="export" data="ringgroup_id=]]..ring_group_id..[["/>]]);
		table.insert(xml, [[<action application="export" data="ringgroup_from_domain=]]..from_domain..[["/>]]);
		if((original_destination_number == '' or original_destination_number == nil) and params:getHeader("variable_forward_did_number") ~= '')then
			original_destination_number =  params:getHeader("variable_forward_did_number");
			fs_logger("warning","[dialplan/ring_group.lua::original_destination_number override"..original_destination_number)
		end
		table.insert(xml, [[<action application="export" data="sip_h_X-original_destination_number=]]..original_destination_number..[["/>]]);
--table.insert(xml, [[<action application="set" data="bypass_media=true"/>]]);

		table.insert(xml, [[<action application="bridge" data="]]..bridge_string..[["/>]]);
		table.insert(xml, [[<action application="set" data="original_destination_number=]]..original_destination_number..[["/>]]);
		footer_xml();
	else
		fs_logger ("warning","No Ring Group Extension Found\n")	
		return true;
	end	
