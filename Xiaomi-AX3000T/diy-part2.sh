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
