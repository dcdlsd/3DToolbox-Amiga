Short: Speaking Amiga MUI client for OctoPrint
Author: Denis Costils
Contact: costils.denis@free.fr
Version: 0.3
Type: comm/misc

OctoControl Speak is an AmigaE/MUI application for controlling an OctoPrint
server from a classic Amiga. It is intended for Amiga systems where the modern
OctoPrint web interface cannot be used comfortably in an Amiga web browser.

This version can also speak printer events through the Amiga speech system
using SAY, narrator.device and translator.library.

FEATURES

- Saves the OctoPrint IP address, port and API key.
- Tests the OctoPrint connection and reconnects the printer.
- Displays printer status, nozzle and bed temperatures, and current job data.
- Opens a small monitor window with automatic refresh.
- Mini mode keeps only the monitor window visible.
- Lists G-code files stored in OctoPrint and starts a selected file.
- Deletes a selected G-code file from OctoPrint.
- Uploads G-code files from the Amiga, with optional immediate printing.
- Home, motors off, preheat, heaters off, filament insert and retract.
- Pause, resume and cancel print jobs.
- Emergency M112 button.
- Speech messages for important events.
- Speech text can be edited without recompiling.

REQUIREMENTS

- AmigaOS 3.x or compatible system.
- MUI installed.
- AmiTCP compatible bsdsocket.library.
- An OctoPrint server reachable on the local network.
- AmigaE 3.3 or compatible compiler, only needed to compile the source.

For speech:

- C:Say
- DEVS:narrator.device
- L:Speak-Handler
- LIBS:translator.library
- SPEAK: mounted

For better multilingual speech, translator42 is recommended:

  https://aminet.net/package/util/libs/translator42

For French speech, the 0Paris accent package can improve pronunciation:

  https://aminet.net/package/util/libs/ax_0Paris

INSTALLATION

1. Copy the compiled program to a directory of your choice.
2. Copy tina2s.iff into the same directory as the compiled program.
3. Copy octocontrol_native.cfg.example to S:octocontrol_native.cfg.
4. Edit S:octocontrol_native.cfg:

   OCTOPRINT=192.168.1.100:80
   APIKEY=PASTE_YOUR_OCTOPRINT_API_KEY_HERE

   Replace the IP address with the address of your OctoPrint server and use
   your own OctoPrint API key.

5. Optional speech configuration:

   Copy octocontrol_speech.cfg.example to S:octocontrol_speech.cfg.
   Edit this file to change the spoken messages without recompiling.

6. Start OctoControl Speak and click Tester.

SPEECH SETUP

Before using the speaking features, test SAY from a Shell:

  Mount SPEAK:
  Say "OctoPrint est hors ligne"

If it does not speak, check that narrator.device, Speak-Handler and
translator.library are correctly installed.

To mount SPEAK: automatically, add this to S:User-Startup:

  Mount SPEAK:

SPEECH CONFIGURATION

The file S:octocontrol_speech.cfg is optional. If it does not exist, the
program uses built-in French messages.

Example:

  TEMP_OK=La buse est a temperature
  PRINTING=L impression est en cours
  PAUSED=L impression est en pause
  DONE=Impression terminee
  OCTOPRINT_OFFLINE=OctoPrint est hors ligne
  INSERT=Insertion du filament
  RETRACT=Retrait du filament

Users can translate these messages to their own language or change the
spelling so that SAY pronounces them better.

SOURCE

OctoControlSpeak.e is the full AmigaE source.

The program uses these modules:

  MODULE 'bsdsocket'
  MODULE 'amitcp/sys/socket'
  MODULE 'amitcp/netinet/in'

The modules must be available to the AmigaE compiler. bsdsocket.m can be
generated from the AmiTCP socket pragmas when it is not already installed.

USAGE NOTES

- Use Tester to verify OctoPrint and the API key.
- Use Connect impr. to reconnect the printer after a reboot or emergency stop.
- Use Status to read temperatures and open/update the monitor.
- Use Mini to hide the main window and keep the monitor visible.
- Use Files, select a G-code entry, then Print choix to print a file already
  stored in OctoPrint.
- Use Effacer to delete the selected OctoPrint file.
- Use Envoyer to upload a G-code from the Amiga without starting it.
- Use Envoyer+Print to upload and immediately start the selected G-code.
- M105 is a safe communication test.
- URGENCE M112 is a real emergency stop. It stops the printer and usually
  requires reconnecting or restarting the printer afterwards.

SECURITY

Never distribute your real S:octocontrol_native.cfg file. It contains your
private OctoPrint API key. Distribute only the provided example configuration.

THANKS

Thanks to the Amiga and OctoPrint communities, MUI, AmigaE, AmiTCP, Aminet,
translator42, 0Paris, and all users who keep classic Amiga systems alive.

Developed by Denis Costils with assistance from Codex.

This program is supplied as freeware with source code included.
