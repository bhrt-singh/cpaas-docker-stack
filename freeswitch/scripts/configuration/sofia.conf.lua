--local fname = '/opt/caching/'..sip_user..'.'..domain_name..'.xml'
if (params:serialize() ~= nil) then
	fs_logger("notice","[configuration/sofia.conf.lua][xml_handler] Params:\n" .. params:serialize())
end	
destination_number = params:getHeader("Hunt-Destination-Number");
extension_domain = params:getHeader("variable_sip_to_host");
for param_key,param_value in pairs(XML_REQUEST) do --pseudocode
	fs_logger("notice","55555555555[configuration/sofia.conf.lua][xml_REQUEST] "..param_key..": " .. param_value)
end                            
local fname = caching_path..'configuration/sip_profiles.xml'
fs_logger("notice","[configuration/sofia.conf.lua][fname] "..fname)
local file, err = io.open(fname, mode or "rb")
if not file then
	fs_logger("notice","[configuration/sofia.conf.lua][XML_STRING] NOT FOUND")
	return nil, err
end
XML_STRING = file:read("*all")
fs_logger("notice","[configuration/sofia.conf.lua][XML_STRING] "..XML_STRING)
return true;
