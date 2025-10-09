local cust_uuid = params:getHeader("variable_cust_uuid")

local xml = {};
table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[<section name="dialplan" description="ASTPP Dialplan">]]);
		table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
			table.insert(xml, [[<extension name="]]..destination_number..[[">]]); 
			table.insert(xml, [[<condition field="destination_number" expression="]]..destination_number..[[">]]);
				table.insert(xml, [[<action application="answer"/>]]);
				table.insert(xml, [[<action application="userspy" data="]]..destination_number..[[@${domain_name}  ]]..cust_uuid..[["/>]]);
			table.insert(xml,[[</condition>]]);
			table.insert(xml,[[</extension>]]);
		table.insert(xml,[[</context>]]);
	table.insert(xml,[[</section>]]);
table.insert(xml,[[</document>]]);
XML_STRING = table.concat(xml, "\n");
fs_logger("notice","[dialplan/call_monitor.lua:: Generated XML:\n" .. XML_STRING);
