fs_logger("notice","[dialplan/playback.lua][XML_STRING] IN playback");
hangup_cause = "NORMAL_CLEARING";

header_xml();
table.insert(xml, [[<action application="set" data="sip_ignore_remote_cause=true"/>]]);        
table.insert(xml, [[<action application="playback" data="]]..upload_file_path..[[/]]..did_routing_uuid..[[.wav"/>]]);
table.insert(xml, [[<action application="hangup" data="]]..hangup_cause..[["/>]]);
footer_xml();
