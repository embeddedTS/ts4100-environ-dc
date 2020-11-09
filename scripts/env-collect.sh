#!/bin/sh

# Remove max leading spaces in file
shiftleft() {
	len=$(grep -e "^[[:space:]]*$" -v "${1}" | sed -E 's/([^ ]).*/x/' | sort -r | head -1 | wc -c)
	cut -c $((len-1))- "${1}" > "${1}".new
	mv "${1}".new "${1}"
}

# Trim all lines to a length that fits in the LCD, 25 char max
trimlines() {
	cut -c -25 "${1}" > "${1}".new
	mv "${1}".new "${1}"
}


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

# Locate local IIO devices
for DIR in /sys/bus/iio/devices/* ; do
	if [ ! -f "${DIR}"/name ]; then continue; fi
	if [ $(cat "${DIR}"/name) == "ms8607-humidity" ] ; then
		HUMIDITY_F="${DIR}"/in_humidityrelative_input
	fi
done

for DIR in /sys/bus/iio/devices/* ; do
	if [ ! -f "${DIR}"/name ]; then continue; fi
	if [ $(cat "${DIR}"/name) == "ms8607-temppressure" ] ; then
		TEMP_F="${DIR}"/in_temp_input
		PRESSURE_F="${DIR}"/in_pressure_input
	fi
done

while true; do
	# Build the file for current weather from wttr.in
	EXT_WEATHER_F=$(mktemp)

	curl https://wttr.in/?0AFTQ -o "${EXT_WEATHER_F}" 2>/dev/null
	if [ $? -ne 0 ]; then
		# Network is broken, display some informative lines
		echo "Unable to connect to" > "${EXT_WEATHER_F}"
		echo "wttr.in" >> "${EXT_WEATHER_F}"
		echo " " >> "${EXT_WEATHER_F}"
		echo "Check network connection" >> "${EXT_WEATHER_F}"
		echo " " >> "${EXT_WEATHER_F}"
	fi
	shiftleft "${EXT_WEATHER_F}"
	trimlines "${EXT_WEATHER_F}"


	# There are some issues with "Emoji" glyphs. The HIGH VOLTAGE glyph is
	# used in some ASCII art from wttr and this is an emoji. Remap it from
	# U+26A1 to U+2607 (non-emoji "LIGHTNING")
	# NOTE! This requires GNU sed, does not work with busybox sed!
	sed -i -e 's/\xE2\x9a\xa1/\xE2\x98\x87/g' "${EXT_WEATHER_F}"


	# XXX: There is a variable number of spaces due to how much of the leading
	# whitespace is chopped off above. Below is just a rough guess and needs
	# to be cleaned up later.
	# All of the ASCII art is not made the same, it will all be within 13
	# spaces, but may have different widths inside that.
	EMPTY=$(printf "             " "${ALIGN}")
	# Get number of spaces on last line
	#ALIGN=$(tail -n1 "${EXT_WEATHER_F}" | awk -F'[^ ]' '{print length($1)}')
	#EMPTY=$(printf '%*s' "${ALIGN}")

	# Create a separating line between outside and inside, 25 chars
	SEPARATOR_F=$(mktemp)
	echo "-------------------------" > "${SEPARATOR_F}"

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

	# Create inside temp file
	INSIDE_F=$(mktemp)
	# XXX: fix this later!
	echo -n "Inside:      " >> "${INSIDE_F}"
	# echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${TEMP} °F" >> "${INSIDE_F}"
	echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${HUMIDITY} %RH" >> "${INSIDE_F}"
	echo -n "${EMPTY}" >> "${INSIDE_F}"
	echo "${PRESSURE} inHg" >> "${INSIDE_F}"
	trimlines "${INSIDE_F}"


	# Build up the final file
	FINAL_F=$(mktemp)
	cat "${EXT_WEATHER_F}" >> "${FINAL_F}"
	cat "${SEPARATOR_F}" >> "${FINAL_F}"
	cat "${INSIDE_F}" >> "${FINAL_F}"

	cat "${FINAL_F}" | cairo-display-text

	# Clean up
	rm "${EXT_WEATHER_F}"
	rm "${SEPARATOR_F}"
	rm "${INSIDE_F}"
	rm "${FINAL_F}"

	sleep 60
done
