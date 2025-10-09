JSON = (loadfile (scripts_dir .."common/JSON.lua"))();

if (params:serialize() ~= nil) then
	if(params_log == 0)then
	        fs_logger("info","[dialplan/index.lua][xml_handler] Params:\n" .. params:serialize())
	end
end


destination_number = params:getHeader("Hunt-Destination-Number");
originate_destination_number = destination_number
original_destination_number = destination_number
routed_destination_number = ''
webphonetransfer = 0
did_as_cid = 1
custom_record_flag = 0
--sticky_agent_str  = "";
three_way_callerid_flag = 0;
custom_caller_id = "";
sticky_agent_flag = "1";
is_pbx_transfer = 0
threeway_transfer_flag = 1
threeway_agent_extension = "";
threeway_agent_extension_uuid = "";
to_domain = params:getHeader("variable_sip_to_host");
from_domain = params:getHeader("variable_sip_from_host");
caller_uuid = params:getHeader("variable_extension_uuid");
--caller_uuid = "c5f896e5-0d3f-45ea-ad13-a6b6331060e7";  -- HARDIK TEMP :::  params:getHeader("variable_extension_uuid");
--caller_user_uuid = "e3f3686f-5e54-4b0e-9758-1a4b8108d75c"
caller_user_uuid = params:getHeader("variable_user_uuid");
caller_tenant_uuid =  params:getHeader("variable_domain_uuid")
--caller_tenant_uuid = "89c1b939-bb13-476d-b217-9bfa5373ed0a"; -- HARDIK TEMP:::  params:getHeader("variable_tenant_uuid")
tenant_account_code = "";
campaign_uuid = params:getHeader("variable_sip_h_X-selectedcampaignuuid")
campaign_flag = params:getHeader("variable_sip_h_X-campaign_flag")
if(caller_tenant_uuid == '' or caller_tenant_uuid == nil)then
	caller_tenant_uuid = params:getHeader("variable_sip_h_P-tenant_uuid")
end
if(caller_user_uuid == '' or caller_user_uuid == nil)then
	caller_user_uuid = params:getHeader("variable_sip_h_P-user_uuid")
end
if(caller_uuid == '' or caller_uuid == nil)then
	caller_uuid = params:getHeader("variable_sip_h_P-extension_uuid")
--	caller_uuid = "c5f896e5-0d3f-45ea-ad13-a6b6331060e7";  
--	caller_user_uuid = "e3f3686f-5e54-4b0e-9758-1a4b8108d75c"; 
--	caller_tenant_uuid = "89c1b939-bb13-476d-b217-9bfa5373ed0a"; 
end
if (from_domain ~= "")then
--	local check_licence = check_licence_validate(from_domain)
	local check_licence = 0
	if(check_licence == 1)then
		hangup_cause = "AUTHENTICATION_FAIL";
		fail_audio_file = sounds_dir..'/badnumber.wav';
		fs_logger("warning","[dialplan/index.lua WHMCS Licence key not found/Expired.")
		dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
		return true;
	end
end
if(tonumber(destination_number) ~= 17027025991)then
local check_dispo = check_dispo_count(destination_number)
if(tonumber(check_dispo) == 1)then
	hangup_cause = "AUTHENTICATION_FAIL";
	fs_logger("warning","[dialplan/index.lua check_dispo section ::::.")
	fail_audio_file = sounds_dir..'/badnumber.wav';
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;

end

-- ::: HARDIK TEMP START -------
--local first_three_destination_number = string.sub(tostring(destination_number), 1, 3)
--is_check_area_code = check_area_code(first_three_destination_number)
--fs_logger("notice","[dialplan/index.lua:: is_check_area_code::"..is_check_area_code);
--if(tonumber(is_check_area_code) == 1)then
--	hangup_cause = "AUTHENTICATION_FAIL";
--	fail_audio_file = sounds_dir..'/badnumber.wav';
--	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
--	return true;
--
--end
end
-- ::::::::::: -------------- --
if(destination_number == '921234567' or destination_number == '92123456789' )  then

	fs_logger("notice","[dialplan/index.lua:: conference_mobile MOBILE CONFERENCE::");
	dofile(scripts_dir .. "dialplan/custom_playback.lua");
	return true;
end
if(destination_number == '10011001') then

	fs_logger("notice","[dialplan/index.lua:: conference_mobile MOBILE CONFERENCE::");
	dofile(scripts_dir .. "dialplan/conference_mobile.lua");
	return true;
end
if(params:getHeader("variable_spy")) then
--Run Command :: originate {spy=true,cust_uuid=38ab724c-1489-48ac-90b0-847bad333b7b}user/104@harsh2.inextrix.com 104 xml external mod_spy mod_spy mod_spy
	fs_logger("notice","[dialplan/index.lua:: In Call Monitor");
	dofile(scripts_dir .. "dialplan/call_monitor.lua");
	return true;
end
if(params:getHeader("variable_barge")) then
--Run Command :: originate {barge=true,cust_uuid=840f9bb8-f582-4dbf-a9cd-e492d0744659}user/104@harsh2.inextrix.com 104 xml external mod_barge mod_barge mod_barge
	fs_logger("notice","[dialplan/index.lua:: In Call Barge");
	dofile(scripts_dir .. "dialplan/call_barge.lua");
	return true;
end
if(params:getHeader("variable_whisper")) then
--Run Command :: originate {whisper=true,cust_uuid=85b72bf1-51c7-4c06-891b-fadb759ffc3b}user/104@harsh2.inextrix.com 104 xml external mod_whisper mod_whisper mod_whisper
	fs_logger("notice","[dialplan/index.lua:: In Call Whisper");
	dofile(scripts_dir .. "dialplan/call_whisper.lua");
	return true;
end
if(destination_number == 'attended_xfer') then
--Run Command :: originate {barge=true,cust_uuid=840f9bb8-f582-4dbf-a9cd-e492d0744659}user/104@harsh2.inextrix.com 104 xml external mod_barge mod_barge mod_barge
	fs_logger("notice","[dialplan/index.lua:: attended_xfer");
	dofile(scripts_dir .. "dialplan/app_conference.lua");
	return true;
end

if(string.find(destination_number,'webphonetransfer')) then
	webphonetransfer = 1
end

if(string.find(destination_number,'PBX')) then
	is_pbx_transfer = 1
end



is_sticky_did_number = check_did_info(destination_number)

if (is_sticky_did_number == 1 and destination_number ~= '' and destination_number ~= nil and caller_tenant_uuid ~= nil and caller_tenant_uuid ~= '' and webphonetransfer == 0 and is_pbx_transfer == 0 )then
	local user_collection = mongo_collection_name:getCollection "user"
	local user_role_collection = mongo_collection_name:getCollection "user_role"
	local sticky_agent_collecc = mongo_collection_name:getCollection "sticky_agent"
	local extension_collection = mongo_collection_name:getCollection "extensions"
	
	local extension_query = {username = destination_number}
	local extension_data = extension_collection:find(extension_query)
	extension_array = ""
	for extension_data in extension_data:iterator() do
		extension_array = extension_data
	end
	
	if extension_array == '' then
		local sticky_query = {phone_number = destination_number,tenant_uuid = caller_tenant_uuid}
		local sticky_data = sticky_agent_collecc:find(sticky_query)
		sticky_array = ''
		for sticky_data in sticky_data:iterator() do
			sticky_array = sticky_data
		end
		if(sticky_array == "")then 
			fs_logger("warning","[dialplan/custom.lua:: STICKY AGENT INFO: NIL::")
			fs_logger("warning","[dialplan/custom.lua:: STICKY AGENT INFO: NIL::")
			local user_query = {uuid = params:getHeader("variable_user_uuid")}
			local user_data = user_collection:find(user_query)
			user_array = ''
			for user_data in user_data:iterator() do
				user_array = user_data
			end
			if(user_array ~= "")then
				fs_logger("warning","[dialplan/custom.lua:: STICKY AGENT INFO: not user NIL::")
				local user_role_query = {uuid = user_array.user_role_uuid}
				local user_role_data = user_role_collection:find(user_role_query)
				user_role_array = ''
				for user_role_data in user_role_data:iterator() do
					user_role_array = user_role_data
				end
				if (user_role_array ~= '' and  tonumber(user_role_array.sticky_agent) ~= 1)then
				local sticky_collection = mongo_collection_name:getCollection "sticky_agent"
					sticky_uuid = generateUUIDv4()
					local datatoinsert = {phone_number = destination_number,user_uuid = caller_user_uuid,tenant_uuid = caller_tenant_uuid,user_role_uuid = user_role_array.uuid,uuid = sticky_uuid,sticky_user_role_status = '0'}
					--local datatoinsert = {phone_number = "91372887745928",user_uuid = "fagdfgadfhadf",tenant_uuid = "kjfhghsfgjs",user_role_uuid = "jkhfshfkjvjnsklf"}
					fs_logger("warning","[dialplan/custom.lua:: STICKY AGENT INFO: not user NIL::"..datatoinsert.phone_number)
					
					sticky_collection:insert(datatoinsert)
					--fs_logger("warning","[dialplan/custom.lua:: STICKY AGENT INFO: not user NIL insert::"..insert)
				end
			end
		end
	end
end


if (is_sticky_did_number == 1 and params:getHeader("variable_sip_h_X-selectedcampaignuuid") and params:getHeader("variable_sip_h_X-selectedcampaignuuid") ~= '' and params:getHeader("variable_sip_h_X-selectedcampaignuuid") ~= nil and params:getHeader("variable_sip_h_X-type") and params:getHeader("variable_sip_h_X-type") == 'transfer')then
	threeway_transfer_flag = 0;
	local campaign_array = ''
	-- local outbound_campaign_uuid = params:getHeader("variable_sip_h_X-selectedcampaignuuid")
	if(campaign_flag and campaign_flag ~= nil and campaign_flag == 'blended')then
			local blended_campaign_collection = mongo_collection_name:getCollection "blended_campaign"
			local blended_query = {uuid = campaign_uuid}
			local blended_data = blended_campaign_collection:find(blended_query)
			for blended_data in blended_data:iterator() do
					campaign_array = blended_data
			end
	elseif(campaign_flag and campaign_flag ~= nil and campaign_flag == 'outbound')then
			local outbound_campaign_collection = mongo_collection_name:getCollection "outbound_campaign"
			local outbound_query = {uuid = campaign_uuid}
			local outbound_data = outbound_campaign_collection:find(outbound_query)
			for outbound_data in outbound_data:iterator() do
					campaign_array = outbound_data
			end

	end
	if(campaign_array ~= '' and tonumber(campaign_array.three_way_caller_id) == 0)then
		fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Three way callerid is 0 ::")
		three_way_callerid_flag = 0;
	elseif(campaign_array ~= '' and tonumber(campaign_array.three_way_caller_id) == 1)then
		fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Three way callerid is 1 ::")
		three_way_callerid_flag = 1;
		local customer_callerid_management_collection = mongo_collection_name:getCollection "customer_callerid_management"
		local customer_callerid_query = {user_uuid = caller_uuid}
		local customer_callerid_data = customer_callerid_management_collection:find(customer_callerid_query)
		local customer_callerid_array = ''
		for customer_callerid_data in customer_callerid_data:iterator() do
			customer_callerid_array = customer_callerid_data
		end
		if customer_callerid_array == "" then
			fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: NIL::")
		else
			if(customer_callerid_array ~= '' and customer_callerid_array.phone_number ~= '')then 
				threeway_agent_extension = customer_callerid_array.phone_number
				threeway_agent_extension_uuid = customer_callerid_array.user_uuid
			end
		end
		
		--if(caller_uuid ~= "") then
		--	local extension_collection = mongo_collection_name:getCollection "extensions"
		--	local extension_query = {uuid = caller_uuid}
		--	local extension_data = extension_collection:find(extension_query)
		--	local extension_array = ""
		--	for extension_data in extension_data:iterator() do
		--		extension_array = extension_data
		--	end
		--	
			--if extension_array == "" then 
			--	fs_logger("warning","[dialplan/index.lua:: extension INFO: NIL::")
			--else
			--	fs_logger("warning","[dialplan/index.lua:: extension INFO :::")
			--	if (extension_array ~= "" and extension_array.caller_id_number ~= '') then
			--		threeway_agent_extension = extension_array.caller_id_number
			--	elseif(extension_array ~= "" and extension_array.username ~= '') then
			--		threeway_agent_extension = extension_array.username
			--	end
			--end
		--end
		
	elseif(campaign_array ~= '' and tonumber(campaign_array.three_way_caller_id) == 2 and campaign_array.custom_caller_id ~= '')then
		fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Three way callerid is 2 ::")
		three_way_callerid_flag = 2;
		custom_caller_id = campaign_array.custom_caller_id
	else
		three_way_callerid_flag = 0;
	end
end

if (is_sticky_did_number == 1 and params:getHeader("variable_sip_h_X-selectedcampaignuuid") and params:getHeader("variable_sip_h_X-selectedcampaignuuid") ~= '' and params:getHeader("variable_sip_h_X-selectedcampaignuuid") ~= nil)then
	if (params:getHeader("variable_sip_h_X-type") and params:getHeader("variable_sip_h_X-type") == 'transfer')then
		fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Adesh this your transfer"..params:getHeader("Core-UUID"))
	else
		fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Adesh this your call")
		--fs_logger("warning","[dialplan/index.lua:: OUTBOUND CAMPAIGN INFO: Adesh this your call"..params:getHeader("variable_extension_uuid"))
		local customer_callerid_management_collection = mongo_collection_name:getCollection "customer_callerid_management"
		customer_caller_uuid = generateUUIDv4()
		threeway_agent_extension_uuid = caller_uuid
		local datatoinsert = {phone_number = destination_number,user_uuid = caller_uuid,uuid = customer_caller_uuid}
		customer_callerid_management_collection:insert(datatoinsert)
		
	end
end



if (is_sticky_did_number == 1 and destination_number ~= '' and destination_number ~= nil and caller_tenant_uuid ~= nil and caller_tenant_uuid ~= '' and campaign_uuid ~= nil and campaign_uuid ~= '')then
	fs_logger("warning","[dialplan/index.lua::destination number::::::"..destination_number)
	fs_logger("warning","[dialplan/index.lua:: tenant uuid::::::"..caller_tenant_uuid)
	fs_logger("warning","[dialplan/index.lua::destination number::::::"..is_did_number)
	fs_logger("warning","[dialplan/index.lua::destination number::::::"..campaign_uuid)
	local dnc_collection = mongo_collection_name:getCollection "dnc"
	local query = {phone_number = destination_number,tenant_uuid = caller_tenant_uuid}
	local cursor = dnc_collection:find(query)
	local dnc_array = ''
	for dnc_details in cursor:iterator() do
		dnc_array = dnc_details;
	end
	if (dnc_array.phone_number ~= nil and dnc_array.phone_number ~= '')then
		if (dnc_array.global_status ~= nil and tonumber(dnc_array.global_status) == 0)then 
			local sip_from_user = destination_number
			hangup_cause = "AUTHENTICATION_FAIL";
			fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
			fs_logger("warning","[dialplan/index.lua tenant:: No Route To Destination.")
			dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
			return true;
		else
			if (campaign_uuid ~= '' and campaign_uuid ~= nil)then
				if (campaign_uuid == dnc_array.campaign_uuid)then
					local sip_from_user = destination_number
					hangup_cause = "AUTHENTICATION_FAIL";
					fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
					fs_logger("warning","[dialplan/index.lua campaign:: No Route To Destination.")
					dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
					return true;
				end
			end
		end
	end 
	
	
	
end

	

fail_call_flag = 0
authentication_type = 'auth'
if(params:getHeader("variable_authentication_type") ~= nil)then
	authentication_type = params:getHeader("variable_authentication_type")
end
if(params:getHeader("variable_sip_h_P-authentication_type") ~= nil)then
	authentication_type = params:getHeader("variable_sip_h_P-authentication_type")
end

	if(params:getHeader('variable_sip_h_P-voicebroadcast') == 'true')then
		authentication_type = 'acl'
	end
local current_custom_application = params:getHeader("variable_current_application");
time_condition_frwd = 0
if(current_custom_application and current_custom_application == 'execute_extension')then
	time_condition_frwd = 1
	local forward_did_number = params:getHeader("variable_forward_did_number")
	local did_acl_destination_array = check_acl_did_info(forward_did_number)
	if(did_acl_destination_array ~= nil and did_acl_destination_array.tenant_uuid ~= nil and did_acl_destination_array.tenant_uuid ~= '')then
		caller_tenant_uuid = did_acl_destination_array.tenant_uuid
		did_number = did_acl_destination_array.number
		if(did_acl_destination_array.did_as_cid ~= nil and did_acl_destination_array.did_as_cid ~= "")then
			did_as_cid = did_acl_destination_array.did_as_cid
			fs_logger("warning","[dialplan/index.lua:: did_as_cid:::"..did_as_cid..":::")
		end

	end
	if(caller_uuid == '' or caller_uuid == nil)then
		authentication_type = 'acl'
	end
end
fs_logger("warning","[dialplan/index.lua:: time_condition_frwd:::"..time_condition_frwd..":::")
if(caller_tenant_uuid == '' or caller_tenant_uuid == nil and time_condition_frwd == 0)then
	from_ip = params:getHeader('Hunt-Network-Addr')
		fs_logger("warning","[dialplan/index.lua:: CHECK FOR IP MAP:::"..from_ip..":::")
		local ip_mapping_collection = mongo_collection_name:getCollection "ip_mapping"
		local query = {  status = '0', ip = from_ip}
		local projection = { uuid=true, ip = true,prefix = true,tenant_uuid = true, _id = false }
		--local cursor = ip_mapping_collection:find(query,{ projection = projection, }):sort({ field = -1 }):toArray()
		local cursor = ip_mapping_collection:find(query,{ projection = projection, })

		local ip_mapping_array = {}
		local ipmap_key=1;
		for ip_mapping_details in cursor:iterator() do
			ip_mapping_array[ipmap_key] = ip_mapping_details;
			ipmap_key = ipmap_key+1
		end

		local admin_ip_mapping_collection = mongo_collection_name:getCollection "admin_ip_mapping"
		local admin_query = {  status = '0', ip = from_ip}
		local admin_projection = { uuid=true, ip = true,prefix = true, _id = false }
		local admin_cursor = admin_ip_mapping_collection:find(admin_query,{ projection = admin_projection, })
		for admin_ip_mapping_details in admin_cursor:iterator() do
			ip_mapping_array[ipmap_key] = admin_ip_mapping_details;
			ipmap_key = ipmap_key+1
		end
		
		local acl_flag = 0
		if(ip_mapping_array ~= nil and ip_mapping_array[1] ~= nil)then
			ip_map_uuid = ''
			table.sort(ip_mapping_array ,  function (a, b) return  (a.prefix >  b.prefix ) end)        
			for param_key, param_value in ipairs( ip_mapping_array ) do
				if(param_value.ip ~= nil and param_value.ip ~= '')then
					local prefix_length = string.len(param_value.prefix);
					local destination_prefix = string.sub(destination_number, 1, tonumber(prefix_length))
					if(tonumber(param_value.prefix) == tonumber(destination_prefix) or param_value.prefix == '')
					then
							destination_number = do_number_translation(param_value.prefix,destination_number)
fs_logger("notice","[common/index.lua:: destination_number::"..destination_number)
						local did_acl_destination_array = check_acl_did_info(destination_number)
						if(did_acl_destination_array ~= nil and did_acl_destination_array.tenant_uuid ~= nil and did_acl_destination_array.tenant_uuid ~= '')then
							caller_tenant_uuid = did_acl_destination_array.tenant_uuid
							did_number = did_acl_destination_array.number
							if(did_acl_destination_array.did_as_cid ~= nil and did_acl_destination_array.did_as_cid ~= "")then
								did_as_cid = did_acl_destination_array.did_as_cid
								fs_logger("warning","[dialplan/index.lua:: did_as_cid:::"..did_as_cid..":::")
							end
							fs_logger("notice","[common/index.lua:: IP Mapping IP EXIST::"..param_value.ip)
							fs_logger("notice","[common/index.lua:: IP Mapping IP ADDED::"..param_value.prefix)
							ip_map_uuid = param_value.uuid
							fs_logger("notice","[common/index.lua:: IP Mapping destination_prefix::"..destination_prefix)
							fs_logger("notice","[common/index.lua:: IP Mapping caller_tenant_uuid::"..caller_tenant_uuid)
							break;
						end
					end
				end
			end
		end
tenant_info = get_tenant_info(caller_tenant_uuid)
from_domain = tenant_info.domain
tenant_account_code = tenant_info.account_code
	if(caller_tenant_uuid ~= '' and caller_tenant_uuid ~= nil)then
		authentication_type = 'acl'
		if (params:getHeader("Caller-Caller-ID-Number") and params:getHeader('Caller-Caller-ID-Number') ~= '' and params:getHeader('Caller-Caller-ID-Number') ~= nil)then
			fs_logger("warning","[dialplan/index.lua:: adesh callerid found::::::")
			callerid = params:getHeader('Caller-Caller-ID-Number')
			callerid = skip_plus_sign(callerid)
			fs_logger("warning","[dialplan/index.lua:: adesh callerid found::::::"..callerid)
			fs_logger("warning","[dialplan/index.lua:: adesh callerid found::::::"..caller_tenant_uuid)
			local block_inbound_collection = mongo_collection_name:getCollection "block_inbound_campaign"
			local blacklist_callerid_find = 0
			while string.len(callerid) > 0 do
				local query = {type_value = callerid,tenant_uuid = caller_tenant_uuid }
				--local projection = { type_value = true, _id = false }
				local cursor = block_inbound_collection:find(query)
				local blacklist_array = ''
				for blacklist_details in cursor:iterator() do
					blacklist_array = blacklist_details;
				end
				if callerid == blacklist_array.type_value then
					fs_logger("warning","[dialplan/index.lua:: adesh callerid found::::::"..callerid)
					blacklist_callerid_find = 1		
				end
				
				if (blacklist_callerid_find == 1) then break; end
				callerid  = callerid:sub(1,-2)
				fs_logger("warning","[dialplan/index.lua:: adesh callerid found::::::"..callerid)
			end
			if (blacklist_callerid_find == 1) then
				local sip_from_user = callerid
				hangup_cause = "AUTHENTICATION_FAIL";
				fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
				fs_logger("warning","[dialplan/index.lua:: No Route To Destination.")
				dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
				return true;
				end		
		end
		local sticky_agent_collection = mongo_collection_name:getCollection "sticky_agent"
		local user_role_collection = mongo_collection_name:getCollection "user_role"
		callerid = params:getHeader("Caller-Caller-ID-Number")
		callerid = skip_plus_sign(callerid)
		local sticky_query = {phone_number = callerid ,tenant_uuid = caller_tenant_uuid}
		local sticky_data = sticky_agent_collection:find(sticky_query)
		local sticky_array = ''
		for sticky_data in sticky_data:iterator() do
			sticky_array = sticky_data
		end
		if(sticky_array ~= '' and sticky_array.user_uuid ~= '' and sticky_array.user_uuid ~= nil and sticky_array.sticky_user_role_status == '0')then
			fs_logger("warning","[dialplan/index.lua:: Transfer to sticky agent ::"..sticky_array.user_uuid)
			caller_user_uuid = sticky_array.user_uuid
			dofile(scripts_dir .. "dialplan/sticky_agent.lua");
			return true;
		end
	
	else
		fs_logger("warning","[dialplan/index.lua:: caller_tenant_uuid Not Found/Fake Request")
		fail_call_flag = 1 
		xml = {};
		table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
		table.insert(xml, [[<document type="freeswitch/xml">]]);
		table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
		table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
		table.insert(xml, [[<extension name="]]..destination_number..[[">]]);
		table.insert(xml, [[<condition field="destination_number" expression="]]..skip_special_char(destination_number)..[[">]]);
		table.insert(xml, [[<action application="set" data="sip_ignore_remote_cause=true"/>]]);        
		table.insert(xml, [[<action application="hangup" data="NO_USER_FOUND"/>]]);
		footer_xml();		
		return true;
	end
 end

tenant_info = get_tenant_info(caller_tenant_uuid)
if(tenant_info == '' or tenant_info == nil)then fail_call_flag = 1 end

from_domain = tenant_info.domain
tenant_account_code = tenant_info.account_code

if(tonumber(fail_call_flag) == 1)then
	local sip_from_user = params:getHeader("variable_sip_from_user")
	hangup_cause = "AUTHENTICATION_FAIL";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[dialplan/index.lua:: Tenant Is Inactive/deleted. Not Found")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end
caller_user_recording_flag = 1
--Check Click2call info
local click_to_call_array = check_click2call_info(destination_number)
if(click_to_call_array ~= nil and click_to_call_array ~= '' and click_to_call_array.clicktocall_forwarding_type ~= nil and click_to_call_array.clicktocall_forwarding_value ~= nil and click_to_call_array.clicktocall_forwarding_type ~= '' and click_to_call_array.clicktocall_forwarding_value ~= '')then
	is_click2call_number = 0
	call_type = 'click2call';
	fs_logger("notice","[dialplan/index.lua:: In Click2call")	
	caller_tenant_uuid = click_to_call_array.tenant_uuid;
	caller_user_uuid =click_to_call_array.user_uuid;
	callerid_name =click_to_call_array.callier_id_number;
	callerid_number =click_to_call_array.callier_id_number;
	tenant_info = get_tenant_info(caller_tenant_uuid)
	authentication_type = 'click2call';	
	destination_number = 'click2call';
	caller_uuid = 'click2call';
end
if(authentication_type == 'auth') then caller_user_info = get_userinfo(caller_user_uuid) end
if(authentication_type == 'auth' and (caller_user_info == '' or caller_user_uuid == nil or caller_user_uuid == '' or caller_tenant_uuid == ''))then
	hangup_cause = "AUTHENTICATION_FAIL";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[dialplan/index.lua:: Caller User Info Not Found.")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
else
	if(caller_user_info ~= nil and caller_user_info.recording ~= '' and tonumber(caller_user_info.recording) == 0) then
		caller_user_recording_flag = 0
		fs_logger("notice","[dialplan/index.lua:: Caller User Recording flag is enable")		
	end
end

caller_info = get_caller_info(caller_uuid)
if (params:getHeader('variable_caller_id_number') ~= nil) then
    callerid_number = params:getHeader('variable_caller_id_number') or ""
    callerid_name = params:getHeader('variable_caller_id_name') or callerid_number
else
    callerid_number = params:getHeader('Caller-Caller-ID-Number') or ""
    callerid_name = params:getHeader('Caller-Caller-ID-Name') or callerid_number
end  
caller_sip_recording_flag = 1
if((caller_info == '' or caller_uuid == '' or caller_tenant_uuid == '') and call_type ~='click2call')then
	local sip_from_user = params:getHeader("variable_sip_from_user")
	hangup_cause = "AUTHENTICATION_FAIL";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[dialplan/index.lua:: sip_from_user"..sip_from_user.." Is Inactive/deleted.")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
else
	if(caller_info.caller_id_name ~= '' and callerid_name == nil)then
		callerid_name = caller_info.caller_id_name
	end
	if(caller_info.caller_id_number ~= '' and callerid_number == nil)then
		callerid_number = caller_info.caller_id_number
	end
	if(call_type == 'click2call')then
		callerid_name =click_to_call_array.callier_id_number;
		callerid_number =click_to_call_array.callier_id_number;
		fs_logger("warning","[dialplan/index.lua::Click2call callerid_number"..callerid_number)
	end
	if(caller_info.recording ~= '' and tonumber(caller_info.recording) == 0) then
		caller_sip_recording_flag = 0
		fs_logger("notice","[dialplan/index.lua:: Caller SIP Recording flag is enable")		
	end
end

for param_key,param_value in pairs(XML_REQUEST) do --pseudocode
	fs_logger("notice","[dialplan/index.lua][xml_REQUEST] "..param_key..": " .. param_value)
end

--CHECK FOR AUTO_CAMPAIGN
if(destination_number == 'AUTO_CAMPAIGN' ) then
	did_routing_uuid = '57bd6da2-bf27-11ed-afa1-0242ac120002'
	fs_logger("notice", "[index.lua]"..scripts_dir.."dialplan/call_queue.lua\n");
	dofile(scripts_dir .. "dialplan/call_queue.lua");
	return true;
end
if(destination_number == '2005' ) then
	fs_logger("notice", "[index.lua]"..scripts_dir.."dialplan/check_amvd.lua\n");
	dofile(scripts_dir .. "dialplan/check_amvd.lua");
	return true;
end
		
--CHECK FOR Three way callerid



--CHECK FOR Feature code.
if string.sub(destination_number, 1, 1) == "*" then
	is_feature_code = check_feature_code(destination_number);
	if(tonumber(is_feature_code) == 0)then
		fs_logger("notice","[dialplan/index.lua][CHECK FOR Feature Code.]");
		dofile(scripts_dir .. "dialplan/featurecode.lua");
		return true;
	end	
end
--CHECK FOR VOICE MAIL
if(destination_number == '*97' ) then
	fs_logger("notice","[dialplan/index.lua][CHECK FOR VOICEMAIL]");
	dofile(scripts_dir .. "dialplan/voicemail.lua");
	return true;	

end

--CHECK FOR SPEED DIAL
if(string.len(destination_number) == 1 ) then
	fs_logger("notice","[dialplan/index.lua][CHECK FOR SPEED DIAL]");
	dofile(scripts_dir .. "dialplan/speedial.lua");
	return true;	

end
--CHECK CALL IS SIP DEVICE
is_extensions = check_extension_info(destination_number);
call_pass_flag = 1
if(tonumber(is_extensions) == 0)then
	call_pass_flag = 0
	fs_logger("notice", "[index.lua]"..scripts_dir.."dialplan/extensions.lua\n");
	dofile(scripts_dir .. "dialplan/extensions.lua");
	return true;
end

--Check Call is DID or not once DID collection is ready. 0: DID number,1: Not DID number(Right now static set 0 for RG and IVR code)
is_did_number = check_did_info(destination_number)



local custom_routes = "";
if(current_custom_application and current_custom_application == 'execute_extension')then
	fs_logger("notice","[dialplan/index.lua][XML_STRING] current_custom_application::"..current_custom_application)
	forward_did_number = params:getHeader("variable_forward_did_number");
	custom_routes  = current_custom_application;
	is_did_number = 0
end

if(string.find(destination_number,'#PBX#')) then
	is_did_number = 0
fs_logger("notice","[dialplan/index.lua][XML_STRING] destination_number WITH PBX "..destination_number)
end
if(string.find(destination_number,'webphonetransfer')) then
	is_did_number = 0
	fs_logger("notice","[dialplan/index.lua][XML_STRING] destination_number WITH webphonetransfer PBX "..destination_number)
end

if(call_type == 'click2call')then
custom_routing_forwarding(click_to_call_array.clicktocall_forwarding_type,click_to_call_array.clicktocall_forwarding_value)
	return true;
end	

if(tonumber(is_did_number) == 0 and tonumber(is_extensions) ~= 0)then
	call_type= 'did'
	call_pass_flag = 0
	did_routing_type = did_destination_array.did_forwarding_type
	did_routing_uuid = did_destination_array.did_forwarding_value
	did_number = did_destination_array.number
	if(custom_routes ~= '')then
		did_routing_type = params:getHeader("variable_forward_call_type");
		did_routing_uuid = params:getHeader("variable_extensions");
		if(tonumber(did_routing_type)  == 8)then
			pstn_destination_number = did_routing_uuid
		end
		if(did_routing_type ~= nil and did_routing_uuid ~= nil)then
			fs_logger("notice","[dialplan/index.lua][XML_STRING]  did_routing_type"..did_routing_type)
			fs_logger("notice","[dialplan/index.lua][XML_STRING] did_routing_uuid "..did_routing_uuid)
		end
	end
	fs_logger("notice","[dialplan/index.lua][XML_STRING] WITH PBX  destination_number"..destination_number)
	local pbx_frwd = 0
	if(string.find(destination_number,'#PBX#')) then
		routed_destination_number = destination_number;
		pbx_find = split(destination_number,"#")
		did_number = pbx_find[1]
		destination_number = pbx_find[1]
		did_routing_type = pbx_find[3]
		did_routing_uuid = pbx_find[4]
		if(did_routing_type ~= nil and did_routing_uuid ~= nil)then
			pbx_frwd = 1
			fs_logger("notice","[dialplan/index.lua][XML_STRING] WITH PBX  did_routing_type"..did_routing_type)
			fs_logger("notice","[dialplan/index.lua][XML_STRING] WITH PBX did_routing_uuid "..did_routing_uuid)
		end
	end
	if(string.find(destination_number,'webphonetransfer') and pbx_frwd==0) then
		routed_destination_number = destination_number;
		webphonetransfer = 1
		callerid_name = params:getHeader("variable_effective_caller_id_name")
		callerid_number = params:getHeader("variable_effective_caller_id_number")
		local transfer_find = split(destination_number,"_")
		did_number = params:getHeader("variable_sip_from_user")
		destination_number = params:getHeader("variable_sip_from_user")
		did_routing_type = transfer_find[2]
		did_routing_uuid = transfer_find[3]
		if(did_routing_type ~= nil and did_routing_uuid ~= nil)then
			fs_logger("notice","[dialplan/index.lua][XML_STRING] WITH PBX WITH webphonetransfer did_routing_type"..did_routing_type)
			fs_logger("notice","[dialplan/index.lua][XML_STRING] WITH PBX WITH webphonetransfer did_routing_uuid "..did_routing_uuid)
		end
	end
	if(did_routing_type == nil or did_routing_uuid == nil)then
		local sip_from_user = params:getHeader("variable_sip_from_user")
		hangup_cause = "NO_ROUTE_DESTINATION";
		fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
		fs_logger("warning","[dialplan/index.lua:: DID Routing Not Set")
		dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
		return true;
	end

	original_destination_number = did_number
	if(original_destination_number ~= nil and original_destination_number ~= '' and (pbx_frwd==1 or webphonetransfer == 1))then
	is_did_number = check_did_info(original_destination_number)
		if(did_destination_array.did_as_cid ~= nil and did_destination_array.did_as_cid ~= "")then
			did_as_cid = did_destination_array.did_as_cid
			fs_logger("warning","[dialplan/index.lua:: did_as_cid:::"..did_as_cid..":::")
		end	
	end
	custom_routing_forwarding(did_routing_type,did_routing_uuid)
	return true;
--$call_type_drop_down = array(
--'12'8 => gettext('PSTN'),
--'7' 6 => gettext('Ring-Group'),
--'8' 4 => gettext('Conference'),
--'10'2 => gettext('IVR'),
--'9' 5=> gettext('Queue'),
--'11'1=> gettext('SIP Device'),
--'13'7=> gettext('Voicemail')
--);
end

--PSTN NUMBER
if(tonumber(is_did_number) ~= 0 and tonumber(is_extensions) ~= 0 and tonumber(is_click2call_number) ~= 0)then
	if(authentication_type == 'auth')then
		call_pass_flag = 0
		fs_logger("notice", "[index.lua]"..scripts_dir.."dialplan/outbound_call.lua\n");
		dofile(scripts_dir .. "dialplan/outbound_call.lua");
	else	
		if(caller_tenant_uuid ~= '' and caller_tenant_uuid ~= nil)then
			call_pass_flag = 0		
			fs_logger("notice", "[custom.lua]"..scripts_dir.."dialplan/acl_outbound_call.lua\n");
			dofile(scripts_dir .. "dialplan/acl_outbound_call.lua");
		end
	end
end

if(tonumber(call_pass_flag) == 1)then
	local sip_from_user = params:getHeader("variable_sip_from_user")
	hangup_cause = "AUTHENTICATION_FAIL";
	fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
	fs_logger("warning","[dialplan/index.lua:: No Route To Destination.")
	dofile(scripts_dir .. "dialplan/fail_xml_dialplan.lua");
	return true;
end

