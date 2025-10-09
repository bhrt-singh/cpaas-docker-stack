fs_logger("notice","[dialplan/featurecode.lua][XML_STRING] IN FeatureCode");

function update_feature_code(feature_code_array)
	fs_logger("notice","[common/custom.lua:: Feature code feature_code_array.name::"..feature_code_array.name)
	fs_logger("notice","[common/custom.lua:: Feature code caller_array.call_forward::")
	if(caller_array.call_forward ~= nil and (feature_code_array.name == 'call_forwarding_enable' or feature_code_array.name == 'call_forwarding_disable' or feature_code_array.name == 'call_forwarding_toggle' or feature_code_array.name == 'on_busy_enable' or feature_code_array.name == 'on_busy_disable' or feature_code_array.name == 'on_busy_toggle' or feature_code_array.name == 'no_answered_enable' or feature_code_array.name == 'no_answered_disable' or feature_code_array.name == 'no_answered_toggle' or feature_code_array.name == 'not_registered_enable' or feature_code_array.name == 'not_registered_disable' or feature_code_array.name == 'not_registered_toggle'))then
		update_caller_array = {}
		for param_key, param_value in pairs( caller_array.call_forward ) do
			fs_logger("notice"," [dialplan/custom.lua] extension "..param_key.."\n")
			if(param_key == 'call_forward')then
				fs_logger("notice"," [dialplan/custom.lua] call_forward ::"..feature_code_array.name.." \n")
				fs_logger("notice"," [dialplan/custom.lua] call_forwarding_status BEFORE:: "..param_value['call_forwarding_status'].."\n")
				if(feature_code_array.name == 'call_forwarding_enable')then
					param_value['call_forwarding_status'] = 0
				end
				if(feature_code_array.name == 'call_forwarding_disable')then
					param_value['call_forwarding_status'] = 1
				end
				if(feature_code_array.name == 'call_forwarding_toggle')then
					if(tonumber(param_value['call_forwarding_status']) == 1)then
						param_value['call_forwarding_status'] = 0
					elseif(tonumber(param_value['call_forwarding_status']) == 0)then
						param_value['call_forwarding_status'] = 1
					end	
				end
				fs_logger("notice"," [dialplan/custom.lua] call_forwarding_status AFTER:: "..param_value['call_forwarding_status'].."\n")
				update_caller_array.call_forward = param_value
			end
			if(param_key == 'on_busy')then
				fs_logger("notice"," [dialplan/custom.lua] on_busy ::"..feature_code_array.name.." \n")
				fs_logger("notice"," [dialplan/custom.lua] on_busy_status BEFORE:: "..param_value['on_busy_status'].."\n")
				if(feature_code_array.name == 'on_busy_enable')then
					param_value['on_busy_status'] = 0
				end
				if(feature_code_array.name == 'on_busy_disable')then
					param_value['on_busy_status'] = 1
				end
				if(feature_code_array.name == 'on_busy_toggle')then
					if(tonumber(param_value['on_busy_status']) == 1)then
						param_value['on_busy_status'] = 0
					elseif(tonumber(param_value['on_busy_status']) == 0)then
						param_value['on_busy_status'] = 1
					end	
				end
				fs_logger("notice"," [dialplan/custom.lua] on_busy_status AFTER:: "..param_value['on_busy_status'].."\n")
				update_caller_array.on_busy = param_value
			end
			if(param_key == 'no_answered')then
				fs_logger("notice"," [dialplan/custom.lua] no_answered ::"..feature_code_array.name.." \n")
				fs_logger("notice"," [dialplan/custom.lua] no_answered_status BEFORE:: "..param_value['no_answered_status'].."\n")
				if(feature_code_array.name == 'no_answered_enable')then
					param_value['no_answered_status'] = 0
				end
				if(feature_code_array.name == 'no_answered_disable')then
					param_value['no_answered_status'] = 1
				end
				if(feature_code_array.name == 'no_answered_toggle')then
					if(tonumber(param_value['no_answered_status']) == 1)then
						param_value['no_answered_status'] = 0
					elseif(tonumber(param_value['no_answered_status']) == 0)then
						param_value['no_answered_status'] = 1
					end	
				end
				fs_logger("notice"," [dialplan/custom.lua] no_answered_status AFTER:: "..param_value['no_answered_status'].."\n")
				update_caller_array.no_answered = param_value
			end
			if(param_key == 'not_registered')then
				fs_logger("notice"," [dialplan/custom.lua] not_registered ::"..feature_code_array.name.." \n")
				fs_logger("notice"," [dialplan/custom.lua] not_registered_status BEFORE:: "..param_value['not_registered_status'].."\n")
				if(feature_code_array.name == 'not_registered_enable')then
					param_value['not_registered_status'] = 0
				end
				if(feature_code_array.name == 'not_registered_disable')then
					param_value['not_registered_status'] = 1
				end
				if(feature_code_array.name == 'not_registered_toggle')then
					if(tonumber(param_value['not_registered_status']) == 1)then
						param_value['not_registered_status'] = 0
					elseif(tonumber(param_value['not_registered_status']) == 0)then
						param_value['not_registered_status'] = 1
					end	
				end
				fs_logger("notice"," [dialplan/custom.lua] not_registered_status AFTER:: "..param_value['not_registered_status'].."\n")
				update_caller_array.not_registered = param_value
			end

		end
		local extension_collection = mongo_collection_name:getCollection "extensions"
		local filter = { uuid = caller_array.uuid }
		local update = { ["$set"] = { call_forward = update_caller_array } }
		local result = extension_collection:update(filter, update)
	end
	if(feature_code_array.name == 'dnd_enable' or feature_code_array.name == 'dnd_disable' or feature_code_array.name == 'dnd_toggle')then
		fs_logger("notice"," [dialplan/custom.lua] DND ::"..feature_code_array.name.." \n")	
		fs_logger("notice"," [dialplan/custom.lua] DND BEFORE:: "..caller_array.dnd.."\n")
		if(feature_code_array.name == 'dnd_enable')then
			caller_array.dnd = '0'
		end
		if(feature_code_array.name == 'dnd_disable')then
			caller_array.dnd = '1'
		end
		if(feature_code_array.name == 'dnd_toggle')then
			if(caller_array.dnd == '0')then
				caller_array.dnd = '1'
			elseif(caller_array.dnd == '1')then
				caller_array.dnd = '0'

			end
		end

		fs_logger("notice"," [dialplan/custom.lua] DND After:: "..caller_array.dnd.."\n")
		local extension_collection = mongo_collection_name:getCollection "extensions"
		local filter = { uuid = caller_array.uuid }
		local update = { ["$set"] = { dnd = ''..caller_array.dnd..'' } }
		local result = extension_collection:update(filter, update)
	end
	if(feature_code_array.name == 'follow_me_enable' or feature_code_array.name == 'follow_me_disable' or feature_code_array.name == 'follow_me_toggle')then
		fs_logger("notice"," [dialplan/custom.lua] Follow me ::"..feature_code_array.name.." \n")	
		fs_logger("notice"," [dialplan/custom.lua] Follow me BEFORE:: "..caller_array.follow_me['follow_me_status'].."\n")
		if(feature_code_array.name == 'follow_me_enable')then
			caller_array.follow_me['follow_me_status'] = 0
		end
		if(feature_code_array.name == 'follow_me_disable')then
			caller_array.follow_me['follow_me_status'] = 1
		end
		if(feature_code_array.name == 'follow_me_toggle')then
			if(tonumber(caller_array.follow_me['follow_me_status']) == 0)then
				caller_array.follow_me['follow_me_status'] = 1
			elseif(tonumber(caller_array.follow_me['follow_me_status']) == 1)then
				caller_array.follow_me['follow_me_status'] = 0

			end
		end
		fs_logger("notice"," [dialplan/custom.lua] Follow me After:: "..caller_array.follow_me['follow_me_status'].."\n")
		local extension_collection = mongo_collection_name:getCollection "extensions"
		local filter = { uuid = caller_array.uuid }
		local update = { ["$set"] = { follow_me = caller_array.follow_me } }
		local result = extension_collection:update(filter, update) 
	end

end

update_feature_code(feature_code_array)
header_xml();
table.insert(xml, [[<action application="answer"/>]]);
table.insert(xml, [[<action application="set" data="sip_ignore_remote_cause=true"/>]]);   
table.insert(xml, [[<action application="set" data="feature_code_flag=true"/>]]);             
table.insert(xml, [[<action application="playback" data="]]..sounds_dir..[[/pbx/feature-code-success.wav"/>]]);
table.insert(xml, [[<action application="hangup" data="NORMAL_CLEARING"/>]]);  
footer_xml();

