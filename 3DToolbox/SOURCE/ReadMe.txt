Short: Amiga 3D printing toolbox with OctoPrint, STL and G-code tools
Author: Denis Costils
Contact: costils.denis@free.fr
Type: gfx/3d

Amiga 3DToolbox is a small 3D-printing toolbox for classic Amiga systems.

It started as OctoControlSpeak, an Amiga MUI client for OctoPrint, because
modern OctoPrint web pages are not usable on classic Amiga browsers. The
project then grew into a complete toolbox around 3D printing: OctoPrint
control, G-code utilities, STL conversion/viewing helpers, Raspberry Pi
temperature monitoring, text-to-STL generation, and a PC slicer bridge.

TESTED SYSTEMS

- Amiga 1200 PiStorm / Emu68
- Amiga 1200 Tower 68060
- WinUAE
- OctoPrint on Raspberry Pi
- WEEDO / Entina Tina2S 3D printer

PiStorm / Emu68 is recommended for the most comfortable use. On 68060 systems,
large STL or G-code operations can be slower, but the tools remain usable.


MAIN TOOLS

OctoControlSpeak
----------------

MUI client for OctoPrint.

Features:

- connect to OctoPrint through the local network
- save OctoPrint IP address, port and API key
- read printer status, temperatures and current job data
- upload G-code files from the Amiga
- start uploaded files
- list and delete OctoPrint files
- pause, resume and cancel print jobs
- home axes, motors off, heat off
- filament heat, insert and retract commands
- emergency M112 command
- optional speech feedback through SAY / narrator.device
- French and English versions


PiTempMUI
---------

Small MUI client used to read the temperature of a Raspberry Pi running a tiny
Python server.

Useful when OctoPrint runs on a Raspberry Pi inside a small case.


GCodeColorPauseMUI
------------------

Utility to insert a color-change pause in a G-code file.

Designed mainly for single-extruder printers. The generated pause sequence lets
the user manually change filament, then continue the print.


DDD2STLMUI
----------

MUI frontend to convert Amiga 3D data handled by ddd.library to ASCII STL.

Useful for moving old Amiga 3D objects toward a modern slicer workflow.


3DView
------

3D viewer based on the work of Andre Capus.

This package includes and credits the original 3DView / ddd.library work, with
additional STL-related experiments and integration for the toolbox workflow.


SlicerMUI / Slicer Bridge
-------------------------

Network bridge between the Amiga and a PC running a Python server.

Typical workflow:

1. Select an STL on the Amiga.
2. Send it to the PC slicer server.
3. The PC runs PrusaSlicer from the command line.
4. The generated G-code is sent back to the Amiga.
5. The G-code can then be sent to OctoPrint with OctoControlSpeak.


Text2STLMUI
-----------

Creates simple text-based STL objects on the Amiga.

It supports a built-in pixel style and selected Amiga fonts, depending on what
prints cleanly.


ZSetupMUI
---------

Small helper for Z-offset setup.

WARNING: this tool sends printer movement and Z-offset commands. Use it only if
you understand the values required by your printer. Wrong Z values can make the
nozzle hit the bed.


REQUIREMENTS

Amiga side:

- AmigaOS 3.x compatible system
- MUI
- TCP/IP stack such as Miami, AmiTCP or Roadshow
- bsdsocket.library
- AmigaE compiler if you want to rebuild the sources
- needed AmigaE modules such as bsdsocket.m, ddd.m and related modules

For OctoControlSpeak:

- OctoPrint reachable on the local network
- OctoPrint API key
- printer already configured in OctoPrint

For Slicer Bridge:

- PC on the same local network
- Python 3
- PrusaSlicer
- a working PrusaSlicer printer profile for your printer
- slicer_server.py configured with PC paths and allowed Amiga IP address

Optional speech support:

- C:Say
- DEVS:narrator.device
- L:Speak-Handler
- LIBS:translator.library
- SPEAK: mounted

translator42 is recommended for better speech support:

  https://aminet.net/package/util/libs/translator42

For French speech, the 0Paris accent package can improve pronunciation:

  https://aminet.net/package/util/libs/ax_0Paris


CONFIGURATION FILES

Configuration examples are provided in the package.

Typical files:

- octocontrol_native.cfg.example
- octocontrol_speech.cfg.example
- octocontrol_speech_en.cfg.example
- pitemp.cfg.example
- slicer_server.cfg

Keep your real OctoPrint API key private. Do not publish a configuration file
containing your personal key.


OCTOPRINT API KEY

To use OctoControlSpeak, create or copy an OctoPrint API key from a modern
browser on a PC:

1. Open OctoPrint in a web browser.
2. Go to Settings.
3. Open Application Keys or API.
4. Create or copy an API key.
5. Put the IP address, port and API key in the OctoControl configuration file.

Example S:octocontrol_native.cfg:

  OCTOPRINT=192.168.1.100:80
  APIKEY=PASTE_YOUR_OCTOPRINT_API_KEY_HERE

The Amiga does not need to display the OctoPrint web interface after this first
configuration step.


SECURITY NOTES

Never distribute your real S:octocontrol_native.cfg file. It contains your
private OctoPrint API key.

The slicer server is intended for a trusted local network.

Recommended:

- configure ALLOWED_CLIENTS with only your Amiga IP address
- do not expose slicer_server.py to the internet
- do not publish your OctoPrint API key
- keep a backup of your working configuration files


SOURCE NOTES

This SOURCE drawer contains AmigaE sources and support files used by the
toolbox.

The ddd_stl_patch drawer contains the modified ddd.library source work used for
STL support. The original 3DView / ddd.library work is credited to Andre Capus.


CREDITS

Project idea, testing and Amiga hardware workflow:

- Denis Costils

3DView and original ddd.library work:

- Andre Capus

Development assistance:

- OpenAI Codex

Thanks to the Amiga, OctoPrint, MUI, AmigaE, AmiTCP, Aminet and retro-computing
communities, and to all users who keep classic Amiga systems alive.


DISCLAIMER

This software controls real hardware.

Use it carefully. Always supervise a 3D printer while testing new commands,
G-code files, Z-offset changes or emergency/reconnect workflows.

This package is supplied as freeware with source code included.
