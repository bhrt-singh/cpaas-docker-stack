dofile("/usr/local/freeswitch/scripts/config.lua")
dofile(scripts_dir .. "common/db.lua");
dofile(scripts_dir .. "common/custom.lua");

local json = dofile("/usr/local/freeswitch/scripts/dkjson.lua")

function fs_logger(logger_flag,log_type,body_message)
        if(tostring(logger_flag) == '0')then
                freeswitch.consoleLog (log_type,body_message.."\n");
        end
end


-- Helper to remove unsupported types from MongoDB result
local function sanitize_table(obj)
    local clean = {}
    for k, v in pairs(obj) do
        if type(v) ~= "userdata" and type(v) ~= "function" then
            clean[k] = type(v) == "table" and sanitize_table(v) or v
        else
            clean[k] = tostring(v)
        end
    end
    return clean
end


function get_prefered_language(logger, caller_number, user_collection)
   -- local mobile = "7435071756"
   -- local text = "We’ve received your request and created a ticket. Our team is on it! Need quick help? Call us anytime at 02717428900 - Adopt NetTech"
   -- local templateId = "test"
   -- send_SMS_res = Send_SMS(mobile, text, templateId)
   --fs_logger(logger, "notice", "[DEBUG] Send SMS API RES: " .. tostring(send_SMS_res))
    fs_logger(logger, "notice", "[DEBUG] Querying phone_number: " .. tostring(caller_number))

    local user_data = user_collection:find({ phone_number = caller_number })

    fs_logger(logger, "notice", "[DEBUG] Cursor object: " .. tostring(user_data))

    local found_any = false
    local session_language = ''
    local user_preference_array = nil

    for doc in user_data:iterator() do
        found_any = true
        user_preference_array = doc

        -- Print first matching document (sanitized)
        local clean_doc = sanitize_table(doc)
        fs_logger(logger, "notice", "[DEBUG] Found document:\n" .. json.encode(clean_doc, { indent = true }))

        break -- only take the first result
    end

    if not found_any then
        fs_logger(logger, "notice", "[KENYA_IVR] No user found for phone_number: " .. tostring(caller_number))
    else
        fs_logger(logger, "notice", "[KENYA_IVR] Preferred language: " .. (user_preference_array.language_code or "nil"))
        session_language = user_preference_array.language_code or ''
    end

    return session_language
end

function get_account_number(logger,account_file)
 local allowed_account_digit = '[1-2]'
    local get_account_input = session:playAndGetDigits(1,1,1,10000,'#',account_file,'',allowed_account_digit)
    fs_logger(logger,"notice", "[KENYA_IVR] ::get_account_input::" .. (get_account_input or "nil"))
    return get_account_input
end

function get_account_details(logger, enter_account_number_file, account_number_invalid_file)
    fs_logger(logger, 'notice', "[dialplan/kenya_ivr.lua][KENYA_IVR] coming for the get account_details")
    local account_not_found_retry = 3
    local max_digits = MAX_ACCOUNT_NO_DIGIT
    local timeout = 10000
    local digit_regex = "\\d+"
    local current_retries = 0

    fs_logger(logger, "notice", "[KENYA_IVR] max account digit " .. MAX_ACCOUNT_NO_DIGIT)

    while current_retries < account_not_found_retry do
        -- Prompt for account number
        local account_number = session:playAndGetDigits(1, max_digits, 1, timeout, '#', enter_account_number_file, '', digit_regex)
        
        if not account_number then
            fs_logger(logger, "notice", "[KENYA_IVR] no account number entered")
            current_retries = current_retries + 1
            if current_retries < account_not_found_retry then
                fs_logger(logger, "notice", "[KENYA_IVR] playing invalid account prompt, retry " .. current_retries + 1)
                session:streamFile(account_number_invalid_file)
            end
        else
            fs_logger(logger, "notice", "[KENYA_IVR] customer entered account number: " .. account_number)
            local account_res = get_customer_by_accountNumber(account_number)
            local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")
            local res_str = dkjson.encode(account_res or {})
            fs_logger(logger, "notice", "[KENYA_IVR] customer API response: " .. res_str)

            if account_res and account_res.status == 200 and type(account_res.customerList) == "table" and #account_res.customerList > 0 then
                fs_logger(logger, "notice", "[KENYA_IVR] customer is verified")
                return account_res
            else
                current_retries = current_retries + 1
                fs_logger(logger, "notice", "[KENYA_IVR] customer entered an invalid account number, retry " .. current_retries)
                if current_retries < account_not_found_retry then
                    session:streamFile(account_number_invalid_file)
                end
            end
        end
    end

    -- Max retries reached, hang up the call
    fs_logger(logger, "notice", "[KENYA_IVR] max retries (" .. account_not_found_retry .. ") reached, hanging up")
    session:hangup()
end

function main_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] coming in the main_menu");
    -- Kenya_IVR_Inq_Main_Prompt_en --
    local after_Account_Verify_Ind_Main_file = "/opt/caching/upload/"..user_selected_language.."/88ed17df-1c24-4fa0-be9c-8457d307ff20.wav"
    local main_menu_allowed_digit = '[0-4]'
    local main_menu_input = session:playAndGetDigits(1,1,1,50000,'#',after_Account_Verify_Ind_Main_file,'',main_menu_allowed_digit)
    if(tonumber(main_menu_input) == 1)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the"..tonumber(main_menu_input));
        billing_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    elseif(tonumber(main_menu_input) == 2)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the"..tonumber(main_menu_input));
        internet_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    elseif(tonumber(main_menu_input) == 3)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the"..tonumber(main_menu_input));
        sales_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    elseif(tonumber(main_menu_input) == 4)then
        general_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the"..tonumber(main_menu_input));
    elseif(tonumber(main_menu_input) == 0)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the"..tonumber(main_menu_input));
        main_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    end
    session:hangup()
end

function billing_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][BILLING_MENU] coming in the billing menu");
    if(user_selected_language == 'en')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in english queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    elseif(user_selected_language == 'swah')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in swahili queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    end
    -- Kenya_IVR_Payment_and_billing_queries_en
    local Payment_and_billing_queries_file = "/opt/caching/upload/"..user_selected_language.."/9f6b50f8-7e8d-4635-b643-b0672aef4b89.wav"
    local payment_menu_allow_digit = '[0-9]'
    local payment_menu_input = session:playAndGetDigits(1,1,1,5000,'#',Payment_and_billing_queries_file,'',payment_menu_allow_digit)
    if(tonumber(payment_menu_input) == 1)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][BILLING_MENU] user seleceted the"..tonumber(payment_menu_input));
        -- Kenya_IVR_Payment_Inq_1_en
        local Details_on_Due_date_and_bill_amount_file = "/opt/caching/upload/"..user_selected_language.."/2d0a509a-85ab-48a8-ba9c-c42f254d5f49.wav"
        session:streamFile(Details_on_Due_date_and_bill_amount_file)
    elseif(tonumber(payment_menu_input) == 2)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][BILLING_MENU] user seleceted the"..tonumber(payment_menu_input));
        -- Kenya_IVR_Details_on_Due_date_and_bill_amount_en
        local Details_on_Due_date_and_bill_amount_file = "/opt/caching/upload/"..user_selected_language.."/a38707f5-0806-483c-afb8-d51340b96856.wav"
        session:streamFile(Details_on_Due_date_and_bill_amount_file)
    elseif(tonumber(payment_menu_input) == 9)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][BILLING_MENU] user seleceted the"..tonumber(payment_menu_input));
        pass_queue(callerid,tenant_uuid,queue_uuid,logger,scripts_dir)
    elseif(tonumber(payment_menu_input) == 0)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][BILLING_MENU] user seleceted the"..tonumber(payment_menu_input));
        billing_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    end
    --session:hangup()
end

function internet_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] coming in the internet menu");
    if(user_selected_language == 'en')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in english queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    elseif(user_selected_language == 'swah')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in swahili queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    end
    -- Kenya_IVR_Internet_related_queries_en
    local Internet_related_queries_file = "/opt/caching/upload/"..user_selected_language.."/827e9993-c4ac-4af4-8b80-c49b3e3acd62.wav"
    local Internet_menu_allow_digit = '[0-9]'
    local internet_menu_input = session:playAndGetDigits(1,1,1,5000,'#',Internet_related_queries_file,'',Internet_menu_allow_digit)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] user seleceted the"..internet_menu_input);
    if(tonumber(internet_menu_input) == 1)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] user seleceted the"..tonumber(internet_menu_input));
        -- Kenya_IVR_Internet_Inq_1_en
        local no_internet_file = "/opt/caching/upload/"..user_selected_language.."/6afb4f6e-604c-4b25-9ab2-8b7507555294.wav"
        session:streamFile(no_internet_file)
    elseif(tonumber(internet_menu_input) == 2)then
        -- Kenya_IVR_Internet_Inq_2_en
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] user seleceted the"..tonumber(internet_menu_input));
        local modem_not_powering_on = "/opt/caching/upload/"..user_selected_language.."/36ef541e-4e96-479e-ae89-8663547531af.wav"
        session:streamFile(modem_not_powering_on)
    elseif(tonumber(internet_menu_input) == 9)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] user seleceted the"..tonumber(internet_menu_input));
        pass_queue(callerid,tenant_uuid,queue_uuid,logger,scripts_dir)
    elseif(tonumber(internet_menu_input) == 0)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][INTERNET_MENU] user seleceted the"..tonumber(internet_menu_input));
        internet_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    end
    --session:hangup()
end

function sales_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][SALES_MENU] coming in the sales menu");
    if(user_selected_language == 'en')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in english queue")
            queue_uuid = "dada5fdd-51bf-45ed-a5f3-e04ddb592f8b"
    elseif(user_selected_language == 'swah')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in swahili queue")
            queue_uuid = "dada5fdd-51bf-45ed-a5f3-e04ddb592f8b"
    end
    -- Kenya_IVR_Sale_Inq_en
    local sales_rellated_queries = "/opt/caching/upload/"..user_selected_language.."/195feb14-4932-4f21-8b79-41b44a6b6c4b.wav"
    local sales_menu_allowed_digit = '[0-3]'
    local sales_menu_input = session:playAndGetDigits(1,1,1,5000,'#',sales_rellated_queries,'',sales_menu_allowed_digit)
    if(tonumber(sales_menu_input) == 1)then
         -- Kenya_IVR_sales_Inq_1_en
         fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][SALES_MENU] user seleceted the"..tonumber(sales_menu_input));
        local delay_installation = "/opt/caching/upload/"..user_selected_language.."/b3e5f305-c4ea-4913-981e-63640350dfcd.wav"
        session:streamFile(delay_installation)
    elseif(tonumber(sales_menu_input) == 2)then
         -- Kenya_IVR_sales_Inq_2_en
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][SALES_MENU] user seleceted the"..tonumber(sales_menu_input));
        local new_account_opening = "/opt/caching/upload/"..user_selected_language.."/915768fb-bc04-4a87-880b-70bff14caf9c.wav"
        session:streamFile(new_account_opening)
    elseif(tonumber(sales_menu_input) == 3)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][SALES_MENU] user seleceted the"..tonumber(sales_menu_input));
        pass_queue(callerid,tenant_uuid,queue_uuid,logger,scripts_dir)
    elseif(tonumber(sales_menu_input) == 0)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][SALES_MENU] user seleceted the"..tonumber(sales_menu_input));
        sales_menu(logger,account_res,user_selected_language,caller_id,tenant_uuid,queue_uuid,scripts_dir)
    end
    --session:hangup()
end

function general_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_MENU] coming in the general menu");
    if(user_selected_language == 'en')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in english queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    elseif(user_selected_language == 'swah')then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in swahili queue")
            queue_uuid = "9de28831-c74f-4069-95fd-84b61e5e8525"
    end
    -- Kenya_IVR_General_Inq_en
    local general_queries = "/opt/caching/upload/"..user_selected_language.."/301f6870-3a30-41ea-9285-fcf0f727f067.wav"
    local general_menu_allowed_digit = '[0-9]'
    local general_menu_input = session:playAndGetDigits(1,1,1,5000,'#',general_queries,'',general_menu_allowed_digit)
    if(tonumber(general_menu_input) == 1)then
        -- Kenya_IVR_General_Inq_1_en
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_MENU] user seleceted the"..tonumber(general_menu_input));
        local general_inquiry_1 = "/opt/caching/upload/"..user_selected_language.."/58a63438-15ec-4e2b-81bd-ba13675f1dfc.wav"
        session:streamFile(general_inquiry_1)
    elseif(tonumber(general_menu_input) == 2)then
        -- Kenya_IVR_General_Inq_2_en
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_MENU] user seleceted the"..tonumber(general_menu_input));
        local general_inquiiry_2 = "/opt/caching/upload/"..user_selected_language.."/56e5694e-988f-4c56-b9e9-316670e93c8d.wav"
        session:streamFile(general_inquiiry_2)
    elseif(tonumber(general_menu_input) == 9)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_MENU] user seleceted the"..tonumber(general_menu_input));
        pass_queue(callerid,tenant_uuid,queue_uuid,logger,scripts_dir)
    elseif(tonumber(general_menu_input) == 0)then
        fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_MENU] user seleceted the"..tonumber(general_menu_input));
        general_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,queue_uuid,scripts_dir)
    end
    --session:hangup()
end

function pass_queue(callerid,tenant_uuid,queue_uuid,logger,scripts_dir)
        dofile(scripts_dir .. "common/db.lua");
        dofile(scripts_dir .. "common/custom.lua");
        callerid = string.gsub(callerid, "+", "")
        local lead_info = get_lead_info_for_queue_custom(callerid,tenant_uuid)
        local lead_name = ""
        local lead_uuid = ""
        local lead_group_uuid = "ff90b0aa-942d-448c-8248-b2acced3e9ad"
        if(lead_info ~= nil and lead_info ~= "")then
                if(lead_array.last_name ~= nil and lead_array.last_name ~= "")then
                        lead_name = lead_array.first_name.."__"..lead_array.last_name
                else
                        lead_name = lead_array.first_name
                end
                lead_uuid = lead_info.lead_management_uuid
                fs_logger(logger,"warning","["..callerid.."][CUSTOM_IVR][pass_queue] Lead Found")
        else
                local str_uuid = generateUUIDv4()
                local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
                local datatoinsert = {phone_number = callerid,custom_phone_number = callerid,first_name = "Anonymous",last_name = "",lead_management_uuid=str_uuid,tenant_uuid = tenant_uuid,lead_group_uuid = lead_group_uuid}
                fs_logger(logger,"warning","["..callerid.."][KENYA_IVR][pass_queue] Lead not found and insert str_uuid "..tostring(str_uuid))
                lead_mgmt_collection:insert(datatoinsert)
                lead_uuid = str_uuid
                lead_name = "Anonymous"
        end
        session:execute("export","sip_h_X-lead_name="..lead_name)
        session:execute("export","sip_h_X-Leaduuid="..lead_uuid)
        session:execute("set","sip_h_X-lead_name="..lead_name)
        session:execute("set","sip_h_X-Leaduuid="..lead_uuid)
        session:execute("export","sip_h_X-inbound_campaign_flag=true")
        session:execute("set","sip_h_X-inbound_campaign_flag=true")
        session:execute("export","sip_h_X-tenant_uuid="..tenant_uuid)
        session:execute("set","sip_h_X-tenant_uuid="..tenant_uuid)
        session:execute("export","sip_h_X-Custom-Callid="..session:getVariable("sip_call_id"))
        session:execute("export","custom_callid="..session:getVariable("sip_call_id"))
        session:execute("set","cc_export_vars=sip_h_X-Custom-Callid,custom_callid,sip_h_X-lead_name,sip_h_X-Leaduuid,sip_h_X-inbound_campaign_flag,sip_h_X-tenant_uuid")
        --session:execute("set","cc_export_vars=sip_h_X-lead_name,sip_h_X-Leaduuid,sip_h_X-inbound_campaign_flag,sip_h_X-tenant_uuid")
        session:execute("export","call_queue_id="..queue_uuid)
        session:execute("set","call_queue_id="..queue_uuid)
        session:execute("export","pbx_feature=call_queue")
        session:execute("set","pbx_feature=call_queue")
        session:execute("callcenter",queue_uuid.."@default")
end


fs_logger(logger,'notice',"[dialplan/kenya_ivr.lua][KENYA_IVR] Script start from here");
if (session:ready() ~= true) then
        return
else
        if (not params) then
                params = {}
                function params:getHeader(name)
                        self.name = name;
                end
                function params:serialize(name)
                        self.name = name;
                end
        end
        if (params:serialize() ~= nil) then
                fs_logger(logger,"notice","[KENYA_IVR] Params:\n" .. params:serialize())
        end
    local callerid = session:getVariable("caller_id_number")
    local logger = 0
    local session_language = 'en'
    local user_collection = mongo_collection_name:getCollection "user_info"
    local user_selected_language = get_prefered_language(logger,callerid,user_collection)
    local tenant_uuid = session:getVariable('tenant_uuid')
    local kenya_sales_english_queue = "dada5fdd-51bf-45ed-a5f3-e04ddb592f8b"
    local kenya_sales_swahili_queue = "dada5fdd-51bf-45ed-a5f3-e04ddb592f8b"
    -- Kenya_IVR_Welcome --
    local welcome_file = "/opt/caching/upload/"..session_language.."/cbf52f9f-1b05-4683-a36b-a37b32696c64.wav";
    fs_logger(logger,"notice","user selected langauge"..user_selected_language)

    if(user_selected_language ~= "")then
        -- Kenya_IVR_Welcome_save_langauge_en --
        -- welcome_file = "/opt/caching/upload/"..user_selected_language.."/3299c6f6-ed1e-468b-bad8-247b73402744.wav";
         welcome_file = "/opt/caching/upload/"..user_selected_language.."/32e4c7e9-73c5-4d23-a39d-b5464ca42185.wav";
    end
    fs_logger(logger,"notice","[KENYA_IVR] Phone number: : "..callerid)
        fs_logger(logger,"notice","[KENYA_IVR] Logger :0-> Enable,1->Disable :  "..logger)
    local scripts_dir ='/usr/local/freeswitch/scripts/'
    session:execute("set",'custom_ivr_file=true')
        session:execute("export",'custom_ivr_file=true')
    local get_account_input = '';
    if user_selected_language == "" then
        local language_selection_allowed_digit = "[1-2]"
        local get_language_input = session:playAndGetDigits(1, 1, 1, 50000, '#', welcome_file, '', language_selection_allowed_digit)

        fs_logger(logger,"notice", "[KENYA_IVR] ::get_language_input::" .. (get_language_input or "nil"))

        local after_language_selection_file = ""

        if get_language_input == "1" then
            fs_logger(logger,"notice", "[KENYA_IVR] ::customer selected the English language::")
            user_selected_language = "en"
            -- Kenya_IVR_after_select_langauge_en --
            after_language_selection_file = "/opt/caching/upload/"..user_selected_language.."/26d7a257-9db4-4dd6-a67f-598c33ba3d4f.wav"
        elseif get_language_input == "2" then
            fs_logger(logger,"notice", "[KENYA_IVR] ::customer selected the Swahili language::")
            user_selected_language = "swah"
            -- Kenya_IVR_after_select_langauge_en --
            after_language_selection_file = "/opt/caching/upload/"..user_selected_language.."/26d7a257-9db4-4dd6-a67f-598c33ba3d4f.wav"
        else
            fs_logger(logger,"notice", "[KENYA_IVR] ::invalid input or timeout::")
            session:hangup()
            return
        end

        -- Play confirmation file
        if after_language_selection_file ~= "" then
            local new_user = {
                first_name = "anonymous",  -- default to anonymous
                phone_number = callerid,
                email = "",
                custom_fields = "",
                language_code = user_selected_language
            }
            user_collection:insert(new_user)
            -- session:streamFile(after_language_selection_file)
            get_account_input = get_account_number(logger,after_language_selection_file)
        end
    else
        get_account_input = get_account_number(logger,welcome_file)
    end
    local account_res = {}
       fs_logger(logger,"notice", "Raw input value: [" .. tostring(get_account_input) .. "]")
    if(get_account_input ~= '')then
        fs_logger(logger,"notice", "Raw input type: " .. type(get_account_input))
        fs_logger(logger,"notice", "Raw input value: [" .. tostring(get_account_input) .. "]")
        if(tonumber(get_account_input) == 1)then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option")
            if(user_selected_language == 'en')then
                fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in english queue")
                pass_queue(callerid,tenant_uuid,kenya_sales_english_queue,logger,scripts_dir)
                -- break
            elseif(user_selected_language == 'swah')then
                fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the new user option and going in swahili queue")
                pass_queue(callerid,tenant_uuid,kenya_sales_swahili_queue,logger,scripts_dir)
                -- break
            end
        elseif(tonumber(get_account_input) == 2)then
            fs_logger(logger,"notice", "[KENYA_IVR] customer is selected the existing customer")
            -- Account Number invalid File 
            local account_number_invalid_file = '/opt/caching/upload/'..user_selected_language..'/002aa495-5e65-4485-8cbb-500549613e96.wav'
            --- Kenya_IVR_Account_No_Press_en ---
            local enter_account_number_file = '/opt/caching/upload/'..user_selected_language..'/601fb8e9-e49f-4412-8010-9767db6ce275.wav'
            account_res = get_account_details(logger,enter_account_number_file,account_number_invalid_file)
            -- account_res = get_customer_by_accountNumber(get_account_input)
            -- local dkjson = dofile("/usr/local/freeswitch/scripts/dkjson.lua")
            -- local res_str = dkjson.encode(account_res or {})
            -- fs_logger(logger,"notice", "[KENYA_IVR] customer api respone "..res_str.."\n")
        end
    end
    -- local account_verified = ''
    -- if(get_account_input == 2)then

    if account_res and account_res.status == 200 and type(account_res.customerList) == "table" and #account_res.customerList > 0 then
        -- Kenya_IVR_Inq_Main_Prompt_en --
        main_menu(logger,account_res,user_selected_language,callerid,tenant_uuid,kenya_sales_english_queue,scripts_dir)
        fs_logger(logger,"notice", "[KENYA_IVR] customer is verified")
    end    
    
--    session:hangup()
end
