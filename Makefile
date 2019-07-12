.PHONY: program roms clean

build:
	quartus_sh --flow compile rygar

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/rygar.sof@2"

roms:
	srec_cat roms/5.5p -binary -o roms/cpu_5p.mif -mif
	srec_cat roms/cpu_5m.bin -binary -o roms/cpu_5m.mif -mif
	srec_cat roms/cpu_5j.bin -binary -o roms/cpu_5j.mif -mif
	srec_cat roms/cpu_8k.bin -binary -o roms/cpu_8k.mif -mif
	srec_cat roms/vid_6p.bin -binary -offset 0x00000 \
					 roms/vid_6o.bin -binary -offset 0x08000 \
					 roms/vid_6n.bin -binary -offset 0x10000 \
					 roms/vid_6l.bin -binary -offset 0x18000 \
					 -o roms/fg.mif -mif
	srec_cat roms/vid_6f.bin -binary -offset 0x00000 \
					 roms/vid_6e.bin -binary -offset 0x08000 \
					 roms/vid_6c.bin -binary -offset 0x10000 \
					 roms/vid_6b.bin -binary -offset 0x18000 \
					 -o roms/bg.mif -mif
	srec_cat roms/vid_6k.bin -binary -offset 0x00000 \
					 roms/vid_6j.bin -binary -offset 0x08000 \
					 roms/vid_6h.bin -binary -offset 0x10000 \
					 roms/vid_6g.bin -binary -offset 0x18000 \
					 -o roms/sprite.mif -mif

clean:
	rm -rf db incremental_db output_files
