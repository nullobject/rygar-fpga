# rygar-mister

A MiSTer core for the Rygar arcade game. I also wrote an emulator for Rygar, which you can play [here](https://rygar.joshbassett.info/).

<img alt="Rygar" src="https://raw.githubusercontent.com/nullobject/rygar/master/rygar.png" />

Compiling:

    $ make compile

Programming:

    $ make program

Generate MIFs from ROMs:

    $ srec_cat cpu_5j.bin -binary -o cpu_5j.mif -mif
