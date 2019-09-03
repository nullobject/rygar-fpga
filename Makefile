.PHONY: program rom clean

build:
	quartus_sh --flow compile rygar

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/rygar.sof@2"

rom:
	srec_cat rom/5.5p       -binary -offset 0x00000 \
	         rom/cpu_5m.bin -binary -offset 0x08000 \
	         rom/cpu_5j.bin -binary -offset 0x0C000 \
					 rom/cpu_8k.bin -binary -offset 0x14000 \
					 rom/vid_6k.bin -binary -offset 0x1C000 \
					 rom/vid_6j.bin -binary -offset 0x24000 \
					 rom/vid_6h.bin -binary -offset 0x2C000 \
					 rom/vid_6g.bin -binary -offset 0x34000 \
					 rom/vid_6p.bin -binary -offset 0x3C000 \
					 rom/vid_6o.bin -binary -offset 0x44000 \
					 rom/vid_6n.bin -binary -offset 0x4C000 \
					 rom/vid_6l.bin -binary -offset 0x54000 \
					 rom/vid_6f.bin -binary -offset 0x5C000 \
					 rom/vid_6e.bin -binary -offset 0x64000 \
					 rom/vid_6c.bin -binary -offset 0x6C000 \
					 rom/vid_6b.bin -binary -offset 0x74000 \
					 -o rom/rygar.mif -mif
	cat rom/5.5p \
			rom/cpu_5m.bin \
			rom/cpu_5j.bin \
			rom/cpu_8k.bin \
			rom/vid_6k.bin \
			rom/vid_6j.bin \
			rom/vid_6h.bin \
			rom/vid_6g.bin \
			rom/vid_6p.bin \
			rom/vid_6o.bin \
			rom/vid_6n.bin \
			rom/vid_6l.bin \
			rom/vid_6f.bin \
			rom/vid_6e.bin \
			rom/vid_6c.bin \
			rom/vid_6b.bin \
			> rom/a.rygar.rom

clean:
	rm -rf db incremental_db output_files
