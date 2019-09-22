# Rygar (1986)

<img alt="Rygar" src="https://github.com/nullobject/rygar-fpga/raw/master/doc/rygar-banner.jpg" />

Rygar was one of my favourite arcade games as a kid. It was originally built in 1986 by Tecmo, a Japanese video game company, and saw later releases on consoles like Nintendo Entertainment System, Sega Master System, Commodore 64, Atari Lynx, etc.

I began this project by writing an [emulator](https://github.com/nullobject/rygar-emu), so I could focus on learning how the arcade game works, without having to worry about the FPGA side of things.

## Generating the ROM

To run the game on MiSTer, you will need to generate the `a.rygar.rom` ROM file and copy it to your MiSTer.

You will need a copy of the MAME ROMs to generate the Rygar ROM file (not include with this project).

### Linux/MacOS

To generate the ROM file, run the following script with the path to the MAME ROMs as an argument:

    $ ./build-rom.sh mame/rygar.zip

### Windows

To generate the ROM file, run the following script:

    build-rom.bat

## Development

Compile the FPGA core:

    $ make build

Program the FPGA:

    $ make program

## Shout Outs

* Jose Tejada (@topapate)
* Bruno Silva (@eubrunosilvapt)

## Licence

Rygar is licensed under the MIT licence. See the LICENCE file for more details.
