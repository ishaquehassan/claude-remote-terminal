#!/usr/bin/env python3
"""
/remote-devices-logout — logout all paired devices from Claude Remote server.
Clears paired_devices.json and forces all connected phones back to server list.
"""

import asyncio
import json
import sys

try:
    import websockets
except ImportError:
    print("websockets not installed. Run: pip3 install websockets")
    sys.exit(1)

HOST  = "localhost"
PORT  = 8765
TOKEN = "xrlabs-remote-terminal-2024"


async def main():
    try:
        async with websockets.connect(f"ws://{HOST}:{PORT}") as ws:
            await ws.send(json.dumps({"type": "auth", "token": TOKEN}))

            # Drain until auth_ok
            async for raw in ws:
                msg = json.loads(raw)
                if msg.get("type") == "auth_ok":
                    break
                if msg.get("type") == "auth_fail":
                    print("Auth failed — check AUTH_TOKEN in server.py")
                    return

            await ws.send(json.dumps({"type": "logout_all_devices"}))

            async for raw in ws:
                msg = json.loads(raw)
                if msg.get("type") == "logout_ok":
                    count = msg.get("count", 0)
                    print(f"✓ {count} device(s) logged out. All phones have been disconnected.")
                    return

    except ConnectionRefusedError:
        print("Could not connect to server — is remote-terminal running?")
    except Exception as e:
        print(f"Error: {e}")


asyncio.run(main())
