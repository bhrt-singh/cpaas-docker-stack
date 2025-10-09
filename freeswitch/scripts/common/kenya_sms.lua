dofile("/usr/local/freeswitch/scripts/config.lua")
local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")
local https = require("ssl.https")
local ltn12 = require("ltn12")
dofile(scripts_dir .. "common/db.lua");

local sms_log_collection = mongo_collection_name:getCollection "sms_logs"

-- send SMS
function send_sms_via_onfon(Number, Text)


    freeswitch.consoleLog("NOTICE", "[SMS][KENYA_IVR] SMS Caller id : " .. Number .. "\n")

    local payload = {
        SenderId = "SAVANNA_KE",
        IsUnicode = false,
        IsFlash = false,
        ScheduleDateTime = nil,
        MessageParameters = {
            {
                Number = Number,
                Text = Text
            }
        },
        ApiKey = "bp24X6h7uqOzQAeSv0UL8GaHNEyZxf3mVsFt9klg1d5BPWIc",
        ClientId = "savannake"
    }

    local response_body = {}

    local json_payload = dkjson.encode(payload)
    freeswitch.consoleLog("NOTICE", "[SMS][KENYA_IVR] Request Payload: " .. json_payload .. "\n")

    local res, code, headers, status = https.request{
        url = "https://api.onfonmedia.co.ke/v1/sms/SendBulkSMS",
        method = "POST",
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#dkjson.encode(payload)),
			["AccessKey"] = "savannake"
        },
        source = ltn12.source.string(dkjson.encode(payload)),
        sink = ltn12.sink.table(response_body)
    }

    local response_str = table.concat(response_body or {})
    local parsed, pos, err = dkjson.decode(response_str)

     -- Log response body
    freeswitch.consoleLog("NOTICE", "[SMS][KENYA_IVR] Response Body: " .. response_str .. "\n")

    
    if not parsed then
        freeswitch.consoleLog("ERR", "[SMS][KENYA_IVR] Failed to parse response: " .. tostring(err) .. "\n")
        return false
    end
    
    add_SMS_logs(Number, Text, response_str)
    
    if parsed.ErrorCode == 0 and parsed.Data and parsed.Data[1] then
        local msg = parsed.Data[1]
        if msg.MessageErrorCode == 0 then
            freeswitch.consoleLog("INFO", "[SMS][KENYA_IVR] SMS sent successfully to " .. Number .. "\n")
            return true
        else
            freeswitch.consoleLog("ERR", "[SMS][KENYA_IVR] SMS not sent. Reason: " .. msg.MessageErrorDescription .. "\n")
            return false
        end
    else
        freeswitch.consoleLog("ERR", "[SMS][KENYA_IVR] Unexpected response structure or error: " .. response_str .. "\n")
        return false
    end
end


-- function send_payment_sms(number, template_id, data)
--     local payload = {
--         SenderId = "SAVANNA_KE",
--         IsUnicode = false,
--         IsFlash = false,
--         ScheduleDateTime = nil,
--         TemplateId = "25604",
--         MessageParameters = {
--             {
--                 Number = number,
--                 Account = data.Account,
--                 Due_Date = data.Due_Date,
--                 Bill_Amount = data.Bill_Amount
--             }
--         },
--         ApiKey = "bp24X6h7uqOzQAeSv0UL8GaHNEyZxf3mVsFt9klg1d5BPWIc",
--         ClientId = "savannake"
--     }

--     -- JSON encode payload
--     local payload_str = json.encode(payload)
--     local response_body = {}

--     local res, code, headers, status = https.request{
--         url = "https://api.onfonmedia.co.ke/v1/sms/SendBulkSMS",
--         method = "POST",
--         headers = {
--             ["Content-Type"] = "application/json",
--             ["Content-Length"] = tostring(#payload_str)
--         },
--         source = ltn12.source.string(payload_str),
--         sink = ltn12.sink.table(response_body)
--     }

--     local response = table.concat(response_body)
--     return {
--         status = code,
--         success = (code == 200),
--         response = response
--     }
-- end


-- ADD SMS logs
function add_SMS_logs(Number, Text, response_str)

   local parsed = dkjson.decode(response_str)
   local msgData = parsed.Data[1]
   local status = (msgData.MessageErrorCode ~= 0) and "FAILED" or "SUCCESS"

    local smsLog = {
        mobileNumber = msgData.MobileNumber or "",
        message = Text,
        status = status, 
        errorCode = msgData.MessageErrorCode,
        errorDescription = msgData.MessageErrorDescription,
        messageId = msgData.MessageId,
        custom = msgData.Custom,
        sentAt = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        response = response_str -- ✅ moved into table with comma before it
    }


    -- Insert into MongoDB
    local ok, err = sms_log_collection:insert(smsLog)
    if not ok then
        freeswitch.consoleLog("ERR", "[SMS][KENYA_IVR] Failed to insert SMS log: " .. tostring(err) .. "\n")
    else
        freeswitch.consoleLog("NOTICE", "[SMS][KENYA_IVR] SMS log inserted into MongoDB.\n")
    end
end