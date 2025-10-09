fs_logger("notice","[dialplan/voicemail.lua][XML_STRING] IN Voicemail");

header_xml();
table.insert(xml, [[<action application="answer"/>]]); 
table.insert(xml, [[<action application="voicemail" data="check default ]]..to_domain..[[ ]]..params:getHeader("Hunt-Username")..[["/>]]);
footer_xml();
