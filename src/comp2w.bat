rem makefile.wco in PDPCLIB should be run first

wasm -zq -zcm -D__SZ4__ -Dmemodel=huge -DWATCOM pdosstrt.asm
wasm -zq -zcm -D__SZ4__ -Dmemodel=huge support.asm

wasm -zq -zcm -D__SZ4__ -Dmemodel=huge lldos.asm
rem ml -nologo -c -D__SZ4__ -Dmemodel=huge lldos.asm
rem as86 -D__SZ4__ -Dmemodel=huge lldos.asm

wasm -zq -zcm -D__SZ4__ -Dmemodel=huge handlers.asm
rem ml -nologo -c -D__SZ4__ -Dmemodel=huge handlers.asm
rem as86 -D__SZ4__ -Dmemodel=huge handlers.asm

set OPT=-oneatx
rem if you want a one-shot shot at running NE executable
rem set NEDEMO=-DNEDEMO
set NEDEMO=

wcl %OPT% -D__SZ4__ -zp1 -ecc -q -w -c -mh -zl -fpi87 -s -zdp -zu -D__MSDOS__ -DBUFSIZ=512 -I..\pdpclib memmgr.c patmat.c process.c
wcl %OPT% -D__SZ4__ -zp1 -ecc -q -w -c -mh -zl -fpi87 -s -zdp -zu -D__MSDOS__ -DBUFSIZ=512 -I..\pdpclib int21.c log.c helper.c
wcl %OPT% -D__SZ4__ -zp1 -ecc -q -w -c -mh -zl -fpi87 -s -zdp -zu -D__MSDOS__ -DBUFSIZ=512 -I..\pdpclib bos.c fat.c

rem if doing NE, want this too
rem wcl %OPT% -D__SZ4__ -zp1 -ecc -q -w -c -mh -zl -fpi87 -s -zdp -zu -D__MSDOS__ -DBUFSIZ=512 -I..\pdpclib -DNEED_MZ -DNO_DLLENTRY ..\bios\exeload.c

rem bcc -w- to switch off warnings
wcl %OPT% -D__SZ4__ -zp1 -ecc -q -w -c -mh -zl -fpi87 -s -zdp -zu -D__MSDOS__ -DBUFSIZ=512 -I..\pdpclib %NEDEMO% pdos.c

if exist os.lib del os.lib
wlib -b -q os +bos.obj
wlib -b -q os +support.obj
wlib -b -q os +fat.obj
wlib -b -q os +lldos.obj
wlib -b -q os +handlers.obj
wlib -b -q os +memmgr.obj
wlib -b -q os +patmat.obj
wlib -b -q os +process.obj
wlib -b -q os +int21.obj
wlib -b -q os +log.obj
wlib -b -q os +helper.obj
rem If doing NE, want this too
rem wlib -b -q os +exeload.obj

wlink File pdosstrt.obj,pdos.obj Name pdos.exe Form dos Output raw offset=0x20000 Order clname CODE segment pdosstrt_TEXT segaddr=0x2000 offset=0x0 clname DATA clname BSS clname STACK Library os.lib,..\pdpclib\watcomo.lib Option quiet,map,verbose,dosseg
