fs_logger("notice","[dialplan/ivr.lua][XML_STRING] IN IVR")
local ivr_collection = mongo_collection_name:getCollection "ivr"
-- ::yaksh (updated 08/05/2025)::
xml = xml or {} 
-- Get caller number
local caller_number = params:getHeader("Hunt-Caller-ID-Number")
fs_logger("info", "[IVR] Caller Number: " .. caller_number)

-- Get MongoDB collection
local user_collection = mongo_collection_name:getCollection "user_info"
local lead_collection = mongo_collection_name:getCollection "lead_management"

-- Check if user already exists in MongoDB
local user_data = user_collection:find({ phone_number = caller_number })

local user_preference_array = ''
for  user_pref_details in user_data:iterator() do
    user_preference_array = user_pref_details
end

local query = { uuid = did_routing_uuid, status = '0' }
local projection = { uuid = true, _id = false }
local cursor = ivr_collection:find(query, { projection = projection })
-- iterate over the results
ivr_array = ''
for  ivr_details in cursor:iterator() do
    ivr_array = ivr_details
end
fs_logger("warning","[dialplan/ivr.lua:: IVR Caller number::"..ivr_array.uuid)

if(ivr_array == '')then
        fs_logger("warning","[dialplan/ivr.lua:: IVR: NIL::")
        return true;
end

header_xml();
callerid_xml();

if user_preference_array and user_preference_array.language_code and user_preference_array.language_code ~= "" then
    -- Case 1: User exists in MongoDB, use stored language
    fs_logger("info", "[IVR] User found in MongoDB. Language: " .. user_preference_array.language_code)
    table.insert(xml, [[<action application="set" data="session_language=]] .. user_preference_array.language_code .. [["/>]]);
    -- ::yaksh (language selected -> ivr change) 10-05-2025::
    ivr_array.uuid = "fa705f7d-66d6-4101-a80c-f016c6d6aefd";

-- Case 1: User exists in MongoDB, use stored language
    --session:setVariable("session_language", user_data.language_code)
else

    -- Case 2: Not in MongoDB, call API
    local response = call_customer_api(caller_number)

local new_user = {
    first_name = "anonymous",  -- default to anonymous
    phone_number = caller_number,
    email = "",
    custom_fields = "",
    language_code = session_language or "en"
}

if response and response.customerList and #response.customerList > 0 then
    local customer = response.customerList[1]

    -- Update user info from API response
    new_user.first_name = customer.name or "anonymous"
    new_user.custom_fields = customer.name or ""

    fs_logger("info", "[IVR] Customer found via API.")
else
    fs_logger("info", "[IVR] No customer found via API. Inserting anonymous user.")
end

-- Insert user into MongoDB
user_collection:insert(new_user)

-- Set default language in session
local lang = session_language and session_language ~= "" and session_language or "en"
table.insert(xml, [[<action application="set" data="session_language=]] .. lang .. [["/>]]);
fs_logger("info", "[IVR] Default language set to: " .. lang)
end
--local user_data_preference = user_collection:find({phoneNo = '"'..caller_number..'"'})

-- iterate over the results
--local user_preference_array = ''
--for  user_pref_details in user_data:iterator() do
--    user_preference_array = user_pref_details
--end

-- fs_logger("warning","[dialplan/ivr.lua:: IVR Caller number::"..session_language)

--local query = { uuid = did_routing_uuid, status = '0' }
--local projection = { uuid = true, _id = false }
--local cursor = ivr_collection:find(query, { projection = projection })
-- iterate over the results
--ivr_array = ''
--for  ivr_details in cursor:iterator() do
--    ivr_array = ivr_details
--end
--fs_logger("warning","[dialplan/ivr.lua:: IVR Caller number::"..ivr_array.uuid)

--if(ivr_array == '')then
--	fs_logger("warning","[dialplan/ivr.lua:: IVR: NIL::")
--	return true;
--end

--	header_xml();
--	callerid_xml();
	-- :: yaksh (set dynamic language variable in IVR diaplan)::
	--local lang = session_language and session_language ~= "" and session_language or "en"
	--table.insert(xml, [[<action application="set" data="session_language=]] .. lang .. [["/>]]);

	--table.insert(xml, [[<action application="set" data="session_language=]]..session_language..[["/>]]);
	--table.insert(xml, [[<action application="set" data="session_language=hn"/>]]);
	if(is_did_number ~= nil and did_as_cid ~= nil and tonumber(is_did_number) == 0 and tonumber(did_as_cid) == 0)then
		  if(did_number == nil or did_number == '' )then
                         did_number = params:getHeader("variable_forward_did_number");
              		 original_destination_number =  params:getHeader("variable_forward_did_number");
                end
		fs_logger("notice","[index/ivr.lua::DID number As Caller ID"..did_number.."\n")	
		table.insert(xml, [[<action application="set" data="effective_caller_id_name=]]..did_number..[["/>]]);
		table.insert(xml, [[<action application="set" data="effective_caller_id_number=]]..did_number..[["/>]]);
	end	
	if(original_destination_number == nil)then
		original_destination_number = destination_number
	end
	table.insert(xml, [[<action application="answer"/>]]);
--	table.insert(xml, [[<action application="sleep" data="1000"/>]])
	--table.insert(xml, [[<action application="export" data="api_on_answer=uuid_record ${uuid} pause $${recordings_dir}/${uuid}.wav"/>]]);
--	table.insert(xml, [[<action application="stop_record_session" data="$${recordings_dir}/${uuid}.wav"/>]]);
--	local delete_command = "$${recordings_dir}/${uuid}.wav"
--	os.remove(delete_command)
--	table.insert(xml, [[<action application="set" data="RECORD_APPEND=false"/>]]);	
	table.insert(xml, [[<action application="set" data="hold_music=call-queue.wav"/>]]);	
	table.insert(xml, [[<action application="bridge_export" data="hold_music=call-queue.wav"/>]]);
	table.insert(xml, [[<action application="set" data="ringback=%(2000,4000,440,480)"/>]]);
	table.insert(xml, [[<action application="set" data="pbx_feature=ivr"/>]]);
	table.insert(xml, [[<action application="set" data="ivr_group_uuid=]]..ivr_array.uuid..[["/>]]);
        table.insert(xml, [[<action application="set" data="original_destination_number=]]..original_destination_number..[["/>]])
--        table.insert(xml, [[<action application="record_session" data="$${recordings_dir}/${uuid}.wav"/>]]);
--	table.insert(xml, [[<action application="set" data="execute_on_answer=record_session $${recordings_dir}/${uuid}.wav"/>]]);
        table.insert(xml, [[<action application="ivr" data="]]..ivr_array.uuid..[["/>]])
        
        
        --table.insert(xml, [[<action application="export" data="api_on_answer=uuid_record ${uuid} resume $${recordings_dir}/${uuid}.wav"/>]]);
	footer_xml();
