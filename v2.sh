#!/bin/bash
apt update
sudo apt install iptables -y

6to4_ipv6() {
    clear
    prepration_ipv6
    echo ""
    echo -e "       ${MAGENTA}Setting up 6to4 IPv6 addresses...${NC}"

    echo -ne "${YELLOW}Enter the IPv4 address${NC}   "
    read ipv4
    ipv6_address=$(printf "2002:%02x%02x:%02x%02x::1" `echo $ipv4 | tr "." " "`)
    echo -e "${YELLOW}IPv6to4 Address: ${GREEN}$ipv6_address ${YELLOW}was created but not configured yet for routing.${NC}"
    echo ""
    press_enter
    
    sleep 2
    modprobe sit
    ip tunnel add tun6to4 mode sit ttl 255 remote any local "$ipv4"
    ip -6 link set dev tun6to4 mtu 1480
    ip link set dev tun6to4 up
    ip -6 addr add "$ipv6_address/16" dev tun6to4
    ip -6 route add 2000::/3 via ::192.88.99.1 dev tun6to4 metric 1
    sleep 1
    echo -e "    ${GREEN} [$ipv6_address] was added and routed successfully, please${RED} reboot ${NC}"

    opiran_6to4_dir="/root/opiran-6to4"
    opiran_6to4_script="$opiran_6to4_dir/6to4"

    if [ ! -d "$opiran_6to4_dir" ]; then
        mkdir "$opiran_6to4_dir"
    else
        rm -f "$opiran_6to4_script"
    fi

cat << EOF | tee -a "$opiran_6to4_script" > /dev/null
#!/bin/bash

modprobe sit
ip tunnel add tun6to4 mode sit ttl 255 remote any local "$ipv4"
ip -6 link set dev tun6to4 mtu 1480
ip link set dev tun6to4 up
ip -6 addr add "$ipv6_address/16" dev tun6to4
ip -6 route add 2000::/3 via ::192.88.99.1 dev tun6to4 metric 1
EOF

    chmod +x "$opiran_6to4_script"

    (crontab -l || echo "") | grep -v "/root/opiran-6to4/6to4" | (cat; echo "@reboot /root/opiran-6to4/6to4") | crontab -

    echo ""
    echo -e "${GREEN} Everythings were successfully done.${NC}"
    echo ""
    echo -e "${YELLOW} Your 6to4 IP: ${GREEN} [$ipv6_address]${NC}"
    press_enter
}

uninstall_6to4_ipv6() {
    clear
    sleep 1
    echo ""
    echo -e "     ${MAGENTA}List of 6to4 IPv6 addresses:${NC}"
    
    ipv6_list=$(ip -6 addr show dev tun6to4 | grep -oP "(?<=inet6 )[0-9a-f:]+")
    
    if [ -z "$ipv6_list" ]; then
        echo "No 6to4 IPv6 addresses found on the tun6to4 interface."
        return
    fi
    
    ipv6_array=($ipv6_list)
    
    for ((i = 0; i < ${#ipv6_array[@]}; i++)); do
        echo "[$i]: ${ipv6_array[$i]}"
    done
    
    echo ""
    echo -ne "Enter the number of the IPv6 address to uninstall: "
    read choice

    if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
        echo "Invalid input. Please enter a valid number."
        return
    fi
    
    if ((choice < 0 || choice >= ${#ipv6_array[@]})); then
        echo "Invalid number. Please enter a valid number within the range."
        return
    fi
    
    selected_ipv6="${ipv6_array[$choice]}"

    
    sleep 3
    /sbin/ip -6 addr del "$selected_ipv6" dev tun6to4
    echo ""
    echo -e " ${YELLOW}IPv6 address $selected_ipv6 has been deleted please${RED} reboot ${YELLOW}to take action."
}
