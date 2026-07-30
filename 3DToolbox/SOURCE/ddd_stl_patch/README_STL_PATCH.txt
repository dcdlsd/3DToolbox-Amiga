DDD STL ASCII patch - test notes
================================

Goal
----
Experimental direct ASCII STL loading in ddd.library / 3DView.

Files in this folder
--------------------
ddd.e        patched library source
dddobject.e  patched object/constants module
dddHeader.e  version bumped to 0.8018
ddd.build    original build file copied for convenience

What changed
------------
- Reused the old inactive LightWave slot as TYPE_STL.
- Format name displayed by the library is now "STL ASCII".
- checkIf3DFile() detects ASCII STL files starting with "solid".
- readFile3D() calls readStlFile() for TYPE_STL.
- readStlFile() loads ASCII STL "vertex" lines into object3d points/faces.
- Binary STL is not supported yet.

Important
---------
This is a test patch. Keep a backup of the original ddd.library and sources.

Suggested Amiga test
--------------------
1. Copy these files into a test copy of the 3DView source folder.
2. Compile with the original build:

   Build ddd.m

3. Make sure the new library is installed:

   Version LIBS:ddd.library

   It should show 0.8018.

4. Reboot or flush old library from memory.
5. Launch 3DView and try opening an ASCII STL file directly:

   test_cube_20mm_ascii.stl
   text.stl

If compilation fails
--------------------
Send the compiler error file/result and we patch from there.
