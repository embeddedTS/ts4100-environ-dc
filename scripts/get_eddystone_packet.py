#!/usr/bin/env python3

'''
 Simple script written in python to utilize aioblescan to parse Eddystone TLM beacons.
 python-aioblescan 0.2.9+ is required for correct parsing of Eddystone TLM beacons.

 Note that aioblescan needs a few modifications for this to work! Namely, 'type' needs
 to be added to .decode(), as well as mac_address being added to .decode() for TLM.
 Both of these modifications are present in this Buildroot project. Though as Buildroot
 changes over time, these patches may need to be re-implemented.

 This will ultimately output the first TLM packet it sees in a bash parseable format.
 This may need to be modified to correctly work in a noisier environment, but one thing
 at a time.

 It is the responsibility of the calling application to terminate this tool in a
 reasonable amount of time if needed.
'''

import argparse
import json
import asyncio
import aioblescan as aiobs
from aioblescan.plugins import EddyStone

def decode_packet(data):
	ev = aiobs.HCI_Event()
	xx = ev.decode(data)
	xx = EddyStone().decode(ev)
	if xx and xx['type'] == 32:
		# Prints each decoded TLM packet as JSON format
		# Write to the file and print to stdout for ref
		formatted = json.dumps(xx)
		fd.write(formatted)
		print(formatted)
		return

def stop_loop(args=None):
	event_loop.stop()

# Create an asyncio loop that is global so the decode_packet function can stop it
# once it gets a valid beacon packet.
event_loop = asyncio.get_event_loop()
def main(args=None):

	parser = argparse.ArgumentParser()
	parser.add_argument("filename")
	parser.add_argument("timeout")
	args = parser.parse_args()

	global fd
	fd = open(args.filename, "w");

	mysocket = aiobs.create_bt_socket(0)

	fac = event_loop._create_connection_transport(
		mysocket, aiobs.BLEScanRequester, None, None
	)

	conn, btctrl = event_loop.run_until_complete(fac)

	btctrl.process = decode_packet

	event_loop.run_until_complete(btctrl.send_scan_request())
	event_loop.call_later(int(args.timeout), stop_loop)
	try:
		event_loop.run_forever()

	except KeyboardInterrupt:
		print("")

	finally:
		event_loop.run_until_complete(btctrl.stop_scan_request())
		conn.close()
		event_loop.close()
		fd.close()

main()
