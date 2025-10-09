if (params:serialize() ~= nil) then
	fs_logger("notice","[configuration/callcenter.conf.lua][xml_handler] Params:\n" .. params:serialize())
end	
destination_number = params:getHeader("Hunt-Destination-Number");
extension_domain = params:getHeader("variable_sip_to_host");
for param_key,param_value in pairs(XML_REQUEST) do --pseudocode
	fs_logger("notice","[configuration/callcenter.conf.lua][xml_REQUEST] "..param_key..": " .. param_value)
end              
--pending
local call_queue_file_name = 'CALL_CENTER'--params:getHeader("CC-Queue");        
local fname = caching_path..'callcenter/'..call_queue_file_name..'.xml'
fs_logger("notice","[configuration/callcenter.conf.lua][fname] "..fname)
local file, err = io.open(fname, mode or "rb")
if not file then
	fs_logger("notice","[configuration/callcenter.conf.lua][XML_STRING] NOT FOUND")
	return nil, err
end
XML_STRING = file:read("*all")

	fs_logger("notice","[configuration/callcenter.conf.lua][XML_STRING] "..XML_STRING)
return true;
--[[ DYNAMIC CODE
local call_queue_uuid = params:getHeader("CC-Queue");
if(call_queue_uuid~= nil)then
		    fs_logger ("notice","[configuration/callcenter.conf.lua][XML_STRING] NOT FOUND:::call_queue_uuid:::"..call_queue_uuid)
	--fs_logger ("notice","[configuration/callcenter.conf.lua][call_queue_uuid] "..call_queue_uuid)
	local call_queue_collection = mongo_collection_name:getCollection "call_queue"
	local query = { uuid = call_queue_uuid }
	local projection = { tenant_uuid = true, _id = false }
	local cursor = call_queue_collection:find(query, { projection = projection })
	call_queue_array = ''
	for  call_queue_details in cursor:iterator() do
		call_queue_array = call_queue_details;
	end
		call_queuename = ''
	if(call_queue_array == '')then
		fs_logger ("warning","[common/custom.lua:: Call Queue: NIL::")
		    fs_logger ("notice","[configuration/callcenter.conf.lua][XML_STRING] NOT FOUND")
		    return nil, err
	else
		call_queue_tenant_uuid = call_queue_array.tenant_uuid
		fs_logger ("notice","[configuration/callcenter.conf.lua][fname] "..call_queue_tenant_uuid)
		local fname = caching_path..'call_queue/'..call_queue_tenant_uuid..'.xml'
		fs_logger ("notice","[configuration/callcenter.conf.lua][fname] "..fname)
		local file, err = io.open(fname, mode or "rb")
		if not file then
		    fs_logger ("notice","[configuration/callcenter.conf.lua][XML_STRING] NOT FOUND")
		    return nil, err
		end
		XML_STRING = file:read("*all")

		fs_logger ("notice","[configuration/callcenter.conf.lua][XML_STRING] "..XML_STRING)
	end
end	
return true;
]]--
