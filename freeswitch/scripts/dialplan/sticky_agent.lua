fs_logger("warning","[dialplan/sticky_agent.lua:: Transfer to sticky agent ::"..caller_user_uuid)
local user_collection = mongo_collection_name:getCollection "user"
local extension_collection = mongo_collection_name:getCollection "extensions"
local user_query = {uuid = caller_user_uuid}
local user_data = user_collection:find(user_query)
sticky_agent_flag = "0"
local user_array = ''
for user_data in user_data:iterator() do
	user_array = user_data
end

if user_array == '' then
	fs_logger("warning","[dialplan/sticky_agent.lua:: USER : NIL ::")
	return true;
end

local extension_query = {uuid = user_array.default_extension}
local extension_data = extension_collection:find(extension_query)
local extension_array = ''
for extension_data in extension_data:iterator() do
	extension_array = extension_data
end
if extension_array == ''then
	fs_logger("warning","[dialplan/sticky_agent.lua:: EXTENSION : NIL ::")
	return true;
end
	 bridge_string = "[leg_timeout=30]user/"..extension_array.username.."@"..from_domain
--	return bridge_string;
	header_xml();
	callerid_xml();
	if (type(user_array.callkit_token) ~= "table" and user_array.callkit_token ~= nil and user_array.callkit_token ~= "" and user_array.callkit_token ~= "null" and user_array.callkit_token ~= "" and user_array.mobile_type ~= nil and user_array.mobile_type ~= "" and user_array.mobile_type ~= "null")then
		local notify_call_type = "extension"
		if notify then notify(xml,extension_array.user_uuid,user_array.callkit_token,user_array.mobile_type,caller_id_name,caller_id_number,extension_array.username,from_domain,notify_call_type)
		end	
	end
table.insert(xml, [[<action application="set" data="receiver_extension_uuid=]]..extension_array.uuid..[["/>]]);
table.insert(xml, [[<action application="set" data="receiver_user_uuid=]]..extension_array.user_uuid..[["/>]]);	
	table.insert(xml, [[<action application="bridge" data="]]..bridge_string..[["/>]]);
	footer_xml();
	
	
