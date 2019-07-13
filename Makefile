.PHONY: program rom clean

build:
	quartus_sh --flow compile rygar

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/rygar.sof@2"

rom:
	srec_cat rom/5.5p -binary -o rom/cpu_5p.mif -mif
	srec_cat rom/cpu_5m.bin -binary -o rom/cpu_5m.mif -mif
	srec_cat rom/cpu_5j.bin -binary -o rom/cpu_5j.mif -mif
	srec_cat rom/cpu_8k.bin -binary -o rom/cpu_8k.mif -mif
	srec_cat rom/vid_6p.bin -binary -offset 0x00000 \
					 rom/vid_6o.bin -binary -offset 0x08000 \
					 rom/vid_6n.bin -binary -offset 0x10000 \
					 rom/vid_6l.bin -binary -offset 0x18000 \
					 -o rom/fg.mif -mif
	srec_cat rom/vid_6f.bin -binary -offset 0x00000 \
					 rom/vid_6e.bin -binary -offset 0x08000 \
					 rom/vid_6c.bin -binary -offset 0x10000 \
					 rom/vid_6b.bin -binary -offset 0x18000 \
					 -o rom/bg.mif -mif
	srec_cat rom/vid_6k.bin -binary -offset 0x00000 \
					 rom/vid_6j.bin -binary -offset 0x08000 \
					 rom/vid_6h.bin -binary -offset 0x10000 \
					 rom/vid_6g.bin -binary -offset 0x18000 \
					 -o rom/sprite.mif -mif

clean:
	rm -rf db incremental_db output_files
