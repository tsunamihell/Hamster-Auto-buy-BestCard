#!/bin/bash

# رنگ‌ها
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
purple='\033[0;35m'
cyan='\033[0;36m'
blue='\033[0;34m'
rest='\033[0m'

# اگر در Termux اجرا شود، بروزرسانی و ارتقا انجام می‌دهد
if [ -d "$HOME/.termux" ] && [ -z "$(command -v jq)" ]; then
    echo "در حال بروزرسانی و ارتقا ..."
    pkg update -y
    pkg upgrade -y
fi

# تابع نصب بسته‌های ضروری
install_packages() {
    local packages=(curl jq bc)
    local missing_packages=()

    # بررسی بسته‌های موجود
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # نصب بسته‌های گمشده در صورت وجود
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
            echo -e "${yellow}مدیریت بسته پشتیبانی نمی‌شود. لطفا بسته‌های مورد نیاز را به صورت دستی نصب کنید.${rest}"
        fi
    fi
}

# نصب بسته‌های ضروری
install_packages

# پاکسازی صفحه
clear

# درخواست مجوز
echo -e "${purple}=======${yellow}Hamster Combat Auto Buy best cards${purple}=======${rest}"
echo ""
echo -en "${green}مجوز خود را وارد کنید [${cyan}مثال: ${yellow}Bearer 171852....${green}]: ${rest}"
read -r Authorization
echo -e "${purple}============================${rest}"

# درخواست حداقل موجودی
echo -en "${green}حداقل میزان موجودی را وارد کنید (${yellow}اسکریپت در صورتی که موجودی کمتر از این مقدار باشد خرید را متوقف خواهد کرد${green}):${rest} "
read -r min_balance_threshold

# تابع خرید ارتقا
purchase_upgrade() {
    upgrade_id="$1"
    timestamp=$(date +%s%3N)
    response=$(curl -s -X POST \
      -H "Content-Type: application/json" \
      -H "Authorization: $Authorization" \
      -H "Origin: https://hamsterkombat.io" \
      -H "Referer: https://hamsterkombat.io/" \
      -d "{\"upgradeId\": \"$upgrade_id\", \"timestamp\": $timestamp}" \
      https://api.hamsterkombat.io/clicker/buy-upgrade)
    echo "$response"
}

# تابع برای دریافت بهترین آیتم ارتقا با سود مناسب
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
        https://api.hamsterkombat.io/clicker/upgrades-for-buy | jq -r '
        .upgradesForBuy | 
        map(select(.isExpired == false and .isAvailable)) | 
        map(select(.profitPerHourDelta != 0 and .price != 0 and (.profitPerHourDelta / .price) >= 0.001)) | 
        sort_by(-(.profitPerHourDelta / .price))[:1] | 
        .[0] | 
        {id: .id, section: .section, price: .price, profitPerHourDelta: .profitPerHourDelta, cooldownSeconds: .cooldownSeconds}'
}

# تابع انتظار برای دوره خنک‌شدن با شمارش معکوس
wait_for_cooldown() {
    cooldown_seconds="$1"
    echo -e "${yellow}ارتقا در دوره خنک‌شدن است. منتظر دوره خنک‌شدن به مدت ${cyan}$cooldown_seconds${yellow} ثانیه...${rest}"
    while [ $cooldown_seconds -gt 0 ]; do
        echo -ne "${cyan}$cooldown_seconds\033[0K\r"
        sleep 1
        ((cooldown_seconds--))
    done
}

# منطق اصلی اسکریپت
main() {
    while true; do
        # دریافت بهترین آیتم برای خرید
        best_item=$(get_best_item)
        best_item_id=$(echo "$best_item" | jq -r '.id')
        section=$(echo "$best_item" | jq -r '.section')
        price=$(echo "$best_item" | jq -r '.price')
        profit=$(echo "$best_item" | jq -r '.profitPerHourDelta')
        cooldown=$(echo "$best_item" | jq -r '.cooldownSeconds')

        echo -e "${purple}============================${rest}"
        echo -e "${green}بهترین آیتم برای خرید:${yellow} $best_item_id ${green}در بخش:${yellow} $section${rest}"
        echo -e "${blue}قیمت: ${cyan}$price${rest}"
        echo -e "${blue}سود در ساعت: ${cyan}$profit${rest}"
        echo ""

        # دریافت موجودی فعلی
        current_balance=$(curl -s -X POST \
            -H "Authorization: $Authorization" \
            -H "Origin: https://hamsterkombat.io" \
            -H "Referer: https://hamsterkombat.io/" \
            https://api.hamsterkombat.io/clicker/sync | jq -r '.clickerUser.balanceCoins')

        # بررسی اگر موجودی فعلی بعد از خرید بالاتر از حداقل موجودی باشد
        if (( $(echo "$current_balance - $price > $min_balance_threshold" | bc -l) )); then
            # تلاش برای خرید بهترین آیتم ارتقا
            if [ -n "$best_item_id" ]; then
                echo -e "${green}تلاش برای خرید ارتقا '${yellow}$best_item_id${green}'...${rest}"
                echo ""

                purchase_status=$(purchase_upgrade "$best_item_id")

                if echo "$purchase_status" | grep -q "error_code"; then
                    wait_for_cooldown "$cooldown"
                else
                    purchase_time=$(date +"%Y-%m-%d %H:%M:%S")
                    total_spent=$(echo "$total_spent + $price" | bc)
                    total_profit=$(echo "$total_profit + $profit" | bc)
                    current_balance=$(echo "$current_balance - $price" | bc)

                    echo -e "${green}ارتقا ${yellow}'$best_item_id'${green} با موفقیت در ${cyan}$purchase_time${green} خریداری شد.${rest}"
                    echo -e "${green}کل هزینه تا کنون: ${cyan}$total_spent${green} سکه.${rest}"
                    echo -e "${green}کل سود افزوده شده: ${cyan}$total_profit${green} سکه در ساعت.${rest}"
                    echo -e "${green}موجودی فعلی: ${cyan}$current_balance${green} سکه.${rest}"
                    
                    sleep_duration=$((RANDOM % 8 + 5))
                    echo -e "${green}منتظر ${yellow}$sleep_duration${green} ثانیه قبل از خرید بعدی...${rest}"
                    while [ $sleep_duration -gt 0 ]; do
                        echo -ne "${cyan}$sleep_duration\033[0K\r"
                        sleep 1
                        ((sleep_duration--))
                    done
                fi
            else
                echo -e "${red}آیتم معتبر برای خرید یافت نشد.${rest}"
                break
            fi
        else
            echo -e "${red}موجودی فعلی ${cyan}(${current_balance}) ${red}منهای قیمت آیتم ${cyan}(${price}) ${red}کمتر از حداقل موجودی ${cyan}(${min_balance_threshold})${red} است. خرید متوقف شد.${rest}"
            break
        fi
    done
}

# اجرای تابع اصلی
main
