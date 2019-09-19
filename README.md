# Rygar (1986)

<img alt="Rygar" src="https://github.com/nullobject/rygar-fpga/raw/master/doc/rygar-banner.jpg" />

Rygar was one of my favourite arcade games as a kid. It was originally built in 1986 by Tecmo, a Japanese video game company, and saw later releases on consoles like Nintendo Entertainment System, Sega Master System, Commodore 64, Atari Lynx, etc.

I began this project by writing an [emulator](https://github.com/nullobject/rygar-emu), so I could focus on learning how the arcade game works, without having to worry about the FPGA side of things.

## Building the ROM

To build the ROM file for this core, you will need a copy of the MAME ROMs. They are not include with this project, but you should be able to find them easily.

### Linux/MacOS

Build the ROM file from the Rygar MAME ROMs:

    $ ./build-rom.sh rygar.zip

### Windows

Build the ROM file from the Rygar MAME ROMs:

    $ ./build-rom.bat rygar.zip

## Development

Compile the core:

    $ make build

Program the FPGA:

    $ make program

## Shout Outs

* Jose Tejada (@topapate)
* Bruno Silva (@eubrunosilvapt)

## Licence

Rygar is licensed under the MIT licence. See the LICENCE file for more details.
