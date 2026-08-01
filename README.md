# Amiga 3DToolbox

Amiga 3DToolbox is a small 3D-printing toolbox for classic Amiga systems.

It started as a way to control an OctoPrint server from an Amiga, because modern
OctoPrint web pages are not usable on classic Amiga browsers. The project then
grew into a set of tools around 3D printing: OctoPrint control, G-code utilities,
STL conversion/viewing helpers, Raspberry Pi temperature monitoring, and a PC
slicer bridge.

The software was developed and tested with:

- Amiga 1200 PiStorm / Emu68
- Amiga 1200 Tower 68060
- WinUAE
- OctoPrint on Raspberry Pi
- WEEDO / Entina Tina2S 3D printer

Other OctoPrint-compatible printers should work with adaptation and testing.

## Main Tools

### OctoControlSpeak

MUI client for OctoPrint.

Features:

- connect to OctoPrint through the local network
- read printer status and temperatures
- upload G-code files
- start uploaded files
- pause, resume and cancel a print
- home axes
- motors off
- heat off
- emergency command
- filament heat, insert and retract commands
- optional speech feedback through `SAY` / `narrator.device`
- French and English versions

Note: the OctoPrint file list is intentionally read with a limited buffer to
remain stable on classic Amiga systems. If OctoControlSpeak reports a partial
file list, remove old G-code files from OctoPrint and prefer short file names.

### PiTempMUI

Small MUI client used to read the temperature of a Raspberry Pi running a tiny
Python server.

Useful when OctoPrint runs on a Raspberry Pi inside a small case.

### GCodeColorPauseMUI

Utility to insert a color-change pause in a G-code file.

Designed mainly for single-extruder printers. The generated pause sequence lets
the user manually change filament, then continue the print.

The automatic output name uses a short suffix:

```text
example.gcode -> example_color.gcode
```

This keeps generated G-code names shorter and easier for OctoControlSpeak and
classic Amiga file lists.

### DDD2STLMUI

MUI frontend to convert Amiga 3D data handled by `ddd.library` to ASCII STL.

Useful for moving old Amiga 3D objects toward a modern slicer workflow.

### 3DView

3D viewer based on the work of Andre Capus.

This package includes and credits the original 3DView / `ddd.library` work, with
additional STL-related experiments and integration for the toolbox workflow.

### SlicerMUI / Slicer Bridge

Network bridge between the Amiga and a PC running a Python server.

Typical workflow:

1. Select an STL on the Amiga.
2. Send it to the PC slicer server.
3. The PC runs PrusaSlicer from the command line.
4. The generated G-code is sent back to the Amiga.
5. The G-code can then be sent to OctoPrint with OctoControlSpeak.

### Text2STLMUI

Creates simple text-based STL objects on the Amiga.

It supports a built-in pixel style and selected Amiga fonts, depending on what
prints cleanly.

### ZSetupMUI

Small helper for Z-offset setup.

Warning: this tool sends printer movement and Z-offset commands. Use it only if
you understand the values required by your printer. Wrong Z values can make the
nozzle hit the bed.

## Requirements

On the Amiga side:

- AmigaOS 3.x compatible system
- MUI
- TCP/IP stack such as Miami, AmiTCP or Roadshow
- `bsdsocket.library`
- `bsdsocket.m` module for compiling the AmigaE sources
- AmigaE compiler if you want to rebuild the sources
- Optional: `translator.library`, `narrator.device`, `SAY`, and voice data for speech

For OctoControlSpeak:

- OctoPrint reachable on the local network
- OctoPrint API key
- printer already configured in OctoPrint

For Slicer Bridge:

- PC on the same local network
- Python 3
- PrusaSlicer
- a working PrusaSlicer printer profile for your printer
- `slicer_server.py` configured with the PC paths and allowed Amiga IP address

## Amiga Installation

The archive includes an Amiga Installer script named `Install`.

It can:

- ask for the installation location
- create the `3DToolbox` drawer if needed
- copy the Amiga tools and documentation
- copy the PC/Pi server explanations and scripts
- optionally install the AmigaE source drawer
- create `S:3DToolbox-startup`
- show the line to add manually to `S:User-startup`

The assign used by the tools is:

```text
Assign 3DToolbox: SYS:Tools/3DToolbox
```

The destination path depends on the drawer selected during installation.

For safety, the installer does not modify `S:User-startup` directly. To make
the assign permanent after reboot, add this line manually:

```text
Execute S:3DToolbox-startup
```

## OctoPrint API Key

To use OctoControlSpeak, create or copy an OctoPrint API key from a modern
browser on a PC:

1. Open OctoPrint in a web browser.
2. Go to `Settings`.
3. Open `Application Keys` or `API`.
4. Create or copy an API key.
5. Put the IP address, port and API key in the OctoControl configuration file.

The Amiga does not need to display the OctoPrint web interface after this first
configuration step.

## Configuration Files

Configuration examples are provided in the package.

Typical files:

- `octocontrol_native.cfg`
- `octocontrol_speech.cfg`
- `octocontrol_speech_en.cfg`
- `pitemp.cfg`
- `slicer_server.cfg`

Keep your real OctoPrint API key private. Do not publish a configuration file
containing your personal key.

## Current Notes

- OctoControlSpeak keeps the OctoPrint file list stable by limiting the amount
  of JSON read from OctoPrint.
- If `(partial list: too many files)` or `liste partielle: trop de fichiers`
  appears, clean old G-code files from OctoPrint or use shorter file names.
- GCodeColorPauseMUI now generates shorter names such as `part_color.gcode`
  instead of long layer-based names.

## Security Notes

The slicer server is intended for a trusted local network.

Recommended:

- bind the server only to the needed network interface when possible
- configure allowed client IP addresses
- do not expose the slicer server to the internet
- do not publish your OctoPrint API key

## Repository Layout

Suggested layout:

```text
Amiga-3DToolbox/
  README.md
  LICENSE
  Docs/              HTML documentation in French
  Docs_EN/           HTML documentation in English
  amiga_sources/
  pc_python_servers/
  pc_python_tools/
  screenshots/
  examples_and_assets/
  releases/
  third_party_3DView_Andre_Capus/
```

## Credits

Project idea, testing and Amiga hardware workflow:

- Denis Costils

3DView and original `ddd.library` work:

- Andre Capus

Development assistance:

- OpenAI Codex

OctoPrint:

- The OctoPrint project and contributors

## French Summary

Amiga 3DToolbox est une boite a outils pour piloter et preparer des impressions
3D depuis un Amiga classique.

Le programme principal, OctoControlSpeak, permet de controler OctoPrint sans
navigateur moderne. L'Amiga peut envoyer un G-code, lancer une impression,
suivre les temperatures, faire pause/reprise, annuler, faire un home, couper les
moteurs, chauffer la buse, gerer le filament et annoncer certains evenements par
la voix avec `SAY`.

La toolbox contient aussi des outils pour le changement de couleur dans un
G-code, la conversion STL, la visualisation 3D, le suivi de temperature du
Raspberry Pi et un pont reseau vers un PC pour lancer PrusaSlicer.

Ce projet est tres niche, mais il montre qu'un Amiga peut encore s'integrer dans
un flux de travail moderne autour de l'impression 3D.

## Disclaimer

This software controls real hardware.

Use it carefully. Always supervise a 3D printer while testing new commands,
G-code files or Z-offset settings. The author is not responsible for damaged
hardware, failed prints or wrong printer configuration.
