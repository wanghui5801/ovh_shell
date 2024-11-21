import os
import requests
import ovh
import time
from requests.exceptions import RequestException
from ovh.exceptions import APIError, NetworkError
from datetime import datetime

# 从环境变量中获取 BOT_TOKEN 和 CHAT_ID
BOT_TOKEN = os.environ.get("BOT_TOKEN")
CHAT_ID = os.environ.get("CHAT_ID")

# 检查是否获取到了必要的环境变量
if not BOT_TOKEN or not CHAT_ID:
    print("Error: BOT_TOKEN or CHAT_ID environment variables not set.")
    exit(1)

# 从环境变量中获取 OVH API 凭据
OVH_ENDPOINT = os.environ.get("OVH_ENDPOINT", "ovh-eu")
OVH_APPLICATION_KEY = os.environ.get("OVH_APPLICATION_KEY")
OVH_APPLICATION_SECRET = os.environ.get("OVH_APPLICATION_SECRET")
OVH_CONSUMER_KEY = os.environ.get("OVH_CONSUMER_KEY")

# 检查 OVH API 凭据是否完整
if not OVH_APPLICATION_KEY or not OVH_APPLICATION_SECRET or not OVH_CONSUMER_KEY:
    print("Error: OVH API credentials are not fully set.")
    exit(1)

# 实例化客户端
client = ovh.Client(
    endpoint=OVH_ENDPOINT,
    application_key=OVH_APPLICATION_KEY,
    application_secret=OVH_APPLICATION_SECRET,
    consumer_key=OVH_CONSUMER_KEY,
)

# 函数：重试网络请求
def retry_request(func, *args, max_retries=5, **kwargs):
    retries = 0
    max_retries = int(max_retries)
    while retries < max_retries:
        try:
            return func(*args, **kwargs)
        except (APIError, NetworkError, RequestException) as e:
            retries += 1
            print(f"Request failed: '{e}', retrying... ({retries}/{max_retries})")
            if retries == max_retries:
                send_telegram_error(f"Maximum retries reached for request: {func.__name__}")
            time.sleep(min(2 * retries, 10))  # 指数退避，最大等待10秒
        except Exception as e:
            print(f"Unexpected error: {e}")
            send_telegram_error(f"Unexpected error in {func.__name__}: {str(e)}")
            return None
    print("Max retries reached. Request failed.")
    return None

# 函数：发送错误消息到 Telegram
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

# 修改打印函数
def log_message(message):
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")

# 无限循环，直到订单完成
while True:
    try:
        # 获取 subsidiary 信息
        subsidiary = retry_request(client.get, "/me")
        if subsidiary is None:
            continue
        subsidiary = subsidiary.get("ovhSubsidiary")

        # 获取 availability 信息
        ava = retry_request(client.get, "/dedicated/server/datacenter/availabilities", datacenters="bhs", planCode="24ska01")
        if not ava:
            time.sleep(2)
            continue
            
        availability_status = ava[0]['datacenters'][0]['availability']
        log_message(f"Current availability status: {availability_status}")

        if availability_status != 'unavailable':
            # 第一条消息：KSA is available
            message = "KSA is available"
            url = f'https://api.telegram.org/bot{BOT_TOKEN}/sendMessage'
            data = {
                'chat_id': CHAT_ID,
                'text': message
            }
            response = retry_request(requests.post, url, data=data)

            # 检查发送结果
            if response and response.status_code == 200:
                print("Message 1 sent successfully.")
            else:
                print("Failed to send message 1.")
                continue

            # 创建购物车并添加项目
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

            # 结账并获取订单
            quotation = retry_request(client.get, f"/order/cart/{cart.get('cartId')}/checkout")
            salesorder = retry_request(client.post, f"/order/cart/{cart.get('cartId')}/checkout")
            if salesorder is None:
                continue

            # 第二条消息：订单信息
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

            # 检查发送结果
            if response2 and response2.status_code == 200:
                print("Message 2 sent successfully.")
                break  # 订单成功发送，停止循环
            else:
                print("Failed to send message 2.")

        else:
            # 当 availability 为 'unavailable' 时，打印消息
            print("KSA is not available")

    except Exception as e:
        error_message = str(e)
        print(f"Critical error occurred: {error_message}")
        send_telegram_error(f"Critical error: {error_message}")
        time.sleep(30)  # 发生严重错误时等待更长时间
        continue  # 使用 continue 而不是 break，保持脚本运行

    # 根据可用性状态动态调整查询间隔
    if availability_status == 'unavailable':
        time.sleep(3)  # 不可用时等待5秒
    else:
        time.sleep(2)  # 可用时快速轮询
