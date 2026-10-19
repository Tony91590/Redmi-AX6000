#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
# 
# Custom for Xiaomi AX6000
#cp $GITHUB_WORKSPACE/Xiaomi-AX3000T/patch/7661-022-fix-rrm-snprintf-error.patch package/mtk/drivers/mt_wifi/patches-7673/
#cp $GITHUB_WORKSPACE/Xiaomi-AX3000T/patch/7661-022-fix-rrm-snprintf-error.patch package/mtk/drivers/mt_wifi/patches/
sed -i 's/192.168.6.1/192.168.1.1/g' package/base-files/files/bin/config_generate
sed -i 's/default-settings-chn/default-settings/g' include/target.mk
PATCH_FILE="$GITHUB_WORKSPACE/Xiaomi-AX3000T/diff.patch"
patch -p1 < "$PATCH_FILE"

#rm -rf feeds/luci/themes/luci-theme-argon feeds/luci/themes/luci-app-argon-config

#git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon
#git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config

rm -f package/base-files/files/bin/config_generate.orig
rm -f target/linux/mediatek/dts/mt7986a-xiaomi-redmi-router-ax6000-ubootmod.dts.orig
rm -f target/linux/mediatek/dts/mt7986a-xiaomi-redmi-router-ax6000.dtsi.orig
rm -f feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/css/cascade.css.orig
