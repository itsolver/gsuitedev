import stripe
try:
    import simplejson as json
except ImportError:
    import json

# START import secrets into variables
import os
from dotenv import load_dotenv
load_dotenv()

stripe.api_key = os.getenv("STRIPE_API_KEY")
subscription_id = os.getenv("SUBSCRIPTION_ID")
# END import secrets into variables

managed_products = ['g-suite-business', 'g-suite-basic', 'g-suite-support-premium', 'g-suite-support-standard']

# TAB subscription
subscription = stripe.Subscription.retrieve(subscription_id)
# Test subscription
# subscription = stripe.Subscription.retrieve("sub_GOYvrswLOW34n2")
#print(subscription)
if 'items' in subscription:
    if 'data' in subscription['items']:
        print("Iterating subscription data")
        for items_data in subscription['items']['data']:
            if items_data['plan']['product'] in managed_products:
                current_quantity = items_data['quantity']
                print("Current subscription:", items_data['plan']['id'], current_quantity)
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
  "si_GOXT7HBES7O38Z",
  quantity=new_quantity,
)
stripe.SubscriptionItem.modify(
  "si_GUiXFFL364Tpv7",
  quantity=new_quantity,
)

# TAB subscription
subscription = stripe.Subscription.retrieve(subscription_id)
# Test subscription
# subscription = stripe.Subscription.retrieve("sub_GOYvrswLOW34n2")
#print(subscription)
if 'items' in subscription:
    if 'data' in subscription['items']:
        print("Iterating subscription data")
        for items_data in subscription['items']['data']:
            if items_data['plan']['product'] in managed_products:
                current_quantity = items_data['quantity']
                print("Subscription updated:", items_data['plan']['id'], current_quantity)
            else:
                print("found another product")