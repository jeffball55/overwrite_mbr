overwrite_mbr
=============

WARNING: These programs will make your computer unbootable.  Don't use them unless that's the desired behavior.

A collection of tools for overwriting the MBR (Master Boot Record) of a machine with another file.  After overwriting, the 
executables will reboot the machine into the new boot image.  Additionally, another executable is included that will run in the
background and wait until a specific time to overwrite the mbr.  This is useful for synchronizing the overwriting of MBRs on
multiple machines (to increasing the trolling effect).

I've included some fun boot images you can use, none of which were created by me (See the readmes in their directories for the 
more info).  The nyancat boot image has been embedded into these programs so that they can be run with any other files needed 
besides the executable.
