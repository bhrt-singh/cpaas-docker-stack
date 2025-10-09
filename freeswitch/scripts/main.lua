--get the argv values
scripts_dir = '/usr/local/freeswitch/scripts/'
--upload_file_path = '/var/www/html/backend/beltalk/upload'
--upload_file_path = '/opt/backend/beltalk/upload'
dofile(scripts_dir.."config.lua")
caching_path = '/opt/caching/'
-- ::yaksh::
argv = {}

if(XML_REQUEST['section']=='directory') then
        logger_flag = 0
        params_log  = 0
else
        dofile(scripts_dir .. "common/db.lua");
end
dofile(scripts_dir .. "common/custom.lua");
for param_key,param_value in pairs(XML_REQUEST) do --pseudocode
        if(params_log == 0)then
                fs_logger("notice","[main.lua][xml_REQUEST] "..param_key..": " .. param_value)
        end
end
--if the params class and methods do not exist then add them to prevent errors
if (not params) then
        params = {}
        function params:getHeader(name)
                self.name = name;
        end
        function params:serialize(name)
                self.name = name;
        end
end
--Call for make directory
if(XML_REQUEST['section']=='directory') then
        if(params_log == 0)then fs_logger("notice", "[main.lua]"..scripts_dir.."directory/index.lua\n"); end
        return_value = dofile(scripts_dir .. "directory/index.lua");
end
--Call for make dialplan
if(XML_REQUEST['section']=='dialplan') then
        err = '';
        fs_logger("notice", "[main.lua]"..scripts_dir.."dialplan/index.lua\n");
        return_value = dofile(scripts_dir .. "dialplan/index.lua");
        if(return_value == nil)then
                fs_logger("notice", "[main.lua]"..err.."\n");
                fs_logger("notice", "[main.lua]Return Nil value\n");
        end
end
--Call for make configuration
if(XML_REQUEST['section']=='configuration' and XML_REQUEST['key_value']=='ivr.conf' and XML_REQUEST['key_value']=='ivr.conf') then -- ::yaksh:: 
-- if(XML_REQUEST['section']=='configuration' and XML_REQUEST['key_value']=='sofia.conf' and XML_REQUEST['key_value']=='ivr.conf') then
-- if(XML_REQUEST['section']=='configuration' and XML_REQUEST['key_value']=='ivr.conf') then
        if(params_log == 0)then fs_logger("notice", "[main.lua]"..scripts_dir.."configuration/"..XML_REQUEST['key_value']..".lua\n"); end
        -- ::yaksh::
        dofile(scripts_dir .. "configuration/"..XML_REQUEST['key_value']..".lua");
        --dofile(scripts_dir.."update_language.lua")
end
if(XML_REQUEST['section']=='configuration' and XML_REQUEST['key_value']=='callcenter.conf') then
        if(params_log == 0)then fs_logger("notice", "[main.lua]"..scripts_dir.."configuration/"..XML_REQUEST['key_value']..".lua\n"); end
        dofile(scripts_dir .. "configuration/"..XML_REQUEST['key_value']..".lua");
end
if(XML_REQUEST['section']=='configuration' and XML_REQUEST['key_value']=='acl.conf') then
        if(params_log == 0)then fs_logger("notice", "[main.lua]"..scripts_dir.."configuration/"..XML_REQUEST['key_value']..".lua\n"); end
        dofile(scripts_dir .. "configuration/"..XML_REQUEST['key_value']..".lua");
end
--      fs_logger("notice", "[main.lua]START UNSET VARIABLE\n");
--      unset_variable();
--      fs_logger("notice", "[main.lua]DONE UNSET VARIABLE\n");
--      do return end 
