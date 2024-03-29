rem theoretically we could have a different C library for all 3
rem of MVS applications, PDOS applications and standalone programs,
rem which would require 3 different conditional compilations.
rem However, PDOS applications are sufficiently close to MVS that
rem a special compilation is not required. In addition, the
rem structure and scope of standalone programs (such as the PDOS
rem operating system itself) don't use most of the C library
rem functions, and the bit that they do use can fit within the
rem same structure so long as the assembler code is changed.
rem That is how we get away without requiring a special version
rem of the C library!

gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/start.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/stdio.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/stdlib.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/ctype.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/string.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/time.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/errno.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/assert.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/locale.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/math.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/setjmp.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/signal.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib ../pdpclib/__memmgr.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib pload.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -DXXZAM31 -S -I . -I ../pdpclib pdos.c
gccmvs -DUSE_MEMMGR -Os -DZARCH -S -I . -I ../pdpclib pdosutil.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib pcomm.c
gccmvs -O0 -DZARCH -S -I . -I ../pdpclib world.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib mkipltap.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib mkiplcrd.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib bbs.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib exe2com.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../src/pdpnntp.c
gccmvs -DTARGET_MVS -Os -DZARCH -S -I . -I ../pdpclib ../util/multisc.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/copycon.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/assemble.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/xychop.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../util/mfemul.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/zcalc.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/hex2dec.c
gccmvs -Os -DZARCH -S -I . -I ../pdpclib ../../mvssrc/ozpd/c/dec2hex.c

sleep 1

rem when globally changing, change the DS3x0 to whatever
rem and then change the file in the next line after comments
rem also you will need to change pdptop.mac

rem copy pdosz.cnf pdos.cnf


rem we did compiles already, but now need to do assembles and
rem links, plus iebcopy unloads, so we use MVS for that

m4 -I . -I ../pdpclib pdos.m4 >pdos.jcl
call runmvs pdos.jcl output.txt none pdos.zip

loc2ebc output.txt listing.txt 0

rem extract everything and put into expected names

unzip -o pdos
copy pload.txt pload.sys
copy pdos.txt pdos.sys
copy pdosimg.txt pdos.img
copy pdosin.txt config.sys
copy pcomm.txt pcomm.exe
copy pcommin.txt autoexec.bat
copy world.txt world.exe
copy mkipltap.txt mkipltap.exe
copy mkiplcrd.txt mkiplcrd.exe
copy bbs.txt bbs.exe
copy exe2com.txt exe2com.exe
copy pdpnntp.txt pdpnntp.exe
copy copycon.txt copycon.exe
copy zcalc.txt zcalc.exe
copy hex2dec.txt hex2dec.exe
copy dec2hex.txt dec2hex.exe
copy mfemul.txt mfemul.exe
copy xychop.txt xychop.exe
copy assemble.txt assemble.exe
copy multisc.txt multisc.exe
copy mvssamp.txt mvssamp.c
copy sample.txt sample.c
copy wtoworld.txt wtoworld.exe
copy diff.txt diff.exe
copy uemacs.txt uemacs.exe
copy edlin.txt edlin.exe
copy pdmake.txt pdmake.exe
copy pdcc.txt pdcc.exe
copy memacs.txt memacs.exe
copy gcc.txt gcc.exe
copy copyfile.txt copyfile.exe
copy hexdump.txt hexdump.exe
copy mvsendec.txt mvsendec.exe
copy mvsunzip.txt mvsunzip.exe
copy wtowcom.txt wtowcom.com
copy exprogm.txt exprog.mak
copy msjoin.txt msjoin.c
copy msstart.txt msstart.c
copy exprog.txt exprog.c
copy mssup.txt mssup.h

rem create dummy batch file

echo echo nothing to run >hercauto.bat
del hercauto.zip
zip -0X hercauto hercauto.bat

rem copy some header files so that we can do simple compiles
del pdpi.zip
zip -0X -j pdpi.zip ..\pdpclib\*.h


rem build DASD. Put a copy into MVS/380 area for no particular reason

del pdos00.ckd
dasdload ctl.txt pdos00.ckd
rem dasdload -bz2 ctl.txt pdos00.cckd
rem copy pdos00.cckd %MVS380%\dasd\pdos00.199

rem dasdinit -bz2 scratch.cckd 3390 SC3390

rem Try out the new version of PDOS, and remember to manually do the
rem mvsunzip pdpi.zip

hetinit -d -n tapes/out.aws

set HERCULES_RC=auto_ipl.rc
hercules -f pdos.cnf >hercules.log

hetget -n -b tapes/out.aws tapes/out.dat 1 U 0 18452

rem create package suitable for "shipping"

del pdospkg.zip
zip -9X pdospkg pload.sys pdos.sys config.sys readme.txt
zip -9X pdospkg pcomm.exe autoexec.bat world.exe bbs.exe sample.c
zip -9X pdospkg wtoworld.exe hercauto.zip
zip -9X pdospkg ctl.txt pdos00.ckd pdos.cnf auto*.rc termherc*.rc
zip -9X pdospkg runpdos.bat pdos.bat pdpi.zip pdpnntp.exe mkipltap.exe
zip -9X pdospkg mvsendec.exe mvsunzip.exe hexdump.exe copyfile.exe
zip -9X pdospkg pdmake.exe antitwit.txt pdos.img mkiplcrd.exe wtowcom.com
zip -9X pdospkg exe2com.exe multisc.exe mvssamp.c copycon.exe assemble.exe
zip -9X pdospkg xychop.exe mfemul.exe zcalc.exe hex2dec.exe dec2hex.exe
zip -9X pdospkg memacs.exe pdcc.exe
zip -9X pdospkg exprog.mak msjoin.c msstart.c exprog.c mssup.h

rem Simply unzip the package into c:\pdos or whatever and it's done
