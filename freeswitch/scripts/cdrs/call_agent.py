from freeswitchESL import ESL
from datetime import datetime
import pymongo
import json,sys,uuid,time
import urllib.parse
import re

def word_exists(text, word):
    return bool(re.search(r'\b' + re.escape(word) + r'\b', text))

# create an ESL connection to FreeSWITCH
con = ESL.ESLconnection("127.0.0.1", "8021", "ClueCon")

# authenticate with FreeSWITCH
if con.connected():
    print("Successfully connected to FreeSWITCH!")
else:
    print("Failed to connect to FreeSWITCH")
    
myclient = pymongo.MongoClient("mongodb://mongoadmin:secret@127.0.0.1:27017/db_pbxcc?authSource=admin")
mydb = myclient["db_pbxcc"]
auto_originate_collection = mydb['auto_campaign_originate']
realtime_report_collection = mydb['realtime_report_count_mgmt']
inbound_report_collection = mydb['inbound_realtime_count_mgmt']
manager_realtime_collection = mydb['manager_realtime_count_mgmt']
manager_inbound_realtime_collection = mydb['manager_inbound_realtime_count_mgmt']

#con.events('plain', 'CHANNEL_CREATE')
#con.events('plain', 'CHANNEL_CREATE CHANNEL_EXECUTE CHANNEL_DESTROY CHANNEL_ANSWER CHANNEL_HANGUP')
con.events("plain", "ALL")


while True:
    event = con.recvEvent();
#    print("-----")
    print(event.serialize())
#    print(event.getHeader("Event-Name"))
#    print("-----")
    if event.getHeader("Event-Name") == "CHANNEL_EXECUTE" and event.getHeader("variable_sip_h_X-inbound_campaign_flag") == 'true' and event.getHeader("variable_sip_h_X-Leaduuid") != "" and event.getHeader("variable_sip_h_X-tenant_uuid") != "" and event.getHeader("Application") == 'callcenter':
    	inbound_realtime_uuid = uuid.uuid4()
    	inbound_realtime_uuid = str(inbound_realtime_uuid)
    	lead_uuid = event.getHeader("variable_sip_h_X-Leaduuid")
    	tenant_uuid = event.getHeader("variable_sip_h_X-tenant_uuid")
    	filter = {"lead_uuid":lead_uuid}
    	inbound_realtime_report_data = inbound_report_collection.find_one(filter)
    	if inbound_realtime_report_data == None:
    		inbound_realtime_report_string = {"uuid":inbound_realtime_uuid,"lead_uuid":lead_uuid,"tenant_uuid":tenant_uuid,"type":1}
    		inbound_report_collection.insert_one(inbound_realtime_report_string)
    		print(inbound_realtime_report_string)
    	
    if event.getHeader("Event-Name") == "CHANNEL_CREATE" and event.getHeader("variable_sip_h_X-inbound_campaign_flag") == 'true' and event.getHeader("variable_sip_h_X-Leaduuid") != "" and event.getHeader("variable_sip_h_X-tenant_uuid") != "":
    	inbound_realtime_uuid = uuid.uuid4()
    	inbound_realtime_uuid = str(inbound_realtime_uuid)
    	lead_uuid = event.getHeader("variable_sip_h_X-Leaduuid")
    	tenant_uuid = event.getHeader("variable_sip_h_X-tenant_uuid")
    	filter = {"lead_uuid":lead_uuid}
    	inbound_realtime_report_data = inbound_report_collection.find_one(filter)
    	if inbound_realtime_report_data != None:
    		update = {"$set":{"type":0}}
    		filter = {"lead_uuid":lead_uuid}
    		inbound_report_collection.update_one(filter,update)
    		
    		
    if event.getHeader("Event-Name") == "CUSTOM" and event.getHeader("Event-Subclass") == "X_FER_HANGUP":
    	print("IN KILL X-FER line hangup")
    	#HPprint(event.getHeader("Event-Subclass"))
    	#HPprint(event.getHeader("conference_uuid"))
    	hangup_command = f'uuid_kill {event.getHeader("conference_uuid")}'
    	con.api(hangup_command)
    if event.getHeader("Event-Name") == "CUSTOM" and event.getHeader("Event-Subclass") == "A_LEG_HANGUP":
    	print("IN KILL A_LEG_HANGUP line hangup")
    	#HPprint(event.getHeader("Event-Subclass"))
    	#HPprint(event.getHeader("conference_uuid"))
    	hangup_command = f'uuid_kill {event.getHeader("conference_uuid")}'
    	con.api(hangup_command)
    if ((event.getHeader("Event-Name") == "CHANNEL_EXECUTE"  and event.getHeader("variable_current_application") == 'three_way') or (event.getHeader("Event-Name") == "CALL_UPDATE" and event.getHeader("Other-Leg-Destination-Number") == 'attended_xfer') ):
    	print("IN THREE WAY")
    	command = 'show registrations as json'
    	response = con.api(command)
    	#HPprint(response.getBody())
    	print("------------")
    	parsed_data = json.loads(response.getBody())
    	rows = parsed_data.get("rows", [])
    	#bridge_variable = urllib.parse.unquote(event.getHeader("variable_bridge_channel"))
    	bridge_variable = urllib.parse.unquote(event.getHeader("Other-Leg-Callee-ID-Number"))
    	print("bridge_variable",bridge_variable)
    	print("++++")
    	register_user = ""
    	for row in rows:
    		#HPprint(row.get("url"))
    		#if(word_exists(row.get("url"), bridge_variable)):
    		check_var = event.getHeader("variable_original_destination_number")
    		if event.getHeader("Other-Leg-Direction") == 'inbound':
    			check_var = event.getHeader("Other-Leg-Username")
    		#HPprint("check_var::",check_var)
    		#HPprint("Presence-Call-Direction::",event.getHeader("Presence-Call-Direction"))
    		if(word_exists(row.get("reg_user"), check_var)):
    			register_user = row.get("reg_user")
    			final_string = "sip:"+row.get("reg_user")+"@"+row.get("network_ip")+":"+row.get("network_port")+";transport=wss"
    			print("EXIST::final_string",final_string)
    		else:
    			print("NOT-EXIST")
    	if register_user != "":
    		print("------------")
    		#HPprint(event.serialize())
	    	sip_from_host = event.getHeader("variable_sip_from_host")
    		sip_from_user = event.getHeader("variable_sip_from_user")
    		sip_from_uri = "sip:"+event.getHeader("variable_sip_from_uri")
    		sip_to_uri = event.getHeader("variable_sip_to_uri")
    		profile_name = event.getHeader("variable_sofia_profile_name")
    		x_fer_uuid = event.getHeader("Unique-ID")
    		temp_user = "202"#event.getHeader("Other-Leg-Callee-ID-Number")
    		print("x_fer_uuid:"+x_fer_uuid)
    		a_leg_call_uuid = event.getHeader("variable_sip_h_X-a_leg_call_uuid")
    		print("a_leg_call_uuid:"+a_leg_call_uuid)
    		print(sip_from_host,sip_from_user,sip_from_uri,sip_to_uri,profile_name)
    		event = ESL.ESLevent("SWITCH_EVENT_NOTIFY")
    		event.addHeader("profile", 'external')
    		event.addHeader("from-uri", sip_from_uri)
    		event.addHeader("to-uri", final_string)
    		event.addHeader("user", temp_user)
    		event.addHeader("host", sip_from_host)
    		event.addHeader("X-XFER-UUID", x_fer_uuid)    
    		event.addHeader("extra-headers", "X-XFER-UUID:"+x_fer_uuid+",X-A-LEG-UUID:"+a_leg_call_uuid)
#    		event.addHeader("X-A-LEG-UUID", a_leg_call_uuid)    
#    		event.addHeader("extra-headers", "X-A-LEG-UUID:"+a_leg_call_uuid)
    		serialized_event = event.serialize("xml")
	    	#HPprint("log", "notice [events] {}".format(serialized_event))
	    	result = con.sendEvent(event)
	    	#HPprint("log", "notice [result] {}".format(result))
	  
    if event.getHeader("Event-Name") == "CHANNEL_ORIGINATE" and event.getHeader("variable_sip_h_P-auto_campaign") == 'true':
    	realtime_report_uuid = uuid.uuid4()
    	realtime_report_uuid = str(realtime_report_uuid)
    	#call_uuid = event.getHeader("Channel-Call-UUID")
    	campaign_uuid = event.getHeader("variable_sip_h_P-campaign_uuid")
    	tenant_uuid = event.getHeader("variable_sip_h_P-tenant_uuid")
    	lead_uuid = event.getHeader("variable_sip_h_P-lead_uuid")
    	callstart = event.getHeader("variable_sip_h_P-call_start")
    	filter = {"lead_uuid":lead_uuid}
    	realtime_report_data = realtime_report_collection.find_one(filter)
    	if realtime_report_data == None:
    		if event.getHeader('variable_sip_h_P-manager_uuid') and event.getHeader('variable_sip_h_P-manager_uuid') != '':
    			manager_uuid = event.getHeader('variable_sip_h_P-manager_uuid')
    			realtime_report_insert_string = {"uuid":realtime_report_uuid,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"tenant_uuid":tenant_uuid,"type":3,'manager_uuid':manager_uuid,'created_at':callstart}
    			realtime_report_collection.insert_one(realtime_report_insert_string)
    			print("realtime_report_string MANAGER => ",realtime_report_insert_string)
    		else:
    			realtime_report_insert_string = {"uuid":realtime_report_uuid,"lead_uuid":lead_uuid,"campaign_uuid":campaign_uuid,"tenant_uuid":tenant_uuid,"type":3,'created_at':callstart}
    			realtime_report_collection.insert_one(realtime_report_insert_string)
    			print("realtime_report_string HARSH => ",realtime_report_insert_string)
    	#if event.getHeader('variable_sip_h_P-manager_uuid') and event.getHeader('variable_sip_h_P-manager_uuid') != '':
    	#	manager_realtime_uuid = uuid.uuid4()
    	#	manager_realtime_uuid = str(manager_realtime_uuid)
    	#	manager_uuid = event.getHeader('variable_sip_h_P-manager_uuid')
    	#	filter = {'lead_uuid':lead_uuid}
    	#	manager_realtime_report_data = manager_realtime_collection.find_one(filter)
    	#	if manager_realtime_report_data == None:
    	#		manager_realtime_report_insert_string = {'uuid':manager_realtime_uuid,'lead_uuid':lead_uuid,'campaign_uuid':campaign_uuid,'tenant_uuid':tenant_uuid,'manager_uuid':manager_uuid,'type':3,'created_at':callstart}
    	#		manager_realtime_collection.insert_one(manager_realtime_report_insert_string)
    	#		print("manager_realtime_report insert string => ",manager_realtime_report_insert_string)
    	
    if event.getHeader("Event-Name") == "CHANNEL_PROGRESS" and event.getHeader("variable_sip_h_P-auto_campaign") == 'true':
    	call_uuid = event.getHeader("Channel-Call-UUID")
    	lead_uuid = event.getHeader("variable_sip_h_P-lead_uuid")
    	filter = {"lead_uuid":lead_uuid}
    	realtime_report_data = realtime_report_collection.find_one(filter)
    	if realtime_report_data != None and realtime_report_data['lead_uuid'] != '':
    		update = {"$set":{"type":0}}
    		filter = {"lead_uuid":lead_uuid}
    		realtime_report_collection.update_one(filter,update)
    	#if event.getHeader('variable_sip_h_P-manager_uuid') and event.getHeader('variable_sip_h_P-manager_uuid') != '':
    	#	filter = {'lead_uuid':lead_uuid}
    	#	manager_realtime_report_data = manager_realtime_collection.find_one(filter)
    	#	if manager_realtime_report_data != None and manager_realtime_report_data['lead_uuid'] != '':
    	#		update = {"$set":{"type":0}}
    	#		filter = {"lead_uuid":lead_uuid}
    	#		manager_realtime_collection.update_one(filter,update)        	
    	
    if event.getHeader("Event-Name") == "CHANNEL_ANSWER":
    	#HPprint(event.serialize())
    	if event.getHeader("variable_sip_h_P-auto_campaign") == 'true':
    		auto_campaign_originate = event.getHeader('variable_sip_h_P-auto_campaign_originate')
    		auto_campaign_recording = event.getHeader('variable_custom_recording')
    		destination_number = event.getHeader('Other-Leg-Destination-Number')
    		call_uuid = event.getHeader('variable_uuid')
    		recording_path = event.getHeader('variable_recording_directory')
    		if auto_campaign_originate and auto_campaign_originate != "" and auto_campaign_recording and auto_campaign_recording == '0' and call_uuid and call_uuid != "" and destination_number and destination_number != '' and recording_path and recording_path:
    			#recording_path = '/usr/local/freeswitch/recordings/'
    			recording_command = f'uuid_record {call_uuid} start {recording_path}/{destination_number}_{call_uuid}.wav'
    			#HPprint('recording command',recording_command)
    			con.api(recording_command) 
    			print('adesh this is your condition')
    		if event.getHeader("variable_sip_h_P-amd_status") == 'true':
    			if auto_campaign_originate and auto_campaign_originate != "":
    				print("CAMAPAING FIND RETURE")
    			else:   
    				#print(event.serialize())
    				createtimestr = event.getHeader("Caller-Channel-Created-Time")
    				progressmediatime_str = event.getHeader("Caller-Channel-Progress-Media-Time")
    				progresstime_str = event.getHeader("Caller-Channel-Progress-Time")
    				answertime_str = event.getHeader('Caller-Channel-Answered-Time')
    				createtime = datetime.fromtimestamp(int(createtimestr) / 1000000)
    				answertime = datetime.fromtimestamp(int(answertime_str) / 1000000)
    				progressmediatime = datetime.fromtimestamp(int(progressmediatime_str) / 1000000)
    				progresstime = datetime.fromtimestamp(int(progresstime_str) / 1000000)
    				#HPprint("create time",createtime)
    				#HPprint("answer time",answertime)
    				#HPprint("progrees time",progresstime)
    				#HPprint("progress media time",progressmediatime)
    				if int(progresstime_str) == 0 and int(progressmediatime_str) == 0:
    					print("no media ringing time and ringing")
    					seconds_difference = (answertime - createtime).total_seconds()
    					#HPprint("create",seconds_difference)
    				elif int(progresstime_str) != 0 and int(progressmediatime_str) == 0:
    					print("no media ringing time")
    					seconds_difference = (answertime - progresstime).total_seconds()
    					#HPprint("ringing ", seconds_difference)
    				else:
    					print("media found")
    					seconds_difference = (answertime - progressmediatime).total_seconds()
    					#HPprint("progress seconds difference",seconds_difference)
    				flag = False
    				myArray = [
    						[0.0,1.50],
    						[23.00,24.00],
    						[30.00,31.00]
		 			]
    				for element in myArray:
    					if (seconds_difference > element[0] and seconds_difference < element[1]) or (seconds_difference < 1):
    						#HPprint("hangup element======================", element)
    						flag = True
    						break  # No need to continue checking once the condition is met
    			
    				if flag:
    					print("flag is true")
    					call_uuid = event.getHeader("Channel-Call-UUID")
    					variable_name = "amd_hangup"
    					variable_value = "true"
    					#broadcast_command = f'uuid_broadcast {call_uuid} start /usr/share/freeswitch/scripts/call-queue.wav'
    					#print("broadcast_command ======>",broadcast_command)
    					#con.api(broadcast_command)
    					variable_command = f'uuid_setvar {call_uuid} {variable_name} {variable_value}'
    					#HPprint("variable command ========>",variable_command)
    					con.api(variable_command)
    					#time.sleep(6)
    					#hangup_command = f'uuid_kill {event.getHeader("Unique-ID")} INCOMPATIBLE_DESTINATION'
    					#con.api(hangup_command)
    					#print("hangup commanf ========>",hangup_command)
    					if event.getHeader('variable_sip_h_P-campaign_uuid') != "" and event.getHeader('variable_sip_h_P-user_uuid') != "":
    						print("found the values")
    						filter = {"campaign_uuid": event.getHeader("variable_sip_h_P-campaign_uuid"),"agent_uuid":event.getHeader("variable_sip_h_P-user_uuid")}
    						update = {"$set": {"flag":'0'}}
    						auto_originate_collection.update_one(filter,update)
    				else:
    					print("flag is false")
    	

    		lead_uuid = event.getHeader("variable_sip_h_P-lead_uuid")
    		filter = {"lead_uuid":lead_uuid}
    		realtime_report_data = realtime_report_collection.find_one(filter)
    		api_command = "callcenter_config agent set state "+event.getHeader("variable_sip_h_P-username")+"."+event.getHeader("variable_sip_h_P-tenant_domain")+"@default 'In a queue call'"
    		#api_command = "callcenter_config agent set state "+event.getHeader("variable_sip_h_P-username")+".labtest2.belsmart.io@default 'In a queue call'"
    		con.api(api_command)
    		if realtime_report_data != None and realtime_report_data['lead_uuid'] != "":
    			update = {"$set":{"type":2}}
    			filter = {"lead_uuid":lead_uuid}
    			realtime_report_collection.update_one(filter,update)
    		if event.getHeader('variable_sip_h_P-manager_uuid') and event.getHeader('variable_sip_h_P-manager_uuid') != '':
    			filter = {"lead_uuid":lead_uuid}
    			manager_realtime_report_data = manager_realtime_collection.find_one(filter)
    			if manager_realtime_report_data != None and manager_realtime_report_data['lead_uuid'] != '':
    				update = {"$set":{"type":2}}
    				filter = {"lead_uuid":lead_uuid}
    				manager_realtime_collection.update_one(filter,update)
    	if event.getHeader("variable_sip_h_X-inbound_campaign_flag") == 'true' and event.getHeader("variable_sip_h_X-Leaduuid") != "" and event.getHeader("variable_sip_h_X-tenant_uuid") != "":
    		lead_uuid = event.getHeader("variable_sip_h_X-Leaduuid")
    		tenant_uuid = event.getHeader("variable_sip_h_X-tenant_uuid")
    		filter = {"lead_uuid":lead_uuid}
    		inbound_realtime_report_data = inbound_report_collection.find_one(filter)
    		if inbound_realtime_report_data != None:
    			update = {"$set":{"type":2}}
    			filter = {"lead_uuid":lead_uuid}
    			inbound_report_collection.update_one(filter,update)
    		#else:
    		#	if (int(progresstime_str) == 0):
    		#		seconds_difference = (answertime - createtime).total_seconds()
    		#	else:
    		#		seconds_difference = (answertime - progresstime).total_seconds()
    		#	print("seconds difference",seconds_difference)
    		#	flag = False
    		#	myArray = [
    		#			[0.0,1.50],
		 #	]
    		#	for element in myArray:
    		#		if (seconds_difference > element[0] and seconds_difference < element[1]) or (seconds_difference < 1):
    		#			print("hangup element======================", element)
    		#			flag = True
    		#			break  # No need to continue checking once the condition is met
    		#	
    		#	if flag:
    		#		print("flag is true")
    		#		hangup_command = f'uuid_kill {event.getHeader("Unique-ID")} INCOMPATIBLE_DESTINATION'
    		#		con.api(hangup_command)
    		#		print("hangup commanf ========>",hangup_command)
    		#		if event.getHeader('variable_sip_h_P-campaign_uuid') != "" and event.getHeader('variable_sip_h_P-user_uuid') != "":
    		#			print("found the values")
    		#			filter = {"campaign_uuid": event.getHeader("variable_sip_h_P-campaign_uuid"),"agent_uuid":event.getHeader("variable_sip_h_P-user_uuid")}
    		#			update = {"$set": {"flag":'0'}}
    		#			auto_originate_collection.update_one(filter,update)
    		#	else:
    		#		print("flag is false123")
    					
    #if event.getHeader("Event-Name") == "CHANNEL_DESTROY":
        #if event.getHeader('variable_call_type') == 'local':
            #if event.getHeader("variable_sip_from_user") != '' and event.getHeader("Caller-Destination-Number") != '':
                #api_command = "callcenter_config agent set state "+event.getHeader("variable_sip_from_user")+"."+event.getHeader("variable_domain_name")+"@default 'Waiting'"
                #con.api(api_command)
                #print(api_command)
                #api_command1 = "callcenter_config agent set state "+event.getHeader("Caller-Destination-Number")+"."+event.getHeader("variable_domain_name")+"@default 'Waiting'"
                #con.api(api_command1)
       	      
    if (event.getHeader("Event-Name") == "CHANNEL_DESTROY" or event.getHeader("Event-Name") == "CHANNEL_HANGUP" or event.getHeader("Event-Name") == "CHANNEL_HANGUP_COMPLETE"):
    	if event.getHeader("variable_sip_h_P-auto_campaign") == 'true':
    		#HPprint(event.serialize())
    		auto_campaign_originate = event.getHeader('variable_sip_h_P-auto_campaign_originate')
    		auto_campaign_recording = event.getHeader('variable_custom_recording')
    		destination_number = event.getHeader('Other-Leg-Destination-Number')
    		recording_path = event.getHeader('variable_recording_directory')
    		#auto_campaign_recording = event.getHeader('variable_sip_h_X-auto_campaign_recording')
    		call_uuid = event.getHeader('variable_uuid')
    		if auto_campaign_originate and auto_campaign_originate != '' and auto_campaign_recording and auto_campaign_recording == '0' and destination_number and destination_number != '' and call_uuid and call_uuid != '' and recording_path and recording_path != '':
    			#recording_path = '/usr/local/freeswitch/recordings/'
    			recording_command = f'uuid_record {call_uuid} stop {recording_path}/{destination_number}_{call_uuid}.wav'
    			print('recording command',recording_command)
    			con.api(recording_command) 
    			print('adesh this is your condition')
    		api_command = "callcenter_config agent set state "+event.getHeader("variable_sip_h_P-username")+"."+event.getHeader("variable_sip_h_P-tenant_domain")+"@default 'Idle'"
    		#api_command = "callcenter_config agent set state "+event.getHeader("variable_sip_h_P-username")+".labtest2.belsmart.io@default 'In a queue call'"
    		con.api(api_command)
    		lead_uuid = event.getHeader("variable_sip_h_P-lead_uuid")
    		filter = {"lead_uuid":lead_uuid}
    		realtime_report_data = realtime_report_collection.delete_one(filter)
    		#if event.getHeader('variable_sip_h_P-manager_uuid') and event.getHeader('variable_sip_h_P-manager_uuid') != '':
    		#	filter = {"lead_uuid":lead_uuid}
    		#	manager_realtime_collection.delete_one(filter)
    	if event.getHeader("variable_sip_h_X-inbound_campaign_flag") == 'true' and event.getHeader("variable_sip_h_X-Leaduuid") != "" and event.getHeader("variable_sip_h_X-tenant_uuid") != "":
    		lead_uuid = event.getHeader("variable_sip_h_X-Leaduuid")
    		filter = {"lead_uuid":lead_uuid}
    		inbound_report_collection.delete_one(filter)    	
    if event.getHeader("Event-Name") == "CUSTOM" and event.getHeader("Beep-Status") == "DETECTED":
        #HPprint(event.serialize())
        event.getHeader('Unique-ID')
        if event.getHeader('Unique-ID') != "":
            hangup_command = f'uuid_kill {event.getHeader("Unique-ID")}'
            con.api(hangup_command)
            print("Hangup command sent:", hangup_command)

