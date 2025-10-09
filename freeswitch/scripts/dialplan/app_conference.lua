local cust_uuid = params:getHeader("variable_cust_uuid")
local transfer_type = params:getHeader("variable_sip_info_h_X-Transfer-Type");
local transfer_value = params:getHeader("variable_sip_info_h_X-Transfer-Value");
local caller_number = params:getHeader("variable_sip_info_h_X-Caller-Number");
local transfer_domain = params:getHeader("variable_domain_name");
--transfer_type = 'sip'
--transfer_value = '1005'
local xml = {};
table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[<section name="dialplan" description="CCPBX Dialplan">]]);
		table.insert(xml, [[<context name="]]..params:getHeader("Hunt-Context")..[[">]]);
			table.insert(xml, [[<extension name="attended_xfer">]]);
			table.insert(xml, [[<action application="bind_digit_action" data="start_recording,*4,exec:execute_extension,START_RECORDING XML default"/>]]);	
			if(transfer_value == '' or transfer_value == nil)then
				hangup_cause = "NO_ROUTE_DESTINATION";
				fail_audio_file = sounds_dir..'/pbx/badnumber.wav';
				fs_logger("warning","[dialplan/app_conference.lua:: DID Routing Not Set")
				local callstart = os.date("%Y-%m-%d %H:%M:%S")
				table.insert(xml, [[<action application="set" data="custom_callstart=]]..callstart..[["/>]]);	
				table.insert(xml, [[<action application="set" data="sip_ignore_remote_cause=true"/>]]);        
				table.insert(xml, [[<action application="playback" data="]]..fail_audio_file..[["/>]]);
				table.insert(xml, [[<action application="hangup" data="]]..hangup_cause..[["/>]]);
			else
				table.insert(xml, [[<condition field="destination_number" expression="^attended_xfer$">]]);
					table.insert(xml, [[<action application="set" data="continue_on_fail=true"/>]]);
					table.insert(xml, [[<action application="export" data="sip_h_X-transfer_leg_call_uuid=]]..params:getHeader("variable_call_uuid")..[["/>]]);
					table.insert(xml, [[<action application="export" data="sip_h_P-user_uuid=]]..params:getHeader("variable_user_uuid")..[["/>]]);
					table.insert(xml, [[<action application="export" data="sip_h_P-effective_caller_id_name=]]..params:getHeader("Other-Leg-Caller-ID-Number")..[["/>]]);					
					
					table.insert(xml, [[<action application="export" data="sip_h_P-extension_uuid=]]..params:getHeader("variable_extension_uuid")..[["/>]]);
					table.insert(xml, [[<action application="export" data="sip_h_P-tenant_uuid=]]..params:getHeader("variable_tenant_uuid")..[["/>]]);					
					table.insert(xml, [[<action application="answer"/>]]);
					table.insert(xml, [[<action application="set" data="transfer_ringback=${fr-ring}"/>]]);
					table.insert(xml, [[<action application="info"/>]]);
--					table.insert(xml, [[<action application="set" data="origination_cancel_key=#"/>]]);
-- B line hangup
					table.insert(xml, [[<action application="set" data="attxfer_hangup_key=*"/>]]);
-- XFER line hangup
					table.insert(xml, [[<action application="set" data="attxfer_cancel_key=#"/>]]);
--UN HOLD connect three way
					table.insert(xml, [[<action application="set" data="attxfer_conf_key=0"/>]]);
					if(transfer_type == 'sip')then
						--FOR SIP
						table.insert(xml, [[<action application="att_xfer" data="user/]]..transfer_value..[[@]]..transfer_domain..[["/>]]);
					end
					if(transfer_type == 'ring_group')then
						--FOR RG
						table.insert(xml, [[<action application="att_xfer" data="sofia/external/]]..transfer_value..[[@${domain_name}"/>]]);
					end
					if(transfer_type == 'call_queue')then
						--FOR Call QUEUE
						table.insert(xml, [[<action application="att_xfer" data="sofia/external/]]..transfer_value..[[@${domain_name}"/>]]);
					end
					if(transfer_type == 'pstn')then
						--FOR PSTN
						if(caller_number ~= nil and caller_number ~= "")then
							table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..skip_special_char(caller_number)..[["/>]]);
							table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..skip_special_char(caller_number)..[["/>]]);
						end
						table.insert(xml, [[<action application="att_xfer" data="sofia/external/]]..transfer_value..[[@${domain_name}"/>]]);
					end
				table.insert(xml, [[</condition>]]);
			end
			table.insert(xml, [[</extension>]]);        
		table.insert(xml,[[</context>]]);
	table.insert(xml,[[</section>]]);
table.insert(xml,[[</document>]]);
XML_STRING = table.concat(xml, "\n");
fs_logger("notice","[dialplan/call_barge.lua:: Generated XML:\n" .. XML_STRING);
