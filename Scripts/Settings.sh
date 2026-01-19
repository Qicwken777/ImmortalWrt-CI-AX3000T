#!/bin/bash

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
    #修改WIFI名称
    sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$WIFI_SH"
    #修改WIFI密码
    if [ -n "$WRT_WORD" ]; then
        sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$WIFI_SH"
    fi
elif [ -f "$WIFI_UC" ]; then
    #修改WIFI名称
    sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" "$WIFI_UC"
    #修改WIFI地区
    sed -i "s/country='.*'/country='CN'/g" "$WIFI_UC"
    #修改WIFI加密
    sed -i "s/encryption='.*'/encryption='none'/g" "$WIFI_UC"
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

#修改apk软件源为南京大学镜像站
DEFAULT_SETTINGS=$(find ./package/emortal/default-settings/files/ -type f -name "99-default-settings" 2>/dev/null | head -1)
if [ -f "$DEFAULT_SETTINGS" ]; then
    LAST_LINE=$(awk '/exit 0/{print NR}' "$DEFAULT_SETTINGS" | tail -1)
    if [ -n "$LAST_LINE" ]; then
        sed -i "${LAST_LINE}i\\"$'\n'"sed -i \"s,https://downloads.immortalwrt.org,https://mirror.nju.edu.cn/immortalwrt,g\" /etc/apk/repositories.d/distfeed.list" "$DEFAULT_SETTINGS"
    fi
fi

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
    echo "$WRT_PACKAGE" >> ./.config
fi

# 添加dnsmasq设置，将miwifi.com解析到192.168.11.1
DNSMASQ_CONF="./package/network/services/dnsmasq/files/dnsmasq.conf"
if [ -f "$DNSMASQ_CONF" ]; then
    echo "address=/miwifi.com/192.168.11.1" >> "$DNSMASQ_CONF"
else
    # 尝试其他可能的位置
    DNSMASQ_CONF2="./package/base-files/files/etc/dnsmasq.conf"
    if [ -f "$DNSMASQ_CONF2" ]; then
        echo "address=/miwifi.com/192.168.11.1" >> "$DNSMASQ_CONF2"
    elif [ -f "$DEFAULT_SETTINGS" ]; then
        # 在默认设置中添加命令，让系统启动时写入
        LAST_LINE=$(awk '/exit 0/{print NR}' "$DEFAULT_SETTINGS" | tail -1)
        if [ -n "$LAST_LINE" ]; then
            sed -i "${LAST_LINE}i\\"$'\n'"echo \"address=/miwifi.com/192.168.11.1\" >> /etc/dnsmasq.conf" "$DEFAULT_SETTINGS"
        fi
    fi
fi

# 移动UPnP页面从Services到Network
if [ -f "./feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json" ]; then
    sed -i 's#admin/services/upnp#admin/network/upnp#g' \
    ./feeds/luci/applications/luci-app-upnp/root/usr/share/luci/menu.d/luci-app-upnp.json
fi

# 移动MosDNS页面从Services到Network
MOSDNS_MENU=$(find .. -type f \
  -path "*luci-app-mosdns*/root/usr/share/luci/menu.d/luci-app-mosdns.json" \
  2>/dev/null | head -n 1)

if [ -n "$MOSDNS_MENU" ]; then
    sed -i 's#admin/services/mosdns#admin/network/mosdns#g' "$MOSDNS_MENU"
    echo "Moved luci-app-mosdns menu to Network:"
    echo "  $MOSDNS_MENU"
else
    echo "luci-app-mosdns menu file not found!"
fi

# 从源码中读取版本信息
DISTRIB_RELEASE=$(sed -n 's/^VERSION_NUMBER[:=]\s*//p' include/version.mk | tr -d " '")

if [ -z "$DISTRIB_RELEASE" ]; then
    DISTRIB_RELEASE=$(sed -n 's/^DISTRIB_RELEASE[:=]\s*//p' include/version.mk | tr -d " '")
fi

[ -z "$DISTRIB_RELEASE" ] && DISTRIB_RELEASE="$(date +%Y%m%d)"

# 创建banner目录（如果不存在）
mkdir -p ./package/base-files/files/etc/

# 修改banner
cat << EOF > ./package/base-files/files/etc/banner
     _________
    /        /\      __  __                       _ 
   /  MO    /  \    |  \/  | ___  _ __ ___   ___ (_)
  /    MO  /    \   | |\/| |/ _ \| '_ ' _ \ / _ \| |
 /________/  MO  \  | |  | | (_) | | | | | | (_) | |
 \        \   MO /  |_|  |_|\___/|_| |_| |_|\___/|_|
  \    MO  \    /  -------------------------------------------
   \  MO    \  /    ImmortalWrt, ${DISTRIB_RELEASE}
    \________\/    -------------------------------------------

EOF
