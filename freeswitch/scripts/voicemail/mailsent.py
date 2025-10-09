import logging
from logging.handlers import RotatingFileHandler
     
logging.basicConfig(filename='/mnt/py.log',
                    filemode='a',
                    format='%(asctime)s,%(msecs)d %(name)s %(levelname)s %(message)s',
                    datefmt='%H:%M:%S',
                    level=logging.DEBUG)
import sys
logging.info("Running Urban Planning111")
line_print = ""
for line in sys.stdin:
    if 'Exit' == line.rstrip():
        break
    line_print = line_print + line


email = line_print


exploded_list = email.split("\n\n")

mainheader = exploded_list[0];
maincontent = email[len(mainheader):len(email)]

First = "Account: ";
Second = "<br>";

Firstpos = maincontent.find(First)
Secondpos=maincontent.find(Second)


to_account = maincontent[int(Firstpos):int(Secondpos)]
to_account_array = to_account.split(":")
to_account_array = to_account_array[1].strip()
to_account_array = to_account_array.split("@")
to_account_user = to_account_array[0];
to_account_domain = to_account_array[1].strip()
domain_arrays = to_account_domain.split("--")
domain_array = domain_arrays[0].split("\n\n")
final_domain = domain_array[0]
tmparray = mainheader.split("\n")
contenttmp = tmparray[1];
tmparray = contenttmp.split(";")
contenttmp = tmparray[1]
tmparray = contenttmp.split("=")
boundary = tmparray[1];
boundary = boundary.strip('"')

mainheaderarray = mainheader.split("\n")
var = {}
for val in mainheaderarray:
	tmparray = val.split(':')
	if tmparray[0] == 'Subject':
		var[tmparray[0]] = val.replace("Subject:", "")
	else:
		var[tmparray[0]] = tmparray[1].strip()
var['To'] = var['To'].replace("<", "")
var['To'] = var['To'].replace(">", "")
maincontent = maincontent.replace(boundary+"--", boundary)
tmpArray = maincontent.split("--"+boundary)
subboundary = ""
for mimepart in tmpArray:
	array = mimepart.split("\n\n")
	subHeader = array[0].strip();
	mimeHeaderArray = subHeader.split("\n")
	x=0
	for val in mimeHeaderArray:
		result= val.find(":")
		if result != '-1':
			tmparray = val.split("=")
			if tmparray[0].strip() == "boundary":
				subboundary = tmparray[1];
				subboundary = subboundary.strip('"')
		else:
			tmparray = val.split(":")
#		if tmparray[0] and tmparray[0].strip() != '':
#			var[tmparray[0].strip()] = tmparray[1].strip()
	contenttypearray = mimeHeaderArray[0].split(" ")
	if contenttypearray[0] == "Content-Type:":
		contenttype = contenttypearray[1].strip()
		if contenttype == "multipart/alternative;":
			content = mimepart[len(subHeader):len(mimepart)]
			content = content.strip()
			maincontent = content.replace(subboundary+"--", subboundary)
			tmpSubArray = maincontent.split("--"+subboundary)
			for mimesubsubpart in tmpSubArray:
				array = mimesubsubpart.split("\n\n")
				subSubHeader = array[0].strip()
				subSubMimeHeaderArray =  subSubHeader.split("\n")
				subsubcontenttypearray =  subSubMimeHeaderArray[0].split(" ")
				if subsubcontenttypearray[0] == "Content-Type:":
					subsubcontenttype = subsubcontenttypearray[1].strip()
					if subsubcontenttype == "text/plain;":
						textplain = mimesubsubpart[len(subSubHeader)+1:len(mimesubsubpart)]
						textplain = textplain.strip()
					elif subsubcontenttype == "text/html;":
						texthtml = mimesubsubpart[len(subSubHeader):len(mimesubsubpart)]
						texthtml = textplain.strip()
		elif contenttype == "audio/x-wave;":
	 		wav_file_name = 'msg_e7647664-7a34-48b3-839f-8c6db7058f23.wav'
	 		subHeader_explode =  subHeader.split("\n")
	 		subHeader_explode =  subHeader_explode[0].split('name="')
	 		wav_file_name = subHeader_explode[1].replace('"', "")
			#strwav = mimepart[len(subHeader):len(mimepart)]
			#strwav = strwav.strip()
			#print("****")
			#print(strwav)
			#print("****")
			#exit(1)
#			strwav = strwav.strip('"')
#			strwav = strwav.strip('\n')

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.audio import MIMEAudio

# SMTP server configuration
smtp_server = 'smtp.gmail.com'
smtp_port = 587
smtp_username = 'weforyouweb@gmail.com'
smtp_password = 'fpflmbzybycrielq'

# Email content
sender_email = 'weforyouweb@gmail.com'
receiver_email = var['To']
subject = var['Subject']
#attachment_text = strwav

# Create a multipart message
msg = MIMEMultipart()
msg['From'] = sender_email
msg['To'] = receiver_email
msg['Subject'] = subject
msg.attach(MIMEText(textplain, 'plain'))
file_path = '/var/lib/freeswitch/storage/voicemail/default/'+final_domain+'/'+to_account_user+'/'+wav_file_name
file = open(file_path, 'rb')
audio = MIMEAudio(file.read())
file.close()
audio.add_header('Content-Disposition', 'attachment', filename="voicemail.wav")
msg.attach(audio)

#attachment_part = MIMEText(attachment_text)
#attachment_part.add_header(
#    "Content-Disposition",
#    "attachment",
#    filename="voicemail.wav"
#)
#msg.attach(attachment_part)
# Create a MIMEText object for the attachment
#attachment = MIMEText(attachment_text)

# Set the appropriate content type and disposition for the attachment
#attachment.add_header('Content-Disposition', 'attachment', filename='attachment.wav')

# Attach the attachment to the message
#msg.attach(attachment)

# Connect to the SMTP server
with smtplib.SMTP(smtp_server, smtp_port) as server:
    server.starttls()
    server.login(smtp_username, smtp_password)
    server.send_message(msg)

os.unlink(file_path)
