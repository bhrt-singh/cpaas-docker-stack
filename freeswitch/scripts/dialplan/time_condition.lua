fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] IN TIME CONDITION")

local tc_collection = mongo_collection_name:getCollection "time_condition"

local query = { uuid = did_routing_uuid, status = '0' }
local projection = {tenant_uuid = true, condition = true, failover_routing_type = true, failover_routing_options = true, name = true, uuid=true, _id = false }
local cursor = tc_collection:find(query, { projection = projection })
-- iterate over the results

time_condition_array = ''
for  time_condition_details in cursor:iterator() do
	time_condition_array = time_condition_details;
    -- do something with the document
end

if(time_condition_array == '')then
	fs_logger("warning","[dialplan/time_condition.lua:: time condition: NIL::")
	return true;
end
timecondition_uuid = time_condition_array.uuid
main_timecondition = time_condition_array.condition
failover_routing_type = time_condition_array.failover_routing_type
failover_routing_options = time_condition_array.failover_routing_options
fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] IN TIME CONDITION failover_routing_type:: "..failover_routing_type)
fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] IN TIME CONDITION failover_routing_options::: "..failover_routing_options)
--local condition_str = JSON:decode(main_timecondition) 

header_xml_time_condition()

if(failover_routing_type and failover_routing_options ~= '')then
	local failover_condition_str = ''

	if(failover_routing_options ~='' and failover_routing_options ~= nil)then
		table.insert(xml, [[<extension name="]]..time_condition_array.name..[[" continue="true">]]);
		local fail_condition_str = 'time-of-day= "00:01-23:59"'
		table.insert(xml, [[<condition ]]..fail_condition_str..[[ break="never">]]);
		table.insert(xml, [[<action application="set" data="office_status=open" inline="true"/>]]);
		table.insert(xml, [[<action application="set" data="extensions=]]..failover_routing_options..[[" inline="true"/>]]);
		table.insert(xml, [[<action application="set" data="forward_did_number=]]..did_number..[[" inline="true"/>]]);						
		table.insert(xml, [[<action application="set" data="forward_call_type=]]..failover_routing_type..[[" inline="true"/>]]);
		table.insert(xml, [[<action application="set" data="pbx_feature=time_condition"/>]]);
		table.insert(xml, [[<action application="set" data="time_condition_uuid=]]..timecondition_uuid..[["/>]]);
		table.insert(xml, [[</condition>]]);
		table.insert(xml, [[</extension>]]);
	end
end
if(main_timecondition and main_timecondition ~= '')then

	for condition_key,condition_value in ipairs(main_timecondition) do
	fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] IN TIME CONDITION condition_key::: "..condition_key)
	fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] IN TIME CONDITION condition_value::: "..condition_value.start_hour)
		local condition_str = ''
		local start_hour = '00'
		local end_hour = '23'
		local start_minute = '00'
		local end_minute = '59'
		local year_flag = 1
		if(condition_value.start_hour ~= '' and condition_value.end_hour ~= '' and condition_value.start_minute ~= '' and condition_value.end_minute ~= '')then
		start_hour = condition_value.start_hour
		end_hour = condition_value.end_hour
		start_minute = condition_value.start_minute
		end_minute = condition_value.end_minute
			local time_of_day = condition_value.start_hour..":"..condition_value.start_minute.."-"..condition_value.end_hour..":"..condition_value.end_minute	
				condition_str = condition_str..' time-of-day= "'..time_of_day..'" '
		end
		if(condition_value.weekday_start ~= '' and  condition_value.weekday_end ~= '')then
			local wday = condition_value.weekday_start.."-"..condition_value.weekday_end
			condition_str = condition_str..' wday= "'..wday..'" '
		end
		if(condition_value.monthday_start ~= '' and  condition_value.monthday_end ~= '')then
			year_flag = 0
--			local mday = condition_value.monthday_start.."-"..condition_value.monthday_end
--			condition_str = condition_str..' mday= "'..mday..'" '
		end
		if(condition_value.start_month ~= '' and  condition_value.end_month ~= '')then
--			local mon = condition_value.start_month.."-"..condition_value.end_month
--			condition_str = condition_str..' mon= "'..mon..'" '
		end
		if(condition_value.start_year ~= '' and  condition_value.end_year ~= '')then
--			local year = condition_value.start_year.."-"..condition_value.end_year
--			condition_str = condition_str..' year= "'..year..'" '
		end
		if (year_flag == 0)then
			local year_string = condition_value.start_year..'-'..condition_value.start_month..'-'..condition_value.monthday_start..' '..start_hour..':'..start_minute..':00~'..condition_value.end_year..'-'..condition_value.end_month..'-'..condition_value.monthday_end..' '..end_hour..':'..end_minute..':59'
			fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] ::: year_string::"..year_string)
			condition_str = condition_str..' date-time="'..year_string..'"'
		end
		fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] ::: condition_str::"..condition_str)
		if(condition_value.extension_destination ~='' and condition_value.extension_destination ~= nil)then
			local condition_extensions = condition_value.extension_destination
			local no_answer_call_type = condition_value.extension_calltype
			--start timezone changes
--PENDING Pass static Time-Zone ID

			local tenant_info_for_timezone = get_tenant_info(time_condition_array.tenant_uuid)
			
			local time_zone_uuid = '70607c32-e8c4-45d7-970a-fde198b55947'
			if(tenant_info_for_timezone ~= nil and tenant_info_for_timezone ~= '' and tenant_info_for_timezone.time_zone_uuid ~= '')then
				time_zone_uuid = tenant_info_for_timezone.time_zone_uuid
			end
			local time_zone_name=get_time_zone_info(time_zone_uuid);
			table.insert(xml, [[<extension name="]]..time_condition_array.name..[[" continue="true">]]);
			if(time_zone_name ~= '' and time_zone_name ~= nil)then
				table.insert(xml, [[<condition break="never">]]);
				table.insert(xml, [[<action application="set" data="timezone=]]..time_zone_name..[[" inline="true"/>]]);
				table.insert(xml, [[</condition>]]);
			end
			--end timezone
			table.insert(xml, [[<condition ]]..condition_str..[[ break="never">]]);
			table.insert(xml, [[<action application="set" data="office_status=open" inline="true"/>]]);
			table.insert(xml, [[<action application="set" data="extensions=]]..condition_extensions..[[" inline="true"/>]]);
			table.insert(xml, [[<action application="set" data="forward_did_number=]]..did_number..[[" inline="true"/>]]);						
			table.insert(xml, [[<action application="set" data="forward_call_type=]]..no_answer_call_type..[[" inline="true"/>]]);
			
			table.insert(xml, [[<action application="set" data="pbx_feature=time_condition"/>]]);
			table.insert(xml, [[<action application="set" data="time_condition_uuid=]]..timecondition_uuid..[["/>]]);
			table.insert(xml, [[</condition>]]);
			table.insert(xml, [[</extension>]]);
		end
	end 
end

if(time_condition_array and time_condition_array ~= '')then	
	table.insert(xml, [[<action application="export" data="caller_tenant_uuid=]]..caller_tenant_uuid..[["/>]]);
	orignal_destination_number = destination_number;
	if(routed_destination_number ~= '')then
		fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] Before Routed Destnation number"..destination_number)
		destination_number = routed_destination_number
		fs_logger("notice","[dialplan/time_condition.lua][XML_STRING] Routed Destnation number"..destination_number)
	end
	table.insert(xml, [[<extension name="tod route, x]]..destination_number..[[">]]);
	table.insert(xml, [[<condition field="destination_number" expression="^(\+?)?(]]..originate_destination_number..[[)$">]]);
	table.insert(xml, [[<action application="execute_extension" data="]]..orignal_destination_number..[[_${office_status}"/>]]);
	table.insert(xml, [[</condition>]]);
	table.insert(xml, [[</extension>]]);
	table.insert(xml, [[<extension name="office is open">]]);
	table.insert(xml, [[<condition field="destination_number" expression="^(\+?)?(]]..originate_destination_number..[[_open)$">]]);
	table.insert(xml, [[<action application="set" data="set_extensions=${extensions}"/>]]);
	table.insert(xml, [[<action application="set" data="no_answer_flag=true"/>]]);
	table.insert(xml, [[<action application="set" data="no_answer_number=${extensions}" />]]);
	table.insert(xml, [[</condition>]]);
	table.insert(xml, [[</extension>]]);
	destination_number = orignal_destination_number
end

footer_xml_time_condition()
