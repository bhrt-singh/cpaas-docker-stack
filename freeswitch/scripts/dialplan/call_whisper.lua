local cust_uuid = params:getHeader("variable_cust_uuid")

local xml = {};
table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[<section name="dialplan" description="CC_PBX Dialplan">]]);
		table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
			table.insert(xml, [[<extension name="]]..destination_number..[[">]]); 
			table.insert(xml, [[<condition field="destination_number" expression="]]..destination_number..[[">]]);
				table.insert(xml, [[<action application="answer"/>]]);
				table.insert(xml, [[<action application="set" data="eavesdrop_whisper_aleg=true"/>]]);
				table.insert(xml, [[<action application="eavesdrop" data="]]..cust_uuid..[["/>]]);
			table.insert(xml,[[</condition>]]);
			table.insert(xml,[[</extension>]]);
		table.insert(xml,[[</context>]]);
	table.insert(xml,[[</section>]]);
table.insert(xml,[[</document>]]);
XML_STRING = table.concat(xml, "\n");
fs_logger("notice","[dialplan/call_whisper.lua:: Generated XML:\n" .. XML_STRING);
