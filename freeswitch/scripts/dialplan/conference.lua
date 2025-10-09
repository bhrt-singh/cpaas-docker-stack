fs_logger("notice","[dialplan/conference.lua][XML_STRING] IN Conference")
local conference_collection = mongo_collection_name:getCollection "conference"

local query = { uuid = did_routing_uuid, status = '0'}
local projection = { uuid = true, pin = true,greeting_uuid = true, _id = false }
local cursor = conference_collection:find(query, { projection = projection })
-- iterate over the results
conference_array = ''
for  conference_details in cursor:iterator() do
    conference_array = conference_details
end

if(conference_array == '')then
	fs_logger ("warning","[dialplan/conference.lua:: Conference: NIL::")
	return true;
end
	header_xml();
	if(conference_array.greeting_uuid ~= '') then
		table.insert(xml, [[<action application="playback" data="]]..upload_file_path..[[/]]..conference_array.greeting_uuid..[[.wav"/>]]);
	end
        table.insert(xml, [[<action application="conference" data="]]..conference_array.uuid..[[@default+]]..conference_array.pin..[["/>]])
	footer_xml();
