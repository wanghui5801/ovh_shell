import os
import requests
import ovh
import time
from requests.exceptions import RequestException
from ovh.exceptions import APIError, NetworkError
from datetime import datetime

# Get BOT_TOKEN and CHAT_ID from environment variables
BOT_TOKEN = os.environ.get("BOT_TOKEN")
CHAT_ID = os.environ.get("CHAT_ID")

# Check if required environment variables are set
if not BOT_TOKEN or not CHAT_ID:
    print("Error: BOT_TOKEN or CHAT_ID environment variables not set.")
    exit(1)

# Get OVH API credentials from environment variables
OVH_ENDPOINT = os.environ.get("OVH_ENDPOINT", "ovh-eu")
OVH_APPLICATION_KEY = os.environ.get("OVH_APPLICATION_KEY")
OVH_APPLICATION_SECRET = os.environ.get("OVH_APPLICATION_SECRET")
OVH_CONSUMER_KEY = os.environ.get("OVH_CONSUMER_KEY")

# Check if OVH API credentials are complete
if not OVH_APPLICATION_KEY or not OVH_APPLICATION_SECRET or not OVH_CONSUMER_KEY:
    print("Error: OVH API credentials are not fully set.")
    exit(1)

# Initialize client
client = ovh.Client(
    endpoint=OVH_ENDPOINT,
    application_key=OVH_APPLICATION_KEY,
    application_secret=OVH_APPLICATION_SECRET,
    consumer_key=OVH_CONSUMER_KEY,
)

# Function: Retry network requests
def retry_request(func, *args, max_retries=5, **kwargs):
    retries = 0
    max_retries = int(max_retries)  # Ensure max_retries is an integer
    while retries < max_retries:
        try:
            return func(*args, **kwargs)
        except (APIError, NetworkError, RequestException) as e:
            retries += 1
            print(f"Request failed: '{e}', retrying... ({retries}/{max_retries})")
            time.sleep(2)  # Wait 2 seconds before retrying
        except Exception as e:
            print(f"Unexpected error: {e}")
            return None
    print("Max retries reached. Request failed.")
    return None

# Function: Send error message to Telegram
def send_telegram_error(message):
    try:
        url = f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage'
        data = {
            'chat_id': CHAT_ID,
            'text': f"Error occurred: {message}"
        }
        response = requests.post(url, data=data)
        if response.status_code == 200:
            print("Error message sent successfully.")
        else:
            print("Failed to send error message:", response.status_code, response.text)
    except Exception as e:
        print(f"Failed to send error message via Telegram: {e}")

# Infinite loop until order is complete
while True:
    try:
        # Get subsidiary information
        subsidiary = retry_request(client.get, "/me")
        if subsidiary is None:
            continue
        subsidiary = subsidiary.get("ovhSubsidiary")

        # Get availability information
        ava = retry_request(client.get, "/dedicated/server/datacenter/availabilities", datacenters="bhs", planCode="24ska01")
        if ava is None or len(ava) == 0:
            continue

        # Check availability
        if ava[0]['datacenters'][0]['availability'] != 'unavailable':
            # First message: KSA is available
            message = "KSA is available"
            url = f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage'
            data = {
                'chat_id': CHAT_ID,
                'text': message
            }
            response = retry_request(requests.post, url, data=data)

            # Check send result
            if response and response.status_code == 200:
                print("Message 1 sent successfully.")
            else:
                print("Failed to send message 1.")
                continue

            # Create shopping cart and add items
            cart = retry_request(client.post, "/order/cart", ovhSubsidiary=subsidiary, _need_auth=False)
            if cart is None:
                continue

            retry_request(client.post, f"/order/cart/{cart.get('cartId')}/assign")

            item = retry_request(client.post, f"/order/cart/{cart.get('cartId')}/eco",
                                 planCode="24ska01", duration="P1M", pricingMode="default", quantity=1)
            if item is None:
                continue

            retry_request(client.post, f"/order/cart/{cart.get('cartId')}/eco/options",
                          pricingMode="default", quantity=1, duration="P1M", itemId=item.get("itemId"),
                          planCode="ram-64g-noecc-2133-24ska01")
            retry_request(client.post, f"/order/cart/{cart.get('cartId')}/eco/options",
                          pricingMode="default", quantity=1, duration="P1M", itemId=item.get("itemId"),
                          planCode="softraid-1x480ssd-24ska01")

            retry_request(client.post, f"/order/cart/{cart.get('cartId')}/item/{item.get('itemId')}/configuration",
                          label="dedicated_datacenter", value="bhs")
            retry_request(client.post, f"/order/cart/{cart.get('cartId')}/item/{item.get('itemId')}/configuration",
                          label="dedicated_os", value="none_64.en")

            # Checkout and get order
            quotation = retry_request(client.get, f"/order/cart/{cart.get('cartId')}/checkout")
            salesorder = retry_request(client.post, f"/order/cart/{cart.get('cartId')}/checkout")
            if salesorder is None:
                continue

            # Second message: Order information
            message2 = u"Order #{0} ({1}) has been generated : {2}".format(
                salesorder["orderId"],
                salesorder["prices"]["withTax"]["text"],
                salesorder["url"]
            )

            data2 = {
                'chat_id': CHAT_ID,
                'text': message2
            }

            response2 = retry_request(requests.post, url, data=data2)

            # Check send result
            if response2 and response2.status_code == 200:
                print("Message 2 sent successfully.")
                break  # Order sent successfully, stop loop
            else:
                print("Failed to send message 2.")

        else:
            # When availability is 'unavailable', print message
            print("KSA is not available")

    except Exception as e:
        error_message = str(e)
        print(f"An error occurred: {error_message}")
        # Send error message to Telegram
        send_telegram_error(error_message)
        break  # Stop loop on unrecoverable error

    # Wait 2 minutes before retrying to avoid frequent requests
    time.sleep(2)
