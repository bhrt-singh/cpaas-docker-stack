fs_logger("notice","[dialplan/playback.lua][XML_STRING] IN playback");
hangup_cause = "NORMAL_CLEARING";

xml = {};
table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
table.insert(xml, [[<document type="freeswitch/xml">]]);
table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
table.insert(xml, [[<context name="]]..params:getHeader("Caller-Context")..[[">]]);
table.insert(xml, [[<extension name="]]..destination_number..[[">]]);
table.insert(xml, [[<condition field="destination_number" expression="]]..skip_special_char(originate_destination_number)..[[">]]);
table.insert(xml, [[<action application="answer"/>]]);        
table.insert(xml, [[<action application="playback" data="/usr/local/freeswitch/scripts/audio/dum.wav"/>]]);
--table.insert(xml, [[<action application="hangup" data="USER_BUSY"/>]]);
        table.insert(xml, [[</condition>]]);
        table.insert(xml, [[</extension>]]);
        table.insert(xml, [[</context>]]);
        table.insert(xml, [[</section>]]);
        table.insert(xml, [[</document>]]);
        XML_STRING = table.concat(xml, "\n");
	fs_logger("info","Generated XML:\n" .. XML_STRING)

