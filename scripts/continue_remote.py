#!/usr/bin/env python3
"""
/continue-remote — current Claude session ko phone app mein continue karo.
Server ko auto_open flag ke saath new session request bhejta hai.
Phone app automatically us session pe navigate karta hai.
"""
import asyncio
import json
import sys
import websockets

HOST = "localhost"
PORT = 8765
TOKEN = "xrlabs-remote-terminal-2024"


async def main():
    uri = f"ws://{HOST}:{PORT}"
    try:
        async with websockets.connect(uri, open_timeout=5) as ws:
            # Auth
            await ws.send(json.dumps({"type": "auth", "token": TOKEN}))
            msg = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            if msg.get("type") != "auth_ok":
                print(f"[continue-remote] Auth failed: {msg}")
                sys.exit(1)

            # New session with auto_open=True — server broadcasts to phone
            import os
            await ws.send(json.dumps({
                "type": "new_session",
                "cmd": "claude --continue",
                "rows": 40,
                "cols": 80,
                "auto_open": True,
                "cwd": os.getcwd(),  # current project directory — claude uses this to find conversation
            }))

            # Wait for session_created confirmation
            while True:
                raw = await asyncio.wait_for(ws.recv(), timeout=10)
                msg = json.loads(raw)
                if msg.get("type") == "session_created":
                    sid = msg.get("session_id", "?")
                    print(f"[continue-remote] Session {sid} created — phone app mein khul rahi hai!")
                    return
                # Skip other messages (sessions_list etc.)

    except ConnectionRefusedError:
        print(f"[continue-remote] Server nahi mila ({HOST}:{PORT}) — server.py chal raha hai?")
        sys.exit(1)
    except asyncio.TimeoutError:
        print("[continue-remote] Timeout — server ne respond nahi kiya")
        sys.exit(1)
    except Exception as e:
        print(f"[continue-remote] Error: {e}")
        sys.exit(1)


asyncio.run(main())
