#!/bin/sh

# To anyone who ends up reading this file and feels like its many things
# mashed together, bear in mind this demo has evolved over time in both
# scope and complexity and has not seen a complete rewrite. May the
# comments be your guide.

# Timeout for how often we want to try to reach wttr.in
TIMEOUT_LEN=3600

# Remove max leading spaces in file
# Used for wttr.in to left align the output always
shiftleft() {
	len=$(grep -e "^[[:space:]]*$" -v "${1}" | sed -E 's/([^ ]).*/x/' | sort -r | head -1 | wc -c)
	cut -c $((len-1))- "${1}" > "${1}".new
	mv "${1}".new "${1}"
}

# Trim all lines to a length that fits in the LCD, 25 char max
# XXX Causes issues with multi-byte characters and isn't really
# used anymore
trimlines() {
	cut -c -25 "${1}" > "${1}".new
	mv "${1}".new "${1}"
}


startup() {
	# Loop startup a bit waiting for network
	# In order for this to work, need to be able to connect to internet
	# and have correct time for SSL. Keep polling the weather website
	# until we get a valid response or timeout. Network is up and ready
	# when valid response from https://wttr.in
	STARTUP_F=$(mktemp)
	echo "" > "${STARTUP_F}"
	echo "" >> "${STARTUP_F}"
	echo "Starting Application" >> "${STARTUP_F}"
	echo "Waiting for network" >> "${STARTUP_F}"
	cat "${STARTUP_F}" | cairo-display-text
	x=0
	while [ "$x" -lt 25 ]; do
		x=$((x+1))
		sleep 2

		curl https://wttr.in/?0AFTQ >/dev/null 2>&1
		if [ $? -eq 0 ]; then break; fi

		echo -n "." >> "${STARTUP_F}"
		cat "${STARTUP_F}" | cairo-display-text
	done
	rm "${STARTUP_F}"
}

iio_get_devices() {
	# Locate local IIO devices
	for DIR in /sys/bus/iio/devices/* ; do
		if [ ! -f "${DIR}"/name ]; then continue; fi
		if [ $(cat "${DIR}"/name) = "ms8607-humidity" ] ; then
			HUMIDITY_F="${DIR}"/in_humidityrelative_input
		fi
	done

	for DIR in /sys/bus/iio/devices/* ; do
		if [ ! -f "${DIR}"/name ]; then continue; fi
		if [ $(cat "${DIR}"/name) = "ms8607-temppressure" ] ; then
			TEMP_F="${DIR}"/in_temp_input
			PRESSURE_F="${DIR}"/in_pressure_input
		fi
	done
}

ext_weather_build() {
	# If EXT_WEATHER_LAST_F is older than TIMEOUT_LEN minutes or is blank,
	# we need to try and update it. A successful curl operation
	# will create/update this file.
	GET_UPDATE=0
	if [ ! -s "${EXT_WEATHER_LAST_F}" ] ; then
		GET_UPDATE=1
	else
		DATE=$(date +%s)
		EXT_AGO=$(date +%s -r "${EXT_WEATHER_F}")
		EXT_AGO=$((DATE - EXT_AGO))
		if [ ${EXT_AGO} -gt ${TIMEOUT_LEN} ]; then
			GET_UPDATE=1
		fi
	fi

	if [ ${GET_UPDATE} -eq 1 ]; then
		curl https://wttr.in/?0AFTQ -o "${EXT_WEATHER_F}" 2>/dev/null
		if [ $? -ne 0 ]; then # Error!
			if [ -s "${EXT_WEATHER_LAST_F}" ]; then
				# If no data from curl, and we have the last weather
				# update, then use that instead
				cat "${EXT_WEATHER_LAST_F}" > "${EXT_WEATHER_F}"
			else
				# Network is broken, display some informative lines
				echo "Unable to connect to" > "${EXT_WEATHER_F}"
				echo "wttr.in" >> "${EXT_WEATHER_F}"
				echo " " >> "${EXT_WEATHER_F}"
				echo "Check network connection" >> "${EXT_WEATHER_F}"
				echo " " >> "${EXT_WEATHER_F}"
			fi
		else # Success!
			# Process the output to shift and trim in to our display area
			shiftleft "${EXT_WEATHER_F}"
			#trimlines "${EXT_WEATHER_F}"

			# There are some issues with "Emoji" glyphs. The HIGH VOLTAGE glyph is
			# used in some ASCII art from wttr and this is an emoji. Remap it from
			# U+26A1 to U+2607 (non-emoji "LIGHTNING")
			# NOTE! This requires GNU sed, does not work with busybox sed!
			sed -i -e 's/\xE2\x9a\xa1/\xE2\x98\x87/g' "${EXT_WEATHER_F}"

			# Set current weather to last weather for future use
			cat "${EXT_WEATHER_F}" > "${EXT_WEATHER_LAST_F}"
		fi
	fi
}

int_weather_build() {
	# NOTE: This function works fine, but could probably use some printf
	# or sed magic to get the Inside lines to line up with the exterior
	# lines. The issue is that wttr.in does have some variability in art
	# width and this means some weather states can shift the column that
	# the actual data lines up at. It's a minor difference, but, would
	# add some good detail if this can be addressed.

	# XXX: There is a variable number of spaces due to how much of the leading
	# whitespace is chopped off above. Below is just a rough guess and needs
	# to be cleaned up later.
	# All of the ASCII art is not made the same, it will all be within 13
	# spaces, but may have different widths inside that.
	EMPTY=$(printf "             " "${ALIGN}")
	# Get number of spaces on last line
	#ALIGN=$(tail -n1 "${EXT_WEATHER_F}" | awk -F'[^ ]' '{print length($1)}')
	#EMPTY=$(printf '%*s' "${ALIGN}")

	# XXX: It would be nice to break this out in to a separate process
	# or thread and take multiple samples to average out over the minute
	# or some amount of time between updates

	# Gather inside stats
	# Humidity is milli %RH
	HUMIDITY=$(cat "${HUMIDITY_F}")
	HUMIDITY=$(echo "scale=1; ${HUMIDITY} / 1000" | bc -l)

	# Pressure is in kPa, convert to inHg
	PRESSURE=$(cat "${PRESSURE_F}")
	PRESSURE=$(echo "scale=1; ${PRESSURE} / 3.386" | bc -l)

	# Temp is in milli C, convert to F
	# This takes multiple steps to cleanly do with scaling
	TEMP=$(cat "${TEMP_F}")
	TEMP=$(echo "scale=2; ${TEMP} / 1000" | bc -l)
	TEMP=$(echo "((9/5) * ${TEMP}) + 32" | bc -l)
	TEMP=$(echo "scale=0; ${TEMP} / 1" | bc -l)

	# XXX: fix this later!
	> "${INSIDE_F}"
	echo -n "Inside:      " >> "${INSIDE_F}"
	# echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${TEMP} °F" >> "${INSIDE_F}"
	echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${HUMIDITY} %RH" >> "${INSIDE_F}"
	echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${PRESSURE} inHg" >> "${INSIDE_F}"
	#trimlines "${INSIDE_F}"

	echo 0
}

beacon_build() {
	# This is a bit chunky because there is no nice looping...
	B1_UPTIME=$(jq  'select(."mac address"=="'${B1_MAC}'") | .uptime' "${BEACON_RAW_F}" | tail -n 1)
	B1_BAT_MV=$(jq  'select(."mac address"=="'${B1_MAC}'") | .battery' "${BEACON_RAW_F}" | tail -n 1)
	B1_TEMP_C=$(jq  'select(."mac address"=="'${B1_MAC}'") | .temperature' "${BEACON_RAW_F}" | tail -n 1)

	# If B1 was not found, check for B1 backup
	if [ -z "${B1_UPTIME}" ]; then
		B1_UPTIME=$(jq  'select(."mac address"=="'${B1B_MAC}'") | .uptime' "${BEACON_RAW_F}" | tail -n 1)
		B1_BAT_MV=$(jq  'select(."mac address"=="'${B1B_MAC}'") | .battery' "${BEACON_RAW_F}" | tail -n 1)
		B1_TEMP_C=$(jq  'select(."mac address"=="'${B1B_MAC}'") | .temperature' "${BEACON_RAW_F}" | tail -n 1)
	fi

	# Build/rebuild B1_F if new data was found from B1 or B1B
	if [ -n "${B1_UPTIME}" ]; then
		> "${B1_F}"
		cat "${SEPARATOR_F}" >> "${B1_F}"

		# Convert temp from C with decimal to F whole number
		TEMP=$(echo "((9/5) * ${B1_TEMP_C}) + 32" | bc -l)
		TEMP=$(echo "scale=0; ${TEMP} / 1" | bc -l)
		echo "1: Temp: ${TEMP} °F" >> "${B1_F}"

		# Check battery voltage
		printf "   Batt: ${B1_BAT_MV} mV" >> "${B1_F}"
		if [ ${B1_BAT_MV} -lt 2200 ]; then
			printf "!!!\n" >> "${B1_F}"
		else
			printf "\n" >> "${B1_F}"
		fi
		let UPTIME=${B1_UPTIME}/1000
		UPTIME=$(date -d "1970-01-01 0:0:${UPTIME}" +%H:%M:%S)
		echo "   Up:   ${UPTIME}" >> "${B1_F}"
	fi
	
		

	NAME="${B2_NAME}"
	B2_UPTIME=$(jq  'select(."mac address"=="'${B2_MAC}'") | .uptime' "${BEACON_RAW_F}" | tail -n 1)
	B2_BAT_MV=$(jq  'select(."mac address"=="'${B2_MAC}'") | .battery' "${BEACON_RAW_F}" | tail -n 1)
	B2_TEMP_C=$(jq  'select(."mac address"=="'${B2_MAC}'") | .temperature' "${BEACON_RAW_F}" | tail -n 1)

	# If B2 was not found, check for B2 backup
	if [ -z "${B2_UPTIME}" ] ; then
		NAME="${B2B_NAME}"
		B2_UPTIME=$(jq  'select(."mac address"=="'${B2B_MAC}'") | .uptime' "${BEACON_RAW_F}" | tail -n 1)
		B2_BAT_MV=$(jq  'select(."mac address"=="'${B2B_MAC}'") | .battery' "${BEACON_RAW_F}" | tail -n 1)
		B2_TEMP_C=$(jq  'select(."mac address"=="'${B2B_MAC}'") | .temperature' "${BEACON_RAW_F}" | tail -n 1)
	fi

	# Build/rebuild B2_F if new data was found from B2 or B2B
	if [ -n "${B2_UPTIME}" ]; then
		> "${B2_F}"
		cat "${SEPARATOR_F}" >> "${B2_F}"

		# Convert temp from C with decimal to F whole number
		TEMP=$(echo "((9/5) * ${B2_TEMP_C}) + 32" | bc -l)
		TEMP=$(echo "scale=0; ${TEMP} / 1" | bc -l)
		echo "2: Temp: ${TEMP} °F" >> "${B2_F}"

		# Check battery voltage
		printf "   Batt: ${B2_BAT_MV} mV" >> "${B2_F}"
		if [ ${B2_BAT_MV} -lt 2200 ]; then
			printf "!!!\n" >> "${B2_F}"
		else
			printf "\n" >> "${B2_F}"
		fi

		let UPTIME=${B2_UPTIME}/1000
		UPTIME=$(date -d "1970-01-01 0:0:${UPTIME}" +%H:%M:%S)
		echo "   Up:   ${UPTIME}" >> "${B2_F}"
	fi


	# Figure out how long its been since we've seen each beacon
	B1_AGO=$(date +%s -r "${B1_F}")
	B2_AGO=$(date +%s -r "${B2_F}")
	DATE=$(date +%s)
	B1_AGO=$((DATE - B1_AGO))
	B2_AGO=$((DATE - B2_AGO))

	# If beacon has been missing for more than 300 seconds, then
	# clear the file since there is likely some issue with the
	# beacon.
	if [ ${B1_AGO} -gt 300 ]; then
		> "${B1_F}"
	fi
	if [ ${B2_AGO} -gt 300 ]; then
		> "${B2_F}"
	fi

	# Finally, get our string set up to printf
	B1_AGO=$(printf "%03s" "${B1_AGO}")
	B2_AGO=$(printf "%03s" "${B2_AGO}")

	> "${BEACON_F}"
	if [ -s "${B1_F}" ] || [ -s "${B2_F}" ]; then
		echo "  Eddystone TLM Beacons" >> "${BEACON_F}"
		sed '2s/$/  '"${B1_AGO}"' s ago/' "${B1_F}" >> "${BEACON_F}"
		sed '2s/$/  '"${B2_AGO}"' s ago/' "${B2_F}" >> "${BEACON_F}"
		echo 0
	else
		echo 1
	fi
	#trimlines "${BEACON_F}"
}

# Make a handful of global file names that are used and re-used for
# building up text blocks
text_file_create() {
	# Build the file for current weather from wttr.in
	EXT_WEATHER_F=$(mktemp)

	# Create the file to maintain the previous ext/int weather
	EXT_WEATHER_LAST_F=$(mktemp)

	# Create a separating line between outside and inside, 25 chars
	SEPARATOR_F=$(mktemp)
	echo "-------------------------" > "${SEPARATOR_F}"

	# Create a centered URL line for the repo project
	GITHUB_F=$(mktemp)
	echo "  URL: TS.to/ts4100-dc" > "${GITHUB_F}"

	# Create inside temp file
	INSIDE_F=$(mktemp)

	# Build up the final ext/int display file
	FINAL_F=$(mktemp)

	# File to capture Eddystone beacon packets to
	BEACON_RAW_F=$(mktemp)

	# File to build Eddyston beacon printed info
	BEACON_F=$(mktemp)

	# File with Beacon 1 details
	B1_F=$(mktemp)

	# File with Beacon 2 details
	B2_F=$(mktemp)
}

main() {
	# This spins waiting for network or returns no network
	startup

	# Create our files in /tmp for building up text
	text_file_create

	# This sets HUMIDITY_F, TEMP_F, PRESSURE_F files for the int_ functions
	iio_get_devices

	# Source BLE MAC addresses
	# Note that the function looking for these vars only currently uses
	# B1_MAC, B1B_MAC, B2_MAC, and B2B_MAC
	if [ -e /etc/beacons.env ]; then
		source /etc/beacons.env
		BEACON_NONE=0
	else
		echo "No /etc/beacons.env file!\nNot displaying beacon info!" | cairo-display-text
		sleep 10
		BEACON_NONE=1
	fi

	# Main loop to display info on screen
	# If BEACON_NONE or no beacons seen, the only update the ext/int display every 60 seconds
	# If beacons seen, show each screen for 10 s
	while true; do
		ext_weather_build

		int_weather_build

		# Only update the output once a minute normally
		DATE=$(date +%s)
		FINAL_AGO=$(date +%s -r "${FINAL_F}")
		FINAL_AGO=$((DATE - FINAL_AGO))
		if [ ${FINAL_AGO} -gt 60 ]; then
			> "${FINAL_F}"
		fi

		# Update the ext/int screen and re-run on display
		# if the file was cleared out due to timeout or
		# for updating faster when beacons are being
		# displayed too
		if [ ! -s "${FINAL_F}" ]; then
			cat "${EXT_WEATHER_F}" >> "${FINAL_F}"
			cat "${SEPARATOR_F}" >> "${FINAL_F}"
			cat "${INSIDE_F}" >> "${FINAL_F}"
			cat "${GITHUB_F}" >> "${FINAL_F}"
			cat "${FINAL_F}" | cairo-display-text
		fi

		# Run the beacon packet capture for 10 seconds, killing it with
		# a SIGINT to ensure the file gets closed and written to properly
		if [ ${BEACON_NONE} -ne 1 ]; then
			# The main beacon collection script takes a filename to write to
			# as well as a timeout in seconds to run for
			get_eddystone_packet.py "${BEACON_RAW_F}" 10

			ret=$(beacon_build)
			if [ ${ret} -eq 0 ]; then
				cat "${BEACON_F}" | cairo-display-text
				# Touch the ext/int environ file to hint that it should be
				# re-built and re-displayed.
				> "${FINAL_F}"
				sleep 10
			fi
		else
			sleep 10
		fi
	done

}

main

