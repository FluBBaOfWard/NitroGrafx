# PCE PSG

Hu6280 Sound emulator for ARM32.

## How to use

First you need to allocate space for the sound core state, either by using the struct from C or allocating/reserving memory using the "pcePsgSize".
Next call PCEPSGInit with a pointer to that memory.
Memory needs to aligned to 0x20 for sample indexing.

## Projects that use this sound core

* https://github.com/FluBBaOfWard/NitroGrafx

## Credits

Fredrik Ahlström

<https://bsky.app/profile/therealflubba.bsky.social>

<https://www.github.com/FluBBaOfWard>

X/Twitter @TheRealFluBBa
