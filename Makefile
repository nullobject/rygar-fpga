.PHONY: program rom clean

build:
	quartus_sh --flow compile rygar

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/rygar.sof@2"

rom:
	srec_cat rom/5.5p -binary -o rom/cpu_5p.mif -mif
	srec_cat rom/cpu_5m.bin -binary -o rom/cpu_5m.mif -mif
	srec_cat rom/cpu_5j.bin -binary -o rom/cpu_5j.mif -mif
	srec_cat rom/5.5p       -binary -offset 0x00000 \
	         rom/cpu_5m.bin -binary -offset 0x08000 \
					 rom/cpu_8k.bin -binary -offset 0x0C000 \
					 rom/vid_6k.bin -binary -offset 0x14000 \
					 rom/vid_6j.bin -binary -offset 0x1C000 \
					 rom/vid_6h.bin -binary -offset 0x24000 \
					 rom/vid_6g.bin -binary -offset 0x2C000 \
					 -o rom/tiles.mif -mif

clean:
	rm -rf db incremental_db output_files
