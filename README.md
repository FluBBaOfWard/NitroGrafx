# NitroGrafx V0.9.0

PC-Engine/TurboGrafx-16 emulator for NDS

This is a PC-Engine/TurboGrafx-16 emulator for the Nintendo DS(i)/3DS, it can
also emulate some of the (Super) CD-ROM^2 & Arcade Card. It does not emulate
the SuperGrafx. All games are not perfect. Don't use overdumps as these are
evil on PC-Engine.

## How to use

1. Create a folder named "NitroGrafx" in either the root of your flash card or
 in the data directory (eg h:\NitroGrafx or h:\data\NitroGrafx). This is where
 settings and save files end up.
2. Now put your games into a folder where you have (PC-Engine) roms, max 768
 games per folder, filenames must not be longer than 127 chars. You can use
 zipped files (as long as they use the deflate compression).
3. Depending on your flashcart you might have to DLDI patch the emulator.

The GUI is accessed by pressing L+R (shoulder buttons) or by touching the
screen, tabs are changed by pressing the L or R button, going to the left most
tab exits the GUI. Closing your DS puts the emulator in sleep mode, just open
it to resume.

When you first run the emulator I suggest you take a peak through the options
and change the settings to your liking and then save them. To be able to use
CD-ROM games you have to select a CD-ROM System rom (bios) from
Options-Machine-BiosSettings-SelectBios. You can use .iso files or .bin/.cue
files see CDROM_readme.txt for more info.

Now load up a game and you should be good to go.

## Menu

### File

* Load Hucard:
* Load CDROM:
* Load State: Load state for current game.
* Save State: Save state for current game.
* Save Settings: Saves settings and current path.
* Eject Game:
* Power On/Off:
* Reset Game:
* Quit Emulator: (If supported.)

### Options

* Controller:
  * MultiTap: Select if MultiTap is connected.
  * Controller: Select which player is controlled (if MultiTap).
  * Joypad: Select which kind of controller is connected (2 or 6 Button).
  * B Autofire: Select if you want autofire on button B.
  * A Autofire: Select if you want autofire on button A.
  * Swap A-B: Swap which NDS button is mapped to which PCE button.
  * Use R as FastForward: Select turbo speed as long as R button is held.
* Display:
  * Display: Here you can select if you want scaled or unscaled screenmode.
  * Scaling: Here you can select if you want flicker or barebones lineskip.
  * Output: Select between Composite or RGB (affects colors).
  * Gamma: Lets you change the gamma ("brightness").
  * Color: Lets you change the color saturation.
* Machine:
  * Region: Change the region between US & JP, US should work for most games.
  * Machine: Here you can select the hardware, Auto should work for most games.
  * Bios Settings:
    * Use Bios: Here you can select if you want to use the selected BIOSes.
    * Select Bios: Browse for CD bios.
  * Fake spritecollision: Not used yet.
* Settings:
  * Speed: Switch between speed modes.
    * Normal: Game runs at it's normal speed.
    * 200%: Game can run up to double speed.
    * Max: Game can run up to 4 times normal speed.
    * 50%: Game runs at half speed.
  * Autoload State: Toggle Savestate autoloading. Automagicaly load the
    savestate associated with the selected game.
  * Autosave BRAM: Saves BRAM if it's changed when entering GUI.
  * Autosave Settings: Saves changed settings every time you leave GUI.
  * Autopause Game: Pause game when opening GUI.
  * Powersave 2nd Screen: If graphics/light should be turned off for the GUI
    screen when menu is not active.
  * Emulator on Bottom: Select if top or bottom screen should be used for
    emulator, when menu is active emulator screen is allways on top.
  * Debug Output: Set if you want debug output or not.
* Debug:
  * Debug Output: Show FPS and logged text.
  * Disable Background: Turn on/off background rendering.
  * Disable Sprites: Turn on/off sprite rendering.
  * Step Frame: Emulate one frame.


### About

Some dumb info about the emulator...

## Controls

* NDS B & A buttons are mapped to PC-Engine II & I.
* NDS Start is mapped to PC-Engine Run.
* NDS Select is mapped to PC-Engine Select.
* NDS d-pad is mapped to PC-Engine d-pad.

## Games

* Cadash, vertical flickering alot.
* Night Creatures, no sprites.
* Space Harrier, no sprites.
* Turrican, hangs at continue.

## Credits

```text
Thanks to:
Zeograd for a lot of help with the debugging.
Charles MacDonald (http://cgfm2.emuviews.com) &
David Shadoff for a lot of the info on the PC-Engine.
```

Fredrik Ahlström

<https://bsky.app/profile/therealflubba.bsky.social>

<https://www.github.com/FluBBaOfWard>

X/Twitter @TheRealFluBBa
