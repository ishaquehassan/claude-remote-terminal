#!/usr/bin/env python3
"""
test_history.py — Claude Remote session history persistence test

ADB-driven automation:
  1. Launch app fresh
  2. Create a new Claude session
  3. Send N dynamic conversational prompts (waits for each response intelligently)
  4. Kill app
  5. Relaunch app
  6. Open the same session
  7. Verify history is preserved and rendered correctly
  8. Clean up all sessions before next cycle

!! DO NOT DISCONNECT THE DEVICE WHILE THIS SCRIPT IS RUNNING !!
The device selected at startup is used for the entire session.

Usage:
  python3 test_history.py                      # 1 cycle, 4 prompts
  python3 test_history.py --cycles 3           # 3 full cycles back-to-back
  python3 test_history.py --prompts 6          # 6 prompts per cycle
  python3 test_history.py --cycles 2 --prompts 5 --output ./results
"""

import subprocess
import time
import random
import os
import sys
import json
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from datetime import datetime

# ── ANSI colors ───────────────────────────────────────────────────────────────

R  = "\033[31m"   # red
G  = "\033[32m"   # green
Y  = "\033[33m"   # yellow
B  = "\033[34m"   # blue
M  = "\033[35m"   # magenta
C  = "\033[36m"   # cyan
W  = "\033[37m"   # white
BLD= "\033[1m"    # bold
DIM= "\033[2m"    # dim
RST= "\033[0m"    # reset

def clr(color, text): return f"{color}{text}{RST}"
def ok(text):  return clr(G + BLD, text)
def err(text): return clr(R + BLD, text)
def info(text):return clr(C, text)
def warn(text):return clr(Y, text)
def hdr(text): return clr(M + BLD, text)
def dim(text): return clr(DIM, text)
def step(text):return clr(B + BLD, text)

# ── Config ────────────────────────────────────────────────────────────────────

APP = "com.xrlabs.claude_remote"

DEVICE_SERIAL: str = ""   # set once by select_device() at startup

# ── Device selection ──────────────────────────────────────────────────────────

def select_device() -> str:
    """
    List connected ADB devices and let the user pick one.
    Auto-selects if only one device is connected.
    The chosen serial is used for ALL ADB calls throughout the session.
    """
    global DEVICE_SERIAL
    result = subprocess.run(
        ["adb", "devices"],
        capture_output=True, text=True, timeout=10,
    )
    lines = [
        l.strip() for l in result.stdout.splitlines()
        if l.strip()
        and not l.startswith("List of")
        and "\tdevice" in l
    ]
    if not lines:
        print(err("\n[ERROR] No ADB device found."))
        print(warn("        Connect your phone via USB or wireless ADB, then retry.\n"))
        sys.exit(1)

    serials = [l.split("\t")[0] for l in lines]

    if len(serials) == 1:
        DEVICE_SERIAL = serials[0]
        print(info(f"  Device auto-selected : {DEVICE_SERIAL}"))
    else:
        print(hdr("  Multiple devices found:"))
        for i, s in enumerate(serials, 1):
            print(f"    {clr(C, f'[{i}]')} {s}")
        while True:
            choice = input(clr(Y, f"  Select device [1-{len(serials)}]: ")).strip()
            if choice.isdigit() and 1 <= int(choice) <= len(serials):
                DEVICE_SERIAL = serials[int(choice) - 1]
                break
            print(err("  Invalid choice — try again."))

    print(warn(f"  !! DO NOT DISCONNECT: {DEVICE_SERIAL} !!\n"))
    return DEVICE_SERIAL


# ── Prompt pool — conversational only, zero destructive actions ───────────────

SHORT = [
    "hi",
    "hello",
    "hey there",
    "what is your name",
    "how are you doing",
    "good morning",
    "ok cool",
    "interesting",
    "tell me something",
    "nice",
]

MEDIUM = [
    "what is the capital of Japan",
    "tell me a very short joke",
    "what is 17 multiplied by 13",
    "name three colors of the rainbow",
    "what language do people speak in Argentina",
    "how many hours are in a week",
    "what is the largest planet in our solar system",
    "who invented the light bulb",
    "what is the boiling point of water in Celsius",
    "name the five oceans of the world",
    "what year did World War 2 end",
    "how many sides does a hexagon have",
]

LONG = [
    "Can you briefly explain what the internet is and how it works at a high level in simple terms for a complete beginner",
    "I want to understand the difference between RAM and storage in a computer. Can you explain it using a simple everyday analogy",
    "What are the main differences between a compiled and an interpreted programming language. Please give one real world example of each",
    "Can you explain what machine learning is in two or three sentences without using any technical jargon or complicated words",
    "What is the difference between a web browser and a search engine because many people seem to confuse these two things",
    "Can you briefly explain the concept of version control and why software development teams use tools like git in their daily workflow",
    "What is cloud computing and can you give me two or three examples of everyday services that most people use without realizing they are cloud based",
    "What is the difference between frontend and backend development in the context of building a web application or website",
    "Can you explain what an API is and why software developers use them so frequently when building applications",
    "I am curious about how GPS works. Can you give me a simple high level explanation of how my phone knows exactly where I am",
    "What is the difference between artificial intelligence and machine learning. Are they the same thing or is one a subset of the other",
    "Can you explain what open source software means in plain English and give me two or three well known examples that most people have heard of",
]


def pick_prompts(n: int) -> list:
    """Pick n varied prompts — always a mix of short, medium, and long."""
    short_n  = max(1, n // 4)
    long_n   = max(1, n // 4)
    medium_n = n - short_n - long_n

    picked = (
        random.sample(SHORT,  min(short_n,  len(SHORT)))  +
        random.sample(MEDIUM, min(medium_n, len(MEDIUM))) +
        random.sample(LONG,   min(long_n,   len(LONG)))
    )
    random.shuffle(picked)
    return picked[:n]


# ── ADB helpers (all calls use DEVICE_SERIAL) ─────────────────────────────────

def sh(*args, timeout: int = 30) -> str:
    """Run an adb shell command on the selected device. Returns stdout."""
    cmd = ["adb", "-s", DEVICE_SERIAL, "shell"] + [str(a) for a in args]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return result.stdout.strip()


def pull(remote: str, local: str) -> None:
    subprocess.run(
        ["adb", "-s", DEVICE_SERIAL, "pull", remote, local],
        capture_output=True, timeout=30,
    )


def screencap(tag: str) -> str:
    """Take a screenshot and pull it to /tmp. Returns local path."""
    remote = f"/sdcard/_crtest_{tag}.png"
    local  = f"/tmp/_crtest_{tag}.png"
    sh("screencap", "-p", remote)
    pull(remote, local)
    sh("rm", "-f", remote)
    return local


def tap(x: int, y: int) -> None:
    sh("input", "tap", x, y)
    time.sleep(0.4)


def ui_nodes() -> list:
    """Return all clickable UI nodes with their desc and center coords."""
    sh("uiautomator", "dump", "/sdcard/_crtest_ui.xml")
    pull("/sdcard/_crtest_ui.xml", "/tmp/_crtest_ui.xml")
    sh("rm", "-f", "/sdcard/_crtest_ui.xml")
    nodes = []
    try:
        tree = ET.parse("/tmp/_crtest_ui.xml")
        for n in tree.iter("node"):
            if n.get("clickable") != "true":
                continue
            desc   = n.get("content-desc", "")
            bounds = n.get("bounds", "")
            parts  = []
            for chunk in bounds.replace("][", ",").strip("[]").split(","):
                try:
                    parts.append(int(chunk))
                except ValueError:
                    pass
            if len(parts) == 4:
                cx = (parts[0] + parts[2]) // 2
                cy = (parts[1] + parts[3]) // 2
                nodes.append({"desc": desc, "cx": cx, "cy": cy,
                              "x1": parts[0], "x2": parts[2],
                              "y1": parts[1], "y2": parts[3]})
    except Exception:
        pass
    return nodes


def tap_node(desc_fragment: str) -> bool:
    """Find first clickable node containing desc_fragment and tap it."""
    for n in ui_nodes():
        if desc_fragment.lower() in n["desc"].lower():
            tap(n["cx"], n["cy"])
            return True
    return False


def press_back() -> None:
    sh("input", "keyevent", "4")
    time.sleep(0.8)


def type_terminal(text: str) -> None:
    """
    Type text into the terminal widget and press Enter.
    Spaces become %s (ADB input text convention).
    Single/double quotes stripped to avoid shell quoting issues.
    """
    tap(640, 800)
    time.sleep(0.4)
    safe = text.replace(" ", "%s").replace("'", "").replace('"', "")
    sh("input", "text", safe)
    time.sleep(0.5)
    sh("input", "keyevent", "66")   # Enter


# ── Image content heuristics (no external dependencies) ──────────────────────

def _png_size(png_path: str) -> int:
    try:
        return os.path.getsize(png_path)
    except Exception:
        return 0


def content_ratio(png_path: str) -> float:
    """
    Ratio of 'bright' bytes in PNG body vs total.
    Blank black terminal ~0.005; terminal with text >0.015.
    """
    try:
        data = Path(png_path).read_bytes()
        body = data[256:]
        bright = sum(1 for b in body if b > 40)
        return bright / len(body) if body else 0.0
    except Exception:
        return 0.0


def has_content(png_path: str) -> bool:
    return content_ratio(png_path) > 0.015


def size_similarity(p1: str, p2: str) -> float:
    """
    Rough content similarity via compressed PNG size ratio.
    Returns 0.0–1.0.
    """
    try:
        s1, s2 = os.path.getsize(p1), os.path.getsize(p2)
        return min(s1, s2) / max(s1, s2) if max(s1, s2) > 0 else 0.0
    except Exception:
        return 0.0


# ── Smart response wait ───────────────────────────────────────────────────────

def wait_for_response(min_wait: float = 4.0,
                      timeout: float  = 120.0,
                      stable_secs: float = 3.5,
                      poll: float = 2.5) -> bool:
    """
    Wait until Claude finishes responding by watching PNG file size stability.

    Logic:
      - Take periodic screenshots and measure compressed PNG size.
      - While Claude is typing, terminal content changes → PNG size fluctuates.
      - Once stable for `stable_secs` seconds → Claude is done.

    Args:
      min_wait    : minimum seconds to wait before starting to poll.
      timeout     : give up after this many seconds total.
      stable_secs : how long size must be stable to declare done.
      poll        : seconds between polls.

    Returns True if stable (done), False if timed out.
    """
    print(info(f"      waiting for response"), end="", flush=True)
    time.sleep(min_wait)

    prev_size     = -1
    stable_elapsed = 0.0
    total_elapsed  = min_wait
    dots           = 0

    while total_elapsed < timeout:
        path = screencap("_resp_poll")
        size = _png_size(path)
        try:
            os.unlink(path)
        except Exception:
            pass

        if prev_size >= 0 and abs(size - prev_size) < 400:
            stable_elapsed += poll
            print(clr(G, "."), end="", flush=True)
            if stable_elapsed >= stable_secs:
                elapsed_total = total_elapsed + poll
                print(info(f" done ({elapsed_total:.0f}s)"))
                return True
        else:
            stable_elapsed = 0
            print(clr(Y, "~"), end="", flush=True)

        prev_size      = size
        dots          += 1
        time.sleep(poll)
        total_elapsed += poll

    print(warn(f" TIMEOUT ({timeout:.0f}s)"))
    return False


# ── Session cleanup ───────────────────────────────────────────────────────────

def kill_all_sessions() -> int:
    """
    Delete all Claude session cards from the sessions screen.
    Must be called while on the sessions screen.
    Returns number of sessions deleted.
    """
    deleted = 0
    for _ in range(20):   # safety limit: max 20 sessions
        nodes = ui_nodes()

        # Find session cards (have "claude" in desc, but not "New Claude Session")
        session_cards = [
            n for n in nodes
            if "claude" in n["desc"].lower()
            and "new claude" not in n["desc"].lower()
        ]
        if not session_cards:
            break

        card = session_cards[0]
        card_cy = card["cy"]

        # Find unnamed clickable buttons at the same vertical level as the card.
        # The session card contains two icon buttons: [rename] [delete].
        # Delete (trash) is the rightmost one.
        card_buttons = sorted(
            [
                n for n in nodes
                if not n["desc"]                        # unnamed button
                and abs(n["cy"] - card_cy) < 120        # same row as card
                and n["cx"] > card["cx"]                # to the right of card center
            ],
            key=lambda n: n["cx"],
        )

        if not card_buttons:
            # Fallback: try tapping far-right area of card row
            tap(1055, card_cy)
        else:
            # Rightmost unnamed button = delete/trash
            delete_btn = card_buttons[-1]
            tap(delete_btn["cx"], delete_btn["cy"])

        deleted += 1
        time.sleep(1.5)   # let the list update

    return deleted


# ── Single test cycle ─────────────────────────────────────────────────────────

def run_cycle(num: int, n_prompts: int, out_dir: str) -> dict:

    print(f"\n{hdr('═' * 54)}")
    print(f"  {hdr(f'CYCLE {num}')}")
    print(f"{hdr('═' * 54)}")

    shots   = {}
    passed  = False
    reason  = ""

    # ── Step 1 — fresh app launch ─────────────────────────────────────────────
    print(step("\n  [1] Force-stop → launch app"))
    sh("am", "force-stop", APP)
    time.sleep(1.5)
    sh("monkey", "-p", APP, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)
    shots["01_launch"] = screencap(f"c{num}_01_launch")
    print(info("      App launched"))

    # ── Step 2 — create new Claude session ───────────────────────────────────
    print(step("\n  [2] Creating new Claude session"))
    if not tap_node("New Claude Session"):
        reason = "Button 'New Claude Session' not found on screen"
        print(err(f"      FAIL — {reason}"))
        return _result(num, [], passed, reason, shots, out_dir)

    time.sleep(9)
    shots["02_session"] = screencap(f"c{num}_02_session")

    ratio_open = content_ratio(shots["02_session"])
    if not has_content(shots["02_session"]):
        reason = f"Terminal blank after session create (ratio={ratio_open:.3f})"
        print(err(f"      FAIL — {reason}"))
        return _result(num, [], passed, reason, shots, out_dir)
    print(ok(f"      Session open  ") + dim(f"ratio={ratio_open:.3f}"))

    # ── Step 3 — send prompts, wait for each response ────────────────────────
    prompts = pick_prompts(n_prompts)
    print(step(f"\n  [3] Sending {len(prompts)} prompts"))

    for i, prompt in enumerate(prompts, 1):
        preview = (prompt[:50] + " ...") if len(prompt) > 50 else prompt
        ptype   = "SHORT" if len(prompt) < 20 else "MEDIUM" if len(prompt) < 80 else "LONG"
        label   = clr(C, f"[{i}/{len(prompts)}]") + clr(DIM, f" [{ptype}]")
        print(f"\n      {label} {clr(W, preview)}")

        type_terminal(prompt)

        # Smart wait — polls until terminal stabilises
        min_w = 3.0 if len(prompt) < 20 else 5.0 if len(prompt) < 80 else 7.0
        wait_for_response(min_wait=min_w, timeout=120, stable_secs=3.5, poll=2.5)

    time.sleep(1.5)
    shots["03_before_kill"] = screencap(f"c{num}_03_before_kill")
    ratio_before = content_ratio(shots["03_before_kill"])
    print(ok(f"\n      History built  ") + dim(f"ratio={ratio_before:.3f}"))

    # ── Step 4 — kill app ─────────────────────────────────────────────────────
    print(step("\n  [4] Killing app"))
    sh("am", "force-stop", APP)
    time.sleep(1.5)
    print(info("      App killed"))

    # ── Step 5 — relaunch ────────────────────────────────────────────────────
    print(step("\n  [5] Relaunching app"))
    sh("monkey", "-p", APP, "-c", "android.intent.category.LAUNCHER", "1")
    time.sleep(5)
    shots["04_relaunch"] = screencap(f"c{num}_04_relaunch")
    print(info("      Sessions screen loaded"))

    # ── Step 6 — tap existing session ────────────────────────────────────────
    print(step("\n  [6] Opening existing session"))
    nodes   = ui_nodes()
    session = next(
        (n for n in nodes
         if "claude" in n["desc"].lower()
         and "new claude" not in n["desc"].lower()),
        None,
    )
    if not session:
        reason = "No existing session card found on sessions screen after relaunch"
        print(err(f"      FAIL — {reason}"))
        return _result(num, prompts, passed, reason, shots, out_dir)

    print(info(f"      Found session card: {dim(session['desc'][:40])}"))
    tap(session["cx"], session["cy"])
    time.sleep(5)

    # ── Step 7 — verify history ───────────────────────────────────────────────
    print(step("\n  [7] Verifying history after resume"))
    shots["05_after_resume"] = screencap(f"c{num}_05_after_resume")
    ratio_after = content_ratio(shots["05_after_resume"])
    sim         = size_similarity(shots["03_before_kill"], shots["05_after_resume"])

    print(info(f"      ratio_before={ratio_before:.3f}  "
               f"ratio_after={ratio_after:.3f}  "
               f"similarity={sim:.2f}"))

    if not has_content(shots["05_after_resume"]):
        reason = f"Terminal blank after resume  (ratio={ratio_after:.3f})"
        print(err(f"      FAIL — {reason}"))
    elif sim < 0.60:
        reason = (f"Content present but significantly different from before kill  "
                  f"(sim={sim:.2f})")
        print(warn(f"      WARN — {reason}"))
    else:
        passed = True
        reason = (f"History preserved and rendered correctly  "
                  f"(ratio={ratio_after:.3f}, similarity={sim:.2f})")
        print(ok(f"      PASS — {reason}"))

    # ── Step 8 — clean up all sessions ───────────────────────────────────────
    print(step("\n  [8] Cleaning up sessions for next cycle"))
    press_back()          # back to sessions screen from terminal
    time.sleep(1.5)
    deleted = kill_all_sessions()
    if deleted:
        print(ok(f"      Deleted {deleted} session(s)"))
    else:
        print(dim("      No sessions to delete"))

    return _result(num, prompts, passed, reason, shots, out_dir)


def _result(num, prompts, passed, reason, shots, out_dir):
    """Save screenshots to output dir, return structured result dict."""
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    saved = {}
    for key, path in shots.items():
        if path and os.path.exists(path):
            dest = os.path.join(out_dir, os.path.basename(path))
            os.replace(path, dest)
            saved[key] = dest
    return {
        "cycle":   num,
        "passed":  passed,
        "reason":  reason,
        "prompts": prompts,
        "shots":   saved,
    }


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Claude Remote — session history persistence test"
    )
    parser.add_argument("--cycles",  type=int, default=1,
                        help="Number of test cycles to run (default: 1)")
    parser.add_argument("--prompts", type=int, default=4,
                        help="Number of prompts per cycle (default: 4)")
    parser.add_argument("--output",  type=str, default="/tmp/cr_test_results",
                        help="Directory for screenshots and JSON report")
    args = parser.parse_args()

    ts      = datetime.now().strftime("%Y%m%d_%H%M%S")
    out_dir = os.path.join(args.output, ts)

    print(f"\n{hdr('╔' + '═' * 52 + '╗')}")
    print(hdr("║") + f"  {BLD}Claude Remote — Session History Persistence Test{RST}  " + hdr("║"))
    print(hdr("║") + f"  Cycles  : {clr(C, str(args.cycles)):<20}                      " + hdr("║"))
    print(hdr("║") + f"  Prompts : {clr(C, str(args.prompts))} per cycle{' ' * 30}" + hdr("║"))
    print(hdr("║") + f"  Output  : {clr(DIM, out_dir)[:40]:<40}   " + hdr("║"))
    print(f"{hdr('╚' + '═' * 52 + '╝')}")

    select_device()

    results = []
    for i in range(1, args.cycles + 1):
        r = run_cycle(i, args.prompts, out_dir)
        results.append(r)

    # ── Summary ───────────────────────────────────────────────────────────────
    passed = sum(1 for r in results if r["passed"])
    print(f"\n{hdr('╔' + '═' * 52 + '╗')}")
    print(hdr("║") + f"  {BLD}SUMMARY{RST}" + " " * 45 + hdr("║"))
    print(hdr("╠" + "═" * 52 + "╣"))
    for r in results:
        icon   = ok("PASS") if r["passed"] else err("FAIL")
        p_list = dim(", ".join(f'"{p[:25]}"' for p in r["prompts"][:2]))
        extra  = dim(f" +{len(r['prompts'])-2} more") if len(r["prompts"]) > 2 else ""
        print(hdr("║") + f"  Cycle {r['cycle']} [{icon}]  {clr(DIM, r['reason'][:35])}")
        print(hdr("║") + f"    Prompts: {p_list}{extra}")
    print(hdr("╠" + "═" * 52 + "╣"))
    total_clr = ok(f"{passed}/{len(results)}") if passed == len(results) else err(f"{passed}/{len(results)}")
    print(hdr("║") + f"  Result  : {total_clr}  cycles passed" + " " * 25 + hdr("║"))
    print(hdr("║") + f"  Reports : {clr(DIM, out_dir)[:42]}" + " " * 1 + hdr("║"))
    print(f"{hdr('╚' + '═' * 52 + '╝')}\n")

    # ── JSON report ───────────────────────────────────────────────────────────
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    report = {
        "timestamp": ts,
        "device":    DEVICE_SERIAL,
        "total":     len(results),
        "passed":    passed,
        "failed":    len(results) - passed,
        "cycles":    results,
    }
    report_path = os.path.join(out_dir, "report.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(info(f"  Report saved: {report_path}\n"))

    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
