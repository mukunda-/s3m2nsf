              _____          ___              ____
         ____|__  /____ ___ |__ \ ____  _____/ __/
        / ___//_ </ __ `__ \__/ // __ \/ ___/ /_  
       (__  )__/ / / / / / / __// / / (__  ) __/  
      /____/____/_/ /_/ /_/____/_/ /_/____/_/     

 (c) 2007 Mukunda Johnson, Juan Linietsky. See license in source

COMMAND LINE:
-=-=-=-=-=-=-

S3M2NSF is a Command Line application. This means, you need to run it
from the console, or drag s3m files over the executable.
Additional options and parameters for the creation of NSF file are 
shown by typing:

C:\> s3m2nsf -h

or

skaven@fc:~$ s3m2nsf --help

MAKING S3Ms
-=-=-=-=-=-

First of all, use nespack.s3m to make your song. ANY OTHER PACKS WON'T WORK. 
This is because samples need to be tuned to the c4 freq in
nespack.s3m to generate the proper amiga periods that can be
later transformed into nes square/triangle/noise periods easily.

If you still insist on using another pack, or a song made for
another pack, it will work but pitch slides, vibrato, etc will be
highly inaccurate.

-Channels 1 and 2 are used for square waves. You can use samples 1 to 4
in them. Lowest note is A-2.

-Channel 3 is used for the triangle wave, Lower pitch is permitted, but
volume will be clipped to on/off. Sample 5 must be used/

-Channel 4 is noise, not all notes are permitted, and will be corrected.
Most notes are 
Pitch effects will still work. Samples 6 and 7 must be used.

-Channel 5 is DPCM. See DPCM Section.


TIMING:
-=-=-=-

Tempos over 150 may also prove to be inaccurate in some cases, (as well
as use more 6502 cycles) as more ticks will be processed than the 
60hz NTSC timing can handle. This will be more evident on SCx / SDx / Jxx
commands.

DPCM:
-=-=-

DPCM sounds must be loaded contiguous on sample slots 8+ , and should have
ideally 8363hz as base speed (C-5). 
For higher precision, Most of the existing DPCM drums should be
used in your track at C-7, which is the highest possible bitrate 
(simple make them so they sound fine at C-7, with base speed of 8363hz).

Permitted notes for DPCM samples:

C-4, D-4, E-4, F-4, G-4, A-4, B-4, 
C-5, D-5,      F-5, G-5, A-5, 
C-6, E-6,      G-6
C-7.

Loop is supported, but goes from 0 to length (whole sample).

Note: With VRC6, DPCM samples start at 17+.

VRC6:
-=-=-

Use nespack_vrc6.s3m if you want VRC6 support. Channel 6 & 7 are
now extra square waves to be used with samples 8->16. Channel 8
is the VRC6 sawtooth (sample 17).

AUTHORSHIP
-=-=-=-=-=-

s3m2nsf is (c) 2007 Mukunda Johnson, Juan Linietsky. See license in source
files.

Credits: 

	C Util and Converter: Juan Linietsky
	6502-based S3M Player: Mukunda Johnson
	Additional Help: Ken Snyder, Hubert Lamontagne, James Martin
