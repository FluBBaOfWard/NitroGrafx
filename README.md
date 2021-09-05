# NitroGrafx V0.9.0
PC-Engine/TurboGrafx-16 emulator for NDS

This is a PC-Engine/TurboGrafx-16 emulator for the NDS, it can also
emulate some of the (Super) CD-ROM^2 & Arcade Card.
All games are not perfect, (alot of US games doesn't work because they are encrypted,
use PCEToy or the emulator Ootake to decrypt these before you use them).
Don't use overdumps as these are evil on PC Engine.

And this readme is still W.I.P.

## How to use:

Depending on your flashcart you might have to DLDI patch the emulator file.
You should also create a "NitroGrafx" directory either in the root of your card or in
the data directory (eg h:\NitroGrafx or h:\data\NitroGrafx).

Put your games on your flash card, max 768 games per folder (though shouldn't be
a problem).
Filenames must not be longer than 127 chars.
You can use zipped files (as long as they use the deflate compression).

The GUI is accessed by pressing L+R (shoulder buttons) or by touching the
screen, tabs are changed by pressing the L or R button, going to the left most
tab exits the GUI. Closing your DS puts the emulator in sleep mode, just open
it to resume.

When you first run the emulator I suggest you take a peak through the options
and change the settings to your liking and then save them.
To be able to use CD-ROM games you have to select a CD-ROM System rom (bios)
from Options-Machine-BiosSettings-SelectBios.
You can use .iso files or .bin/.cue files see CDROM_readme.txt for more info.

Now load up a game and you should be good to go.


## Menu:
### File:
	Load Hucard:
	Load CDROM:
	Load State: Load state for current game.
	Save State: Save state for current game.
	Save Settings: Saves settings and current path.
	Eject Game:
	Power On/Off:
	Reset Game:

### Options:
	Controller:
		Autofire: Select if you want autofire.
		Controller: 2P control player 2.
		Swap A/B: Swap which NDS button is mapped to which PCE button.
		Use R as FastForward: Select turbo speed as long as R button is held.

	Display:
		Display: Here you can select if you want scaled or unscaled screenmode.
		Scaling: Here you can select if you want flicker or barebones lineskip.
		Gamma: Lets you change the gamma ("brightness").
		Color: Lets you change the color.
		Disable Background: Turn on/off background rendering.
		Disable Sprites: Turn on/off sprite rendering.

	Machine:
		Region: Change the region between US & JP, US should work for most games.
		Machine: Here you can select the hardware, Auto should work for most games.
		Bios Settings:
			Use Bios: Here you can select if you want to use the selected BIOSes.
			Select Bios: Browse for CD bios.
		Fake spritecollision: Not used yet.

	Settings:
		Speed: Switch between speed modes, can also be toggled with L+START.
			Normal: Standard, 100% speed.
			Fast: Double, 200% speed.
			Max: Fastest, 400% speed.
			Slowmo: Slow, 50% speed.
		Autoload State: Toggle Savestate autoloading.
			Automagicaly load the savestate associated with the selected game.
		Autosave Settings: Saves changed settings every time you leave GUI.
		Autosave BRAM: Saves BRAM if it's changed when entering GUI.
		Autopause Game: Pause game when opening GUI.
		Powersave 2nd Screen: If graphics/light should be turned off for the
			GUI screen when menu is not active.
		Emulator on Bottom: Select if top or bottom screen should be used for
			emulator, when menu is active emulator screen is allways on top.
		Debug Output: Set if you want debug output or not.
		Autosleep: Change the autosleep time, also see Sleep. !!!DoesntWork!!!

### About:
	Some dumb info...

Sleep: Put the NDS into sleepmode.
	START+SELECT wakes up from sleep mode (activated from this menu or from
	5/10/30	minutes of inactivity). !!! Doesn't work !!!

## Credits:
Thanks to:
Zeograd for a lot of help with the debugging.
Charles MacDonald (http://cgfm2.emuviews.com) &
David Shadoff for a lot of the info on the PC-Engine.

Don't forget to join the NitroGrafx forum at http://boards.pocketheaven.com/

Fredrik Ahlström
Twitter @TheRealFluBBa
http://www.github.com/FluBBaOfWard

