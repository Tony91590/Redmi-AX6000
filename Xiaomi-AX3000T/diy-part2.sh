#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Custom build script - Redmi AX6000 
# Optimized LuCI + ImmortalWrt enhancements

set -e

# ==========================================
# Kernel vermagic override
# ==========================================

PATCH_VER="$GITHUB_WORKSPACE/Xiaomi-AX3000T/vermagic.patch"

echo "[0] Setting kernel vermagic"

patch -p1 < "$PATCH_VER"

echo "✓ Setting kernel vermagic applied successfully."

# ==========================================
# LuCI system status patch
# ==========================================

PATCH_FILE="$GITHUB_WORKSPACE/Xiaomi-AX3000T/10_system.patch"

echo "[1] Applying LuCI system status patch..."

patch -p1 < "$PATCH_FILE"

echo "✓ LuCI system status patch applied successfully."


echo "[2] Patching LuCI RPC backend..."

python3 <<'PY'
from pathlib import Path

file = Path("feeds/luci/modules/luci-base/root/usr/share/rpcd/ucode/luci")

if not file.exists():
    raise SystemExit("LuCI RPC file not found")

s = file.read_text()

if "getTempInfo:" in s:
    print("Patch already applied, skipping.")
    exit(0)

block = r"""
        getTempInfo: {
            call: function() {
                if (!access('/sbin/tempinfo'))
                    return {};

                const fd = popen('/sbin/tempinfo');
                if (!fd)
                    return { tempinfo: error() };

                let tempinfo = fd.read('all') || '?';
                fd.close();

                return { tempinfo: tempinfo };
            }
        }
"""

marker_candidates = [
    "\n};\n\nreturn { luci: methods };",
    "\n}; return { luci: methods };"
]

for marker in marker_candidates:
    if marker in s:
        s = s.replace(marker, ",\n" + block.strip() + marker, 1)
        file.write_text(s)
        print("Patch applied successfully.")
        break
else:
    raise SystemExit("LuCI RPC end marker not found, aborting.")
PY


echo "[3] Adding ImmortalWrt packages..."

mkdir -p files/sbin

cat > files/sbin/tempinfo <<'EOF'
#!/bin/sh
#
# MediaTek Filogic platform support: CPU and WiFi temperature monitoring

IEEE_PATH="/sys/class/ieee80211"
THERMAL_PATH="/sys/class/thermal"

wifi_temp="$(awk '{printf("%.1f°C ", $0 / 1000)}' "$IEEE_PATH"/phy*/hwmon*/temp1_input 2>"/dev/null" | awk '$1=$1')"
cpu_temp="$(awk '{printf("%.1f°C", $0 / 1000)}' "$THERMAL_PATH/thermal_zone0/temp" 2>"/dev/null")"

echo -n "CPU: $cpu_temp, WiFi: $wifi_temp"
EOF

chmod +x files/sbin/tempinfo

mkdir -p files/usr/share/rpcd/acl.d

cat > files/usr/share/rpcd/acl.d/luci-mod-status-autocore.json <<'EOF'
{
	"luci-mod-status-autocore": {
		"description": "Grant access to autocore",
		"read": {
			"ubus": {
				"luci": [ "getTempInfo" ]
			}
		}
	}
}
EOF


echo "[4] Kernel tweak (mt76 / AX3000T)..."

#sed -i '/AUTOLOAD:=$(call AutoProbe,mt7915e)/a \  MODPARAMS.mt7915e:=wed_enable=Y' package/kernel/mt76/Makefile

echo "[5] LuCI theme Argon..."

rm -rf package/luci-theme-argon package/luci-app-argon-config

git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config


echo "[6] Default WiFi + firewall config..."

mkdir -p files/etc/uci-defaults

cat > files/etc/uci-defaults/99-default-settings << 'EOF'
#!/bin/sh

uci set wireless.@wifi-device[0].disabled='0'
uci set wireless.@wifi-iface[0].disabled='0'
uci set wireless.@wifi-iface[0].encryption='none'
uci set wireless.@wifi-iface[0].ssid="OpenWrt_2.4G"

uci set wireless.@wifi-device[1].disabled='0'
uci set wireless.@wifi-iface[1].disabled='0'
uci set wireless.@wifi-iface[1].encryption='none'
uci set wireless.@wifi-iface[1].ssid="OpenWrt_5G"

uci commit wireless

exit 0
EOF

chmod +x files/etc/uci-defaults/99-default-settings

PATCH_FILE="$GITHUB_WORKSPACE/Xiaomi-AX3000T/diff.patch"
patch -p1 < "$PATCH_FILE"

rm -f feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js.orig
rm -f package/kernel/leds-ws2812b/src/leds-ws2812b.c.orig

mkdir -p target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface

cat > target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface/95-wan6-pd-recovery <<'ODHCPD_EOF'
#!/bin/sh

TAG="wan6-pd-recovery"

log() {
	logger -t "$TAG" "$1"
}

# Seulement wan6
[ "$INTERFACE" = "wan6" ] || exit 0

# Seulement au démarrage de l'interface
[ "$ACTION" = "ifup" ] || exit 0

log "wan6 started"

# Laisser odhcp6c/netifd commencer son travail
sleep 3

get_pd() {
	ubus call network.interface.wan6 status 2>/dev/null |
		jsonfilter -e '@["ipv6-prefix"][0].address' 2>/dev/null
}

# Vérification initiale
PD="$(get_pd)"

if [ -n "$PD" ]; then
	log "IPv6-PD found: $PD"
	/etc/init.d/odhcpd reload
	log "odhcpd reloaded"
	exit 0
fi

# Aucun PD : forcer une nouvelle négociation DHCPv6
log "No IPv6-PD found, restarting wan6"

ifdown wan6
sleep 2
ifup wan6

# Attendre le PD pendant 30 secondes
i=0

while [ "$i" -lt 30 ]; do
	sleep 1

	PD="$(get_pd)"

	if [ -n "$PD" ]; then
		log "IPv6-PD acquired: $PD"

		# Laisser netifd appliquer le préfixe
		sleep 2

		/etc/init.d/odhcpd reload

		log "odhcpd reloaded after PD acquisition"
		exit 0
	fi

	i=$((i + 1))
done

log "IPv6-PD not acquired after 30 seconds"
exit 1
ODHCPD_EOF

chmod 0755 target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface/95-wan6-pd-recovery

echo "Done ✔"
