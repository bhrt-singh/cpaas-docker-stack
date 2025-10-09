fs_logger("notice","[dialplan/check_amvd.lua][XML_STRING] IN check_amvd");




header_xml();
--table.insert(xml, [[<action application="set" data="execute_on_answer=lua avmd.lua"/>]]);
table.insert(xml, [[<action application="answer"/>]])
table.insert(xml, [[<action application="avmd_start" data= "detection_mode=2,inbound_channel=1,outbound_channel=1"/>]])
table.insert(xml, [[<hook event="AVMD_EVENT_BEEP" script="avmd.lua"/>]])

--table.insert(xml, [[<action application="bridge" data="sofia/gateway/52sertver/2005"/>]])
table.insert(xml, [[<action application="playback" data="]]..scripts_dir..[[/10682567-9747054d80a30e1e2375d6ee7c652231.wav"/>]])
table.insert(xml, [[<action application="avmd_stop" />]])
footer_xml();
