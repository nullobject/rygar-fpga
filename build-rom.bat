rem version 2.20 - 2019/08/16 by Bruno Silva
@echo off
setlocal ENABLEDELAYEDEXPANSION
set pwd=%~dp0
MODE CON COLS=132 LINES=50
color 2
Title Rygar's Arcade Rom Creator
set "verb=> nul"
set /A merged=0

:MENU
cls
echo '########::'##:::'##::'######::::::'###::::'########::
echo  ##.... ##:. ##:'##::'##... ##::::'## ##::: ##.... ##:
echo  ##:::: ##::. ####::: ##:::..::::'##:. ##:: ##:::: ##:
echo  ########::::. ##:::: ##::'####:'##:::. ##: ########::
echo  ##.. ##:::::: ##:::: ##::: ##:: #########: ##.. ##:::
echo  ##::. ##::::: ##:::: ##::: ##:: ##.... ##: ##::. ##::
echo  ##:::. ##:::: ##::::. ######::: ##:::: ##: ##:::. ##:
echo ..:::::..:::::..::::::......::::..:::::..::..:::::..::

echo.
if %merged% EQU 0 (
echo Copy Mame Non-Merged set files to !pwd!MAME folder
) else (
echo Copy Mame Merged set files to !pwd!MAME folder
)
echo Copy HBMame Merged set files to !pwd!HBMAME folder
echo.
echo This bat file was tested with mame version 0.213
echo.
echo Press H for Help
echo.
echo ** MENU **
echo 1 - Rygar (US set 1) - Default
echo 2 - Argus no Senshi (Japan)
echo 3 - Rygar (US set 2)
echo 4 - Rygar (US set 3 Old Version)
echo 5 - Argus no Senshi (Translation Chinese) - HBMame
echo 6 - Argus no Senshi (Translation Korean) - HBMame
echo 7 - Rygar (US, bootleg) - HBMame

echo.
if %merged% EQU 0 (
echo C - Change from Non-Merged to Merged MAME ROM SET
) else (
echo C - Change from Merged to Non-Merged MAME ROM SET
)
if "%verb%" EQU "" (
echo V - Set verbose Off
) else (
echo V - Set verbose On
)
echo H - HELP
echo Q - Quit


if NOT EXIST "!pwd!MAME" mkdir "!pwd!MAME" 2> nul
if NOT EXIST "!pwd!HBMAME" mkdir "!pwd!HBMAME" 2> nul
echo.
SET /P M="Choose option and then press ENTER (or Q to quit): "
IF '%M%'=='1' GOTO RYGAR
IF '%M%'=='2' GOTO RYGARJ
IF '%M%'=='3' GOTO RYGAR2
IF '%M%'=='4' GOTO RYGAR3
IF '%M%'=='5' GOTO RYGARJS01HB
IF '%M%'=='6' GOTO RYGARKHB
IF '%M%'=='7' GOTO RYGARS01HB

echo.
IF '%M%'=='c' GOTO CHANGEMERGED
IF '%M%'=='C' GOTO CHANGEMERGED
IF '%M%'=='h' GOTO HELP
IF '%M%'=='H' GOTO HELP
IF '%M%'=='v' GOTO VERBOSE
IF '%M%'=='V' GOTO VERBOSE
IF '%M%'=='q' GOTO QUIT
IF '%M%'=='Q' GOTO QUIT

GOTO MENU

:RYGAR
set zip1m=MAME\rygar.zip
set ifilesm=5.5p+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=MAME\rygar.zip
set ifiles=5.5p+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=e0355e7803fdab0a8d8b5bda284ef2a5
set ofile=a.rygar.rom
set fullname=Rygar (US set 1) - Default
GOTO START

:RYGARJ
set zip1m=MAME\rygar.zip
set ifilesm=rygarj\cpuj_5p.bin+rygarj\cpuj_5m.bin+rygarj\cpuj_5j.bin+rygarj\cpuj_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=MAME\rygarj.zip
set ifiles=cpuj_5p.bin+cpuj_5m.bin+cpuj_5j.bin+cpuj_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=c30e7c77f006ea8a3ba57ca394e216b6
set ofile=Argus no Senshi (Japan).rom
set fullname=Argus no Senshi (Japan)
GOTO START

:RYGAR2
set zip1m=MAME\rygar.zip
set ifilesm=rygar2\5p.bin+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=MAME\rygar2.zip
set ifiles=5p.bin+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=4a8892ea320c2b99bebf48056a60c699
set ofile=Rygar (US set 2).rom
set fullname=Rygar (US set 2)
GOTO START

:RYGAR3
set zip1m=MAME\rygar.zip
set ifilesm=rygar3\cpu_5p.bin+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=MAME\rygar3.zip
set ifiles=cpu_5p.bin+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=a31fe6b380f88e60a0d07b4d64661355
set ofile=Rygar (US set 3 Old Version).rom
set fullname=Rygar (US set 3 Old Version)
GOTO START

:RYGARJS01HB
set zip1m=HBMAME\rygar.zip
set ifilesm=rygarjs01\cpuj_5phc01.bin+rygarjs01\cpuj_5m.bin+rygarjs01\cpuj_5jhc1.bin+rygarjs01\cpuj_8khc01.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=HBMAME\rygar.zip
set ifiles=rygarjs01\cpuj_5phc01.bin+rygarjs01\cpuj_5m.bin+rygarjs01\cpuj_5jhc1.bin+rygarjs01\cpuj_8khc01.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=0e778a2625c42b3bc0221e882b63bb50
set ofile=Argus no Senshi (Translation Chinese) - HB.rom
set fullname=Argus no Senshi (Translation Chinese) - HBMame
GOTO START

:RYGARKHB
set zip1m=HBMAME\rygar.zip
set ifilesm=rygark\cpuj_5p.bin+rygarjs01\cpuj_5m.bin+rygark\cpuj_5j.bin+rygark\rygark.8k+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=HBMAME\rygar.zip
set ifiles=rygark\cpuj_5p.bin+rygarjs01\cpuj_5m.bin+rygark\cpuj_5j.bin+rygark\rygark.8k+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=275d85aec49446c86fc1db01f71f85a8
set ofile=Argus no Senshi (Translation Korean) - HB.rom
set fullname=Argus no Senshi (Translation Korean) - HBMame
GOTO START

:RYGARS01HB
set zip1m=HBMAME\rygar.zip
set ifilesm=rygars01\5_ps01.5p+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set zip1=HBMAME\rygar.zip
set ifiles=rygars01\5_ps01.5p+cpu_5m.bin+cpu_5j.bin+cpu_8k.bin+vid_6p.bin+vid_6o.bin+vid_6n.bin+vid_6l.bin+vid_6f.bin+vid_6e.bin+vid_6c.bin+vid_6b.bin+vid_6k.bin+vid_6j.bin+vid_6h.bin+vid_6g.bin+cpu_4h.bin+cpu_1f.bin
set md5valid=e20bda5553beffaeee441e0f9babb4a3
set ofile=Rygar (US, bootleg) - HB.rom
set fullname=Rygar (US, bootleg) - HBMame
GOTO START


:CHANGEMERGED
if %merged% EQU 0 (
	set /A merged=1
	echo.
	echo You will now use Merged MAME ROM SET. Press a key to continue...
) else (
	set /A merged=0
	echo.
	echo You will now use Non-Merged MAME ROM SET. Press a key to continue...
)
pause > nul
GOTO MENU

:VERBOSE
if "%verb%" EQU "" (
	set "verb=> nul"
	echo.
	echo Verbose is Off. Press a key to continue...
) else (
	set "verb="
	echo.
	echo Verbose is On. Press a key to continue...
)
pause > nul
GOTO MENU

:START

rem =====================================
echo.
echo.

if %merged% EQU 1 (
	set zip1=%zip1m%
	set ifiles=%ifilesm%
)


if NOT EXIST %zip1% GOTO ERRORZIP1
if NOT EXIST "!pwd!7za.exe" GOTO ERROR7Z
echo.
echo Starting creating rom for %fullname%
echo.
echo Unziping rom file...
echo.
"!pwd!7za" x -y -otmp %zip1% %verb%

	if !ERRORLEVEL! EQU 0 (
		cd tmp
		echo.
		echo Creating rom file...
		echo.
		copy /b /y /v %ifiles% "!pwd!%ofile%" %verb%

			if !ERRORLEVEL! EQU 0 (
				cd "!pwd!"

				set "md5="
					echo.
					echo Checking MD5...
					echo.
					for /f "skip=1 tokens=* delims=" %%# in ('certutil -hashfile "!pwd!%ofile%" MD5') do (
						if not defined md5 (
							for %%Z in (%%#) do  (
								set "md5=%%Z"
							)
						)
					)

				if "%md5valid%" EQU "!md5!" (
					echo.
					echo ** Process is complete! **
					echo.
					echo Copy "%ofile%" into SD card
				) else (
					echo.
					echo ** PROBLEM IN ROM **
					echo.
					echo MD5 DOESN'T MATCH! CHECK YOU ZIP FILE
					echo It could work anyway...
					echo.
					echo MD5 is !md5! but should be "%md5valid%"
				)
			) else (
				GOTO ERRORCOPY
			)
		cd !pwd!
		rmdir /s /q tmp
		GOTO END
	) else (
		GOTO ERRORUNZIP
	)

:ERRORZIP1
	echo.
	echo Error: Cannot find "%zip1%" file.
	GOTO END

:ERROR7Z
	echo.
	echo Error: Cannot find "7za.exe" file. Put it in the same directory as "%~nx0"!
	GOTO END

:ERRORCOPY
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: Problem creating rom!
	echo.
	GOTO END

:ERRORUNZIP
	cd !pwd!
	rmdir /s /q tmp > nul
	echo.
	echo Error: problem unzipping file!
	echo.
	GOTO END


:HELP
color 7
cls
echo '########::'##:::'##::'######::::::'###::::'########::
echo  ##.... ##:. ##:'##::'##... ##::::'## ##::: ##.... ##:
echo  ##:::: ##::. ####::: ##:::..::::'##:. ##:: ##:::: ##:
echo  ########::::. ##:::: ##::'####:'##:::. ##: ########::
echo  ##.. ##:::::: ##:::: ##::: ##:: #########: ##.. ##:::
echo  ##::. ##::::: ##:::: ##::: ##:: ##.... ##: ##::. ##::
echo  ##:::. ##:::: ##::::. ######::: ##:::: ##: ##:::. ##:
echo ..:::::..:::::..::::::......::::..:::::..::..:::::..::

echo.
echo HELP for this .bat file
echo.
echo ** Merged and Non-Merged mame roms **
echo By default this .bat file uses non-merged version of mame roms. You can change to merged version by pressing C in the menu
echo.
echo ** Verbose **
echo By default the .bat doesn't display the output of some commands (unzip/copy). You can see the output by pressing V in the menu.
echo.
echo ** Rom Creation **
echo Choose a number from the menu to create a rom from the zip files from mame. This .bat file checks the md5 for the rom created.
echo Having a different md5 doesn't mean that the rom doesn't work.
echo.
echo ** Copy Files to SD Card **
echo Copy a.rygar.rom to SDCard's root or bootrom folder (mister) and the other roms to a.rygar folder.
echo.
echo ** For reference **
echo.
echo Merged Set:
echo A merged set takes the parent set and one or more clone sets and puts them all inside the parent set^'s storage. To use the
echo existing Pac-Man example, combining the Puckman, Midway Pac-Man (USA) sets, along with various bootleg versions - and combining
echo it all into PUCKMAN.ZIP, would be making a merged set.
echo Remark: The parent games in a merged set DO NOT include BIOS or DEVICE files - they are separate files within the set (An example
echo would be 100lions (No BIOS in the parent) and Galaga (No device file in the parent) - This is per MAME design.
echo.
echo Non-Merged Set:
echo A non-merged set is one that contains absolutely everything necessary for a given game to run in one ZIP file.
echo The non-merged set is ideal for those people that work on Arcade PCBs as ALL roms/devices/bios files are contained within the game.
echo This set is also great for those that for instance create their own arcade cabinets and want to copy only very specific games to
echo their PC/Rapsberry/Other, the game.zip file contain all the files needed, no more searching for the dependent parent files, BIOS
echo files, device files - just copy galaga.zip and you are set.
echo.
echo.
echo Press a key to return to menu...
pause > nul
color 2
GOTO MENU



:END
echo.
echo.
echo Press a key to return to menu...
pause > nul
GOTO MENU

:QUIT
