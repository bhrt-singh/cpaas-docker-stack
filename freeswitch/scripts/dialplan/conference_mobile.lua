fs_logger("notice","[dialplan/conference.lua][XML_STRING] IN Conference Mobile")
	xml = {};
        table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
        table.insert(xml, [[<document type="freeswitch/xml">]]);
        table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
        table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
	 table.insert(xml, [[<extension name="conference_sample">]]);
	 table.insert(xml, [[<condition field="destination_number" expression="^10011001$">]]);
	 table.insert(xml, [[<action application="answer"/>]]);
	 table.insert(xml, [[<action application="conference" data="myconference@default"/>]]);
        table.insert(xml, [[</condition>]]);
        table.insert(xml, [[</extension>]]);
        table.insert(xml, [[</context>]]);
        table.insert(xml, [[</section>]]);
        table.insert(xml, [[</document>]]);
        XML_STRING = table.concat(xml, "\n");
	fs_logger("info","Generated XML:\n" .. XML_STRING)        
