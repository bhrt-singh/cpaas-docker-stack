-- Load dkjson for JSON encoding/decoding
local json = dofile("/usr/local/freeswitch/scripts/dkjson.lua")
-- Get mobile number from dialplan argument
local mobile = argv[1] or "0000000000"
-- Bearer token (replace with your real token)
local bearer_token = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ7XCJ1c2VybmFtZVwiOlwiYWRtaW5Ac2F2YW5uYVwiLFwiZmlyc3ROYW1lXCI6XCJzYXZhbm5hXCIsXCJsYXN0TmFtZVwiOlwic2F2YW5uYVwiLFwidXNlcklkXCI6MTEsXCJwYXJ0bmVySWRcIjoxLFwicm9sZXNMaXN0XCI6XCIxXCIsXCJzZXJ2aWNlQXJlYUlkXCI6bnVsbCxcIm12bm9JZFwiOjMsXCJzZXJ2aWNlQXJlYUlkTGlzdFwiOltdLFwic3RhZmZJZFwiOjExLFwiYnVJZHNcIjpbXSxcInJvbGVJZHNcIjpbMV0sXCJ0ZWFtSWRzXCI6W10sXCJhc3NpZ25hYmxlUm9sZUlkc1wiOltdLFwiYXNzaWduYWJsZVJvbGVOYW1lc1wiOltdLFwibXZub05hbWVcIjpcInNhdmFubmFcIixcInRlYW1zXCI6W10sXCJsY29cIjpmYWxzZX0iLCJleHAiOjE4MzU4NjU5Njh9.eY4-1611xSDHNFgVmTXZ-r97lyOwCtox7ZZhFSn6um8"
-- Prepare Lua table payload
local payload_table = {
    mobile = mobile,
    text = "We’ve received your request and created a ticket. Our team is on it! Need quick help? Call us anytime at 02717428900 - Adopt NetTech"
}
-- Encode payload to JSON
local payload_json = json.encode(payload_table)
-- API endpoint
local api_url = "https://xcess-internal-cc.local:5000/send/sms"
-- Prepare safe JSON string for shell (replace single quotes to prevent shell errors)
local safe_payload = payload_json:gsub("'", [["]])
-- Build curl command with Bearer token
local curl_cmd = string.format(
    'curl -s -X POST "%s" ' ..
    '-H "Content-Type: application/json" ' ..
    '-H "Authorization: Bearer %s" ' ..
    '-d \'%s\'',
    api_url,
    bearer_token,
    safe_payload
)
-- Log the command (optional)
freeswitch.consoleLog("INFO", "[sms_integration.lua] Executing curl with token...\n")
-- Execute and capture response
local handle = io.popen(curl_cmd)
local result = handle:read("*a")
handle:close()
-- Try to parse JSON response
local decoded, _, err = json.decode(result)
if decoded then
    freeswitch.consoleLog("INFO", "[sms_integration.lua] API JSON Response OK\n")
    freeswitch.consoleLog("INFO", "[sms_integration.lua] Lead Added Successfully.\n")
else
    freeswitch.consoleLog("WARNING", "[sms_integration.lua] Failed to parse JSON response: " .. tostring(err) .. "\n")
end
-- Log raw response
--freeswitch.consoleLog("INFO", "[sms_integration.lua] Raw API Response: " .. tostring(result) .. "\n")