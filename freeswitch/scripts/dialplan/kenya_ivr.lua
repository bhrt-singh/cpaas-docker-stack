dofile("/usr/local/freeswitch/scripts/config.lua")
dofile(scripts_dir .. "common/db.lua");
dofile(scripts_dir .. "common/custom.lua");
dofile(scripts_dir .. "common/kenya_sms.lua");
local json = dofile("/usr/local/freeswitch/scripts/dkjson.lua")
local user_collection = mongo_collection_name:getCollection "user_info"
local current_time = os.date("%Y-%m-%d %H:%M:%S")
local tenant_uuid = session:getVariable('tenant_uuid')

  -- get caller id --        
local callerid = session:getVariable("sip_from_user")
fs_logger("notice", "[KENYA_IVR] callerid details:\n" .. callerid)

local kenya_Repeat_queue = "941ddfea-668e-4881-b493-d7a8829d3ae6"
local kenya_Sales_queue = "dada5fdd-51bf-45ed-a5f3-e04ddb592f8b"
local kenya_Billing_queue = "7fe9f067-8221-4294-a9c0-44cfe47c3adf"
local kenya_internet_queue = "9de28831-c74f-4069-95fd-84b61e5e8525"
local kenya_site_follow_up_queue = "e7f8adfe-e8e4-49d6-9bb8-0151c22a2c66"
local kenya_general_inquiry_queue = "46f4a74c-539a-4542-96ab-74c0e493df8a"

        -- Start Functions --

        -- Converts userdata (e.g., BSON types) in Lua tables into safe string representations
                function sanitize_bson(tbl)
                        local function recurse(obj)
                                if type(obj) ~= "table" then
                                return obj
                                end

                                local clean = {}
                                for k, v in pairs(obj) do
                                local vtype = type(v)
                                if vtype == "userdata" then
                                        -- Safely convert userdata to string
                                        local success, str = pcall(tostring, v)
                                        clean[k] = success and str or "[userdata]"
                                elseif vtype == "table" then
                                        clean[k] = recurse(v)
                                else
                                        clean[k] = v
                                end
                                end
                                return clean
                        end

                        return recurse(tbl)
                end

                -- Agent Queue Route Function --
                function pass_queue(callerid,tenant_uuid,queue_uuid)
                       

                        local queue_collection = mongo_collection_name:getCollection "call_queue"
                        local query = { uuid = queue_uuid, tenant_uuid = tenant_uuid }
                        local cursor = queue_collection:find(query)
                        local queue_array = ''
                       
                        for queue_details in cursor:iterator() do
                                queue_array = queue_details;
                        end
                        local  queue_name = queue_array.name
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
                                fs_logger("warning","["..callerid.."][CUSTOM_IVR][pass_queue] Lead Found")
                        else
                                local str_uuid = generateUUIDv4()
                                local lead_mgmt_collection = mongo_collection_name:getCollection "lead_management"
                                local datatoinsert = {phone_number = callerid,custom_phone_number = callerid,first_name = "Anonymous",last_name = "",lead_management_uuid=str_uuid,tenant_uuid = tenant_uuid,lead_group_uuid = lead_group_uuid}
                                fs_logger("warning","["..callerid.."][KENYA_IVR][pass_queue] Lead not found and insert str_uuid "..tostring(str_uuid))
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
                        session:execute("export","sip_h_X-queue_name="..queue_name)
                        session:execute("set","sip_h_X-queue_name="..queue_name)
                        session:execute("export","sip_h_X-tenant_uuid="..tenant_uuid)
                        session:execute("set","sip_h_X-tenant_uuid="..tenant_uuid)
                        session:execute("export","sip_h_X-Custom-Callid="..session:getVariable("sip_call_id"))
                        session:execute("export","custom_callid="..session:getVariable("sip_call_id"))
                        session:execute("set","cc_export_vars=sip_h_X-Custom-Callid,custom_callid,sip_h_X-lead_name,sip_h_X-Leaduuid,sip_h_X-inbound_campaign_flag,sip_h_X-tenant_uuid,sip_h_X-queue_name")
                        --session:execute("set","cc_export_vars=sip_h_X-lead_name,sip_h_X-Leaduuid,sip_h_X-inbound_campaign_flag,sip_h_X-tenant_uuid")
                        session:execute("export","call_queue_id="..queue_uuid)
                        session:execute("set","call_queue_id="..queue_uuid)
                        session:execute("export","pbx_feature=call_queue")
                        session:execute("set","pbx_feature=call_queue")
                        session:execute("callcenter",queue_uuid.."@default")
                end

                 -- Get User data by callerid
                 function get_user_by_callerId(collection, callerid)
                        local cursor = collection:find({ phone_number = callerid })
                        if cursor then
                                local doc = cursor:value()
                                if doc ~= nil then
                                setmetatable(doc, { __index = function(tbl, key)
                                        return rawget(tbl, key)
                                end })
                                local clean = sanitize_bson(doc)

                                -- Logging
                                fs_logger("notice", "[KENYA_IVR] existing_user details:\n" .. json.encode(clean, { indent = true }))
                               -- fs_logger("notice", "Language: " .. tostring(doc.language_code))
                               -- fs_logger("notice", "Attempts: " .. tostring(doc.call_attempt))
                                return doc, clean
                                end
                        end

                        -- No document found
                        fs_logger("notice", "[KENYA_IVR] No existing user found.")
                        return nil, nil
                 end

                 -- Reusable IVR Menu Function with manual validation
                function ivr_menu_with_retries(opts)
                                local invalid_attempts = 0
                                local noinput_attempts = 0

                                while true do
                                        local input = session:playAndGetDigits(
                                        opts.min_digits or 1,
                                        opts.max_digits or 1,
                                        1,
                                        opts.timeout or 5000,
                                        opts.terminator or '#',
                                        opts.main_prompt,
                                        '',
                                        ''  -- no regex here, we'll validate manually
                                        )


                                        fs_logger('warning', "input " .. input)

                                        if input == nil or input == "" then
                                        -- 🔇 No input
                                        noinput_attempts = noinput_attempts + 1
                                        fs_logger('warning', "[IVR] No input (attempt " .. noinput_attempts .. ")")

                                        if noinput_attempts >= (opts.max_noinput_attempts or 1) then
                                                if opts.on_not_input_received then
                                                        opts.on_not_input_received()
                                                elseif opts.user_selected_language then
                                                        session:streamFile(opts.no_input_prompt)
                                                        call_hangup(opts.user_selected_language)
                                                else
                                                        session:streamFile(opts.no_input_prompt)
                                                        call_hangup("en")
                                                end
                                                return nil
                                        end

                                        session:streamFile(opts.no_input_prompt)

                                        elseif not string.match(input, opts.allowed_digits) then
                                        -- ❌ Invalid input
                                        invalid_attempts = invalid_attempts + 1
                                        fs_logger('warning', "[IVR] Invalid input: " .. tostring(input) .. " (attempt " .. invalid_attempts .. ")")

                                        if invalid_attempts >= (opts.max_invalid_attempts or 2) then
                                                session:streamFile(opts.invalid_input_prompt)
                                                if opts.user_selected_language then
                                                        call_hangup(opts.user_selected_language)
                                                else
                                                        call_hangup("en")
                                                end
                                                return nil
                                        end

                                        session:streamFile(opts.invalid_input_prompt)

                                        else
                                        -- ✅ Valid input
                                        fs_logger('notice', "[IVR] Valid input: " .. tostring(input))
                                        return input
                                        end
                                end
                end

                 -- Main menu play 
                 function main_menu(account_res,user_selected_language,callerid,tenant_uuid,prompt_file)
                        fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] coming in the main_menu");

                        local base_path = "/opt/caching/upload/"..user_selected_language.."/"

                        local main_menu_input = ivr_menu_with_retries{
                                user_selected_language = user_selected_language,
                                allowed_digits = "[0-5]",
                                max_invalid_attempts = 2,
                                max_noinput_attempts = 2,
                                main_prompt = prompt_file,
                                no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                                invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav"
                        }


                        if main_menu_input == nil then
                                fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] User failed to input after retries.")
                                return
                        end

                        local main_menu_digit = tonumber(main_menu_input)
                        fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][MAIN_MENU] user seleceted the -> "..main_menu_digit)

                          if main_menu_digit == 1 then
                                sales_queue(user_selected_language)
                          elseif main_menu_digit == 2 then
                               payment_billing_menu(user_selected_language)
                          elseif main_menu_digit == 3 then
                                internet_queue(user_selected_language)
                          elseif main_menu_digit == 4 then
                                site_visit_follow_up_queue(user_selected_language)
                          elseif main_menu_digit == 5 then
                                 general_inquiry_menu(user_selected_language)
                         elseif main_menu_digit == 0 then
                               main_menu(account_res,user_selected_language,callerid,tenant_uuid,prompt_file)
                        end
                        
                end

                -- Sales Queue 
                function sales_queue(user_selected_language) 

                         -- Kenya_IVR_Repeat_Queue_Welcome_File_en --
                         local Kenya_IVR_Repeat_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/7ad9789c-56a4-48d2-aafe-e931b3edb9fc.wav";
                         session:streamFile(Kenya_IVR_Repeat_Queue_Welcome_File)
                         pass_queue(callerid,tenant_uuid,kenya_Sales_queue)
                end


                function payment_billing_menu(user_selected_language)
                        fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][PAYMENT_BILLING_MENU] Starting menu")

                        local base_path = "/opt/caching/upload/"..user_selected_language.."/"

                        local payment_billing_menu_input = ivr_menu_with_retries{
                                user_selected_language = user_selected_language,
                                allowed_digits = "[0-2]",
                                max_invalid_attempts = 2,
                                max_noinput_attempts = 2,
                                main_prompt = base_path.."2498b8dc-508e-4f22-8a10-fc52093aee8e.wav",
                                no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                                invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav"
                        }

                        if payment_billing_menu_input == nil then
                                fs_logger('notice', "[KENYA_IVR][PAYMENT_BILLING_MENU] User failed to input after retries.")
                                return
                        end

                        local payment_billing_menu_digit = tonumber(payment_billing_menu_input)
                        fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][PAYMENT_BILLING_MENU] user seleceted the -> "..payment_billing_menu_digit)

                        if payment_billing_menu_digit == 1 then
                                payment_billing_press_1_menu(user_selected_language)
                        elseif payment_billing_menu_digit == 2 then
                                local account_res = {}
                                --Kenya_IVR_Payment_and_Billing_Inquiries_Press_2_en --
                                 local enter_account_number_file = '/opt/caching/upload/'..user_selected_language..'/1ad29708-3502-4ebd-ac5c-58d91c8c33b9.wav'
                                account_res = get_account_details(enter_account_number_file, user_selected_language)
                        elseif payment_billing_menu_digit == 0 then
                                payment_billing_menu(user_selected_language)
                        end
                end

                 


                -- payment_billing_menu_Press_1
                function payment_billing_press_1_menu(user_selected_language)
                         fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][PAYMENT_BILLING_MENU_PRESS_1] coming in the payment billing menu press 1");

                         -- Kenya_IVR_Payment_and_Billing_Inquiries_en --
                         local Kenya_IVR_Payment_and_Billing_Inquiries_Press_1_en = "/opt/caching/upload/"..user_selected_language.."/fbbc7018-09c3-4366-8456-9d6791391bdf.wav";
                        
                        
                        local base_path = "/opt/caching/upload/"..user_selected_language.."/"

                        local payment_billing_menu_press_1_input = ivr_menu_with_retries{
                                user_selected_language = user_selected_language,
                                allowed_digits = "^[09]$",
                                max_invalid_attempts = 2,
                                max_noinput_attempts = 2,
                                main_prompt = Kenya_IVR_Payment_and_Billing_Inquiries_Press_1_en,
                                no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                                invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav"
                        }

                        if payment_billing_menu_press_1_input == nil then
                                fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][PAYMENT_BILLING_MENU_PRESS_1] User failed to input after retries.")
                                return
                        end

                        local payment_billing_menu_press_1_digit = tonumber(payment_billing_menu_press_1_input)
                        fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][PAYMENT_BILLING_MENU_PRESS_1] user seleceted the -> "..payment_billing_menu_press_1_digit)


                         if payment_billing_menu_press_1_digit == 9 then
                                -- Kenya_IVR__Billing_Queue_Welcome_File_en --
                                local Kenya_IVR__Billing_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/634349f5-7ef3-42c0-ad4f-264117fae899.wav";
                                billing_queue(user_selected_language, Kenya_IVR__Billing_Queue_Welcome_File)
                        elseif payment_billing_menu_press_1_digit == 0 then
                                payment_billing_press_1_menu(user_selected_language)
                        end

                end

                -- Get Account Verified
                function get_account_details(enter_account_number_file,user_selected_language)
                         fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR] coming for the get account_details");
                         local max_digits = MAX_ACCOUNT_NO_DIGIT
                         local timeout = 10000
                         local digit_regex = "\\d+"
                         fs_logger("notice", "[KENYA_IVR] max account digit "..MAX_ACCOUNT_NO_DIGIT)
                         local account_number = session:playAndGetDigits(1,max_digits,1,timeout,'#',enter_account_number_file,'',digit_regex)

                         
                         if account_number == nil or account_number == '' then
                                fs_logger('notice', "[KENYA_IVR][ACCOUNT_NUMBER] No input received. Play Prompt")

                                -- Kenya_IVR_Account_Number_Not_Entered_Billing_Queue_Welcome_File_en --
                                local account_number_not_entered_file = '/opt/caching/upload/'..user_selected_language..'/b94d6842-34f1-445d-ba52-cd6fb56b76c7.wav'
                                billing_queue(user_selected_language, account_number_not_entered_file)
                                return
                         end

                         if(account_number)then 
                                        account_res = get_customer_by_accountNumber_and_mobileNo(account_number, callerid)
                                        local res_str = json.encode(account_res or {})
                                        fs_logger("notice", "[KENYA_IVR] customer api respone "..res_str.."\n")

                                        if account_res and type(account_res) == "table" and account_res.dataList and #account_res.dataList > 0 then
                                                fs_logger("notice", "[KENYA_IVR] customer is verified")
                                                send_payment_SMS(user_selected_language, account_number)
                                                return account_res
                                        else
                                                fs_logger("notice", "[KENYA_IVR] customer has entered a wrong accountnumber")
                                                -- Kenya_IVR_Wrong_Account_Number_Billing_Queue_Welcome_File_en --
                                                local account_number_invalid_file = '/opt/caching/upload/'..user_selected_language..'/432e5663-988d-458e-9273-3f5704d56de3.wav'
                                                billing_queue(user_selected_language, account_number_invalid_file)
                                        end
                         end       
                end        

                -- Billing Queue 
                function billing_queue(user_selected_language, welcome_prompt) 

                         session:streamFile(welcome_prompt)
                         pass_queue(callerid,tenant_uuid,kenya_Billing_queue)
                end


                 -- Internet Queue 
                function internet_queue(user_selected_language) 

                         -- Kenya_IVR_Internet_Queue_Welcome_File_en --
                         local Kenya_IVR_Internet_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/6a749b08-f4b0-46db-9b23-3fabc1ca12e7.wav";
                         session:streamFile(Kenya_IVR_Internet_Queue_Welcome_File)
                         pass_queue(callerid,tenant_uuid,kenya_internet_queue)
                end

                 -- Site Visit Follow up Queue 
                function site_visit_follow_up_queue(user_selected_language) 

                         -- Kenya_IVR_Site_Visit_Follow_Up_Queue_Welcome_File_en --
                         local Kenya_IVR_Site_Visit_Follow_Up_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/c3e82281-9a1f-44df-baed-1dfde0c6c1df.wav";
                         session:streamFile(Kenya_IVR_Site_Visit_Follow_Up_Queue_Welcome_File)
                         pass_queue(callerid,tenant_uuid,kenya_site_follow_up_queue)
                end

                  -- General Inquiry Menu
                function general_inquiry_menu(user_selected_language)
                         fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_INQUIRY_MENU] coming in the general inquiry menu");
                       
                         -- Kenya_IVR_General_Inquiries_en --
                         local Kenya_IVR_General_Inquiries = "/opt/caching/upload/"..user_selected_language.."/bdf5508c-ab94-44eb-b72b-bf021f9a92af.wav";
        
                         local base_path = "/opt/caching/upload/"..user_selected_language.."/"

                        local general_inquiry_menu_input = ivr_menu_with_retries{
                                user_selected_language = user_selected_language,
                                allowed_digits = "^[012]$",
                                max_invalid_attempts = 2,
                                max_noinput_attempts = 1,
                                main_prompt = Kenya_IVR_General_Inquiries,
                                no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                                invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav",
                                -- ✅ Custom no input handler
                                on_not_input_received = function()
                                        fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_MENU] No input received. Calling fallback...")
                                        Not_Press_Key_gen_inq_menu(user_selected_language)
                                end
                        }

                        if general_inquiry_menu_input == nil then
                                fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_MENU] User failed to input after retries.")
                                return
                        end

                        local general_inquiry_menu_digit = tonumber(general_inquiry_menu_input)
                        fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_MENU] user seleceted the -> "..general_inquiry_menu_digit)

                         if general_inquiry_menu_digit == 1 then
                               send_location_SMS(user_selected_language)
                         elseif general_inquiry_menu_digit == 2 then
                               send_Service_Coverage_SMS(user_selected_language)
                         elseif general_inquiry_menu_digit == 0 then
                                general_inquiry_menu(user_selected_language)
                         end
                end    
                
                -- send Payment SMS --
                function send_payment_SMS(user_selected_language, account_number) 
                        fs_logger('notice', "[KENYA_IVR] coming in send Payment SMS")
                        local final_account_number = COMMON_ACCOUNT_NO .. account_number
                        
                        local api_result = get_due_date_and_amount(account_number)

                        if not api_result then
                                fs_logger("err", "[send_payment_SMS] Could not fetch due date and amount.\n")
                                -- Kenya_IVR_Wrong_Account_Number_Billing_Queue_Welcome_File_en --
                                local account_number_invalid_file = '/opt/caching/upload/'..user_selected_language..'/432e5663-988d-458e-9273-3f5704d56de3.wav'
                                billing_queue(user_selected_language, account_number_invalid_file)
                                return
                        end
                        
                         local due_date_formatted = format_due_date(api_result.data.dueDate or "")
                        local bill_amount = string.format("%.2f", tonumber(api_result.data.totalAmount) or 0)



                        local location_SMS_text = "Your Acc: " .. final_account_number ..
                                " is due on " .. due_date_formatted ..
                                ". Top up KES" .. bill_amount ..
                                " & enjoy unlimited internet. M-Pesa Paybill 5515216 or Airtel Money Business Name SAVANNA_KE"
                       
                                 fs_logger("INFO", "[send_payment_SMS] Payment SMS \n" ..location_SMS_text)

                                 --local location_SMS_text = "Your Acc: ##Account## is due on ##Due_Date##. Top up KES ##Bill_Amount## & enjoy unlimited internet. M-Pesa Paybill 5515216 or Airtel Money Business Name SAVANNA_KE"
                                 local success = send_sms_via_onfon(callerid, location_SMS_text)
                                 if success then
                                        -- Kenya_IVR_Account_Number_Verified_SMS_en --
                                        local Kenya_IVR_Account_Number_Verified_SMS_File = "/opt/caching/upload/"..user_selected_language.."/3c1466de-e912-4405-8563-2ec8508e7d72.wav";
                                        session:streamFile(Kenya_IVR_Account_Number_Verified_SMS_File)
                                
                                else
                                        fs_logger("err", "[send_payment_SMS] SMS ERROR\n")
                                        -- Kenya_IVR_SMS_Failed_en --
                                        local Kenya_IVR_SMS_Failed_en_file = '/opt/caching/upload/'..user_selected_language..'/5b049e38-a1d4-4bde-aa29-49f8e96dc379.wav'
                                        billing_queue(user_selected_language, Kenya_IVR_SMS_Failed_en_file)
                                        return
                                end
                end 

                -- send Location SMS --
                function send_location_SMS(user_selected_language) 
                        
                         local location_SMS_text = "Shop 1 - Rehema House: Need help or ready to join Savanna Fibre? Walk into our shop at New Rehema House, Ground Floor, Rhapta Road - our team is ready to assist you! Shop 2 - Valley Arcade: Let's get you connected! Visit our Savanna Fibre shop at Valley Arcade Mall, Ground Floor, Gitanga Road - we're here to answer your questions and get you started."
                         send_sms_via_onfon(callerid, location_SMS_text)

                         local success = send_sms_via_onfon(callerid, location_SMS_text)
                        if success then
                                -- Kenya_IVR_General_Inquiries_Press_1_en --
                                local Kenya_IVR_General_Inquiries_Press_1 = "/opt/caching/upload/"..user_selected_language.."/bd376216-011b-4a79-b7ba-ccb95aed680b.wav";
                                session:streamFile(Kenya_IVR_General_Inquiries_Press_1)
                               
                        else
                                fs_logger("err", "[send_payment_SMS] SMS ERROR\n")
                                -- Kenya_IVR_SMS_Failed_en --
                                local Kenya_IVR_SMS_Failed_en_file = '/opt/caching/upload/'..user_selected_language..'/5b049e38-a1d4-4bde-aa29-49f8e96dc379.wav'
                                general_inquiry_queue(user_selected_language, Kenya_IVR_SMS_Failed_en_file)
                                return
                        end
                end   

                -- send Service Coverage SMS --
                 function send_Service_Coverage_SMS(user_selected_language) 
                        
                         local service_coverage_SMS_text = "Good news! Savanna Fibre may be available in your area. Check coverage now at www.savannafibre.co.ke/coverage and get connected to fast, reliable internet today"
                         send_sms_via_onfon(callerid, service_coverage_SMS_text)

                          local success = send_sms_via_onfon(callerid, location_SMS_text)
                        if success then
                               -- Kenya_IVR_General_Inquiries_Press_2_en --
                                local Kenya_IVR_General_Inquiries_Press_2 = "/opt/caching/upload/"..user_selected_language.."/fcc11a37-e6bc-4204-9c06-bf519b631f0e.wav";
                                session:streamFile(Kenya_IVR_General_Inquiries_Press_2)
                               
                        else
                                fs_logger("err", "[send_payment_SMS] SMS ERROR\n")
                                -- Kenya_IVR_SMS_Failed_en --
                                local Kenya_IVR_SMS_Failed_en_file = '/opt/caching/upload/'..user_selected_language..'/5b049e38-a1d4-4bde-aa29-49f8e96dc379.wav'
                                general_inquiry_queue(user_selected_language, Kenya_IVR_SMS_Failed_en_file)
                                return
                        end
                        
                end 

                function Not_Press_Key_gen_inq_menu(user_selected_language)
                         fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR][GENERAL_INQUIRY_NOT_PRESS_KEY_MENU] coming in the Not press key general inquiry menu");
                         --local general_inquiry_not_press_key_menu_allowed_digit = '[0-9]'
                         -- Kenya_IVR_General_Inquiries_Not_Entered_Any_Key_en --
                        -- local Kenya_IVR_General_Inquiries_Not_Entered_Any_Key = "/opt/caching/upload/"..user_selected_language.."/6c7677c4-0aa2-44ab-a0f7-85357877b13a.wav";
                         --local general_inquiry_not_press_menu_input = session:playAndGetDigits(1,1,1,5000,'#',Kenya_IVR_General_Inquiries_Not_Entered_Any_Key,'', general_inquiry_not_press_key_menu_allowed_digit)
               
                         -- Kenya_IVR_Gen_Inq_You_did_not_Press_Any_Key_en --
                         local Kenya_IVR_Gen_Inq_You_did_not_Press_Any_Key_en_file = "/opt/caching/upload/"..user_selected_language.."/d38bd59c-9449-4046-b7d9-f7d12d5e5902.wav";

                         session:streamFile(Kenya_IVR_Gen_Inq_You_did_not_Press_Any_Key_en_file)

                          -- Kenya_IVR_General_Inq_Repeat_or_Speak_en --
                         local Kenya_IVR_General_Inq_Repeat_or_Speak_en_file = "/opt/caching/upload/"..user_selected_language.."/9c60a0d9-abd5-4e63-9693-b0d93c6644e2.wav";
                         local base_path = "/opt/caching/upload/"..user_selected_language.."/"

                        local general_inq_not_press_key_menu_input = ivr_menu_with_retries{
                                user_selected_language = user_selected_language,
                                allowed_digits = "^[09]$",
                                max_invalid_attempts = 2,
                                max_noinput_attempts = 1,
                                main_prompt = Kenya_IVR_General_Inq_Repeat_or_Speak_en_file,
                                no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                                invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav",
                                -- ✅ Custom no input handler
                                on_not_input_received = function()
                                        fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_NOT_PRESS_KEY_MENU] No input received. Calling fallback...")
                                        call_hangup(user_selected_language)   
                                end
                        }

                        if general_inq_not_press_key_menu_input == nil then
                                fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_NOT_PRESS_KEY_MENU] User failed to input after retries.")
                                return
                        end

                        local general_inq_not_press_key_menu_digit = tonumber(general_inq_not_press_key_menu_input)
                        fs_logger('notice', "[KENYA_IVR][GENERAL_INQUIRY_NOT_PRESS_KEY_MENU] user seleceted the -> "..general_inq_not_press_key_menu_digit)
                        

                        if general_inq_not_press_key_menu_digit == 9 then
                                 -- Kenya_IVR_General_Inquiries_Queue_Welcome_File_en --
                                local Kenya_IVR_General_Inquiries_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/4589aabf-6237-43ae-ad10-0336a1e31551.wav";
                                general_inquiry_queue(user_selected_language, Kenya_IVR_General_Inquiries_Queue_Welcome_File)
                        elseif general_inq_not_press_key_menu_digit == 0 then
                                Not_Press_Key_gen_inq_menu(user_selected_language)        
                        end
                end

                 -- Site Visit Follow up Queue 
                function general_inquiry_queue(user_selected_language, welcome_prompt) 
                         session:streamFile(welcome_prompt)
                         pass_queue(callerid,tenant_uuid,kenya_general_inquiry_queue)
                end


                function call_hangup(user_selected_language) 
                         -- Kenya_IVR_Thank_You_File_en --
                         local Kenya_IVR_Thank_You_File = "/opt/caching/upload/"..user_selected_language.."/712bfc6f-39c4-430a-858a-eb6a93a03ea1.wav";
                         session:streamFile(Kenya_IVR_Thank_You_File)
                         session:hangup()
                end

        -- End Functions --

        -- IVR scripts start 
        fs_logger('notice',"[dialplan/kenya_ivr.lua][KENYA_IVR] Script start from here");

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
                        fs_logger("notice","[KENYA_IVR] Params:\n" .. params:serialize())
                end

        -- Set default langauge -- 
        local session_language = 'en'

        -- Check Existing User  -- 
        local user_doc, clean_doc = get_user_by_callerId(user_collection, callerid)

        -- User Call Attempts -- 
        local attempts = 0

        if user_doc  then
                fs_logger("notice", "User exists. Incrementing attempt...")
                attempts = tonumber(user_doc.call_attempt or 0)

                user_collection:update(
                        { phone_number = callerid },
                        { 
                                ["$inc"] = { call_attempt = 1 },
                                ["$set"] = { last_inbound_call = current_time }
                        }
                )
        else
                fs_logger("notice", "User not found. Inserting new user...")
                user_collection:insert({
                        phone_number = callerid,
                        call_attempt = 1,
                        created_at = current_time,
                        last_inbound_call = current_time,
                        first_name = "anonymous",
                        last_name = "anonymous",
                        language_code = "",
                        email = "",
                })
        end


         local user_selected_language = ""

         local user_detail_doc, user_json = get_user_by_callerId(user_collection, callerid)       

          if user_detail_doc then
                 user_selected_language = user_detail_doc.language_code or ""
          end

        -- Route logic
        if attempts >= 100 then
                fs_logger("debug", "User selected langauage..." ..user_selected_language)  
                session:execute("set",'session_language='..user_selected_language)
                -- Route to Repeat queue agent
                fs_logger("notice", "User exceeded 3 calls. Routing to Repeat queue agent...")

                -- Kenya_IVR_Repeat_Queue_Welcome_File_en --
                local Kenya_IVR_Repeat_Queue_Welcome_File = "/opt/caching/upload/"..session_language.."/9124d5b0-2ae4-448e-b200-9b6fd5f7fc4b.wav";
               
                if (user_selected_language == '') then 
                        -- Kenya_IVR_Repeat_Queue_Welcome_File_en --
                        Kenya_IVR_Repeat_Queue_Welcome_File = "/opt/caching/upload/"..session_language.."/9124d5b0-2ae4-448e-b200-9b6fd5f7fc4b.wav";
                else 
                        -- Kenya_IVR_Repeat_Queue_Welcome_File_en --
                        Kenya_IVR_Repeat_Queue_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/9124d5b0-2ae4-448e-b200-9b6fd5f7fc4b.wav";        
                end

                session:streamFile(Kenya_IVR_Repeat_Queue_Welcome_File)
                pass_queue(callerid,tenant_uuid,kenya_Repeat_queue)

        else
        -- Continue IVR
         fs_logger("notice", "User within limit. Routing to IVR...")

          -- Kenya_IVR_Language_Not_Selected_Welcome_File_en --
          local kenya_welcome_file = "/opt/caching/upload/"..session_language.."/7b9aa5e3-6913-4301-b25b-5e7ced18544d.wav";

           session:execute("set",'custom_ivr_file=true')
           session:execute("export",'custom_ivr_file=true')

          if (user_selected_language == '') then 
                -- Kenya_IVR_Language_Not_Selected_Welcome_File_en --
                 kenya_welcome_file = "/opt/caching/upload/"..session_language.."/7b9aa5e3-6913-4301-b25b-5e7ced18544d.wav";

                 local base_path = "/opt/caching/upload/"..session_language.."/"

                local langauge_selection_input = ivr_menu_with_retries{
                        user_selected_language = session_language,
                        allowed_digits = "[1-2]",
                        max_invalid_attempts = 2,
                        max_noinput_attempts = 2,
                        main_prompt = kenya_welcome_file,
                        no_input_prompt = base_path.."0501025f-fff0-48e7-aaac-bb82ebb35ecd.wav",
                        invalid_input_prompt = base_path.."6c7bea4a-93a5-44e5-af8c-deca7e7653f8.wav"
                }

                        if langauge_selection_input == nil then
                                fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][LANGAUGE_SELECTION] User failed to input after retries.")
                                return
                        end

                        local langauge_selection_digit = tonumber(langauge_selection_input)
                        fs_logger('notice', "[dialplan/kenya_ivr.lua][KENYA_IVR][LANGAUGE_SELECTION] user seleceted the -> "..langauge_selection_digit)

                 
                  local after_language_selection_file = ""

                 if langauge_selection_digit == 1 then
                       fs_logger("notice", "[KENYA_IVR] ::customer selected the English language::")
                       user_selected_language = "en"
                       session:execute("set",'session_language='..user_selected_language)
                       -- Kenya_IVR_After_Language_Selected_File_en --
                       after_language_selection_file = "/opt/caching/upload/"..user_selected_language.."/15259120-4880-4d55-9fa5-02db517f3fbf.wav"  
                elseif langauge_selection_digit == 2 then
                        fs_logger("notice", "[KENYA_IVR] ::customer selected the Swahili language::")
                        user_selected_language = "swah"
                         session:execute("set",'session_language='..user_selected_language)
                        -- Kenya_IVR_After_Language_Selected_File_en --
                        after_language_selection_file = "/opt/caching/upload/"..user_selected_language.."/15259120-4880-4d55-9fa5-02db517f3fbf.wav"
                end
                
                -- update user selected langauage --
                user_collection:update(
                        { phone_number = callerid },
                        { 
                                ["$set"] = { language_code = user_selected_language }
                        }
                )
                
                --session:streamFile(after_language_selection_file)
                main_menu(user_detail_doc,user_selected_language,callerid,tenant_uuid,after_language_selection_file)
          else 
                -- Kenya_IVR_Language_Selected_Welcome_File_en --
                fs_logger("debug", "User selected langauage..." ..user_selected_language)        
                session:execute("set",'session_language='..user_selected_language)
                local Kenya_IVR_Language_Selected_Welcome_File = "/opt/caching/upload/"..user_selected_language.."/3305488e-4ef1-493b-b986-94443a3b40c2.wav"
                main_menu(user_detail_doc,user_selected_language,callerid,tenant_uuid,Kenya_IVR_Language_Selected_Welcome_File)
          end      

        -- session:execute("transfer", "ivr_start XML default")
        end
end




