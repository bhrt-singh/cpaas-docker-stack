dofile("/usr/local/freeswitch/scripts/common/db.lua");
freeswitch.consoleLog("info", "[IVR] Inside Updated Language Lua")
local selected_lang_code = argv[1] or "nil"
--freeswitch.consoleLog("info", "[IVR] Lang argv: " .. argv[1] .. "\n")
--local selected_lang_code = session:getVariable("lang_code");
freeswitch.consoleLog("info", "[IVR] Language updated to: " .. selected_lang_code .. "\n")

local caller_number = session:getVariable("effective_caller_id_number")
--local caller_number = params:getHeader("Hunt-Caller-ID-Number")
freeswitch.consoleLog("info", "[IVR] Language caller number: " .. caller_number .. "\n")

-- Save to MongoDB
local user_collection = mongo_collection_name:getCollection "user_info"
local update_query = { phone_number = caller_number }
local update_data = { ["$set"] = { language_code = selected_lang_code } }
--user_collection:update(update_query, update_data, false, true)
user_collection:update(update_query, update_data, { upsert = false, multi = true })

session:setVariable("session_language", selected_lang_code)
-- Log
freeswitch.consoleLog("info", "[IVR] Language updated to: " .. selected_lang_code .. "\n")

