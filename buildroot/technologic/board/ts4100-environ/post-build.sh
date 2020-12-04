#!/bin/bash -e

MKIMAGE=$HOST_DIR/bin/mkimage

# Install network interfaces files
install -m 0644 -D "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/interfaces "${TARGET_DIR}"/etc/network/
install -m 0644 -D "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/wpa_supplicant.conf "${TARGET_DIR}"/etc/

# Install startup scripts
install -m 0755 -D "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/S35loadwifilcdmodules "${TARGET_DIR}"/etc/init.d/
install -m 0755 -D "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/S37startenviron "${TARGET_DIR}"/etc/init.d/

# Create U-Boot script in image, create both .ub and .scr for compat sake
$MKIMAGE -A arm -T script -C none -n 'readonly' -d "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/tsinit.source "${TARGET_DIR}"/boot/boot.scr
$MKIMAGE -A arm -T script -C none -n 'readonly' -d "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/tsinit.source "${TARGET_DIR}"/boot/boot.ub
