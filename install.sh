#!/bin/bash

# تعریف رنگ‌ها برای خروجی
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# اگر در Termux اجرا می‌شود، بروزرسانی و ارتقاء بسته‌ها
if [ -d "$HOME/.termux" ] && [ -z "$(command -v jq)" ]; then
    echo "در حال بروزرسانی و ارتقاء..."
    pkg update -y
    pkg upgrade -y
fi

# تابع برای نصب بسته‌های مورد نیاز
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    # بررسی بسته‌های مفقود
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # نصب بسته‌های مفقود
    if [ ${#missing_packages[@]} -gt 0 ]; then
        if [ -n "$(command -v pkg)" ]; then
            pkg install "${missing_packages[@]}" -y
        elif [ -n "$(command -v apt)" ]; then
            sudo apt update -y
            sudo apt install "${missing_packages[@]}" -y
        elif [ -n "$(command -v yum)" ]; then
            sudo yum update -y
            sudo yum install "${missing_packages[@]}" -y
        elif [ -n "$(command -v dnf)" ]; then
            sudo dnf update -y
            sudo dnf install "${missing_packages[@]}" -y
        else
            echo -e "${yellow}مدیریت بسته‌های پشتیبانی نشده. لطفاً بسته‌های مورد نیاز را به صورت دستی نصب کنید.${rest}"
        fi
    fi
}

# نصب بسته‌های مورد نیاز
install_packages

# پاک کردن صفحه
clear

# درخواست برای مجوز
echo -e "${purple}=======${yellow} خرید خودکار بهترین کارت‌های Hamster Combat ${purple}=======${rest}"
echo ""
echo -en "${green}ورود مجوز [${cyan}مثال: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# درخواست برای حداقل موجودی
echo -en "${green}ورود حداقل میزان موجودی (${yellow}اسکریپت در صورت پایین بودن موجودی از این مقدار، خرید را متوقف می‌کند${green}):${rest} "
read -r min_balance_threshold

# تابع برای خرید ارتقاء
purchase_upgrade() {
    local upgrade_id="$1"
    local timestamp=$(date +%s%3N)
    local response=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: $Authorization" \
      -H "Origin: https://hamsterkombat.io" \
      -H "Referer: https://hamsterkombat.io/" \
      -d "{\"upgradeId\": \"$upgrade_id\", \"timestamp\": $timestamp}" \
      https://api.hamsterkombat.io/clicker/buy-upgrade)
    echo "$response"
}

# تابع برای دریافت بهترین آیتم ارتقاء
get_best_item() {
    curl -s -X POST -H "User-Agent: Mozilla/5.0 (Android 12; Mobile; rv:102.0) Gecko/102.0 Firefox/102.0" \
        -H "Accept: */*" \
        -H "Accept-Language: en-US,en;q=0.5" \
        -H "Referer: https://hamsterkombat.io/" \
        -H "Authorization: $Authorization" \
        -H "Origin: https://hamsterkombat.io" \
        -H "Connection: keep-alive" \
        -H "Sec-Fetch-Dest: empty" \
        -H "Sec-Fetch-Mode: cors" \
        -H "Sec-Fetch-Site: same-site" \
        -H "Priority: u=4" \
        https://api.hamsterkombat.io/clicker/upgrades-for-buy | jq -r \
        '.upgradesForBuy | map(select(.isExpired == false and .isAvailable)) | 
        map(select(.profitPerHourDelta != 0 and .price != 0)) | 
        sort_by(-(.profitPerHourDelta / .price))[:1] | .[0] | 
        {id: .id, section: .section, price: .price, profitPerHourDelta: .profitPerHourDelta, cooldownSeconds: .cooldownSeconds}'
}

# تابع برای انتظار دوره سرد شدن
wait_for_cooldown() {
    local cooldown_seconds="$1"
    echo -e "${yellow}ارتقاء در دوره سرد شدن است. انتظار برای دوره سرد شدن به مدت ${cyan}$cooldown_seconds${yellow} ثانیه...${rest}"
    sleep "$cooldown_seconds"
}

# منطق اصلی اسکریپت
main() {
    while true; do
        # دریافت بهترین آیتم برای خرید
        local best_item
        best_item=$(get_best_item)
        local best_item_id
        best_item_id=$(echo "$best_item" | jq -r '.id')
        local section
        section=$(echo "$best_item" | jq -r '.section')
        local price
        price=$(echo "$best_item" | jq -r '.price')
        local profit
        profit=$(echo "$best_item" | jq -r '.profitPerHourDelta')
        local cooldown
        cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')

        echo -e "${purple}============================${rest}"
        echo -e "${green}بهترین آیتم برای خرید:${yellow} $best_item_id ${green}در بخش:${yellow} $section${rest}"
        echo -e "${blue}قیمت: ${cyan}$price${rest}"
        echo -e "${blue}سود در ساعت: ${cyan}$profit${rest}"
        echo ""

        # دریافت موجودی فعلی
        local current_balance
        current_balance=$(curl -s -X POST \
            -H "Authorization: $Authorization" \
            -H "Origin: https://hamsterkombat.io" \
            -H "Referer: https://hamsterkombat.io/" \
            https://api.hamsterkombat.io/clicker/sync | jq -r '.clickerUser.balanceCoins')

        # بررسی اگر موجودی فعلی بعد از خرید بالاتر از آستانه است
        if (( $(echo "$current_balance - $price > $min_balance_threshold" | bc -l) )); then
            # تلاش برای خرید بهترین آیتم ارتقاء
            if [ -n "$best_item_id" ]; then
                echo -e "${green}تلاش برای خرید ارتقاء '${yellow}$best_item_id${green}'...${rest}"
                echo ""

                local purchase_status
                purchase_status=$(purchase_upgrade "$best_item_id")

                if echo "$purchase_status" | grep -q "error_code"; then
                    wait_for_cooldown "$cooldown"
                else
                    echo -e "${green}ارتقاء ${yellow}'$best_item_id'${green} با موفقیت خریداری شد.${rest}"
                    local sleep_duration
                    sleep_duration=$((RANDOM % 8 + 5))
                    echo -e "${green}انتظار برای ${yellow}$sleep_duration${green} ثانیه قبل از خرید بعدی...${rest}"
                    sleep "$sleep_duration"
                fi
            else
                echo -e "${red}آیتم معتبری برای خرید یافت نشد.${rest}"
                break
            fi
        else
            echo -e "${red}موجودی فعلی ${cyan}(${current_balance}) ${red}کمتر از قیمت آیتم ${cyan}(${price}) ${red}و آستانه ${cyan}(${min_balance_threshold})${red} است. خریدها متوقف می‌شوند.${rest}"
            break
        fi
    done
}

# اجرای تابع اصلی
main
