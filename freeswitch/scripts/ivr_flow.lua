dofile("/usr/local/freeswitch/scripts/common/custom.lua")

local min_digits = 1
local max_digits = 7
local max_tries = 3
local timeout = 50000
local terminator = "#"
local invalid_file = "/usr/local/freeswitch/sounds/en/us/callie/ivr/invalid_entry.wav"
local account_verify_wait_file="/opt/caching/upload/en/0d0823c5-982d-4fc9-af03-bb55c4a64aec.wav"

local digits = session:playAndGetDigits(min_digits, max_digits, max_tries, timeout, terminator, menu_prompt, invalid_file, "\\d+")


-- Handle user input
freeswitch.consoleLog("INFO", "User input: " .. digits .. "\n")


local api_result = nil
local polling_done = false

-- Start background thread simulation
local function play_waiting_audio()
    while session:ready() and not polling_done do
        session:streamFile(account_verify_wait_file)
    end
end

-- Start a Lua coroutine to simulate concurrent execution
local co = coroutine.create(play_waiting_audio)
coroutine.resume(co)


local res = get_customer_by_accountNumber(digits)
polling_done = true
 local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")

 local res_str = dkjson.encode(res or {})

-- Handle Api Result
freeswitch.consoleLog("INFO", "API Result: " .. res_str .. "\n")



if res and res.status == 200 and type(res.customerList) == "table" and #res.customerList > 0 then
    freeswitch.consoleLog("INFO", "Customer found: " .. res.customerList[1].name .. "\n")
if session:ready() then
session:streamFile("/opt/caching/upload/en/0d0823c5-982d-4fc9-af03-bb55c4a64aec.wav")
        --  session:execute("transfer", "89c1b939-bb13-476d-b217-9bfa5373ed0a XML default")
else
    freeswitch.consoleLog("WARNING", "Session not ready — cannot transfer\n")
end

    -- Play success WAV (e.g., please_wait.wav)
--    session:streamFile("/opt/caching/upload/en/0d0823c5-982d-4fc9-af03-bb55c4a64aec.wav")
else
    freeswitch.consoleLog("ERR", "Invalid account number or no customer found\n")

    -- Play retry message
    session:streamFile("/usr/local/freeswitch/sounds/en/us/callie/ivr/8000/retry_account_number.wav")
end