fs_logger("notice","[dialplan/speedial.lua][XML_STRING] IN Speed dial");
local speedial_array = caller_array.speed_dial
if(speedial_array ~= nil)then

	for param_key, param_value in pairs( speedial_array ) do
fs_logger("notice","[dialplan/speedial.lua][XML_STRING] IN Speed dial speedial_array12131:::"..tonumber(destination_number).." ==".. tonumber(param_key));

		if(tonumber(destination_number) == tonumber(param_key-1) and param_value['routing_type'] ~= '' and param_value['routing_value'] ~= '')then
			fs_logger("notice","[dialplan/speedial.lua] Speeddial digit::: "..param_key.."\n")
			fs_logger("notice","[dialplan/speedial.lua] routing_type "..param_value['routing_type'].."\n")
			fs_logger("notice","[dialplan/speedial.lua] routing_value "..param_value['routing_value'].."\n")
			original_destination_number = destination_number
			custom_routing_forwarding(param_value['routing_type'],param_value['routing_value'])
			return;
		end
	end
end

