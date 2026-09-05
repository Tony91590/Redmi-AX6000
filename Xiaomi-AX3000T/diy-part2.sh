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

sed -i '/AUTOLOAD:=$(call AutoProbe,mt7915e)/a \  MODPARAMS.mt7915e:=wed_enable=Y' package/kernel/mt76/Makefile

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

uci set firewall.@defaults[0].flow_offloading='1'
uci set firewall.@defaults[0].flow_offloading_hw='1'

uci commit firewall

exit 0
EOF

chmod +x files/etc/uci-defaults/99-default-settings

rm -f feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js.orig

mkdir -p target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface

cat > target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface/99-odhcpd-reload <<'ODHCPD_EOF'
#!/bin/sh

[ "$ACTION" = "ifup" ] || exit 0

if [ "$INTERFACE" = "wan6" ]; then
        sleep 10
        /etc/init.d/odhcpd reload
fi
ODHCPD_EOF

chmod 0755 target/linux/mediatek/filogic/base-files/etc/hotplug.d/iface/99-odhcpd-reload

echo "Done ✔"
