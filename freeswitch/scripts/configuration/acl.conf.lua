if (params:serialize() ~= nil) then
	fs_logger("notice","[configuration/acl.conf.lua][xml_handler] Params:\n" .. params:serialize())
end	
local function has_value (tab, val)
    for index, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end
local ip_unique_array = {}
local ip_unique_key = 1
local ip_mapping_collection = mongo_collection_name:getCollection "ip_mapping"
local query = {  status = '0' }
local projection = { ip = true, _id = false }
local cursor = ip_mapping_collection:find(query,{ projection = projection })
local ip_mapping_array = {}
local ipmap_key=1;
for ip_mapping_details in cursor:iterator() do
	ip_mapping_array[ipmap_key] = ip_mapping_details;
	ipmap_key = ipmap_key+1
end

--For Master Admin
local admin_ip_mapping_collection = mongo_collection_name:getCollection "admin_ip_mapping"
local admin_query = {  status = '0' }
local admin_projection = { ip = true, _id = false }
local admin_cursor = admin_ip_mapping_collection:find(admin_query,{ projection = admin_projection })
for ip_mapping_details in admin_cursor:iterator() do
	ip_mapping_array[ipmap_key] = ip_mapping_details;
	ipmap_key = ipmap_key+1
end

local acl_xml = '<document type="freeswitch/xml">\n'
acl_xml = acl_xml..'<section name="Configuration" description="Configuration">\n'
acl_xml = acl_xml..'<configuration name="acl.conf" description="Network List">\n'
acl_xml = acl_xml..'<network-lists>\n'
acl_xml = acl_xml..'<list name="default" default="deny">\n'
acl_xml = acl_xml..'<node type="allow" cidr="127.0.0.1/32"/>\n'
if(ip_mapping_array == '' or ip_mapping_array[1] == nil)then
	fs_logger("warning","[common/acl.conf.lua:: ip_mapping INFO: NIL::");
	return true;
else
	local sip_details_json = ''
	for param_key, param_value in ipairs( ip_mapping_array ) do
		if(param_value.ip ~= nil and param_value.ip ~= '')then
			if has_value(ip_unique_array, param_value.ip) then
				fs_logger("notice","[common/acl.conf.lua:: IP Mapping IP EXIST::"..param_value.ip)
			else
				fs_logger("notice","[common/acl.conf.lua:: IP Mapping IP ADDED::"..param_value.ip)
				acl_xml = acl_xml..'<node type="allow" cidr="'..param_value.ip..'/32"/>\n'	
			end
			
			ip_unique_array[ip_unique_key] = param_value.ip
			ip_unique_key = ip_unique_key + 1
		end
	end
---	acl_xml = acl_xml..'<node type="allow" cidr="74.48.114.104/32"/>\n'	
---	acl_xml = acl_xml..'<node type="allow" cidr="209.151.148.82/32"/>\n'	
end


acl_xml = acl_xml..'</list>\n'


--acl_xml = acl_xml..'<list name="loopback.auto" default="allow">\n'
--acl_xml = acl_xml..'<node type="allow" cidr="103.240.35.46/32"/>\n'
--acl_xml = acl_xml..'</list>\n'

acl_xml = acl_xml..'<list name="event" default="deny">\n'
acl_xml = acl_xml..'<node type="allow" cidr="127.0.0.0/8"/>\n'
acl_xml = acl_xml..' </list>\n'

acl_xml = acl_xml..'</network-lists>\n'
acl_xml = acl_xml..'</configuration>\n'
acl_xml = acl_xml..'</section>\n'
acl_xml = acl_xml..' </document>\n'

XML_STRING = acl_xml
fs_logger("notice","[configuration/acl.conf.lua][XML_STRING] "..XML_STRING)
return true;

--XML_STRING = '<document type="freeswitch/xml">  <section name="Configuration" description="Configuration">      <configuration name="acl.conf" description="Network List">          <network-lists>      <list name="default" default="deny">               <node type="allow" cidr="127.0.0.1/32"/>               <node type="allow" cidr="3.7.71.183/32"/>       </list>       <list name="event" default="deny">               <node type="allow" cidr="127.0.0.0/8"/>       </list>          </network-lists>      </configuration>  </section></document>'

--HARSH DO NOT DELETE THIS CODE
--[[
JSON = (loadfile (scripts_dir .."common/JSON.lua"))();
local sip_profile_collection = mongo_collection_name:getCollection "sip_profile"
local query = {  status = '0' }
local cursor = sip_profile_collection:find(query)
local sip_profile_array = {}
local sip_key=1;
for sip_profile_details in cursor:iterator() do
	sip_profile_array[sip_key] = sip_profile_details;
	sip_key = sip_key+1
end
if(sip_profile_array == '' or sip_profile_array[1] == nil)then
	fs_logger("warning","[common/acl.conf.lua:: sip profile INFO: NIL::");
	return true;
else
	local sip_details_json = ''
	for param_key, param_value in ipairs( sip_profile_array ) do
		if(param_value.sip_details ~= nil and param_value.sip_details ~= '')then
			sip_details_json = JSON:decode(param_value.sip_details)
			fs_logger("warning","[common/acl.conf.lua:: apply-inbound-acl::"..sip_details_json['apply-inbound-acl'])
		end
	end
end
]]--
