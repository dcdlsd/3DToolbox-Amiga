SlicerServer - PC bridge for PrusaSlicer
========================================

This small Python script runs on the PC and allows another machine, for example
an Amiga, to ask the PC to slice an STL file with PrusaSlicer.

File:
  slicer_server.py
  slicer_server.cfg

Requirements
------------

- Python 3 on the PC.
- PrusaSlicer installed here:
  C:\Program Files\Prusa3D\PrusaSlicer\prusa-slicer-console.exe
- a PrusaSlicer printer profile exported as an .ini file

Start manually
--------------

From PowerShell, in the folder containing this file:

  python .\slicer_server.py

The server starts on port 18090:

  http://PC_IP:18090/

Configuration
-------------

The server reads slicer_server.cfg from the same drawer as slicer_server.py.
If the file does not exist, it is created automatically.

Example:

  HOST=0.0.0.0
  PORT=18090
  ALLOWED_CLIENTS=127.0.0.1,IP_DE_VOTRE_AMIGA
  MAX_UPLOAD_MB=64
  ALLOW_PC_PATHS=no
  PRUSA_EXE=C:\Program Files\Prusa3D\PrusaSlicer\prusa-slicer-console.exe
  BASE_DIR=C:\SlicerBridge
  PROFILE_STANDARD=C:\Users\YourName\AppData\Roaming\PrusaSlicer\Your_Printer_Profile.ini

HOST=0.0.0.0 means that the PC accepts connections from the local network.
ALLOWED_CLIENTS limits which machines may use the server. For normal use, put
127.0.0.1 and your real Amiga IP address only. Replace IP_DE_VOTRE_AMIGA with
the Amiga address used on your network, for example 192.168.1.xxx. You may also
use a network such as 192.168.1.0/24, but this is less restrictive.
MAX_UPLOAD_MB limits the accepted STL upload size.
ALLOW_PC_PATHS=no is safer: remote machines must upload an STL to the hotfolder
instead of asking the server to read arbitrary PC paths.
BASE_DIR is the PC hotfolder used by the server.
PROFILE_STANDARD is the PrusaSlicer profile used by SlicerMUI.

The server creates a hotfolder here:

  SlicerBridge\in
  SlicerBridge\out
  SlicerBridge\done
  SlicerBridge\error

Before slicing, the server reads the STL dimensions and compares them with the
PrusaSlicer bed size. It also keeps a print margin for the PrusaSlicer skirt or
brim, so the generated G-code does not go outside the Tina2S bed. If the model
is too large for the safe print area, slicing is refused with a clear error
message.

You can also ask only for the STL dimensions:

  http://127.0.0.1:18090/stl-info?path=G:/modele.stl&profile=standard&scale=100

The answer contains:

  STL_SIZE: width x depth x height mm
  APPLIED_SCALE: xx.x%
  SCALED_SIZE: width x depth x height mm
  BED_SIZE: width x depth mm
  PRINT_MARGIN: x.x mm
  SAFE_BED_SIZE: width x depth mm
  SUGGESTED_SCALE: xx.x%
  COLOR_HINT: RAISED_TEXT
  COLOR_Z: x.xxx mm
  COLOR_ACTION: change color near COLOR_Z after slicing

For a simple STL made from a flat base with raised text, COLOR_Z is the height
where the text starts. This is useful for a two-color print: print the base in
one color, then pause/change filament before the text begins.

After slicing, PrusaSlicer can still print the last top skin of the base on
the first layer at COLOR_Z. For this reason, INSERT_COLOR_LAYER is adjusted to
the next useful layer when possible.

When slicing, the server creates a temporary STL in SlicerBridge\work. This
temporary STL is scaled, moved to Z=0, and centered on the bed. The bed center
is calculated from the bed_shape of the selected PrusaSlicer profile.

Quick tests from the PC browser
-------------------------------

Server status:

  http://127.0.0.1:18090/status

Available profiles:

  http://127.0.0.1:18090/profiles

Slice a PC file directly, only if ALLOW_PC_PATHS=yes:

  http://127.0.0.1:18090/slice?input=G:/modele.stl&output=G:/Sortie.gcode&profile=standard&scale=100

The answer gives a job ID, for example:

  STATUS: RUNNING
  ID: 1

Check the job:

  http://127.0.0.1:18090/job?id=1

When the job is finished, the answer can also contain:

  COLOR_LAYER_0: n
  COLOR_LAYER_1: n
  COLOR_LAYER_Z: x.xxx mm
  INSERT_COLOR_LAYER: n
  INSERT_COLOR_Z: x.xxx mm

COLOR_LAYER_0 is zero-based. COLOR_LAYER_1 is the same layer counted from 1,
which is usually easier to read for humans. These lines describe the first
layer detected at the text height.
INSERT_COLOR_LAYER is the corrected value to use in GCodeColorPauseMUI.

Check the last job:

  http://127.0.0.1:18090/last

Hotfolder upload / download
---------------------------

Upload an STL with a raw HTTP POST:

  POST http://127.0.0.1:18090/upload?name=modele.stl

Upload and slice immediately:

  POST http://127.0.0.1:18090/upload-and-slice?name=modele.stl&profile=standard&scale=100

The STL is stored in:

  SlicerBridge\in

The generated G-code is stored in:

  SlicerBridge\out

When the job is OK, the answer contains:

  DOWNLOAD: /download?id=1

Download the G-code:

  http://127.0.0.1:18090/download?id=1

You can also slice a file already uploaded:

  http://127.0.0.1:18090/slice-uploaded?name=modele.stl&profile=standard

Notes
-----

The server does not modify OctoPrint.
The server does not need any external Python module.
For paths with spaces, replace spaces with %20 in the URL.
Port used: 18090.
