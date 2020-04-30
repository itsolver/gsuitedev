import requests, json
 
# START import secrets into variables
import os
from dotenv import load_dotenv
load_dotenv()

prism_client_id = os.getenv("PRISM_CLIENT_ID")
prism_client_secret = os.getenv("PRISM_CLIENT_SECRET")
# END import secrets into variables

def get_access_token(): # Request an access token
  headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
  }

  data = {
    'grant_type': 'client_credentials',
    'client_id': prism_client_id,
    'client_secret': prism_client_secret,
    'scope': 'rhipeapi'
  }
  r = requests.post('https://identity.prismportal.online/core/connect/token', headers=headers, data=data)
  return json.loads(r.content)['access_token']

prism_access_token = get_access_token()

auth_headers = {
  'Authorization': 'Bearer ' + prism_access_token,
  'Accept' : 'application/json', 
  'Content-Type' : 'application/json'
}

payload = open('prismportal-customers-create.json', 'rb').read()

new_customer = requests.post('https://api.prismportal.online/api/v2/customers', headers=auth_headers, data=payload).text

print(new_customer)