fs_logger("notice","[dialplan/fail_xml_dialplan.lua][XML_STRING] IN fail_xml_dialplan");

header_xml();
local callstart = os.date("%Y-%m-%d %H:%M:%S")
table.insert(xml, [[<action application="set" data="custom_callstart=]]..callstart..[["/>]]);	
table.insert(xml, [[<action application="set" data="sip_ignore_remote_cause=true"/>]]);        
table.insert(xml, [[<action application="playback" data="]]..fail_audio_file..[["/>]]);
table.insert(xml, [[<action application="hangup" data="]]..hangup_cause..[["/>]]);
footer_xml();
