import requests
import simplejson as json

url = "https://hook.eu1.make.com/rrcunnlep3j7lfsukd6v41qi29p47axs"
data = {'description': 'incoming calls notification from Belsmart', 'caller_name': 'id1', 'caller_number': 'Something1', 'did': '123123', 'date': 'Subtitle', 'duration': '30','call_status':'Success','answered_call':'11231231'}
headers = {'Content-type': 'application/json'}
r = requests.post(url, data=json.dumps(data), headers=headers)
print(r)
