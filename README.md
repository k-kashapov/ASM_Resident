# ASM_Resident
Resident program, that processes key press and time step interruptions in DOS

# Overview
This is a resident program written for DOS using Assembly language.
Draws a frame with registers on the screen. The registers' value updates every 55 ms, so it can barely be used to check their values.
Also, double bufferization is available so the contents of the screen would be displayed properly, when the frame is turned off.
Note that double bufferization uses video memory pages 0, 1 and 2.
# Installing
  1) Compile res.asm with Turbo ASM into .COM file
  2) Run compiled code on DOS
# Usage
You can turn the frame on/off with Right Shift key. 
When on, hold Left Shift key and press arrow keys to move the frame in the respective direction. 
Make sure you don't move it too high above the screen, as it can corrupt some vital memory.
