import stripe
try:
    import simplejson as json
except ImportError:
    import json

# START import secrets into variables
import os
from dotenv import load_dotenv
BASE_DIR = os.path.abspath(os.path.dirname(__file__))
load_dotenv(dotenv_path=os.path.join(BASE_DIR, ".env"))

stripe.api_key = str(os.getenv("STRIPE_API_KEY"))
subscription_id = str(os.getenv("SUBSCRIPTION_ID"))
# END import secrets into variables

managed_products = ['g-suite-business', 'g-suite-basic',
                    'g-suite-support-premium', 'g-suite-support-standard', 'plan_HBd3WvBJgURtuX']

# TAB subscription
subscription = stripe.Subscription.retrieve(subscription_id)
# Test subscription
# subscription = stripe.Subscription.retrieve("sub_GOYvrswLOW34n2")
if 'items' in subscription:
    if 'data' in subscription['items']:
        print("Iterating subscription data")
        for items_data in subscription['items']['data']:
            if items_data['plan']['product'] in managed_products:
                current_quantity = items_data['quantity']
                print("Current subscription:",
                      items_data['plan']['id'], current_quantity)
            else:
                print("found another product")

new_quantity = current_quantity + 1

# Test subscription
# stripe.SubscriptionItem.modify(
#   "si_GOYvOEtE8otRM6",
#   quantity=new_quantity,
# )
# stripe.SubscriptionItem.modify(
#   "si_GOYygLNHq7ZErJ",
#   quantity=new_quantity,
# )
# TAB subscription
stripe.SubscriptionItem.modify(
    "si_HtR12uRXcZGjMs",
    quantity=new_quantity,
)
stripe.SubscriptionItem.modify(
    "si_HHt2geladICiD3",
    quantity=new_quantity,
)

# TAB subscription
subscription = stripe.Subscription.retrieve(subscription_id)
# Test subscription
# subscription = stripe.Subscription.retrieve("sub_GOYvrswLOW34n2")
if 'items' in subscription:
    if 'data' in subscription['items']:
        print("Iterating subscription data")
        for items_data in subscription['items']['data']:
            if items_data['plan']['product'] in managed_products:
                current_quantity = items_data['quantity']
                print("Subscription updated:",
                      items_data['plan']['id'], current_quantity)
            else:
                print("found another product")
