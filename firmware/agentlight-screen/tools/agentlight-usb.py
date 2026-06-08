#!/usr/bin/env python3
"""agentlight-usb.py — talk to an AgentLight screen over USB serial (setup only).

The user's AI agent calls this during onboarding so it never hand-rolls serial I/O.
Everything prints a single JSON line on stdout.

  find                                  locate the device (scans /dev/cu.*); ->
                                        {"port","id","wifi","ip"} or {"error":..}
  id        [--port P]                  read device status
  provision --ssid S --pass P [--port P]  write WiFi creds, wait for connect ->
                                        {"ok":true,"ip":..} / {"ok":false,"error":..}

Requires pyserial.  python3 agentlight-usb.py find
"""
import sys, glob, time, json, argparse

try:
    import serial
except ImportError:
    print(json.dumps({"error": "pyserial not installed (pip install pyserial)"}))
    sys.exit(2)

BAUD = 115200


def candidate_ports():
    return [p for p in glob.glob("/dev/cu.*")
            if any(k in p for k in ("usbmodem", "usbserial", "wchusb"))]


def _open(port):
    return serial.Serial(port, BAUD, timeout=0.5)


def read_banner(port, timeout=3.0):
    """Return the parsed self-announce banner dict, or None."""
    try:
        s = _open(port)
    except Exception:
        return None
    try:
        end = time.time() + timeout
        while time.time() < end:
            line = s.readline().decode(errors="replace").strip()
            if line.startswith("AGENTLIGHT"):
                kv = {}
                for tok in line.split()[1:]:
                    if "=" in tok:
                        k, v = tok.split("=", 1)
                        kv[k] = v
                return kv
    finally:
        s.close()
    return None


def find():
    for port in candidate_ports():
        kv = read_banner(port)
        if kv and "id" in kv:
            return {"port": port, **kv}
    return {"error": "no AgentLight device found on USB"}


def resolve_port(arg):
    if arg:
        return arg
    f = find()
    return f.get("port")


def cmd_and_reply(port, payload, reply_timeout):
    """Send one JSON command line; return the first {...} JSON reply line parsed."""
    try:
        s = _open(port)
    except Exception as e:
        return {"ok": False, "error": f"open failed: {e}"}
    try:
        s.write((json.dumps(payload) + "\n").encode())
        s.flush()
        end = time.time() + reply_timeout
        while time.time() < end:
            line = s.readline().decode(errors="replace").strip()
            if line.startswith("{"):
                try:
                    return json.loads(line)
                except Exception:
                    continue
        return {"ok": False, "error": "no reply (timeout)"}
    finally:
        s.close()


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="action", required=True)
    sub.add_parser("find")
    p_id = sub.add_parser("id"); p_id.add_argument("--port")
    p_pv = sub.add_parser("provision")
    p_pv.add_argument("--ssid", required=True)
    p_pv.add_argument("--pass", dest="password", required=True)
    p_pv.add_argument("--port")
    args = ap.parse_args()

    if args.action == "find":
        print(json.dumps(find())); return

    port = resolve_port(getattr(args, "port", None))
    if not port:
        print(json.dumps({"error": "device not found; pass --port"})); sys.exit(1)

    if args.action == "id":
        print(json.dumps(cmd_and_reply(port, {"cmd": "id"}, 3))); return

    if args.action == "provision":
        # Device tries for ~20s, so wait a little longer for its reply.
        print(json.dumps(cmd_and_reply(
            port, {"cmd": "wifi", "ssid": args.ssid, "pass": args.password}, 25)))
        return


if __name__ == "__main__":
    main()
