import time
from requests import post

# Colors for terminal output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[0;33m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    BLUE = '\033[0;34m'
    RESET = '\033[0m'

# Function to wait for cooldown period
def wait_for_cooldown(cooldown_seconds):
    print(f"{Colors.YELLOW}ارتقاء در حالت انتظار است. انتظار برای {Colors.CYAN}{cooldown_seconds}{Colors.YELLOW} ثانیه...{Colors.RESET}")
    time.sleep(cooldown_seconds)

# Function to wait for balance to increase
def wait_for_balance(min_balance_threshold, headers, url):
    print(f"{Colors.YELLOW}موجودی کمتر از حداقل موجودی است. انتظار برای افزایش موجودی...{Colors.RESET}")
    while True:
        response = post(url, headers=headers)
        current_balance = float(response.json()['clickerUser']['balanceCoins'])
        print(f"{Colors.GREEN}موجودی فعلی: {Colors.CYAN}{current_balance}{Colors.RESET}")
        if current_balance > min_balance_threshold:
            return current_balance
        time.sleep(60)  # Check balance every 60 seconds

authorization = input(f"{Colors.GREEN}لطفا مجوز را وارد کنید [{Colors.CYAN}مثال: {Colors.YELLOW}Bearer 171852....{Colors.GREEN}]: {Colors.RESET}")
print(f"{Colors.PURPLE}============================{Colors.RESET}")

# Prompt for minimum balance threshold
min_balance_threshold = float(input(f"{Colors.GREEN}لطفا حداقل موجودی را وارد کنید ({Colors.YELLOW}اسکریپت در صورت کمتر بودن موجودی از این مقدار خریدها را متوقف می‌کند{Colors.GREEN}):{Colors.RESET} "))

print(f"{Colors.PURPLE}============================{Colors.RESET}")

# Function to purchase upgrade
def purchase_upgrade(authorization, upgrade_id):
    timestamp = int(time.time() * 1000)
    url = "https://api.hamsterkombat.io/clicker/buy-upgrade"
    headers = {
        "Content-Type": "application/json",
        "Authorization": authorization,
        "Origin": "https://hamsterkombat.io",
        "Referer": "https://hamsterkombat.io/"
    }
    data = {
        "upgradeId": upgrade_id,
        "timestamp": timestamp
    }
    response = post(url, headers=headers, json=data)
    return response.json()

# Headers for requests
headers = {
    'User-Agent': 'Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0',
    'Accept': '*/*',
    'Accept-Language': 'en-US,en;q=0.5',
    'Referer': 'https://hamsterkombat.io/',
    'Authorization': authorization,
    'Origin': 'https://hamsterkombat.io',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-site',
    'Priority': 'u=4',
}

# Get available upgrades
response = post('https://api.hamsterkombat.io/clicker/upgrades-for-buy', headers=headers).json()

upgrades = [
    item for item in response["upgradesForBuy"]
    if not item["isExpired"] and item["isAvailable"] and item["price"] > 0
]

# Get current balance
url = "https://api.hamsterkombat.io/clicker/sync"
response = post(url, headers=headers)
current_balance = float(response.json()['clickerUser']['balanceCoins'])

# Selecting the best upgrade based on profit and price
best_upgrade = max(upgrades, key=lambda x: x["profitPerHourDelta"] / x["price"])
best_upgrade_id = best_upgrade['id']
best_upgrade_section = best_upgrade['section']
best_upgrade_price = best_upgrade['price']
best_upgrade_profit = best_upgrade['profitPerHourDelta']

print(f"{Colors.PURPLE}============================{Colors.RESET}")
print(f"{Colors.GREEN}بهترین آیتم برای خرید: {Colors.YELLOW}{best_upgrade_id}{Colors.GREEN} در بخش: {Colors.YELLOW}{best_upgrade_section}{Colors.RESET}")
print(f"{Colors.BLUE}قیمت: {Colors.CYAN}{best_upgrade_price}{Colors.RESET}")
print(f"{Colors.BLUE}سود در ساعت: {Colors.CYAN}{best_upgrade_profit}{Colors.RESET}")

# Main loop to ensure we wait for enough balance
while True:
    if current_balance - best_upgrade_price > min_balance_threshold:
        print(f"{Colors.GREEN}تلاش برای خرید ارتقاء '{Colors.YELLOW}{best_upgrade_id}{Colors.GREEN}'...{Colors.RESET}")
        purchase_status = purchase_upgrade(authorization, best_upgrade_id)
        
        if 'error_code' in purchase_status:
            cooldown_seconds = best_upgrade.get('cooldownSeconds', 0)
            wait_for_cooldown(cooldown_seconds)
        else:
            print(f"{Colors.GREEN}ارتقاء '{Colors.YELLOW}{best_upgrade_id}{Colors.GREEN}' با موفقیت خریداری شد.{Colors.RESET}")
            break
    else:
        print(f"{Colors.RED}موجودی فعلی ({current_balance}) منهای قیمت آیتم ({best_upgrade_price}) کمتر از آستانه ({min_balance_threshold}) است. انتظار برای افزایش موجودی...{Colors.RESET}")
        current_balance = wait_for_balance(min_balance_threshold, headers, url)
