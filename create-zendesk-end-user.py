from zenpy import Zenpy
from zenpy.lib.api_objects import User


# START import secrets into variables
import os
from dotenv import load_dotenv
load_dotenv()

zendesk_subdomain = os.getenv("ZENDESK_SUBDOMAIN")
zendesk_oauth_token = os.getenv("ZENDESK_OAUTH_TOKEN")
# END import secrets into variables

# Variables
full_name = "Leigh Risbey"
email_address = "leigh.risbey@thealternativeboard.com.au"
organization_id = "360016690895"
# An OAuth token
creds = {
  "subdomain": zendesk_subdomain,
  "oauth_token": zendesk_oauth_token
}

# Create a Zenpy instance
zenpy_client = Zenpy(**creds)

user = User (name=full_name, email=email_address, organization_id=organization_id)
created_user = zenpy_client.users.create(user)
