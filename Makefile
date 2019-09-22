.PHONY: program clean

build:
	quartus_sh --flow compile rygar

program:
	quartus_pgm -m jtag -c 1 -o "p;output_files/rygar.sof@2"

release:
	zip -j9 rygar-mister.zip build-rom.bat build-rom.sh output_files/rygar.rbf LICENCE README.md

clean:
	rm -rf db incremental_db output_files
