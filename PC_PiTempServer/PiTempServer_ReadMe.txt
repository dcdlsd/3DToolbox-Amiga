PiTempServer - Raspberry Pi temperature server
================================================

This small Python script runs on the Raspberry Pi / OctoPi and returns the
CPU temperature through a simple HTTP request.

File:
  pitemp_server.py

Copy to the Raspberry Pi
------------------------

With FileZilla/SFTP, copy pitemp_server.py to:

  /home/pi/pitemp_server.py

Or from a PC command line:

  scp pitemp_server.py pi@192.168.1.162:/home/pi/

Replace 192.168.1.162 with your OctoPi IP address.

Start manually
--------------

Connect by SSH:

  ssh pi@192.168.1.162

Run:

  python3 /home/pi/pitemp_server.py

Test from a browser or from another machine:

  http://192.168.1.162:8088/temp

Expected answer:

  43.5

Stop manually
-------------

Press Ctrl+C in the SSH window.

Notes
-----

This script does not modify OctoPrint.
This script does not need any external Python module.
Port used: 8088.

