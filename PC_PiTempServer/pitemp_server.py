#!/usr/bin/env python3
"""
PiTempServer - tiny Raspberry Pi temperature HTTP server.

Copy this file to the Raspberry Pi / OctoPi and run it with Python 3.

Example:
    python3 pitemp_server.py

Then open:
    http://PI_IP:8088/temp

The answer is a simple text value, for example:
    43.5
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import subprocess
import sys

HOST = "0.0.0.0"
PORT = 8088


def read_pi_temperature():
    """Return Raspberry Pi temperature in Celsius as a string like '43.5'."""
    commands = [
        ["vcgencmd", "measure_temp"],
        ["/opt/vc/bin/vcgencmd", "measure_temp"],
    ]

    for command in commands:
        try:
            output = subprocess.check_output(
                command,
                stderr=subprocess.STDOUT,
                timeout=3,
                text=True,
            ).strip()
        except Exception:
            continue

        # vcgencmd returns: temp=43.5'C
        if output.startswith("temp="):
            value = output.split("=", 1)[1].split("'", 1)[0]
            return value

    # Fallback for Linux systems exposing the thermal zone.
    try:
        with open("/sys/class/thermal/thermal_zone0/temp", "r", encoding="ascii") as handle:
            raw = handle.read().strip()
        return f"{int(raw) / 1000:.1f}"
    except Exception as exc:
        raise RuntimeError("Unable to read Raspberry Pi temperature") from exc


class PiTempHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/temp"):
            self.send_response(404)
            self.send_header("Content-Type", "text/plain; charset=ascii")
            self.end_headers()
            self.wfile.write(b"Not found\n")
            return

        try:
            temperature = read_pi_temperature()
            body = f"{temperature}\n".encode("ascii")
            self.send_response(200)
        except Exception as exc:
            body = f"ERROR: {exc}\n".encode("ascii", errors="replace")
            self.send_response(500)

        self.send_header("Content-Type", "text/plain; charset=ascii")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Keep the console quiet.
        return


def main():
    server = HTTPServer((HOST, PORT), PiTempHandler)
    print(f"PiTempServer running on http://{HOST}:{PORT}/temp")
    print("Press Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping PiTempServer.")
    finally:
        server.server_close()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
