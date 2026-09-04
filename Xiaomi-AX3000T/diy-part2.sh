#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
# 
# Custom for Xiaomi AX6000
cp $GITHUB_WORKSPACE/Xiaomi-AX3000T/patch/7661-022-fix-rrm-snprintf-error.patch package/mtk/drivers/mt_wifi/patches-7673/
cp $GITHUB_WORKSPACE/Xiaomi-AX3000T/patch/7661-022-fix-rrm-snprintf-error.patch package/mtk/drivers/mt_wifi/patches-7661/
#sed -i 's/192.168.1.1/192.168.31.1/g' package/base-files/files/bin/config_generate
sed -i '/\["FR"\]/s/{ 1, 2 }/{ 1, 1 }/' package/mtk/applications/mtwifi-cfg/files/mtwifi-cfg/mtwifi_defs.lua
sed -i 's/default-settings-chn/default-settings/g' include/target.mk
grep -R '\["FR"\]' package/mtk/applications/mtwifi-cfg/files/mtwifi-cfg/mtwifi_defs.lua
