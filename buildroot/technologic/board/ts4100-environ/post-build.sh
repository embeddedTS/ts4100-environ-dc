#!/bin/bash -e

MKIMAGE=$HOST_DIR/bin/mkimage

# Create U-Boot script in image, create both .ub and .scr for compat sake
$MKIMAGE -A arm -T script -C none -n 'readonly' -d "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/tsinit.source "${TARGET_DIR}"/boot/boot.scr
$MKIMAGE -A arm -T script -C none -n 'readonly' -d "${BR2_EXTERNAL_TS4100_ENVIRON_PATH}"/board/ts4100-environ/tsinit.source "${TARGET_DIR}"/boot/boot.ub

# Remove dropbear server startup if it exists
if [ -e "${TARGET_DIR}"/etc/init.d/*dropbear ]; then
	rm "${TARGET_DIR}"/etc/init.d/*dropbear
fi
