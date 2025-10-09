import os, json, pymongo, uuid, time,sys
import requests
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from datetime import datetime, timezone ,timedelta
#import datetime
import simplejson as json
import subprocess


# This is my path
path_to_json_files = "/usr/local/freeswitch/log/json_cdr/"
path_to_move_json_files = "/usr/local/freeswitch/log/json_cdr_archive/"

#Mongo Connection
myclient = pymongo.MongoClient("mongodb://mongoadmin:secret@127.0.0.1:27017/db_pbxcc?authSource=admin")
#myclient = pymongo.MongoClient("mongodb://inextrix:4Gc5fXwqN4BazAdc@127.0.0.1:27017/db_pbxcc")
mydb = myclient["db_pbxcc"]
cdrs_collection = mydb["cdrs"]
inbound_cdrs_collection = mydb["inbound_cdrs"]
webhook_collection = mydb["web_hook"]
lead_mgmt_collection = mydb['lead_management']
customer_callerid_collection = mydb["customer_callerid_management"]
ringgroup_collection = mydb["ring_group"]
tmp_rg_collection = mydb["tmp_ringgroup_details"]
recordings_collection = mydb["recording"]
cdrs_summary_collection = mydb["cdrs_summary"]
extension_collection = mydb["extensions"]
campaign_statistics_collection = mydb["campaign_statistics"]
#Json File List
json_file_names = [filename for filename in os.listdir(path_to_json_files) if filename.endswith('.json')]
json_file_names.sort(key=lambda x: os.path.getctime(os.path.join(path_to_json_files, x)), reverse=True)
#json_file_names.sort(key=lambda x: os.path.getctime(os.path.join(path_to_json_files, x)))

#file_name = sys.argv[1]
#print("File name:", file_name)


def manage_drop_call_flag (lead_uuid,hangup_reason):
        print("hangup_reason",hangup_reason)
        lead_mgmt_collection = mydb['lead_management']
        disposition_collection = mydb['disposition']
        lead_report_collection = mydb['lead_report']
        auto_hangup = variables_value['sip_h_X-amd_hangup'] if 'sip_h_X-amd_hangup' in variables_value else '';
        if auto_hangup != '' and auto_hangup == 'true':
                filter = {"code":"AA"}
        elif hangup_reason == 'ALLOTTED_TIMEOUT':
                filter = {"code":"NA"}
        elif hangup_reason == 'NORMAL_UNSPECIFIED':
                filter = {"code":"Busy"}
        elif hangup_reason == 'NO_USER_RESPONSE':
                filter = {"code":"NAVL"}
        else:
                filter = {"code":"DROP"}
        print("manage_drop_lead_uuid",lead_uuid)
        disposition_collection_data = disposition_collection.find_one(filter)
        disposition_uuid = "";
        if disposition_collection_data != '' and disposition_collection_data != None and disposition_collection_data != 'None':
                disposition_uuid = disposition_collection_data['disposition_uuid']
                print("Update lead status as DROP call for disposition_uuid",disposition_uuid)
                print("Update lead status as DROP call for UUID",lead_uuid)
                filter = {"lead_management_uuid": lead_uuid}
                update = {"$set": {"lead_status": disposition_uuid}}
                lead_mgmt_collection.update_one(filter, update)

                filter = {"lead_management_uuid":lead_uuid}
                lead_management_data = lead_mgmt_collection.find_one(filter)
                print("lead_management_data",lead_management_data)

                if lead_management_data != "" and lead_management_data != None:
                        new_call_count = lead_management_data['call_count'] + 1
                        filter = {"lead_group_uuid":lead_management_data['lead_group_uuid'],"disposition_uuid":disposition_uuid,"called_count":new_call_count}
                        lead_report_data = lead_report_collection.find_one(filter)

                        if lead_report_data != None:
                                print("lead_report_data",lead_report_data)
                                filter = {"lead_group_uuid":lead_management_data['lead_group_uuid'],"disposition_uuid":disposition_uuid,"called_count":new_call_count}

                                update = {"$inc":{"count":1}}
                                lead_report_collection.update_one(filter,update)
                                print("lead report updated successfully")
                        else:
                                print("lead_report_found_empty")
                                lead_report_uuid = uuid.uuid4()
                                lead_report_uuid = str(lead_report_uuid)
                                insert_lead_report_string = {"disposition_uuid":disposition_uuid,"lead_group_uuid":lead_management_data['lead_group_uuid'],"uuid":lead_report_uuid,"called_count":1,"count":1}
                                lead_report_collection.insert_one(insert_lead_report_string)
                                print("lead_report_insert_string",insert_lead_report_string)


        return disposition_uuid


def manage_lead_originated(variables_value):
        auto_lead_uuid  = variables_value['sip_h_P-lead_uuid'] if 'sip_h_P-lead_uuid' in variables_value else "";
        lead_originate = mydb["lead_originate"]
#       lead_originate_archive = mydb["lead_originate_archive"]
        filter = {"lead_management_uuid": auto_lead_uuid}
        print("auto_lead_uuid",auto_lead_uuid)
        document_to_copy = lead_originate.find_one(filter)
#       if document_to_copy != '' and document_to_copy != None and document_to_copy != 'None':
#               print(document_to_copy)
#               print(":::::document_to_copy")
#               lead_originate_archive.insert_one(document_to_copy)
        if auto_lead_uuid != "" and auto_lead_uuid != None and auto_lead_uuid != 'None':
                print("auto_lead_uuid DELETE",auto_lead_uuid)
                lead_originate.delete_many(filter)

def manage_auto_campaign(variables_value,auto_campaign_originate_uuid):
#       for variables_key in variables_value:
#               print(variables_key,"::HARSH:",variables_value[variables_key])
        auto_campaign_originate = mydb["auto_campaign_originate"]
        current_time = datetime.now()
        formatted_time = current_time.strftime("%Y-%m-%d %H:%M:%S")
        print("adesh formated date",formatted_time)
        filter = {"auto_campaign_originate_uuid": auto_campaign_originate_uuid,"flag":'3'}
        if int(variables_value['billsec']) > 0:
                print("manage_auto_campaign duration > 0")
                update = {"$set": {"flag": "0","last_calldate":formatted_time}}
        else:
                print("manage_auto_campaign duration == 0")
                update = {"$set": {"flag": "0"}}
        auto_campaign_originate.update_one(filter, update)

def manage_auto_campaign_count(variables_value,auto_campaign_originate_uuid):
#       for variables_key in variables_value:
#               print(variables_key,"::HARSH:",variables_value[variables_key])
        auto_campaign_originate = mydb["auto_campaign_originate"]
        current_time = datetime.now()
        formatted_time = current_time.strftime("%Y-%m-%d %H:%M:%S")
        filter = {"auto_campaign_originate_uuid": auto_campaign_originate_uuid}
        if int(variables_value['billsec']) > 0:
                print("manage_auto_campaign_count duration > 0",auto_campaign_originate_uuid)
                #update = {'$inc': {'call_count': 1}}
                update = {"$set": {"flag": "0","last_calldate":formatted_time}}
                auto_campaign_originate.update_one(filter, update)
        else:
                print("manage_auto_campaign_count duration == 0",auto_campaign_originate_uuid)
                update = {"$set": {"flag": "0"}}
                auto_campaign_originate.update_one(filter, update)


def check_number_masking(campaign_uuid,campaign_flag):
        outbound_campaign = mydb['outbound_campaign']
        blended_campaign = mydb['blended_campaign']
        filter = {'uuid':campaign_uuid}
        if(campaign_flag == 'blended'):
                result_campaign = blended_campaign.find_one(filter)
        else:
                result_campaign = outbound_campaign.find_one(filter)
        print(result_campaign)
        print("result of campaign")
        return result_campaign

def manage_lead_retries(variables_value,campaign_uuid,campaign_flag):
        lead_uuid = variables_value['sip_h_P-lead_uuid'] if 'sip_h_P-lead_uuid' in variables_value else '';
        outbound_campaign_db = mydb['outbound_campaign']
        blended_campaign_db = mydb['blended_campaign']
        filter = {'uuid':campaign_uuid}
        if(campaign_flag == 'blended'):
                campaign = blended_campaign_db.find_one(filter)
        else:
                campaign = outbound_campaign_db.find_one(filter)
        print(campaign)
        if campaign is not None:
                max_retries = campaign['max_retries']
                retries_time = campaign['retries_time']
                #campaign_leads_in_queue_count = outbound_campaign['leads_in_queue_count']
                print(max_retries)
                print(retries_time)
                print('adesh this you lead in _queue_count')
                #print(campaign_leads_in_queue_count)
                current_date = datetime.now()
                new_date = current_date + timedelta(minutes=int(retries_time))
                iso_date = f'ISODate({new_date.isoformat()}Z)'
                leads_in_queue_db = mydb['leads_in_queue'] 
                filter = {'campaign_uuid':campaign_uuid,'lead_management_uuid':lead_uuid}
                print(filter)
                lead_in_queue =  leads_in_queue_db.find_one(filter)
                print(lead_in_queue)
                if lead_in_queue is not None:
                        if 'lead_resent_count' in lead_in_queue:
                                if int(lead_in_queue['lead_resent_count']) < int(max_retries):
                                        lead_type = int(lead_in_queue['lead_resent_count']) + 1
                                        if int(lead_type) == int(max_retries):
                                                filter = {"campaign_uuid":campaign_uuid,"lead_management_uuid":lead_uuid}
                                                leads_in_queue_db.delete_one(filter)
                                                #campaign_filter = {'uuid':campaign_uuid}
                                                #campaign_leads_in_queue = int(campaign_leads_in_queue_count) - 1
                                                #update = {"$set":{'leads_in_queue_count':campaign_leads_in_queue}}
                                                #outbound_campaign_db.update_one(campaign_filter,update)
                                        else:
                                                filter = {"campaign_uuid":campaign_uuid,"lead_management_uuid":lead_uuid}
                                                update = {"$set": {"lead_resent_count": lead_type,"lead_sent":'1','resend_lead_time':iso_date}}
                                                leads_in_queue_db.update_one(filter,update)
                        else:
                                filter = {"campaign_uuid":campaign_uuid,"lead_management_uuid":lead_uuid}
                                update = {"$set": {"lead_resent_count": '1',"lead_sent":'1',"resend_lead_time":iso_date}}
                                leads_in_queue_db.update_one(filter,update)
                                print("updated successfully")

def lead_entry_management(destination_number,user_uuid,tenant_uuid):
        print("\n","here4:::")
        if destination_number.startswith("+"):
                dest_number = destination_number[1:]
        else:
                dest_number = destination_number
        tenant_collection = mydb['tenant']
        filter = {"uuid":tenant_uuid}
        tenant_info = tenant_collection.find_one(filter)
        lead_mgmt_collection = mydb['lead_management']
        lead_uuid = uuid.uuid4()
        new_lead_uuid = str(lead_uuid)
        filter = {"phone_number": dest_number,"tenant_uuid":tenant_uuid}
        lead_mgmt = lead_mgmt_collection.find_one(filter)
        if not lead_mgmt:
                if 'add_anonymous_lead' in tenant_info and str(tenant_info['add_anonymous_lead']) != '1':
                        insert_lead_mgmt_string = {"address": '',"state": '',"province": '',"postal_code": '',"dob": '',"phone_code": '',"alternate_phone_number": '',"email": '',"status": '0',"gender": '0',"created_flag": '2',"country_uuid": '',"city": '',"first_name":"Anonymous","last_name":"","phone_number":dest_number,"user_uuid":user_uuid,"tenant_uuid":tenant_uuid,"lead_management_uuid":new_lead_uuid, "lead_status": '3809f32d-9096-406b-b2ff-1207b3fbfbc5'}
                        lead_mgmt_collection.insert_one(insert_lead_mgmt_string)
                        print(insert_lead_mgmt_string)
                        return new_lead_uuid
                else:
                        return ""
        else:
                return lead_mgmt['lead_management_uuid']

def get_voicebroadcast_disposition(vb_type,lead_uuid,voicebroadcast_uuid,duration):
        disposition_collection = mydb['disposition']
        lead_mgmt_collection = mydb['lead_management']
        voicebroadcast_collection = mydb['voice_broadcast']
        lead_broadcast_queue_collection = mydb['lead_broadcast_queue']
        if vb_type == '0':
                filter = {'code':'SURVEY'}
        elif vb_type == '1':
                filter = {'code':'IVR'}
        elif vb_type == '2':
                filter = {'code':'NI'}
        elif vb_type == '3':
                filter = {'code':'DNC'}
        elif vb_type == 'CANCEL':
                filter = {'code':'NA'}
        elif vb_type == 'Busy Here':
                filter = {'code':'Busy'}
        elif vb_type == 'Temporarily Unavailable':
                filter = {'code':'NAVL'}
        elif vb_type == 'send_bye':
                filter = {'code':'NAVL'}
        elif duration != '0':
                filter = {'code':'NDP'}
        else:
                filter = {'code':'NA'}
        disposition = disposition_collection.find_one(filter)
        if disposition is not None:
                disposition_uuid = disposition['disposition_uuid']
                disposition_uuid = str(disposition_uuid)
                print("Update lead status as DROP voicebroadcast call for disposition_uuid",disposition_uuid)
                print("Update lead status as DROP voicebroadcast call for UUID",lead_uuid)
                filter = {"lead_management_uuid": lead_uuid}
                update = {"$set": {"lead_status": disposition_uuid}}
                lead_mgmt_collection.update_one(filter, update)
                filter = {'uuid':voicebroadcast_uuid}
                voicebroadcast_data = voicebroadcast_collection.find_one(filter)
                print('adesh this is your voicebroadcast data')
                print(voicebroadcast_data)
                filter = {'lead_management_uuid':leaduuid}
                lead_management_data = lead_mgmt_collection.find_one(filter)
                print(lead_management_data)
                if lead_management_data['retries_count'] < int(voicebroadcast_data['max_retries']):
                        if disposition_uuid in voicebroadcast_data['max_retries_disposition_uuid']:
                                max_count_document = lead_broadcast_queue_collection.find_one({"lead_group_uuid":lead_management_data['lead_group_uuid']},sort=[("count",-1)])
                                max_count = max_count_document['count'] if max_count_document else 0
                                new_count = max_count + 1
                                lead_broadcast_uuid = uuid.uuid4()
                                new_uuid = str(lead_broadcast_uuid)
                                lead_broadcast_queue_insert_string = {"lead_group_uuid":lead_management_data['lead_group_uuid'],"tenant_uuid":lead_management_data['tenant_uuid'],"lead_management_uuid":lead_management_data['lead_management_uuid'],"count":new_count,"uuid":new_uuid}
                                lead_broadcast_queue_collection.insert_one(lead_broadcast_queue_insert_string)
                                print('leads_in_queue_insert_string')
                                print(lead_broadcast_queue_insert_string)
                                lead_mgmt_collection.update_one({"lead_management_uuid":lead_uuid},{"$inc":{"retries_count":1}})
                        else:
                                print('not going in disposition condition')
                else:
                        print('not going in retries condition')
                return disposition_uuid

def starts_with_number(s):
    try:
        first_char = s[0]
        int(first_char)  # Try converting the first character to an integer
        return True  # If successful, it starts with a number
    except ValueError:
        return False

def send_notification(tenant_uuid,caller_id_name,caller_id_number,destination_number,callstart,call_type):
        print(tenant_uuid)
        print(caller_id_name)
        print(caller_id_number)
        print(destination_number)
        print(callstart)
        print("first",call_type)
        name_check = starts_with_number(caller_id_name)
        if name_check == True:
                caller_id_name = "Anonymous"
        mail_db = mydb['mail_configuration']
        #filter = {'host':"smtp.gmail.com"}
        #mail_configuration = mail_db.find_one(filter)
        tenant_db = mydb['tenant']
        filter = {'uuid':tenant_uuid}
        tenant_info = tenant_db.find_one(filter)
        print(tenant_info)
        #print(mail_configuration)
        #sender_email = str(mail_configuration['username'])
        sender_email = "7b26b2da1b254e6133d47b2cc3a2184a"
        sender_password = "1b7f00c11402cc3c26cacf592725ea87"
        from_email = "notifications@test.io"
        #recipient_email = "anjali.dixit@inextrix.com"
        recipient_email = str(tenant_info['email'])
        if call_type == "local":
                call_type = 'sip'
        subject = "Missed call notification from COMPANY"
        message = f"""\
    <html>
    <body>
        <p>Hello,</p>
        <p>You have received a missed call.</p>
        <p>Caller name: {caller_id_name}<br>
        Caller number: {caller_id_number}<br>
        Destination number: {destination_number}<br>
        Time: {callstart}<br>
        Missed by: {call_type}</p>
        <p>Thanks for using COMPANY</p>
        <br>
    </body>
    </html>
    """
        msg = MIMEMultipart()
        msg["From"] = from_email
        msg["To"] = recipient_email
        msg["Subject"] = subject
        msg.attach(MIMEText(message, "html"))
        smtp_server = "in-v3.mailjet.com"
        smtp_port = 587
        #with smtplib.SMTP_SSL(smtp_server, smtp_port) as server:
        #       server.login(sender_email, sender_password)
        #       server.sendmail(from_email, recipient_email, msg.as_string())
        #       print("Email sent successfully!")
        with smtplib.SMTP(smtp_server, smtp_port) as server:
                server.starttls()  # Use TLS encryption
                server.login(sender_email, sender_password)
                server.sendmail(from_email, recipient_email, msg.as_string())
                print("Email sent successfully!")

def set_caller_sticky(user_uuid,tenant_uuid,caller_id_number):
        user_collection = mydb['user']
        user_role_collection = mydb['user_role']
        sticky_agent_collection = mydb['sticky_agent']
        print("print the entry adesh")
        print(user_uuid)
        print(tenant_uuid)
        print(caller_id_number)
        filter = {'uuid':user_uuid}
        user_info = user_collection.find_one(filter)
        print("adesh user_info",user_info['user_role_uuid'])
        filter = {'uuid':user_info['user_role_uuid']}
        user_role_info = user_role_collection.find_one(filter)
        print("adesh_user_role_info",user_role_info)
        if 'sticky_agent' in user_role_info and user_role_info['sticky_agent'] == '0':
                sticky_new_uuid = uuid.uuid4()
                sticky_new_uuid = str(sticky_new_uuid)
                insert_sticky_string = {'uuid':sticky_new_uuid,'user_uuid':user_uuid,'tenant_uuid':tenant_uuid,'user_role_uuid':user_role_info['uuid'],'phone_number':caller_id_number,'sticky_user_role_status':'0'}
                sticky_agent_collection.insert_one(insert_sticky_string)
                print("sticky data inserted successfully")

#def Manage_new_incoming_lead(lead_uuid,campaign_uuid):
#       outbound_campaign_collection = mydb['outbound_campaign']
#       lead_mgmt_collection = mydb['lead_management']
#
#       filter = {'uuid':campaign_uuid}
#       outbound_campaign_info = outbound_campaign_collection.find_one(filter)
#       print("adesh incoming lead outbound campaign",outbound_campaign_info)
#       if 'lead_group_uuid' in outbound_campaign_info and outbound_campaign_info['lead_group_uuid'] != "":
#               filter = {'uuid':lead_uuid}
#               update = {"$set":{"lead_group_uuid":outbound_campaign_info['lead_group_uuid']}}
#               lead_mgmt_collection.update_one(filter,update)

def get_telecom_circle(tenant_uuid, destination_number):
    telecom_circle_collection = mydb['telecom_circle']
    first_digit = int(str(destination_number)[0])
    prefix_len = 0
    longest_prefix = ''
    longest_prefix_name = ''

    while len(destination_number) > 0:
        filter = {'tenant_uuid': tenant_uuid, 'prefix': {'$regex': '^' + str(first_digit)}}
        result = telecom_circle_collection.find(filter)

        for prefix_details in result:
            prefix_array = prefix_details
            if prefix_len == 0 or prefix_len < len(prefix_array['prefix']):
                prefix_len = len(prefix_array['prefix'])
                longest_prefix = prefix_array['prefix']
                longest_prefix_name = prefix_array['uuid']
                print("[common/custom.py]:: Prefix base caller id match:", longest_prefix)
                print("[common/custom.py]:: Prefix base caller id match:", longest_prefix_name)

        destination_number = destination_number[:-1]
        print('new longest_prefix', longest_prefix)
        print('new longest_prefix name', longest_prefix_name)

        # Check if the longest prefix matches the complete destination number
        if str(destination_number).startswith(longest_prefix):
            return longest_prefix_name

    # If no prefix matches the complete number, return blank response
    return ''

#For Loop for All File
for json_file_name in json_file_names:
    print("\n","Jsom File parsing Start for:",json_file_name)
    cdrs_json_file_collection = mydb['cdrs_json_file']
    filter = {"json_file_name": json_file_name}
    cdrs_json_file_exist = cdrs_json_file_collection.find_one(filter)
    if cdrs_json_file_exist:
        os.system("mv "+path_to_json_files+json_file_name+" "+path_to_move_json_files+json_file_name)
        print("\n","Json File exist Return")
        continue
    else:
        print("\n","File not exist Insert")
    insert_file_string = {"json_file_name":json_file_name}
    cdrs_json_file_collection.insert_one(insert_file_string)
    file_pass_flag = 0
    array_key = 0
    inbound_answered_user_uuid = ""
    inbound_answered_extension_uuid = ""
    with open(os.path.join(path_to_json_files, json_file_name)) as json_file:
        loaded_json = json.load(json_file)
        #Per File Loop
        for key in loaded_json:
                if key == 'variables':
                        #print(key,":::",loaded_json[key])
                        json_str = json.dumps(loaded_json[key])
                        variables_value = json.loads(json_str)
                        #Un Comment Below Line for Debug
                        temp_arr = []
                        for variables_key in variables_value:
                                if variables_key == 'dialed_user':
                                        temp_arr.append(variables_value[variables_key])
                                print(variables_key,":::",variables_value[variables_key])
                        print("harsh dialed_user",temp_arr)
                        auto_campaign = variables_value['sip_h_P-auto_campaign'] if 'sip_h_P-auto_campaign' in variables_value else "";
                        threeway_agent_extension_uuid = variables_value['threeway_agent_extension_uuid'] if 'threeway_agent_extension_uuid' in variables_value else "";
                        if threeway_agent_extension_uuid != "":
                                filter = {'user_uuid':threeway_agent_extension_uuid}
                                customer_callerid_info = customer_callerid_collection.delete_many(filter)
                        print("harsh auto_campaign",auto_campaign)              
                        voice_broadcast = variables_value['sip_h_P-voicebroadcast'] if 'sip_h_P-voicebroadcast' in variables_value else "";
                        if voice_broadcast == "false":
                                voice_broadcast = ''
                        sticky_agent_flag = variables_value['sticky_agent_flag'] if 'sticky_agent_flag' in variables_value else "";
                        #incoming_new_lead_flag = variables_value['sip_h_X-incoming_new_lead'] if 'sip_h_X-incoming_new_lead' in variables_value else "";
                        #if incoming_new_lead_flag != "" and incoming_new_lead_flag == 'true':
                        #       incoming_campaign_uuid = variables_value['sip_h_P-campaign_uuid'] if 'sip_h_P-campaign_uuid' in variables_value else "";
                
                        #       incoming_lead_uuid = variables_value['sip_h_X-lead_uuid'] if 'sip_h_X-lead_uuid' in variables_value else "";
                        #       print("incoming flag is found")
                        #       print("incoming camp",incoming_campaign_uuid)
                        #       print("incoming lead",incoming_lead_uuid)
                        #       if incoming_campaign_uuid != "" and incoming_lead_uuid != "":
                        #               Manage_new_incoming_lead(incoming_lead_uuid,incoming_campaign_uuid)
                
                        inbound_hangup_cause = variables_value['hangup_cause'] if 'hangup_cause' in variables_value else "";
                        success_answered_user_uuid = variables_value['user_uuid'] if 'user_uuid' in variables_value else "";
                        success_answered_extension_uuid = variables_value['extension_uuid'] if 'extension_uuid' in variables_value else "";
                        if inbound_hangup_cause == "NORMAL_CLEARING" and success_answered_user_uuid != "" and success_answered_extension_uuid != "":
                                tmp_call_uuid = variables_value['uuid'] if 'uuid' in variables_value else "";
                                inbound_answered_user_uuid = success_answered_user_uuid
                                inbound_answered_extension_uuid = success_answered_extension_uuid
                                tmp_uuid = uuid.uuid4()
                                new_tmp_uuid = str(tmp_uuid)
                                insert_rg_string = {"uuid":new_tmp_uuid,"call_uuid":tmp_call_uuid,"user_uuid":inbound_answered_user_uuid,"extension_uuid":inbound_answered_extension_uuid}
                                tmp_rg_collection.insert_one(insert_rg_string)
                
                
                
                                print("adesh this is the answered user uuid number",inbound_answered_user_uuid)
                                print("adesh answered extension uuid",inbound_answered_extension_uuid)
                        print("harsh manage_lead_originated",auto_campaign)
#                       if auto_campaign != '':
                        print("harsh manage_lead_originated",auto_campaign)
                        manage_lead_originated(variables_value)
                        auto_campaign_originate_uuid = variables_value['sip_h_P-auto_campaign_originate'] if 'sip_h_P-auto_campaign_originate' in variables_value else "";
                        if auto_campaign_originate_uuid != "":
                                manage_auto_campaign_count(variables_value,auto_campaign_originate_uuid)
                        auto_agent_flag = variables_value['sip_h_P-auto_agent_flag'] if 'sip_h_P-auto_agent_flag' in variables_value else "";
                        if auto_campaign_originate_uuid != "" and auto_agent_flag == '':
                                manage_auto_campaign(variables_value,auto_campaign_originate_uuid)
                        if(auto_agent_flag == "auto_agent"):
                                #Remove un-use file.
                                file_pass_flag = 1
                                os.unlink(path_to_json_files+json_file_name)
                                print("\n","Remove un-use file",path_to_json_files+json_file_name)
                                continue
                        callstart = variables_value['custom_callstart'] if 'custom_callstart' in variables_value else "";
                        created_at = datetime.now(timezone.utc)
                        #created_at = current_utc_time.strftime("%Y-%m-%dT%H:%M:%S.%f%z")
                        if callstart == "":
                                callstart = variables_value['sip_h_P-callstart'] if 'sip_h_P-callstart' in variables_value else "";
                        feature_code_flag = variables_value['feature_code_flag'] if 'feature_code_flag' in variables_value else "false";
                        if auto_campaign != "" or voice_broadcast != "":
                                if callstart == "":
                                        epoch_time = variables_value['end_epoch'] if 'end_epoch' in variables_value else "";
                                        print(int(epoch_time))
                                        #date_object = datetime.datetime.fromtimestamp(int(epoch_time))
                                        utc_now = datetime.utcnow()
                                        formatted_date = utc_now.strftime('%Y-%m-%d %H:%M:%S')
                                        callstart = formatted_date
                                        print("adesh auto campaign callstart ",callstart)
                        dest_number = variables_value['Caller-Destination-Number'] if 'Caller-Destination-Number' in variables_value else '';
                        if voice_broadcast != "" and voice_broadcast != 'false':
                                if dest_number == "":
                                        print("voicebroadcast fail dest_number coming");
                                        os.unlink(path_to_json_files+json_file_name)
                                        print("\n","Remove un-use file",path_to_json_files+json_file_name)
                                        break
                                print("voicebroadcast coming")
                                insert_broadcast_string = '';
                                main_lead_disposition = '';
                                broadcast_uuid = uuid.uuid4()
                                broadcast_uuid = str(broadcast_uuid)
                                voicebroadcast_details_collection = mydb['voicebroadcast_details']
                                billseconds = variables_value['billsec'] if 'billsec' in variables_value else '0';
                                voicebroadcast_uuid = variables_value['sip_h_P-campaign_uuid'] if 'sip_h_P-campaign_uuid' in variables_value else '';
                                voicebroadcast_uuid = str(voicebroadcast_uuid)
                                ten_uuid = variables_value['sip_h_P-tenant_uuid'] if 'sip_h_P-tenant_uuid' in variables_value else '';
                                ten_uuid = str(ten_uuid)
                                leaduuid = variables_value['sip_h_P-lead_uuid'] if 'sip_h_P-lead_uuid' in variables_value else '';
                                leaduuid = str(leaduuid)
                                callerid = variables_value['variable_effective_caller_id_number'] if 'variable_effective_caller_id_number' in variables_value else '';
                
                                voicebroadcast_type = variables_value['sip_h_P-voicebroadcast_type'] if 'sip_h_P-voicebroadcast_type' in variables_value else '';
                                print("voicebroadcast_type",voicebroadcast_type)
                                if voicebroadcast_type == '0':
                                        #broad cast type = Survey
                                        survey_string = variables_value['sip_h-p_survey_string'] if 'sip_h-p_survey_string' in variables_value else '';
                                        survey_disposition = get_voicebroadcast_disposition(voicebroadcast_type,leaduuid,voicebroadcast_uuid,billseconds)
                                        survey_disposition = str(survey_disposition)
                                        main_lead_disposition = survey_disposition
                                        print(survey_disposition)
                                        insert_broadcast_string = {"callstart":callstart,"phone_number":dest_number,"callerid":callerid,"duration":billseconds,"type":voicebroadcast_type,"disposition_uuid":survey_disposition,"voicebroadcast_uuid":voicebroadcast_uuid,"tenant_uuid":ten_uuid,"lead_uuid":leaduuid,"survey_details":survey_string,"uuid":broadcast_uuid}
                                        print(insert_broadcast_string)
                                        url = "https://hook.eu1.make.com/93frwd3fh8kldc6x1kdm9ucmijeyo68x"
                                        survey_webhook_data = survey_string
                                        print("\n","survey_webhook_data::::",survey_webhook_data)
                                        #headers = {'Content-type': 'application/json'}
                                        #survey_response_webhooks = requests.post(url, data=json.dumps(survey_webhook_data), headers=headers)
                                        #print("\n","survey_response_webhooks::::",survey_response_webhooks)
                                elif voicebroadcast_type == '1':
                                        #broad cast type = IVR
                                        dialed_digits = variables_value['digits_dialed'] if 'digits_dialed' in variables_value else '';
                                        skip_flag = variables_value['sip_h_P-skip_flag'] if 'sip_h_P-skip_flag' in variables_value else '';
                                        skip_flag = str(skip_flag)
                                        dialed_digits = str(dialed_digits)
                                        #digits = dialed_digits[1:];
                                        if skip_flag == 'true':
                                                digits = dialed_digits[1:];
                                        else:
                                                digits = dialed_digits;
                                        pressed_digits = ''
                                        for char in digits:
                                                pressed_digits += char + ","
                
                                        pressed_digits = pressed_digits.rstrip(',')
                                        print("adesh digits",pressed_digits)
                                        ivr_disposition = get_voicebroadcast_disposition(voicebroadcast_type,leaduuid,voicebroadcast_uuid,billseconds)
                                        ivr_disposition = str(ivr_disposition)
                                        main_lead_disposition = ivr_disposition
                                        insert_broadcast_string = {"callstart":callstart,"phone_number":dest_number,"callerid":callerid,"duration":billseconds,"type":voicebroadcast_type,"DTMF":str(pressed_digits),"disposition_uuid":ivr_disposition,"voicebroadcast_uuid":voicebroadcast_uuid,"tenant_uuid":ten_uuid,"lead_uuid":leaduuid,"uuid":broadcast_uuid}
                                        print(insert_broadcast_string)
                                elif voicebroadcast_type == '2':
                                        #broad cast type = Not Interested
                                        ni_disposition = get_voicebroadcast_disposition(voicebroadcast_type,leaduuid,voicebroadcast_uuid,billseconds)
                                        ni_disposition = str(ni_disposition)
                                        main_lead_disposition = ni_disposition
                                        insert_broadcast_string = {"callstart":callstart,"phone_number":dest_number,"callerid":callerid,"duration":billseconds,"type":voicebroadcast_type,"disposition_uuid":ni_disposition,"voicebroadcast_uuid":voicebroadcast_uuid,"tenant_uuid":ten_uuid,"lead_uuid":leaduuid,"uuid":broadcast_uuid}
                                        print(insert_broadcast_string)
                                elif voicebroadcast_type == '3':
                                        #broad cast type = DNC
                                        dnc_disposition = get_voicebroadcast_disposition(voicebroadcast_type,leaduuid,voicebroadcast_uuid,billseconds)
                                        dnc_disposition = str(dnc_disposition)
                                        main_lead_disposition = dnc_disposition
                                        insert_broadcast_string = {"callstart":callstart,"phone_number":dest_number,"callerid":callerid,"duration":billseconds,"type":voicebroadcast_type,"disposition_uuid":dnc_disposition,"voicebroadcast_uuid":voicebroadcast_uuid,"tenant_uuid":ten_uuid,"lead_uuid":leaduuid,"uuid":broadcast_uuid}
                                        print(insert_broadcast_string)
                                elif voicebroadcast_type == '':
                                        hangup_cause = variables_value['sip_invite_failure_phrase'] if 'sip_invite_failure_phrase' in variables_value else '';
                                        if hangup_cause == "":
                                                hangup_cause = variables_value['sip_hangup_disposition'] if 'sip_hangup_disposition' in variables_value else '';
                                        if hangup_cause != '':
                                                hangup_disposition = get_voicebroadcast_disposition(hangup_cause,leaduuid,voicebroadcast_uuid,billseconds)
                                                hangup_disposition = str(hangup_disposition)
                                                main_lead_disposition = hangup_disposition
                                                insert_broadcast_string = {"callstart":callstart,"phone_number":dest_number,"callerid":callerid,"duration":billseconds,"type":'',"disposition_uuid":hangup_disposition,"voicebroadcast_uuid":voicebroadcast_uuid,"tenant_uuid":ten_uuid,"lead_uuid":leaduuid,"uuid":broadcast_uuid}
                                                print(insert_broadcast_string)
                                if insert_broadcast_string != '':
                                        voicebroadcast_details_collection.insert_one(insert_broadcast_string)
                                        filter = {"lead_management_uuid": leaduuid}
                                        update = {"$set": {"lead_status": main_lead_disposition}}
                                        lead_mgmt_collection.update_one(filter, update)
                                file_pass_flag = 1
                                os.unlink(path_to_json_files+json_file_name)
                                print("\n","Remove un-use file",path_to_json_files+json_file_name)
                                break
                
                        if feature_code_flag == "true":
                                #Remove un-use file.
                                file_pass_flag = 1
                                os.unlink(path_to_json_files+json_file_name)
                                print("\n","FEATURE CODE","Remove un-use file",path_to_json_files+json_file_name)
                                continue

                        if callstart == "":
                                #Remove un-use file.
                                file_pass_flag = 1
                                os.unlink(path_to_json_files+json_file_name)
                                print("\n","Remove un-use file",path_to_json_files+json_file_name)
                                continue
                        pbx_feature = variables_value['pbx_feature'] if 'pbx_feature' in variables_value else "";
                        pbx_feature_uuid = ""
                        if pbx_feature == 'call_queue':
                                pbx_feature_uuid = variables_value['call_queue_id'] if 'call_queue_id' in variables_value else "";
                        if pbx_feature == 'ivr':
                                pbx_feature_uuid = variables_value['ivr_group_uuid'] if 'ivr_group_uuid' in variables_value else "";
                        if pbx_feature == 'ring_group':
                                pbx_feature_uuid = variables_value['ringgroup_id'] if 'ringgroup_id' in variables_value else "";
                        if pbx_feature == 'time_condition':
                                pbx_feature_uuid = variables_value['time_condition_uuid'] if 'time_condition_uuid' in variables_value else "";
                        ip_map_uuid = variables_value['ip_map_uuid'] if 'ip_map_uuid' in variables_value else "";
                        custom_callid = variables_value['custom_callid'] if 'custom_callid' in variables_value else "";
                        if custom_callid == '':
                                custom_callid = variables_value['sip_h_X-custom_callid'] if 'sip_h_X-custom_callid' in variables_value else "";
                        if custom_callid == '':
                                custom_callid = variables_value['sip_h_X-Custom-Callid'] if 'sip_h_X-Custom-Callid' in variables_value else "";
                        tenant_uuid = variables_value['tenant_uuid'] if 'tenant_uuid' in variables_value else "";
                        if tenant_uuid == '':
                                tenant_uuid = variables_value['sip_h_P-tenant_uuid'] if 'sip_h_P-tenant_uuid' in variables_value else "";
                        direction = variables_value['direction'] if 'direction' in variables_value else "outbound";
                        bridge_uuid = variables_value['bridge_uuid'] if 'bridge_uuid' in variables_value else str(uuid.uuid4());
                        user_uuid = variables_value['user_uuid'] if 'user_uuid' in variables_value else "";
                        if user_uuid == '':
                                user_uuid = variables_value['sip_h_P-user_uuid'] if 'sip_h_P-user_uuid' in variables_value else "";
                        authentication_type = variables_value['authentication_type'] if 'authentication_type' in variables_value else "auth";
                        extension_uuid = variables_value['extension_uuid'] if 'extension_uuid' in variables_value else "";
                        trunk_uuid = variables_value['trunk_uuid'] if 'trunk_uuid' in variables_value else "";
                        sip_user = variables_value['sip_user'] if 'sip_user' in variables_value else "";
                        #avmd_detect = variables_value['avmd_detect'] if 'avmd_detect' in variables_value else "";
                        ivr_group = variables_value['ivr_group_uuid'] if 'ivr_group_uuid' in variables_value else "";
                        variables_value['caller_id_name'] = variables_value['caller_id_name'] if 'caller_id_name' in variables_value else "";
                        caller_id_name = variables_value['effective_caller_id_name'] if 'effective_caller_id_name' in variables_value else variables_value['caller_id_name'];
                        variables_value['caller_id_number'] = variables_value['caller_id_number'] if 'caller_id_number' in variables_value else "";
                        caller_id_number = variables_value['effective_caller_id_number'] if 'effective_caller_id_number' in variables_value else variables_value['caller_id_number'];
                        variables_value['dialed_user'] = variables_value['dialed_user'] if 'dialed_user' in variables_value else '';
                        lead_uuid = variables_value['sip_h_X-Leaduuid'] if 'sip_h_X-Leaduuid' in variables_value else '';
                        if lead_uuid == '':
                                lead_uuid = variables_value['sip_h_X-lead_uuid'] if 'sip_h_X-lead_uuid' in variables_value else '';
                        if lead_uuid == '':
                                lead_uuid = variables_value['sip_h_P-lead_uuid'] if 'sip_h_P-lead_uuid' in variables_value else '';
                        if lead_uuid == "null":
                                lead_uuid = ""
                        hangup_reason = variables_value['hangup_cause'] if 'hangup_cause' in variables_value else '';
                        print("hangup1",hangup_reason)
                        auto_call_flag = "0" # Not Auto call
                        hangup_cause = ""
                        campaign_uuid = variables_value['sip_h_X-selectedcampaignuuid'] if 'sip_h_X-selectedcampaignuuid' in variables_value else '';
                        campaign_flag = variables_value['sip_h_X-campaign_flag'] if 'sip_h_X-campaign_flag' in variables_value else '';
                        call_stick_status = variables_value['call_stick_status'] if 'call_stick_status' in variables_value else 1;
                        billsecond = int(variables_value['billsec']) if 'billsec' in variables_value else '0';
                        if campaign_uuid == '':
                                campaign_uuid = variables_value['sip_h_P-campaign_uuid'] if 'sip_h_P-campaign_uuid' in variables_value else '';
                        if campaign_uuid != '':
                                current_date = datetime.now()
                                campaign_date = current_date.strftime('%Y-%m-%d')
                                manager_uuid = variables_value['sip_h_P-manager_uuid'] if 'sip_h_P-manager_uuid' in variables_value else '';
                                campaign_statistics_filter = {'tenant_uuid': tenant_uuid,'campaign_uuid': campaign_uuid,'campaign_date':campaign_date,'manager_uuid':manager_uuid}
                                campaign_duration_check = 0
                                if billsecond > 0 and billsecond < 30:
                                        campaign_duration_check = 1
                                campaign_statistics_drop_count = 0;
                                campaign_statistics_fail_count = 0;
                                campaign_statistics_amd_count = 0;
                                campaign_statistics_success_count = 0;
                                if auto_campaign != '':
                                        print("checking lead originate issue")
                                        print("adesh auto campaign",auto_campaign)
                                        print("adesh auto campaign originate uuid",auto_campaign_originate_uuid)
                                        print("adesh lead_uuid",lead_uuid)
                                        if auto_campaign != '' and auto_campaign_originate_uuid == '' and lead_uuid != "":
                                                print("adesh_ outbound")
                                                if int(billsecond) > 0:
                                                        campaign_statistics_drop_count = 1;
                                                print(tenant_uuid)
                                                print(hangup_reason)        
                                                hangup_cause = manage_drop_call_flag(lead_uuid,hangup_reason)
                                                auto_call_flag = "2" # Auto call and Drop 
                                        elif auto_campaign != '' and auto_campaign_originate_uuid != '' and lead_uuid != "":
                                                print("this is success but fail")
                                                if hangup_reason != "" and (hangup_reason == "NO_USER_RESPONSE" or hangup_reason == "ORIGINATOR_CANCEL"):
                                                        manage_drop_call_flag(lead_uuid,hangup_reason)
                                                        if int(billsecond) > 0:
                                                                campaign_statistics_drop_count = 1;
                                                        auto_call_flag = "2" # Auto call and Drop 
                                                else:
                                                        campaign_statistics_success_count = 1;
                                                        auto_call_flag = "1" # Auto call and success
                                        if billsecond > 0:
                                                campaign_statistics_success_count = 1;
                                        else:
                                                campaign_statistics_fail_count = 1;
                                else:
                                        if int(billsecond) > 0:
                                                print("adesh this auto_originate from success")
                                                campaign_statistics_success_count = 1;
                                        else:
                                                print("adesh this is auto originate")
                                                campaign_statistics_fail_count = 1;
                                        #campaign_statistics_success_count = 1;
                                auto_hangup = variables_value['sip_h_X-amd_hangup'] if 'sip_h_X-amd_hangup' in variables_value else '';
                                if auto_hangup != '' and auto_hangup == 'true':
                                        campaign_statistics_amd_count = 1
                                        campaign_statistics_drop_count = 0
                                #if billsecond > 0:
                                #       campaign_statistics_success_count = 1;
                                #else:
                                #       campaign_statistics_fail_count = 1;
                        
                                campaign_statistics_update = {'$inc': {'drop': campaign_statistics_drop_count,'success': campaign_statistics_success_count,'fail': campaign_statistics_fail_count,'short_call':campaign_duration_check,'amd':campaign_statistics_amd_count,'billsecond':billsecond}}
                                print(campaign_statistics_update)
                                print("campaign_statistics_update")
                                campaign_statistics_result = campaign_statistics_collection.find_one_and_update(campaign_statistics_filter,campaign_statistics_update, upsert=True)
                
                
                        if 'custom_destination_number' in variables_value and variables_value['custom_destination_number'] != '':
                                destination_number = variables_value['custom_destination_number']
                        else:
                                destination_number = variables_value['effective_destination_number'] if 'effective_destination_number' in variables_value else variables_value['dialed_user'];
                        disposition = variables_value['hangup_cause'] if 'hangup_cause' in variables_value else 'NORMAL_CLEARING';
                        call_state = 'normal'
                        originate_failed_cause = variables_value['originate_failed_cause'] if 'originate_failed_cause' in variables_value else '';
                        if originate_failed_cause != '' and originate_failed_cause == 'ORIGINATOR_CANCEL':
                                disposition = originate_failed_cause
                        if disposition == 'NO_ANSWER' or disposition == 'NO_USER_RESPONSE' or disposition == 'ORIGINATOR_CANCEL' or disposition == 'RECOVERY_ON_TIMER_EXPIRE':
                                call_state = 'missed'
                        ivr_menu_status = variables_value['ivr_menu_status'] if 'ivr_menu_status' in variables_value else '';
                        if ivr_menu_status == 'failure':
                                call_state = 'missed'
                                disposition = 'IVR_TIMEOUT'
                                pbx_feature_uuid = ivr_group
                        if ivr_menu_status == 'timeout':
                                call_state = 'missed'
                                disposition = 'IVR_TIMEOUT'
                                pbx_feature_uuid = ivr_group
                        cc_cause = variables_value['cc_cause'] if 'cc_cause' in variables_value else '';
                        if cc_cause and cc_cause != 'answered':
                                call_state = 'missed'
                                disposition = 'CALLQUEUE_TIMEOUT'
                        if disposition == 'ORIGINATOR_CANCEL':
                                call_state_main = 'normal'
                        else:
                                 call_state_main = call_state
                
                
                
                        call_type = variables_value['call_type'] if 'call_type' in variables_value else 'standard';
                        if call_type == 'standard' or call_type == 'did':
                                direction = 'outbound'
                        if 'custom_recording' in variables_value and  variables_value['custom_recording'] == '0':
                                print('adesh this is recording')
                
                                if 'current_application' in variables_value and variables_value['current_application'] == 'record_session':
                                        recording_path = variables_value['current_application_data'] if 'current_application_data' in variables_value else '';
                                else:
                                        execute_on_answer = variables_value['execute_on_answer'] if 'execute_on_answer' in variables_value else '';
                                        if 'record_session' in execute_on_answer:
                                                #recording_path = execute_on_answer.replace('record_session ', '')
                                                recording_path = execute_on_answer.split("/")
                                                recording_path = f"/{'/'.join(recording_path[1:])}"
                                                print('recording_path_in_execute_on_answer',recording_path)
                                        else:
                                                recording_path = ''
                                if 'sip_h_X-Autocalltype' in variables_value and variables_value['sip_h_X-Autocalltype'] == 'true':
                                        dialed_user = variables_value['sip_to_user'] if 'sip_to_user' in variables_value else '';
                                        recording_uuid = variables_value['bridge_uuid'] if 'bridge_uuid' in variables_value else '';
                                        recording_directory = variables_value['recording_directory'] if 'recording_directory' in variables_value else '';
                                        if recording_uuid != '':
                                                recording_path = recording_directory+'/'+dialed_user+'_'+recording_uuid+'.wav'
                                        else:
                                                recording_path = ''
                        else:
                                recording_path = ''
                        if recording_path != '':
                                print("this is the recording url",recording_path)
                                #audio = AudioSegment.from_wav(recording_path)
                                new_path = os.path.splitext(recording_path)[0] + '.wav'
                                #audio.export(new_path, format="mp3")
                                #ffmpeg -i recording_path new_path
                                result = subprocess.run(['ffmpeg', '-y', '-i', recording_path,'-ar', '44100', '-ac', '2', '-ab', '320k', new_path], stderr=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
                                print("ffmpeg Output:")
                                print(result.stdout)
                                print("ffmpeg Errors:")
                                print(result.stderr)
                                print("this is the new recording path",new_path)
                                if os.path.exists(recording_path):
                                    os.remove(recording_path)
                        recording_path = new_path
                        receiver_extension_uuid = variables_value['receiver_extension_uuid'] if 'receiver_extension_uuid' in variables_value else '';
                        originate_disposition = variables_value['originate_disposition'] if 'originate_disposition' in variables_value else '';
                        if originate_disposition != '' and (originate_disposition =='NO_ANSWER' or originate_disposition =='USER_BUSY'):
                                call_state = 'missed'
                                disposition = originate_disposition
                                billsecond = 0
                        if receiver_extension_uuid != '':
                                direction = 'outbound'
                        incoming_extra_entry_flag = 0
                        call_mode = '0'
                        if campaign_uuid != '':
                                call_mode = '1';
                        number_masking = '1'
                        dial_method = ""
                        if campaign_uuid != '' and campaign_flag != '':
                                result_outbound_campaign = check_number_masking(campaign_uuid,campaign_flag)
                                if result_outbound_campaign is not None:
                                        number_masking = result_outbound_campaign['number_masking'] if 'number_masking' in result_outbound_campaign else '1';
                                        dial_method = result_outbound_campaign['dial_method']
                        if campaign_uuid != '' and campaign_flag != '':
                                print(billsecond)
                                print(disposition)
                                if int(billsecond) == 0 and disposition != 'ORIGINATOR_CANCEL':
                                        manage_lead_retries(variables_value,campaign_uuid,campaign_flag)
                        print("\n","here1:::")
                        if destination_number != "" and lead_uuid == "":
                                print("\n","here2:::")
                                if user_uuid != "" and call_type != 'local':
                                        lead_uuid = lead_entry_management(destination_number,user_uuid,tenant_uuid)
                        #if avmd_detect != "":
                                #filter = {"code":"AA"}
                                #disposition = disposition_collection.find_one(filter)
                                #hangup_cause = disposition['disposition_uuid']         
                        auto_campaign = variables_value['sip_h_P-auto_campaign'] if 'sip_h_P-auto_campaign' in variables_value else "";
                        predictive_campaign = variables_value['sip_h_P-predictive_campaign'] if 'sip_h_P-predictive_campaign' in variables_value else "";
                        if(predictive_campaign == 'true'):
                                destination_number = variables_value['sip_h_P-original_number'] if 'sip_h_P-original_number' in variables_value else destination_number;
                                if (auto_call_flag =='1'):
                                        predictive_flag = "0"
                                else:
                                        predictive_flag = "1"
                                predictive_uuid = uuid.uuid4()
                                predictive_uuid = str(predictive_uuid)
                                insert_predictive_campaign = {"uuid":predictive_uuid,"campaign_uuid":campaign_uuid,"agent_uuid":user_uuid,"tenant_uuid":tenant_uuid,"flag":predictive_flag}
                                predictive_calculation_collection = mydb["predictive_calculation"]
                                predictive_calculation_collection.insert_one(insert_predictive_campaign)
                                print("\n","insert_predictive_campaign::::",insert_predictive_campaign)
                        if(auto_campaign == 'true'):
                                print("\n","auto_campaign CHANGE Destination:::")
                                destination_number = variables_value['sip_h_P-original_number'] if 'sip_h_P-original_number' in variables_value else destination_number;
                                caller_id_name = variables_value['Hunt-Callee-ID-Name'] if 'Hunt-Callee-ID-Name' in variables_value else caller_id_name;
                                caller_id_number = variables_value['Hunt-Orig-Caller-ID-Number'] if 'Hunt-Orig-Caller-ID-Number' in variables_value else caller_id_number;
                                number_masking = variables_value['sip_h_P-number_masking'] if 'sip_h_P-number_masking' in variables_value else number_masking;
                        hangup_party_disposition = variables_value['sip_hangup_disposition'] if 'sip_hangup_disposition' in variables_value else '';
                        print("adesh hangup party disposition",hangup_party_disposition)
                        print("hangup direction",direction)
                        disconnected_by = ''
                        if hangup_party_disposition == 'send_bye':
                                if direction == 'inbound':
                                        disconnected_by = '0'
                                else:
                                        disconnected_by = '1'
                        elif hangup_party_disposition == 'recv_bye':
                                if direction == 'inbound':
                                        disconnected_by = '1'
                                else:
                                        disconnected_by = '0'
                        elif hangup_party_disposition == 'recv_cancel':
                                if direction == 'inbound':
                                        disconnected_by = '1'
                                else:
                                        disconnected_by = '0'
                        elif hangup_party_disposition == 'send_refuse':
                                if direction == 'inbound':
                                        disconnected_by = '0'
                                else:
                                        disconnected_by = '1'
                        print("disconnected by",disconnected_by)
                        telecom_circle = ''
                        if direction == 'outbound':
                                telecom_circle = get_telecom_circle(tenant_uuid,destination_number)
                        else:
                                telecom_circle = get_telecom_circle(tenant_uuid,caller_id_number)
                        #Check Auto campaign connect with agent or not if not connect blank user_uuid
                        auto_campaign_connect = 0
                        if ip_map_uuid != '' or user_uuid == '':
                                #direction = 'inbound'
                                incoming_extra_entry_flag = 1
                                if(variables_value['sip_from_user'] and variables_value['sip_from_user'] != ''):
                                        caller_id_name = variables_value['sip_from_user'].replace("+","")
                                        caller_id_number = variables_value['sip_from_user'].replace("+","")
                                insert_inbound_cdr_json = {"uuid": bridge_uuid,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"trunk_uuid":trunk_uuid, "sip_user":sip_user,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"disposition":disposition,"direction": direction,"call_type":call_type, "callstart":callstart,"recording_path":recording_path,"pbx_feature":pbx_feature,"pbx_feature_uuid":pbx_feature_uuid,"authentication_type":authentication_type, "custom_callid":custom_callid,"ip_map_uuid":ip_map_uuid,"call_state":call_state_main,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"call_mode":call_mode, "hangup_cause":hangup_cause,"auto_call_flag":auto_call_flag,"ivr_group":ivr_group,"disconnected_by":disconnected_by,"createdAt":created_at,"circle_uuid":telecom_circle}
                                inbound_cdrs_collection.insert_one(insert_inbound_cdr_json)
                                print("\n","Inbound CDR Insert::::",insert_inbound_cdr_json)
                                if tenant_uuid != "":
                                        webhook_filter = {"tenant_uuid":tenant_uuid}
                                        webhook_data = webhook_collection.find_one(webhook_filter)
                                        print("adesh webhook data",webhook_data)
                                        if webhook_data is not None:
                                                url = str(webhook_data['web_hook_url'])
                                                if (str(webhook_data['notify']) != '0' and str(call_state) == 'missed'):
                                                        web_hook_data = {'description': 'incoming calls notification from Belsmart', 'caller_id_name': caller_id_name, 'caller_id_number': caller_id_number, 'did': destination_number, 'date': callstart, 'duration': billsecond,'call_status':call_state,'answered_call':variables_value['dialed_user']}
                                                else:
                                                        web_hook_data = {'description': 'incoming calls notification from Belsmart', 'caller_id_name': caller_id_name, 'caller_id_number': caller_id_number, 'did': destination_number, 'date': callstart, 'duration': billsecond,'call_status':call_state,'answered_call':variables_value['dialed_user']}
                                                print("\n","response_webhooks::::",web_hook_data)
                                                headers = {'Content-type': 'application/json'}
                                                response_webhooks = requests.post(url, data=json.dumps(web_hook_data), headers=headers)
                                                print("\n","response_webhooks::::",response_webhooks)
                
                                #if tenant_uuid == 'b4cebcbe-8ff6-4a8f-8ff4-9d99847f22bf':
                                        #url = "https://hook.eu1.make.com/rrcunnlep3j7lfsukd6v41qi29p47axs"
                                        #web_hook_data = {'description': 'incoming calls notification from Belsmart', 'caller_id_name': caller_id_name, 'caller_id_number': caller_id_number, 'did': destination_number, 'date': callstart, 'duration': billsecond,'call_status':call_state,'answered_call':variables_value['dialed_user']}
                                        #print("\n","response_webhooks::::",web_hook_data)
                                        #headers = {'Content-type': 'application/json'}
                                        #response_webhooks = requests.post(url, data=json.dumps(web_hook_data), headers=headers)
                                        #print("\n","response_webhooks::::",response_webhooks)
                                #if tenant_uuid == 'd615aa9c-5e2d-45d3-a721-a22b3b62a9ec' and destination_number == '00918069982776':
                                        #url = "https://hook.eu1.make.com/93frwd3fh8kldc6x1kdm9ucmijeyo68x"
                                        #web_hook_data = {'description': 'incoming calls notification from Belsmart', 'caller_id_name': caller_id_name, 'caller_id_number': caller_id_number, 'did': destination_number, 'date': callstart, 'duration': billsecond,'call_status':call_state,'answered_call':variables_value['dialed_user']}
                                        #print("\n","response_webhooks::::",web_hook_data)
                                        #headers = {'Content-type': 'application/json'}
                                        #response_webhooks = requests.post(url, data=json.dumps(web_hook_data), headers=headers)
                                        #print("\n","response_webhooks::::",response_webhooks)
                
                        else:
                                if auto_campaign != "":
                                        print("Auto Campaign call")
                                        if 'sip_h_X-Autocalltype' in variables_value and variables_value['sip_h_X-Autocalltype'] == 'true':
                                                print("Auto campaign  user_uuid in ");
                                        else:
                                                user_uuid = ""
                                                print("Remove user_uuid in ");          
                                did_pstn = ''
                                print("\n","CDRS")
                                insert_cdr_json = {"uuid": bridge_uuid,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"trunk_uuid":trunk_uuid, "sip_user":sip_user,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"disposition":disposition,"direction": direction,"call_type":call_type, "callstart":callstart,"recording_path":recording_path,"pbx_feature":pbx_feature,"pbx_feature_uuid":pbx_feature_uuid,"authentication_type":authentication_type, "custom_callid":custom_callid,"ip_map_uuid":ip_map_uuid,"call_state":call_state_main,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"call_mode":call_mode,"number_masking":number_masking,"dial_method":dial_method,"hangup_cause":hangup_cause,"auto_call_flag":auto_call_flag,"ivr_group":ivr_group,"disconnected_by":disconnected_by,"createdAt":created_at,"circle_uuid":telecom_circle }
                                print("\n","first harsh CDR Insert::::",insert_cdr_json)
                                cdrs_collection.insert_one(insert_cdr_json)
                        did_pstn = variables_value['did_pstn'] if 'did_pstn' in variables_value else '';
                        if (disposition == 'IVR_TIMEOUT' or disposition == 'CALLQUEUE_TIMEOUT' or did_pstn != '' or ivr_menu_status != ''):
                                bridge_uuid = bridge_uuid+"incoming"
                                direction = 'inbound'
                                insert_cdr_json = {"uuid": bridge_uuid,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"trunk_uuid":trunk_uuid, "sip_user":sip_user,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"disposition":disposition,"direction": direction,"call_type":call_type, "callstart":callstart,"recording_path":recording_path,"pbx_feature":pbx_feature,"pbx_feature_uuid":pbx_feature_uuid,"authentication_type":authentication_type, "custom_callid":custom_callid,"ip_map_uuid":ip_map_uuid,"call_state":call_state_main,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"call_mode":call_mode,"number_masking":number_masking,"dial_method":dial_method,"hangup_cause":hangup_cause,"auto_call_flag":auto_call_flag,"ivr_group":ivr_group,"createdAt":created_at,"circle_uuid":telecom_circle }
                                print("\n","second harsh CDR FOR INBOUND FAIL OR DIRECT OUTBOUND Insert::::",insert_cdr_json)
                                cdrs_collection.insert_one(insert_cdr_json)

                        #Insert Recording entry if have.
                        if billsecond != '' and int(billsecond) != 0:
                                if recording_path != '':
                                        insert_recoding_json = {"uuid": bridge_uuid,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"recording_path":recording_path,"direction": direction,"callstart":callstart,"call_state":call_state_main,"createdAt":created_at }
                                        recordings_collection.insert_one(insert_recoding_json)
                                        print("\n","Recording Insert::::",insert_recoding_json)
                        ##MANAGE CDRs SUMMARY
                        today_date = time.strftime("%Y-%m-%d")
                        # Define the filter to find the document
                        summary_filter = {'date': today_date,'tenant_uuid': tenant_uuid,'user_uuid': user_uuid,'direction':direction,"createdAt":created_at}
                        fail_count= 0 if int(billsecond) > 0 else 1;
                        success_count = 1 if int(billsecond) > 0 else 0;
                        total_count = 1
                        # Define the update operation
                        summary_update = {'$inc': {'fail': fail_count,'success': success_count,'total': total_count,'billsecond': billsecond}}
                        # Find the document and perform the update
#                       if ip_map_uuid != '' or user_uuid == '':
#                               print("\n",'Inbound call skip in summary')
#                       else:
#                               summaray_result = cdrs_summary_collection.find_one_and_update(summary_filter, summary_update, upsert=True)
#                               if summaray_result:
                                        # The record exists, and the update was successful
#                                       print("\n",'Summaray exists and was updated:', summaray_result)
#                               else:
                                        # The record doesn't exist
#                                       print("\n",'Summaray Record does not exist so updated.',summary_update)
                        summaray_result = cdrs_summary_collection.find_one_and_update(summary_filter, summary_update, upsert=True)
                        if summaray_result:
                                # The record exists, and the update was successful
                                print("\n",'Summaray exists and was updated:', summaray_result)
                        else:
                                # The record doesn't exist
                                print("\n",'Summaray Record does not exist so updated.',summary_update)
                        ##MANAGE CDRs SUMMARY END
                        #Extra CDRs Entry.
                
                        if receiver_extension_uuid != '':
                                direction = 'inbound'
                                if hangup_party_disposition == 'send_bye':
                                        if direction == 'inbound':
                                                disconnected_by = '0'
                                        else:
                                                disconnected_by = '1'
                                elif hangup_party_disposition == 'recv_bye':
                                        if direction == 'inbound':
                                                disconnected_by = '1'
                                        else:
                                                disconnected_by = '0'
                                elif hangup_party_disposition == 'recv_cancel':
                                        if direction == 'inbound':
                                                disconnected_by = '1'
                                        else:
                                                disconnected_by = '0'
                                elif hangup_party_disposition == 'send_refuse':
                                        if direction == 'inbound':
                                                disconnected_by = '0'
                                        else:
                                                disconnected_by = '1'
                                print("inbound_disconnected by",disconnected_by)
                                extension_uuid = receiver_extension_uuid
                                user_uuid = variables_value['receiver_user_uuid'] if 'receiver_user_uuid' in variables_value else "";
                                sip_call_id = variables_value['sip_call_id'] if 'sip_call_id' in variables_value else custom_callid;
                                #Insert CDRs Entry.
                                if call_type == 'did':
                                        print("\n","here6:::")
                                        if user_uuid != "" and lead_uuid == "" and call_type != 'local':
                                                print("\n","here7:::")
                                                if caller_id_number.startswith("+"):
                                                        caller_id_number = caller_id_number[1:]
                                                if caller_id_name.startswith("+"):
                                                        caller_id_name = caller_id_name[1:]
                                                lead_uuid = lead_entry_management(caller_id_number,user_uuid,tenant_uuid)
                                if call_state == 'missed':
                                        send_notification(tenant_uuid,caller_id_name,caller_id_number,destination_number,callstart,call_type)
                                insert_cdr_json = {"uuid": bridge_uuid+"-local","user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"trunk_uuid":trunk_uuid, "sip_user":sip_user,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"disposition":disposition,"direction": direction,"call_type":call_type,"callstart":callstart,"recording_path":recording_path,"pbx_feature":pbx_feature,"pbx_feature_uuid":pbx_feature_uuid,"authentication_type":authentication_type, "custom_callid":sip_call_id,"ip_map_uuid":ip_map_uuid,"call_state":call_state ,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"call_mode":call_mode,"number_masking":number_masking,"dial_method":dial_method,"hangup_cause":hangup_cause,"auto_call_flag":auto_call_flag,"ivr_group":ivr_group,"disconnected_by":disconnected_by,"createdAt":created_at,"circle_uuid":telecom_circle }
                                cdrs_collection.insert_one(insert_cdr_json)
                                print("\n","third harsh Extra CDR Insert::::",insert_cdr_json)
                                #Insert Recording entry if have.
                                if billsecond != '' and int(billsecond) != 0:
                                        if recording_path != '':
                                                insert_recoding_json = {"uuid": bridge_uuid+"-local","user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"recording_path":recording_path,"direction": direction,"callstart":callstart,"call_state":call_state,"createdAt":created_at }
                                                recordings_collection.insert_one(insert_recoding_json)
                                                print("\n","Extra Recording Insert::::",insert_recoding_json)
                                ##MANAGE CDRs SUMMARY
                                today_date_second = time.strftime("%Y-%m-%d")
                                # Define the filter to find the document
                                summary_filter = {'date': today_date_second,'tenant_uuid': tenant_uuid,'user_uuid': user_uuid,'direction':direction,"createdAt":created_at}
                                fail_count = 0 if int(billsecond) > 0 else 1
                                success_count = 1 if int(billsecond) > 0 else 0
                                total_count = 1
                                # Define the update operation
                                summary_update = {'$inc': {'fail': fail_count,'success': success_count,'total': total_count,'billsecond': billsecond}}
                
                                # Find the document and perform the update
                                summaray_result = cdrs_summary_collection.find_one_and_update(summary_filter, summary_update, upsert=True)
                                if summaray_result:
                                        # The record exists, and the update was successful
                                        print("\n",'Extra Summaray exists and was updated:', summaray_result)
                                else:
                                        # The record doesn't exist
                                        print("\n",'Extra Summaray Record does not exist so updated.',summary_update)
                                ##MANAGE CDRs SUMMARY END
                        ##FOR RING GROUP AND OTHER FEATURES
                        #if (pbx_feature == 'ring_group' or pbx_feature == 'call_queue') and authentication_type == 'acl':
                        if pbx_feature == 'ring_group' or pbx_feature == 'call_queue':
                                if pbx_feature == 'ring_group':
                                        dialed_user = variables_value['dialed_user']
                                        extension_user = dialed_user
                                if pbx_feature == 'call_queue':
                                        dialed_user = variables_value['cc_agent'].replace("@default", "") if 'cc_agent' in variables_value else variables_value['dialed_user']
                                        dialed_user_explode = dialed_user.split('.')
                                        extension_user = dialed_user_explode[0]

                        
                                extension_search_query = {'username': extension_user, 'tenant_uuid':tenant_uuid}
                                extensions_result = extension_collection.find_one(extension_search_query)
                                print("\n","IN PBX FEATURE EXTRA ENTRY",pbx_feature,extension_search_query)
                                if  extensions_result and extensions_result['uuid'] != '':
                                        extension_uuid = extensions_result['uuid']
                                        user_uuid = extensions_result['user_uuid']
                                        direction = 'inbound'
                                        sip_call_id = variables_value['sip_call_id'] if 'sip_call_id' in variables_value else custom_callid;
                                        #Insert CDRs Entry.
                                        print("\n","here5:::",call_type)
                                        if call_type == 'did':
                                                print("\n","here6:::")
                                                if user_uuid != "" and lead_uuid == "" and call_type != 'local':
                                                        print("\n","here7:::")
                                                        if caller_id_number.startswith("+"):
                                                                caller_id_number = caller_id_number[1:]
                                                        if caller_id_name.startswith("+"):
                                                                caller_id_name = caller_id_name[1:]
                                                        lead_uuid = lead_entry_management(caller_id_number,user_uuid,tenant_uuid)
                                        if call_state == "missed":
                                                send_notification(tenant_uuid,caller_id_name, caller_id_number,destination_number,callstart,pbx_feature)
                                        harsh_user = variables_value['harsh_user'] if 'harsh_user' in variables_value else ""
                                        if pbx_feature == 'ring_group':
                                                last_bridge_uuid = variables_value['last_bridge_to'] if 'last_bridge_to' in variables_value else "";
                                                if last_bridge_uuid != "":
                                                        filter = {'call_uuid':last_bridge_uuid}
                                                        call_data = tmp_rg_collection.find_one(filter)
                                                        print(call_data)
                                                        if call_data is not None:
                                                                user_uuid = call_data['user_uuid']
                                                                extension_uuid = call_data['extension_uuid']
                                                                print(user_uuid)
                                                                print(extension_uuid)
                                                else:
                                                        print("adesh this is last bridge else")
                                                        ringgroup_uuid = variables_value['ringgroup_id'] if 'ringgroup_id' in variables_value else "";
                                                        ringgroup_from_domain = variables_value['ringgroup_from_domain'] if 'ringgroup_from_domain' in variables_value else "";
                                                        print(ringgroup_uuid)
                                                        filter = {'uuid':ringgroup_uuid}
                                                        ringgroup_data = ringgroup_collection.find_one(filter)
                                                        if ringgroup_data is not None:
                                                                extension_list = ringgroup_data.get("extension_list", [])
                                                                print("extensionlist",extension_list)
                                                                for extension_info in extension_list:
                                                                        if extension_info != "":
                                                                                extension_type = extension_info.get('extension_type')
                                                                                extension = extension_info.get('extension')
                                                                                extension_user_uuid = extension_info.get('user_uuid')
                                                                                if int(extension_type) == 0:
                                                                                        #status_command = "/mnt/myenv/bin/python3.10 /usr/local/freeswitch/scripts/cdrs/register.py ",extesnion ,ringgroup_from_domain)
                                                                                        status_command = "/mnt/myenv/bin/python3.10 /usr/local/freeswitch/scripts/cdrs/register.py {} {}".format(extension, ringgroup_from_domain)
                                                                                        print(status_command)
                                                                                        os.system(status_command + " > temp_output.txt")
                                                                                        with open("temp_output.txt", "r") as temp_file:
                                                                                                captured_output = temp_file.read()
                                                                                                print(captured_output)
                                                                                                captured_output = captured_output.strip()
                                                                                                if captured_output == 'Registered':
                                                                                                        print(captured_output)
                                                                                                        user_uuid = extension_user_uuid
                                                                                                        print(user_uuid)
                
                
                
                
                                        if sticky_agent_flag == '1' and call_type != "local" and call_state != 'missed':
                                                print("useruuid_array",inbound_answered_user_uuid)
                                                print("extension_uuid",inbound_answered_extension_uuid)
                                                print("adesh ",user_uuid)
                                                print("harsh_user check",harsh_user)
                                                set_caller_sticky(user_uuid,tenant_uuid,caller_id_number)

                                        insert_cdr_json = {"uuid": bridge_uuid+"-"+pbx_feature,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"trunk_uuid":trunk_uuid, "sip_user":sip_user,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"disposition":disposition,"direction": direction,"call_type":call_type,"callstart":callstart,"recording_path":recording_path,"pbx_feature":pbx_feature,"pbx_feature_uuid":pbx_feature_uuid,"authentication_type":authentication_type, "custom_callid":sip_call_id,"ip_map_uuid":ip_map_uuid,"call_state":call_state,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"call_mode":call_mode,"number_masking":number_masking,"dial_method":dial_method,"call_stick_status":call_stick_status,"hangup_cause":hangup_cause,"auto_call_flag":auto_call_flag,"ivr_group":ivr_group,"disconnected_by":disconnected_by,"createdAt":created_at,"circle_uuid":telecom_circle }
                                        cdrs_collection.insert_one(insert_cdr_json)
                                        print("\n","Four harsh Extra PBX CDR Insert::::",insert_cdr_json)
                                        #Insert Recording entry if have.
                                        if billsecond != '' and int(billsecond) != 0:
                                                if recording_path != '':
                                                        insert_recoding_json = {"uuid": bridge_uuid+"-"+pbx_feature,"user_uuid":user_uuid,"extension_uuid":extension_uuid,"tenant_uuid":tenant_uuid,"caller_id_name":caller_id_name,"caller_id_number":caller_id_number,"destination_number":destination_number, "billsecond":billsecond,"recording_path":recording_path,"direction": direction,"callstart":callstart,"call_state":call_state,"createdAt":created_at }
                                                        recordings_collection.insert_one(insert_recoding_json)
                                                        print("\n","Extra PBX Recording Insert::::",insert_recoding_json)
                                        ##MANAGE CDRs SUMMARY
                                        today_date_second = time.strftime("%Y-%m-%d")
                                        # Define the filter to find the document
                                        summary_filter = {'date': today_date_second,'tenant_uuid': tenant_uuid,'user_uuid': user_uuid,'direction':direction,"createdAt":created_at}
                                        fail_count = 0 if int(billsecond) > 0 else 1
                                        success_count = 1 if int(billsecond) > 0 else 0
                                        total_count = 1
                                        # Define the update operation
                                        summary_update = {'$inc': {'fail': fail_count,'success': success_count,'total': total_count,'billsecond': billsecond}}
                                        # Find the document and perform the update
                                        summaray_result = cdrs_summary_collection.find_one_and_update(summary_filter, summary_update, upsert=True)
                                        if summaray_result:
                                                # The record exists, and the update was successful
                                                print("\n",'Extra Summaray exists and was updated:', summaray_result)
                                        else:
                                                # The record doesn't exist
                                                print("\n",'Extra Summaray Record does not exist so updated.',summary_update)

    #Mv file in other place one record pass
    if file_pass_flag == 0:     
        os.system("mv "+path_to_json_files+json_file_name+" "+path_to_move_json_files+json_file_name)
    print("\n","Jsom File parsing END for:",json_file_name)

#Mongo Connection close.    
myclient.close()
